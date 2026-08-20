import 'package:flutter/material.dart';

import '../../core/models/media_streams.dart';
import '../../shared/stacked_badges.dart';
import '../i18n/poster_badge_visibility_provider.dart';

/// 详情页封面技术徽章规格。
@immutable
class CoverBadgeSpec {
  const CoverBadgeSpec(this.kind, this.label, this.color, [this.tooltip]);
  final PosterBadgeKind kind;
  final String label;
  final Color color;
  final String? tooltip;

  IconData get icon => switch (kind) {
        PosterBadgeKind.codec => Icons.memory_outlined,
        PosterBadgeKind.hdr => Icons.hdr_on,
        PosterBadgeKind.strm => Icons.link_outlined,
        PosterBadgeKind.subtitle => Icons.closed_caption_outlined,
        PosterBadgeKind.crack => Icons.lock_open_rounded,
        PosterBadgeKind.resolution => Icons.tv_rounded,
      };
}

// 番号后缀正则 · 规则与 core/models/movie.dart (MovieListItemX) 及
// Web 端 useCoverBadges.js 保持一致。
final _kEmbeddedSubtitleRegex = RegExp(
  r'(?:^|[-_. ])(c|ch|chs|cht|zh|sub|subs)(?=$|[-_. ])',
);
final _kCrackWithSubRegex = RegExp(r'(?:^|[-_. ])(uc|umr-c)(?=$|[-_. ])');
final _kUmrCrackRegex = RegExp(r'(?:^|[-_. ])umr(?:-c)?(?=$|[-_. ])');
final _kCrackRegex = RegExp(
  r'(?:^|[-_. ])(u|uc|uncen|uncensored|leak|leaked)(?=$|[-_. ])',
);
final _kUhdRegex = RegExp(r'(?:^|[-_. ])(2160p|4k|uhd)(?=$|[-_. ])');
final _kProb4Regex = RegExp(r'(?:^|[-_. ])prob[-_. ]?4(?=$|[-_. ])');
final _kHdRegex =
    RegExp(r'(?:^|[-_. ])(720p|1080p|1440p|hd|fhd|qhd)(?=$|[-_. ])');
const _uhdSizeThreshold = 15 * 1024 * 1024 * 1024;

String _fileNameStem(String? filePath) {
  final raw = (filePath ?? '').trim();
  if (raw.isEmpty) return '';
  final name = raw.split(RegExp(r'[\\/]')).last;
  if (name.isEmpty) return '';
  return name.replaceFirst(RegExp(r'\.[^.]+$'), '').toLowerCase();
}

