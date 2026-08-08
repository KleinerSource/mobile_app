import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config_provider.dart';

enum PlayerLandscapeSide {
  cameraLeft('camera_left', '摄像头在左侧'),
  cameraRight('camera_right', '摄像头在右侧');

  const PlayerLandscapeSide(this.value, this.label);

  final String value;
  final String label;

  static PlayerLandscapeSide fromValue(String? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => PlayerLandscapeSide.cameraLeft,
    );
  }
}

enum PlayerEntryOrientation {
  unchanged('unchanged', '无变化'),
  forceLandscape('force_landscape', '强制横屏'),
  forcePortrait('force_portrait', '强制竖屏');

  const PlayerEntryOrientation(this.value, this.label);

  final String value;
  final String label;

  static PlayerEntryOrientation fromValue(String? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => PlayerEntryOrientation.forceLandscape,
    );
  }
}

@immutable
class PlayerSettings {
  const PlayerSettings({
    this.resumeFromLastPosition = true,
    this.landscapeSide = PlayerLandscapeSide.cameraLeft,
    this.entryOrientation = PlayerEntryOrientation.forceLandscape,
    this.doubleTapCenter = true,
    this.doubleTapEdges = true,
    this.hapticLongPress = true,
    this.hapticSeek = true,
    this.hapticRate = true,
    this.hapticProgressBar = true,
  });

  final bool resumeFromLastPosition;
  final PlayerLandscapeSide landscapeSide;
  final PlayerEntryOrientation entryOrientation;
  final bool doubleTapCenter;
  final bool doubleTapEdges;
  final bool hapticLongPress;
  final bool hapticSeek;
  final bool hapticRate;
  final bool hapticProgressBar;

  PlayerSettings copyWith({
    bool? resumeFromLastPosition,
    PlayerLandscapeSide? landscapeSide,
    PlayerEntryOrientation? entryOrientation,
    bool? doubleTapCenter,
    bool? doubleTapEdges,
    bool? hapticLongPress,
    bool? hapticSeek,
    bool? hapticRate,
    bool? hapticProgressBar,
  }) {
    return PlayerSettings(
      resumeFromLastPosition:
          resumeFromLastPosition ?? this.resumeFromLastPosition,
      landscapeSide: landscapeSide ?? this.landscapeSide,
      entryOrientation: entryOrientation ?? this.entryOrientation,
      doubleTapCenter: doubleTapCenter ?? this.doubleTapCenter,
      doubleTapEdges: doubleTapEdges ?? this.doubleTapEdges,
      hapticLongPress: hapticLongPress ?? this.hapticLongPress,
      hapticSeek: hapticSeek ?? this.hapticSeek,
      hapticRate: hapticRate ?? this.hapticRate,
      hapticProgressBar: hapticProgressBar ?? this.hapticProgressBar,
    );
  }
}

class PlayerSettingsRepository {
  PlayerSettingsRepository(this._prefs);

  static const _resumeKey = 'player.resume_from_last_position';
  static const _landscapeSideKey = 'player.landscape_side';
  static const _entryOrientationKey = 'player.entry_orientation';
  static const _doubleTapCenterKey = 'player.double_tap_center';
  static const _doubleTapEdgesKey = 'player.double_tap_edges';
  static const _hapticLongPressKey = 'player.haptic_long_press';
  static const _hapticSeekKey = 'player.haptic_seek';
  static const _hapticRateKey = 'player.haptic_rate';
  static const _hapticProgressBarKey = 'player.haptic_progress_bar';

  final SharedPreferences _prefs;

  PlayerSettings load() {
    return PlayerSettings(
      resumeFromLastPosition: _prefs.getBool(_resumeKey) ?? true,
      landscapeSide: PlayerLandscapeSide.fromValue(
        _prefs.getString(_landscapeSideKey),
      ),
      entryOrientation: PlayerEntryOrientation.fromValue(
        _prefs.getString(_entryOrientationKey),
      ),
      doubleTapCenter: _prefs.getBool(_doubleTapCenterKey) ?? true,
      doubleTapEdges: _prefs.getBool(_doubleTapEdgesKey) ?? true,
      hapticLongPress: _prefs.getBool(_hapticLongPressKey) ?? true,
      hapticSeek: _prefs.getBool(_hapticSeekKey) ?? true,
      hapticRate: _prefs.getBool(_hapticRateKey) ?? true,
      hapticProgressBar: _prefs.getBool(_hapticProgressBarKey) ?? true,
    );
  }

  Future<void> save(PlayerSettings settings) async {
    await Future.wait([
      _prefs.setBool(_resumeKey, settings.resumeFromLastPosition),
      _prefs.setString(_landscapeSideKey, settings.landscapeSide.value),
      _prefs.setString(
        _entryOrientationKey,
        settings.entryOrientation.value,
      ),
      _prefs.setBool(_doubleTapCenterKey, settings.doubleTapCenter),
      _prefs.setBool(_doubleTapEdgesKey, settings.doubleTapEdges),
      _prefs.setBool(_hapticLongPressKey, settings.hapticLongPress),
      _prefs.setBool(_hapticSeekKey, settings.hapticSeek),
      _prefs.setBool(_hapticRateKey, settings.hapticRate),
      _prefs.setBool(_hapticProgressBarKey, settings.hapticProgressBar),
    ]);
  }
}

final playerSettingsRepositoryProvider = Provider<PlayerSettingsRepository>(
  (ref) => PlayerSettingsRepository(ref.watch(sharedPrefsProvider)),
);

class PlayerSettingsNotifier extends Notifier<PlayerSettings> {
  @override
  PlayerSettings build() {
    return ref.watch(playerSettingsRepositoryProvider).load();
  }

  Future<void> update(PlayerSettings next) async {
    final previous = state;
    state = next;
    try {
      await ref.read(playerSettingsRepositoryProvider).save(next);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final playerSettingsProvider =
    NotifierProvider<PlayerSettingsNotifier, PlayerSettings>(
  PlayerSettingsNotifier.new,
);
