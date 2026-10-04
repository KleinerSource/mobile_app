import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 紧凑筛选按钮 · 与影片库排序/高级筛选按钮保持一致。
class CompactFilterButton extends StatelessWidget {
  const CompactFilterButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final fg = active ? c.accent : c.text;
    final iconColor = active ? c.accent : c.muted;
    final icon = this.icon;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.15) : c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? c.accent.withValues(alpha: 0.5) : c.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: iconColor),
              if (label.isNotEmpty) const SizedBox(width: 5),
            ],
            if (label.isNotEmpty)
              Flexible(
                child: Text(
                  label,
                  strutStyle: const StrutStyle(
                    fontSize: 11.5,
                    height: 1.0,
                    forceStrutHeight: true,
                  ),
                  style: TextStyle(
                    color: fg,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(trailingIcon!, size: 12, color: iconColor),
            ],
          ],
        ),
      ),
    );
  }
}

/// 紧凑排序按钮 · 用于资源、演员等管理列表。
class CompactSortButton extends StatelessWidget {
  const CompactSortButton({
    super.key,
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CompactFilterButton(
      label: label,
      icon: Icons.sort_rounded,
      active: active,
      trailingIcon: active
          ? (ascending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded)
          : null,
      onTap: onTap,
    );
  }
}

/// 排序选项 chip 行 · 筛选弹层内排序区的统一呈现：
/// 字段 chips + 行尾升降序切换（[onToggleOrder] 为 null 时不显示切换 chip）。
///
/// 不含水平内边距，由调用方按各自弹层布局包裹。
class SortOptionChipRow extends StatelessWidget {
  const SortOptionChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.ascendingLabel,
    required this.descendingLabel,
    this.ascending = true,
    this.onToggleOrder,
  });

  final List<({String value, String label})> options;
  final String selected;
  final ValueChanged<String> onSelected;

  /// 当前升降序方向，仅用于行尾切换 chip 的展示。
  final bool ascending;
  final VoidCallback? onToggleOrder;
  final String ascendingLabel;
  final String descendingLabel;

  @override
  Widget build(BuildContext context) {
    final toggleOrder = onToggleOrder;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            CompactFilterButton(
              label: options[index].label,
              active: options[index].value == selected,
              onTap: () => onSelected(options[index].value),
            ),
          ],
          if (toggleOrder != null) ...[
            const SizedBox(width: 7),
            CompactFilterButton(
              label: ascending ? ascendingLabel : descendingLabel,
              icon: ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              active: true,
              onTap: toggleOrder,
            ),
          ],
        ],
      ),
    );
  }
}

/// 紫色 chip · 用于 filter 行。
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    super.key,
    required this.label,
    this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String? count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.chipBgActive : c.chipBg,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? c.chipTextActive : c.text2,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  count!,
                  style: TextStyle(
                    color: active
                        ? c.chipTextActive.withValues(alpha: 0.7)
                        : c.muted,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 多彩 hue chip · 用于 genre / tag。
class HueChip extends StatelessWidget {
  const HueChip({
    super.key,
    required this.label,
    required this.hue,
    this.count,
    this.onTap,
    this.removable = false,
    this.onRemove,
  });

  final String label;
  final int hue;
  final int? count;
  final VoidCallback? onTap;
  final bool removable;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final textColor = AppHues.chipText(hue, b);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppHues.chipBg(hue, b),
            border: Border.all(color: AppHues.chipBorder(hue), width: 1.5),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: -0.12,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
              if (removable) ...[
                const SizedBox(width: 6),
                Icon(Icons.close, size: 12, color: textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