/// 组合文件名后缀 + 媒体探测结果生成封面徽章(与 Web 端 useCoverBadges 对齐):
/// 编码 / HDR / STRM / 外挂字幕 / 内嵌字幕轨道 / 文件名内嵌字幕 / 破解 / UHD / HD，
/// 无数据的项自动省略。
List<CoverBadgeSpec> buildCoverBadges({
  String? filePath,
  int? fileSize,
  VideoStreamInfo? video,
  bool hasExternalSubtitle = false,
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
    badges.add(CoverBadgeSpec(
      PosterBadgeKind.codec,
      label,
      color,
      '视频编码: $label',
    ));
  }

  // HDR 动态范围: DoVi > HDR10(PQ) > HLG；SDR 不显示
  if (video != null) {
    if (video.dolbyVision) {
      badges.add(const CoverBadgeSpec(
        PosterBadgeKind.hdr,
        'Dolby Vision',
        Color(0xFF7C3AED),
        '动态范围: Dolby Vision',
      ));
    } else {
      switch (video.colorTransfer) {
        case 'smpte2084':
          badges.add(const CoverBadgeSpec(
            PosterBadgeKind.hdr,
            'HDR10',
            Color(0xFFEA580C),
            '动态范围: HDR10 (PQ)',
          ));
        case 'arib-std-b67':
          badges.add(const CoverBadgeSpec(
            PosterBadgeKind.hdr,
            'HLG',
            Color(0xFF16A34A),
            '动态范围: HLG',
          ));
      }
    }
  }

  final stem = _fileNameStem(filePath);

  if ((filePath ?? '').toLowerCase().endsWith('.strm')) {
    badges.add(const CoverBadgeSpec(
      PosterBadgeKind.strm,
      'STRM',
      Color(0xFF475569),
      'STRM 视频文件',
    ));
  }

  if (hasExternalSubtitle) {
    badges.add(const CoverBadgeSpec(
      PosterBadgeKind.subtitle,
      '字幕',
      Color(0xFFFF9F1C),
      '外挂字幕',
    ));
  }

  // 内嵌字幕轨道: 视频容器内的字幕流,与文件名标识相互独立
  if (hasMuxedSubtitle) {
    badges.add(const CoverBadgeSpec(
      PosterBadgeKind.subtitle,
      '字幕',
      Color(0xFF16A34A),
      '内嵌字幕轨道',
    ));
  }

  // 文件名内嵌标识: -c / -chs / -uc / -umr-c 等番号后缀
  if (stem.isNotEmpty &&
      (_kEmbeddedSubtitleRegex.hasMatch(stem) ||
          _kCrackWithSubRegex.hasMatch(stem))) {
    badges.add(const CoverBadgeSpec(
      PosterBadgeKind.subtitle,
      '字幕',
      Color(0xFFCA8A04),
      '内嵌字幕',
    ));
  }

  if (stem.isNotEmpty &&
      (_kUmrCrackRegex.hasMatch(stem) || _kCrackRegex.hasMatch(stem))) {
    badges.add(const CoverBadgeSpec(
      PosterBadgeKind.crack,
      '破解',
      Color(0xFFDB2777),
      '破解/无码',
    ));
  }

  // UHD / HD: 高度优先，文件名后缀与 prob4+大小 兜底
  final height = video?.height ?? 0;
  final isUhd = height >= 2160 ||
      (stem.isNotEmpty && _kUhdRegex.hasMatch(stem)) ||
      (stem.isNotEmpty &&
          (fileSize ?? 0) > _uhdSizeThreshold &&
          _kProb4Regex.hasMatch(stem));
  if (isUhd) {
    badges.add(const CoverBadgeSpec(
      PosterBadgeKind.resolution,
      'UHD',
      Color(0xFF2563EB),
      '2160p / 4K',
    ));
  } else if ((height >= 720 && height < 2160) ||
      (stem.isNotEmpty && _kHdRegex.hasMatch(stem))) {
    badges.add(const CoverBadgeSpec(
      PosterBadgeKind.resolution,
      'HD',
      Color(0xFF0891B2),
      '720p 及以上',
    ));
  }

  return badges;
}

/// 封面底部技术徽章行:
/// 仅多来源字幕合并为叠堆(收起时叠加、点按向上展开),
/// 其余徽章(编码/HDR/分辨率/STRM/破解)逐个平铺显示。
class CoverBadgeRow extends StatelessWidget {
  const CoverBadgeRow({super.key, required this.badges});

  final List<CoverBadgeSpec> badges;

  @override
  Widget build(BuildContext context) {
    final subs = <CoverBadgeSpec>[];
    final others = <CoverBadgeSpec>[];
    for (final b in badges) {
      if (b.kind == PosterBadgeKind.subtitle) {
        subs.add(b);
      } else {
        others.add(b);
      }
    }

    Widget subGroup(List<CoverBadgeSpec> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      if (list.length == 1) return _CoverBadgePill(spec: list.single);
      return StackedBadges(
        tooltip: '字幕 ×${list.length}（点按展开）',
        children: [for (final b in list) _CoverBadgePill(spec: b)],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final b in others) _CoverBadgePill(spec: b),
        subGroup(subs),
      ],
    );
  }
}

/// 单个彩色胶囊徽章 (原 CoverBadgeRow 的内联样式)
class _CoverBadgePill extends StatelessWidget {
  const _CoverBadgePill({required this.spec});

  final CoverBadgeSpec spec;

  @override
  Widget build(BuildContext context) {
    final b = spec;
    return Tooltip(
      message: b.tooltip ?? b.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: b.color,
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
            Icon(b.icon, color: Colors.white, size: 11),
            const SizedBox(width: 3),
            Text(
              b.label,
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
