import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/playback/media_browser_audio_playback.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_scaffold.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// MediaBrowser 专辑详情页：专辑信息 + 曲目列表。
///
/// 点击曲目以整专辑为队列播放；「播放全部」从第一首开始。
class MediaBrowserAlbumDetailPage extends ConsumerStatefulWidget {
  const MediaBrowserAlbumDetailPage({super.key, required this.albumId});

  final String albumId;

  @override
  ConsumerState<MediaBrowserAlbumDetailPage> createState() =>
      _MediaBrowserAlbumDetailPageState();
}

class _MediaBrowserAlbumDetailPageState
    extends ConsumerState<MediaBrowserAlbumDetailPage> {
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPosition = ValueNotifier(0.0);
  bool _actionBusy = false;

  String get _albumId => widget.albumId;

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPosition.dispose();
    super.dispose();
  }

  void _syncHeroArt(MediaBrowserItem album, MediaBrowserServerUrls? urls) {
    final url = urls == null || album.primaryImageTag == null
        ? ''
        : urls.poster(album.id, tag: album.primaryImageTag);
    final art = HeroArt(
      movieId: album.id,
      url: url,
      imageHeaders: urls?.imageHeaders,
    );
    final current = _heroArts.value;
    if (current.length == 1 &&
        current.first.movieId == art.movieId &&
        current.first.url == art.url) {
      return;
    }
    _heroArts.value = [art];
  }

  Future<void> _toggleFavorite(MediaBrowserItem album) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(mediaBrowserMediaRepositoryProvider)
          .markFavorite(album.id, !album.userData.isFavorite);
      _invalidateDetail();
    } catch (error) {
      _showError(toApiException(error).message);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _invalidateDetail() {
    ref.invalidate(
      mediaBrowserItemDetailProvider(
        MediaBrowserItemDetailRequest(serverId: _serverId, itemId: _albumId),
      ),
    );
  }

  String get _serverId => ref.read(serverConfigProvider)?.activeServerId ?? '';

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(
      mediaBrowserItemDetailProvider(
        MediaBrowserItemDetailRequest(serverId: _serverId, itemId: _albumId),
      ),
    );
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    final colors = appColors(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppL10n.of(context).loadFailed,
                style: AppText.sectionTitle(context),
              ),
              const SizedBox(height: 8),
              Text(toApiException(error).message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(
                  mediaBrowserItemDetailProvider(
                    MediaBrowserItemDetailRequest(
                      serverId: _serverId,
                      itemId: _albumId,
                    ),
                  ),
                ),
                child: Text(AppL10n.of(context).mediaBrowserRetry),
              ),
            ],
          ),
        ),
        data: (album) {
          _syncHeroArt(album, urls.value);
          return MovieDetailScaffold(
            heroArts: _heroArts,
            heroPosition: _heroPosition,
            hero: MovieDetailHero(
              imageUrl: album.primaryImageTag == null
                  ? null
                  : urls.value?.poster(album.id, tag: album.primaryImageTag),
              title: album.name,
              year: album.productionYear,
              imageHeaders: urls.value?.imageHeaders,
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
                  child: MovieDetailTitle(
                    title: album.name,
                    originalTitle: album.displayArtist,
                    year: album.productionYear,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _playAlbum(),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            AppL10n.of(context).mediaBrowserPlayAll,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _actionBusy
                              ? null
                              : () => _toggleFavorite(album),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: album.userData.isFavorite
                                ? colors.accent
                                : colors.text,
                            side: BorderSide(
                              color: album.userData.isFavorite
                                  ? colors.accent.withValues(alpha: 0.55)
                                  : colors.cardBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          icon: Icon(
                            album.userData.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 16,
                          ),
                          label: Text(
                            album.userData.isFavorite
                                ? AppL10n.of(context).detailFavorited
                                : AppL10n.of(context).mediaBrowserFavoriteAction,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (album.overview?.trim().isNotEmpty == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                    child: MovieDetailPlot(plot: album.overview!),
                  ),
                ),
              SliverToBoxAdapter(child: _TrackSection(album: album)),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
  }

  void _playAlbum() {
    final tracks = ref
        .read(
          mediaBrowserAlbumTracksProvider(
            MediaBrowserAlbumTracksRequest(
              serverId: _serverId,
              albumId: _albumId,
            ),
          ),
        )
        .value;
    if (tracks == null || tracks.isEmpty) return;
    unawaited(
      openMediaBrowserAudioPlayback(
        context,
        ref,
        tracks: tracks,
        startIndex: 0,
      ),
    );
  }
}

/// 曲目列表；点击任一曲目以整专辑队列从该曲播放。
class _TrackSection extends ConsumerWidget {
  const _TrackSection({required this.album});

  final MediaBrowserItem album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId = ref.watch(serverConfigProvider)?.activeServerId ?? '';
    final tracks = ref.watch(
      mediaBrowserAlbumTracksProvider(
        MediaBrowserAlbumTracksRequest(serverId: serverId, albumId: album.id),
      ),
    );
    final colors = appColors(context);
    return tracks.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 22),
        child: Row(
          children: [
            Expanded(
              child: Text(
                toApiException(error).message,
                style: TextStyle(color: colors.muted),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(
                mediaBrowserAlbumTracksProvider(
                  MediaBrowserAlbumTracksRequest(
                    serverId: serverId,
                    albumId: album.id,
                  ),
                ),
              ),
              child: Text(AppL10n.of(context).mediaBrowserRetry),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                AppL10n.of(context).mediaBrowserNoTracks,
                style: AppText.meta(context),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              child: MovieDetailSection(
                title: AppL10n.of(context).mediaBrowserTracks,
                bottom: 0,
                child: const SizedBox.shrink(),
              ),
            ),
            for (final (index, track) in list.indexed)
              _TrackTile(
                track: track,
                albumArtist: album.displayArtist,
                showDisc: _hasMultipleDiscs(list),
                onTap: () => openMediaBrowserAudioPlayback(
                  context,
                  ref,
                  tracks: list,
                  startIndex: index,
                ),
              ),
          ],
        );
      },
    );
  }

  bool _hasMultipleDiscs(List<MediaBrowserItem> tracks) {
    final discs = tracks.map((track) => track.parentIndexNumber ?? 1).toSet();
    return discs.length > 1;
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.onTap,
    this.albumArtist,
    this.showDisc = false,
  });

  final MediaBrowserItem track;
  final VoidCallback onTap;

  /// 专辑艺术家；曲目参与艺术家与之不同时补充显示。
  final String? albumArtist;
  final bool showDisc;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final played = track.userData.played;
    final number = track.indexNumber;
    final duration = mediaBrowserTicksToSeconds(track.runTimeTicks);
    final featured = track.displayArtist?.trim() ?? '';
    final showFeatured =
        featured.isNotEmpty && albumArtist != null && featured != albumArtist;
    final meta = [
      if (showDisc)
        AppL10n.of(context).mediaBrowserDisc(track.parentIndexNumber ?? 1),
      if (showFeatured) featured,
      if (duration > 0)
        '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    number == null || number <= 0
                        ? '–'
                        : number.toString().padLeft(2, '0'),
                    style: AppText.movieCardMeta(context).copyWith(
                      color: played ? colors.muted : colors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardTitle(
                          context,
                        ).copyWith(color: played ? colors.muted : colors.text),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.movieCardMeta(
                            context,
                          ).copyWith(color: colors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (played) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_rounded, size: 16, color: colors.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
