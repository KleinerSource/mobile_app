import 'package:omm/shared/paged_request_coordinator.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/paged_selection.dart';
import 'package:omm/shared/status_pill.dart';
import 'package:omm/shared/debouncer.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_provider.dart';
import 'package:omm/features/oh_my_media/tasks/task_model.dart';
import 'package:omm/features/oh_my_media/tasks/task_name_labels.dart';
import 'package:omm/features/translation/modal_transcription_providers.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'audio_models.dart';
import 'audio_providers.dart';

/// 转译阶段的展示文案：未知 stage 原样返回，stage 为空且活跃时显示兜底。
String _transcriptionStageLabel(AppL10n l, AudioTranscription t) {
  if (t.status == 'queued') return l.audioStageQueued;
  if (t.stage.isNotEmpty) {
    return switch (t.stage) {
      'queued' => l.audioStageQueued,
      'starting' => l.audioStageStarting,
      'connecting' => l.audioStageConnecting,
      'sandbox' => l.audioStageSandbox,
      'preparing' => l.audioStagePreparing,
      'uploading' => l.audioStageUploading,
      'transcribing' => l.audioStageTranscribing,
      'downloading' => l.audioStageDownloading,
      'registering' => l.audioStageRegistering,
      'completed' => l.audioStageCompleted,
      'failed' => l.audioStageFailed,
      'canceled' => l.audioStageCanceled,
      'skipped' => l.audioStageSkipped,
      _ => t.stage,
    };
  }
  return t.isActive ? l.audioStageTranscribingFallback : t.status;
}

/// 音频管理 · 集中查看已提取的音频资产与字幕转译进度
///
/// - 汇总卡 + 搜索栏 (320ms debounce)
/// - 提取中任务：来自任务中心 WebSocket，含实时进度，左滑取消
/// - 资产卡片：影片 / 文件 / 规格 / 转译状态，单项操作左滑展开
/// - 长按多选（滑动连选）：批量加入转译、批量删除
/// - 音频提取请从影片详情页发起
class AudioManagementPage extends ConsumerStatefulWidget {
  const AudioManagementPage({super.key});

  @override
  ConsumerState<AudioManagementPage> createState() =>
      _AudioManagementPageState();
}

