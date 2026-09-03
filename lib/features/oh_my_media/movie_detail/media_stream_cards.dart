import 'package:flutter/material.dart';

import 'package:omm/core/models/media_streams.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// 媒体流详情卡片轨道：视频 / 每条音轨一张卡 / 字幕，横向滚动。
///
/// 数据来自 `GET /movies/id/{id}/media-info` 的 `video` / `audio_streams[]` /
/// `subtitle_streams[]`（backend media_info_service.go 展开的 probe_json 缓存）。
/// 探测失败（.strm）时无流数据，[MediaStreamCards] 渲染为空。
class MediaStreamCards extends StatelessWidget {
  const MediaStreamCards({super.key, required this.detail, this.padding});

  final MediaInfoDetail detail;

  /// 横向滚动的内边距。调用方把滚动视口铺满屏宽（不再由外层 Section 垫
  /// 横向边距）时，用它让首卡与标题对齐、末卡滚到边缘后仍留呼吸空隙。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final streams = detail.streams;
    final cards = <Widget>[];
    if (streams.video != null) {
      cards.add(
        _VideoStreamCard(
          video: streams.video!,
          fallbackBitRate: detail.bitRate,
        ),
      );
    }
    for (var i = 0; i < streams.audioStreams.length; i++) {
      cards.add(
        _AudioStreamCard(ordinal: i + 1, track: streams.audioStreams[i]),
      );
    }
    if (streams.subtitleStreams.isNotEmpty) {
      cards.add(_SubtitleStreamCard(streams: streams.subtitleStreams));
    }
    if (cards.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                cards[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============ 卡片骨架 ============

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.icon,
    required this.title,
    required this.child,
    this.badge,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      width: 245,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: c.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (badge != null) badge!,
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: c.cardBorder),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow(this.label, this.value, {this.valueWidget});

  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(
                color: c.muted,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child:
                valueWidget ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppText.mono(
                    context,
                    size: 11.5,
                  ).copyWith(color: c.text),
                ),
          ),
        ],
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          height: 1.1,
        ),
      ),
    );
  }
}

// ============ 视频卡 ============

class _VideoStreamCard extends StatelessWidget {
  const _VideoStreamCard({required this.video, this.fallbackBitRate});

  final VideoStreamInfo video;

  /// 流级码率缺失且后端未能推导时，退回文件级总码率。
  final int? fallbackBitRate;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final range = dynamicRange(video);
    final badgeColor = switch (range.$2) {
      _RangeTone.dolbyVision => const Color(0xFFC084FC),
      _RangeTone.hdr10 => const Color(0xFFFFB454),
      _RangeTone.hlg => const Color(0xFF4ADE80),
      _RangeTone.sdr => c.muted,
    };
    return _CardShell(
      icon: Icons.movie_outlined,
      title: l.mediaStreamVideo,
      badge: _CardBadge(range.$1, badgeColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in _videoRows(video, fallbackBitRate, l))
            _CardRow(r.label, r.value!),
        ],
      ),
    );
  }
}

// ============ 音频卡 ============

class _AudioStreamCard extends StatelessWidget {
  const _AudioStreamCard({required this.ordinal, required this.track});

  final int ordinal;
  final AudioStreamInfo track;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return _CardShell(
      icon: Icons.graphic_eq_outlined,
      title: l.mediaStreamAudio(ordinal),
      badge: track.isDefault
          ? _CardBadge(l.mediaStreamDefault, c.accent)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in _audioRows(track, l)) _CardRow(r.label, r.value!),
        ],
      ),
    );
  }
}

// ============ 字幕卡 ============

class _SubtitleStreamCard extends StatelessWidget {
  const _SubtitleStreamCard({required this.streams});

