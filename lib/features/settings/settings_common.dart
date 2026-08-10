import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.items});
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 0, 10),
            child: Text(title.toUpperCase(), style: AppText.eyebrow(context)),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.cardBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: c.divider),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.leadingIcon,
    this.showChevron = true,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final IconData? leadingIcon;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              AppHaptics.selection();
              onTap!();
            },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (destructive ? c.danger : c.accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  leadingIcon,
                  color: destructive ? c.danger : c.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: destructive ? c.danger : c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.meta(context)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null && !destructive && showChevron)
              Icon(Icons.chevron_right, size: 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}

/// 偏好设置卡片统一开关。
///
/// 使用固定的 Material 开关外观，避免 `Switch` 与 `Switch.adaptive` 在
/// iOS/Android 以及不同页面中显示成不同颜色和尺寸。
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Switch(
      value: value,
      onChanged: AppHaptics.wrapToggle(onChanged),
      activeThumbColor: c.accent,
      activeTrackColor: c.accent.withValues(alpha: 0.38),
      inactiveThumbColor: c.muted,
      inactiveTrackColor: c.muted2.withValues(alpha: 0.32),
      trackOutlineColor: WidgetStatePropertyAll(c.cardBorder),
    );
  }
}

/// 设置页输入控件的统一外观与最小触控高度。
InputDecoration settingsInputDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool borderless = false,
}) {
  final c = appColors(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c.cardBorder),
  );
  return InputDecoration(
    filled: true,
    fillColor: borderless ? Colors.transparent : c.surface,
    hintText: hintText,
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: borderless ? InputBorder.none : border,
    enabledBorder: borderless ? InputBorder.none : border,
    focusedBorder: borderless
        ? InputBorder.none
        : border.copyWith(
            borderSide: BorderSide(color: c.accent, width: 1.5),
          ),
  );
}

BoxDecoration settingsCardDecoration(BuildContext context) {
  final c = appColors(context);
  return BoxDecoration(
    color: c.surface,
    border: Border.all(color: c.cardBorder),
    borderRadius: BorderRadius.circular(16),
  );
}

/// 设置页标题栏的统一新增操作。
class SettingsAddButton extends StatelessWidget {
  const SettingsAddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        '添加',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: c.text,
        foregroundColor: c.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}

/// 设置页统一的保存操作，避免不同页面混用按钮组件和文案。
class SettingsSaveButton extends StatelessWidget {
  const SettingsSaveButton({
    super.key,
    required this.onPressed,
    this.saving = false,
    this.label = '保存设置',
  });

  final VoidCallback? onPressed;
  final bool saving;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: saving ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: c.text,
          foregroundColor: c.bg,
          disabledBackgroundColor: c.text.withValues(alpha: 0.45),
          disabledForegroundColor: c.bg.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.bg,
                ),
              )
            : const Icon(Icons.save_outlined, size: 18),
        label: Text(
          saving ? '保存中...' : label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// 设置页通用滑块 · 在拖动起始、跨分段和提交时提供触觉反馈。
class HapticSlider extends StatefulWidget {
  const HapticSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.label,
    this.onChangeStart,
    this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String? label;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<HapticSlider> createState() => _HapticSliderState();
}

class _HapticSliderState extends State<HapticSlider> {
  int? _lastHapticBucket;

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: widget.value.clamp(widget.min, widget.max).toDouble(),
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      label: widget.label,
      onChangeStart: (value) {
        _lastHapticBucket = _bucket(value);
        AppHaptics.selection();
        widget.onChangeStart?.call(value);
      },
      onChanged: (value) {
        final bucket = _bucket(value);
        if (bucket != _lastHapticBucket) {
          _lastHapticBucket = bucket;
          AppHaptics.selection();
        }
        widget.onChanged(value);
      },
      onChangeEnd: (value) {
        _lastHapticBucket = null;
        AppHaptics.medium();
        widget.onChangeEnd?.call(value);
      },
    );
  }

  int _bucket(double value) {
    final span = widget.max - widget.min;
    if (span <= 0 || widget.divisions <= 0) return 0;
    return ((value - widget.min) / span * widget.divisions).round();
  }
}

/// 通用设置子页头部 · 分组眉标题 + 中文主标题 + 返回按钮/右侧操作
class SettingsSubPageHeader extends StatelessWidget {
  const SettingsSubPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBackButton = true,
  });
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              else
                const SizedBox(width: 48, height: 48),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(), style: AppText.eyebrow(context)),
                const SizedBox(height: 3),
                Text(title, style: AppText.pageTitle(context)),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(subtitle!, style: AppText.meta(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
