import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/models/related_movie.dart';
import '../../core/models/resource.dart';
import '../../core/models/actor.dart';
import '../../core/models/watch_record.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/filter_chip.dart';
import '../../shared/glass_menu.dart';
import '../../shared/movie_card.dart';
import '../../shared/poster.dart';
import '../../shared/actor_avatar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/favorites_providers.dart';
import '../lists/add_to_list_sheet.dart';
import '../movies/movies_providers.dart';
import '../player/player_page.dart';
import '../player/player_queue.dart';
import '../resources/resource_movies_page.dart';
import 'actor_movies_page.dart';
import 'dbo_diff_sheet.dart';
import 'resources_sheet.dart';
import '../resources/resources_repository.dart';
import 'movie_editor_sheet.dart';
import 'movie_detail_formatters.dart';
import 'cover_badges.dart';
import 'media_stream_cards.dart';
import 'thunder_subtitle_sheet.dart';
import '../home/home_movie_view_state.dart';

class MovieDetailPage extends ConsumerStatefulWidget {
  const MovieDetailPage({super.key, required this.movieId});
  final int movieId;

  @override
  ConsumerState<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends ConsumerState<MovieDetailPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(homeMovieViewStateProvider).markMovieViewed(widget.movieId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(movieDetailProvider(widget.movieId));
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final c = appColors(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败', style: AppText.sectionTitle(context)),
                const SizedBox(height: 8),
                Text('$e', style: AppText.body(context), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (movie) => _DetailBody(
          movie: movie,
          urlBuilder: urlBuilder,
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.movie, required this.urlBuilder});
  final MovieDetail movie;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final favStatus = ref.watch(favoriteStatusProvider);
    // 初始化收藏状态种子
    if (!favStatus.containsKey(movie.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(favoriteStatusProvider.notifier).seed(movie.id, movie.isFavorited);
      });
    }
    final isFavorited = favStatus[movie.id] ?? movie.isFavorited;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 320,
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
                child: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: isFavorited ? c.accent : null,
                ),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final l = AppL10n.of(context);
                try {
                  final value = await ref
                      .read(favoriteStatusProvider.notifier)
                      .toggle(movie.id);
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                        value ? l.detailFavorited : l.detailUnfavorited),
                    duration: const Duration(seconds: 1),
                  ));
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('操作失败: $e')),
                  );
                }
              },
            ),
            const SizedBox(width: 6),
            _MoreMenuButton(movie: movie),
            const SizedBox(width: 6),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroHeader(movie: movie, urlBuilder: urlBuilder),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: _TitleBlock(movie: movie),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: _ActionRow(movie: movie),
          ),
        ),
        if (movie.plot != null && movie.plot!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              child: Text(
                movie.plot!,
                style: AppText.body(context).copyWith(height: 1.55),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _ExtraFanartSection(
            movieId: movie.id,
            canFetch: movie.num?.trim().isNotEmpty == true,
          ),
        ),
        if (movie.actors.isNotEmpty)
          SliverToBoxAdapter(
            child: _CastSection(actors: movie.actors),
          ),
        SliverToBoxAdapter(
          child: _ActorRelatedMoviesSection(
            movie: movie,
            urlBuilder: urlBuilder,
          ),
        ),
        // 分组显示 series / genres / tags
        if (movie.series != null)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: '系列',
              items: [movie.series!],
              kind: ResourceKind.series,
              hueOffset: 0,
              prefix: '◇ ',
            ),
          ),
        if (movie.genres.isNotEmpty)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: '分类',
              items: movie.genres,
              kind: ResourceKind.genre,
              hueOffset: 0,
            ),
          ),
        if (movie.tags.isNotEmpty)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: '标签',
              items: movie.tags,
              kind: ResourceKind.tag,
              hueOffset: 2,
              prefix: '# ',
            ),
          ),
        SliverToBoxAdapter(
          child: _DetailsTable(movie: movie),
        ),
        SliverToBoxAdapter(
          child: _MediaInfoSection(movieId: movie.id),
        ),
        SliverToBoxAdapter(
          child: _RelatedFilesSection(movie: movie),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }
}

class _HeroHeader extends ConsumerWidget {
  const _HeroHeader({required this.movie, required this.urlBuilder});
  final MovieDetail movie;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    // fanart fallback poster fallback thumb
    final heroUuid = movie.fanartUuid?.isNotEmpty == true
        ? movie.fanartUuid
        : (movie.posterUuid?.isNotEmpty == true ? movie.posterUuid : null);

