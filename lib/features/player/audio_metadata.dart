import 'package:flutter/foundation.dart';

import 'lrc_parser.dart';
import 'player_queue.dart';

@immutable
class AudioTrackMetadata {
  const AudioTrackMetadata({
    this.artworkPath,
    this.artworkMimeType,
    this.artist,
    this.album,
    this.lyrics,
  });

  final String? artworkPath;
  final String? artworkMimeType;
  final String? artist;
  final String? album;
  final LrcDocument? lyrics;
}

typedef AudioTrackMetadataLoader =
    Future<AudioTrackMetadata> Function(PlayerQueueItem item);

abstract interface class AudioMetadataSink {
  Future<void> updateCurrentMetadata(AudioTrackMetadata metadata);
}
