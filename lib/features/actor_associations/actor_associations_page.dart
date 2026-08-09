import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';
import 'actor_associations_providers.dart';
import 'widgets/actor_association_editor_sheet.dart';
import 'widgets/actor_association_sync_sheet.dart';

class ActorAssociationsPage extends ConsumerStatefulWidget {
  const ActorAssociationsPage({super.key});

  @override
  ConsumerState<ActorAssociationsPage> createState() =>
      _ActorAssociationsPageState();
}

class _ActorAssociationsPageState extends ConsumerState<ActorAssociationsPage> {
  static const _pageSize = 20;
  final _controller = PagingController<int, MappingRule>(firstPageKey: 0);
  final _searchCtl = TextEditingController();
  String _search = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    try {
      final repo = ref.read(actorAssociationsRepositoryProvider);
      final r = await repo.list(
        limit: _pageSize,
        offset: offset,
        search: _search,
      );
      final nextOffset = offset + r.items.length;
      if (nextOffset >= r.totalCount || r.items.isEmpty) {
        _controller.appendLastPage(r.items);
      } else {
        _controller.appendPage(r.items, nextOffset);
      }
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final s = v.trim();
      if (s == _search) return;
      _search = s;
      _controller.refresh();
    });
  }

  Future<void> _create() async {
    final ok = await ActorAssociationEditorSheet.show(
      context,
      mode: ActorAssocEditMode.create,
    );
    if (ok == true) _controller.refresh();
  }

  Future<void> _edit(MappingRule r) async {
    final ok = await ActorAssociationEditorSheet.show(
      context,
      mode: ActorAssocEditMode.edit,
      existing: r,
    );
    if (ok == true) _controller.refresh();
  }

  Future<void> _append(MappingRule r) async {
    final ok = await ActorAssociationEditorSheet.show(
      context,
      mode: ActorAssocEditMode.append,
      existing: r,
    );
    if (ok == true) _controller.refresh();
  }

  Future<void> _sync(MappingRule r) async {
    final ok = await ActorAssociationSyncSheet.show(context, r);
    if (ok == true) _controller.refresh();
  }

  Future<void> _delete(MappingRule r) async {
    final c = appColors(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除关联'),
        content: Text(
            '确定删除「${r.mappedValue ?? ''}」及其 ${r.originalValues.length} 个别名?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: c.danger, foregroundColor: Colors.white),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(actorAssociationsRepositoryProvider)
          .deleteById(r.id);
      messenger.showSnackBar(const SnackBar(content: Text('已删除')));
      _controller.refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('删除失败: ${toApiException(e).message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsSubPageHeader(
                eyebrow: '媒体库',
                title: '演员关联管理',
                trailing: SettingsAddButton(onPressed: _create),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: _SearchBar(
                  controller: _searchCtl,
                  onChanged: _onSearchChanged,
                ),
              ),
              Expanded(
                child: PagedListView<int, MappingRule>(
                  pagingController: _controller,
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 96),
                  builderDelegate: PagedChildBuilderDelegate<MappingRule>(
                    itemBuilder: (ctx, item, _) => _AssocCard(
                      rule: item,
                      onSync: () => _sync(item),
                      onAppend: () => _append(item),
                      onEdit: () => _edit(item),
                      onDelete: () => _delete(item),
                    ),
                    firstPageProgressIndicatorBuilder: (_) =>
                        const Center(child: CupertinoActivityIndicator()),
                    firstPageErrorIndicatorBuilder: (_) => ErrorView(
                      message: _controller.error?.toString() ?? '加载失败',
                      onRetry: () => _controller.refresh(),
                    ),
                    noItemsFoundIndicatorBuilder: (_) =>
                        const EmptyView(message: '没有演员关联记录'),
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
              decoration: InputDecoration(
                hintText: '搜索标准名 / 别名',
                hintStyle:
                    TextStyle(color: c.muted, fontWeight: FontWeight.w500),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
              ),
              style: TextStyle(color: c.text, fontWeight: FontWeight.w500),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _AssocCard extends StatelessWidget {
  const _AssocCard({
    required this.rule,
    required this.onSync,
    required this.onAppend,
    required this.onEdit,
    required this.onDelete,
  });
  final MappingRule rule;
  final VoidCallback onSync;
  final VoidCallback onAppend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, color: c.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rule.mappedValue?.trim().isNotEmpty == true
                      ? rule.mappedValue!
                      : '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${rule.originalValues.length}',
                  style: TextStyle(
                    color: c.accent,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (rule.originalValues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in rule.originalValues.take(8))
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.chipBg,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: c.cardBorder),
                    ),
                    child: Text(
                      v,
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                if (rule.originalValues.length > 8)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.chipBg,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: c.cardBorder),
                    ),
                    child: Text(
                      '+${rule.originalValues.length - 8}',
                      style: TextStyle(
                        color: c.muted,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionBtn(
                tooltip: '数据源同步',
                icon: Icons.cloud_download_outlined,
                color: c.accent,
                onTap: onSync,
              ),
              _ActionBtn(
                tooltip: '追加别名',
                icon: Icons.add_rounded,
                color: c.accent,
                onTap: onAppend,
              ),
              _ActionBtn(
                tooltip: '编辑',
                icon: Icons.edit_outlined,
                color: c.text,
                onTap: onEdit,
              ),
              _ActionBtn(
                tooltip: '删除',
                icon: Icons.delete_outline,
                color: c.danger,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18, color: color),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
