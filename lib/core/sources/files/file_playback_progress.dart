import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FilePlaybackProgress {
  const FilePlaybackProgress({
    required this.positionSec,
    required this.durationSec,
  });

  final int positionSec;
  final int durationSec;

  double get ratio =>
      durationSec <= 0 ? 0 : (positionSec / durationSec).clamp(0.0, 1.0);

  int get percentage => (ratio * 100).round().clamp(0, 100);
}

/// 保存文件来源视频的本地续播位置。
///
/// 文件来源没有 OMM 的服务端影片 ID，因此只使用文件名作为本地记录标识。
/// 记录只包含播放位置和时长，不包含服务器凭据或目录路径。
class FilePlaybackProgressRepository {
  FilePlaybackProgressRepository(this._prefs);

  static const _keyPrefix = 'file.playback.position.';

  final SharedPreferences _prefs;

  FilePlaybackProgress? load(String fileName) {
    final key = _storageKey(fileName);
    if (key == null) return null;
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final positionSec = _positiveInt(decoded['position_sec']);
      final durationSec = _positiveInt(decoded['duration_sec']);
      if (positionSec == null || durationSec == null) return null;
      return FilePlaybackProgress(
        positionSec: positionSec,
        durationSec: durationSec,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePosition({
    required String fileName,
    required int positionSec,
    required int durationSec,
  }) async {
    final key = _storageKey(fileName);
    if (key == null || positionSec <= 0 || durationSec <= 0) return;
    if (positionSec >= durationSec * 0.95) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(
      key,
      jsonEncode({
        'position_sec': positionSec.clamp(1, durationSec),
        'duration_sec': durationSec,
      }),
    );
  }

  Future<void> clear(String fileName) async {
    final key = _storageKey(fileName);
    if (key != null) await _prefs.remove(key);
  }

  String? _storageKey(String fileName) {
    final value = _fileNameOnly(fileName);
    if (value.isEmpty) return null;
    return '$_keyPrefix${base64Url.encode(utf8.encode(value))}';
  }

  String _fileNameOnly(String value) {
    final segments = value.trim().split(RegExp(r'[\\/]'));
    for (final segment in segments.reversed) {
      final fileName = segment.trim();
      if (fileName.isNotEmpty) return fileName;
    }
    return '';
  }

  int? _positiveInt(Object? value) {
    final number = value is num ? value.toInt() : int.tryParse('$value');
    return number == null || number <= 0 ? null : number;
  }
}
