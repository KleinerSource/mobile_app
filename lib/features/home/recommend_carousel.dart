import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:omm/features/db_online/models/db_online_movie.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/poster.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import '../privacy/privacy_mask.dart';

/// 首页 hero 轮播。
///
/// OMM 与 dbonline 共用这一套轮播布局。dbonline 使用命名构造器提供
/// 自己的字符串 ID、图片 URL 和详情跳转回调，避免把数据强行转换为
/// [MovieListItem]。
class RecommendCarousel extends StatefulWidget {
  const RecommendCarousel({
    super.key,
    required this.items,
    required this.urlBuilder,
    required this.onMovieReturned,
    this.pagePosition,
  }) : _dbOnlineItems = null,
       _dbOnlineImageUrlBuilder = null,
       _dbOnlineOnTap = null;

  const RecommendCarousel.dbOnline({
    super.key,
    required List<DbOnlineMovie> items,
    required String Function(DbOnlineMovie movie) imageUrlBuilder,
    required Future<void> Function(BuildContext context, DbOnlineMovie movie)
    onMovieTap,
    this.pagePosition,
  }) : items = const <MovieListItem>[],
       urlBuilder = null,
       onMovieReturned = _noopMovieReturned,
       _dbOnlineItems = items,
       _dbOnlineImageUrlBuilder = imageUrlBuilder,
       _dbOnlineOnTap = onMovieTap;

  final List<MovieListItem> items;
  final String Function(String uuid)? urlBuilder;
  final ValueChanged<MovieDataChanges> onMovieReturned;
  final ValueNotifier<double>? pagePosition;
  final List<DbOnlineMovie>? _dbOnlineItems;
  final String Function(DbOnlineMovie movie)? _dbOnlineImageUrlBuilder;
  final Future<void> Function(BuildContext context, DbOnlineMovie movie)?
  _dbOnlineOnTap;

  static void _noopMovieReturned(MovieDataChanges _) {}

  @override
  State<RecommendCarousel> createState() => _RecommendCarouselState();
}

class _RecommendCarouselState extends State<RecommendCarousel> {
  late final PageController _controller;
  Timer? _autoplay;
  static const _initialPageBase = 10000;
  int _page = 0;
  int _index = 0;
  late List<_CarouselItem> _items;

