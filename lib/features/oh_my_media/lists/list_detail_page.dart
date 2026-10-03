import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'list_labels.dart';
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
    final l10n = AppL10n.of(context);
    final list = ref.watch(favoriteListProvider(listId));

    if (list == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(l10n.listHeroEyebrow),
        ),
        body: Center(child: Text(AppL10n.of(context).listMissing)),
      );
    }
    final displayName = favoriteListDisplayName(l10n, list);

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
              title: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: Center(
                child: HeaderActionButton(
                  icon: Icons.arrow_back,
                  tooltip: l10n.back,
                  style: HeaderActionStyle.overlay,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              actions: [
                HeaderActionButton(
                  icon: Icons.more_horiz,
                  tooltip: l10n.more,
                  style: HeaderActionStyle.overlay,
                  onPressed: () => _showMoreSheet(context, ref, list),
                ),
                const SizedBox(width: 6),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _Hero(
                  name: displayName,
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
                padding: MediaListLayout.padding.copyWith(top: 18, bottom: 80),
                sliver: SliverGrid(
                  gridDelegate: const MediaGridDelegate(),
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
                subtitle: favoriteListDisplayName(l10n, list),
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
      error: (_, __) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onLongPress: () => _confirmRemove(context, ref, movieId: movieId),
        child: Container(
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
              style: TextStyle(
                color: c.muted,
                fontFamily: 'Inter',
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
      data: (movie) => MovieCard(
        movie: MovieListItem(
          id: movie.id,
          title: movie.title,
          year: movie.year,
          rating: movie.rating,
          runtime: movie.runtime,
          posterUuid: movie.posterUuid,
          resolutionTier: movie.resolutionTier,
          hasExternalSubtitle: movie.hasExternalSubtitle,
          hasAiSubtitle: movie.hasAiSubtitle,
          hasInternalSubtitle: movie.hasInternalSubtitle,
          watchRecord: movie.watchRecord,
        ),
        posterUrlBuilder: urlBuilder,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)),
        ),
        onLongPress: () => _confirmRemove(
          context,
          ref,
          movieId: movie.id,
          movieTitle: movie.title,
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref, {
    required int movieId,
    String? movieTitle,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppL10n.of(ctx).listRemoveTitle),
        content: Text(
          movieTitle == null
              ? AppL10n.of(ctx).listRemoveMissingConfirm
              : AppL10n.of(ctx).listRemoveConfirm(movieTitle),
        ),
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
      await ref.read(listsProvider.notifier).removeMovie(listId, movieId);
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
