import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/server_config_provider.dart';
import 'update_models.dart';
import 'update_service.dart';

class UpdateSettingsRepository {
  UpdateSettingsRepository(this._prefs);

  static const githubRepositoryKey = 'app.update.github_repository';
  static const ignoredUpdateKey = 'app.update.ignored_update';
  static const includeDevelopmentKey = 'app.update.include_development';

  final SharedPreferences _prefs;

  String? loadRepository() {
    final value = _prefs.getString(githubRepositoryKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> saveRepository(String? value) async {
    final normalized = value?.trim() ?? '';
    final previous = loadRepository();
    if (normalized.isEmpty) {
      await _prefs.remove(githubRepositoryKey);
      await _prefs.remove(ignoredUpdateKey);
    } else {
      await _prefs.setString(githubRepositoryKey, normalized);
      if (previous != normalized) await _prefs.remove(ignoredUpdateKey);
    }
  }

  bool loadIncludeDevelopment() =>
      _prefs.getBool(includeDevelopmentKey) ?? false;

  Future<void> saveIncludeDevelopment(bool value) async {
    if (loadIncludeDevelopment() == value) return;
    await _prefs.setBool(includeDevelopmentKey, value);
    await _prefs.remove(ignoredUpdateKey);
  }

  bool isUpdateIgnored({
    required String repositoryUrl,
    required UpdatePlatform platform,
    required AppReleaseVersion version,
  }) {
    return _prefs.getString(ignoredUpdateKey) ==
        _ignoredUpdateValue(repositoryUrl, platform, version);
  }

  Future<void> ignoreUpdate({
    required String repositoryUrl,
    required UpdatePlatform platform,
    required AppReleaseVersion version,
  }) {
    return _prefs.setString(
      ignoredUpdateKey,
      _ignoredUpdateValue(repositoryUrl, platform, version),
    );
  }

  String _ignoredUpdateValue(
    String repositoryUrl,
    UpdatePlatform platform,
    AppReleaseVersion version,
  ) {
    return '${repositoryUrl.trim()}|${platform.name}|${version.display}';
  }
}

final updateSettingsRepositoryProvider = Provider<UpdateSettingsRepository>(
  (ref) => UpdateSettingsRepository(ref.watch(sharedPrefsProvider)),
);

class UpdateRepositoryNotifier extends Notifier<String?> {
  @override
  String? build() {
    return ref.watch(updateSettingsRepositoryProvider).loadRepository();
  }

  Future<void> save(String? value) async {
    final repository = ref.read(updateSettingsRepositoryProvider);
    await repository.saveRepository(value);
    state = value?.trim().isEmpty == true ? null : value?.trim();
  }
}

final updateRepositoryUrlProvider =
    NotifierProvider<UpdateRepositoryNotifier, String?>(
      UpdateRepositoryNotifier.new,
    );

class IncludeDevelopmentUpdatesNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(updateSettingsRepositoryProvider).loadIncludeDevelopment();
  }

  Future<void> setEnabled(bool value) async {
    if (value == state) return;
    final previous = state;
    state = value;
    try {
      await ref
          .read(updateSettingsRepositoryProvider)
          .saveIncludeDevelopment(value);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final includeDevelopmentUpdatesProvider =
    NotifierProvider<IncludeDevelopmentUpdatesNotifier, bool>(
      IncludeDevelopmentUpdatesNotifier.new,
    );

final gitHubUpdateServiceProvider = Provider<GitHubUpdateService>(
  (ref) => GitHubUpdateService(),
);
