import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/server_config_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'playback_engine.dart';

enum PlayerLandscapeSide {
  cameraLeft('camera_left'),
  cameraRight('camera_right');

  const PlayerLandscapeSide(this.value);

  final String value;

  String label(AppL10n l) => switch (this) {
    PlayerLandscapeSide.cameraLeft => l.playerLandscapeCameraLeft,
    PlayerLandscapeSide.cameraRight => l.playerLandscapeCameraRight,
  };

  static PlayerLandscapeSide fromValue(String? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => PlayerLandscapeSide.cameraRight,
    );
  }
}

enum PlayerEntryOrientation {
  unchanged('unchanged'),
  forceLandscape('force_landscape'),
  forcePortrait('force_portrait');

  const PlayerEntryOrientation(this.value);

  final String value;

  String label(AppL10n l) => switch (this) {
    PlayerEntryOrientation.unchanged => l.playerOrientationUnchanged,
    PlayerEntryOrientation.forceLandscape => l.playerOrientationForceLandscape,
    PlayerEntryOrientation.forcePortrait => l.playerOrientationForcePortrait,
  };

  static PlayerEntryOrientation fromValue(String? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => PlayerEntryOrientation.forceLandscape,
    );
  }
}

/// 播放预载的内存档位。预载（前向 demuxer 缓冲）在播放和暂停期间都会
/// 后台填充，直到达到档位字节数或媒体结尾。
enum PlayerPreloadSize {
  mb250('250mb'),
  mb500('500mb'),
  mb750('750mb'),
  gb1('1gb');

  const PlayerPreloadSize(this.value);

  final String value;

  String label(AppL10n l) => switch (this) {
    PlayerPreloadSize.mb250 => l.playerPreload250Mb,
    PlayerPreloadSize.mb500 => l.playerPreload500Mb,
    PlayerPreloadSize.mb750 => l.playerPreload750Mb,
    PlayerPreloadSize.gb1 => l.playerPreload1Gb,
  };

  int get bytes => switch (this) {
    PlayerPreloadSize.mb250 => 250 * 1024 * 1024,
    PlayerPreloadSize.mb500 => 500 * 1024 * 1024,
    PlayerPreloadSize.mb750 => 750 * 1024 * 1024,
    PlayerPreloadSize.gb1 => 1024 * 1024 * 1024,
  };

  static PlayerPreloadSize fromValue(String? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => PlayerPreloadSize.mb250,
    );
  }
}

@immutable
class PlayerSettings {
  const PlayerSettings({
    this.resumeFromLastPosition = true,
    this.landscapeSide = PlayerLandscapeSide.cameraRight,
    this.entryOrientation = PlayerEntryOrientation.forceLandscape,
    this.preloadSize = PlayerPreloadSize.mb250,
    this.iosEngine = PlaybackEngineKind.libmpv,
    this.debugMode = false,
    this.performanceMonitorEnabled = false,
    this.doubleTapCenter = true,
    this.doubleTapEdges = true,
    this.hapticLongPress = true,
    this.hapticSeek = true,
    this.hapticRate = true,
    this.hapticProgressBar = true,
    this.showSystemTime = true,
    this.showNetworkSpeed = true,
    this.showCpuUsage = true,
    this.showBattery = true,
    this.showPlayPauseButton = true,
    this.showSeekButtons = true,
    this.showSpeedButton = true,
    this.showPipButton = true,
    this.showOrientationButton = true,
    this.showMediaSwitchButton = true,
  });

  final bool resumeFromLastPosition;
  final PlayerLandscapeSide landscapeSide;
  final PlayerEntryOrientation entryOrientation;
  final PlayerPreloadSize preloadSize;
  final PlaybackEngineKind iosEngine;
  final bool debugMode;
  final bool performanceMonitorEnabled;
  final bool doubleTapCenter;
  final bool doubleTapEdges;
  final bool hapticLongPress;
  final bool hapticSeek;
  final bool hapticRate;
  final bool hapticProgressBar;
  final bool showSystemTime;
  final bool showNetworkSpeed;
  final bool showCpuUsage;
  final bool showBattery;
  final bool showPlayPauseButton;
  final bool showSeekButtons;
  final bool showSpeedButton;
  final bool showPipButton;
  final bool showOrientationButton;
  final bool showMediaSwitchButton;

