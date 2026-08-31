import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config_provider.dart';

enum FileBrowserSortField { name, date, size, category }

@immutable
class FileBrowserPreferences {
  const FileBrowserPreferences({
    this.sortField = FileBrowserSortField.name,
    this.sortAscending = true,
    this.showHiddenFiles = false,
  });

  final FileBrowserSortField sortField;
  final bool sortAscending;
  final bool showHiddenFiles;

  FileBrowserPreferences copyWith({
    FileBrowserSortField? sortField,
    bool? sortAscending,
    bool? showHiddenFiles,
  }) {
    return FileBrowserPreferences(
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
    );
  }
}

class FileBrowserPreferencesRepository {
  FileBrowserPreferencesRepository(this._prefs);

  static const _storageKeyPrefix = 'file_browser.preferences.v1.';

  final SharedPreferences _prefs;
  Future<void> _writeQueue = Future<void>.value();

  FileBrowserPreferences load(String serverId) {
    final raw = _prefs.getString(_key(serverId));
    if (raw == null || raw.isEmpty) return const FileBrowserPreferences();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const FileBrowserPreferences();
      return FileBrowserPreferences(
        sortField: _sortField(decoded['sort_field']),
        sortAscending: decoded['sort_ascending'] is bool
            ? decoded['sort_ascending'] as bool
            : true,
        showHiddenFiles: decoded['show_hidden_files'] is bool
            ? decoded['show_hidden_files'] as bool
            : false,
      );
    } on FormatException {
      return const FileBrowserPreferences();
    }
  }

  Future<void> save(String serverId, FileBrowserPreferences preferences) {
    final result = _writeQueue.then((_) async {
      await _prefs.setString(
        _key(serverId),
        jsonEncode({
          'sort_field': preferences.sortField.name,
          'sort_ascending': preferences.sortAscending,
          'show_hidden_files': preferences.showHiddenFiles,
        }),
      );
    });
    _writeQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  /// 等待已经排队的偏好写入完成。
  Future<void> flush() => _writeQueue;

  FileBrowserSortField _sortField(Object? value) {
    for (final field in FileBrowserSortField.values) {
      if (field.name == value) return field;
    }
    return FileBrowserSortField.name;
  }

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

final fileBrowserPreferencesRepositoryProvider =
    Provider<FileBrowserPreferencesRepository>(
      (ref) => FileBrowserPreferencesRepository(ref.watch(sharedPrefsProvider)),
    );

class FileBrowserPreferencesNotifier extends Notifier<FileBrowserPreferences> {
  FileBrowserPreferencesNotifier(this.serverId);

  final String serverId;
  late FileBrowserPreferencesRepository _repository;

  @override
  FileBrowserPreferences build() {
    _repository = ref.read(fileBrowserPreferencesRepositoryProvider);
    return _repository.load(serverId);
  }

  void toggleHiddenFiles() {
    _update(state.copyWith(showHiddenFiles: !state.showHiddenFiles));
  }

  void setSort(FileBrowserSortField field) {
    final next = state.sortField == field
        ? state.copyWith(sortAscending: !state.sortAscending)
        : state.copyWith(sortField: field, sortAscending: true);
    _update(next);
  }

  void _update(FileBrowserPreferences next) {
    state = next;
    unawaited(_repository.save(serverId, next));
  }
}

final fileBrowserPreferencesProvider =
    NotifierProvider.family<
      FileBrowserPreferencesNotifier,
      FileBrowserPreferences,
      String
    >(FileBrowserPreferencesNotifier.new);