  @override
  void initState() {
    super.initState();
    _items = _itemsFor(widget);
    _page = _initialPage(_items.length);
    _controller = PageController(initialPage: _page);
    _controller.addListener(_syncPagePosition);
    _startAutoplay();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPagePosition());
  }

  @override
  void didUpdateWidget(covariant RecommendCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousItems = _items;
    _items = _itemsFor(widget);
    if (!_itemsChanged(previousItems, _items)) return;

    if (_items.isEmpty) {
      _autoplay?.cancel();
      _page = 0;
      _index = 0;
      return;
    }

    final currentKey = previousItems.isEmpty
        ? null
        : previousItems[_index % previousItems.length].key;
    final matchingIndex = currentKey == null
        ? -1
        : _items.indexWhere((item) => item.key == currentKey);
    final nextIndex = matchingIndex >= 0
        ? matchingIndex
        : _index.clamp(0, _items.length - 1);
    final nextPage = _page - (_page % _items.length) + nextIndex;
    _page = nextPage;
    _index = nextIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.jumpToPage(nextPage);
      }
      _syncPagePosition();
    });
    _startAutoplay();
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _controller.removeListener(_syncPagePosition);
    _controller.dispose();
    super.dispose();
  }

  void _syncPagePosition() {
    final notifier = widget.pagePosition;
    if (notifier == null || !_controller.hasClients || _items.isEmpty) return;
    final raw = _controller.page ?? _page.toDouble();
    final normalized = raw % _items.length;
    if ((notifier.value - normalized).abs() > 0.001) {
      notifier.value = normalized;
    }
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    if (_items.length <= 1) return;
    _autoplay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: _buildCoverStage()),
        PageView.builder(
          controller: _controller,
          onPageChanged: (i) {
            setState(() {
              _page = i;
              _index = i % _items.length;
            });
            _startAutoplay();
          },
          itemBuilder: (context, i) {
            final item = _items[i % _items.length];
            return _HeroInfoCard(movie: item, onTap: () => item.onTap(context));
          },
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black38, Colors.transparent],
                stops: [0.0, 0.35],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: IgnorePointer(
            child: _Dots(active: _index, total: _items.length),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverStage() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final rawPage = _controller.hasClients
            ? (_controller.page ?? _page.toDouble())
            : _page.toDouble();
        final basePage = rawPage.floor();
        final progress = (rawPage - basePage).clamp(0.0, 1.0);
        final current = _items[basePage % _items.length];
        final next = _items[(basePage + 1) % _items.length];
        return _HeroCoverStage(
          current: current,
          next: next,
          currentImageUrl: current.imageUrl,
          nextImageUrl: next.imageUrl,
          progress: progress,
        );
      },
    );
  }

  List<_CarouselItem> _itemsFor(RecommendCarousel value) {
    final dbItems = value._dbOnlineItems;
    final dbImageBuilder = value._dbOnlineImageUrlBuilder;
    final dbOnTap = value._dbOnlineOnTap;
    if (dbItems != null && dbImageBuilder != null && dbOnTap != null) {
      return [
        for (final movie in dbItems)
          _CarouselItem(
            key: _dbOnlinePrivacyId(movie),
            title: movie.title.trim().isEmpty ? movie.number : movie.title,
            code: movie.number,
            imageUrl: _nullableUrl(dbImageBuilder(movie)),
            rating: movie.score,
            runtime: _runtimeMinutes(movie.duration),
            year: _yearFromDate(movie.releaseDate),
            privacyId: _dbOnlinePrivacyId(movie),
            canPlay: movie.canPlay,
            onTap: (context) => dbOnTap(context, movie),
          ),
      ];
    }

    final urlBuilder = value.urlBuilder;
    if (urlBuilder == null) return const <_CarouselItem>[];
    return [
      for (final movie in value.items)
        _CarouselItem(
          key: '${movie.id}',
          title: movie.title,
          code: movie.num,
          imageUrl: _nullableUrl(_ommImageUrl(movie, urlBuilder)),
          rating: movie.rating,
          runtime: movie.runtime,
          year: movie.year,
          privacyId: movie.id,
          onTap: (context) async {
            final changesBeforeVisit = MovieDataChanges.snapshot(
              movieId: movie.id,
            );
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MovieDetailPage(movieId: movie.id),
              ),
            );
            if (mounted) value.onMovieReturned(changesBeforeVisit);
          },
        ),
    ];
  }

  static String? _ommImageUrl(
    MovieListItem movie,
    String Function(String uuid) urlBuilder,
  ) {
    final uuid = movie.fanartUuid ?? movie.posterUuid ?? movie.thumbUuid;
    return uuid == null ? null : urlBuilder(uuid);
  }

  static String? _nullableUrl(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static String _dbOnlinePrivacyId(DbOnlineMovie movie) {
    final id = movie.id.trim();
    return id.isEmpty ? movie.number.trim() : id;
  }

  static int? _runtimeMinutes(String? duration) {
    final match = RegExp(r'\d+').firstMatch(duration ?? '');
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static int? _yearFromDate(String? date) {
    final match = RegExp(r'^(\d{4})').firstMatch(date?.trim() ?? '');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  int _initialPage(int length) {
    if (length <= 0) return 0;
    return _initialPageBase - (_initialPageBase % length);
  }

  bool _itemsChanged(List<_CarouselItem> previous, List<_CarouselItem> next) {
    if (previous.length != next.length) return true;
    for (var i = 0; i < previous.length; i++) {
      if (previous[i].key != next[i].key) return true;
    }
    return false;
  }
}

class _CarouselItem {
  const _CarouselItem({
    required this.key,
    required this.title,
    required this.onTap,
    this.code,
    this.imageUrl,
    this.rating,
    this.runtime,
    this.year,
    this.privacyId,
    this.canPlay = false,
  });

  final String key;
  final String title;
  final String? code;
  final String? imageUrl;
  final double? rating;
  final int? runtime;
  final int? year;
  final Object? privacyId;
  final bool canPlay;
  final Future<void> Function(BuildContext context) onTap;
}

class _HeroCoverStage extends StatelessWidget {
  const _HeroCoverStage({
    required this.current,
    required this.next,
    required this.currentImageUrl,
    required this.nextImageUrl,
    required this.progress,
  });

  final _CarouselItem current;
  final _CarouselItem next;
  final String? currentImageUrl;
  final String? nextImageUrl;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final split = 1 - progress;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.45, 1.0],
      ).createShader(bounds),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroCover(movie: current, imageUrl: currentImageUrl),
          if (progress > 0)
            Positioned.fill(
              child: ClipRect(
                key: const ValueKey('hero-cover-edge-clip'),
                clipper: _RightRevealClipper(split),
                child: _HeroCover(movie: next, imageUrl: nextImageUrl),
              ),
            ),
        ],
      ),
    );
  }
}

