import 'package:flutter/material.dart';

import '../../core/models/media_streams.dart';

/// 详情页封面技术徽章规格。
@immutable
class CoverBadgeSpec {
  const CoverBadgeSpec(this.label, this.color, [this.tooltip]);
  final String label;
  final Color color;
  final String? tooltip;
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
/// 编码 / HDR / STRM / 内嵌字幕 / 破解 / UHD / HD，无数据的项自动省略。
List<CoverBadgeSpec> buildCoverBadges({
  String? filePath,
  int? fileSize,
  VideoStreamInfo? video,
}) {
  final badges = <CoverBadgeSpec>[];

  // 编码
  final codec = (video?.codec ?? '').trim().toLowerCase();
  if (codec.isNotEmpty) {
    final (label, color) = switch (codec) {
      'h264' || 'avc' || 'avc1' => ('H264', const Color(0xFF9AD2FF)),
      'hevc' || 'h265' => ('HEVC', const Color(0xFF8DF0BE)),
      'av1' => ('AV1', const Color(0xFFD0B0FF)),
      'vp9' => ('VP9', const Color(0xFFFFCF8A)),
      _ => (codec.toUpperCase(), const Color(0xFFD7DCE6)),
    };
    badges.add(CoverBadgeSpec(label, color, '视频编码: $label'));
  }

  // HDR 动态范围: DoVi > HDR10(PQ) > HLG；SDR 不显示
  if (video != null) {
    if (video.dolbyVision) {
      badges.add(const CoverBadgeSpec('Dolby Vision', Color(0xFFC084FC), '动态范围: Dolby Vision'));
    } else {
      switch (video.colorTransfer) {
        case 'smpte2084':
          badges.add(const CoverBadgeSpec('HDR10', Color(0xFFFFB454), '动态范围: HDR10 (PQ)'));
        case 'arib-std-b67':
          badges.add(const CoverBadgeSpec('HLG', Color(0xFF4ADE80), '动态范围: HLG'));
      }
    }
  }

  final stem = _fileNameStem(filePath);

  if ((filePath ?? '').toLowerCase().endsWith('.strm')) {
    badges.add(const CoverBadgeSpec('STRM', Color(0xFFE2E8F0), 'STRM 视频文件'));
  }

  if (stem.isNotEmpty &&
      (_kEmbeddedSubtitleRegex.hasMatch(stem) ||
          _kCrackWithSubRegex.hasMatch(stem))) {
    badges.add(const CoverBadgeSpec('字幕', Color(0xFFFFE066), '内嵌字幕'));
  }

  if (stem.isNotEmpty &&
      (_kUmrCrackRegex.hasMatch(stem) || _kCrackRegex.hasMatch(stem))) {
    badges.add(const CoverBadgeSpec('破解', Color(0xFFFF7A98), '破解/无码'));
  }

  // UHD / HD: 高度优先，文件名后缀与 prob4+大小 兜底
  final height = video?.height ?? 0;
  final isUhd = height >= 2160 ||
      (stem.isNotEmpty && _kUhdRegex.hasMatch(stem)) ||
      (stem.isNotEmpty &&
          (fileSize ?? 0) > _uhdSizeThreshold &&
          _kProb4Regex.hasMatch(stem));
  if (isUhd) {
    badges.add(const CoverBadgeSpec('UHD', Color(0xFF7CC4FF), '2160p / 4K'));
  } else if ((height >= 720 && height < 2160) ||
      (stem.isNotEmpty && _kHdRegex.hasMatch(stem))) {
    badges.add(const CoverBadgeSpec('HD', Color(0xFF4CC9F0), '720p 及以上'));
  }

  return badges;
}

/// 封面底部技术徽章行(半透明胶囊，横向排列)。
class CoverBadgeRow extends StatelessWidget {
  const CoverBadgeRow({super.key, required this.badges});

  final List<CoverBadgeSpec> badges;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final b in badges)
          Tooltip(
            message: b.tooltip ?? b.label,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: b.color.withValues(alpha: 0.55)),
              ),
              child: Text(
                b.label,
                style: TextStyle(
                  color: b.color,
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
