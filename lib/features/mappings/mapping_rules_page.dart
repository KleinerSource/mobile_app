import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import 'mappings_providers.dart';
import 'mappings_repository.dart';

/// 通用映射规则管理页 (tags/genres/series/actors 共用)
class MappingRulesPage extends ConsumerStatefulWidget {
  const MappingRulesPage({super.key, required this.type});
  final MappingType type;

  @override
  ConsumerState<MappingRulesPage> createState() => _MappingRulesPageState();
}

class _MappingRulesPageState extends ConsumerState<MappingRulesPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String? _search;
  String _status = 'all';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) {
        setState(() => _search = v.trim().isEmpty ? null : v.trim());
      }
    });
  }

  MappingsListKey get _key =>
      MappingsListKey(type: widget.type, search: _search, status: _status);

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final async = ref.watch(mappingsListProvider(_key));

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: c.accent,
            onRefresh: () =>
                ref.refresh(mappingsListProvider(_key).future).then((_) {}),
            child: CustomScrollView(
              slivers: [
                // 顶栏 + 添加
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
                        if (widget.type == MappingType.actor)
                          IconButton(
                            tooltip: '同步演员映射',
                            icon: Icon(Icons.sync, color: c.muted),
                            onPressed: _syncActors,
                          ),
                        FilledButton.icon(
                          onPressed: () => _showEditor(),
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
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('映射规则', style: AppText.eyebrow(context)),
                        const SizedBox(height: 3),
                        Text('${widget.type.label}映射',
                            style: AppText.pageTitle(context)),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              async.maybeWhen(
                                data: (list) => '${list.length}',
                                orElse: () => '—',
                              ),
                              style: AppText.pageTitle(context),
                            ),
                            const SizedBox(width: 8),
                            Text('条规则', style: AppText.meta(context)),
                          ],
                        ),
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
                                    fontWeight: FontWeight.w500),
                                isCollapsed: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                border: InputBorder.none,
                              ),
                              style: TextStyle(
                                  color: c.text, fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close,
                                  size: 16, color: c.muted),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = null);
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
                        _statusChip('全部', 'all'),
                        const SizedBox(width: 7),
                        _statusChip('映射规则', 'convert'),
                        const SizedBox(width: 7),
                        _statusChip('删除规则', 'delete'),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),

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
                        child:
                            Text('加载失败: $e', style: AppText.body(context)),
                      ),
                    ),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Empty(type: widget.type),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _RuleTile(
                            rule: list[i],
                            onEdit: () => _showEditor(rule: list[i]),
                            onDelete: () => _confirmDelete(list[i]),
                          ),
                          childCount: list.length,
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

  Widget _statusChip(String label, String value) {
    final c = appColors(context);
    final active = _status == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.chipBgActive : c.chipBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? c.chipTextActive : c.text2,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _showEditor({MappingRule? rule}) async {
    final originalCtrl = TextEditingController(
        text: rule == null ? '' : rule.originalValues.join('\n'));
    final mappedCtrl =
        TextEditingController(text: rule?.mappedValue ?? '');
    bool isDelete = rule?.isDelete ?? false;

    final c = appColors(context);
    final result = await showModalBottomSheet<({
      List<String> originals,
      String? mapped,
    })>(
      context: context,
      backgroundColor: c.bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (sctx, setSt) {
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
                Text('ORIGINAL VALUES',
                    style: AppText.eyebrow(ctx)),
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
                          horizontal: 14, vertical: 12),
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
                          Text('MAPPED VALUE',
                              style: AppText.eyebrow(ctx)),
                          const SizedBox(height: 2),
                          Text(
                              isDelete
                                  ? '删除规则 · 扫描时丢弃这些值'
                                  : '映射为新值',
                              style: AppText.meta(ctx)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text('删除规则',
                            style: TextStyle(
                              color: c.muted,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            )),
                        Switch(
                          value: isDelete,
                          onChanged: (v) {
                            AppHaptics.selection();
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
                            horizontal: 14, vertical: 12),
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
                      if (!isDelete && mappedCtrl.text.trim().isEmpty) return;
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
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      rule == null ? '创建' : '保存',
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
        });
      },
    );

    originalCtrl.dispose();
    mappedCtrl.dispose();
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(mappingsRepositoryProvider);
      if (rule == null) {
        await repo.create(widget.type,
            originalValues: result.originals, mappedValue: result.mapped);
      } else {
        await repo.update(widget.type, rule.id,
            originalValues: result.originals, mappedValue: result.mapped);
      }
      AppHaptics.medium();
      messenger.showSnackBar(SnackBar(
        content: Text(rule == null ? '已创建' : '已保存'),
        duration: const Duration(seconds: 1),
      ));
      // ignore: unused_result
      ref.refresh(mappingsListProvider(_key));
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
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(mappingsRepositoryProvider).delete(widget.type, [r.id]);
      AppHaptics.medium();
      messenger.showSnackBar(const SnackBar(
        content: Text('已删除'),
        duration: Duration(seconds: 1),
      ));
      // ignore: unused_result
      ref.refresh(mappingsListProvider(_key));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: ${toApiException(e).message}')),
      );
    }
  }

  Future<void> _syncActors() async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(mappingsRepositoryProvider).syncActors();
      AppHaptics.medium();
      messenger.showSnackBar(const SnackBar(
        content: Text('同步已启动'),
        duration: Duration(seconds: 1),
      ));
      // ignore: unused_result
      ref.refresh(mappingsListProvider(_key));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('同步失败: ${toApiException(e).message}')),
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
          Text('还没有${type.label}映射规则',
              style:
                  AppText.body(context).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('点击右上 + 添加按钮创建第一条规则',
              style: AppText.meta(context)),
        ],
      ),
    );
  }
}

// ============ Rule tile ============
class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });

  final MappingRule rule;
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
    final summary = isDelete
        ? '丢弃'
        : (rule.mappedValue ?? '');
    return InkWell(
      onTap: onEdit,
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
            // ... 按钮 (编辑/删除)
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
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 16, color: c.danger),
                    const SizedBox(width: 8),
                    Text('删除', style: TextStyle(color: c.danger)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
