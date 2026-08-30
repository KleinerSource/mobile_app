import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

enum PlayerQueueItemType { video, audio }

@immutable
class PlayerQueueItem {
  const PlayerQueueItem({
    this.movieId,
    required this.title,
    this.type = PlayerQueueItemType.video,
    this.mediaId,
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
  final PlayerQueueItemType type;
  final String? mediaId;
  final int startPositionSec;
  final String? part;

  /// 文件管理器直链队列项使用的播放信息。
  final String? directUrl;
  final Map<String, String>? directHeaders;
  final String? directFormatHint;
  final String? directPlaybackFileName;
  final bool directPreferFfmpegForHls;

  /// 系统媒体会话使用的 ID。它只包含 OMM 影片 ID 或不可逆摘要，
  /// 不会把直链中的 token、密码或请求头暴露给通知与锁屏。
  String get safeMediaId {
    if (movieId != null) return 'movie:$movieId';
    final source = mediaId?.trim();
    if (source != null && source.isNotEmpty) return 'file:${_digest(source)}';
    return 'item:${_digest(title)}';
  }

  Map<String, dynamic> toAudioPayload() => <String, dynamic>{
    'title': title,
    'mediaId': safeMediaId,
    'url': directUrl ?? '',
    'headers': jsonEncode(directHeaders ?? const <String, String>{}),
    'formatHint': directFormatHint ?? '',
    'fileName': directPlaybackFileName ?? title,
  };
}

String playerQueueKey(Iterable<PlayerQueueItem> items) {
  final value = items.map((item) => item.safeMediaId).join('\u0000');
  return 'queue:${_digest(value)}';
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
