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
import '../../shared/pagination_footer.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../../shared/swipe_actions.dart';
import '../privacy/privacy_mask.dart';
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
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MappingRule>(
    _controller,
  );
  final _searchCtl = TextEditingController();
  String _search = '';
  Timer? _searchDebounce;
  bool _lastPageComplete = false;

  /// 当前左滑展开的行（规则 id），同一时刻只展开一个。
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
    _scrollController.addListener(_closeSwipeOnScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _searchCtl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
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
        // 末页标记：连排列表只有最后一行需要底部圆角。
        if (mounted) setState(() => _lastPageComplete = true);
        _controller.appendLastPage(r.items);
      } else {
        if (_lastPageComplete && mounted) {
          setState(() => _lastPageComplete = false);
        }
        _controller.appendPage(r.items, nextOffset);
      }
      _scrollRestorer.restoreAfterPage(_scrollController);
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  void _reload({bool preserveScroll = false}) {
    _scrollRestorer.prepare(_scrollController, preserve: preserveScroll);
    _controller.refresh();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final s = v.trim();
      if (s == _search) return;
      _search = s;
      _reload();
    });
  }

  Future<void> _create() async {
    final ok = await ActorAssociationEditorSheet.show(
      context,
      mode: ActorAssocEditMode.create,
    );
    if (ok == true) _reload(preserveScroll: true);
  }

  Future<void> _edit(MappingRule r) async {
    final ok = await ActorAssociationEditorSheet.show(
      context,
      mode: ActorAssocEditMode.edit,
      existing: r,
    );
    if (ok == true) _reload(preserveScroll: true);
  }

  Future<void> _append(MappingRule r) async {
    final ok = await ActorAssociationEditorSheet.show(
      context,
      mode: ActorAssocEditMode.append,
      existing: r,
    );
    if (ok == true) _reload(preserveScroll: true);
  }

  Future<void> _sync(MappingRule r) async {
    final ok = await ActorAssociationSyncSheet.show(context, r);
    if (ok == true) _reload(preserveScroll: true);
  }

  Future<void> _delete(MappingRule r) async {
    final c = appColors(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除关联'),
        content: Text(
          '确定删除「${r.mappedValue ?? ''}」及其 ${r.originalValues.length} 个别名?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: c.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(actorAssociationsRepositoryProvider).deleteById(r.id);
      messenger.showSnackBar(const SnackBar(content: Text('已删除')));
      _reload(preserveScroll: true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: ${toApiException(e).message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: '媒体库',
              title: '演员关联管理',
              trailing: SettingsAddButton(onPressed: _create),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: _SearchBar(
                    controller: _searchCtl,
                    onChanged: _onSearchChanged,
                  ),
                ),
                Expanded(
                  child: PagedListView<int, MappingRule>.separated(
                    scrollController: _scrollController,
                    pagingController: _controller,
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 96),
                    separatorBuilder: (_, itemIndex) {
                      // 隐藏末项与状态页脚之间的尾随分隔线（末行底部圆角）。
                      final count = _controller.itemList?.length ?? 0;
                      return itemIndex >= count - 1
                          ? const SizedBox.shrink()
                          : Divider(height: 1, color: c.divider);
                    },
                    builderDelegate: PagedChildBuilderDelegate<MappingRule>(
                      itemBuilder: (ctx, item, index) {
                        // 连排整条列表：首行圆上角、末行圆下角，
                        // 操作块沿用同一圆角避免顶出行轮廓。
                        final isLastRow =
                            _lastPageComplete &&
                            index == (_controller.itemList?.length ?? 0) - 1;
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
                          cellKey: item.id,
                          enabled: true,
                          actions: [
                            SwipeActionData(
                              icon: Icons.cloud_download_outlined,
                              label: '同步',
                              color: AppHues.top(AppHues.sky),
                              onPressed: () => _sync(item),
                            ),
                            SwipeActionData(
                              icon: Icons.add_rounded,
                              label: '追加别名',
                              color: AppHues.top(AppHues.mint),
                              onPressed: () => _append(item),
                            ),
                            SwipeActionData(
                              icon: Icons.edit_outlined,
                              label: '编辑',
                              color: c.accent,
                              onPressed: () => _edit(item),
                            ),
                            SwipeActionData(
                              icon: Icons.delete_outline,
                              label: '删除',
                              color: c.danger,
                              onPressed: () => _delete(item),
                            ),
                          ],
                          child: ClipRRect(
                            borderRadius: rowRadius,
                            child: _AssocCard(rule: item),
                          ),
                        );
                      },
                      firstPageProgressIndicatorBuilder: (_) =>
                          const Center(child: CupertinoActivityIndicator()),
                      firstPageErrorIndicatorBuilder: (_) => ErrorView(
                        message: _controller.error?.toString() ?? '加载失败',
                        onRetry: () => _controller.refresh(),
                      ),
                      noItemsFoundIndicatorBuilder: (_) =>
                          const EmptyView(message: '没有演员关联记录'),
                      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
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
                hintStyle: TextStyle(
                  color: c.muted,
                  fontWeight: FontWeight.w500,
                ),
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
  const _AssocCard({required this.rule});
  final MappingRule rule;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return PrivacyAwareInkWell(
      // 卡片本身无跳转,InkWell 仅用于隐私模式下的"点击揭示"
      movieId: rule.id,
      scope: PrivacyScope.actorAssociation,
      onTap: null,
      borderRadius: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        // 连排行：无独立边框与圆角，行背景即分组表面。
        color: c.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, color: c.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: PrivacyText(
                    movieId: rule.id,
                    scope: PrivacyScope.actorAssociation,
                    text: rule.mappedValue?.trim().isNotEmpty == true
                        ? rule.mappedValue!
                        : '-',
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
              // 关联名称 chips 固定单行：超出部分裁掉并在右缘渐隐，
              // 不显示 +x 标记；总数见标题行右侧胶囊。
              const SizedBox(height: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.82, 1],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: SizedBox(
                  height: 27,
                  child: ClipRect(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final v in rule.originalValues)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.chipBg,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: c.cardBorder),
                            ),
                            child: PrivacyText(
                              movieId: rule.id,
                              scope: PrivacyScope.actorAssociation,
                              text: v,
                              style: TextStyle(
                                color: c.text,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
