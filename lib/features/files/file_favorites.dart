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
  static const _manualOrderKeyPrefix = 'file_browser.favorites.manual.v1.';

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

  /// 存储数组本身有序：手动拖拽后的顺序就是保存顺序。
  Future<void> save(String serverId, List<FileFavorite> favorites) {
    return _enqueue(() async {
      await _prefs.setString(
        _key(serverId),
        jsonEncode([for (final favorite in favorites) favorite.toJson()]),
      );
    });
  }

  /// 是否已进入手动排序模式（用户拖拽过收藏后启用）。
  bool loadManualOrder(String serverId) =>
      _prefs.getBool(_manualOrderKeyPrefix + _encodedId(serverId)) ?? false;

  Future<void> saveManualOrder(String serverId, bool value) {
    return _enqueue(
      () async => _prefs.setBool(
        _manualOrderKeyPrefix + _encodedId(serverId),
        value,
      ),
    );
  }

  /// 等待已经排队的收藏写入完成。
  Future<void> flush() => _writeQueue;

  /// 收藏写入按调用顺序串行落盘，避免并发覆写互相吞掉。
  Future<void> _enqueue(Future<void> Function() write) {
    final result = _writeQueue.then((_) => write());
    _writeQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  String _key(String serverId) => '$_storageKeyPrefix${_encodedId(serverId)}';

  String _encodedId(String serverId) {
    final normalized = serverId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(serverId, 'serverId', '服务器 ID 不能为空');
    }
    return base64Url
        .encode(utf8.encode(normalized))
        .replaceAll('=', '');
  }
}

final fileFavoritesRepositoryProvider =
    Provider<FileFavoritesRepository>(
      (ref) => FileFavoritesRepository(ref.watch(sharedPrefsProvider)),
    );

/// 手动排序模式：用户在收藏列表拖拽过一次后启用，此后列表顺序完全由
/// 存储数组顺序决定（新增收藏置顶），不再按「目录在前 + 时间倒序」自动排。
class FileFavoritesManualOrderNotifier extends FamilyNotifier<bool, String> {
  late FileFavoritesRepository _repository;

  @override
  bool build(String serverId) {
    _repository = ref.read(fileFavoritesRepositoryProvider);
    return _repository.loadManualOrder(serverId);
  }

  void enable() {
    if (state) return;
    state = true;
    unawaited(_repository.saveManualOrder(arg, true));
  }
}

final fileFavoritesManualOrderProvider =
    NotifierProvider.family<
      FileFavoritesManualOrderNotifier,
      bool,
      String
    >(FileFavoritesManualOrderNotifier.new);

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
      // 手动排序模式下新收藏置顶，保证收藏后立即可见；默认模式仍追加
      // 到尾部，由列表按时间倒序展示。
      final fresh = FileFavorite.fromEntry(entry);
      if (ref.read(fileFavoritesManualOrderProvider(arg))) {
        next.insert(0, fresh);
      } else {
        next.add(fresh);
      }
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

  /// 应用拖拽后的完整顺序，并从此进入手动排序模式。
  void reorder(List<FileFavorite> ordered) {
    if (ordered.length != state.length) return;
    enableManualOrder();
    _update([...ordered]);
  }

  void enableManualOrder() {
    ref.read(fileFavoritesManualOrderProvider(arg).notifier).enable();
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
