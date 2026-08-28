import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/debouncer.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/translation/translation_providers.dart';
import 'entity_merge_sheet.dart';
import 'resource_movies_page.dart';
import 'resources_providers.dart';
import 'resources_repository.dart';

String _normalizeResourceName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String _resourceTranslationField(ResourceKind kind) {
  switch (kind) {
    case ResourceKind.genre:
      return 'genre_name';
    case ResourceKind.tag:
      return 'tag_name';
    case ResourceKind.series:
      return 'series_name';
  }
}

/// 通用资源列表页 · genre / tag / series 共用
///
/// - 顶部: 计数 + 标题 + 添加按钮
/// - 搜索栏 (320ms debounce)
/// - 排序 chips (名称 / 影片数 / 创建时间)
/// - 列表行: hue 圆 + 名称 + 数量胶囊 + 左滑 (编辑 / 删除)
/// - 点击行 → ResourceMoviesPage 看该维度下所有影片
class ResourceListPage extends ConsumerStatefulWidget {
  const ResourceListPage({super.key, required this.kind});
  final ResourceKind kind;

  @override
  ConsumerState<ResourceListPage> createState() => _ResourceListPageState();
}

class _ResourceListPageState extends ConsumerState<ResourceListPage> {
  static const _tagAndGenrePageSize = 300;
  static const _seriesPageSize = 100;

