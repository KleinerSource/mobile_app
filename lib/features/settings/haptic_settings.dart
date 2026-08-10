import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';

class HapticSettingsRepository {
  HapticSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  HapticIntensity load() {
    return HapticIntensity.fromStorage(
      _prefs.getString(AppHaptics.preferenceKey),
    );
  }

  Future<void> save(HapticIntensity intensity) async {
    await _prefs.setString(
      AppHaptics.preferenceKey,
      intensity.storageValue,
    );
  }
}

final hapticSettingsRepositoryProvider = Provider<HapticSettingsRepository>(
  (ref) => HapticSettingsRepository(ref.watch(sharedPrefsProvider)),
);

class HapticIntensityNotifier extends Notifier<HapticIntensity> {
  @override
  HapticIntensity build() {
    final value = ref.watch(hapticSettingsRepositoryProvider).load();
    AppHaptics.setIntensity(value);
    return value;
  }

  Future<void> set(HapticIntensity value) async {
    if (value == state) return;
    final previous = state;
    state = value;
    AppHaptics.setIntensity(value);
    try {
      await ref.read(hapticSettingsRepositoryProvider).save(value);
    } catch (_) {
      state = previous;
      AppHaptics.setIntensity(previous);
      rethrow;
    }
  }
}

final hapticIntensityProvider =
    NotifierProvider<HapticIntensityNotifier, HapticIntensity>(
  HapticIntensityNotifier.new,
);
