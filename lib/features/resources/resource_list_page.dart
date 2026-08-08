import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/resource.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import 'resource_movies_page.dart';
import 'resources_providers.dart';
import 'resources_repository.dart';

/// 通用资源列表页 · genre / tag / series 共用
///
/// - 顶部: 计数 + 标题 + 添加按钮
/// - 搜索栏 (320ms debounce)
/// - 排序 chips (名称 / 影片数 / 创建时间)
/// - 列表行: hue 圆 + 名称 + 描述 + 数量胶囊 + more (编辑 / 删除)
/// - 点击行 → ResourceMoviesPage 看该维度下所有影片
class ResourceListPage extends ConsumerStatefulWidget {
  const ResourceListPage({super.key, required this.kind});
  final ResourceKind kind;

  @override
  ConsumerState<ResourceListPage> createState() => _ResourceListPageState();
}

class _ResourceListPageState extends ConsumerState<ResourceListPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _search;
  String _sortBy = 'name';
  String _sortOrder = 'asc';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) {
        setState(() => _search = v.trim().isEmpty ? null : v.trim());
      }
    });
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
  }

  ResourceListKey get _key => ResourceListKey(
        kind: widget.kind,
        search: _search,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final async = ref.watch(resourceListProvider(_key));

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: c.accent,
            onRefresh: () =>
                ref.refresh(resourceListProvider(_key).future).then((_) {}),
            child: CustomScrollView(
              slivers: [
                // 顶部
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => _showEditor(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('添加',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: c.text,
                            foregroundColor: c.bg,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.kind.icon,
                            style: AppText.eyebrow(context)),
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              async.maybeWhen(
                                data: (p) => '${p.totalCount}',
                                orElse: () => '—',
                              ),
                              style: AppText.pageTitle(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.kind.label,
                              style: TextStyle(
                                color: c.muted,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

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
                          Icon(Icons.search, size: 18, color: c.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: widget.kind.searchHint,
                                hintStyle: TextStyle(
                                  color: c.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                                isCollapsed: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
                              icon: Icon(Icons.close, size: 16, color: c.muted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = null);
                              },
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
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      children: [
                        _SortChip(
                          label: '名称',
                          field: 'name',
                          activeField: _sortBy,
                          order: _sortOrder,
                          onTap: () => _setSort('name'),
                        ),
                        const SizedBox(width: 7),
                        _SortChip(
                          label: '影片数',
                          field: 'movie_count',
                          activeField: _sortBy,
                          order: _sortOrder,
                          onTap: () => _setSort('movie_count'),
                        ),
                        const SizedBox(width: 7),
                        _SortChip(
                          label: '创建时间',
                          field: 'created_at',
                          activeField: _sortBy,
                          order: _sortOrder,
                          onTap: () => _setSort('created_at'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // 列表
                async.when(
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('加载失败: $e', style: AppText.body(context)),
                      ),
                    ),
                  ),
                  data: (paged) {
                    if (paged.items.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Empty(kind: widget.kind),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final r = paged.items[i];
                            final hue =
                                AppHues.all[i % AppHues.all.length];
                            return _ResourceTile(
                              kind: widget.kind,
                              item: r,
                              hue: hue,
                              onTap: () => Navigator.of(ctx).push(
                                MaterialPageRoute(
                                  builder: (_) => ResourceMoviesPage(
                                    kind: widget.kind,
                                    resource: r,
                                  ),
                                ),
                              ),
                              onEdit: () => _showEditor(ctx, edit: r),
                              onDelete: () => _confirmDelete(ctx, r),
                            );
                          },
                          childCount: paged.items.length,
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
    );
  }

  // ============ Editor ============

  Future<void> _showEditor(BuildContext context, {ResourceItem? edit}) async {
    final c = appColors(context);
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final descCtrl = TextEditingController(text: edit?.description ?? '');
    final isEdit = edit != null;

    final result = await showModalBottomSheet<({String name, String? desc})>(
      context: context,
      backgroundColor: c.bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
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
                isEdit ? '编辑${widget.kind.label}' : '新建${widget.kind.label}',
                style: AppText.sectionTitle(ctx),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: nameCtrl,
                  autofocus: !isEdit,
                  decoration: InputDecoration(
                    hintText: '${widget.kind.label}名称',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: '描述 (可选)',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx, (
                      name: name,
                      desc: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    ));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.text,
                    foregroundColor: c.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEdit ? '保存' : '创建',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    nameCtrl.dispose();
    descCtrl.dispose();

    if (result == null) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(resourcesRepositoryProvider);
      if (isEdit) {
        await repo.update(widget.kind, edit.id,
            name: result.name, description: result.desc ?? '');
      } else {
        await repo.create(widget.kind,
            name: result.name, description: result.desc);
      }
      AppHaptics.medium();
      messenger.showSnackBar(SnackBar(
        content: Text(isEdit ? '已保存' : '已创建'),
        duration: const Duration(seconds: 1),
      ));
      // ignore: unused_result
      ref.refresh(resourceListProvider(_key));
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
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(hasMovies ? '强制删除' : '删除')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(resourcesRepositoryProvider)
          .deleteBatch(widget.kind, [r.id], force: hasMovies);
      AppHaptics.medium();
      messenger.showSnackBar(const SnackBar(
        content: Text('已删除'),
        duration: Duration(seconds: 1),
      ));
      // ignore: unused_result
      ref.refresh(resourceListProvider(_key));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: ${toApiException(e).message}')),
      );
    }
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
          Text('还没有${kind.label}',
              style:
                  AppText.body(context).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('点击右上 + 添加按钮创建第一个', style: AppText.meta(context)),
        ],
      ),
    );
  }
}

// ============ Sort chip ============

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.field,
    required this.activeField,
    required this.order,
    required this.onTap,
  });

  final String label;
  final String field;
  final String activeField;
  final String order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final active = field == activeField;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.chipBgActive : c.chipBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? c.chipTextActive : c.text2,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(
                order == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: c.chipTextActive,
              ),
            ],
          ],
        ),
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
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ResourceKind kind;
  final ResourceItem item;
  final int hue;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.cardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
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
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta(context),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: c.muted),
              padding: EdgeInsets.zero,
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('编辑'),
                    ])),
                PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 16, color: c.danger),
                      const SizedBox(width: 8),
                      Text('删除', style: TextStyle(color: c.danger)),
                    ])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
