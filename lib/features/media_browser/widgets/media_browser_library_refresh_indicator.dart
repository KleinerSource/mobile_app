import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// 媒体库扫描进度指示器。
///
/// [ratio] 有值时显示确定进度和百分比，否则显示不确定进度圈。
class MediaBrowserLibraryRefreshIndicator extends StatelessWidget {
  const MediaBrowserLibraryRefreshIndicator({
    super.key,
    required this.ratio,
    this.size = 40,
  });

  final double? ratio;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final value = ratio?.clamp(0.0, 1.0).toDouble();
    final indicatorSize = (size * 0.675).clamp(16.0, size - 8).toDouble();
    return Semantics(
      container: true,
      label: AppL10n.of(context).mediaBrowserRefresh,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: indicatorSize,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: size >= 32 ? 2.5 : 2,
                color: colors.accent,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            if (value != null)
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: (size * 0.225).clamp(7.0, 9.0).toDouble(),
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
