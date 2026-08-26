import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/drag_selection.dart';
import '../../shared/entity_batch_toolbar.dart';
import '../../shared/error_view.dart';
import '../../shared/glow_background.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../../shared/pagination_footer.dart';
import '../../shared/status_pill.dart';
import '../../shared/debouncer.dart';
import '../../shared/swipe_actions.dart';
import '../movie_detail/movie_detail_page.dart';
import '../settings/settings_common.dart';
import '../tasks/task_center_provider.dart';
import '../tasks/task_model.dart';
import '../translation/modal_transcription_providers.dart';
import 'audio_models.dart';
import 'audio_providers.dart';

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
  final _controller = PagingController<int, AudioAsset>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<AudioAsset>(
    _controller,
  );

  final _debounce = Debouncer();
  Timer? _taskReloadDebounce;
  String? _search;
  String _lastTaskSignature = '';
  bool _lastPageComplete = false;
  int _requestSerial = 0;
  int _totalCount = 0;
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};
  final Set<int> _busyAssetIds = <int>{};
  final Set<String> _busyTaskIds = <String>{};

  /// 当前左滑展开的行（资产 id 或 'task:$id'），同一时刻只展开一个。
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  Completer<void>? _refreshCompleter;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
    _scrollController.addListener(_closeSwipeOnScroll);
  }

  @override
  void dispose() {
    _completeRefresh();
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _taskReloadDebounce?.cancel();
    _debounce.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
  }

  Future<void> _fetch(int offset) async {
    // 刷新已有列表时保留旧数据，避免列表组件触发额外的后续分页请求。
    if (_refreshing && offset != 0) return;
    final requestSerial = _requestSerial;
    try {
      final page = await ref
          .read(audioRepositoryProvider)
          .listAssets(limit: _pageSize, offset: offset, search: _search);
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
      setState(() => _lastPageComplete = !hasMore);
      _pruneSelection(page.items);
      _completeRefresh();
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = toApiException(error).message;
      _refreshing = false;
      _completeRefresh();
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
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(keep);
        if (_selectedIds.isEmpty) _selectionMode = false;
      });
    }
  }

  void _reload({bool preserveScroll = false}) {
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
      _controller.refresh();
      return;
    }

    // 已有内容时不清空分页控制器，让刷新请求在后台完成，避免首屏加载态
    // 替换当前列表造成闪烁，也避免滚动中的行被卸载而中断用户操作。
    unawaited(_refreshLoadedItems(requestSerial, loadedItems.length));
  }

  Future<void> _refreshLoadedItems(int requestSerial, int loadedCount) async {
    try {
      final page = await ref
          .read(audioRepositoryProvider)
          .listAssets(
            limit: loadedCount > _pageSize ? loadedCount : _pageSize,
            offset: 0,
            search: _search,
          );
      if (!mounted || requestSerial != _requestSerial) return;

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
      _completeRefresh();
    } catch (_) {
      if (!mounted || requestSerial != _requestSerial) return;
      // 刷新失败时保留旧列表和当前交互状态，下一次刷新或分页请求可以重试。
      _refreshing = false;
      _completeRefresh();
    }
  }

  Future<void> _refresh() {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _refreshCompleter = completer;
    _reload();
    return completer.future;
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
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

  /// WebSocket 中正在转译的影片集合：当前页之外的资产也据此禁用选择与入队。
  Set<int> _activeTranscriptionMovieIds() {
    final ids = <int>{};
    for (final task in ref.read(taskCenterProvider)) {
      if (task.name == '字幕转译' &&
          (task.status == 'queued' || task.status == 'running') &&
          task.movieId > 0) {
        ids.add(task.movieId);
      }
    }
    return ids;
  }

  bool _isAssetLocked(AudioAsset asset, Set<int> activeMovies) {
    if (asset.isTranscriptionActive) return true;
    return asset.movieId > 0 && activeMovies.contains(asset.movieId);
  }

  /// 单个资产的左滑操作集：无可用操作时返回空列表（禁用滑动）。
  List<SwipeActionData> _assetSwipeActions(
    AppColors c,
    AudioAsset asset,
    bool transcriptionEnabled,
    bool locked,
  ) {
    final t = asset.transcriptionView;
    final actions = <SwipeActionData>[];
    if (asset.isTranscriptionActive) {
      actions.add(
        SwipeActionData(
          icon: Icons.stop_rounded,
          label: '取消转译',
          color: c.danger,
          onPressed: () => _cancelTranscription(asset),
        ),
      );
    } else if (t.isFailed || t.isCanceled) {
      actions.add(
        SwipeActionData(
          icon: Icons.refresh_rounded,
          label: '重新转译',
          color: c.warning,
          onPressed: () => _retryTranscription(asset),
        ),
      );
    } else if (transcriptionEnabled && asset.fileExists && !locked) {
      actions.add(
        SwipeActionData(
          icon: Icons.cloud_upload_outlined,
          label: '加入转译',
          color: c.accent,
          onPressed: () => _enqueueTranscriptions([asset]),
        ),
      );
    }
    if (!asset.isTranscriptionActive && !locked) {
      actions.add(
        SwipeActionData(
          icon: Icons.delete_outline_rounded,
          label: '删除',
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
        .where((task) => task.name == '音频提取' || task.name == '字幕转译')
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
    setState(() {
      _selectionMode = true;
      _setSelectionValue(id, selected);
    });
  }

  void _applySelectionSweep(int id, bool selected) {
    if (_selectedIds.contains(id) == selected) return;
    if (selected && !_isSelectableId(id)) return;
    setState(() => _setSelectionValue(id, selected));
  }

  void _finishSelectionSweep() {
    if (_selectionMode && _selectedIds.isEmpty) _exitSelection();
  }

  void _setSelectionValue(int id, bool selected) {
    if (selected) {
      _selectedIds.add(id);
    } else {
      _selectedIds.remove(id);
    }
  }

  void _toggleSelect(int id) {
    if (!_selectedIds.contains(id) && !_isSelectableId(id)) return;
    setState(() {
      if (_selectedIds.remove(id)) {
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectionMode = true;
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() {
    if (!_selectionMode && _selectedIds.isEmpty) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAllLoaded() {
    final loaded = _controller.itemList ?? const <AudioAsset>[];
    final activeMovies = _activeTranscriptionMovieIds();
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(
          loaded
              .where((asset) => !_isAssetLocked(asset, activeMovies))
              .map((asset) => asset.id),
        );
    });
  }

  List<AudioAsset> _selectedItems() {
    final loaded = _controller.itemList ?? const <AudioAsset>[];
    return loaded.where((item) => _selectedIds.contains(item.id)).toList();
  }

  // ============ 操作 ============

  Future<void> _cancelExtraction(TaskItem task) async {
    if (!_busyTaskIds.add(task.id)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(audioRepositoryProvider).cancelExtraction(task.id);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('音频提取取消请求已提交')));
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('取消音频提取失败: ${toApiException(error).message}')),
        );
      }
    } finally {
      _busyTaskIds.remove(task.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _cancelTranscription(AudioAsset asset) async {
    if (!_busyAssetIds.add(asset.id)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(audioRepositoryProvider).cancelTranscription(asset.id);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('已提交取消请求')));
        _reload(preserveScroll: true);
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('取消转译失败: ${toApiException(error).message}')),
        );
      }
    } finally {
      _busyAssetIds.remove(asset.id);
      if (mounted) setState(() {});
    }
  }

  /// 单个/批量加入转译或失败重试前，让用户选择是否覆盖已有同名字幕。
  Future<void> _enqueueTranscriptions(List<AudioAsset> assets) async {
    if (assets.isEmpty || _busyAssetIds.isNotEmpty) return;
    final overwrite = await _showTranscriptionSheet(
      title: assets.length == 1 ? '加入字幕转译' : '批量加入字幕转译',
      message: assets.length == 1
          ? '将「${assets.first.displayTitle}」的音频加入云端转译队列。'
          : '将 ${assets.length} 个音频资产加入云端转译队列。',
      confirmLabel: '开始转译',
    );
    if (overwrite == null || !mounted) return;

    final ids = assets.map((asset) => asset.id).toList();
    if (!_busyAssetIds.add(ids.first)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(audioRepositoryProvider)
          .enqueueTranscriptions(ids, overwrite: overwrite);
      if (!mounted) return;
      AppHaptics.medium();
      final rejected = result.rejected.isNotEmpty
          ? result.rejected.first.message
          : '';
      if (rejected.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('已加入 ${result.accepted} 个任务 · $rejected')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('已加入 ${result.accepted} 个字幕转译任务')),
        );
      }
      _exitSelection();
      _reload(preserveScroll: true);
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('加入字幕转译队列失败: ${toApiException(error).message}'),
          ),
        );
      }
    } finally {
      _busyAssetIds.remove(ids.first);
      if (mounted) setState(() {});
    }
  }

  Future<void> _retryTranscription(AudioAsset asset) async {
    final overwrite = await _showTranscriptionSheet(
      title: '重新转译',
      message: '重新提交「${asset.displayTitle}」的字幕转译任务。',
      confirmLabel: '重新转译',
    );
    if (overwrite == null || !mounted) return;

    if (!_busyAssetIds.add(asset.id)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(audioRepositoryProvider)
          .retryTranscription(asset.id, overwrite: overwrite);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('任务已重新加入队列')));
        _reload(preserveScroll: true);
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('重新转译失败: ${toApiException(error).message}')),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(single ? '删除音频资产' : '批量删除音频资产'),
        content: Text(
          single
              ? '确定删除「${assets.first.fileName.isEmpty ? '该音频文件' : assets.first.fileName}」吗？\n音频文件与转译信息都会被删除，已生成的字幕不受影响。'
              : '确定删除选中的 ${assets.length} 个音频资产吗？\n音频文件与转译信息都会被删除，已生成的字幕不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: appColors(ctx).danger,
              foregroundColor: Colors.white,
            ),
            child: Text(single ? '删除' : '批量删除'),
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
            content: Text('删除完成：成功 ${result.deleted.length} 个，$rejected'),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('已删除 ${result.deleted.length} 个音频资产')),
        );
      }
      _exitSelection();
      _reload(preserveScroll: true);
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('删除音频资产失败: ${toApiException(error).message}')),
        );
      }
    } finally {
      _busyAssetIds.remove(ids.first);
      if (mounted) setState(() {});
    }
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
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: appColors(context).bg,
      showDragHandle: true,
      builder: (sheetContext) {
        final c = appColors(sheetContext);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.sectionTitle(sheetContext)),
                  const SizedBox(height: 6),
                  Text(message, style: AppText.meta(sheetContext)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: settingsCardDecoration(sheetContext),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '覆盖已有同名字幕',
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
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: c.text,
                            side: BorderSide(color: c.cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, overwrite),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: c.text,
                            foregroundColor: c.bg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
    final tasks = ref.watch(taskCenterProvider);
    final extractionTasks = tasks
        .where(
          (task) =>
              task.name == '音频提取' &&
              (task.status == 'idle' || task.status == 'running'),
        )
        .toList();
    final activeMovies = {
      for (final task in tasks)
        if (task.name == '字幕转译' &&
            (task.status == 'queued' || task.status == 'running') &&
            task.movieId > 0)
          task.movieId,
    };
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
    });

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: PopScope(
            canPop: !_selectionMode,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && _selectionMode) _exitSelection();
            },
            child: Stack(
              children: [
                SettingsFixedHeaderLayout(
                  scrollController: _scrollController,
                  header: SettingsSubPageHeader(
                    eyebrow: '媒体工具',
                    title: '音频管理',
                    titleTrailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$_totalCount', style: AppText.pageTitle(context)),
                        const SizedBox(width: 6),
                        Text('个音频资产', style: AppText.meta(context)),
                      ],
                    ),
                    subtitle: _search == null
                        ? '已提取的音频资产与字幕转译进度 · 提取请从影片详情页发起'
                        : '搜索“$_search”',
                  ),
                  body: RefreshIndicator(
                    color: c.accent,
                    onRefresh: _refresh,
                    child: DragSelectionScope<int>(
                      scrollController: _scrollController,
                      selectionLayout: DragSelectionLayout.list,
                      isSelected: _selectedIds.contains,
                      onSelectionStart: _startSelectionSweep,
                      onSelectionChanged: _applySelectionSweep,
                      onSelectionEnd: _finishSelectionSweep,
                      selectionMode: _selectionMode,
                      child: CustomScrollView(
                        controller: _scrollController,
                        primary: false,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                              child: _SearchField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                onClear: _clearSearch,
                              ),
                            ),
                          ),
                          if (extractionTasks.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  0,
                                  22,
                                  8,
                                ),
                                child: Text(
                                  '提取中  ·  ${extractionTasks.length}',
                                  style: AppText.eyebrow(context),
                                ),
                              ),
                            ),
                            // 提取任务少且有界：合并为设置页式分组卡，行间细分隔线。
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  0,
                                  22,
                                  14,
                                ),
                                child: Container(
                                  decoration: settingsCardDecoration(context),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Column(
                                      children: [
                                        for (
                                          var i = 0;
                                          i < extractionTasks.length;
                                          i++
                                        ) ...[
                                          if (i > 0)
                                            Divider(
                                              height: 1,
                                              color: c.divider,
                                            ),
                                          SwipeActionCell(
                                            group: _openSwipe,
                                            cellKey:
                                                'task:${extractionTasks[i].id}',
                                            enabled:
                                                !_selectionMode &&
                                                !_busyTaskIds.contains(
                                                  extractionTasks[i].id,
                                                ),
                                            actions: [
                                              SwipeActionData(
                                                icon: Icons.stop_rounded,
                                                label: '取消提取',
                                                color: c.danger,
                                                onPressed: () =>
                                                    _cancelExtraction(
                                                      extractionTasks[i],
                                                    ),
                                              ),
                                            ],
                                            child: _ExtractionTaskCard(
                                              task: extractionTasks[i],
                                              busy: _busyTaskIds.contains(
                                                extractionTasks[i].id,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              22,
                              0,
                              22,
                              _selectionMode ? 136 : 80,
                            ),
                            sliver: PagedSliverList<int, AudioAsset>.separated(
                              pagingController: _controller,
                              separatorBuilder: (_, itemIndex) {
                                // 分页组件在末项与状态页脚之间也会排一条
                                // 分隔线，末行底部圆角下会多出一条线，隐藏之。
                                final count = _controller.itemList?.length ?? 0;
                                return itemIndex >= count - 1
                                    ? const SizedBox.shrink()
                                    : Divider(height: 1, color: c.divider);
                              },
                              builderDelegate:
                                  PagedChildBuilderDelegate<AudioAsset>(
                                    itemBuilder: (ctx, asset, index) {
                                      final busy = _busyAssetIds.contains(
                                        asset.id,
                                      );
                                      final locked = _isAssetLocked(
                                        asset,
                                        activeMovies,
                                      );
                                      // 连排整条列表：首行圆上角、末行圆下角，
                                      // 操作块沿用同一圆角避免顶出行轮廓。
                                      final isLastRow =
                                          _lastPageComplete &&
                                          index ==
                                              (_controller.itemList?.length ??
                                                      0) -
                                                  1;
                                      final rowRadius = BorderRadius.vertical(
                                        top: index == 0
                                            ? const Radius.circular(16)
                                            : Radius.zero,
                                        bottom: isLastRow
                                            ? const Radius.circular(16)
                                            : Radius.zero,
                                      );
                                      return SwipeActionCell(
                                        actionBorderRadius: rowRadius,
                                        group: _openSwipe,
                                        cellKey: asset.id,
                                        enabled: !_selectionMode && !busy,
                                        actions: _assetSwipeActions(
                                          c,
                                          asset,
                                          transcriptionEnabled,
                                          locked,
                                        ),
                                        child: DragSelectionTarget<int>(
                                          key: ValueKey(asset.id),
                                          id: asset.id,
                                          selectionIndex: index,
                                          selectionHandleAlignment:
                                              Alignment.centerLeft,
                                          child: ClipRRect(
                                            borderRadius: rowRadius,
                                            child: _AssetCard(
                                              asset: asset,
                                              selected: _selectedIds.contains(
                                                asset.id,
                                              ),
                                              selecting: _selectionMode,
                                              locked: locked,
                                              busy: busy,
                                              onToggleSelect: () =>
                                                  _toggleSelect(asset.id),
                                              onOpenMovie: () =>
                                                  _openMovieDetail(asset),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    firstPageProgressIndicatorBuilder: (_) =>
                                        const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(32),
                                            child: CupertinoActivityIndicator(),
                                          ),
                                        ),
                                    firstPageErrorIndicatorBuilder: (_) =>
                                        ErrorView(
                                          message:
                                              _controller.error?.toString() ??
                                              '加载失败',
                                          onRetry: () => _controller.refresh(),
                                        ),
                                    noItemsFoundIndicatorBuilder: (_) =>
                                        _EmptyState(searching: _search != null),
                                    noMoreItemsIndicatorBuilder: (_) =>
                                        const NoMoreContent(),
                                  ),
                            ),
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
                    child: EntityBatchToolbar(
                      selectedCount: _selectedIds.length,
                      onSelectAll: _selectAllLoaded,
                      onClear: _exitSelection,
                      onClose: _exitSelection,
                      actions: [
                        if (transcriptionEnabled)
                          EntityBatchAction(
                            icon: Icons.cloud_upload_outlined,
                            label: '加入转译',
                            onTap: _busyAssetIds.isEmpty
                                ? () => _enqueueTranscriptions(_selectedItems())
                                : null,
                          ),
                        EntityBatchAction(
                          icon: Icons.delete_outline,
                          label: '删除音频',
                          color: c.danger,
                          onTap: _busyAssetIds.isEmpty
                              ? () => _deleteAssets(_selectedItems())
                              : null,
                        ),
                      ],
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
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: '搜索影片或音频文件...',
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
  const _ExtractionTaskCard({required this.task, this.busy = false});

  final TaskItem task;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final brightness = Theme.of(context).brightness;
    final color = AppHues.top(AppHues.lavender);
    final tint = AppHues.chipBg(AppHues.lavender, brightness);
    final percent = task.progress.clampedPercent / 100;
    final title = task.movieTitle.isNotEmpty
        ? task.movieTitle
        : task.movieFileName.isNotEmpty
        ? task.movieFileName
        : task.fileName;

    return AnimatedOpacity(
      opacity: busy ? 0.55 : 1,
      duration: const Duration(milliseconds: 180),
      child: Padding(
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
                          title.isEmpty ? '音频提取' : title,
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: c.divider,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.status == 'idle' ? '排队等待执行' : '正在提取音频…',
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
    required this.busy,
    required this.onToggleSelect,
    required this.onOpenMovie,
  });

  final AudioAsset asset;
  final bool selected;
  final bool selecting;
  final bool locked;
  final bool busy;
  final VoidCallback onToggleSelect;
  final VoidCallback onOpenMovie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final transcription = asset.transcriptionView;
    final status = _statusInfo(c);
    final extracting = asset.isTranscriptionActive;

    final inner = AnimatedOpacity(
      opacity: busy ? 0.55 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        // 分组连排行：无独立边框，选中以整行背景提示。
        color: selected ? c.accent.withValues(alpha: 0.07) : c.surface,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(c, status),
            const SizedBox(height: 6),
            Text(
              asset.fileName.isEmpty ? '-' : asset.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(context, size: 10.5, color: c.muted),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        if (asset.movieFileName.isNotEmpty && asset.movieTitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            asset.movieFileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.muted,
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSpecs(BuildContext context, AppColors c) {
    final brightness = Theme.of(context).brightness;
    final specs = <(String, int)>[
      (asset.formatLabel, AppHues.lavender),
      if (asset.bitrateKbps > 0) ('${asset.bitrateKbps} kbps', AppHues.sky),
      (_formatBytes(asset.fileSize), AppHues.mint),
      (_formatDuration(asset.durationSec), AppHues.solar),
      if (!asset.fileExists) ('文件缺失', AppHues.coral),
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

  _StatusInfo _statusInfo(AppColors c) {
    final transcription = asset.transcriptionView;
    if (asset.isTranscriptionActive) {
      return _StatusInfo(transcription.stageLabel, c.warning, pulsing: true);
    }
    if (transcription.isFailed) return _StatusInfo('转译失败', c.danger);
    if (transcription.isCanceled) return _StatusInfo('已取消', c.muted);
    if (asset.isTranscriptionDone) {
      return _StatusInfo('已转译', AppHues.top(AppHues.mint));
    }
    if (!asset.fileExists) return _StatusInfo('文件缺失', c.danger);
    return _StatusInfo('未转译', c.muted2);
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
                  t.message.isNotEmpty ? t.message : t.stageLabel,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (t.clampedPercent / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: c.divider,
              color: AppHues.top(AppHues.sky),
            ),
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
        '字幕转译已取消，可重新发起',
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
            searching ? '没有匹配的音频资产' : '暂无音频资产',
            style: TextStyle(
              color: c.text,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            searching ? '换个关键词试试' : '在影片详情页发起音频提取后，资产会显示在这里',
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
