import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../movie_detail/movie_detail_page.dart';
import '../privacy/privacy_mask.dart';

/// 首页 hero 轮播 · 现代化半屏全出血风格:
/// - viewportFraction 1.0 满铺,高度由外层 SliverPersistentHeader 提供
/// - 底部渐隐 + 大标题 + 信息胶囊叠加在封面之上,圆点指示器压底部
/// - 5 秒自动切换,虚拟页无限循环(取模映射首尾相连)
/// - 通过 [pagePosition] 输出归一化连续页位,驱动氛围背景跟随滑动
class RecommendCarousel extends StatefulWidget {
  const RecommendCarousel({
    super.key,
    required this.items,
    required this.urlBuilder,
    this.pagePosition,
  });

  final List<MovieListItem> items;
  final String Function(String uuid) urlBuilder;

  /// 连续页位 [0, items.length),拖动/翻页动画期间逐帧更新
  final ValueNotifier<double>? pagePosition;

  @override
  State<RecommendCarousel> createState() => _RecommendCarouselState();
}

class _RecommendCarouselState extends State<RecommendCarousel> {
  late final PageController _controller;
  Timer? _autoplay;
  static const _initialPageBase = 10000;
  int _page = 0;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _page = _initialPage(widget.items.length);
    _controller = PageController(initialPage: _page);
    _controller.addListener(_syncPagePosition);
    _startAutoplay();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPagePosition());
  }

  @override
  void didUpdateWidget(covariant RecommendCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_itemsChanged(oldWidget.items, widget.items)) return;

    if (widget.items.isEmpty) {
      _autoplay?.cancel();
      _page = 0;
      _index = 0;
      return;
    }

    final currentId = oldWidget.items.isEmpty
        ? null
        : oldWidget.items[_index % oldWidget.items.length].id;
    final matchingIndex = currentId == null
        ? -1
        : widget.items.indexWhere((item) => item.id == currentId);
    final nextIndex = matchingIndex >= 0
        ? matchingIndex
        : _index.clamp(0, widget.items.length - 1);
    final nextPage = _page - (_page % widget.items.length) + nextIndex;
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

  /// 把 PageController 的虚拟页位归一化到 [0, items.length),
  /// 首尾相连的取模保证跨圈翻页时背景也能连续过渡
  void _syncPagePosition() {
    final notifier = widget.pagePosition;
    if (notifier == null || !_controller.hasClients) return;
    final n = widget.items.length;
    if (n <= 0) return;
    final raw = _controller.page ?? _page.toDouble();
    final normalized = raw % n;
    if ((notifier.value - normalized).abs() > 0.001) {
      notifier.value = normalized;
    }
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    if (widget.items.length <= 1) return;
    _autoplay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String? _hero(MovieListItem m) {
    final uuid = m.fanartUuid ?? m.posterUuid ?? m.thumbUuid;
    return uuid != null ? widget.urlBuilder(uuid) : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          onPageChanged: (i) {
            setState(() {
              _page = i;
              _index = i % widget.items.length;
            });
            // 用户手动滑动后,重新启动 autoplay 计时
            _startAutoplay();
          },
          itemBuilder: (ctx, i) {
            final m = widget.items[i % widget.items.length];
            return _HeroCard(
              movie: m,
              imageUrl: _hero(m),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MovieDetailPage(movieId: m.id),
                ),
              ),
            );
          },
        ),
        // 顶部渐隐 · 供问候语/状态栏方向的文字压图可读
        // (无子节点的 DecoratedBox 会吸收指针,必须忽略命中才能让 PageView 接管手势)
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
        // 圆点指示器 · 压在 hero 底缘,不参与手势
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: IgnorePointer(
            child: _Dots(active: _index, total: widget.items.length),
          ),
        ),
      ],
    );
  }

  int _initialPage(int length) {
    if (length <= 0) return 0;
    return _initialPageBase - (_initialPageBase % length);
  }

  bool _itemsChanged(
    List<MovieListItem> previous,
    List<MovieListItem> next,
  ) {
    if (previous.length != next.length) return true;
    for (var i = 0; i < previous.length; i++) {
      if (previous[i].id != next[i].id) return true;
    }
    return false;
  }
}

/// 单页 hero · 满铺封面 + 底部渐隐 + 番号/评分胶囊 + 大标题
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.movie,
    required this.imageUrl,
    required this.onTap,
  });

  final MovieListItem movie;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PrivacyAwareInkWell(
      movieId: movie.id,
      onTap: onTap,
      child: PrivacyMask(
        movieId: movie.id,
        radius: 0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF15161C)),
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            // 底部渐隐 · 与氛围背景色调衔接
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.42, 1.0],
                ),
              ),
            ),
            // 信息区 · 左下
            Positioned(
              left: 22,
              right: 22,
              bottom: 34,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (movie.num != null && movie.num!.isNotEmpty) ...[
                        _GlassPill(text: movie.num!.toUpperCase(), mono: true),
                        const SizedBox(width: 8),
                      ],
                      if (movie.rating != null && movie.rating! > 0)
                        _GlassPill(
                          text: '★ ${movie.rating!.toStringAsFixed(1)}',
                          accent: const Color(0xFFFFD600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PrivacyText(
                    movieId: movie.id,
                    text: movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      height: 1.12,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 8,
                          color: Color(0xB3000000),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MetaRow(movie: movie),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 黑玻璃信息胶囊
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.movie});
  final MovieListItem movie;

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