  final _searchController = TextEditingController();
  final _controller = PagingController<int, ResourceItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<ResourceItem>(
    _controller,
  );
  final _debounce = Debouncer();
  String? _search;
  String _sortBy = 'name';
  String _sortOrder = 'asc';
  int? _totalCount;
  int _requestSerial = 0;
  bool _lastPageComplete = false;
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};
  Completer<void>? _refreshCompleter;

  /// 当前左滑展开的行（资源 id），同一时刻只展开一个。
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
    _scrollController.addListener(_closeSwipeOnScroll);
  }

  int get _pageSize => widget.kind == ResourceKind.series
      ? _seriesPageSize
      : _tagAndGenrePageSize;

  @override
  void dispose() {
    _completeRefresh();
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
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

  void _onSearchChanged(String v) {
    _debounce.run(() {
      if (mounted) {
        setState(() => _search = v.trim().isEmpty ? null : v.trim());
        _reload();
      }
    });
  }

  void _clearSearch() {
    _debounce.cancel();
    _searchController.clear();
    if (_search == null) return;
    setState(() => _search = null);
    _reload();
  }

  void _setSort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
      } else {
        _sortBy = field;
        _sortOrder = field == 'movie_count' ? 'desc' : 'asc';
      }
    });
    _reload();
  }

  Future<void> _fetch(int offset) async {
    final requestSerial = _requestSerial;
    try {
      final page = await ref
          .read(resourcesRepositoryProvider)
          .list(
            widget.kind,
            limit: _pageSize,
            offset: offset,
            search: _search,
            sortBy: _sortBy,
            sortOrder: _sortOrder,
          );
      if (!mounted || requestSerial != _requestSerial) return;

      setState(() => _totalCount = page.totalCount);
      // 末页标记：连排列表只有最后一行需要底部圆角。
      final hasMore = applyPagedListPage(
        controller: _controller,
        offset: offset,
        items: page.items,
        totalCount: page.totalCount,
        restorer: _scrollRestorer,
        scrollController: _scrollController,
      );
      setState(() => _lastPageComplete = !hasMore);
      _completeRefresh();
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = toApiException(error).message;
      _completeRefresh();
    }
  }

  void _reload({bool preserveScroll = false}) {
    _requestSerial++;
    _scrollRestorer.prepare(_scrollController, preserve: preserveScroll);
    _controller.refresh();
  }

  Future<void> _refresh() {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _refreshCompleter = completer;
    _reload();
    return completer.future;
  }

  void _startSelectionSweep(int id, bool selected) {
    setState(() {
      _selectionMode = true;
      _setSelectionValue(id, selected);
    });
  }

  void _applySelectionSweep(int id, bool selected) {
    if (_selectedIds.contains(id) == selected) return;
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
    setState(() {
      if (_selectedIds.remove(id)) {
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAllLoaded() {
    final loaded = _controller.itemList ?? const <ResourceItem>[];
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(loaded.map((item) => item.id));
    });
  }

  List<ResourceItem> _selectedItems() {
    final loaded = _controller.itemList ?? const <ResourceItem>[];
    return loaded.where((item) => _selectedIds.contains(item.id)).toList();
  }

  Future<void> _onBatchDelete() async {
    final items = _selectedItems();
    if (items.isEmpty) return;
    final force = items.any((item) => item.movieCount > 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('批量删除${widget.kind.label}'),
        content: Text(
          force
              ? '已选择 ${items.length} 个${widget.kind.label}，其中包含影片关联。强制删除会解除关联，影片本身不会被删除。'
              : '确定删除已选择的 ${items.length} 个${widget.kind.label}吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(force ? '强制删除' : '删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(resourcesRepositoryProvider)
          .deleteBatch(
            widget.kind,
            items.map((item) => item.id).toList(),
            force: force,
          );
      if (!mounted) return;
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 ${items.length} 个${widget.kind.label}')),
      );
      _exitSelection();
      _reload(preserveScroll: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量删除失败: ${toApiException(error).message}')),
      );
    }
  }

  Future<void> _onBatchMerge() async {
    final items = _selectedItems();
    if (items.length < 2) return;
    final merged = await EntityMergeSheet.show(context, widget.kind, items);
    if (merged == true && mounted) {
      _exitSelection();
      _reload(preserveScroll: true);
    }
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

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
                    eyebrow: '媒体库',
                    title: widget.kind.plural,
                    titleTrailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _totalCount == null ? '—' : '$_totalCount',
                          style: AppText.pageTitle(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '个${widget.kind.label}',
                          style: AppText.meta(context),
                        ),
                      ],
                    ),
                    trailing: SettingsAddButton(
                      onPressed: () => _showEditor(context),
                    ),
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
                          // 搜索栏
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  border: Border.all(color: c.cardBorder),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 14),
                                    Icon(
                                      Icons.search,
                                      size: 18,
                                      color: c.muted,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        textAlignVertical:
                                            TextAlignVertical.center,
                                        onChanged: _onSearchChanged,
                                        decoration: InputDecoration(
                                          hintText: widget.kind.searchHint,
                                          hintStyle: TextStyle(
                                            color: c.muted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          isCollapsed: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                          border: InputBorder.none,
                                        ),
                                        style: TextStyle(
                                          color: c.text,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (_searchController.text.isNotEmpty)
                                      IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: c.muted,
                                        ),
                                        onPressed: _clearSearch,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 排序 chips
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 36,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                children: [
                                  CompactSortButton(
                                    label: '名称',
                                    active: _sortBy == 'name',
                                    ascending: _sortOrder == 'asc',
                                    onTap: () => _setSort('name'),
                                  ),
                                  const SizedBox(width: 7),
                                  CompactSortButton(
                                    label: '影片数',
                                    active: _sortBy == 'movie_count',
                                    ascending: _sortOrder == 'asc',
                                    onTap: () => _setSort('movie_count'),
                                  ),
                                  const SizedBox(width: 7),
                                  CompactSortButton(
                                    label: '创建时间',
                                    active: _sortBy == 'created_at',
                                    ascending: _sortOrder == 'asc',
                                    onTap: () => _setSort('created_at'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          // 列表
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              22,
                              0,
                              22,
                              _selectionMode ? 136 : 80,
                            ),
                            sliver: PagedSliverList<int, ResourceItem>.separated(
                              pagingController: _controller,
                              separatorBuilder: (_, itemIndex) {
                                // 隐藏末项与状态页脚之间的尾随分隔线（末行底部圆角）。
                                final count = _controller.itemList?.length ?? 0;
                                return itemIndex >= count - 1
                                    ? const SizedBox.shrink()
                                    : Divider(height: 1, color: c.divider);
                              },
                              builderDelegate:
                                  PagedChildBuilderDelegate<ResourceItem>(
                                    itemBuilder: (ctx, r, i) {
                                      final hue =
                                          AppHues.all[i % AppHues.all.length];
                                      // 连排整条列表：首行圆上角、末行圆下角，
                                      // 操作块沿用同一圆角避免顶出行轮廓。
                                      final isLastRow =
                                          _lastPageComplete &&
                                          i ==
                                              (_controller.itemList?.length ??
                                                      0) -
                                                  1;
                                      final rowRadius = BorderRadius.vertical(
                                        top: i == 0
                                            ? const Radius.circular(16)
                                            : Radius.zero,
                                        bottom: isLastRow
                                            ? const Radius.circular(16)
                                            : Radius.zero,
                                      );
                                      return SwipeActionCell(
                                        actionBorderRadius: rowRadius,
                                        group: _openSwipe,
                                        cellKey: r.id,
                                        enabled: !_selectionMode,
                                        actions: [
                                          SwipeActionData(
                                            icon: Icons.edit_outlined,
                                            label: '编辑',
                                            color: c.accent,
                                            onPressed: () =>
                                                _showEditor(ctx, edit: r),
                                          ),
                                          SwipeActionData(
                                            icon: Icons.delete_outline,
                                            label: '删除',
                                            color: c.danger,
                                            onPressed: () =>
                                                _confirmDelete(ctx, r),
                                          ),
                                        ],
                                        child: DragSelectionTarget<int>(
                                          key: ValueKey(r.id),
                                          id: r.id,
                                          selectionIndex: i,
                                          selectionHandleAlignment:
                                              Alignment.centerLeft,
                                          child: ClipRRect(
                                            borderRadius: rowRadius,
                                            child: _ResourceTile(
                                              kind: widget.kind,
                                              item: r,
                                              hue: hue,
                                              selectionMode: _selectionMode,
                                              selected: _selectedIds.contains(
                                                r.id,
                                              ),
                                              onTap: _selectionMode
                                                  ? () => _toggleSelect(r.id)
                                                  : () => Navigator.of(ctx).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            ResourceMoviesPage(
                                                              kind: widget.kind,
                                                              resource: r,
                                                            ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    firstPageProgressIndicatorBuilder: (_) =>
                                        const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                    firstPageErrorIndicatorBuilder: (_) =>
                                        ErrorView(
                                          message:
                                              _controller.error?.toString() ??
                                              '加载失败',
                                          onRetry: _controller.refresh,
                                        ),
                                    newPageErrorIndicatorBuilder: (_) =>
                                        PaginationRetry(
                                          onRetry: _controller
                                              .retryLastFailedRequest,
                                        ),
                                    noItemsFoundIndicatorBuilder: (_) =>
                                        _Empty(kind: widget.kind),
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
                      onClear: () => setState(() => _selectedIds.clear()),
                      onClose: _exitSelection,
                      actions: [
                        EntityBatchAction(
                          icon: Icons.merge_rounded,
                          label: '合并',
                          color: c.warning,
                          onTap: _selectedIds.length < 2 ? null : _onBatchMerge,
                        ),
                        EntityBatchAction(
                          icon: Icons.delete_outline,
                          label: '删除',
                          color: c.danger,
                          onTap: _selectedIds.isEmpty ? null : _onBatchDelete,
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

  // ============ Editor ============

  Future<void> _showEditor(BuildContext context, {ResourceItem? edit}) async {
    final c = appColors(context);
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final isEdit = edit != null;
    final originalName = _normalizeResourceName(edit?.name ?? '');
    var autoMapping = false;
    var translating = false;

    bool nameChanged(String value) {
      if (!isEdit) return false;
      return _normalizeResourceName(value) != originalName;
    }

    Future<void> translateName(
      BuildContext sheetContext,
      StateSetter setSheetState,
    ) async {
      final text = nameCtrl.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('名称内容为空, 无需翻译')));
        return;
      }

      setSheetState(() => translating = true);
      try {
        final translated = await ref
            .read(translationRepositoryProvider)
            .translateText(
              text,
              fieldName: _resourceTranslationField(widget.kind),
            );
        if (!sheetContext.mounted) return;
        final value = translated.trim();
        if (value.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('名称翻译为空')));
          return;
        }
        nameCtrl.value = nameCtrl.value.copyWith(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
        setSheetState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('名称翻译成功')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('名称翻译失败: ${toApiException(e).message}')),
        );
      } finally {
        if (sheetContext.mounted) {
          setSheetState(() => translating = false);
        }
      }
    }

    final result = await showGlassSheet<({String name, bool autoMapping})>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final canAutoMap = nameChanged(nameCtrl.text);
            final mappingActive = autoMapping && canAutoMap;

            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 4,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SheetHeader(
                    icon: isEdit
                        ? Icons.edit_outlined
                        : Icons.add_circle_outline,
                    title: isEdit
                        ? '编辑${widget.kind.label}'
                        : '新建${widget.kind.label}',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.kind.label.toUpperCase(),
                            style: AppText.eyebrow(ctx),
                          ),
                        ),
                        _ResourceTranslateButton(
                          loading: translating,
                          onTap: () => translateName(ctx, setSheetState),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: nameCtrl,
                    autofocus: !isEdit,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) {
                      final changed = nameChanged(nameCtrl.text);
                      setSheetState(() {
                        if (!changed) autoMapping = false;
                      });
                    },
                    decoration: sheetInputDecoration(
                      ctx,
                      hintText: '${widget.kind.label}名称',
                      prefixIcon: const Icon(Icons.drive_file_rename_outline),
                    ),
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: canAutoMap
                            ? () => setSheetState(
                                () => autoMapping = !autoMapping,
                              )
                            : null,
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          foregroundColor: mappingActive ? c.accent : c.text,
                          backgroundColor: mappingActive
                              ? c.accent.withValues(alpha: 0.1)
                              : c.surface,
                          side: BorderSide(
                            color: mappingActive ? c.accent : c.cardBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            IgnorePointer(
                              child: Checkbox(
                                value: mappingActive,
                                onChanged: canAutoMap ? (_) {} : null,
                                activeColor: c.accent,
                                checkColor: c.bg,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '自动映射',
                              style: TextStyle(
                                color: canAutoMap ? c.text : c.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx, (
                          name: name,
                          autoMapping: autoMapping && nameChanged(name),
                        ));
                      },
                      style: sheetPrimaryButtonStyle(ctx),
                      child: Text(
                        isEdit ? '保存' : '创建',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();

    if (result == null) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(resourcesRepositoryProvider);
      if (isEdit) {
        await repo.update(
          widget.kind,
          edit.id,
          name: result.name,
          autoMapping: result.autoMapping,
        );
      } else {
        await repo.create(widget.kind, name: result.name);
      }
      AppHaptics.medium();
      messenger.showSnackBar(
        SnackBar(
          content: Text(isEdit ? '已保存' : '已创建'),
          duration: const Duration(seconds: 1),
        ),
      );
      // ignore: unused_result
      _reload(preserveScroll: isEdit);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败: ${toApiException(e).message}')),
      );
    }
  }

  // ============ Delete ============

  Future<void> _confirmDelete(BuildContext context, ResourceItem r) async {
    if (!context.mounted) return;
    final hasMovies = r.movieCount > 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除${widget.kind.label}'),
        content: Text(
          hasMovies
              ? '「${r.name}」关联了 ${r.movieCount} 部影片。强制删除将解除所有关联,影片本身不会被删。'
              : '确定删除「${r.name}」?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hasMovies ? '强制删除' : '删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(resourcesRepositoryProvider).deleteBatch(widget.kind, [
        r.id,
      ], force: hasMovies);
      AppHaptics.medium();
      messenger.showSnackBar(
        const SnackBar(content: Text('已删除'), duration: Duration(seconds: 1)),
      );
      // ignore: unused_result
      _reload(preserveScroll: true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: ${toApiException(e).message}')),
      );
    }
  }
}

/// 单字段翻译按钮，与影片编辑中的翻译控件保持一致。
class _ResourceTranslateButton extends StatelessWidget {
  const _ResourceTranslateButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.translate_rounded, size: 13, color: c.accent),
            const SizedBox(width: 4),
            Text(
              loading ? '翻译中' : '翻译',
              style: TextStyle(
                color: loading ? c.muted : c.accent,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Empty ============

class _Empty extends StatelessWidget {
  const _Empty({required this.kind});
  final ResourceKind kind;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag_outlined, size: 40, color: c.muted),
          const SizedBox(height: 14),
          Text(
            '还没有${kind.label}',
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('点击右上 + 添加按钮创建第一个', style: AppText.meta(context)),
        ],
      ),
    );
  }
}

// ============ Tile ============

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.kind,
    required this.item,
    required this.hue,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
  });

  final ResourceKind kind;
  final ResourceItem item;
  final int hue;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Material(
      // 连排行：无独立边框圆角，选中以整行背景提示。
      color: selected ? c.accent.withValues(alpha: 0.07) : c.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? c.accent : c.muted,
                ),
                const SizedBox(width: 10),
              ],
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppHues.top(hue), AppHues.bottom(hue)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.name.isNotEmpty ? item.name.characters.first : '·',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.chipBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${item.movieCount}',
                  style: TextStyle(
                    color: c.text2,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