  PlayerSettings copyWith({
    bool? resumeFromLastPosition,
    PlayerLandscapeSide? landscapeSide,
    PlayerEntryOrientation? entryOrientation,
    PlayerPreloadSize? preloadSize,
    PlaybackEngineKind? iosEngine,
    bool? debugMode,
    bool? performanceMonitorEnabled,
    bool? doubleTapCenter,
    bool? doubleTapEdges,
    bool? hapticLongPress,
    bool? hapticSeek,
    bool? hapticRate,
    bool? hapticProgressBar,
    bool? showSystemTime,
    bool? showNetworkSpeed,
    bool? showCpuUsage,
    bool? showBattery,
    bool? showPlayPauseButton,
    bool? showSeekButtons,
    bool? showSpeedButton,
    bool? showPipButton,
    bool? showOrientationButton,
    bool? showMediaSwitchButton,
  }) {
    return PlayerSettings(
      resumeFromLastPosition:
          resumeFromLastPosition ?? this.resumeFromLastPosition,
      landscapeSide: landscapeSide ?? this.landscapeSide,
      entryOrientation: entryOrientation ?? this.entryOrientation,
      preloadSize: preloadSize ?? this.preloadSize,
      iosEngine: iosEngine ?? this.iosEngine,
      debugMode: debugMode ?? this.debugMode,
      performanceMonitorEnabled:
          performanceMonitorEnabled ?? this.performanceMonitorEnabled,
      doubleTapCenter: doubleTapCenter ?? this.doubleTapCenter,
      doubleTapEdges: doubleTapEdges ?? this.doubleTapEdges,
      hapticLongPress: hapticLongPress ?? this.hapticLongPress,
      hapticSeek: hapticSeek ?? this.hapticSeek,
      hapticRate: hapticRate ?? this.hapticRate,
      hapticProgressBar: hapticProgressBar ?? this.hapticProgressBar,
      showSystemTime: showSystemTime ?? this.showSystemTime,
      showNetworkSpeed: showNetworkSpeed ?? this.showNetworkSpeed,
      showCpuUsage: showCpuUsage ?? this.showCpuUsage,
      showBattery: showBattery ?? this.showBattery,
      showPlayPauseButton: showPlayPauseButton ?? this.showPlayPauseButton,
      showSeekButtons: showSeekButtons ?? this.showSeekButtons,
      showSpeedButton: showSpeedButton ?? this.showSpeedButton,
      showPipButton: showPipButton ?? this.showPipButton,
      showOrientationButton:
          showOrientationButton ?? this.showOrientationButton,
      showMediaSwitchButton:
          showMediaSwitchButton ?? this.showMediaSwitchButton,
    );
  }
}

class PlayerSettingsRepository {
  PlayerSettingsRepository(this._prefs);

