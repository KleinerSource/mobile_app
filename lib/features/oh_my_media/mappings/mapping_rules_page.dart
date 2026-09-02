import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/mapping_rule.dart';
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
import 'package:omm/shared/selection_controller.dart';
import 'package:omm/shared/debouncer.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'mappings_providers.dart';
import 'mappings_repository.dart';

/// 映射类型显示名：复用设置页的分类/标签/系列文案。
String _mappingTypeLabel(AppL10n l, MappingType type) => switch (type) {
  MappingType.tag => l.settingsTags,
  MappingType.genre => l.settingsGenres,
  MappingType.series => l.settingsSeries,
};

/// 通用映射规则管理页 (tags/genres/series 共用)
class MappingRulesPage extends ConsumerStatefulWidget {
  const MappingRulesPage({super.key, required this.type});
  final MappingType type;

  @override
  ConsumerState<MappingRulesPage> createState() => _MappingRulesPageState();
}

class _MappingRulesPageState extends ConsumerState<MappingRulesPage> {
  static const _pageSize = 50;

  final _searchCtrl = TextEditingController();
  final _controller = PagingController<int, MappingRule>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MappingRule>(
    _controller,
  );
  final _debounce = Debouncer();
  String? _search;
  String _status = 'all';
  int? _totalCount;
  int _requestSerial = 0;
  bool _lastPageComplete = false;
  late final SelectionController<int> _selection;
  Completer<void>? _refreshCompleter;

