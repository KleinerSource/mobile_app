import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_theme.dart';
import 'privacy_providers.dart';

/// 影片内容隐私遮罩 helper
///
/// 用法 (海报/封面):
///   PrivacyMask(movieId: id, child: Poster(...))
///
/// 隐私模式开启 + 未揭开 → 显示 blur + 暗罩 + 锁图标; 否则透传 child。
class PrivacyMask extends ConsumerWidget {
  const PrivacyMask({
    super.key,
    required this.movieId,
    required this.child,
    this.radius = 10,
    this.icon = true,
  });

  final int movieId;
  final Widget child;
  final double radius;
  final bool icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(privacyShieldProvider);
    final revealed = ref.watch(revealedMoviesProvider).contains(movieId);
    if (!enabled || revealed) return child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // 原 child 仍渲染,但被 blur 模糊
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: child,
          ),
          // 暗罩
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
          ),
          if (icon)
            const Positioned.fill(
              child: Center(
                child: Icon(
                  Icons.visibility_off_outlined,
                  color: Color(0xCCFFFFFF),
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 文本/小段内容隐私遮罩 · 用 SelectableText.rich 不行的简单替代:
/// 隐私模式 + 未揭开 → 显示等长方块 placeholder, 揭开/关闭后透传。
class PrivacyText extends ConsumerWidget {
  const PrivacyText({
    super.key,
    required this.movieId,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  final int movieId;
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(privacyShieldProvider);
    final revealed = ref.watch(revealedMoviesProvider).contains(movieId);
    if (!enabled || revealed) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    // 用纯 ▆ 替换字符保留宽度感
    final masked = '▆▆▆▆▆▆';
    return Text(
      masked,
      style: style.copyWith(color: appColors(context).muted2),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// 包装点击行为 · 隐私模式 + 未揭开时,点击只揭开当前卡片不进入详情
/// 已揭开 / 隐私模式关 → 走原 onTap
class PrivacyAwareInkWell extends ConsumerWidget {
  const PrivacyAwareInkWell({
    super.key,
    required this.movieId,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.borderRadius = 10,
  });

  final int movieId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: () {
        final enabled = ref.read(privacyShieldProvider);
        final revealed = ref.read(revealedMoviesProvider).contains(movieId);
        if (enabled && !revealed) {
          ref.read(revealedMoviesProvider.notifier).reveal(movieId);
          return;
        }
        onTap?.call();
      },
      onLongPress: onLongPress,
      child: child,
    );
  }
}