class _RightRevealClipper extends CustomClipper<Rect> {
  const _RightRevealClipper(this.split);
  final double split;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * split, 0, size.width, size.height);

  @override
  bool shouldReclip(_RightRevealClipper oldClipper) =>
      oldClipper.split != split;
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.movie, required this.imageUrl});
  final _CarouselItem movie;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF15161C)),
        if (imageUrl != null)
          CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
      ],
    );
    final privacyId = movie.privacyId;
    return privacyId == null
        ? content
        : PrivacyMask(movieId: privacyId, radius: 0, child: content);
  }
}

class _HeroInfoCard extends StatelessWidget {
  const _HeroInfoCard({required this.movie, required this.onTap});
  final _CarouselItem movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 22,
          right: 22,
          bottom: 34,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (movie.code?.isNotEmpty == true) ...[
                    _GlassPill(text: movie.code!.toUpperCase(), mono: true),
                    const SizedBox(width: 8),
                  ],
                  if (movie.rating != null && movie.rating! > 0)
                    _GlassPill(
                      text: '★ ${movie.rating!.toStringAsFixed(1)}',
                      accent: const Color(0xFFFFD600),
                    ),
                  if (movie.canPlay) ...[
                    const SizedBox(width: 8),
                    const OnlinePlayBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              _HeroTitle(movie: movie),
              const SizedBox(height: 6),
              _MetaRow(movie: movie),
            ],
          ),
        ),
      ],
    );
    final privacyId = movie.privacyId;
    final masked = privacyId == null
        ? content
        : PrivacyMask(movieId: privacyId, radius: 0, child: content);
    return privacyId == null
        ? InkWell(onTap: onTap, child: masked)
        : PrivacyAwareInkWell(movieId: privacyId, onTap: onTap, child: masked);
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.text, this.mono = false, this.accent});
  final String text;
  final bool mono;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent ?? Colors.white,
          fontFamily: mono ? 'monospace' : 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.movie});

  final _CarouselItem movie;

  static const _style = TextStyle(
    color: Colors.white,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w800,
    fontSize: 24,
    height: 1.12,
    letterSpacing: -0.5,
    shadows: [
      Shadow(offset: Offset(0, 1), blurRadius: 8, color: Color(0xB3000000)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final id = movie.privacyId;
    if (id == null) {
      return Text(
        movie.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _style,
      );
    }
    return PrivacyText(
      movieId: id,
      text: movie.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: _style,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.movie});
  final _CarouselItem movie;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (movie.runtime != null && movie.runtime! > 0) {
      parts.add('${movie.runtime} min');
    }
    if (movie.year != null) parts.add('${movie.year}');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: const TextStyle(
        color: Color(0xCCFFFFFF),
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 11.5,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.active, required this.total});
  final int active;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: on ? c.accent : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );
  }
}
