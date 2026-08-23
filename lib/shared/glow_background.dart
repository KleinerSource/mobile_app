import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 全页背景 · 与首页一致的毛玻璃体系。
///
/// 历史名称 GlowBackground,现为磨砂渐变背景:
/// 底色 + 全幅对角柔和晕染(无光斑) + 磨砂遮罩,API 不变,
/// 所有页面统一换用该效果。
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FrostedBase(
      child: Stack(
        fit: StackFit.expand,
        children: [const FrostedScrim(), child],
      ),
    );
  }
}

/// 磨砂基底 · bg 底色 + 全幅对角低透明度晕染。
/// 无独立光斑、无模糊滤镜,渐变本身即柔和过渡,开销极低;
/// 首页氛围背景(HeroBackdrop)也以此为最底层。
class FrostedBase extends StatelessWidget {
  const FrostedBase({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: colors.bg)),
        // 全幅对角晕染 · 沿用主题 glow 色,低透明度平滑过渡
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.glow1.withValues(alpha: dark ? 0.32 : 0.20),
                    colors.bg.withValues(alpha: 0),
                    colors.glow2.withValues(alpha: dark ? 0.26 : 0.16),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// 磨砂遮罩 · 自上而下加深的主题色渐变,统一各页内容可读性。
/// 首页(HeroBackdrop)与普通页面(GlowBackground)共用。
class FrostedScrim extends StatelessWidget {
  const FrostedScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.bg.withValues(alpha: 0.58),
              c.bg.withValues(alpha: 0.78),
              c.bg.withValues(alpha: 0.94),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}
