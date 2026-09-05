import 'package:flutter/material.dart';

/// 竖版媒体卡片的统一结构：封面 → 信息区。
///
/// 具体数据源负责提供封面、覆盖层和信息内容；外层点击行为由调用方保留，
/// 以兼容 OMM、目录源和 Stash 各自的隐私与选择状态。
class PortraitMediaCard extends StatelessWidget {
  const PortraitMediaCard({
    super.key,
    required this.cover,
    required this.info,
    this.width,
    this.coverOverlay,
    this.infoGap = 6,
  });

  final Widget cover;
  final Widget info;
  final double? width;
  final Widget? coverOverlay;
  final double infoGap;

  @override
  Widget build(BuildContext context) {
    final coverContent = Stack(
      children: [cover, if (coverOverlay != null) coverOverlay!],
    );
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        coverContent,
        SizedBox(height: infoGap),
        info,
      ],
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}
