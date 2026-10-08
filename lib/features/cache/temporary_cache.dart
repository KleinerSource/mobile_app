import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum TemporaryCacheKind { image, music, other }

/// 只管理本应用创建的临时文件，播放/下载持有的文件延后到释放时删除。
class TemporaryCacheService {
  TemporaryCacheService({Directory? rootDirectory})
    : _rootOverride = rootDirectory;
  static final instance = TemporaryCacheService();
  final Directory? _rootOverride;
  final _owners = <String, Set<File>>{};
  final _pendingDeletes = <String>{};
  Future<void> _queue = Future<void>.value();

  String _pathKey(String path) {
    final key = File(path).absolute.path.replaceAll('\\', '/');
    return Platform.isWindows ? key.toLowerCase() : key;
  }

  bool isRetained(String path) => _owners.containsKey(_pathKey(path));
  bool isPendingDeletion(String path) =>
      _pendingDeletes.contains(_pathKey(path));

  void retain(File file) {
    (_owners[_pathKey(file.path)] ??= Set<File>.identity()).add(file);
  }

  Future<void> release(File file) {
    final key = _pathKey(file.path);
    final owners = _owners[key];
    owners?.remove(file);
    if (owners?.isNotEmpty == true) return Future<void>.value();
    _owners.remove(key);
    if (!_pendingDeletes.contains(key)) return Future<void>.value();
    return _enqueue(() async {
      if (_owners.containsKey(key)) return;
      await _delete(file);
      _pendingDeletes.remove(key);
    });
  }

  Future<int> usage(TemporaryCacheKind kind) => _enqueue(() async {
    var bytes = 0;
    await for (final file in _files(kind)) {
      try {
        bytes += await file.length();
      } on PathNotFoundException {
        // 播放会话可能刚释放并删除文件。
      }
    }
    return bytes;
  });

  Future<void> clear(TemporaryCacheKind kind) {
    // 在途下载可能尚未创建文件，仍须在释放时处理本次清理请求。
    for (final path in _owners.keys) {
      if (_kind(path) == kind) _pendingDeletes.add(path);
    }
    return _enqueue(() async {
      await for (final file in _files(kind)) {
        if (isRetained(file.path)) {
          _pendingDeletes.add(_pathKey(file.path));
        } else {
          await _delete(file);
        }
      }
    });
  }

  Stream<File> _files(TemporaryCacheKind kind) async* {
    Directory root;
    try {
      root = _rootOverride ?? await getTemporaryDirectory();
    } catch (_) {
      root = Directory.systemTemp;
    }
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is File && _kind(entity.path) == kind) yield entity;
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!const {
        'omm_mb_audio_media',
        'omm_mb_audio_art',
        'omm_audio_metadata',
      }.contains(name)) {
        continue;
      }
      await for (final child in entity.list(followLinks: false)) {
        if (child is File && _kind(child.path) == kind) yield child;
      }
    }
  }

  TemporaryCacheKind? _kind(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    final name = parts.last;
    final parent = parts.length > 1 ? parts[parts.length - 2] : '';
    if (parent == 'omm_mb_audio_art') return TemporaryCacheKind.image;
    if (parent == 'omm_mb_audio_media') return TemporaryCacheKind.music;
    if (parent == 'omm_audio_metadata' && name.startsWith('omm_audio_')) {
      return name.startsWith('omm_audio_art_')
          ? TemporaryCacheKind.image
          : TemporaryCacheKind.music;
    }
    if ((name.startsWith('omm-playback-') && name.endsWith('.tmp')) ||
        (name.startsWith('mdc-subtitle-') && name.endsWith('.vtt')) ||
        name.startsWith('omm_update_')) {
      return TemporaryCacheKind.other;
    }
    return null;
  }

  Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // 文件已经由其所属会话删除。
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