class _AudioManagementPageState extends ConsumerState<AudioManagementPage> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  final _requests = PagedRequestCoordinator();
  final _controller = PagingController<int, AudioAsset>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<AudioAsset>(
    _controller,
  );

  final _debounce = Debouncer();
  Timer? _taskReloadDebounce;
  int? _loadingPageSerial;
  String? _search;
  String _lastTaskSignature = '';
  bool _lastPageComplete = false;
  int _requestSerial = 0;
  int _totalCount = 0;
  late final PagedSelectionController<int> _selection;
  final Set<int> _busyAssetIds = <int>{};
  final Set<String> _busyTaskIds = <String>{};
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _selection = PagedSelectionController<int>();
    _selection.addModeListener(_onSelectionModeChanged);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _openSwipe.dispose();
    _taskReloadDebounce?.cancel();
    _debounce.cancel();
    _requests.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _selection.dispose();
    super.dispose();
  }

  bool get _selectionMode => _selection.isActive;
  Set<int> get _selectedIds => _selection.selectedIds.cast<int>();

  void _onSelectionModeChanged() {
    if (mounted) setState(() {});
  }

  void _handleScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
    _requestNextPageIfNeeded();
  }

  void _requestNextPageIfNeeded() {
    if (!_scrollController.hasClients ||
        _controller.itemList == null ||
        _controller.nextPageKey == null ||
        _controller.error != null ||
        _refreshing ||
        _loadingPageSerial == _requestSerial) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter > position.viewportDimension) return;
    unawaited(_fetch(_controller.nextPageKey!));
  }

  void _retryNextPage() {
    final nextPageKey = _controller.nextPageKey;
    if (nextPageKey == null) return;
    _controller.error = null;
    unawaited(_fetch(nextPageKey));
  }

  Future<void> _fetch(int offset) async {
    final pageRequest = _requests.begin(offset);
    if (pageRequest == null) return;
    final requestSerial = _requestSerial;
    var didApplyPage = false;
    try {
      // 刷新已有列表时保留旧数据，避免列表组件触发额外的后续分页请求。
      if (_refreshing && offset != 0) return;
      if (!mounted) return;
      setState(() => _loadingPageSerial = requestSerial);
      final page = await ref
          .read(audioRepositoryProvider)
          .listAssets(limit: _pageSize, offset: offset, search: _search);
      if (!pageRequest.isCurrent) return;
      if (!mounted || requestSerial != _requestSerial) return;

      _refreshing = false;
      setState(() {
        _totalCount = page.total;
      });
      // 末页标记：连排列表只有最后一行需要底部圆角。
      final hasMore = applyPagedListPage(
        controller: _controller,
        offset: offset,
        items: page.items,
        totalCount: page.total,
        restorer: _scrollRestorer,
        scrollController: _scrollController,
      );
      didApplyPage = true;
      setState(() => _lastPageComplete = !hasMore);
      _pruneSelection(page.items);
    } catch (error) {
      if (!pageRequest.isCurrent) return;
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = localizedErrorMessage(AppL10n.of(context), error);
      _refreshing = false;
    } finally {
      pageRequest.finish();
      if (mounted && _loadingPageSerial == requestSerial) {
        setState(() => _loadingPageSerial = null);
      }
      if (mounted && didApplyPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _requestNextPageIfNeeded();
        });
      }
    }
  }

  /// 条目进入转译后从已选集合移除，避免已禁用的行残留勾选被批量操作误包含。
  void _pruneSelection(List<AudioAsset> items) {
    if (_selectedIds.isEmpty) return;
    final activeMovies = _activeTranscriptionMovieIds();
    final keep = items
        .where(
          (asset) =>
              _selectedIds.contains(asset.id) &&
              !_isAssetLocked(asset, activeMovies),
        )
        .map((asset) => asset.id)
        .toSet();
    if (keep.length != _selectedIds.length) {
      _selection.retainWhere(keep.contains, deactivateWhenEmpty: true);
    }
  }

  void _reload({bool preserveScroll = false}) {
    _requests.invalidate();
    _resetPaging(preserveScroll: preserveScroll);
  }

  void _resetPaging({bool preserveScroll = false}) {
    final loadedItems = _controller.itemList;
    final requestSerial = ++_requestSerial;
    _scrollRestorer.prepare(_scrollController, preserve: preserveScroll);
    _refreshing = true;

    if (!preserveScroll &&
        loadedItems != null &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    if (loadedItems == null) {
      refreshPagedController(
        controller: _controller,
        requests: _requests,
        loadPage: _fetch,
      );
      return;
    }

    // 已有内容时不清空分页控制器，让刷新请求在后台完成，避免首屏加载态
    // 替换当前列表造成闪烁，也避免滚动中的行被卸载而中断用户操作。
    unawaited(_refreshLoadedItems(requestSerial, loadedItems.length));
  }

  Future<void> _refreshLoadedItems(int requestSerial, int loadedCount) async {
    final pageRequest = _requests.begin(0);
    if (pageRequest == null) return;
    final currentItems = _controller.itemList;
    try {
      final page = await ref
          .read(audioRepositoryProvider)
          .listAssets(
            limit: loadedCount > _pageSize ? loadedCount : _pageSize,
            offset: 0,
            search: _search,
          );
      if (!pageRequest.isCurrent ||
          !mounted ||
          requestSerial != _requestSerial) {
        return;
      }
      if (!identical(currentItems, _controller.itemList)) {
        _refreshing = false;
        return;
      }

      final nextOffset = page.items.length;
      _refreshing = false;
      setState(() {
        _totalCount = page.total;
        _lastPageComplete = nextOffset >= page.total || page.items.isEmpty;
      });
      _controller.value = PagingState<int, AudioAsset>(
        itemList: page.items,
        error: null,
        nextPageKey: nextOffset >= page.total || page.items.isEmpty
            ? null
            : nextOffset,
      );
      _scrollRestorer.restoreAfterPage(_scrollController);
      _pruneSelection(page.items);
      // 新快照提交后，不允许旧偏移的翻页再追加。
      _requests.invalidate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestNextPageIfNeeded();
      });
    } catch (_) {
      if (!pageRequest.isCurrent ||
          !mounted ||
          requestSerial != _requestSerial) {
        return;
      }
      // 刷新失败时保留旧列表和当前交互状态，下一次刷新或分页请求可以重试。
      _refreshing = false;
    } finally {
      pageRequest.finish();
    }
  }

  Future<void> _refresh({bool preserveScroll = false}) {
    return _requests.refresh(() {
      _resetPaging(preserveScroll: preserveScroll);
    });
  }

  void _onSearchChanged(String value) {
    _debounce.run(() {
      if (!mounted) return;
      setState(() => _search = value.trim().isEmpty ? null : value.trim());
      _exitSelection();
      _reload();
    });
  }

  void _clearSearch() {
    _debounce.cancel();
    _searchController.clear();
    if (_search == null) return;
    setState(() => _search = null);
    _exitSelection();
    _reload();
  }

  // ============ 任务联动 ============

  /// 调度排队先于资产投影写入；按资产 ID 补齐等待状态，执行后使用行内进度。
  AudioAsset _assetWithTaskState(AudioAsset asset, List<TaskItem> tasks) {
    final transcription = asset.transcriptionView;
    final task = tasks
        .where(
          (task) =>
              task.taskType == 'subtitle_transcription' &&
              (task.audioAssetIds.contains(asset.id) ||
                  (transcription.taskId.isNotEmpty &&
                      task.id == transcription.taskId)),
        )
        .firstOrNull;
    if (task == null) return asset;
    if ((task.status != 'queued' || transcription.isActive) &&
        transcription.taskId == task.id &&
        transcription.status.isNotEmpty) {
      return asset;
    }
    // 批量任务完成不代表每个音频转译成功，终态完成仍以资产投影为准。
    if (!task.isActive && !task.isFailed && !task.isCanceled) return asset;
    return asset.withTranscription(
      AudioTranscription(
        taskId: task.id,
        status: task.status,
        stage: task.status == 'queued' ? 'queued' : '',
        message: task.message,
        errorMessage: task.isFailed ? task.message : '',
      ),
    );
  }

  /// WebSocket 中正在转译的影片集合：当前页之外的资产也据此禁用选择与入队。
  Set<int> _activeTranscriptionMovieIds() {
    final ids = <int>{};
    final assetIds = <int>{};
    for (final task in ref.read(taskCenterProvider)) {
      if (task.taskType == 'subtitle_transcription' && task.isActive) {
        if (task.movieId > 0) ids.add(task.movieId);
        assetIds.addAll(task.audioAssetIds);
      }
    }
    for (final asset in _controller.itemList ?? const <AudioAsset>[]) {
      if (assetIds.contains(asset.id) && asset.movieId > 0) {
        ids.add(asset.movieId);
      }
    }
    return ids;
  }

  bool _isAssetLocked(AudioAsset asset, Set<int> activeMovies) {
    if (_assetWithTaskState(
      asset,
      ref.read(taskCenterProvider),
    ).isTranscriptionActive) {
      return true;
    }
    return asset.movieId > 0 && activeMovies.contains(asset.movieId);
  }

  /// 单个资产可用的左滑操作。
  List<SwipeActionData> _assetSwipeActions(
    AppColors c,
    AudioAsset asset,
    bool transcriptionEnabled,
    bool locked,
  ) {
    final t = asset.transcriptionView;
    final actions = <SwipeActionData>[];
    if (asset.isTranscriptionActive && t.taskId.isNotEmpty) {
      actions.add(
        SwipeActionData(
          icon: Icons.stop_rounded,
          label: AppL10n.of(context).audioActionCancelTranscription,
          color: c.danger,
          onPressed: () => _cancelTranscription(asset),
        ),
      );
    } else if ((t.isFailed || t.isCanceled) && t.taskId.isNotEmpty && !locked) {
      actions.add(
        SwipeActionData(
          icon: Icons.refresh_rounded,
          label: AppL10n.of(context).audioActionRetryTranscription,
          color: c.warning,
          onPressed: () => _retryTranscription(asset),
        ),
      );
    } else if (transcriptionEnabled && asset.fileExists && !locked) {
      actions.add(
        SwipeActionData(
          icon: Icons.cloud_upload_outlined,
          label: AppL10n.of(context).audioActionEnqueueTranscription,
          color: c.accent,
          onPressed: () => _enqueueTranscriptions([asset]),
        ),
      );
    }
    if (!asset.isTranscriptionActive && !locked) {
      actions.add(
        SwipeActionData(
          icon: Icons.delete_outline_rounded,
          label: AppL10n.of(context).delete,
          color: c.danger,
          onPressed: () => _deleteAssets([asset]),
        ),
      );
    }
    return actions;
  }

  /// 转译信息内嵌在资产行上，音频提取/字幕转译任务有状态或进度变化时
  /// 防抖刷新列表，同步行内转译进度。
  void _scheduleTaskDrivenReload(List<TaskItem> tasks) {
    final signature = tasks
        .where(
          (task) =>
              task.taskType == 'audio_extract' ||
              task.taskType == 'subtitle_transcription',
        )
        .map(
          (task) =>
              '${task.id}:${task.status}:${(task.progress.clampedPercent / 5).round()}',
        )
        .join('|');
    if (signature == _lastTaskSignature) return;
    _lastTaskSignature = signature;
    if (signature.isEmpty) return;

    _taskReloadDebounce?.cancel();
    _taskReloadDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _reload(preserveScroll: true);
    });
  }

  // ============ 多选 ============

  bool _isSelectableId(int id) {
    final loaded = _controller.itemList ?? const <AudioAsset>[];
    final asset = loaded.where((item) => item.id == id).firstOrNull;
    if (asset == null) return false;
    return !_isAssetLocked(asset, _activeTranscriptionMovieIds());
  }

  void _startSelectionSweep(int id, bool selected) {
    if (selected && !_isSelectableId(id)) return;
    _selection.startSweep(id, selected);
  }

  void _applySelectionSweep(int id, bool selected) {
    if (selected && !_isSelectableId(id)) return;
    _selection.applySweep(id, selected);
  }

  void _finishSelectionSweep() {
    if (_selectionMode && _selectedIds.isEmpty) _exitSelection();
  }

  void _toggleSelect(int id) {
    if (!_selectedIds.contains(id) && !_isSelectableId(id)) return;
    _selection.toggle(id);
  }

  void _exitSelection() => _selection.exit();

  void _selectAllLoaded() {
    final loaded = _controller.itemList ?? const <AudioAsset>[];
    final activeMovies = _activeTranscriptionMovieIds();
    _selection.selectAll(
      loaded
          .where((asset) => !_isAssetLocked(asset, activeMovies))
          .map((asset) => asset.id),
    );
  }

  List<AudioAsset> _selectedItems() {
    final loaded = _controller.itemList ?? const <AudioAsset>[];
    return loaded
        .where(
          (item) => _selectedIds.contains(item.id) && _isSelectableId(item.id),
        )
        .toList();
  }

  // ============ 操作 ============

  Future<void> _cancelExtraction(TaskItem task) async {
    if (!_busyTaskIds.add(task.id)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await ref
          .read(audioRepositoryProvider)
          .cancelExtraction(task.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              message ?? AppL10n.of(context).audioCancelExtractionSubmitted,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).audioCancelExtractionFailed(
                localizedErrorMessage(AppL10n.of(context), error),
              ),
            ),
          ),
        );
      }
    } finally {
      _busyTaskIds.remove(task.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _cancelTranscription(AudioAsset asset) async {
    final taskId = asset.transcriptionTaskId;
    if (taskId.isEmpty) return;
    if (!_busyAssetIds.add(asset.id)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await ref
          .read(audioRepositoryProvider)
          .cancelTranscription(taskId);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message ?? AppL10n.of(context).audioCancelSubmitted),
          ),
        );
        _reload(preserveScroll: true);
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).audioCancelTranscriptionFailed(
                localizedErrorMessage(AppL10n.of(context), error),
              ),
            ),
          ),
        );
      }
    } finally {
      _busyAssetIds.remove(asset.id);
      if (mounted) setState(() {});
    }
  }

  /// 新建单个或批量转译时，让用户选择是否覆盖已有同名字幕。
  Future<void> _enqueueTranscriptions(List<AudioAsset> assets) async {
    if (assets.isEmpty || _busyAssetIds.isNotEmpty) return;
    assets = assets.where((asset) => _isSelectableId(asset.id)).toList();
    if (assets.isEmpty) return;
    final repository = ref.read(audioRepositoryProvider);
    final l = AppL10n.of(context);
    final overwrite = await _showTranscriptionSheet(
      title: assets.length == 1
          ? l.audioEnqueueTitle
          : l.audioEnqueueBatchTitle,
      message: assets.length == 1
          ? l.audioEnqueueMessageSingle(assets.first.displayTitle)
          : l.audioEnqueueMessageBatch(assets.length),
      confirmLabel: l.audioEnqueueConfirm,
    );
    if (overwrite == null || !mounted) return;
    if (!identical(repository, ref.read(audioRepositoryProvider))) return;

    assets = assets.where((asset) => _isSelectableId(asset.id)).toList();
    if (assets.isEmpty || _busyAssetIds.isNotEmpty) return;
    final ids = assets.map((asset) => asset.id).toList();
    if (!_busyAssetIds.add(ids.first)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await repository.enqueueTranscriptions(
        ids,
        overwrite: overwrite,
      );
      if (!mounted) return;
      if (!identical(repository, ref.read(audioRepositoryProvider))) return;
      if (result.task case final task? when task.id.isNotEmpty) {
        ref.read(taskCenterProvider.notifier).restore(task);
      }
      AppHaptics.medium();
      final rejected = result.rejected.isNotEmpty
          ? result.rejected.first.message
          : '';
      if (rejected.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? l.audioEnqueuedMixed(result.accepted, rejected),
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message ?? l.audioEnqueued(result.accepted)),
          ),
        );
      }
      _exitSelection();
      _reload(preserveScroll: true);
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).audioEnqueueFailed(
                localizedErrorMessage(AppL10n.of(context), error),
              ),
            ),
          ),
        );
      }
    } finally {
      _busyAssetIds.remove(ids.first);
      if (mounted) setState(() {});
    }
  }

  Future<void> _retryTranscription(AudioAsset asset) async {
    if (!_isSelectableId(asset.id)) return;
    final taskId = asset.transcriptionTaskId;
    if (taskId.isEmpty) return;
    if (!_busyAssetIds.add(asset.id)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await ref
          .read(audioRepositoryProvider)
          .retryTranscription(taskId);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(message ?? AppL10n.of(context).audioRequeued)),
        );
        _reload(preserveScroll: true);
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).audioRetryFailed(
                localizedErrorMessage(AppL10n.of(context), error),
              ),
            ),
          ),
        );
      }
    } finally {
      _busyAssetIds.remove(asset.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteAssets(List<AudioAsset> assets) async {
    if (assets.isEmpty || _busyAssetIds.isNotEmpty) return;
    final single = assets.length == 1;
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(single ? l.audioDeleteTitle : l.audioDeleteBatchTitle),
        content: Text(
          single
              ? l.audioDeleteMessageSingle(assets.first.displayTitle)
              : l.audioDeleteMessageBatch(assets.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: appColors(ctx).danger,
              foregroundColor: Colors.white,
            ),
            child: Text(single ? l.delete : l.audioDeleteBatchAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ids = assets.map((asset) => asset.id).toList();
    if (!_busyAssetIds.add(ids.first)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(audioRepositoryProvider).deleteAssets(ids);
      if (!mounted) return;
      AppHaptics.medium();
      final rejected = result.rejected.isNotEmpty
          ? result.rejected.first.message
          : '';
      if (rejected.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.message ??
                  l.audioDeleteResult(result.deleted.length, rejected),
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? l.audioDeleted(result.deleted.length),
            ),
          ),
        );
      }
      _exitSelection();
      _reload(preserveScroll: true);
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).audioDeleteFailed(
                localizedErrorMessage(AppL10n.of(context), error),
              ),
            ),
          ),
        );
      }
    } finally {
      _busyAssetIds.remove(ids.first);
      if (mounted) setState(() {});
    }
  }

  Widget _buildExtractionTaskRow(
    TaskItem task, {
    required BorderRadius borderRadius,
    required bool showDivider,
  }) {
    final c = appColors(context);
    final busy = _busyTaskIds.contains(task.id);
    return Column(
      key: ValueKey<String>('audio-extraction-row-${task.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SwipeActionCell(
          key: ValueKey('audio-task-${task.id}'),
          actionBorderRadius: borderRadius,
          group: _openSwipe,
          cellKey: 'task:${task.id}',
          enabled: !_selectionMode && !busy,
          actions: [
            SwipeActionData(
              icon: Icons.stop_rounded,
              label: AppL10n.of(context).audioActionCancelExtraction,
              color: c.danger,
              onPressed: () => _cancelExtraction(task),
            ),
          ],
          child: _ExtractionTaskCard(task: task, borderRadius: borderRadius),
        ),
        if (showDivider) Divider(height: 1, color: c.divider),
      ],
    );
  }

  void _openMovieDetail(AudioAsset asset) {
    if (asset.movieId <= 0) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieDetailPage(movieId: asset.movieId),
      ),
    );
  }

  /// 返回 null 表示取消，否则返回是否覆盖已有同名字幕。
  Future<bool?> _showTranscriptionSheet({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    var overwrite = false;
    final c = appColors(context);
    return showGlassSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SheetHeader(
                  icon: Icons.subtitles_outlined,
                  title: title,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 14),
                Text(message, style: AppText.meta(sheetContext)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: settingsCardDecoration(sheetContext),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppL10n.of(
                            sheetContext,
                          ).audioOverwriteExistingSubtitle,
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      SettingsSwitch(
                        value: overwrite,
                        onChanged: (value) =>
                            setSheetState(() => overwrite = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: sheetSecondaryButtonStyle(sheetContext),
                        child: Text(AppL10n.of(sheetContext).cancel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, overwrite),
                        style: sheetPrimaryButtonStyle(sheetContext),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============ 构建 ============

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final tasks = ref.watch(taskCenterProvider);
    final extractionSearch = _search?.trim().toLowerCase();
    final extractionTasks = tasks
        .where(
          (task) =>
              task.taskType == 'audio_extract' &&
              task.isActive &&
              (extractionSearch == null ||
                  '${task.movieTitle} ${task.movieFileName} ${task.fileName} ${task.movieId}'
                      .toLowerCase()
                      .contains(extractionSearch)),
        )
        .toList();
    final activeMovies = _activeTranscriptionMovieIds();
    final transcriptionEnabled = ref
        .watch(modalTranscriptionConfigProvider)
        .when(
          data: (config) => config.enabled,
          loading: () => false,
          error: (_, __) => false,
        );

    // 转译/提取进度通过 WS 高频推送，防抖后刷新列表同步行内进度。
    ref.listen<List<TaskItem>>(taskCenterProvider, (previous, next) {
      _scheduleTaskDrivenReload(next);
      _pruneSelection(_controller.itemList ?? const <AudioAsset>[]);
    });

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          bottom: false,
          child: PopScope(
            canPop: !_selectionMode,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && _selectionMode) _exitSelection();
            },
            child: Stack(
              children: [
                SettingsFixedHeaderLayout(
                  scrollController: _scrollController,
                  header: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SettingsSubPageHeader(
                        eyebrow: l.audioEyebrow,
                        bottomPadding: PageHeader.toolbarTopGap,
                        title: l.settingsAudioManagement,
                        count: _controller.itemList == null
                            ? null
                            : _totalCount,
                        countSuffix: l.audioAssetCountSuffix,
                        subtitle: _search == null
                            ? null
                            : l.audioSearchSubtitle(_search!),
                      ),
                      // 搜索栏固定在头部，不随列表滚动。
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          22,
                          0,
                          22,
                          PageHeader.aboveListGap,
                        ),
                        child: _SearchField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onClear: _clearSearch,
                        ),
                      ),
                    ],
                  ),
                  body: RefreshIndicator(
                    color: c.accent,
                    onRefresh: _refresh,
                    child: DragSelectionScope<int>(
                      scrollController: _scrollController,
                      selectionLayout: DragSelectionLayout.list,
                      isSelected: _selection.contains,
                      onSelectionStart: _startSelectionSweep,
                      onSelectionChanged: _applySelectionSweep,
                      onSelectionEnd: _finishSelectionSweep,
                      selectionMode: _selectionMode,
                      child: CustomScrollView(
                        controller: _scrollController,
                        primary: false,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          ValueListenableBuilder<PagingState<int, AudioAsset>>(
                            valueListenable: _controller,
                            builder: (context, paging, _) {
                              final items = paging.itemList;
                              final assets = items ?? const <AudioAsset>[];
                              final extractionCount = extractionTasks.length;
                              final rowCount = extractionCount + assets.length;
                              final padding = EdgeInsets.fromLTRB(
                                22,
                                MediaListLayout.contentTopInset,
                                22,
                                _selectionMode ? 136 : 80,
                              );
                              if (rowCount == 0 && items == null) {
                                return SliverPadding(
                                  padding: padding,
                                  sliver: SliverToBoxAdapter(
                                    child: paging.error == null
                                        ? const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(32),
                                              child:
                                                  CupertinoActivityIndicator(),
                                            ),
                                          )
                                        : ErrorView(
                                            message: localizedErrorMessage(
                                              l,
                                              paging.error,
                                            ),
                                            onRetry: _reload,
                                          ),
                                  ),
                                );
                              }
                              if (rowCount == 0) {
                                return SliverPadding(
                                  padding: padding,
                                  sliver: SliverToBoxAdapter(
                                    child: paging.error == null
                                        ? _EmptyState(
                                            searching: _search != null,
                                          )
                                        : ErrorView(
                                            message: localizedErrorMessage(
                                              l,
                                              paging.error,
                                            ),
                                            onRetry: _reload,
                                          ),
                                  ),
                                );
                              }

                              final childIndices = <Key, int>{
                                for (var i = 0; i < extractionCount; i++)
                                  ValueKey<String>(
                                    'audio-extraction-row-${extractionTasks[i].id}',
                                  ): i,
                                for (var i = 0; i < assets.length; i++)
                                  ValueKey<String>(
                                    'audio-asset-row-${assets[i].id}',
                                  ): extractionCount + i,
                              };

                              return SliverPadding(
                                padding: padding,
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      if (index == rowCount) {
                                        if (items == null) {
                                          return paging.error == null
                                              ? const Padding(
                                                  padding: EdgeInsets.all(20),
                                                  child: Center(
                                                    child:
                                                        CupertinoActivityIndicator(),
                                                  ),
                                                )
                                              : ErrorView(
                                                  message:
                                                      localizedErrorMessage(
                                                        l,
                                                        paging.error,
                                                      ),
                                                  onRetry: _reload,
                                                );
                                        }
                                        if (assets.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        if (paging.nextPageKey == null) {
                                          return const NoMoreContent();
                                        }
                                        if (paging.error != null) {
                                          return PaginationRetry(
                                            onRetry: _retryNextPage,
                                          );
                                        }
                                        return _loadingPageSerial ==
                                                _requestSerial
                                            ? const Padding(
                                                padding: EdgeInsets.all(20),
                                                child: Center(
                                                  child:
                                                      CupertinoActivityIndicator(),
                                                ),
                                              )
                                            : const SizedBox.shrink();
                                      }

                                      final rowRadius = BorderRadius.vertical(
                                        top: index == 0
                                            ? const Radius.circular(16)
                                            : Radius.zero,
                                        bottom:
                                            _lastPageComplete &&
                                                index == rowCount - 1
                                            ? const Radius.circular(16)
                                            : Radius.zero,
                                      );
                                      if (index < extractionCount) {
                                        final task = extractionTasks[index];
                                        return _buildExtractionTaskRow(
                                          task,
                                          borderRadius: rowRadius,
                                          showDivider: index < rowCount - 1,
                                        );
                                      }

                                      final assetIndex =
                                          index - extractionCount;
                                      final asset = _assetWithTaskState(
                                        assets[assetIndex],
                                        tasks,
                                      );
                                      final locked = _isAssetLocked(
                                        asset,
                                        activeMovies,
                                      );
                                      return Column(
                                        key: ValueKey<String>(
                                          'audio-asset-row-${asset.id}',
                                        ),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SwipeActionCell(
                                            key: ValueKey(
                                              'audio-asset-${asset.id}',
                                            ),
                                            actionBorderRadius: rowRadius,
                                            group: _openSwipe,
                                            cellKey: asset.id,
                                            enabled:
                                                !_selectionMode &&
                                                !_busyAssetIds.contains(
                                                  asset.id,
                                                ),
                                            actions: _assetSwipeActions(
                                              c,
                                              asset,
                                              transcriptionEnabled,
                                              locked,
                                            ),
                                            child: DragSelectionTarget<int>(
                                              id: asset.id,
                                              selectionIndex: assetIndex,
                                              selectionHandleAlignment:
                                                  Alignment.centerLeft,
                                              child:
                                                  ValueListenableBuilder<
                                                    Set<Object>
                                                  >(
                                                    valueListenable: _selection
                                                        .selectedListenable,
                                                    builder:
                                                        (
                                                          context,
                                                          selected,
                                                          _,
                                                        ) => _AssetCard(
                                                          asset: asset,
                                                          selected: selected
                                                              .contains(
                                                                asset.id,
                                                              ),
                                                          selecting:
                                                              _selectionMode,
                                                          locked: locked,
                                                          borderRadius:
                                                              rowRadius,
                                                          onToggleSelect: () =>
                                                              _toggleSelect(
                                                                asset.id,
                                                              ),
                                                          onOpenMovie: () =>
                                                              _openMovieDetail(
                                                                asset,
                                                              ),
                                                        ),
                                                  ),
                                            ),
                                          ),
                                          if (index < rowCount - 1)
                                            Divider(
                                              height: 1,
                                              color: c.divider,
                                            ),
                                        ],
                                      );
                                    },
                                    childCount: rowCount + 1,
                                    findChildIndexCallback: (key) =>
                                        childIndices[key],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectionMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ValueListenableBuilder<Set<Object>>(
                      valueListenable: _selection.selectedListenable,
                      builder: (context, selected, _) => EntityBatchToolbar(
                        selectedCount: selected.length,
                        onSelectAll: _selectAllLoaded,
                        onClear: _exitSelection,
                        onClose: _exitSelection,
                        actions: [
                          if (transcriptionEnabled)
                            EntityBatchAction(
                              icon: Icons.cloud_upload_outlined,
                              label: l.audioActionEnqueueTranscription,
                              onTap: _busyAssetIds.isEmpty
                                  ? () =>
                                        _enqueueTranscriptions(_selectedItems())
                                  : null,
                            ),
                          EntityBatchAction(
                            icon: Icons.delete_outline,
                            label: l.audioActionDeleteAudio,
                            color: c.danger,
                            onTap: _busyAssetIds.isEmpty
                                ? () => _deleteAssets(_selectedItems())
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ 搜索栏 ============
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search, size: 18, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textAlignVertical: TextAlignVertical.center,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: AppL10n.of(context).audioSearchHint,
                hintStyle: TextStyle(
                  color: c.muted,
                  fontWeight: FontWeight.w500,
                ),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
              ),
              style: TextStyle(color: c.text, fontWeight: FontWeight.w500),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, size: 16, color: c.muted),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

// ============ 提取中任务卡 ============
class _ExtractionTaskCard extends StatelessWidget {
  const _ExtractionTaskCard({required this.task, required this.borderRadius});

  final TaskItem task;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final brightness = Theme.of(context).brightness;
    final color = AppHues.top(AppHues.lavender);
    final tint = AppHues.chipBg(AppHues.lavender, brightness);
    final percent = task.progress.clampedPercent / 100;
    final title = task.movieTitle;

    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: borderRadius),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.audiotrack_rounded, size: 21, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty
                            ? taskNameLabel(
                                AppL10n.of(context),
                                task.name,
                                taskType: task.taskType,
                              )
                            : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ),
                    Text(
                      '${task.progress.clampedPercent.toStringAsFixed(1)}%',
                      style: AppText.mono(context, size: 12, color: c.text),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                LinearProgressIndicator(
                  value: percent.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: c.divider,
                  color: color,
                ),
                const SizedBox(height: 8),
                Text(
                  task.status == 'idle'
                      ? AppL10n.of(context).audioTaskQueued
                      : AppL10n.of(context).audioTaskExtracting,
                  style: TextStyle(
                    color: c.muted,
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 资产卡 ============
class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.selected,
    required this.selecting,
    required this.locked,
    required this.borderRadius,
    required this.onToggleSelect,
    required this.onOpenMovie,
  });

  final AudioAsset asset;
  final bool selected;
  final bool selecting;
  final bool locked;
  final BorderRadius borderRadius;
  final VoidCallback onToggleSelect;
  final VoidCallback onOpenMovie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final transcription = asset.transcriptionView;
    final status = _statusInfo(context, c);
    final extracting = asset.isTranscriptionActive;

    final inner = Container(
      // 分组连排行：无独立边框，选中以整行背景提示。
      decoration: BoxDecoration(
        color: selected ? c.accent.withValues(alpha: 0.07) : c.surface,
        borderRadius: borderRadius,
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(c, status),
          const SizedBox(height: 8),
          _buildSpecs(context, c),
          if (extracting ||
              transcription.isFailed ||
              transcription.isCanceled) ...[
            const SizedBox(height: 10),
            _buildTranscriptionSection(context, c, transcription),
          ],
        ],
      ),
    );

    // 多选模式下整卡点击切换勾选；平时点整卡跳影片详情。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: selecting
          ? (locked ? null : onToggleSelect)
          : (asset.movieId > 0 ? onOpenMovie : null),
      child: inner,
    );
  }

  Widget _buildHeader(AppColors c, _StatusInfo status) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (selecting) ...[
          _SelectionMark(
            selected: selected,
            enabled: !locked,
            onTap: locked ? null : onToggleSelect,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(child: _buildTitle(c)),
        if (!selecting) ...[
          const SizedBox(width: 8),
          StatusPill(
            label: status.label,
            color: status.color,
            showDot: true,
            pulsing: status.pulsing,
          ),
        ],
      ],
    );
  }

  Widget _buildTitle(AppColors c) {
    return Row(
      children: [
        Expanded(
          child: Text(
            asset.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.text,
              fontFamily: 'Inter',
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.2,
            ),
          ),
        ),
        if (asset.movieId > 0 && !selecting)
          Icon(Icons.chevron_right_rounded, size: 16, color: c.muted2),
      ],
    );
  }

  Widget _buildSpecs(BuildContext context, AppColors c) {
    final brightness = Theme.of(context).brightness;
    final l = AppL10n.of(context);
    final specs = <(String, int)>[
      (asset.formatLabel, AppHues.lavender),
      if (asset.bitrateKbps > 0) ('${asset.bitrateKbps} kbps', AppHues.sky),
      (_formatBytes(asset.fileSize), AppHues.mint),
      (_formatDuration(asset.durationSec), AppHues.solar),
      if (!asset.fileExists) (l.audioFileMissing, AppHues.coral),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (text, hue) in specs)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: hue == AppHues.coral
                  ? c.danger.withValues(alpha: 0.12)
                  : AppHues.chipBg(hue, brightness),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hue == AppHues.coral
                    ? c.danger.withValues(alpha: 0.35)
                    : AppHues.chipBorder(hue),
              ),
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hue == AppHues.coral
                    ? c.danger
                    : AppHues.chipText(hue, brightness),
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
      ],
    );
  }

  _StatusInfo _statusInfo(BuildContext context, AppColors c) {
    final l = AppL10n.of(context);
    final transcription = asset.transcriptionView;
    if (asset.isTranscriptionActive) {
      return _StatusInfo(
        _transcriptionStageLabel(l, transcription),
        c.warning,
        pulsing: true,
      );
    }
    if (transcription.isFailed) {
      return _StatusInfo(l.audioStatusFailed, c.danger);
    }
    if (transcription.isCanceled) {
      return _StatusInfo(l.audioStatusCanceled, c.muted);
    }
    if (asset.isTranscriptionDone) {
      return _StatusInfo(l.audioStatusTranscribed, AppHues.top(AppHues.mint));
    }
    if (!asset.fileExists) return _StatusInfo(l.audioFileMissing, c.danger);
    return _StatusInfo(l.audioStatusNotTranscribed, c.muted2);
  }

  Widget _buildTranscriptionSection(
    BuildContext context,
    AppColors c,
    AudioTranscription t,
  ) {
    if (asset.isTranscriptionActive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.message.isNotEmpty
                      ? t.message
                      : _transcriptionStageLabel(AppL10n.of(context), t),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.muted,
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${t.clampedPercent}%',
                style: AppText.mono(context, size: 11, color: c.text),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (t.clampedPercent / 100).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: c.divider,
            color: AppHues.top(AppHues.sky),
          ),
        ],
      );
    }
    if (t.isFailed && t.errorMessage.isNotEmpty) {
      return Text(
        t.errorMessage,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c.danger,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      );
    }
    if (t.isCanceled) {
      return Text(
        AppL10n.of(context).audioTranscriptionCanceledHint,
        style: TextStyle(
          color: c.muted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ============ 多选勾选框 ============
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected && enabled ? c.accent : Colors.transparent,
          border: Border.all(
            color: selected && enabled ? c.accent : c.muted2,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: selected && enabled
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : null,
      ),
    );
  }
}

// ============ 状态标识 ============
class _StatusInfo {
  const _StatusInfo(this.label, this.color, {this.pulsing = false});

  final String label;
  final Color color;
  final bool pulsing;
}

// ============ 空态 ============
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 48),
      decoration: settingsCardDecoration(context),
      child: Column(
        children: [
          Icon(Icons.graphic_eq_rounded, size: 38, color: c.muted),
          const SizedBox(height: 12),
          Text(
            searching
                ? AppL10n.of(context).audioEmptySearchTitle
                : AppL10n.of(context).audioEmptyTitle,
            style: TextStyle(
              color: c.text,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            searching
                ? AppL10n.of(context).audioEmptySearchHint
                : AppL10n.of(context).audioEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// ============ 格式化 ============
String _formatBytes(int bytes) {
  if (bytes <= 0) return '-';
  final value = bytes.toDouble();
  if (value < 1024) return '${value.round()} B';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  if (value < 1024 * 1024 * 1024) {
    return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(value / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String _formatDuration(double seconds) {
  final value = (seconds > 0 ? seconds : 0).round();
  if (value <= 0) return '-';
  final hours = value ~/ 3600;
  final minutes = (value % 3600) ~/ 60;
  final remaining = value % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}
