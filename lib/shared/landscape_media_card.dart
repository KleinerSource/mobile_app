import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 横版媒体卡片的统一结构：外框 → 16:9 封面 → 信息区。
///
/// [coverOverlay] 始终位于封面内部，并与外框一起裁剪，适合预览视频、
/// 加载态和封面级交互层。调用方只负责提供封面内容和信息内容。
class LandscapeMediaCard extends StatelessWidget {
  const LandscapeMediaCard({
    super.key,
    required this.cover,
    required this.info,
    this.width,
    this.coverOverlay,
  });

  final Widget cover;
  final Widget info;
  final double? width;
  final Widget? coverOverlay;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final coverContent = Stack(
      fit: StackFit.expand,
      children: [
        cover,
        if (coverOverlay != null) Positioned.fill(child: coverOverlay!),
      ],
    );
    final card = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: coverContent),
          info,
        ],
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}
