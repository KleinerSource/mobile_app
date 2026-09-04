import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/playback/media_browser_playback.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_action_button.dart';
import 'package:omm/features/media_browser/widgets/media_browser_cast_section.dart';
import 'package:omm/features/media_browser/widgets/media_browser_media_info_section.dart';
import 'package:omm/features/media_browser/widgets/media_browser_similar_section.dart';
import 'package:omm/features/media_browser/widgets/stash_scene_card.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_formatters.dart';
import 'package:omm/features/oh_my_media/movie_detail/media_stream_cards.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_scaffold.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';

/// MediaBrowser 条目详情页（电影 / 单集等可播条目）。
///
/// 结构沿用 OMM/DBO 详情页：hero + 标题 + 播放 + 简介 + 标签块；
/// MediaBrowser 特有操作（收藏、已看标记、转码播放）放在标题下方操作行。
class MediaBrowserMovieDetailPage extends ConsumerWidget {
  const MediaBrowserMovieDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId = ref.watch(serverConfigProvider)?.activeServerId ?? '';
    final value = ref.watch(
      mediaBrowserItemDetailProvider(
        MediaBrowserItemDetailRequest(serverId: serverId, itemId: itemId),
      ),
    );
    final similar = ref.watch(
      mediaBrowserSimilarProvider(
        MediaBrowserSimilarRequest(serverId: serverId, itemId: itemId),
      ),
    );
    final colors = appColors(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          message: toApiException(error).message,
          onRetry: () => ref.invalidate(
            mediaBrowserItemDetailProvider(
              MediaBrowserItemDetailRequest(serverId: serverId, itemId: itemId),
            ),
          ),
        ),
        data: (item) => _MediaBrowserDetailBody(item: item, similar: similar),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.loadFailed, style: AppText.sectionTitle(context)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l.mediaBrowserRetry)),
        ],
      ),
    );
  }
}

class _MediaBrowserDetailBody extends ConsumerStatefulWidget {
  const _MediaBrowserDetailBody({required this.item, required this.similar});

  final MediaBrowserItem item;
  final AsyncValue<List<MediaBrowserItem>> similar;

  @override
  ConsumerState<_MediaBrowserDetailBody> createState() =>
      _MediaBrowserDetailBodyState();
}

