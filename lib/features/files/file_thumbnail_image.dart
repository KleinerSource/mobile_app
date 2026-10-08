import 'package:flutter/material.dart';

/// 首帧解码后才从占位图淡入；已解码的缓存图和普通重建直接沿用当前画面。
class FileThumbnailImage extends StatelessWidget {
  const FileThumbnailImage({
    super.key,
    required this.image,
    required this.placeholder,
  });

  final ImageProvider? image;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    final provider = image;
    if (provider == null) return placeholder;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Image(
      key: ObjectKey(provider),
      image: provider,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: frame == null ? placeholder : child,
        );
      },
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
