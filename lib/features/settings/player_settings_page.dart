import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../player/player_settings.dart';
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

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: ListView(
            children: [
              SettingsSubPageHeader(
                eyebrow: l.settingsAppSettings,
                title: '播放器设置',
              ),
              SettingsGroup(
                title: '播放器设置',
                items: [
                  _PlayerSwitchTile(
                    title: '从上次进度播放',
                    subtitle: '打开影片时自动恢复上次观看位置',
                    icon: Icons.restore,
                    value: settings.resumeFromLastPosition,
                    onChanged: (value) => update(
                      settings.copyWith(resumeFromLastPosition: value),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: '屏幕方向',
                items: [
                  _PlayerOptionTile<PlayerLandscapeSide>(
                    title: '设备横屏方向',
                    icon: Icons.screen_rotation,
                    value: settings.landscapeSide,
                    options: PlayerLandscapeSide.values,
                    optionLabel: (value) => value.label,
                    onChanged: (value) => update(
                      settings.copyWith(landscapeSide: value),
                    ),
                  ),
                  _PlayerOptionTile<PlayerEntryOrientation>(
                    title: '进入播放器屏幕方向',
                    icon: Icons.stay_current_landscape,
                    value: settings.entryOrientation,
                    options: PlayerEntryOrientation.values,
                    optionLabel: (value) => value.label,
                    onChanged: (value) => update(
                      settings.copyWith(entryOrientation: value),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: '双击手势',
                items: [
                  _PlayerSwitchTile(
                    title: '双击屏幕中间',
                    subtitle: '暂停 / 播放',
                    icon: Icons.touch_app,
                    value: settings.doubleTapCenter,
                    onChanged: (value) => update(
                      settings.copyWith(doubleTapCenter: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '双击屏幕两边',
                    subtitle: '左侧快退,右侧快进',
                    icon: Icons.fast_forward,
                    value: settings.doubleTapEdges,
                    onChanged: (value) => update(
                      settings.copyWith(doubleTapEdges: value),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: '震动反馈',
                items: [
                  _PlayerSwitchTile(
                    title: '长按屏幕',
                    icon: Icons.pan_tool,
                    value: settings.hapticLongPress,
                    onChanged: (value) => update(
                      settings.copyWith(hapticLongPress: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '滑动调节进度',
                    icon: Icons.swap_horiz,
                    value: settings.hapticSeek,
                    onChanged: (value) => update(
                      settings.copyWith(hapticSeek: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '滑动调节倍速',
                    icon: Icons.speed,
                    value: settings.hapticRate,
                    onChanged: (value) => update(
                      settings.copyWith(hapticRate: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '拖动进度条',
                    icon: Icons.linear_scale,
                    value: settings.hapticProgressBar,
                    onChanged: (value) => update(
                      settings.copyWith(hapticProgressBar: value),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: 'OSD 信息',
                items: [
                  _PlayerSwitchTile(
                    title: '系统时间',
                    subtitle: '在播放器上显示当前时间',
                    icon: Icons.access_time,
                    value: settings.showSystemTime,
                    onChanged: (value) => update(
                      settings.copyWith(showSystemTime: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '设备网速',
                    subtitle: '显示设备当前下载速度',
                    icon: Icons.download,
                    value: settings.showNetworkSpeed,
                    onChanged: (value) => update(
                      settings.copyWith(showNetworkSpeed: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: 'CPU 占用率',
                    subtitle: '显示设备实时 CPU 使用率',
                    icon: Icons.memory,
                    value: settings.showCpuUsage,
                    onChanged: (value) => update(
                      settings.copyWith(showCpuUsage: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '设备电量',
                    subtitle: '显示当前电池电量',
                    icon: Icons.battery_full,
                    value: settings.showBattery,
                    onChanged: (value) => update(
                      settings.copyWith(showBattery: value),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: '播放按钮',
                items: [
                  _PlayerSwitchTile(
                    title: '播放 / 暂停按钮',
                    icon: Icons.play_circle_outline,
                    value: settings.showPlayPauseButton,
                    onChanged: (value) => update(
                      settings.copyWith(showPlayPauseButton: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '快进 / 快退按钮',
                    icon: Icons.fast_forward,
                    value: settings.showSeekButtons,
                    onChanged: (value) => update(
                      settings.copyWith(showSeekButtons: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '速度调节按钮',
                    icon: Icons.speed,
                    value: settings.showSpeedButton,
                    onChanged: (value) => update(
                      settings.copyWith(showSpeedButton: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '画中画按钮',
                    icon: Icons.picture_in_picture_alt,
                    value: settings.showPipButton,
                    onChanged: (value) => update(
                      settings.copyWith(showPipButton: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '旋屏按钮',
                    icon: Icons.screen_rotation,
                    value: settings.showOrientationButton,
                    onChanged: (value) => update(
                      settings.copyWith(showOrientationButton: value),
                    ),
                  ),
                  _PlayerSwitchTile(
                    title: '切换媒体按钮',
                    subtitle: '上一部 / 下一部',
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
    final c = appColors(context);
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: icon,
      trailing: Switch(
        value: value,
        activeThumbColor: c.accent,
        onChanged: onChanged,
      ),
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
  });

  final String title;
  final IconData icon;
  final T value;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<T> onChanged;

  Future<void> _pick(BuildContext context) async {
    final c = appColors(context);
    final picked = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: c.bg,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: AppText.sectionTitle(ctx)),
                ),
              ),
              for (final option in options)
                ListTile(
                  title: Text(
                    optionLabel(option),
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
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
    if (picked != null && picked != value) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: optionLabel(value),
      leadingIcon: icon,
      onTap: () => _pick(context),
    );
  }
}
