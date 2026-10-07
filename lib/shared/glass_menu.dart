import 'dart:async';
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
  static const verticalPadding = 4.0;
  static const rowHeight = 44.0;
  static const dividerHeight = 10.0;

  final List<Widget> children;
  final double width;
  final BorderRadius borderRadius;

  static double heightFor({required int rows, int dividers = 0}) {
    return verticalPadding * 2 + rows * rowHeight + dividers * dividerHeight;
  }

  static double widthForLabels(BuildContext context, Iterable<String> labels) {
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    var longestLabel = 0.0;
    for (final label in labels) {
      painter.text = TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );
      painter.layout();
      if (painter.width > longestLabel) longestLabel = painter.width;
    }
    painter.dispose();
    if (longestLabel == 0) return defaultWidth;

    // Icon + gaps + the row's inner and outer horizontal padding.
    const rowChromeWidth = 65.0;
    final availableWidth = (MediaQuery.sizeOf(context).width - 24)
        .clamp(1.0, double.infinity)
        .toDouble();
    return (longestLabel + rowChromeWidth)
        .clamp(1.0, availableWidth)
        .toDouble();
  }

  static double widthForEntries<T>(
    BuildContext context,
    Iterable<GlassMenuEntry<T>> entries,
  ) {
    final labels = entries
        .where((entry) => !entry.isDivider)
        .map((entry) => entry.label)
        .whereType<String>()
        .where((label) => label.isNotEmpty);
    return widthForLabels(context, labels);
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
              border: isDark
                  ? Border.all(color: Colors.white.withValues(alpha: 0.18))
                  : null,
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
    this.iconSize = 19,
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
    this.label,
    this.height = GlassMenuPanel.rowHeight,
  }) : isDivider = false,
       dividerColor = null;

  const GlassMenuEntry.divider({this.dividerColor})
    : value = null,
      builder = null,
      label = null,
      height = GlassMenuPanel.dividerHeight,
      isDivider = true;

  final T? value;
  final GlassMenuItemBuilder<T>? builder;
  final String? label;
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
    this.child,
    this.builder,
    required this.entries,
    required this.onSelected,
    required this.width,
    this.widthForEntries,
    this.initialSelection,
    this.placement = GlassMenuPlacement.below,
    this.alignment = GlassMenuAlignment.end,
    this.offset = Offset.zero,
    this.enabled = true,
    this.tooltip,
    this.onAnchorTap,
    this.onLongPressEntries,
  }) : assert(
         (child == null) != (builder == null),
         'Provide exactly one of child or builder.',
       );

  final Widget? child;

  /// 由锚点内容自行处理点击（例如绘制波纹），回调用于打开/关闭菜单；
  /// 禁用时回调为 null。长按滑动选择仍由锚点统一处理。
  final Widget Function(BuildContext context, VoidCallback? toggle)? builder;
  final List<GlassMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final double width;
  final double Function(BuildContext context, List<GlassMenuEntry<T>> entries)?
  widthForEntries;
  final T? initialSelection;
  final GlassMenuPlacement placement;
  final GlassMenuAlignment alignment;
  final Offset offset;
  final bool enabled;
  final String? tooltip;
  final VoidCallback? onAnchorTap;

  /// 长按后按需加载菜单项；适用于菜单选项依赖异步状态的锚点。
  final Future<List<GlassMenuEntry<T>>?> Function()? onLongPressEntries;

  @override
  State<GlassMenuAnchor<T>> createState() => _GlassMenuAnchorState<T>();
}

class _GlassMenuAnchorState<T> extends State<GlassMenuAnchor<T>> {
  OverlayEntry? _overlayEntry;
  ValueNotifier<T?>? _selection;
  Rect? _menuRect;
  List<GlassMenuEntry<T>>? _openEntries;
  bool _interactive = false;
  int _longPressRequest = 0;
  bool _preparingLongPress = false;
  bool _longPressReleased = false;
  Offset? _longPressPosition;
  Offset? _longPressOrigin;

