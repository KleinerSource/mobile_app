import 'package:flutter/foundation.dart';

@immutable
class PlayerQueueItem {
  const PlayerQueueItem({
    required this.movieId,
    required this.title,
    this.startPositionSec = 0,
    this.part,
  });

  final int movieId;
  final String title;
  final int startPositionSec;
  final String? part;
}
