import 'package:flutter/material.dart';

import '../core/platform/app_haptics.dart';
import '../core/platform/app_theme.dart';

/// 底部面板统一标题。
///
/// 标题始终左对齐，并通过图标建立面板用途的快速识别；副标题和右侧操作
/// 都保持在同一行的视觉层级中，避免业务面板各自拼装出不同的头部。
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(22, 6, 22, 12),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.sectionTitle(context)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta(context),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// 底部操作区只负责留白与布局，不再绘制不透明背景或标题式分割线。
class SheetActionBar extends StatelessWidget {
  const SheetActionBar({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(22, 10, 22, 10),
      child: child,
    );
  }
}

/// 面板内统一开关外观，避免平台自适应开关在不同面板中产生差异。
class SheetSwitch extends StatelessWidget {
  const SheetSwitch({super.key, required this.value, required this.onChanged});

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

class SheetSwitchTile extends StatelessWidget {
  const SheetSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.body(context)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.meta(context)),
                ],
              ],
            ),
          ),
          SheetSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 底部面板输入控件的统一外观。
///
/// 默认使用半透明玻璃上的 surface 填充、12px 圆角和 accent 焦点边框；
/// [borderless] 仅用于已经有外层边框的兼容场景。
InputDecoration sheetInputDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool borderless = false,
  bool error = false,
  bool isDense = false,
  EdgeInsetsGeometry? contentPadding,
}) {
  final c = appColors(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: error ? c.danger : c.cardBorder),
  );
  final focusedBorder = border.copyWith(
    borderSide: BorderSide(color: c.accent, width: 1.5),
  );
  final errorBorder = border.copyWith(
    borderSide: BorderSide(color: c.danger, width: 1.2),
  );

  return InputDecoration(
    filled: !borderless,
    fillColor: borderless ? Colors.transparent : c.surface,
    hintText: hintText,
    labelText: labelText,
    hintStyle: TextStyle(color: c.muted),
    labelStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
    floatingLabelStyle: TextStyle(color: c.accent, fontWeight: FontWeight.w700),
    prefixIcon: prefixIcon,
    prefixIconColor: c.muted,
    suffixIcon: suffixIcon,
    suffixIconColor: c.muted,
    isDense: isDense,
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: borderless ? InputBorder.none : border,
    enabledBorder: borderless ? InputBorder.none : border,
    focusedBorder: borderless ? InputBorder.none : focusedBorder,
    disabledBorder: borderless ? InputBorder.none : border,
    errorBorder: borderless ? InputBorder.none : errorBorder,
    focusedErrorBorder: borderless ? InputBorder.none : errorBorder,
  );
}

ButtonStyle sheetPrimaryButtonStyle(BuildContext context) {
  final c = appColors(context);
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: c.accent,
    foregroundColor: Theme.of(context).colorScheme.onPrimary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

ButtonStyle sheetSecondaryButtonStyle(BuildContext context) {
  final c = appColors(context);
  return OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    foregroundColor: c.text,
    side: BorderSide(color: c.cardBorder),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
