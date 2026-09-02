import 'package:flutter/widgets.dart';

import 'package:omm/core/models/media_streams.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/oh_my_media/movie_detail/media_stream_cards.dart';

/// Emby/Jellyfin/fnos 的「媒体信息」区块 · 复用 OMM 详情页的流卡片，
/// 把 MediaSource.MediaStreams 映射成 MediaInfoDetail 后交给
/// [MediaStreamCards] 渲染（视频/HDR 徽章 + 每条音轨 + 字幕汇总）。
///
/// 滚动视口铺满屏宽：首卡与标题对齐，向左滚动卡片可贴到屏幕边缘
/// （外层不再垫横向边距，由卡片轨道自带的滚动内边距控制起止位置）。
class MediaBrowserMediaInfoSection extends StatelessWidget {
  const MediaBrowserMediaInfoSection({super.key, required this.item});

  final MediaBrowserItem item;

  @override
  Widget build(BuildContext context) {
    final detail = mediaBrowserMediaInfoDetail(item);
    if (detail == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Text('媒体信息', style: AppText.sectionTitle(context)),
          ),
          MediaStreamCards(
            detail: detail,
            padding: const EdgeInsets.symmetric(horizontal: 22),
          ),
        ],
      ),
    );
  }
}

/// 条目的首选媒体源 → OMM 媒体信息模型；无媒体源或无任何流时返回 null。
MediaInfoDetail? mediaBrowserMediaInfoDetail(MediaBrowserItem item) {
  final source = item.mediaSources.isEmpty ? null : item.mediaSources.first;
  if (source == null) return null;
  final streams = source.mediaStreams;
  final video = streams
      .where((stream) => stream.type.toLowerCase() == 'video')
      .firstOrNull;
  final audio = streams
      .where((stream) => stream.type.toLowerCase() == 'audio')
      .toList(growable: false);
  final subtitle = streams
      .where((stream) => stream.type.toLowerCase() == 'subtitle')
      .toList(growable: false);
  if (video == null && audio.isEmpty && subtitle.isEmpty) return null;
  return MediaInfoDetail(
    container: source.container?.trim().isEmpty == true
        ? null
        : source.container,
    durationSec: mediaBrowserTicksToSeconds(item.runTimeTicks).toDouble(),
    bitRate: video?.bitRate,
    fileSize: source.sizeInBytes,
    streams: MediaStreams(
      video: video == null ? null : _videoInfo(video),
      audioStreams: [for (final stream in audio) _audioInfo(stream)],
      subtitleStreams: [for (final stream in subtitle) _subtitleInfo(stream)],
    ),
  );
}

VideoStreamInfo _videoInfo(MediaBrowserMediaStream stream) => VideoStreamInfo(
  index: stream.index,
  codec: stream.codec,
  profile: stream.profile,
  level: stream.level,
  width: stream.width,
  height: stream.height,
  frameRate: double.tryParse(stream.frameRate ?? ''),
  pixFmt: stream.pixelFormat,
  bitRate: stream.bitRate,
  displayAspectRatio: stream.aspectRatio,
  bitDepth: stream.bitDepth,
  colorTransfer: stream.colorTransfer,
  colorPrimaries: stream.colorPrimaries,
  colorSpace: stream.colorSpace,
  colorRange: stream.colorRange,
  dolbyVision: _isDolbyVision(stream),
);

AudioStreamInfo _audioInfo(MediaBrowserMediaStream stream) => AudioStreamInfo(
  index: stream.index,
  codec: stream.codec,
  profile: stream.profile,
  channels: stream.channels,
  channelLayout: stream.channelLayout,
  sampleRate: stream.sampleRate,
  bitRate: stream.bitRate,
  language: stream.language,
  title: stream.title ?? stream.displayTitle,
  isDefault: stream.isDefault,
);

SubtitleStreamInfo _subtitleInfo(MediaBrowserMediaStream stream) =>
    SubtitleStreamInfo(
      index: stream.index,
      codec: stream.codec,
      language: stream.language,
      title: stream.title ?? stream.displayTitle,
      isDefault: stream.isDefault,
      forced: stream.isForced,
      // 外挂位图（PGS .sup）无法客户端渲染，仅展示。
      playable: !stream.isBitmap || !stream.isExternal,
    );

bool _isDolbyVision(MediaBrowserMediaStream stream) {
  final range = (stream.videoRangeType ?? '').toLowerCase();
  if (range.contains('dovi') || range.contains('dolby')) return true;
  return (stream.profile ?? '').toLowerCase().contains('dolby vision');
}
