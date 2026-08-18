import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/drag_selection.dart';
import '../../shared/entity_batch_toolbar.dart';
import '../../shared/error_view.dart';
import '../../shared/filter_chip.dart';
import '../../shared/glow_background.dart';
import '../../shared/pagination_footer.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../settings/settings_common.dart';
import 'mappings_providers.dart';
import 'mappings_repository.dart';

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
  Timer? _debounce;
  String? _search;
  String _status = 'all';
  int? _totalCount;
  int _requestSerial = 0;
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};
  Completer<void>? _refreshCompleter;

  @override
  void dispose() {
    _completeRefresh();
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) {
        setState(() => _search = v.trim().isEmpty ? null : v.trim());
        _reload();
      }
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
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
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
      _scrollRestorer.restoreAfterPage(_scrollController);
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
    final loaded = _controller.itemList ?? const <MappingRule>[];
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(loaded.map((rule) => rule.id));
    });
  }

  Future<void> _onBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除映射规则'),
        content: Text('确定删除已选择的 ${_selectedIds.length} 条规则吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除 ${_selectedIds.length} 条规则')));
      _exitSelection();
      _reload(preserveScroll: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量删除失败: ${toApiException(error).message}')),
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

    return Scaffold(
      backgroundColor: c.bg,
      bottomNavigationBar: _selectionMode
          ? EntityBatchToolbar(
              selectedCount: _selectedIds.length,
              onSelectAll: _selectAllLoaded,
              onClear: () => setState(() => _selectedIds.clear()),
              onClose: _exitSelection,
              actions: [
                EntityBatchAction(
                  icon: Icons.delete_outline,
                  label: '删除',
                  color: c.danger,
                  onTap: _selectedIds.isEmpty ? null : _onBatchDelete,
                ),
              ],
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
                eyebrow: '映射规则',
                title: '${widget.type.label}映射',
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
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _totalCount == null ? '—' : '$_totalCount',
                                style: AppText.pageTitle(context),
                              ),
                              const SizedBox(width: 8),
                              Text('条规则', style: AppText.meta(context)),
                            ],
                          ),
                        ),
                      ),
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
                                    onChanged: _onSearch,
                                    decoration: InputDecoration(
                                      hintText: '搜索原始值或映射值',
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
                                label: '全部',
                                icon: Icons.filter_list_rounded,
                                active: _status == 'all',
                                onTap: () => _setStatus('all'),
                              ),
                              const SizedBox(width: 7),
                              CompactFilterButton(
                                label: '映射规则',
                                icon: Icons.swap_horiz_rounded,
                                active: _status == 'convert',
                                onTap: () => _setStatus('convert'),
                              ),
                              const SizedBox(width: 7),
                              CompactFilterButton(
                                label: '删除规则',
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
                        sliver: PagedSliverList<int, MappingRule>(
                          pagingController: _controller,
                          builderDelegate:
                              PagedChildBuilderDelegate<MappingRule>(
                                itemBuilder: (ctx, rule, _) =>
                                    DragSelectionTarget<int>(
                                      key: ValueKey(rule.id),
                                      id: rule.id,
                                      child: _RuleTile(
                                        rule: rule,
                                        selectionMode: _selectionMode,
                                        selected: _selectedIds.contains(
                                          rule.id,
                                        ),
                                        onSelectionTap: () =>
                                            _toggleSelect(rule.id),
                                        onEdit: () => _showEditor(rule: rule),
                                        onDelete: () => _confirmDelete(rule),
                                      ),
                                    ),
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
    final originalCtrl = TextEditingController(
      text: rule == null ? '' : rule.originalValues.join('\n'),
    );
    final mappedCtrl = TextEditingController(text: rule?.mappedValue ?? '');
    bool isDelete = rule?.isDelete ?? false;

    final c = appColors(context);
    final result =
        await showModalBottomSheet<({List<String> originals, String? mapped})>(
          context: context,
          backgroundColor: c.bg,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) {
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
                      Text(
                        rule == null
                            ? '新建${widget.type.label}映射'
                            : '编辑${widget.type.label}映射',
                        style: AppText.sectionTitle(ctx),
                      ),
                      const SizedBox(height: 16),
                      Text('ORIGINAL VALUES', style: AppText.eyebrow(ctx)),
                      const SizedBox(height: 2),
                      Text('多个值用换行分隔', style: AppText.meta(ctx)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: c.surface,
                          border: Border.all(color: c.cardBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: originalCtrl,
                          minLines: 2,
                          maxLines: 5,
                          autofocus: rule == null,
                          decoration: const InputDecoration(
                            hintText: '原始值1\n原始值2',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
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
                                  'MAPPED VALUE',
                                  style: AppText.eyebrow(ctx),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isDelete ? '删除规则 · 扫描时丢弃这些值' : '映射为新值',
                                  style: AppText.meta(ctx),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '删除规则',
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
                        Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            border: Border.all(color: c.cardBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: mappedCtrl,
                            decoration: const InputDecoration(
                              hintText: '目标值',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            style: TextStyle(
                              color: c.text,
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            final originals = originalCtrl.text
                                .split('\n')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();
                            if (originals.isEmpty) return;
                            if (!isDelete && mappedCtrl.text.trim().isEmpty) {
                              return;
                            }
                            Navigator.pop(ctx, (
                              originals: originals,
                              mapped: isDelete ? null : mappedCtrl.text.trim(),
                            ));
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: c.text,
                            foregroundColor: c.bg,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            rule == null ? '创建' : '保存',
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
          content: Text(rule == null ? '已创建' : '已保存'),
          duration: const Duration(seconds: 1),
        ),
      );
      // ignore: unused_result
      _reload(preserveScroll: rule != null);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败: ${toApiException(e).message}')),
      );
    }
  }

  Future<void> _confirmDelete(MappingRule r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除映射规则'),
        content: Text('删除规则「${r.originalDisplay}」?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
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

// ============ Empty ============
class _Empty extends StatelessWidget {
  const _Empty({required this.type});
  final MappingType type;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz, size: 40, color: c.muted),
          const SizedBox(height: 14),
          Text(
            '还没有${type.label}映射规则',
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('点击右上 + 添加按钮创建第一条规则', style: AppText.meta(context)),
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
    required this.onDelete,
  });

  final MappingRule rule;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onSelectionTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
    final summary = isDelete ? '丢弃' : (rule.mappedValue ?? '');
    return InkWell(
      onTap: selectionMode ? onSelectionTap : onEdit,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(
            color: selected ? c.accent : c.cardBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
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
                isDelete ? '删除' : '映射',
                style: TextStyle(
                  color: isDelete ? c.danger : c.accent,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多操作',
              icon: Icon(Icons.more_horiz, color: c.muted),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('编辑'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: c.danger),
                      const SizedBox(width: 8),
                      Text('删除', style: TextStyle(color: c.danger)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