  /// 当前左滑展开的行（规则 id），同一时刻只展开一个。
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);

  @override
  void dispose() {
    _completeRefresh();
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _debounce.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selection = SelectionController<int>();
    _selection.activeListenable.addListener(_onSelectionModeChanged);
    _controller.addPageRequestListener(_fetch);
    _scrollController.addListener(_closeSwipeOnScroll);
  }

  bool get _selectionMode => _selection.isActive;
  Set<int> get _selectedIds => _selection.selected;

  void _onSelectionModeChanged() {
    if (mounted) setState(() {});
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
  }

  void _onSearch(String v) {
    _debounce.run(() {
      if (mounted) {
        setState(() => _search = v.trim().isEmpty ? null : v.trim());
        _reload();
      }
    });
  }

  void _clearSearch() {
    _debounce.cancel();
    _searchCtrl.clear();
    if (_search == null) return;
    setState(() => _search = null);
    _reload();
  }

  void _setStatus(String status) {
    if (_status == status) return;
    setState(() => _status = status);
    _reload();
  }

  Future<void> _fetch(int offset) async {
    final requestSerial = _requestSerial;
    try {
      final page = await ref
          .read(mappingsRepositoryProvider)
          .listPage(
            widget.type,
            limit: _pageSize,
            offset: offset,
            search: _search,
            status: _status,
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
    _selection.enter();
    _selection.setSelected(id, selected);
  }

  void _applySelectionSweep(int id, bool selected) {
    _selection.setSelected(id, selected);
  }

  void _finishSelectionSweep() {
    if (_selectionMode && _selectedIds.isEmpty) _exitSelection();
  }

  void _toggleSelect(int id) => _selection.toggle(id);

  void _exitSelection() => _selection.exit();

  void _selectAllLoaded() {
    final loaded = _controller.itemList ?? const <MappingRule>[];
    _selection.selectAll(loaded.map((rule) => rule.id));
  }

  Future<void> _onBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.mappingBatchDeleteTitle),
        content: Text(l.mappingBatchDeleteConfirm(_selectedIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(mappingsRepositoryProvider)
          .delete(widget.type, _selectedIds.toList());
      if (!mounted) return;
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.mappingBatchDeleted(_selectedIds.length))),
      );
      _exitSelection();
      _reload(preserveScroll: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(
              context,
            ).mappingBatchDeleteFailed(toApiException(error).message),
          ),
        ),
      );
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
    final l = AppL10n.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      bottomNavigationBar: _selectionMode
          ? ValueListenableBuilder<Set<int>>(
              valueListenable: _selection.selectedListenable,
              builder: (context, selected, _) => EntityBatchToolbar(
                selectedCount: selected.length,
                onSelectAll: _selectAllLoaded,
                onClear: _selection.clear,
                onClose: _exitSelection,
                actions: [
                  EntityBatchAction(
                    icon: Icons.delete_outline,
                    label: l.delete,
                    color: c.danger,
                    onTap: selected.isEmpty ? null : _onBatchDelete,
                  ),
                ],
              ),
            )
          : null,
      body: PopScope(
        canPop: !_selectionMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectionMode) _exitSelection();
        },
        child: GlowBackground(
          child: SafeArea(
            child: SettingsFixedHeaderLayout(
              scrollController: _scrollController,
              header: SettingsSubPageHeader(
                eyebrow: l.settingsGroupMappings,
                title: l.mappingTypeTitle(_mappingTypeLabel(l, widget.type)),
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
                      l.mappingCountSuffix,
                      style: AppText.meta(context),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [SettingsAddButton(onPressed: () => _showEditor())],
                ),
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
                    slivers: [
                      // 搜索栏
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                          child: Container(
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
                                    controller: _searchCtrl,
                                    textAlignVertical: TextAlignVertical.center,
                                    onChanged: _onSearch,
                                    decoration: InputDecoration(
                                      hintText: l.mappingSearchHint,
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
                                if (_searchCtrl.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: c.muted,
                                    ),
                                    onPressed: () {
                                      _clearSearch();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // status chips
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(
                            children: [
                              CompactFilterButton(
                                label: l.filterAll,
                                icon: Icons.filter_list_rounded,
                                active: _status == 'all',
                                onTap: () => _setStatus('all'),
                              ),
                              const SizedBox(width: 7),
                              CompactFilterButton(
                                label: l.mappingFilterConvert,
                                icon: Icons.swap_horiz_rounded,
                                active: _status == 'convert',
                                onTap: () => _setStatus('convert'),
                              ),
                              const SizedBox(width: 7),
                              CompactFilterButton(
                                label: l.mappingFilterDelete,
                                icon: Icons.delete_outline_rounded,
                                active: _status == 'delete',
                                onTap: () => _setStatus('delete'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),

                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          0,
                          22,
                          _selectionMode ? 136 : 80,
                        ),
                        sliver: PagedSliverList<int, MappingRule>.separated(
                          pagingController: _controller,
                          separatorBuilder: (_, itemIndex) {
                            // 隐藏末项与状态页脚之间的尾随分隔线（末行底部圆角）。
                            final count = _controller.itemList?.length ?? 0;
                            return itemIndex >= count - 1
                                ? const SizedBox.shrink()
                                : Divider(height: 1, color: c.divider);
                          },
                          builderDelegate:
                              PagedChildBuilderDelegate<MappingRule>(
                                itemBuilder: (ctx, rule, index) {
                                  // 连排整条列表：首行圆上角、末行圆下角，
                                  // 操作块沿用同一圆角避免顶出行轮廓。
                                  final isLastRow =
                                      _lastPageComplete &&
                                      index ==
                                          (_controller.itemList?.length ?? 0) -
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
                                    cellKey: rule.id,
                                    enabled: !_selectionMode,
                                    actions: [
                                      SwipeActionData(
                                        icon: Icons.edit_outlined,
                                        label: l.edit,
                                        color: c.accent,
                                        onPressed: () =>
                                            _showEditor(rule: rule),
                                      ),
                                      SwipeActionData(
                                        icon: Icons.delete_outline,
                                        label: l.delete,
                                        color: c.danger,
                                        onPressed: () => _confirmDelete(rule),
                                      ),
                                    ],
                                    child: DragSelectionTarget<int>(
                                      key: ValueKey(rule.id),
                                      id: rule.id,
                                      selectionIndex: index,
                                      selectionHandleAlignment:
                                          Alignment.centerLeft,
                                      child: ClipRRect(
                                        borderRadius: rowRadius,
                                        child: ValueListenableBuilder<Set<int>>(
                                          valueListenable:
                                              _selection.selectedListenable,
                                          builder: (context, selected, _) =>
                                              _RuleTile(
                                                rule: rule,
                                                selectionMode: _selectionMode,
                                                selected: selected.contains(
                                                  rule.id,
                                                ),
                                                onSelectionTap: () =>
                                                    _toggleSelect(rule.id),
                                                onEdit: () =>
                                                    _showEditor(rule: rule),
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
                                          l.loadFailed,
                                      onRetry: _controller.refresh,
                                    ),
                                newPageErrorIndicatorBuilder: (_) =>
                                    PaginationRetry(
                                      onRetry:
                                          _controller.retryLastFailedRequest,
                                    ),
                                noItemsFoundIndicatorBuilder: (_) =>
                                    _Empty(type: widget.type),
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
          ),
        ),
      ),
    );
  }

  Future<void> _showEditor({MappingRule? rule}) async {
    // 单原始值设计：编辑一条规则只处理一个原始值；新建仍可多值输入（保存时拆分为多条规则）。
    final originalCtrl = TextEditingController(
      text: rule == null
          ? ''
          : (rule.originalValues.isNotEmpty ? rule.originalValues.first : ''),
    );
    final mappedCtrl = TextEditingController(text: rule?.mappedValue ?? '');
    bool isDelete = rule?.isDelete ?? false;

    final c = appColors(context);
    final typeLabel = _mappingTypeLabel(AppL10n.of(context), widget.type);
    final result =
        await showGlassSheet<({List<String> originals, String? mapped})>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) {
            final sheetL = AppL10n.of(ctx);
            return StatefulBuilder(
              builder: (sctx, setSt) {
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
                        icon: Icons.rule_outlined,
                        title: rule == null
                            ? sheetL.mappingEditorTitleNew(typeLabel)
                            : sheetL.mappingEditorTitleEdit(typeLabel),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        sheetL.mappingOriginalValuesEyebrow,
                        style: AppText.eyebrow(ctx),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rule == null
                            ? sheetL.mappingOriginalMultiHint
                            : sheetL.mappingOriginalSingleHint,
                        style: AppText.meta(ctx),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: originalCtrl,
                        minLines: 1,
                        maxLines: rule == null ? 5 : 1,
                        autofocus: rule == null,
                        textAlignVertical: rule == null
                            ? null
                            : TextAlignVertical.center,
                        decoration: sheetInputDecoration(
                          sctx,
                          hintText: rule == null
                              ? sheetL.mappingOriginalMultiPlaceholder
                              : sheetL.mappingOriginalPlaceholder,
                          prefixIcon: const Icon(Icons.notes),
                        ),
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sheetL.mappingMappedValueEyebrow,
                                  style: AppText.eyebrow(ctx),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isDelete
                                      ? sheetL.mappingMappedDeleteHint
                                      : sheetL.mappingMappedHint,
                                  style: AppText.meta(ctx),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                sheetL.mappingFilterDelete,
                                style: TextStyle(
                                  color: c.muted,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              SettingsSwitch(
                                value: isDelete,
                                onChanged: (v) {
                                  setSt(() {
                                    isDelete = v;
                                    if (v) mappedCtrl.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (!isDelete) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: mappedCtrl,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: sheetInputDecoration(
                            sctx,
                            hintText: AppL10n.of(sctx).mappingMappedPlaceholder,
                            prefixIcon: const Icon(
                              Icons.drive_file_rename_outline,
                            ),
                          ),
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            final trimmed = originalCtrl.text.trim();
                            final originals = rule == null
                                ? originalCtrl.text
                                      .split('\n')
                                      .map((s) => s.trim())
                                      .where((s) => s.isNotEmpty)
                                      .toList()
                                : (trimmed.isEmpty ? <String>[] : [trimmed]);
                            if (originals.isEmpty) return;
                            if (!isDelete && mappedCtrl.text.trim().isEmpty) {
                              return;
                            }
                            Navigator.pop(ctx, (
                              originals: originals,
                              mapped: isDelete ? null : mappedCtrl.text.trim(),
                            ));
                          },
                          style: sheetPrimaryButtonStyle(sctx),
                          child: Text(
                            rule == null
                                ? AppL10n.of(sctx).listCreate
                                : AppL10n.of(sctx).save,
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

    originalCtrl.dispose();
    mappedCtrl.dispose();
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(mappingsRepositoryProvider);
      if (rule == null) {
        await repo.create(
          widget.type,
          originalValues: result.originals,
          mappedValue: result.mapped,
        );
      } else {
        await repo.update(
          widget.type,
          rule.id,
          originalValues: result.originals,
          mappedValue: result.mapped,
        );
      }
      AppHaptics.medium();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            rule == null
                ? AppL10n.of(context).mappingCreatedToast
                : AppL10n.of(context).configSavedToast,
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      // ignore: unused_result
      _reload(preserveScroll: rule != null);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(context).operationFailed(toApiException(e).message),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(MappingRule r) async {
    final l = AppL10n.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.mappingDeleteRuleTitle),
        content: Text(l.mappingDeleteRuleConfirm(r.originalDisplay)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(mappingsRepositoryProvider).delete(widget.type, [r.id]);
      AppHaptics.medium();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.mappingDeletedToast),
          duration: const Duration(seconds: 1),
        ),
      );
      // ignore: unused_result
      _reload(preserveScroll: true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.mappingDeleteFailed(toApiException(e).message)),
        ),
      );
    }
  }
}

// ============ Empty ============
class _Empty extends StatelessWidget {
  const _Empty({required this.type});
  final MappingType type;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz, size: 40, color: c.muted),
          const SizedBox(height: 14),
          Text(
            l.mappingEmptyTitle(_mappingTypeLabel(l, type)),
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l.mappingEmptyHint,
            style: AppText.meta(context),
          ),
        ],
      ),
    );
  }
}

// ============ Rule tile ============
class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.selectionMode,
    required this.selected,
    required this.onSelectionTap,
    required this.onEdit,
  });

  final MappingRule rule;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onSelectionTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDelete = rule.isDelete;
    // 左侧首字符,与 ResourceTile 一致
    final originals = rule.originalValues;
    final letter = originals.isNotEmpty && originals.first.isNotEmpty
        ? originals.first.characters.first
        : '·';
    // 类型相关 hue (映射 紫 / 删除 红) — 与 chip 配色呼应
    final hue = isDelete ? AppHues.coral : AppHues.lavender;
    final firstLine = originals.join(' · ');
    // 摘要文字 (放第二行 muted)
    final summary = isDelete
        ? AppL10n.of(context).mappingSummaryDiscard
        : (rule.mappedValue ?? '');
    return Material(
      // 连排行：无独立边框圆角，选中以整行背景提示。
      color: selected ? c.accent.withValues(alpha: 0.07) : c.surface,
      child: InkWell(
        onTap: selectionMode ? onSelectionTap : onEdit,
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
              // hue 首字母方块
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
                  letter,
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
                      firstLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          isDelete ? Icons.block : Icons.arrow_forward,
                          size: 12,
                          color: c.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.meta(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 映射/删除 角标 (替代右侧大胶囊, 紧凑放右侧)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDelete
                      ? c.danger.withValues(alpha: 0.15)
                      : c.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  isDelete
                      ? AppL10n.of(context).delete
                      : AppL10n.of(context).mappingBadgeConvert,
                  style: TextStyle(
                    color: isDelete ? c.danger : c.accent,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
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
