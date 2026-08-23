import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/platform/app_haptics.dart';
import '../core/platform/app_theme.dart';

/// 统一的窄幅毛玻璃菜单面板。
///
/// 菜单不提供标题和默认箭头；入口通过高亮、点击反馈和可选尾部状态表达。
class GlassMenuPanel extends StatelessWidget {
  const GlassMenuPanel({
    super.key,
    required this.children,
    this.width = defaultWidth,
    this.borderRadius = defaultBorderRadius,
  });

  static const defaultWidth = 224.0;
  static const defaultBorderRadius = BorderRadius.all(Radius.circular(18));
  static const verticalPadding = 6.0;
  static const rowHeight = 48.0;
  static const dividerHeight = 10.0;

  final List<Widget> children;
  final double width;
  final BorderRadius borderRadius;

  static double heightFor({required int rows, int dividers = 0}) {
    return verticalPadding * 2 + rows * rowHeight + dividers * dividerHeight;
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.bg.withValues(alpha: isDark ? 0.70 : 0.76),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.56),
              ),
              borderRadius: borderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: verticalPadding),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

/// 统一菜单行，支持普通图标、头像等自定义前导内容和状态尾部内容。
class GlassMenuRow extends StatelessWidget {
  const GlassMenuRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
    this.trailing,
    this.selected = false,
    this.foregroundColor,
    this.fontSize = 14,
    this.fontWeight,
    this.height = GlassMenuPanel.rowHeight,
    this.iconSize = 21,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final Color? foregroundColor;
  final double fontSize;
  final FontWeight? fontWeight;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final foreground = foregroundColor ?? (selected ? c.tabActiveText : c.text);
    final leadingWidget =
        leading ??
        (icon == null
            ? const SizedBox(width: 21)
            : Icon(icon, color: foreground, size: iconSize));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          splashColor: c.accent.withValues(alpha: 0.12),
          highlightColor: c.accent.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? c.tabActiveBg.withValues(alpha: 0.86)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                leadingWidget,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'Inter',
                      fontSize: fontSize,
                      fontWeight:
                          fontWeight ??
                          (selected ? FontWeight.w700 : FontWeight.w600),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassMenuDivider extends StatelessWidget {
  const GlassMenuDivider({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return SizedBox(
      height: GlassMenuPanel.dividerHeight,
      child: Center(
        child: Divider(
          height: 1,
          thickness: 0.6,
          color: (color ?? c.divider).withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

typedef GlassMenuItemBuilder<T> =
    Widget Function(BuildContext context, bool selected, VoidCallback onTap);

/// 菜单中的可操作行或分隔线。
class GlassMenuEntry<T> {
  const GlassMenuEntry.action({
    required this.value,
    required this.builder,
    this.height = GlassMenuPanel.rowHeight,
  }) : isDivider = false,
       dividerColor = null;

  const GlassMenuEntry.divider({this.dividerColor})
    : value = null,
      builder = null,
      height = GlassMenuPanel.dividerHeight,
      isDivider = true;

  final T? value;
  final GlassMenuItemBuilder<T>? builder;
  final double height;
  final bool isDivider;
  final Color? dividerColor;
}

enum GlassMenuPlacement { above, below }

enum GlassMenuAlignment { start, center, end }

/// 统一的锚定菜单交互。
///
/// 普通点击会打开菜单，长按后可以把手指滑到菜单项并在松手时直接执行；
/// 长按松手时没有选中菜单项则保持菜单打开，之后可以正常点击选择。
class GlassMenuAnchor<T> extends StatefulWidget {
  const GlassMenuAnchor({
    super.key,
    required this.child,
    required this.entries,
    required this.onSelected,
    required this.width,
    this.initialSelection,
    this.placement = GlassMenuPlacement.below,
    this.alignment = GlassMenuAlignment.end,
    this.offset = Offset.zero,
    this.enabled = true,
    this.tooltip,
    this.onAnchorTap,
  });

  final Widget child;
  final List<GlassMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final double width;
  final T? initialSelection;
  final GlassMenuPlacement placement;
  final GlassMenuAlignment alignment;
  final Offset offset;
  final bool enabled;
  final String? tooltip;
  final VoidCallback? onAnchorTap;

  @override
  State<GlassMenuAnchor<T>> createState() => _GlassMenuAnchorState<T>();
}

class _GlassMenuAnchorState<T> extends State<GlassMenuAnchor<T>> {
  OverlayEntry? _overlayEntry;
  ValueNotifier<T?>? _selection;
  Rect? _menuRect;
  List<GlassMenuEntry<T>>? _openEntries;
  bool _interactive = false;

  double get _menuHeight {
    final entries = widget.entries;
    return GlassMenuPanel.verticalPadding * 2 +
        entries.fold<double>(0, (total, entry) => total + entry.height);
  }

  Rect? _geometry() {
    final anchorObject = context.findRenderObject();
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayObject = overlay.context.findRenderObject();
    if (anchorObject is! RenderBox || overlayObject is! RenderBox) {
      return null;
    }

    final anchorTopLeft = anchorObject.localToGlobal(Offset.zero);
    final anchorRect = anchorTopLeft & anchorObject.size;
    final overlayTopLeft = overlayObject.localToGlobal(Offset.zero);
    final overlaySize = overlayObject.size;
    final overlayRect = overlayTopLeft & overlaySize;
    final menuHeight = _menuHeight;

    final rawLeft = switch (widget.alignment) {
      GlassMenuAlignment.start => anchorRect.left + widget.offset.dx,
      GlassMenuAlignment.center =>
        anchorRect.center.dx - widget.width / 2 + widget.offset.dx,
      GlassMenuAlignment.end =>
        anchorRect.right - widget.width + widget.offset.dx,
    };
    const horizontalInset = 12.0;
    final minLeft = overlayRect.left + horizontalInset;
    final maxLeft = (overlayRect.right - widget.width - horizontalInset).clamp(
      minLeft,
      double.infinity,
    );
    final left = rawLeft.clamp(minLeft, maxLeft).toDouble();

    final rawTop = switch (widget.placement) {
      GlassMenuPlacement.above =>
        anchorRect.top - menuHeight - widget.offset.dy,
      GlassMenuPlacement.below => anchorRect.bottom + widget.offset.dy,
    };
    const verticalInset = 12.0;
    final minTop = overlayRect.top + verticalInset;
    final maxTop = (overlayRect.bottom - menuHeight - verticalInset).clamp(
      minTop,
      double.infinity,
    );
    final top = rawTop.clamp(minTop, maxTop).toDouble();
    return Rect.fromLTWH(left, top, widget.width, menuHeight);
  }

  T? _valueAt(Offset globalPosition) {
    final rect = _menuRect;
    final entries = _openEntries;
    if (rect == null || entries == null || !rect.contains(globalPosition)) {
      return null;
    }
    var y = globalPosition.dy - rect.top - GlassMenuPanel.verticalPadding;
    if (y < 0) return null;
    for (final entry in entries) {
      if (y < entry.height) {
        return entry.isDivider ? null : entry.value;
      }
      y -= entry.height;
    }
    return null;
  }

  void _open({required bool interactive, Offset? initialPosition}) {
    if (!widget.enabled || _overlayEntry != null || widget.entries.isEmpty) {
      return;
    }
    final rect = _geometry();
    if (rect == null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayObject = overlay.context.findRenderObject();
    if (overlayObject is! RenderBox) return;

    final localTopLeft = overlayObject.globalToLocal(rect.topLeft);
    final selection = ValueNotifier<T?>(widget.initialSelection);
    _interactive = interactive;
    _menuRect = rect;
    _openEntries = List<GlassMenuEntry<T>>.of(widget.entries);
    _selection = selection;
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Stack(
          children: [
            if (_interactive)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              left: localTopLeft.dx,
              top: localTopLeft.dy,
              width: widget.width,
              height: rect.height,
              child: ValueListenableBuilder<T?>(
                valueListenable: selection,
                builder: (context, selected, _) {
                  final panel = _GlassMenuContent<T>(
                    entries: _openEntries!,
                    selected: selected,
                    width: widget.width,
                    onSelect: _select,
                  );
                  return _interactive ? panel : IgnorePointer(child: panel);
                },
              ),
            ),
          ],
        ),
      ),
    );
    _overlayEntry = entry;
    overlay.insert(entry);
    if (initialPosition != null) {
      _updateSelection(initialPosition);
    }
  }

  void _toggle() {
    if (!widget.enabled) return;
    if (widget.onAnchorTap != null) {
      widget.onAnchorTap!();
      return;
    }
    if (_overlayEntry == null) {
      _open(interactive: true);
    } else {
      _close();
    }
  }

  void _startLongPress(LongPressStartDetails details) {
    if (!widget.enabled) return;
    _close();
    AppHaptics.medium();
    _open(interactive: false, initialPosition: details.globalPosition);
  }

  void _updateSelection(Offset globalPosition) {
    final selection = _selection;
    if (selection == null) return;
    final next = _valueAt(globalPosition);
    if (next == selection.value) return;
    selection.value = next;
    if (next != null) AppHaptics.selection();
  }

  void _finishLongPress(LongPressEndDetails details) {
    if (_overlayEntry == null) return;
    final value = _valueAt(details.globalPosition);
    if (value != null) {
      _select(value);
      return;
    }
    _updateSelection(details.globalPosition);
    _interactive = true;
    _overlayEntry?.markNeedsBuild();
  }

  void _select(T value) {
    if (_overlayEntry == null) return;
    _close();
    AppHaptics.selection();
    widget.onSelected(value);
  }

  void _close() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    _menuRect = null;
    _openEntries = null;
    _interactive = false;
    _selection?.dispose();
    _selection = null;
    entry?.remove();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _toggle : null,
      onLongPressStart: widget.enabled ? _startLongPress : null,
      onLongPressMoveUpdate: widget.enabled
          ? (details) => _updateSelection(details.globalPosition)
          : null,
      onLongPressEnd: widget.enabled ? _finishLongPress : null,
      child: widget.child,
    );
    if (widget.tooltip?.trim().isNotEmpty == true) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }
}

class _GlassMenuContent<T> extends StatelessWidget {
  const _GlassMenuContent({
    required this.entries,
    required this.selected,
    required this.width,
    required this.onSelect,
  });

  final List<GlassMenuEntry<T>> entries;
  final T? selected;
  final double width;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassMenuPanel(
      width: width,
      children: [
        for (final entry in entries)
          if (entry.isDivider)
            GlassMenuDivider(color: entry.dividerColor)
          else
            entry.builder!(
              context,
              entry.value == selected,
              () => onSelect(entry.value as T),
            ),
      ],
    );
  }
}
