import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 全屏紫粉光晕 · 模拟设计稿的多彩背景氛围。
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: colors.bg)),
        Positioned(
          top: -120,
          left: -100,
          width: 400,
          height: 400,
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.glow1,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 320,
          right: -100,
          width: 300,
          height: 300,
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.glow2,
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
