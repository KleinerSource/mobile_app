import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import '../features/privacy/privacy_mask.dart';

/// 紧凑媒体列表行的统一结构。
///
/// 缩略图、标题和元信息由调用方提供，结构统一维护缩略图尺寸、间距、
/// 分割线、点击层和可选的隐私点击行为。
class MediaListRow extends StatelessWidget {
  const MediaListRow({
    super.key,
    required this.thumbnail,
    required this.title,
    this.meta,
    this.width = double.infinity,
    this.thumbnailWidth = 52,
    this.thumbnailHeight,
    this.thumbnailTextGap = 12,
    this.leading,
    this.leadingGap = 14,
    this.additional,
    this.additionalGap = 8,
    this.trailing,
    this.trailingGap = 8,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.privacyId,
    this.privacyAwareTap = false,
  });

  final Widget thumbnail;
  final Widget title;
  final Widget? meta;
  final double width;
  final double thumbnailWidth;
  final double? thumbnailHeight;
  final double thumbnailTextGap;
  final Widget? leading;
  final double leadingGap;
  final Widget? additional;
  final double additionalGap;
  final Widget? trailing;
  final double trailingGap;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? borderRadius;
  final Object? privacyId;
  final bool privacyAwareTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final content = Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: leadingGap)],
          SizedBox(
            width: thumbnailWidth,
            height: thumbnailHeight,
            child: thumbnail,
          ),
          SizedBox(width: thumbnailTextGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (meta != null) ...[const SizedBox(height: 3), meta!],
                if (additional != null) ...[
                  SizedBox(height: additionalGap),
                  additional!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: trailingGap), trailing!],
        ],
      ),
    );

    final interactive = privacyAwareTap && privacyId != null
        ? PrivacyAwareInkWell(
            movieId: privacyId!,
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: borderRadius ?? 10,
            child: content,
          )
        : InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: borderRadius == null
                ? null
                : BorderRadius.circular(borderRadius!),
            child: content,
          );
    return SizedBox(width: width, child: interactive);
  }
}
