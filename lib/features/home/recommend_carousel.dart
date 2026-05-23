import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/poster.dart';
import '../movie_detail/movie_detail_page.dart';
import '../privacy/privacy_mask.dart';

/// 首页轮播 hero 区
/// - 卡片宽屏 16:10 + fanart 满铺 + 渐隐 + 大标题
/// - 5 秒自动切换
/// - 底部圆点指示器
class RecommendCarousel extends StatefulWidget {
  const RecommendCarousel({
    super.key,
    required this.items,
    required this.urlBuilder,
  });

  final List<MovieListItem> items;
  final String Function(String uuid) urlBuilder;

  @override
  State<RecommendCarousel> createState() => _RecommendCarouselState();
}

class _RecommendCarouselState extends State<RecommendCarousel> {
  late final PageController _controller;
  Timer? _autoplay;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
    _startAutoplay();
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    if (widget.items.length <= 1) return;
    _autoplay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        next,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              // 用户手动滑动后,重新启动 autoplay 计时
              _startAutoplay();
            },
            itemBuilder: (ctx, i) {
              final m = widget.items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _CarouselCard(
                  movie: m,
                  imageUrl: _hero(m),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MovieDetailPage(movieId: m.id),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _Dots(active: _index, total: widget.items.length),
      ],
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({
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
      borderRadius: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: PrivacyMask(
          movieId: movie.id,
          radius: 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Poster(
                url: imageUrl,
                title: movie.title,
                year: movie.year,
                aspectRatio: 16 / 10,
                radius: 0,
              ),
            // 底部渐隐
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
            // 评分角标
            if (movie.rating != null && movie.rating! > 0)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '★',
                        style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        movie.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 番号角标
            if (movie.num != null && movie.num!.isNotEmpty)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    movie.num!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            // 底部 meta + 标题
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaRow(movie: movie),
                  const SizedBox(height: 6),
                  PrivacyText(
                    movieId: movie.id,
                    text: movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      height: 1.1,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 6,
                          color: Color(0x99000000),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            color: on ? c.accent : c.muted2.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );
  }
}
