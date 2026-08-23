import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../../shared/poster.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movies_providers.dart';
import '../privacy/privacy_mask.dart';
import 'list_model.dart';
import 'lists_providers.dart';

/// 单个虚拟 list 详情页
/// - 顶部 hero (hue 渐变 + 标题 + 数量)
/// - 网格展示其包含的影片 (用 movieDetailProvider 单独取详情)
/// - 长按 cell 弹移除确认
/// - 顶右 more 菜单: 重命名 / 删除
class ListDetailPage extends ConsumerWidget {
  const ListDetailPage({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final list = ref.watch(favoriteListProvider(listId));

    if (list == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(),
        body: const Center(child: Text('集合不存在或已删除')),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, size: 18),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_horiz, size: 18),
                  ),
                  onPressed: () => _showMoreSheet(context, ref, list),
                ),
                const SizedBox(width: 6),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _Hero(
                  name: list.name,
                  hue: list.hue,
                  count: list.count,
                ),
              ),
            ),

            if (list.movieIds.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyListView(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 80),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate((ctx, i) {
                    final id = list.movieIds[i];
                    return _ListMovieCell(movieId: id, listId: list.id);
                  }, childCount: list.movieIds.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoreSheet(
    BuildContext context,
    WidgetRef ref,
    FavoriteList list,
  ) async {
    final c = appColors(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_outlined, color: c.text),
                title: const Text(
                  '重命名',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _renameDialog(context, ref, list);
                },
              ),
              if (!list.builtin)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: c.danger),
                  title: Text(
                    '删除集合',
                    style: TextStyle(
                      color: c.danger,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (cctx) => AlertDialog(
                        title: const Text('删除集合'),
                        content: const Text('集合内的影片不会被删除,只是不再属于这个集合。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(cctx, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(cctx, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await ref.read(listsProvider.notifier).delete(list.id);
                      if (context.mounted) {
                        await Navigator.of(context).maybePop();
                      }
                    }
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renameDialog(
    BuildContext context,
    WidgetRef ref,
    FavoriteList list,
  ) async {
    final controller = TextEditingController(text: list.name);
    final renamed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名集合'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '集合名称',
            prefixIcon: Icon(Icons.drive_file_rename_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (renamed != null && renamed.isNotEmpty) {
      await ref.read(listsProvider.notifier).rename(list.id, renamed);
      AppHaptics.medium();
    }
  }
}

class _EmptyListView extends StatelessWidget {
  const _EmptyListView();

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections_bookmark_outlined, size: 40, color: c.muted),
            const SizedBox(height: 14),
            Text(
              '集合是空的',
              style: AppText.body(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('在影片详情里点 + List 加入', style: AppText.meta(context)),
          ],
        ),
      ),
    );
  }
}

class _ListMovieCell extends ConsumerWidget {
  const _ListMovieCell({required this.movieId, required this.listId});
  final int movieId;
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final asyncMovie = ref.watch(movieDetailProvider(movieId));
    final urlBuilder = ref.watch(imageUrlBuilderProvider);

    return asyncMovie.when(
      loading: () => Container(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      error: (_, __) => Container(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.danger.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '加载失败',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontFamily: 'Inter', fontSize: 10),
          ),
        ),
      ),
      data: (movie) => PrivacyAwareInkWell(
        movieId: movieId,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)),
        ),
        onLongPress: () => _confirmRemove(context, ref, movie),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrivacyMask(
              movieId: movieId,
              child: Poster(
                url: movie.posterUuid != null
                    ? urlBuilder(movie.posterUuid!)
                    : null,
                title: movie.title,
                year: movie.year,
              ),
            ),
            const SizedBox(height: 8),
            PrivacyText(
              movieId: movieId,
              text: movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.text,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
            if (movie.year != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${movie.year}${movie.rating != null && movie.rating! > 0 ? '  ★ ${movie.rating!.toStringAsFixed(1)}' : ''}',
                  style: TextStyle(
                    color: c.muted,
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    MovieDetail movie,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从集合移除'),
        content: Text('把「${movie.title}」从这个集合移除?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(listsProvider.notifier).removeMovie(listId, movie.id);
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.hue, required this.count});

  final String name;
  final int hue;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppHues.top(hue), AppHues.bottom(hue)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            width: 240,
            height: 240,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppHues.highlight(hue),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '集合',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      letterSpacing: -0.96,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$count 部',
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
