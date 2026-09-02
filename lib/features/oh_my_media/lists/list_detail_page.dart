import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/models/movie.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
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
        body: Center(child: Text(AppL10n.of(context).listMissing)),
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
    final l10n = AppL10n.of(context);
    await showGlassSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.playlist_play_outlined,
                title: l10n.listActionsTitle,
                subtitle: list.name,
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              ),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: c.text),
                title: Text(
                  l10n.listRename,
                  style: const TextStyle(
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
                    l10n.listDelete,
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
                        title: Text(AppL10n.of(cctx).listDelete),
                        content: Text(AppL10n.of(cctx).listDeleteConfirmBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(cctx, false),
                            child: Text(AppL10n.of(cctx).cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(cctx, true),
                            child: Text(AppL10n.of(cctx).delete),
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
        title: Text(AppL10n.of(ctx).listRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: AppL10n.of(ctx).listNameHint,
            prefixIcon: const Icon(Icons.drive_file_rename_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppL10n.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(AppL10n.of(ctx).save),
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
              AppL10n.of(context).listEmptyTitle,
              style: AppText.body(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              AppL10n.of(context).listEmptyHint,
              style: AppText.meta(context),
            ),
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
            AppL10n.of(context).loadFailed,
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
        title: Text(AppL10n.of(ctx).listRemoveTitle),
        content: Text(AppL10n.of(ctx).listRemoveConfirm(movie.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppL10n.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppL10n.of(ctx).remove),
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
                    AppL10n.of(context).listHeroEyebrow,
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
                    AppL10n.of(context).listHeroCount(count),
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
