import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/server_config_provider.dart';
import 'update_service.dart';

class UpdateSettingsRepository {
  UpdateSettingsRepository(this._prefs);

  static const githubRepositoryKey = 'app.update.github_repository';

  final SharedPreferences _prefs;

  String? loadRepository() {
    final value = _prefs.getString(githubRepositoryKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> saveRepository(String? value) async {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      await _prefs.remove(githubRepositoryKey);
    } else {
      await _prefs.setString(githubRepositoryKey, normalized);
    }
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

final gitHubUpdateServiceProvider = Provider<GitHubUpdateService>(
  (ref) => GitHubUpdateService(),
);