class _MediaBrowserDetailBodyState
    extends ConsumerState<_MediaBrowserDetailBody> {
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPosition = ValueNotifier(0.0);
  bool _actionBusy = false;
  String? _selectedMediaSourceId;
  String? _selectedVideoPartId;

  @override
  void initState() {
    super.initState();
    _syncHeroArt(ref.read(mediaBrowserServerUrlsProvider).value);
  }

  @override
  void didUpdateWidget(covariant _MediaBrowserDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncHeroArt(ref.read(mediaBrowserServerUrlsProvider).value);
    final sourceIds = widget.item.mediaSources
        .map((source) => source.id)
        .toSet();
    if (_selectedMediaSourceId == null ||
        !sourceIds.contains(_selectedMediaSourceId)) {
      _selectedMediaSourceId = widget.item.mediaSources.isEmpty
          ? null
          : widget.item.mediaSources.first.id;
    }
    final partIds = widget.item.videoParts.map((part) => part.id).toSet();
    if (_selectedVideoPartId != null &&
        !partIds.contains(_selectedVideoPartId)) {
      _selectedVideoPartId = null;
    }
  }

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPosition.dispose();
    super.dispose();
  }

  void _syncHeroArt(MediaBrowserServerUrls? urls) {
    final item = widget.item;
    final url = urls?.heroImage(item) ?? '';
    final art = HeroArt(
      movieId: item.id,
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

  Future<void> _toggleFavorite() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(mediaBrowserMediaRepositoryProvider)
          .markFavorite(widget.item.id, !widget.item.userData.isFavorite);
      if (mounted) _invalidateDetail();
    } catch (error) {
      _showError(toApiException(error).message);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _togglePlayed() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(mediaBrowserMediaRepositoryProvider)
          .markPlayed(widget.item.id, !widget.item.userData.played);
      if (mounted) {
        _invalidateDetail();
        ref.invalidate(mediaBrowserNextUpProvider);
      }
    } catch (error) {
      _showError(toApiException(error).message);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _invalidateDetail() {
    final serverId = ref.read(serverConfigProvider)?.activeServerId ?? '';
    ref.invalidate(
      mediaBrowserItemDetailProvider(
        MediaBrowserItemDetailRequest(
          serverId: serverId,
          itemId: widget.item.id,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  MediaBrowserMediaSourceDto? get _selectedMediaSource {
    final selectedPart = _selectedVideoPart;
    if (selectedPart != null) {
      final id = selectedPart.mediaSourceId ?? selectedPart.id;
      return MediaBrowserMediaSourceDto(
        id: id,
        name: selectedPart.name,
        path: selectedPart.path,
        container: selectedPart.container,
        sizeInBytes: selectedPart.sizeInBytes,
        supportsDirectPlay: true,
        supportsDirectStream: true,
        mediaStreams: selectedPart.mediaStreams,
      );
    }
    final sources = widget.item.mediaSources;
    if (sources.isEmpty) return null;
    for (final source in sources) {
      if (source.id == _selectedMediaSourceId) return source;
    }
    return sources.first;
  }

  void _selectMediaSource(String id) {
    if (_selectedMediaSourceId == id) return;
    setState(() => _selectedMediaSourceId = id);
  }

  MediaBrowserVideoPart? get _selectedVideoPart {
    final selectedId = _selectedVideoPartId;
    if (selectedId == null) return null;
    for (final part in widget.item.videoParts) {
      if (part.id == selectedId) return part;
    }
    return null;
  }

  void _selectVideoPart(String id) {
    final next = id.trim().isEmpty ? null : id;
    if (_selectedVideoPartId == next) return;
    setState(() => _selectedVideoPartId = next);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    _syncHeroArt(urls.value);
    final posterUrl = item.primaryImageTag == null
        ? null
        : urls.value?.poster(item.id, tag: item.primaryImageTag);
    final runtimeMinutes = item.runtimeMinutes;
    final videoParts = item.videoParts;
    final selectedVideoPart = _selectedVideoPart;
    final selectedMediaSource = _selectedMediaSource;
    final isFeiniu =
        ref.watch(mediaBrowserConfigProvider)?.project == ServerProject.feiniu;
    final isStash =
        ref.watch(mediaBrowserConfigProvider)?.project == ServerProject.stash;
    final hasFeiniuSourceVariants = isFeiniu && item.mediaSources.length > 1;
    final playbackMediaSourceId = selectedVideoPart == null
        ? selectedMediaSource?.id
        : selectedVideoPart.mediaSourceId;
    final castPeople = [
      for (final person in item.people)
        if (person.type == 'Actor' && person.name.trim().isNotEmpty) person,
    ];
    final directorPeople = [
      for (final person in item.people)
        if (person.type == 'Director' && person.name.trim().isNotEmpty) person,
    ];
    // fnos 列表接口不支持按人物过滤，点击仅对 Emby/Jellyfin 开放。
    final void Function(MediaBrowserPerson)? onOpenPerson = isFeiniu
        ? null
        : (person) => openMediaBrowserPersonWorks(
            context,
            personId: person.id,
            personName: person.name,
          );
    return MovieDetailScaffold(
      heroArts: _heroArts,
      heroPosition: _heroPosition,
      hero: MovieDetailHero(
        imageUrl: posterUrl,
        title: item.name,
        year: item.productionYear,
        imageAlignment: isStash
            ? Alignment.center
            : const Alignment(0, -0.6),
        imageHeaders: urls.value?.imageHeaders,
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
            child: isStash
                ? StashSceneInfo(item: item, padding: EdgeInsets.zero)
                : MovieDetailTitle(
                    title: item.name,
                    year: item.productionYear,
                    runtime: runtimeMinutes > 0 ? runtimeMinutes : null,
                    rating: item.communityRating,
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: _ActionRow(
              canPlay: item.isPlayable,
              favorite: item.userData.isFavorite,
              played: item.userData.played,
              showUserActions: !isStash,
              showTranscode: !isStash,
              busy: _actionBusy,
              onPlay: () => openMediaBrowserPlayback(
                context,
                ref,
                item: item,
                part: selectedVideoPart,
                playAllParts:
                    selectedVideoPart == null && !hasFeiniuSourceVariants,
                mediaSourceId: playbackMediaSourceId,
              ),
              // 与 OMM 详情页一致：长按播放先选内核（libmpv / KSPlayer）。
              onLongPressPlay: playbackEnginePickerEnabled
                  ? () => openMediaBrowserPlaybackWithEnginePicker(
                      context,
                      ref,
                      item: item,
                      part: selectedVideoPart,
                      playAllParts:
                          selectedVideoPart == null && !hasFeiniuSourceVariants,
                      mediaSourceId: playbackMediaSourceId,
                    )
                  : null,
              onTranscodePlay: () => openMediaBrowserPlayback(
                context,
                ref,
                item: item,
                transcode: true,
                part: selectedVideoPart,
                playAllParts:
                    selectedVideoPart == null && !hasFeiniuSourceVariants,
                mediaSourceId: playbackMediaSourceId,
              ),
              onToggleFavorite: _toggleFavorite,
              onTogglePlayed: _togglePlayed,
            ),
          ),
        ),
        if (videoParts.length > 1 && !hasFeiniuSourceVariants)
          SliverToBoxAdapter(
            child: _MediaPartSelector(
              parts: videoParts,
              selectedId: _selectedVideoPartId,
              onChanged: _selectVideoPart,
            ),
          ),
        if (item.mediaSources.length > 1 && selectedVideoPart == null)
          SliverToBoxAdapter(
            child: _MediaSourceSelector(
              item: item,
              sources: item.mediaSources,
              selectedId: selectedMediaSource?.id ?? '',
              onChanged: _selectMediaSource,
            ),
          ),
        if (item.overview?.trim().isNotEmpty == true &&
            (!isStash || item.overview!.trim() != item.name.trim()))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              child: MovieDetailPlot(plot: item.overview!),
            ),
          ),
        if (!isStash && item.genres.isNotEmpty)
          SliverToBoxAdapter(
            child: _ChipSection(
              title: AppL10n.of(context).mediaBrowserGenres,
              labels: item.genres,
            ),
          ),
        if (!isStash && directorPeople.isNotEmpty)
          SliverToBoxAdapter(
            child: MediaBrowserCastSection(
              title: AppL10n.of(context).mediaBrowserDirectors,
              people: directorPeople,
              urls: urls.value,
              onOpenPerson: onOpenPerson,
            ),
          ),
        if (!isStash && castPeople.isNotEmpty)
          SliverToBoxAdapter(
            child: MediaBrowserCastSection(
              people: castPeople,
              urls: urls.value,
              onOpenPerson: onOpenPerson,
            ),
          ),
        widget.similar.when(
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (items) => items.isEmpty
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : SliverToBoxAdapter(
                  child: MediaBrowserSimilarSection(items: items),
                ),
        ),
        SliverToBoxAdapter(
          child: MediaBrowserMediaInfoSection(
            item: item,
            source: selectedMediaSource,
            runTimeTicks: selectedVideoPart?.runTimeTicks,
          ),
        ),
        if (_hasDetails(item, selectedMediaSource))
          SliverToBoxAdapter(
            child: MovieDetailSection(
              title: AppL10n.of(context).mediaBrowserDetails,
              child: _DetailsTable(item: item, source: selectedMediaSource),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }

  bool _hasDetails(MediaBrowserItem item, MediaBrowserMediaSourceDto? source) {
    if (item.originalTitle?.trim().isNotEmpty == true) return true;
    if (item.seriesName?.trim().isNotEmpty == true) return true;
    if (source == null) return false;
    if (source.mediaStreams.isNotEmpty) return true;
    return source.path?.trim().isNotEmpty == true ||
        source.container?.trim().isNotEmpty == true ||
        source.sizeInBytes != null;
  }
}

class _MediaSourceSelector extends StatelessWidget {
  const _MediaSourceSelector({
    required this.item,
    required this.sources,
    required this.selectedId,
    required this.onChanged,
  });

  final MediaBrowserItem item;
  final List<MediaBrowserMediaSourceDto> sources;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return MovieDetailFullBleedSection(
      header: Text(
        l.mediaBrowserMediaSources,
        style: AppText.sectionTitle(context),
      ),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < sources.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                _MediaSelectionCard(
                  label: _mediaSourceSummary(
                    sources[index],
                    unknown: l.commonUnknown,
                  ),
                  selected: sources[index].id == selectedId,
                  onTap: () => onChanged(sources[index].id),
                  onLongPress: () => unawaited(
                    _showMediaSourceDetails(context, item, sources[index]),
                  ),
                  colors: colors,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaSelectionCard extends StatelessWidget {
  const _MediaSelectionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    required this.colors,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? colors.accent.withValues(alpha: 0.14)
            : colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? colors.accent : colors.cardBorder,
          width: selected ? 1.8 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Center(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.cardTitle(context).copyWith(
                  color: selected ? colors.accent : colors.text,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _mediaSourceSummary(
  MediaBrowserMediaSourceDto source, {
  required String unknown,
}) {
  final video = _mediaSourceVideoStream(source);
  if (video == null) return unknown;
  final resolution = _mediaSourceResolution(video, unknown);
  final range = _mediaSourceRange(video, unknown);
  return '$resolution $range';
}

MediaBrowserMediaStream? _mediaSourceVideoStream(
  MediaBrowserMediaSourceDto source,
) {
  for (final stream in source.mediaStreams) {
    if (stream.type.trim().toLowerCase() == 'video') return stream;
  }
  return null;
}

String _mediaSourceResolution(MediaBrowserMediaStream stream, String unknown) {
  final height = stream.height;
  if (height != null && height >= 2160) return '4K';
  if (height != null && height > 0) return '$height';
  return unknown;
}

String _mediaSourceRange(MediaBrowserMediaStream stream, String unknown) {
  final declared = (stream.videoRangeType ?? '').trim().toLowerCase();
  if (declared.contains('dovi') || declared.contains('dolby')) {
    return 'Dolby Vision';
  }
  if (declared.contains('hdr10') || declared.contains('hdr10+')) {
    return 'HDR10';
  }
  if (declared.contains('hlg')) return 'HLG';
  if (declared == 'sdr') return 'SDR';

  final transfer = (stream.colorTransfer ?? '').trim().toLowerCase();
  if (transfer == 'smpte2084' || transfer.contains('pq')) return 'HDR10';
  if (transfer == 'arib-std-b67' || transfer.contains('hlg')) return 'HLG';
  return unknown;
}

String _mediaSourceFileName(MediaBrowserMediaSourceDto source, String unknown) {
  final name = source.name?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final path = source.path?.trim() ?? '';
  if (path.isEmpty) return unknown;
  final normalized = path.replaceAll('\\', '/');
  final fileName = normalized.split('/').last.trim();
  return fileName.isEmpty ? unknown : fileName;
}

Future<void> _showMediaSourceDetails(
  BuildContext context,
  MediaBrowserItem item,
  MediaBrowserMediaSourceDto source,
) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MediaSourceDetailsSheet(item: item, source: source),
  );
}

class _MediaSourceDetailsSheet extends StatelessWidget {
  const _MediaSourceDetailsSheet({required this.item, required this.source});

  final MediaBrowserItem item;
  final MediaBrowserMediaSourceDto source;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final detail = mediaBrowserMediaInfoDetail(item, source: source);
    final fileName = _mediaSourceFileName(source, l.commonUnknown);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              icon: Icons.movie_outlined,
              title: l.mediaBrowserDetails,
              subtitle: fileName,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 14),
            _MediaSourceDetailRow(
              label: l.mediaBrowserFilePath,
              value: source.path?.trim().isNotEmpty == true
                  ? source.path!.trim()
                  : l.commonUnknown,
            ),
            if (source.container?.trim().isNotEmpty == true)
              _MediaSourceDetailRow(
                label: l.mediaBrowserContainer,
                value: source.container!.trim(),
              ),
            if (source.sizeInBytes != null && source.sizeInBytes! > 0)
              _MediaSourceDetailRow(
                label: l.mediaBrowserFileSize,
                value: formatFileSize(source.sizeInBytes!),
              ),
            const SizedBox(height: 12),
            if (detail != null)
              MediaStreamCards(detail: detail)
            else
              Text(l.commonUnknown, style: AppText.meta(context)),
          ],
        ),
      ),
    );
  }
}

class _MediaSourceDetailRow extends StatelessWidget {
  const _MediaSourceDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: AppText.movieCardMeta(
                context,
              ).copyWith(color: colors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppText.movieCardMeta(
                context,
              ).copyWith(color: colors.text, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPartSelector extends StatelessWidget {
  const _MediaPartSelector({
    required this.parts,
    required this.selectedId,
    required this.onChanged,
  });

  final List<MediaBrowserVideoPart> parts;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = appColors(context);
    return MovieDetailFullBleedSection(
      header: Text(
        l.mediaBrowserVideoParts,
        style: AppText.sectionTitle(context),
      ),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              for (var index = 0; index < parts.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                _MediaSelectionCard(
                  label: parts[index].name?.trim().isNotEmpty == true
                      ? parts[index].name!.trim()
                      : l.mediaBrowserVideoPartNumber(index + 1),
                  selected: parts[index].id == selectedId,
                  onTap: () => onChanged(parts[index].id),
                  colors: colors,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.canPlay,
    required this.favorite,
    required this.played,
    required this.showUserActions,
    required this.showTranscode,
    required this.busy,
    required this.onPlay,
    required this.onLongPressPlay,
    required this.onTranscodePlay,
    required this.onToggleFavorite,
    required this.onTogglePlayed,
  });

  final bool canPlay;
  final bool favorite;
  final bool played;
  final bool showUserActions;
  final bool showTranscode;
  final bool busy;
  final VoidCallback onPlay;
  final VoidCallback? onLongPressPlay;
  final VoidCallback onTranscodePlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePlayed;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPlay)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: busy ? null : onPlay,
              onLongPress: busy || onLongPressPlay == null
                  ? null
                  : onLongPressPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.text,
                foregroundColor: colors.bg,
                disabledBackgroundColor: colors.surfaceAlt,
                disabledForegroundColor: colors.muted,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(
                l.detailPlay,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (canPlay) const SizedBox(height: 10),
        if (showUserActions || (canPlay && showTranscode))
          Row(
            children: [
              if (showUserActions) ...[
                Expanded(
                  child: MediaBrowserActionButton(
                    icon: favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: favorite
                        ? l.detailFavorited
                        : l.mediaBrowserFavoriteAction,
                    active: favorite,
                    onPressed: busy ? null : onToggleFavorite,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MediaBrowserActionButton(
                    icon: played
                        ? Icons.task_alt_rounded
                        : Icons.check_circle_outline_rounded,
                    label: played
                        ? l.mediaBrowserWatched
                        : l.mediaBrowserMarkWatched,
                    active: played,
                    onPressed: busy ? null : onTogglePlayed,
                  ),
                ),
              ],
              if (canPlay && showTranscode) ...[
                if (showUserActions) const SizedBox(width: 10),
                Expanded(
                  child: MediaBrowserActionButton(
                    icon: Icons.auto_awesome_rounded,
                    label: l.mediaBrowserTranscodePlay,
                    onPressed: busy ? null : onTranscodePlay,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.title, required this.labels});

  final String title;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final items = labels
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    return MovieDetailSection(
      title: title,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < items.length; i++)
            HueChip(label: items[i], hue: AppHues.all[i % AppHues.all.length]),
        ],
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.item, required this.source});

  final MediaBrowserItem item;
  final MediaBrowserMediaSourceDto? source;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final selectedSource = source;
    final rows = <(String, String)>[
      if (item.originalTitle?.trim().isNotEmpty == true)
        (l.mediaBrowserOriginalTitle, item.originalTitle!),
      if (item.seriesName?.trim().isNotEmpty == true)
        (l.mediaBrowserSeriesLabel, item.seriesName!),
      if (selectedSource?.path?.trim().isNotEmpty == true)
        (l.mediaBrowserFilePath, selectedSource!.path!),
      if (selectedSource?.container?.trim().isNotEmpty == true)
        (l.mediaBrowserContainer, selectedSource!.container!),
      if (selectedSource?.sizeInBytes != null &&
          selectedSource!.sizeInBytes! > 0)
        (l.mediaBrowserFileSize, formatFileSize(selectedSource.sizeInBytes!)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    label,
                    style: AppText.movieCardMeta(
                      context,
                    ).copyWith(color: colors.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: AppText.movieCardMeta(
                      context,
                    ).copyWith(color: colors.text, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
