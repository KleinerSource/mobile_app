import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/sources/common/source_id.dart';
import '../../core/sources/files/file_entry.dart';

/// 收藏的文件/目录。
///
/// 收藏按服务器分别存储（存储键含服务器 ID），不会跨服务器展示；
/// 记录里同时保留 sourceId，使键与 FilePath.stableKey 一致。
@immutable
class FileFavorite {
  const FileFavorite({
    required this.sourceId,
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.addedAtMilliseconds,
  });

  factory FileFavorite.fromEntry(FileEntry entry) {
    return FileFavorite(
      sourceId: entry.path.sourceId.value,
      path: entry.path.value,
      name: entry.name,
      isDirectory: entry.isDirectory,
      addedAtMilliseconds: DateTime.now().millisecondsSinceEpoch,
    );
  }

  final String sourceId;
  final String path;
  final String name;
  final bool isDirectory;
  final int addedAtMilliseconds;

  /// 与 FilePath.stableKey 保持一致，用于判断是否已收藏。
  String get stableKey => '$sourceId:$path';

  /// 还原为最小的 FileEntry，供预览/图标等页面逻辑复用。
  FileEntry toEntry(SourceId fallbackSourceId) {
    return FileEntry(
      path: FilePath(sourceId: fallbackSourceId, value: path),
      name: name,
      type: isDirectory ? FileEntryType.directory : FileEntryType.file,
    );
  }

  Map<String, Object?> toJson() => {
    'source_id': sourceId,
    'path': path,
    'name': name,
    'is_directory': isDirectory,
    'added_at_ms': addedAtMilliseconds,
  };

  static FileFavorite? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    final sourceId = decoded['source_id'];
    final path = decoded['path'];
    final name = decoded['name'];
    if (sourceId is! String || path is! String || name is! String) {
      return null;
    }
    return FileFavorite(
      sourceId: sourceId,
      path: path,
      name: name,
      isDirectory:
          decoded['is_directory'] is bool
              ? decoded['is_directory'] as bool
              : false,
      addedAtMilliseconds:
          decoded['added_at_ms'] is int
              ? decoded['added_at_ms'] as int
              : 0,
    );
  }
}

class FileFavoritesRepository {
  FileFavoritesRepository(this._prefs);

  static const _storageKeyPrefix = 'file_browser.favorites.v1.';

  final SharedPreferences _prefs;
  Future<void> _writeQueue = Future<void>.value();

  List<FileFavorite> load(String serverId) {
    final raw = _prefs.getString(_key(serverId));
    if (raw == null || raw.isEmpty) return const <FileFavorite>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <FileFavorite>[];
      return <FileFavorite>[
        for (final item in decoded)
          if (FileFavorite.fromJson(item) case final favorite?) favorite,
      ];
    } on FormatException {
      return const <FileFavorite>[];
    }
  }

  Future<void> save(String serverId, List<FileFavorite> favorites) {
    final result = _writeQueue.then((_) async {
      await _prefs.setString(
        _key(serverId),
        jsonEncode([for (final favorite in favorites) favorite.toJson()]),
      );
    });
    _writeQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  /// 等待已经排队的收藏写入完成。
  Future<void> flush() => _writeQueue;

  String _key(String serverId) {
    final normalized = serverId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(serverId, 'serverId', '服务器 ID 不能为空');
    }
    final encoded = base64Url
        .encode(utf8.encode(normalized))
        .replaceAll('=', '');
    return '$_storageKeyPrefix$encoded';
  }
}

final fileFavoritesRepositoryProvider =
    Provider<FileFavoritesRepository>(
      (ref) => FileFavoritesRepository(ref.watch(sharedPrefsProvider)),
    );

class FileFavoritesNotifier extends FamilyNotifier<List<FileFavorite>, String> {
  late FileFavoritesRepository _repository;

  @override
  List<FileFavorite> build(String serverId) {
    _repository = ref.read(fileFavoritesRepositoryProvider);
    return _repository.load(serverId);
  }

  bool isFavorite(String stableKey) =>
      state.any((favorite) => favorite.stableKey == stableKey);

  /// 切换收藏状态；返回 true 表示已加入收藏。
  bool toggle(FileEntry entry) {
    final next = [...state];
    final index = next.indexWhere(
      (favorite) => favorite.stableKey == entry.stableKey,
    );
    final added = index < 0;
    if (added) {
      next.add(FileFavorite.fromEntry(entry));
    } else {
      next.removeAt(index);
    }
    _update(next);
    return added;
  }

  void remove(String stableKey) {
    if (!isFavorite(stableKey)) return;
    _update([
      for (final favorite in state)
        if (favorite.stableKey != stableKey) favorite,
    ]);
  }

  void _update(List<FileFavorite> next) {
    state = next;
    unawaited(_repository.save(arg, next));
  }
}

final fileFavoritesProvider =
    NotifierProvider.family<FileFavoritesNotifier, List<FileFavorite>, String>(
      FileFavoritesNotifier.new,
    );
