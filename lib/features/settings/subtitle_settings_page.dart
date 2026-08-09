import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../player/subtitle_settings.dart';
import 'settings_common.dart';

class SubtitleSettingsPage extends ConsumerWidget {
  const SubtitleSettingsPage({super.key});

  static const _fontOptions = <String>[
    'Inter',
    'System',
    'monospace',
    'serif',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(subtitleSettingsProvider);

    void update(SubtitleSettings next) {
      unawaited(ref.read(subtitleSettingsProvider.notifier).update(next));
    }

    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: SafeArea(
        child: ListView(
          children: [
            const SettingsSubPageHeader(
              eyebrow: '应用设置',
              title: '字幕设置',
            ),
            SettingsGroup(
              title: '字幕行为',
              items: [
                _SubtitleSwitchTile(
                  title: '记住所选字幕',
                  subtitle: '下次播放时自动恢复最近使用的字幕轨道',
                  icon: Icons.bookmark_outline,
                  value: settings.rememberSelectedSubtitle,
                  onChanged: (value) => update(
                    settings.copyWith(rememberSelectedSubtitle: value),
                  ),
                ),
                _SubtitleSwitchTile(
                  title: '忽略 ASS 字幕样式',
                  subtitle: '使用下面的客户端字体和颜色设置',
                  icon: Icons.text_fields,
                  value: settings.ignoreAssStyle,
                  onChanged: (value) => update(
                    settings.copyWith(ignoreAssStyle: value),
                  ),
                ),
                _SubtitleSwitchTile(
                  title: '忽略 SRT 字幕样式',
                  subtitle: '忽略字幕中的 HTML 样式标签',
                  icon: Icons.code_off,
                  value: settings.ignoreSrtStyle,
                  onChanged: (value) => update(
                    settings.copyWith(ignoreSrtStyle: value),
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: '文字样式',
              items: [
                _SubtitleOptionTile<String>(
                  title: '字体',
                  subtitle: _fontLabel(settings.fontFamily),
                  icon: Icons.font_download_outlined,
                  value: settings.fontFamily,
                  options: _fontOptions,
                  labelOf: _fontLabel,
                  onChanged: (value) => update(
                    settings.copyWith(fontFamily: value),
                  ),
                ),
                _SubtitleSwitchTile(
                  title: '加粗',
                  icon: Icons.format_bold,
                  value: settings.bold,
                  onChanged: (value) => update(settings.copyWith(bold: value)),
                ),
                _SubtitleSwitchTile(
                  title: '斜体',
                  icon: Icons.format_italic,
                  value: settings.italic,
                  onChanged: (value) =>
                      update(settings.copyWith(italic: value)),
                ),
                _SubtitleColorTile(
                  title: '字体颜色',
                  icon: Icons.format_color_text,
                  color: settings.fontColor,
                  onChanged: (value) =>
                      update(settings.copyWith(fontColor: value)),
                ),
                _SubtitleColorTile(
                  title: '背景颜色',
                  icon: Icons.format_color_fill,
                  color: settings.backgroundColor,
                  onChanged: (value) =>
                      update(settings.copyWith(backgroundColor: value)),
                ),
              ],
            ),
            SettingsGroup(
              title: '描边与阴影',
              items: [
                _SubtitleColorTile(
                  title: '描边颜色',
                  icon: Icons.border_color_outlined,
                  color: settings.outlineColor,
                  onChanged: (value) =>
                      update(settings.copyWith(outlineColor: value)),
                ),
                _SubtitleSliderTile(
                  title: '描边粗细',
                  subtitle: '${settings.outlineWidth.toStringAsFixed(1)} px',
                  icon: Icons.border_style,
                  value: settings.outlineWidth,
                  min: 0,
                  max: 6,
                  divisions: 12,
                  onChanged: (value) =>
                      update(settings.copyWith(outlineWidth: value)),
                ),
                _SubtitleColorTile(
                  title: '阴影颜色',
                  icon: Icons.blur_on_outlined,
                  color: settings.shadowColor,
                  onChanged: (value) =>
                      update(settings.copyWith(shadowColor: value)),
                ),
                _SubtitleSliderTile(
                  title: '阴影大小',
                  subtitle: '${settings.shadowSize.toStringAsFixed(1)} px',
                  icon: Icons.blur_on_outlined,
                  value: settings.shadowSize,
                  min: 0,
                  max: 12,
                  divisions: 24,
                  onChanged: (value) =>
                      update(settings.copyWith(shadowSize: value)),
                ),
              ],
            ),
            SettingsGroup(
              title: '恢复',
              items: [
                SettingsTile(
                  title: '恢复默认',
                  subtitle: '恢复字体、颜色、描边和字幕行为设置',
                  leadingIcon: Icons.restore,
                  destructive: true,
                  onTap: () => unawaited(_reset(context, ref)),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _fontLabel(String value) {
    switch (value) {
      case 'System':
        return '系统字体';
      case 'monospace':
        return '等宽字体';
      case 'serif':
        return '衬线字体';
      default:
        return 'Inter';
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    AppHaptics.medium();
    await ref.read(subtitleSettingsProvider.notifier).reset();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('字幕设置已恢复默认')),
      );
    }
  }
}

class _SubtitleSwitchTile extends StatelessWidget {
  const _SubtitleSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

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
        onChanged: AppHaptics.wrapToggle(onChanged),
      ),
    );
  }
}

class _SubtitleOptionTile<T> extends StatelessWidget {
  const _SubtitleOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  Future<void> _pick(BuildContext context) async {
    final c = appColors(context);
    final picked = await showGlassSheet<T>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Text(title, style: AppText.sectionTitle(ctx)),
          ),
          for (final option in options)
            ListTile(
              title: Text(
                labelOf(option),
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: option == value
                  ? Icon(Icons.check, color: c.accent)
                  : null,
              onTap: () => Navigator.of(ctx).pop(option),
            ),
        ],
      ),
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
      subtitle: subtitle,
      leadingIcon: icon,
      onTap: () => _pick(context),
    );
  }
}

class _SubtitleColorTile extends StatelessWidget {
  const _SubtitleColorTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final Color color;
  final ValueChanged<Color> onChanged;

  Future<void> _pick(BuildContext context) async {
    final c = appColors(context);
    final picked = await showGlassSheet<Color>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.sectionTitle(ctx)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final option in subtitleColorChoices)
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop(option),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _isTransparent(option) ? c.surface : option,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: option == color ? c.accent : c.cardBorder,
                          width: option == color ? 3 : 1,
                        ),
                      ),
                      child: _isTransparent(option)
                          ? Icon(Icons.block, color: c.muted, size: 18)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked != null && picked != color) {
      AppHaptics.selection();
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: _isTransparent(color) ? '透明' : _colorHex(color),
      leadingIcon: icon,
      trailing: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _isTransparent(color) ? Colors.transparent : color,
            shape: BoxShape.circle,
            border: Border.all(color: appColors(context).cardBorder),
          ),
          child: _isTransparent(color)
              ? Icon(Icons.block, size: 16, color: appColors(context).muted)
              : null,
        ),
      ),
      onTap: () => _pick(context),
    );
  }

  String _colorHex(Color value) {
    return '#${value.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  bool _isTransparent(Color value) => (value.toARGB32() >>> 24) == 0;
}

class _SubtitleSliderTile extends StatelessWidget {
  const _SubtitleSliderTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: icon,
      trailing: SizedBox(
        width: 148,
        child: Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