    // 技术徽章(编码/HDR/字幕/破解/UHD...)基于媒体探测 + 文件名后缀
    final video = ref.watch(mediaInfoProvider(movie.id)).value?.streams.video;
    final badges = buildCoverBadges(
      filePath: movie.filePath,
      fileSize: movie.fileSize,
      video: video,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // ---------- 横版主图 (满铺 cover) ----------
        if (heroUuid != null)
          Poster(
            url: urlBuilder(heroUuid),
            title: movie.title,
            year: movie.year,
            aspectRatio: 16 / 9,
            radius: 0,
            imageAlignment: const Alignment(0, -0.6),
          )
        else
          ColoredBox(color: c.surfaceAlt),
        // ---------- 底部渐变让标题区可读 ----------
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.bg.withValues(alpha: 0.0),
                c.bg.withValues(alpha: 0.0),
                c.bg.withValues(alpha: 0.85),
                c.bg,
              ],
              stops: const [0.0, 0.45, 0.85, 1.0],
            ),
          ),
        ),
        // ---------- 顶部小渐变让 AppBar 按钮可读 ----------
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35],
            ),
          ),
        ),
        // ---------- 底部技术徽章 ----------
        if (badges.isNotEmpty)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CoverBadgeRow(badges: badges),
            ),
          ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    const baseStyle = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
      letterSpacing: 1.4,
    );
    final dot = TextSpan(text: '  ·  ', style: baseStyle.copyWith(color: c.muted));
    final spans = <InlineSpan>[];
    void add(InlineSpan s) {
      if (spans.isNotEmpty) spans.add(dot);
      spans.add(s);
    }

    if (movie.year != null) {
      add(TextSpan(text: '${movie.year}', style: baseStyle.copyWith(color: c.muted)));
    }
    if (movie.runtime != null && movie.runtime! > 0) {
      add(TextSpan(
        text: '${movie.runtime} MIN',
        style: baseStyle.copyWith(color: c.accent),
      ));
    }
    if (movie.country != null && movie.country!.isNotEmpty) {
      add(TextSpan(
        text: movie.country!.toUpperCase(),
        style: baseStyle.copyWith(color: c.muted),
      ));
    }
    if (movie.rating != null && movie.rating! > 0) {
      add(TextSpan(
        text: '★ ${movie.rating!.toStringAsFixed(1)}',
        style: baseStyle.copyWith(color: c.warning),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          movie.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.text,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.84,
            height: 1.1,
          ),
        ),
        if (movie.originalTitle != null && movie.originalTitle != movie.title) ...[
          const SizedBox(height: 4),
          Text(
            movie.originalTitle!,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontStyle: FontStyle.italic, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        if (spans.isNotEmpty)
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: spans),
          ),
      ],
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.movie});

  final MovieDetail movie;

  int _startPositionSec(WatchRecord? watchRecord) {
    if (watchRecord != null) return watchRecord.resumePositionSec;

    final wr = movie.watchRecord;
    if (wr == null || wr.completed) return 0;
    final r = wr.progressRatio.clamp(0.0, 1.0);
    final runtimeMin = movie.runtime ?? 0;
    if (runtimeMin <= 0 || r <= 0) return 0;
    return (runtimeMin * 60 * r).round();
  }

  double _progressRatio(WatchRecord? watchRecord) {
    if (watchRecord != null) {
      if (watchRecord.completed || watchRecord.durationSec <= 0) return 0;
      return (watchRecord.lastPositionSec / watchRecord.durationSec)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    final summary = movie.watchRecord;
    if (summary == null || summary.completed) return 0;
    return summary.progressRatio.clamp(0.0, 1.0).toDouble();
  }

  List<PlayerQueueItem> _playerQueue(int startPositionSec) {
    final items = <PlayerQueueItem>[
      PlayerQueueItem(
        movieId: movie.id,
        title: movie.title,
        startPositionSec: startPositionSec,
        part: movie.moviePart,
      ),
      for (final related in movie.partMovies)
        if (related.id != movie.id)
          PlayerQueueItem(
            movieId: related.id,
            title: related.title,
            part: related.moviePart,
          ),
    ];
    if (items.every((item) => item.part?.isNotEmpty == true)) {
      items.sort(_comparePlayerQueueItems);
    }
    return items;
  }

  int _comparePlayerQueueItems(PlayerQueueItem a, PlayerQueueItem b) {
    final aPart = _partNumber(a.part);
    final bPart = _partNumber(b.part);
    if (aPart == null || bPart == null) return 0;
    return aPart.compareTo(bPart);
  }

  int? _partNumber(String? part) {
    final match = RegExp(r'(\d+)').firstMatch(part ?? '');
    return int.tryParse(match?.group(1) ?? '');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final watchRecord =
        ref.watch(movieWatchRecordProvider(movie.id)).valueOrNull;
    final startPositionSec = _startPositionSec(watchRecord);
    final progressRatio = _progressRatio(watchRecord);
    final playLabel = startPositionSec > 0
        ? '${l.detailPlay} (${formatResumePosition(startPositionSec)})'
        : l.detailPlay;
    final playerQueue = _playerQueue(startPositionSec);
    final playerQueueIndex =
        playerQueue.indexWhere((item) => item.movieId == movie.id);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.text,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  if (progressRatio > 0)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progressRatio,
                          heightFactor: 1,
                          child: ColoredBox(
                            color: c.bg.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () async {
                      await PlayerPage.open(
                        context,
                        movieId: movie.id,
                        title: movie.title,
                        startPositionSec: startPositionSec,
                        queue: playerQueue,
                        queueIndex: playerQueueIndex < 0 ? 0 : playerQueueIndex,
                      );
                      if (context.mounted) {
                        ref.invalidate(movieWatchRecordProvider(movie.id));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: c.bg,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow, size: 18),
                        const SizedBox(width: 6),
                        Text(playLabel,
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () => AddToListSheet.show(
              context,
              movieId: movie.id,
              movieTitle: movie.title,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.text,
              side: BorderSide(color: c.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              AppL10n.of(context).detailAddList,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtraFanartSection extends ConsumerStatefulWidget {
  const _ExtraFanartSection({required this.movieId, required this.canFetch});

  final int movieId;
  final bool canFetch;

  @override
  ConsumerState<_ExtraFanartSection> createState() =>
      _ExtraFanartSectionState();
}

class _ExtraFanartSectionState extends ConsumerState<_ExtraFanartSection> {
  bool _fetching = false;

  Future<void> _fetchExtraFanarts() async {
    if (_fetching || !widget.canFetch) return;
    setState(() => _fetching = true);
    try {
      await ref
          .read(moviesRepositoryProvider)
          .downloadExtraFanarts(widget.movieId);
      if (!mounted) return;
      ref.invalidate(extraFanartsProvider(widget.movieId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('预览图获取完成')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取预览图失败: ${toApiException(error).message}')),
      );
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Widget _header(BuildContext context, {required bool hasImages}) {
    return Row(
      children: [
        Expanded(
          child: Text('预览图', style: AppText.sectionTitle(context)),
        ),
        if (widget.canFetch)
          TextButton.icon(
            onPressed: _fetching ? null : _fetchExtraFanarts,
            icon: _fetching
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 17),
            label: Text(hasImages ? '重新获取' : '获取'),
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, String message, IconData icon) {
    final c = appColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.muted, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.body(context))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(extraFanartsProvider(widget.movieId));
    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, hasImages: false),
            const SizedBox(height: 12),
            _emptyState(context, '正在加载预览图', Icons.hourglass_empty_rounded),
          ],
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, hasImages: false),
            const SizedBox(height: 12),
            _emptyState(
              context,
              '预览图加载失败: ${toApiException(error).message}',
              Icons.broken_image_outlined,
            ),
          ],
        ),
      ),
      data: (urls) {
        if (urls.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, hasImages: false),
                const SizedBox(height: 12),
                _emptyState(context, '暂无预览图', Icons.photo_library_outlined),
              ],
            ),
          );
        }

        final cardWidth = (MediaQuery.sizeOf(context).width * 0.72)
            .clamp(220.0, 300.0)
            .toDouble();
        final cardHeight = cardWidth * 9 / 16;

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, hasImages: true),
              const SizedBox(height: 12),
              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: urls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final url = urls[index];
                    return SizedBox(
                      width: cardWidth,
                      child: Material(
                        color: appColors(context).surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            unawaited(_openViewer(context, urls, index));
                          },
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              color: appColors(context).muted,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openViewer(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭预览图',
      // 背景由灯箱自身绘制，才能在下滑时和内容一起实时淡出。
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => _ExtraFanartViewer(
        urls: urls,
        initialIndex: initialIndex,
      ),
    );
  }
}

class _ExtraFanartViewer extends StatefulWidget {
  const _ExtraFanartViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_ExtraFanartViewer> createState() => _ExtraFanartViewerState();
}

class _ExtraFanartViewerState extends State<_ExtraFanartViewer> {
  late final PageController _controller;
  final Map<int, TransformationController> _imageControllers =
      <int, TransformationController>{};
  final Set<int> _zoomedIndexes = <int>{};
  late int _index;
  double _verticalDragOffset = 0;
  bool _isDragging = false;
  bool _isClosing = false;

  static const _dragAnimationDuration = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _imageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _imageControllerFor(int index) {
    return _imageControllers.putIfAbsent(index, () {
      final controller = TransformationController();
      controller.addListener(() => _onImageTransformChanged(index, controller));
      return controller;
    });
  }

  void _onImageTransformChanged(
    int index,
    TransformationController controller,
  ) {
    final scale = controller.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.01;
    final wasZoomed = _zoomedIndexes.contains(index);

    // 缩回完整显示时清掉残留平移，确保下滑退出从稳定的初始位置开始。
    if (!isZoomed) {
      final translation = controller.value.getTranslation();
      if (translation.x.abs() > 0.5 || translation.y.abs() > 0.5) {
        controller.value = Matrix4.identity();
      }
    }

    if (isZoomed == wasZoomed) return;
    if (isZoomed) {
      _zoomedIndexes.add(index);
    } else {
      _zoomedIndexes.remove(index);
    }
    if (mounted && index == _index) setState(() {});
  }

  bool _isZoomed(int index) => _zoomedIndexes.contains(index);

  void _resetImageTransform(int index) {
    final controller = _imageControllers[index];
    if (controller == null) return;
    controller.value = Matrix4.identity();
    _zoomedIndexes.remove(index);
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  void _startVerticalDrag() {
    if (_isClosing || _isZoomed(_index)) return;
    setState(() {
      _isDragging = true;
      _verticalDragOffset = 0;
    });
  }

  void _updateVerticalDrag(DragUpdateDetails details) {
    if (_isClosing || _isZoomed(_index)) return;
    final delta = details.primaryDelta ?? 0;
    setState(() {
      // 只允许向下退出，向上拖动时保持在原位，避免灯箱被拖出屏幕顶部。
      _verticalDragOffset =
          (_verticalDragOffset + delta).clamp(0.0, double.infinity).toDouble();
    });
  }

  void _endVerticalDrag(DragEndDetails details) {
    if (_isClosing || _isZoomed(_index)) return;
    final height = MediaQuery.sizeOf(context).height;
    final velocity = details.primaryVelocity ?? 0;
    final shouldClose =
        _verticalDragOffset > height * 0.2 || velocity > 700;

    if (shouldClose) {
      setState(() {
        _isClosing = true;
        _isDragging = false;
        _verticalDragOffset = height;
      });
      unawaited(
        Future<void>.delayed(_dragAnimationDuration, () {
          if (mounted) Navigator.of(context).pop();
        }),
      );
      return;
    }

    setState(() {
      _isDragging = false;
      _verticalDragOffset = 0;
    });
  }

  void _cancelVerticalDrag() {
    if (_isClosing || _isZoomed(_index)) return;
    setState(() {
      _isDragging = false;
      _verticalDragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final dragProgress =
        (_verticalDragOffset / height).clamp(0.0, 1.0).toDouble();
    final animationDuration = _isDragging
        ? Duration.zero
        : _dragAnimationDuration;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            color: Colors.black.withValues(
              alpha: (0.94 * (1 - dragProgress)).clamp(0.0, 0.94).toDouble(),
            ),
          ),
          AnimatedOpacity(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            opacity: (1 - dragProgress).clamp(0.0, 1.0).toDouble(),
            child: AnimatedContainer(
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                0,
                _verticalDragOffset,
                0,
              ),
              child: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _controller,
                      physics: _isZoomed(_index)
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: widget.urls.length,
                      onPageChanged: (value) {
                        _resetImageTransform(_index);
                        setState(() => _index = value);
                      },
                      itemBuilder: (context, index) {
                        final imageController = _imageControllerFor(index);
                        final isZoomed = _isZoomed(index);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _close,
                          onVerticalDragStart: isZoomed
                              ? null
                              : (_) => _startVerticalDrag(),
                          onVerticalDragUpdate:
                              isZoomed ? null : _updateVerticalDrag,
                          onVerticalDragEnd: isZoomed ? null : _endVerticalDrag,
                          onVerticalDragCancel:
                              isZoomed ? null : _cancelVerticalDrag,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return InteractiveViewer(
                                transformationController: imageController,
                                minScale: 1,
                                maxScale: 6,
                                panEnabled: isZoomed,
                                scaleEnabled: true,
                                constrained: false,
                                boundaryMargin: const EdgeInsets.all(100000),
                                clipBehavior: Clip.none,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: Center(
                                    child: CachedNetworkImage(
                                      imageUrl: widget.urls[index],
                                      fit: BoxFit.contain,
                                      placeholder: (_, __) =>
                                          const CircularProgressIndicator(),
                                      errorWidget: (_, __, ___) => const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white54,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        tooltip: '关闭预览图',
                        onPressed: _close,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (widget.urls.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                '${_index + 1} / ${widget.urls.length}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CastSection extends StatelessWidget {
  const _CastSection({required this.actors});
  final List<ActorItem> actors;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Text('演员', style: AppText.sectionTitle(context)),
          ),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: actors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (ctx, i) {
                final a = actors[i];
                final hue = AppHues.all[i % AppHues.all.length];
                return SizedBox(
                  width: 80,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => ActorMoviesPage(actor: a),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppHues.top(hue).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ActorAvatar(
                          actorId: a.id,
                          name: a.name,
                          hue: hue,
                          size: 76,
                          avatarPath: a.avatarPath,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

class _ActorRelatedMoviesSection extends StatelessWidget {
  const _ActorRelatedMoviesSection({
    required this.movie,
    required this.urlBuilder,
  });

  final MovieDetail movie;
  final String Function(String) urlBuilder;

  List<RelatedMovie> _randomMovies() {
    final seen = <int>{};
    final candidates = movie.actorRelatedMovies.where((item) {
      final isCurrentMovie = item.id == movie.id;
      final isPartMovie = item.moviePart?.trim().isNotEmpty == true;
      return !isCurrentMovie && !isPartMovie && seen.add(item.id);
    }).toList()
      ..shuffle(Random(movie.id));
    return candidates.take(5).toList(growable: false);
  }

  MovieListItem _toMovieListItem(RelatedMovie item) {
    return MovieListItem(
      id: item.id,
      title: item.title,
      num: item.num,
      year: item.year,
      rating: item.rating,
      runtime: item.runtime,
      posterUuid: item.posterUuid ?? item.thumbUuid ?? item.fanartUuid,
      thumbUuid: item.thumbUuid,
      fanartUuid: item.fanartUuid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final relatedMovies = _randomMovies();
    if (relatedMovies.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Text('演员关联影片', style: AppText.sectionTitle(context)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // 与影片库三列网格保持相同的横向内边距、间距和宽高比。
              const columns = 3;
              const horizontalPadding = 44.0;
              const crossAxisSpacing = 10.0;
              const childAspectRatio = 0.55;
              final cardWidth =
                  (constraints.maxWidth - horizontalPadding -
                          crossAxisSpacing * (columns - 1)) /
                      columns;
              return SizedBox(
                height: cardWidth / childAspectRatio,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: relatedMovies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, index) {
                    final related = relatedMovies[index];
                    return SizedBox(
                      width: cardWidth,
                      child: MovieCard(
                        movie: _toMovieListItem(related),
                        posterUrlBuilder: urlBuilder,
                        onTap: () => Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => MovieDetailPage(movieId: related.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 单类 taxonomy 分组 (系列 / 分类 / 标签),带 label + Wrap 多彩 chips。
/// 每个 chip 点击跳 ResourceMoviesPage 按该维度过滤。
class _TaxonomySection extends StatelessWidget {
  const _TaxonomySection({
    required this.label,
    required this.items,
    required this.kind,
    this.hueOffset = 0,
    this.prefix = '',
  });

  final String label;
  final List<ResourceItem> items;
  final ResourceKind kind;
  final int hueOffset;
  final String prefix;

  void _open(BuildContext context, ResourceItem r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResourceMoviesPage(kind: kind, resource: r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.sectionTitle(context),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < items.length; i++)
                HueChip(
                  label: '$prefix${items[i].name}',
                  hue: AppHues.all[(i + hueOffset) % AppHues.all.length],
                  onTap: () => _open(context, items[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 相关文件 section · 优先展示 related_files (含 label+path),
/// fallback 显示单条 file_path。
class _RelatedFilesSection extends StatelessWidget {
  const _RelatedFilesSection({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final files = <({String label, String path})>[];
    if (movie.relatedFiles.isNotEmpty) {
      for (final f in movie.relatedFiles) {
        files.add((label: f.label ?? f.type ?? '文件', path: f.path));
      }
    } else if (movie.filePath != null && movie.filePath!.isNotEmpty) {
      files.add((label: '影片', path: movie.filePath!));
    }
    if (files.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件路径', style: AppText.sectionTitle(context)),
          const SizedBox(height: 12),
          for (var i = 0; i < files.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < files.length - 1
                    ? Border(bottom: BorderSide(color: c.divider))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    files[i].label,
                    style: TextStyle(
                      color: c.muted,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    files[i].path,
                    style: TextStyle(
                      color: c.text2,
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsTable extends ConsumerWidget {
  const _DetailsTable({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final rows = <List<String>>[];
    if (movie.num != null && movie.num!.isNotEmpty) rows.add(['番号', movie.num!]);
    if (movie.country != null && movie.country!.isNotEmpty) {
      rows.add(['产地', movie.country!]);
    }
    // 时长优先用媒体探测结果，缺失时回退 NFO 元数据 runtime
    final durationSec = ref.watch(mediaInfoProvider(movie.id)).value?.durationSec;
    if (durationSec != null && durationSec > 0) {
      rows.add(['时长', _formatDurationSec(durationSec)]);
    } else if (movie.runtime != null && movie.runtime! > 0) {
      rows.add(['时长', '${movie.runtime} MIN']);
    }
    if (movie.fileSize != null && movie.fileSize! > 0) {
      rows.add(['文件大小', _formatBytes(movie.fileSize!)]);
    }
    if (movie.moviePart != null && movie.moviePart!.isNotEmpty) {
      rows.add(['分卷', movie.moviePart!]);
    }
    if (movie.lastDownloadedAt != null && movie.lastDownloadedAt!.isNotEmpty) {
      rows.add(['下载时间', movie.lastDownloadedAt!]);
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('详细信息', style: AppText.sectionTitle(context)),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? Border(bottom: BorderSide(color: c.divider))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      rows[i][0].toUpperCase(),
                      style: TextStyle(
                        color: c.muted,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i][1],
                      style: TextStyle(
                        color: c.text,
                        fontFamily: rows[i][0] == 'File' ? 'monospace' : 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: rows[i][0] == 'File' ? 11.5 : 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(2)} ${units[unit]}';
}

/// 媒体探测时长 → "1h 02m 30s" 风格，供详细信息表使用。
String _formatDurationSec(double sec) {
  final s = sec.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = s % 60;
  return h > 0
      ? '${h}h ${m.toString().padLeft(2, '0')}m ${ss.toString().padLeft(2, '0')}s'
      : '${m}m ${ss.toString().padLeft(2, '0')}s';
}

/// 媒体技术信息 section (容器/大小 + 视频/音频/字幕流卡片)
class _MediaInfoSection extends ConsumerWidget {
  const _MediaInfoSection({required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mediaInfoProvider(movieId));
    return async.maybeWhen(
      data: (detail) {
        if (detail == null) return const SizedBox.shrink();
        final streams = detail.streams;
        final c = appColors(context);
        final rows = <List<String>>[];
        if (detail.container != null) rows.add(['容器', detail.container!]);
        if (detail.fileSize != null && detail.fileSize! > 0) {
          rows.add(['大小', _formatBytes(detail.fileSize!)]);
        }
        final hasCards = streams.hasContent;
        if (rows.isEmpty && !hasCards) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('媒体信息', style: AppText.sectionTitle(context)),
              const SizedBox(height: 14),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          r[0],
                          style: TextStyle(
                            color: c.muted,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r[1],
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasCards) ...[
                if (rows.isNotEmpty) const SizedBox(height: 10),
                MediaStreamCards(detail: detail),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ============ More menu (... popup) ============
class _MoreMenuButton extends ConsumerWidget {
  const _MoreMenuButton({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    return GlassMenuAnchor<String>(
      width: 244,
      entries: _movieMoreEntries(c),
      tooltip: '更多',
      offset: const Offset(0, 8),
      placement: GlassMenuPlacement.below,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_horiz, size: 18),
      ),
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            await MovieEditorSheet.show(context, movie);
            break;
          case 'subtitle':
            await ThunderSubtitleSheet.show(context, movie.id);
            break;
          case 'resources':
            await ResourcesSheet.show(
              context,
              movie: movie,
            );
            break;
          case 'dbo_meta':
            await DboDiffSheet.show(context, movie);
            break;
          case 'sync_nfo':
            await _confirmAndRun(
              context,
              ref,
              title: '同步到 NFO',
              message: '把当前元数据写入磁盘 NFO 文件?',
              run: () =>
                  ref.read(moviesRepositoryProvider).syncNfo(movie.id),
              successMsg: '已同步到 NFO',
            );
            break;
          case 'refresh_nfo':
            await _confirmAndRun(
              context,
              ref,
              title: 'NFO 重载',
              message: '从磁盘 NFO 重新加载,会覆盖当前元数据。',
              run: () =>
                  ref.read(moviesRepositoryProvider).refreshFromNfo(movie.id),
              successMsg: '已从 NFO 重载',
              refreshDetail: true,
            );
            break;
          case 'delete':
            await _confirmDelete(context, ref, movie);
            break;
        }
      },
    );
  }

  List<GlassMenuEntry<String>> _movieMoreEntries(AppColors c) => [
        GlassMenuEntry<String>.action(
          value: 'edit',
          builder: (context, selected, onTap) => GlassMenuRow(
            icon: Icons.edit_outlined,
            label: '编辑影片',
            selected: selected,
            onTap: onTap,
          ),
        ),
        GlassMenuEntry<String>.action(
          value: 'subtitle',
          builder: (context, selected, onTap) => GlassMenuRow(
            icon: Icons.subtitles_outlined,
            label: '下载字幕',
            selected: selected,
            onTap: onTap,
          ),
        ),
        GlassMenuEntry<String>.divider(dividerColor: c.divider),
        GlassMenuEntry<String>.action(
          value: 'dbo_meta',
          builder: (context, selected, onTap) => GlassMenuRow(
            icon: Icons.cloud_download_outlined,
            label: '获取元数据',
            selected: selected,
            onTap: onTap,
          ),
        ),
        GlassMenuEntry<String>.action(
          value: 'resources',
          builder: (context, selected, onTap) => GlassMenuRow(
            icon: Icons.link,
            label: '获取在线资源',
            selected: selected,
            onTap: onTap,
          ),
        ),
        GlassMenuEntry<String>.divider(dividerColor: c.divider),
        GlassMenuEntry<String>.action(
          value: 'sync_nfo',
          builder: (context, selected, onTap) => GlassMenuRow(
            icon: Icons.upload_outlined,
            label: '同步到 NFO',
            selected: selected,
            onTap: onTap,
          ),
        ),
        GlassMenuEntry<String>.action(
          value: 'refresh_nfo',
          builder: (context, selected, onTap) => GlassMenuRow(
            icon: Icons.refresh,
            label: '从 NFO 重载',
            selected: selected,
            onTap: onTap,
          ),
        ),
        GlassMenuEntry<String>.divider(dividerColor: c.divider),
        GlassMenuEntry<String>.action(
          value: 'delete',
          builder: (context, selected, onTap) => GlassMenuRow(
            icon: Icons.delete_outline,
            label: '删除',
            foregroundColor: c.danger,
            selected: selected,
            onTap: onTap,
          ),
        ),
      ];

  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required Future<void> Function() run,
    required String successMsg,
    bool refreshDetail = false,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await run();
      messenger.showSnackBar(SnackBar(
        content: Text(successMsg),
        duration: const Duration(seconds: 1),
      ));
      if (refreshDetail) {
        // ignore: unused_result
        ref.refresh(movieDetailProvider(movie.id));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败: ${toApiException(e).message}')),
      );
    }
  }
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MovieDetail movie,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除影片'),
        content: Text(
          '确定删除「${movie.title}」?\n影片文件、海报、剧照、NFO 等关联资源都会被删除,且不可恢复。',
        ),
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
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref.read(moviesRepositoryProvider).deleteMovie(movie.id);
      messenger.showSnackBar(const SnackBar(
        content: Text('已删除'),
        duration: Duration(seconds: 1),
      ));
      // 返回上一页
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: ${toApiException(e).message}')),
      );
    }
  }
}