  Rect? _geometry(
    List<GlassMenuEntry<T>> entries, {
    required double width,
    Offset? anchorPosition,
  }) {
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
    final menuHeight =
        GlassMenuPanel.verticalPadding * 2 +
        entries.fold<double>(0, (total, entry) => total + entry.height);

    final rawLeft = switch (widget.alignment) {
      GlassMenuAlignment.start =>
        (anchorPosition?.dx ?? anchorRect.left) + widget.offset.dx,
      GlassMenuAlignment.center =>
        (anchorPosition?.dx ?? anchorRect.center.dx) -
            width / 2 +
            widget.offset.dx,
      GlassMenuAlignment.end =>
        anchorPosition == null
            ? anchorRect.right - width + widget.offset.dx
            : anchorPosition.dx - width / 2 + widget.offset.dx,
    };
    const horizontalInset = 12.0;
    final minLeft = overlayRect.left + horizontalInset;
    final maxLeft = (overlayRect.right - width - horizontalInset).clamp(
      minLeft,
      double.infinity,
    );
    final left = rawLeft.clamp(minLeft, maxLeft).toDouble();

    const verticalInset = 12.0;
    final minTop = overlayRect.top + verticalInset;
    final maxTop = (overlayRect.bottom - menuHeight - verticalInset).clamp(
      minTop,
      double.infinity,
    );
    final rawTop = anchorPosition == null
        ? switch (widget.placement) {
            GlassMenuPlacement.above =>
              anchorRect.top - menuHeight - widget.offset.dy,
            GlassMenuPlacement.below => anchorRect.bottom + widget.offset.dy,
          }
        : _topForLongPress(anchorPosition, menuHeight, minTop, maxTop);
    final top = rawTop.clamp(minTop, maxTop).toDouble();
    return Rect.fromLTWH(left, top, width, menuHeight);
  }

  double _topForLongPress(
    Offset position,
    double menuHeight,
    double minTop,
    double maxTop,
  ) {
    const gap = 8.0;
    final below = position.dy + gap + widget.offset.dy;
    if (below <= maxTop) return below;
    return position.dy - menuHeight - gap + widget.offset.dy;
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

  void _open({
    required bool interactive,
    Offset? initialPosition,
    Offset? anchorPosition,
    List<GlassMenuEntry<T>>? entries,
  }) {
    final openEntries = entries ?? widget.entries;
    if (!widget.enabled || _overlayEntry != null || openEntries.isEmpty) {
      return;
    }
    final width =
        widget.widthForEntries?.call(context, openEntries) ?? widget.width;
    final rect = _geometry(
      openEntries,
      width: width,
      anchorPosition: anchorPosition,
    );
    if (rect == null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayObject = overlay.context.findRenderObject();
    if (overlayObject is! RenderBox) return;

    final localTopLeft = overlayObject.globalToLocal(rect.topLeft);
    final selection = ValueNotifier<T?>(widget.initialSelection);
    _interactive = interactive;
    _menuRect = rect;
    _openEntries = List<GlassMenuEntry<T>>.of(openEntries);
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
              width: rect.width,
              height: rect.height,
              child: ValueListenableBuilder<T?>(
                valueListenable: selection,
                builder: (context, selected, _) {
                  final panel = _GlassMenuContent<T>(
                    entries: _openEntries!,
                    selected: selected,
                    width: rect.width,
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
    _longPressReleased = false;
    _longPressPosition = details.globalPosition;
    _longPressOrigin = details.globalPosition;
    final loadEntries = widget.onLongPressEntries;
    if (loadEntries == null) {
      _open(
        interactive: false,
        initialPosition: details.globalPosition,
        anchorPosition: details.globalPosition,
      );
      return;
    }
    _preparingLongPress = true;
    final request = _longPressRequest;
    unawaited(_openAfterLoadingEntries(loadEntries, request));
  }

  Future<void> _openAfterLoadingEntries(
    Future<List<GlassMenuEntry<T>>?> Function() loadEntries,
    int request,
  ) async {
    try {
      final entries = await loadEntries();
      if (!mounted || request != _longPressRequest || !widget.enabled) return;
      final released = _longPressReleased;
      _open(
        interactive: released,
        initialPosition: released ? null : _longPressPosition,
        anchorPosition: _longPressOrigin,
        entries: entries,
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'glass menu',
          context: ErrorDescription('while loading long-press menu entries'),
        ),
      );
    } finally {
      if (mounted && request == _longPressRequest) {
        _preparingLongPress = false;
      }
    }
  }

  void _updateSelection(Offset globalPosition) {
    _longPressPosition = globalPosition;
    final selection = _selection;
    if (selection == null) return;
    final next = _valueAt(globalPosition);
    if (next == selection.value) return;
    selection.value = next;
    if (next != null) AppHaptics.selection();
  }

  void _finishLongPress(LongPressEndDetails details) {
    if (_overlayEntry == null) {
      if (_preparingLongPress) {
        _longPressReleased = true;
        _longPressPosition = details.globalPosition;
      }
      return;
    }
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
    _longPressRequest++;
    _preparingLongPress = false;
    _longPressReleased = false;
    _longPressPosition = null;
    _longPressOrigin = null;
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
    final builder = widget.builder;
    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled && builder == null ? _toggle : null,
      onLongPressStart: widget.enabled ? _startLongPress : null,
      onLongPressMoveUpdate: widget.enabled
          ? (details) => _updateSelection(details.globalPosition)
          : null,
      onLongPressEnd: widget.enabled ? _finishLongPress : null,
      child:
          builder?.call(context, widget.enabled ? _toggle : null) ??
          widget.child!,
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
