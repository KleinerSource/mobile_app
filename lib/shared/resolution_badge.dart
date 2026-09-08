import 'package:flutter/material.dart';

import '../core/models/movie.dart';

/// 移动端封面与详情页共用的清晰度徽章展示规格。
extension ResolutionTierBadge on ResolutionTier {
  String get badgeLabel => switch (this) {
    ResolutionTier.uhd => '4K',
    ResolutionTier.k2 => '2K',
    ResolutionTier.fhd => 'FHD',
    ResolutionTier.hd => 'HD',
    ResolutionTier.sd => 'SD',
    ResolutionTier.none => '',
  };

  IconData get badgeIcon => switch (this) {
    ResolutionTier.uhd => Icons.high_quality_outlined,
    ResolutionTier.k2 => Icons.aspect_ratio,
    ResolutionTier.fhd => Icons.hd_outlined,
    ResolutionTier.hd => Icons.display_settings_outlined,
    ResolutionTier.sd => Icons.sd_outlined,
    ResolutionTier.none => Icons.help_outline,
  };

  // 与 Web 端清晰度语义色保持一致：警告橙 / 紫 / 信息青 / 青铜 / 危险红。
  Color get badgeColor => switch (this) {
    ResolutionTier.uhd => const Color(0xFFFF9F0A),
    ResolutionTier.k2 => const Color(0xFFBF5AF2),
    ResolutionTier.fhd => const Color(0xFF64D2FF),
    ResolutionTier.hd => const Color(0xFFCD7F32),
    ResolutionTier.sd => const Color(0xFFFF453A),
    ResolutionTier.none => Colors.transparent,
  };
}

ResolutionTier resolutionTierFromBadgeLabel(String value) {
  return switch (value.trim().toUpperCase()) {
    '4K' => ResolutionTier.uhd,
    '2K' => ResolutionTier.k2,
    'FHD' => ResolutionTier.fhd,
    'HD' => ResolutionTier.hd,
    'SD' => ResolutionTier.sd,
    _ => ResolutionTier.none,
  };
}
