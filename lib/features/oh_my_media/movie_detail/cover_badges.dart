import 'package:flutter/material.dart';

import 'package:omm/core/models/media_streams.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/stacked_badges.dart';
import 'package:omm/shared/resolution_badge.dart';
import 'package:omm/features/i18n/poster_badge_visibility_provider.dart';

/// 详情页封面技术徽章规格。
@immutable
class CoverBadgeSpec {
  const CoverBadgeSpec(this.kind, this.label, this.color, [this.tooltip]);
  final PosterBadgeKind kind;

  /// 稳定的技术值或内部标签；可见文本由 [localizedLabel] 提供。
  final String label;
  final Color color;

  /// 稳定的 tooltip 标识；设置页预览也可以传入已经本地化的文本。
  final String? tooltip;

  String localizedLabel(AppL10n l) => switch (label) {
    'subtitle' => l.badgeSubtitle,
    'crack' => l.badgeCrack,
    _ => label,
  };

  String? localizedTooltip(AppL10n l) {
    final value = tooltip;
    if (value == null) return null;
    if (value.startsWith('codec:')) {
      return l.coverBadgeCodecTooltip(value.substring('codec:'.length));
    }
    if (value.startsWith('range:')) {
      return l.coverBadgeRangeTooltip(value.substring('range:'.length));
    }
    if (value.startsWith('resolution:')) {
      return '${l.mediaStreamResolution}: ${value.substring('resolution:'.length)}';
    }
    return switch (value) {
      'strm' => l.coverBadgeStrmTooltip,
      'externalSubtitle' => l.movieCardSubExternal,
      'aiSubtitle' => l.movieCardSubAi,
      'muxedSubtitle' => l.movieCardSubMuxedTrack,
      'filenameSubtitle' => l.movieCardSubFilename,
      'embeddedSubtitle' => l.coverBadgeEmbeddedSubtitleTooltip,
      'crack' => l.coverBadgeCrackTooltip,
      _ => value,
    };
  }

  IconData get icon => switch (kind) {
    PosterBadgeKind.codec => Icons.memory_outlined,
    PosterBadgeKind.hdr => Icons.hdr_on,
    PosterBadgeKind.strm => Icons.link_outlined,
    PosterBadgeKind.subtitle => Icons.closed_caption_outlined,
    PosterBadgeKind.crack => Icons.lock_open_rounded,
    PosterBadgeKind.resolution => resolutionTierFromBadgeLabel(label).badgeIcon,
  };
}

// 番号后缀正则 · 规则与 core/models/movie.dart (MovieListItemX) 及
// Web 端 useCoverBadges.js 保持一致。
final _kEmbeddedSubtitleRegex = RegExp(
  r'(?:^|[-_. ()\[\]{}])(c|ch|chs|cht|zh|sub|subs)(?=$|[-_. ()\[\]{}])',
);
final _kCrackWithSubRegex = RegExp(
  r'(?:^|[-_. ()\[\]{}])(uc|umr-c)(?=$|[-_. ()\[\]{}])',
);
final _kUmrCrackRegex = RegExp(
  r'(?:^|[-_. ()\[\]{}])umr(?:-c)?(?=$|[-_. ()\[\]{}])',
);
final _kCrackRegex = RegExp(
  r'(?:^|[-_. ()\[\]{}])(u|uc|uncen|uncensored|leak|leaked)(?=$|[-_. ()\[\]{}])',
);

String _fileNameStem(String? filePath) {
  final raw = (filePath ?? '').trim();
  if (raw.isEmpty) return '';
  final name = raw.split(RegExp(r'[\\/]')).last;
  if (name.isEmpty) return '';
  return name.replaceFirst(RegExp(r'\.[^.]+$'), '').toLowerCase();
}

CoverBadgeSpec resolutionBadgeSpec(ResolutionTier tier) {
  return CoverBadgeSpec(
    PosterBadgeKind.resolution,
    tier.badgeLabel,
    tier.badgeColor,
    'resolution:${tier.badgeLabel}',
  );
}

