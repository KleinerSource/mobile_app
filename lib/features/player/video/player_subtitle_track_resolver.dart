import 'package:media_kit/media_kit.dart';

/// 优先按 media_kit 的轨道 ID 选择内嵌字幕，ID 不一致时按字幕顺序回退。
SubtitleTrack? resolveSubtitleTrack(
  List<SubtitleTrack> tracks,
  String id, {
  int? fallbackIndex,
}) {
  for (final track in tracks) {
    if (track.id == id) return track;
  }
  if (fallbackIndex == null) return null;

  final embedded = tracks
      .where((track) => track.id != 'auto' && track.id != 'no')
      .toList();
  if (fallbackIndex < 0 || fallbackIndex >= embedded.length) return null;
  return embedded[fallbackIndex];
}
