import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../../shared/sheet_controls.dart';
import '../player/common/player_settings.dart';
import '../player/common/playback_engine.dart';
import 'settings_common.dart';

class PlayerSettingsPage extends ConsumerWidget {
  const PlayerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final settings = ref.watch(playerSettingsProvider);

    void update(PlayerSettings next) {
      unawaited(ref.read(playerSettingsProvider.notifier).update(next));
    }

    String engineLabel(PlaybackEngineKind engine) => engine.label;

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsAppSettings,
              title: l.settingsPlayerSettings,
            ),
            body: ListView(
              primary: true,
              children: [
                SettingsGroup(
                  title: l.settingsPlayerSettings,
                  items: [
                    _PlayerSwitchTile(
                      title: l.playerSettingResumeLast,
                      subtitle: l.playerSettingResumeLastSub,
                      icon: Icons.restore,
                      value: settings.resumeFromLastPosition,
                      onChanged: (value) => update(
                        settings.copyWith(resumeFromLastPosition: value),
                      ),
                    ),
                  ],
                ),
                if (!kIsWeb && Platform.isIOS)
                  SettingsGroup(
                    title: l.playerSettingIosEngineGroup,
                    items: [
                      _PlayerOptionTile<PlaybackEngineKind>(
                        title: l.playerSettingDefaultEngine,
                        subtitle: l.playerSettingDefaultEngineSub(
                          engineLabel(settings.iosEngine),
                        ),
                        icon: Icons.video_settings,
                        value: settings.iosEngine,
                        options: PlaybackEngineKind.values,
                        optionLabel: engineLabel,
                        onChanged: (value) =>
                            update(settings.copyWith(iosEngine: value)),
                      ),
                    ],
                  ),
                SettingsGroup(
                  title: l.playerSettingBufferGroup,
                  items: [
                    _PlayerOptionTile<PlayerPreloadSize>(
                      title: l.playerSettingPreloadSize,
                      subtitle: settings.iosEngine != PlaybackEngineKind.libmpv
                          ? l.playerSettingPreloadSizeSub(
                              settings.preloadSize.label,
                            )
                          : null,
                      icon: Icons.memory,
                      value: settings.preloadSize,
                      options: PlayerPreloadSize.values,
                      optionLabel: (value) => value.label,
                      onChanged: (value) =>
                          update(settings.copyWith(preloadSize: value)),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: l.playerSettingOrientationGroup,
                  items: [
                    _PlayerOptionTile<PlayerLandscapeSide>(
                      title: l.playerSettingLandscapeSide,
                      icon: Icons.screen_rotation,
                      value: settings.landscapeSide,
                      options: PlayerLandscapeSide.values,
                      optionLabel: (value) => value.label,
                      onChanged: (value) =>
                          update(settings.copyWith(landscapeSide: value)),
                    ),
                    _PlayerOptionTile<PlayerEntryOrientation>(
                      title: l.playerSettingEntryOrientation,
                      icon: Icons.stay_current_landscape,
                      value: settings.entryOrientation,
                      options: PlayerEntryOrientation.values,
                      optionLabel: (value) => value.label,
                      onChanged: (value) =>
                          update(settings.copyWith(entryOrientation: value)),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: l.playerSettingDoubleTapGroup,
                  items: [
                    _PlayerSwitchTile(
                      title: l.playerSettingDoubleTapCenter,
                      subtitle: l.playerSettingDoubleTapCenterSub,
                      icon: Icons.touch_app,
                      value: settings.doubleTapCenter,
                      onChanged: (value) =>
                          update(settings.copyWith(doubleTapCenter: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingDoubleTapEdges,
                      subtitle: l.playerSettingDoubleTapEdgesSub,
                      icon: Icons.fast_forward,
                      value: settings.doubleTapEdges,
                      onChanged: (value) =>
                          update(settings.copyWith(doubleTapEdges: value)),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: l.playerSettingHapticGroup,
                  items: [
                    _PlayerSwitchTile(
                      title: l.playerSettingHapticLongPress,
                      icon: Icons.pan_tool,
                      value: settings.hapticLongPress,
                      onChanged: (value) =>
                          update(settings.copyWith(hapticLongPress: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingHapticSeek,
                      icon: Icons.swap_horiz,
                      value: settings.hapticSeek,
                      onChanged: (value) =>
                          update(settings.copyWith(hapticSeek: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingHapticRate,
                      icon: Icons.speed,
                      value: settings.hapticRate,
                      onChanged: (value) =>
                          update(settings.copyWith(hapticRate: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingHapticProgressBar,
                      icon: Icons.linear_scale,
                      value: settings.hapticProgressBar,
                      onChanged: (value) =>
                          update(settings.copyWith(hapticProgressBar: value)),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: l.playerSettingOsdGroup,
                  items: [
                    _PlayerSwitchTile(
                      title: l.playerSettingOsdClock,
                      subtitle: l.playerSettingOsdClockSub,
                      icon: Icons.access_time,
                      value: settings.showSystemTime,
                      onChanged: (value) =>
                          update(settings.copyWith(showSystemTime: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingOsdNetwork,
                      subtitle: l.playerSettingOsdNetworkSub,
                      icon: Icons.network_check,
                      value: settings.showNetworkSpeed,
                      onChanged: (value) =>
                          update(settings.copyWith(showNetworkSpeed: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingOsdCpu,
                      subtitle: l.playerSettingOsdCpuSub,
                      icon: Icons.memory,
                      value: settings.showCpuUsage,
                      onChanged: (value) =>
                          update(settings.copyWith(showCpuUsage: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingOsdBattery,
                      subtitle: l.playerSettingOsdBatterySub,
                      icon: Icons.battery_full,
                      value: settings.showBattery,
                      onChanged: (value) =>
                          update(settings.copyWith(showBattery: value)),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: l.playerSettingButtonsGroup,
                  items: [
                    _PlayerSwitchTile(
                      title: l.playerSettingPlayPauseButton,
                      icon: Icons.play_circle_outline,
                      value: settings.showPlayPauseButton,
                      onChanged: (value) => update(
                        settings.copyWith(showPlayPauseButton: value),
                      ),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingSeekButtons,
                      icon: Icons.fast_forward,
                      value: settings.showSeekButtons,
                      onChanged: (value) =>
                          update(settings.copyWith(showSeekButtons: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingSpeedButton,
                      icon: Icons.speed,
                      value: settings.showSpeedButton,
                      onChanged: (value) =>
                          update(settings.copyWith(showSpeedButton: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingPipButton,
                      icon: Icons.picture_in_picture_alt,
                      value: settings.showPipButton,
                      onChanged: (value) =>
                          update(settings.copyWith(showPipButton: value)),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingOrientationButton,
                      icon: Icons.screen_rotation,
                      value: settings.showOrientationButton,
                      onChanged: (value) => update(
                        settings.copyWith(showOrientationButton: value),
                      ),
                    ),
                    _PlayerSwitchTile(
                      title: l.playerSettingMediaSwitchButton,
                      subtitle: l.playerSettingMediaSwitchButtonSub,
                      icon: Icons.skip_next,
                      value: settings.showMediaSwitchButton,
                      onChanged: (value) => update(
                        settings.copyWith(showMediaSwitchButton: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerSwitchTile extends StatelessWidget {
  const _PlayerSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: icon,
      trailing: SettingsSwitch(value: value, onChanged: onChanged),
    );
  }
}

class _PlayerOptionTile<T> extends StatelessWidget {
  const _PlayerOptionTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final T value;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<T> onChanged;
  final String? subtitle;

  Future<void> _pick(BuildContext context) async {
    final c = appColors(context);
    final picked = await showGlassSheet<T>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: icon,
                title: title,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              ),
              for (final option in options)
                ListTile(
                  title: Text(
                    optionLabel(option),
                    style: AppText.body(
                      ctx,
                    ).copyWith(color: c.text, fontWeight: FontWeight.w700),
                  ),
                  trailing: option == value
                      ? Icon(Icons.check, color: c.accent)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(option),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != value) {
      AppHaptics.selection();
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle ?? optionLabel(value),
      leadingIcon: icon,
      onTap: () => _pick(context),
    );
  }
}