/// 组合数据库媒体信息 + 文件名后缀 + 外挂字幕状态生成封面徽章(与 Web 端 useCoverBadges 对齐):
/// 编码 / HDR / STRM / 外挂字幕 / AI 字幕 / 内嵌字幕轨道 / 文件名内嵌字幕 / 破解 / 4K / 2K / FHD / HD / SD，
/// 无数据的项自动省略。
///
/// [resolutionTiers] 是后端统一计算的清晰度档位列表:首位为当前影片档位
/// (media-info 实时值优先，详情快照兜底)，其后可跟同番号其他分卷的档位，
/// 支持多分卷多分辨率叠加展示；空列表或均为 none 时不显示分辨率徽章。
List<CoverBadgeSpec> buildCoverBadges({
  String? filePath,
  List<ResolutionTier> resolutionTiers = const [],
  VideoStreamInfo? video,
  bool hasExternalSubtitle = false,
  bool hasAISubtitle = false,
  bool hasMuxedSubtitle = false,
}) {
  final badges = <CoverBadgeSpec>[];

  // 编码
  final codec = (video?.codec ?? '').trim().toLowerCase();
  if (codec.isNotEmpty) {
    final (label, color) = switch (codec) {
      'h264' || 'avc' || 'avc1' => ('H264', const Color(0xFF2563EB)),
      'hevc' || 'h265' => ('HEVC', const Color(0xFF059669)),
      'av1' => ('AV1', const Color(0xFF7C3AED)),
      'vp9' => ('VP9', const Color(0xFFD97706)),
      _ => (codec.toUpperCase(), const Color(0xFF475569)),
    };
    badges.add(
      CoverBadgeSpec(PosterBadgeKind.codec, label, color, 'codec:$label'),
    );
  }

  // HDR 动态范围: DoVi > HDR10(PQ) > HLG；SDR 不显示
  if (video != null) {
    if (video.dolbyVision) {
      badges.add(
        const CoverBadgeSpec(
          PosterBadgeKind.hdr,
          'Dolby Vision',
          Color(0xFF7C3AED),
          'range:Dolby Vision',
        ),
      );
    } else {
      switch (video.colorTransfer) {
        case 'smpte2084':
          badges.add(
            const CoverBadgeSpec(
              PosterBadgeKind.hdr,
              'HDR10',
              Color(0xFFEA580C),
              'range:HDR10 (PQ)',
            ),
          );
        case 'arib-std-b67':
          badges.add(
            const CoverBadgeSpec(
              PosterBadgeKind.hdr,
              'HLG',
              Color(0xFF16A34A),
              'range:HLG',
            ),
          );
      }
    }
  }

  final stem = _fileNameStem(filePath);

  if ((filePath ?? '').toLowerCase().endsWith('.strm')) {
    badges.add(
      const CoverBadgeSpec(
        PosterBadgeKind.strm,
        'strm',
        Color(0xFF475569),
        'strm',
      ),
    );
  }

  if (hasExternalSubtitle) {
    badges.add(
      const CoverBadgeSpec(
        PosterBadgeKind.subtitle,
        'subtitle',
        Color(0xFFFF9F1C),
        'externalSubtitle',
      ),
    );
  }

  // AI 字幕: 文件名带 .ai. 标记的外挂字幕,与普通外挂字幕徽章同时显示
  if (hasAISubtitle) {
    badges.add(
      const CoverBadgeSpec(
        PosterBadgeKind.subtitle,
        'subtitle',
        Color(0xFF8B5CF6),
        'aiSubtitle',
      ),
    );
  }

  // 内嵌字幕轨道: 视频容器内的字幕流,与文件名标识相互独立
  if (hasMuxedSubtitle) {
    badges.add(
      const CoverBadgeSpec(
        PosterBadgeKind.subtitle,
        'subtitle',
        Color(0xFF16A34A),
        'muxedSubtitle',
      ),
    );
  }

  // 文件名内嵌标识: -c / -chs / -uc / -umr-c 等番号后缀
  if (stem.isNotEmpty &&
      (_kEmbeddedSubtitleRegex.hasMatch(stem) ||
          _kCrackWithSubRegex.hasMatch(stem))) {
    badges.add(
      const CoverBadgeSpec(
        PosterBadgeKind.subtitle,
        'subtitle',
        Color(0xFFCA8A04),
        'embeddedSubtitle',
      ),
    );
  }

  if (stem.isNotEmpty &&
      (_kUmrCrackRegex.hasMatch(stem) || _kCrackRegex.hasMatch(stem))) {
    badges.add(
      const CoverBadgeSpec(
        PosterBadgeKind.crack,
        'crack',
        Color(0xFFDB2777),
        'crack',
      ),
    );
  }

  // 分辨率：档位由后端统一计算(媒体宽高优先，缺失回退文件名标识)。
  // 多分卷影片可能有多个档位(如 cd1 4K / cd2 FHD)，各生成一枚徽章，
  // 由 CoverBadgeRow 叠加展示；去重并保持首个(当前影片)优先。
  final seenTiers = <ResolutionTier>{};
  for (final tier in resolutionTiers) {
    if (tier == ResolutionTier.none || !seenTiers.add(tier)) continue;
    badges.add(resolutionBadgeSpec(tier));
  }

  return badges;
}

