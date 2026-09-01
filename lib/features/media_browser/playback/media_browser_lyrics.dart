import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/player/audio/lrc_parser.dart';

/// 解析 /Audio/{id}/Lyrics 的原始响应为逐行歌词。
///
/// 两家服务器返回形态不同：Jellyfin 10.9+ 返回 LyricsDto 结构
/// （`{"Lyrics": [{"Text": ..., "Start": ticks}]}`），Emby 或旧版本可能
/// 返回纯 LRC 文本。无时间轴的歌词无法参与逐行同步，按「无歌词」处理。
LrcDocument? parseMediaBrowserLyrics(Object? raw) {
  if (raw is Map) {
    final lines = raw['Lyrics'];
    if (lines is List) return _fromLyricLines(lines);
    if (lines is String) return parseLrc(lines);
    return null;
  }
  if (raw is String) {
    final text = raw.trim();
    return text.isEmpty ? null : parseLrc(text);
  }
  return null;
}

LrcDocument? _fromLyricLines(List<dynamic> lines) {
  final cues = <LrcCue>[];
  for (final raw in lines) {
    if (raw is! Map) continue;
    final text = raw['Text']?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    final ticks = int.tryParse(raw['Start']?.toString() ?? '');
    if (ticks == null || ticks < 0) continue;
    cues.add(
      LrcCue(
        position: Duration(
          milliseconds: ticks ~/ (mediaBrowserTicksPerSecond ~/ 1000),
        ),
        text: text,
      ),
    );
  }
  if (cues.isEmpty) return null;
  cues.sort((a, b) => a.position.compareTo(b.position));
  return LrcDocument(cues: List<LrcCue>.unmodifiable(cues));
}