  static const _resumeKey = 'player.resume_from_last_position';
  static const _landscapeSideKey = 'player.landscape_side';
  static const _entryOrientationKey = 'player.entry_orientation';
  static const _preloadSizeKey = 'player.preload_size';
  static const _debugModeKey = 'player.debug_mode';
  static const _performanceMonitorEnabledKey =
      'player.performance_monitor_enabled';
  static const _doubleTapCenterKey = 'player.double_tap_center';
  static const _doubleTapEdgesKey = 'player.double_tap_edges';
  static const _hapticLongPressKey = 'player.haptic_long_press';
  static const _hapticSeekKey = 'player.haptic_seek';
  static const _hapticRateKey = 'player.haptic_rate';
  static const _hapticProgressBarKey = 'player.haptic_progress_bar';
  static const _showSystemTimeKey = 'player.show_system_time';
  static const _showNetworkSpeedKey = 'player.show_network_speed';
  static const _showCpuUsageKey = 'player.show_cpu_usage';
  static const _showBatteryKey = 'player.show_battery';
  static const _showPlayPauseButtonKey = 'player.show_play_pause_button';
  static const _showSeekButtonsKey = 'player.show_seek_buttons';
  static const _showSpeedButtonKey = 'player.show_speed_button';
  static const _showPipButtonKey = 'player.show_pip_button';
  static const _showOrientationButtonKey = 'player.show_orientation_button';
  static const _showMediaSwitchButtonKey = 'player.show_media_switch_button';

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
      preloadSize: PlayerPreloadSize.fromValue(
        _prefs.getString(_preloadSizeKey),
      ),
      iosEngine: PlayerEnginePreference.fromValue(
        _prefs.getString(PlayerEnginePreference.storageKey),
      ),
      debugMode: _prefs.getBool(_debugModeKey) ?? false,
      performanceMonitorEnabled:
          _prefs.getBool(_performanceMonitorEnabledKey) ?? false,
      doubleTapCenter: _prefs.getBool(_doubleTapCenterKey) ?? true,
      doubleTapEdges: _prefs.getBool(_doubleTapEdgesKey) ?? true,
      hapticLongPress: _prefs.getBool(_hapticLongPressKey) ?? true,
      hapticSeek: _prefs.getBool(_hapticSeekKey) ?? true,
      hapticRate: _prefs.getBool(_hapticRateKey) ?? true,
      hapticProgressBar: _prefs.getBool(_hapticProgressBarKey) ?? true,
      showSystemTime: _prefs.getBool(_showSystemTimeKey) ?? true,
      showNetworkSpeed: _prefs.getBool(_showNetworkSpeedKey) ?? true,
      showCpuUsage: _prefs.getBool(_showCpuUsageKey) ?? true,
      showBattery: _prefs.getBool(_showBatteryKey) ?? true,
      showPlayPauseButton: _prefs.getBool(_showPlayPauseButtonKey) ?? true,
      showSeekButtons: _prefs.getBool(_showSeekButtonsKey) ?? true,
      showSpeedButton: _prefs.getBool(_showSpeedButtonKey) ?? true,
      showPipButton: _prefs.getBool(_showPipButtonKey) ?? true,
      showOrientationButton: _prefs.getBool(_showOrientationButtonKey) ?? true,
      showMediaSwitchButton: _prefs.getBool(_showMediaSwitchButtonKey) ?? true,
    );
  }

  Future<void> save(PlayerSettings settings) async {
    await Future.wait([
      _prefs.setBool(_resumeKey, settings.resumeFromLastPosition),
      _prefs.setString(_landscapeSideKey, settings.landscapeSide.value),
      _prefs.setString(_entryOrientationKey, settings.entryOrientation.value),
      _prefs.setString(_preloadSizeKey, settings.preloadSize.value),
      _prefs.setString(
        PlayerEnginePreference.storageKey,
        settings.iosEngine.value,
      ),
      _prefs.setBool(_debugModeKey, settings.debugMode),
      _prefs.setBool(
        _performanceMonitorEnabledKey,
        settings.performanceMonitorEnabled,
      ),
      _prefs.setBool(_doubleTapCenterKey, settings.doubleTapCenter),
      _prefs.setBool(_doubleTapEdgesKey, settings.doubleTapEdges),
      _prefs.setBool(_hapticLongPressKey, settings.hapticLongPress),
      _prefs.setBool(_hapticSeekKey, settings.hapticSeek),
      _prefs.setBool(_hapticRateKey, settings.hapticRate),
      _prefs.setBool(_hapticProgressBarKey, settings.hapticProgressBar),
      _prefs.setBool(_showSystemTimeKey, settings.showSystemTime),
      _prefs.setBool(_showNetworkSpeedKey, settings.showNetworkSpeed),
      _prefs.setBool(_showCpuUsageKey, settings.showCpuUsage),
      _prefs.setBool(_showBatteryKey, settings.showBattery),
      _prefs.setBool(_showPlayPauseButtonKey, settings.showPlayPauseButton),
      _prefs.setBool(_showSeekButtonsKey, settings.showSeekButtons),
      _prefs.setBool(_showSpeedButtonKey, settings.showSpeedButton),
      _prefs.setBool(_showPipButtonKey, settings.showPipButton),
      _prefs.setBool(_showOrientationButtonKey, settings.showOrientationButton),
      _prefs.setBool(_showMediaSwitchButtonKey, settings.showMediaSwitchButton),
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