/// 封面底部技术徽章行:
/// 视频规格(编码/HDR/杜比/STRM)、分辨率(含多分卷多档)与字幕来源
/// 分别合并为叠堆;多个分辨率档位同样叠加,点按展开。收起时叠加、
/// 点按向上展开,详情页与设置预览共用同一套布局。
class CoverBadgeRow extends StatelessWidget {
  const CoverBadgeRow({super.key, required this.badges});

  final List<CoverBadgeSpec> badges;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final subs = <CoverBadgeSpec>[];
    final mediaSpecs = <CoverBadgeSpec>[];
    final resolutions = <CoverBadgeSpec>[];
    final standalone = <CoverBadgeSpec>[];
    for (final b in badges) {
      switch (b.kind) {
        case PosterBadgeKind.codec:
        case PosterBadgeKind.hdr:
        case PosterBadgeKind.strm:
          mediaSpecs.add(b);
        case PosterBadgeKind.subtitle:
          subs.add(b);
        case PosterBadgeKind.resolution:
          resolutions.add(b);
        case PosterBadgeKind.crack:
          standalone.add(b);
      }
    }

    Widget badgeGroup(List<CoverBadgeSpec> list, {String? tooltip}) {
      if (list.isEmpty) return const SizedBox.shrink();
      if (list.length == 1) return _CoverBadgePill(spec: list.single);
      return StackedBadges(
        tooltip: tooltip,
        children: [for (final b in list) _CoverBadgePill(spec: b)],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        badgeGroup(mediaSpecs),
        badgeGroup(resolutions),
        for (final b in standalone) _CoverBadgePill(spec: b),
        badgeGroup(subs, tooltip: l.movieCardSubStack(subs.length)),
      ],
    );
  }
}

/// OMM 风格的彩色详情徽章。
class CoverBadgePill extends StatelessWidget {
  const CoverBadgePill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.24),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 11),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个彩色胶囊徽章 (原 CoverBadgeRow 的内联样式)
class _CoverBadgePill extends StatelessWidget {
  const _CoverBadgePill({required this.spec});

  final CoverBadgeSpec spec;

  @override
  Widget build(BuildContext context) {
    return CoverBadgePill(
      icon: spec.icon,
      label: spec.localizedLabel(AppL10n.of(context)),
      color: spec.color,
      tooltip: spec.localizedTooltip(AppL10n.of(context)),
    );
  }
}