  final List<SubtitleStreamInfo> streams;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return _CardShell(
      icon: Icons.subtitles_outlined,
      title: l.mediaStreamSubtitles,
      badge: _CardBadge(l.mediaStreamCount(streams.length), c.muted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final sub in streams)
            _CardRow(
              _opt(localizedLanguageLabel(l, sub.language)) ??
                  subtitleCodecLabel(sub.codec),
              subtitleCodecLabel(sub.codec),
              valueWidget: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 3,
                children: [
                  Text(
                    subtitleCodecLabel(sub.codec),
                    style: AppText.mono(
                      context,
                      size: 11.5,
                    ).copyWith(color: c.text),
                  ),
                  if (sub.isDefault) _CardBadge(l.mediaStreamDefault, c.accent),
                  if (sub.forced) _CardBadge(l.mediaStreamForced, c.warning),
                  _CardBadge(
                    sub.playable ? l.mediaStreamText : l.mediaStreamBitmap,
                    sub.playable
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFFFB454),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============ 格式化（与 Web 端 MediaInfoPanel 保持一致） ============

/// 卡片行：value 为 null 表示取不到数据，该行直接隐藏。
typedef _StreamRow = ({String label, String? value});

/// 格式化结果为空或占位 '-' 时视为无数据（返回 null）。
String? _opt(String? v) {
  if (v == null || v.isEmpty || v == '-') return null;
  return v;
}

List<_StreamRow> _videoRows(
  VideoStreamInfo video,
  int? fallbackBitRate,
  AppL10n l,
) {
  return [
    (label: l.mediaStreamEncoding, value: _opt(formatVideoCodec(video.codec))),
    (label: l.mediaStreamProfile, value: _opt(video.profile ?? '-')),
    (label: l.mediaStreamLevel, value: _opt(formatVideoLevel(video))),
    (
      label: l.mediaStreamResolution,
      value: video.width != null && video.height != null
          ? '${video.width}×${video.height}'
          : null,
    ),
    (label: l.mediaStreamAspectRatio, value: _opt(formatAspectRatio(video))),
    (
      label: l.mediaStreamFrameRate,
      value: _opt(formatFrameRate(video.frameRate)),
    ),
    (
      label: l.mediaStreamColorPrimaries,
      value: _opt(colorPrimariesLabel(video.colorPrimaries)),
    ),
    (
      label: l.mediaStreamColorSpace,
      value: _opt(colorSpaceLabel(video.colorSpace)),
    ),
    (
      label: l.mediaStreamTransfer,
      value: _opt(colorTransferLabel(video.colorTransfer)),
    ),
    (label: l.mediaStreamRange, value: _opt(colorRangeLabel(video.colorRange))),
    (
      label: l.mediaStreamBitDepth,
      value: video.bitDepth != null ? '${video.bitDepth}-bit' : null,
    ),
    (label: l.mediaStreamPixelFormat, value: video.pixFmt),
    (
      label: l.mediaStreamBitrate,
      value: _opt(formatBitrate(video.bitRate ?? fallbackBitRate)),
    ),
  ].where((r) => r.value != null).toList();
}

List<_StreamRow> _audioRows(AudioStreamInfo track, AppL10n l) {
  return [
    (
      label: l.mediaStreamLanguage,
      value: _opt(localizedLanguageLabel(l, track.language)),
    ),
    (label: l.mediaStreamEncoding, value: _opt(audioCodecLabel(track.codec))),
    (label: l.mediaStreamLevel, value: track.profile),
    (label: l.mediaStreamLayout, value: _opt(channelLayoutLabel(track))),
    (
      label: l.mediaStreamChannelsLabel,
      value: track.channels != null
          ? l.mediaStreamChannels(track.channels!)
          : null,
    ),
    (
      label: l.mediaStreamSampleRate,
      value: _opt(formatSampleRate(track.sampleRate)),
    ),
    (label: l.mediaStreamBitrate, value: _opt(formatBitrate(track.bitRate))),
    (label: l.mediaStreamTitle, value: track.title),
  ].where((r) => r.value != null).toList();
}

const _videoCodecNames = {
  'h264': 'H.264 (AVC)',
  'avc': 'H.264 (AVC)',
  'hevc': 'H.265 (HEVC)',
  'h265': 'H.265 (HEVC)',
  'av1': 'AV1',
  'vp9': 'VP9',
  'vp8': 'VP8',
  'mpeg4': 'MPEG-4',
  'mpeg2video': 'MPEG-2',
  'wmv3': 'WMV',
};

const _audioCodecNames = {
  'aac': 'AAC',
  'ac3': 'Dolby Digital (AC-3)',
  'eac3': 'Dolby Digital+ (E-AC-3)',
  'dts': 'DTS',
  'truehd': 'Dolby TrueHD',
  'flac': 'FLAC',
  'mp3': 'MP3',
  'opus': 'Opus',
  'vorbis': 'Vorbis',
  'pcm_s16le': 'PCM 16-bit',
  'pcm_s24le': 'PCM 24-bit',
};

const _subtitleCodecNames = {
  'subrip': 'SRT',
  'srt': 'SRT',
  'ass': 'ASS',
  'ssa': 'SSA',
  'webvtt': 'VTT',
  'mov_text': 'MOV-TXT',
  'hdmv_pgs_subtitle': 'PGS',
  'dvd_subtitle': 'VobSub',
  'dvb_subtitle': 'DVB-SUB',
};

const _colorPrimariesNames = {
  'bt709': 'BT.709',
  'bt2020': 'BT.2020',
  'bt601': 'BT.601',
  'smpte170m': 'SMPTE 170M',
  'smpte4312': 'DCI-P3',
  'smpte4320': 'Display P3',
};

const _colorSpaceNames = {
  'bt709': 'BT.709',
  'bt2020nc': 'BT.2020nc',
  'bt2020c': 'BT.2020c',
  'smpte170m': 'SMPTE 170M',
  'fcc': 'FCC',
};

const _colorTransferNames = {
  'smpte2084': 'SMPTE 2084 (PQ)',
  'arib-std-b67': 'ARIB B67 (HLG)',
  'bt709': 'BT.709',
  'gamma22': 'Gamma 2.2',
  'gamma28': 'Gamma 2.8',
  'linear': 'Linear',
  'iec61966-2-1': 'sRGB',
};

const _colorRangeNames = {'tv': 'Limited (16-235)', 'pc': 'Full (0-255)'};

String _mapLabel(Map<String, String> map, String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  return map[raw.toLowerCase()] ?? raw;
}

String formatVideoCodec(String? codec) {
  if (codec == null || codec.isEmpty) return '-';
  return _videoCodecNames[codec.toLowerCase()] ?? codec.toUpperCase();
}

String audioCodecLabel(String? codec) => _mapLabel(_audioCodecNames, codec);

String subtitleCodecLabel(String? codec) =>
    _mapLabel(_subtitleCodecNames, codec);

String languageLabel(String? lang) {
  if (lang == null || lang.isEmpty) return '-';
  return lang.toUpperCase();
}

String localizedLanguageLabel(AppL10n l, String? lang) {
  if (lang == null || lang.isEmpty) return '-';
  return switch (lang.toLowerCase()) {
    'jpn' || 'ja' => l.mediaLanguageJapanese,
    'eng' || 'en' => l.mediaLanguageEnglish,
    'chi' || 'zho' || 'zh' => l.mediaLanguageChinese,
    'yue' => l.mediaLanguageCantonese,
    'kor' || 'ko' => l.mediaLanguageKorean,
    'fra' || 'fre' || 'fr' => l.mediaLanguageFrench,
    'rus' || 'ru' => l.mediaLanguageRussian,
    'spa' => l.mediaLanguageSpanish,
    'deu' || 'ger' || 'de' => l.mediaLanguageGerman,
    'tha' || 'th' => l.mediaLanguageThai,
    'und' => l.mediaLanguageUndetermined,
    _ => lang.toUpperCase(),
  };
}

String colorPrimariesLabel(String? v) => _mapLabel(_colorPrimariesNames, v);

String colorSpaceLabel(String? v) => _mapLabel(_colorSpaceNames, v);

String colorTransferLabel(String? v) => _mapLabel(_colorTransferNames, v);

String colorRangeLabel(String? v) => _mapLabel(_colorRangeNames, v);

enum _RangeTone { dolbyVision, hdr10, hlg, sdr }

/// 动态范围：DoVi > HDR10(PQ) > HLG > SDR。
(String, _RangeTone) dynamicRange(VideoStreamInfo video) {
  if (video.dolbyVision) return ('Dolby Vision', _RangeTone.dolbyVision);
  switch (video.colorTransfer) {
    case 'smpte2084':
      return ('HDR10', _RangeTone.hdr10);
    case 'arib-std-b67':
      return ('HLG', _RangeTone.hlg);
  }
  return ('SDR', _RangeTone.sdr);
}

/// 视频等级：H.264 level 为 ×10(41→4.1)，HEVC 为 ×30(120→4.0)。
String formatVideoLevel(VideoStreamInfo video) {
  final level = video.level;
  if (level == null || level <= 0) return '-';
  final codec = (video.codec ?? '').toLowerCase();
  if (codec == 'h264' || codec == 'avc') {
    return 'L${(level / 10).toStringAsFixed(1)}';
  }
  if (codec == 'hevc' || codec == 'h265') {
    return 'L${(level / 30).toStringAsFixed(1)}';
  }
  return 'L$level';
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// 长宽比：优先 ffprobe display_aspect_ratio；缺失时按宽高约分，
/// 约分结果过大(如 160:67)则退化为两位小数(2.39:1)。
String formatAspectRatio(VideoStreamInfo video) {
  final dar = video.displayAspectRatio;
  if (dar != null && dar.isNotEmpty && dar != '0:1' && dar != 'N/A') {
    return dar;
  }
  final w = video.width;
  final h = video.height;
  if (w == null || h == null || w <= 0 || h <= 0) return '-';
  final g = _gcd(w, h);
  final rw = w ~/ g;
  final rh = h ~/ g;
  if (rw > 32 || rh > 32) return '${(w / h).toStringAsFixed(2)}:1';
  return '$rw:$rh';
}

String formatFrameRate(double? fps) {
  if (fps == null || fps <= 0) return '-';
  // 30000/1001 → 29.97，24/1 → 24
  final rounded = (fps * 1000).round() / 1000;
  final trimmed = rounded == rounded.roundToDouble()
      ? rounded.roundToDouble().toInt().toString()
      : rounded.toString();
  return '$trimmed fps';
}

/// 布局：优先 channel_layout，缺失按声道数推导。
String channelLayoutLabel(AudioStreamInfo track) {
  if (track.channelLayout != null && track.channelLayout!.isNotEmpty) {
    return track.channelLayout!;
  }
  return switch (track.channels) {
    1 => 'mono',
    2 => 'stereo',
    6 => '5.1',
    8 => '7.1',
    _ => '-',
  };
}

String formatSampleRate(int? hz) {
  if (hz == null || hz <= 0) return '-';
  final khz = hz / 1000;
  final text = khz == khz.roundToDouble()
      ? khz.roundToDouble().toInt().toString()
      : khz.toStringAsFixed(1);
  return '$text kHz';
}

String formatBitrate(int? bps) {
  if (bps == null || bps <= 0) return '-';
  if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(2)} Mbps';
  return '${(bps / 1000).round()} kbps';
}
