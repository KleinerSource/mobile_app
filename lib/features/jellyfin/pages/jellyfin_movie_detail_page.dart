import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/jellyfin/jellyfin_playback.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/jellyfin/providers/jellyfin_providers.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_scaffold.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';
import 'package:omm/shared/filter_chip.dart';

/// Jellyfin 条目详情页（电影 / 单集等可播条目）。
///
/// 结构沿用 OMM/Emby 详情页：hero + 标题 + 播放 + 简介 + 标签块；
/// Jellyfin 特有操作（收藏、已看标记、转码播放）放在标题下方操作行。
class JellyfinMovieDetailPage extends ConsumerWidget {
  const JellyfinMovieDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId = ref.watch(serverConfigProvider)?.activeServerId ?? '';
    final value = ref.watch(
      jellyfinItemDetailProvider(
        JellyfinItemDetailRequest(serverId: serverId, itemId: itemId),
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
            jellyfinItemDetailProvider(
              JellyfinItemDetailRequest(serverId: serverId, itemId: itemId),
            ),
          ),
        ),
        data: (item) => _JellyfinDetailBody(item: item),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('加载失败', style: AppText.sectionTitle(context)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _JellyfinDetailBody extends ConsumerStatefulWidget {
  const _JellyfinDetailBody({required this.item});

  final MediaBrowserItem item;

  @override
  ConsumerState<_JellyfinDetailBody> createState() => _JellyfinDetailBodyState();
}

class _JellyfinDetailBodyState extends ConsumerState<_JellyfinDetailBody> {
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPosition = ValueNotifier(0.0);
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _syncHeroArt();
  }

  @override
  void didUpdateWidget(covariant _JellyfinDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncHeroArt();
  }

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPosition.dispose();
    super.dispose();
  }

  void _syncHeroArt() {
    final item = widget.item;
    final urls = ref.read(jellyfinServerUrlsProvider).value;
    final url = urls == null
        ? ''
        : item.backdropImageTags.isEmpty
        ? (item.primaryImageTag == null ? '' : urls.poster(item.id))
        : urls.backdrop(item.id);
    final art = HeroArt(movieId: item.id, url: url);
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
          .read(jellyfinMediaRepositoryProvider)
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
          .read(jellyfinMediaRepositoryProvider)
          .markPlayed(widget.item.id, !widget.item.userData.played);
      if (mounted) {
        _invalidateDetail();
        ref.invalidate(jellyfinNextUpProvider);
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
      jellyfinItemDetailProvider(
        JellyfinItemDetailRequest(serverId: serverId, itemId: widget.item.id),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final urls = ref.watch(jellyfinServerUrlsProvider);
    final posterUrl = item.primaryImageTag == null
        ? null
        : urls.value?.poster(item.id);
    final runtimeMinutes = item.runtimeMinutes;
    final actors = [
      for (final person in item.people)
        if (person.name.trim().isNotEmpty)
          person.role?.trim().isNotEmpty == true
              ? '${person.name}（${person.role}）'
              : person.name,
    ];
    final directors = [
      for (final person in item.people)
        if (person.type == 'Director' && person.name.trim().isNotEmpty)
          person.name,
    ];
    return MovieDetailScaffold(
      heroArts: _heroArts,
      heroPosition: _heroPosition,
      hero: MovieDetailHero(
        imageUrl: posterUrl,
        title: item.name,
        year: item.productionYear,
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
            child: MovieDetailTitle(
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
              busy: _actionBusy,
              onPlay: () => openJellyfinPlayback(context, ref, item: item),
              // 与 OMM 详情页一致：长按播放先选内核（libmpv / KSPlayer）。
              onLongPressPlay: playbackEnginePickerEnabled
                  ? () =>
                        openJellyfinPlaybackWithEnginePicker(context, ref, item: item)
                  : null,
              onTranscodePlay: () =>
                  openJellyfinPlayback(context, ref, item: item, transcode: true),
              onToggleFavorite: _toggleFavorite,
              onTogglePlayed: _togglePlayed,
            ),
          ),
        ),
        if (item.overview?.trim().isNotEmpty == true)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              child: MovieDetailPlot(plot: item.overview!),
            ),
          ),
        if (item.genres.isNotEmpty)
          SliverToBoxAdapter(
            child: _ChipSection(title: '类型', labels: item.genres),
          ),
        if (directors.isNotEmpty)
          SliverToBoxAdapter(
            child: _ChipSection(title: '导演', labels: directors),
          ),
        if (actors.isNotEmpty)
          SliverToBoxAdapter(
            child: _ChipSection(title: '演员', labels: actors),
          ),
        if (_hasDetails(item))
          SliverToBoxAdapter(
            child: MovieDetailSection(
              title: '详细信息',
              child: _DetailsTable(item: item),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }

  bool _hasDetails(MediaBrowserItem item) {
    if (item.seriesName?.trim().isNotEmpty == true) return true;
    final source = item.mediaSources.isEmpty ? null : item.mediaSources.first;
    if (source == null) return false;
    return source.path?.trim().isNotEmpty == true ||
        source.container?.trim().isNotEmpty == true ||
        source.sizeInBytes != null;
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.canPlay,
    required this.favorite,
    required this.played,
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
  final bool busy;
  final VoidCallback onPlay;
  final VoidCallback? onLongPressPlay;
  final VoidCallback onTranscodePlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePlayed;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
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
              label: const Text(
                '播放',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (canPlay) const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: favorite ? '已收藏' : '收藏',
                active: favorite,
                onPressed: busy ? null : onToggleFavorite,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: played
                    ? Icons.task_alt_rounded
                    : Icons.check_circle_outline_rounded,
                label: played ? '已看' : '标记已看',
                active: played,
                onPressed: busy ? null : onTogglePlayed,
              ),
            ),
            if (canPlay) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.auto_awesome_rounded,
                  label: '转码播放',
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? colors.accent : colors.text,
        side: BorderSide(
          color: active
              ? colors.accent.withValues(alpha: 0.55)
              : colors.cardBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
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
            HueChip(
              label: items[i],
              hue: AppHues.all[i % AppHues.all.length],
            ),
        ],
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.item});

  final MediaBrowserItem item;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final source = item.mediaSources.isEmpty
        ? null
        : item.mediaSources.first;
    final rows = <(String, String)>[
      if (item.seriesName?.trim().isNotEmpty == true)
        ('所属剧集', item.seriesName!),
      if (source?.path?.trim().isNotEmpty == true) ('文件路径', source!.path!),
      if (source?.container?.trim().isNotEmpty == true)
        ('容器', source!.container!),
      if (source?.sizeInBytes != null && source!.sizeInBytes! > 0)
        ('文件大小', _formatSize(source.sizeInBytes!)),
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
                    style: AppText.movieCardMeta(context).copyWith(
                      color: colors.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: AppText.movieCardMeta(context).copyWith(
                      color: colors.text,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _formatSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit <= 1 ? 0 : 1)} ${units[unit]}';
}
