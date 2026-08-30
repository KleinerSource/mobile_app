import 'package:flutter/foundation.dart';

@immutable
class PlayerQueueItem {
  const PlayerQueueItem({
    this.movieId,
    required this.title,
    this.startPositionSec = 0,
    this.part,
    this.directUrl,
    this.directHeaders,
    this.directFormatHint,
    this.directPlaybackFileName,
    this.directPreferFfmpegForHls = false,
  });

  /// OMM 影片队列项使用的影片 ID。文件直链队列项不需要该字段。
  final int? movieId;
  final String title;
  final int startPositionSec;
  final String? part;

  /// 文件管理器直链队列项使用的播放信息。
  final String? directUrl;
  final Map<String, String>? directHeaders;
  final String? directFormatHint;
  final String? directPlaybackFileName;
  final bool directPreferFfmpegForHls;
}
