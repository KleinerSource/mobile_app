import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/glow_background.dart';
import '../privacy/privacy_providers.dart';

/// hero 封面艺术条目 · 与轮播页一一对应,驱动氛围背景
@immutable
class HeroArt {
  const HeroArt({required this.movieId, required this.url});

  final int movieId;

  /// 无可用封面时为空字符串,该层不渲染
  final String url;
}

/// 首页氛围背景 · SenPlayer/Infuse 风格:
/// - 底层为全 App 统一的磨砂渐变基底(FrostedBase,无光斑)
/// - 背景跟随轮播滑动连续过渡: 当前封面保持,下一张按页位进度
///   逐帧淡入,无整体切换、无闪烁
/// - 顶层磨砂遮罩(FrostedScrim)与普通页面共用,保证内容可读
/// - 隐私模式未揭开该影片时对应层不渲染
class HeroBackdrop extends ConsumerWidget {
  const HeroBackdrop({
    super.key,
    required this.arts,
    required this.position,
  });

  /// 与轮播页对齐的封面艺术列表
  final ValueListenable<List<HeroArt>> arts;

  /// 归一化的连续页位 [0, items.length),由轮播 PageController 驱动
  final ValueListenable<double> position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const FrostedBase(child: SizedBox.expand()),
        ValueListenableBuilder<List<HeroArt>>(
          valueListenable: arts,
          builder: (context, arts, _) => ValueListenableBuilder<double>(
            valueListenable: position,
            builder: (context, position, _) =>
                _BackdropArtLayers(arts: arts, position: position),
          ),
        ),
        // 磨砂遮罩 · 与普通页面统一
        const Positioned.fill(child: FrostedScrim()),
      ],
    );
  }
}

/// 双图层背景: 基础层 = 当前封面(不透明),淡入层 = 相邻封面,
/// 透明度等于页面滑动进度;层保持挂载,仅改透明度,避免加载闪烁
class _BackdropArtLayers extends ConsumerWidget {
  const _BackdropArtLayers({required this.arts, required this.position});

  final List<HeroArt> arts;
  final double position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (arts.isEmpty) return const SizedBox.shrink();

    final privacyOn = ref.watch(privacyShieldProvider);
    final revealed = ref.watch(revealedMoviesProvider);
    bool isVisible(HeroArt art) =>
        art.url.isNotEmpty && (!privacyOn || revealed.contains(art.movieId));

    final n = arts.length;
    final pos = position.isFinite && position >= 0 ? position : 0.0;
    final base = pos.floor();
    final progress = pos - base;

    final layers = <Widget>[
      if (isVisible(arts[base % n]))
        _BackdropArtLayer(art: arts[base % n], opacity: 1),
    ];
    if (progress > 0.001) {
      final incoming = arts[(base + 1) % n];
      if (isVisible(incoming)) {
        layers.add(
          _BackdropArtLayer(art: incoming, opacity: progress.clamp(0.0, 1.0)),
        );
      }
    }
    if (layers.isEmpty) return const SizedBox.shrink();

    return Stack(fit: StackFit.expand, children: layers);
  }
}

class _BackdropArtLayer extends StatelessWidget {
  const _BackdropArtLayer({required this.art, required this.opacity});

  final HeroArt art;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Transform.scale(
                // 放大出血,避免模糊边缘出现半透明条纹
                scale: 1.35,
                child: CachedNetworkImage(
                  imageUrl: art.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  fadeInDuration: const Duration(milliseconds: 250),
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
