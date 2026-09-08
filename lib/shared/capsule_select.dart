import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';

/// 胶囊下拉选项：value 为空字符串时视为"未设置"（保持默认不变）。
typedef CapsuleSelectOption = ({String value, String label});

/// 胶囊风格的单选下拉 · 对齐 Web 端 CapsuleSelect。
///
/// 胶囊本体显示 `标签 · 当前值`，点击后在胶囊下方弹出选项菜单，
/// 避免全宽的 DropdownButtonFormField。
class CapsuleSelect extends StatelessWidget {
  const CapsuleSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<CapsuleSelectOption> options;
  final ValueChanged<String> onChanged;
  final bool enabled;

  bool get _active => value.isNotEmpty;

  String get _valueLabel {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return '';
  }

  Future<void> _open(BuildContext context) async {
    final c = appColors(context);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(
          box.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      constraints: BoxConstraints(minWidth: box.size.width + 24),
      items: [
        for (final option in options)
          PopupMenuItem(
            value: option.value,
            height: 44,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(
                    option.value == value
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: option.value == value ? c.accent : c.muted2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  option.label,
                  style: TextStyle(
                    color: option.value == value ? c.accent : c.text,
                    fontFamily: 'Inter',
                    fontWeight:
                        option.value == value ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (selected != null && selected != value) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final valueLabel = _valueLabel;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: enabled ? () => _open(context) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _active ? c.accent.withValues(alpha: 0.14) : c.chipBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _active
                  ? c.accent.withValues(alpha: 0.55)
                  : c.cardBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 值为“默认”时胶囊直接显示类别名（label），不渲染固定前缀。
              Text(
                valueLabel.isEmpty ? label : valueLabel,
                style: TextStyle(
                  color: valueLabel.isEmpty
                      ? c.muted
                      : (_active ? c.accent : c.text),
                  fontFamily: 'Inter',
                  fontWeight: valueLabel.isEmpty
                      ? FontWeight.w600
                      : FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.arrow_drop_down, size: 16, color: c.muted2),
            ],
          ),
        ),
      ),
    );
  }
}
