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

/// 水平选项行，并在打开或选中值变化后将目标项滚动到可视区中央。
///
/// [childBuilder] 应将第二个参数设为当前选中项的 key；[selectedValue] 为空时
/// 保持默认滚动位置。
class SelectedHorizontalScrollView extends StatefulWidget {
  const SelectedHorizontalScrollView({
    super.key,
    required this.selectedValue,
    required this.childBuilder,
    this.padding = EdgeInsets.zero,
  });

  final String? selectedValue;
  final EdgeInsetsGeometry padding;
  final Widget Function(BuildContext context, Key selectedItemKey) childBuilder;

  @override
  State<SelectedHorizontalScrollView> createState() =>
      _SelectedHorizontalScrollViewState();
}

class _SelectedHorizontalScrollViewState
    extends State<SelectedHorizontalScrollView> {
  final _scrollController = ScrollController();
  final _selectedItemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollToSelectedItem();
  }

  @override
  void didUpdateWidget(covariant SelectedHorizontalScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValue != widget.selectedValue) {
      _scrollToSelectedItem();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedItem() {
    if (widget.selectedValue == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _selectedItemKey.currentContext?.findRenderObject();
      if (target == null) return;
      _scrollController.position.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      child: widget.childBuilder(context, _selectedItemKey),
    );
  }
}

/// 排序选项 chip 行 · 筛选弹层内排序区的统一呈现：
/// 点击未选中字段选中并按升序；点击已选中字段在升序/降序间切换，
/// 当前方向以选中 chip 的箭头展示，无独立的升降序切换按钮。
///
/// 不含水平内边距，由调用方按各自弹层布局包裹。
class SortOptionChipRow extends StatelessWidget {
  const SortOptionChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.ascending,
    required this.onSelected,
  });

  final List<({String value, String label})> options;
  final String selected;

  /// 当前升降序方向，随选中 chip 的箭头展示。
  final bool ascending;

  /// 点击排序字段：未选中字段回调 (字段, true)；已选中字段回调 (字段, 切换后的方向)。
  final void Function(String value, bool ascending) onSelected;

  @override
  Widget build(BuildContext context) {
    return SelectedHorizontalScrollView(
      selectedValue: selected,
      childBuilder: (context, selectedItemKey) => Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            CompactFilterButton(
              key: options[index].value == selected ? selectedItemKey : null,
              label: options[index].label,
              active: options[index].value == selected,
              trailingIcon: options[index].value == selected
                  ? (ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                  : null,
              onTap: () => onSelected(
                options[index].value,
                options[index].value == selected ? !ascending : true,
              ),
            ),
          ],
        ],
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
