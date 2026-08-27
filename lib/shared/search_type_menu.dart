import 'package:flutter/material.dart';

import '../core/platform/app_haptics.dart';
import '../core/platform/app_theme.dart';

@immutable
class SearchTypeOption<T> {
  const SearchTypeOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// OMM 搜索页使用的搜索类型切换器。
///
/// 支持点击打开、长按滑动选择、点击外部关闭和触觉反馈；调用方只需
/// 提供类型选项即可复用同一套交互。
class SearchTypeMenu<T> extends StatefulWidget {
  const SearchTypeMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<SearchTypeOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  State<SearchTypeMenu<T>> createState() => _SearchTypeMenuState<T>();
}

class _SearchTypeMenuState<T> extends State<SearchTypeMenu<T>> {
  static const _menuWidth = 204.0;
  static const _menuPadding = 8.0;
  static const _itemHeight = kMinInteractiveDimension;

  OverlayEntry? _overlayEntry;
  Rect? _menuRect;
  T? _hovered;
  bool _interactive = false;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  Rect? _calculateMenuRect() {
    final anchorObject = context.findRenderObject();
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayObject = overlay.context.findRenderObject();
    if (anchorObject is! RenderBox || overlayObject is! RenderBox) return null;

    final anchorTopLeft = anchorObject.localToGlobal(Offset.zero);
    final anchorRect = anchorTopLeft & anchorObject.size;
    final overlayTopLeft = overlayObject.localToGlobal(Offset.zero);
    final overlayRect = overlayTopLeft & overlayObject.size;
    final menuHeight = _menuPadding * 2 + widget.options.length * _itemHeight;
    const inset = 12.0;
    final left = (anchorRect.left).clamp(
      overlayRect.left + inset,
      overlayRect.right - _menuWidth - inset,
    );
    final below = anchorRect.bottom;
    final top = below + menuHeight + inset <= overlayRect.bottom
        ? below
        : anchorRect.top - menuHeight;
    return Rect.fromLTWH(left, top, _menuWidth, menuHeight);
  }

  T? _valueAt(Offset globalPosition) {
    final rect = _menuRect;
    if (rect == null || !rect.contains(globalPosition)) return null;
    final y = globalPosition.dy - rect.top - _menuPadding;
    if (y < 0) return null;
    final index = (y / _itemHeight).floor();
    if (index < 0 || index >= widget.options.length) return null;
    return widget.options[index].value;
  }

  void _openMenu({required bool interactive, Offset? initialPosition}) {
    final rect = _calculateMenuRect();
    if (rect == null) return;
    _closeMenu();
    _menuRect = rect;
    _interactive = interactive;
    _hovered = interactive ? widget.value : null;

    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayObject = overlay.context.findRenderObject();
    if (overlayObject is! RenderBox) return;
    final localTopLeft = overlayObject.globalToLocal(rect.topLeft);
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Stack(
          children: [
            if (_interactive)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeMenu,
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              left: localTopLeft.dx,
              top: localTopLeft.dy,
              width: rect.width,
              height: rect.height,
              child: IgnorePointer(
                ignoring: !_interactive,
                child: _SearchTypeMenuPopup<T>(state: this),
              ),
            ),
          ],
        ),
      ),
    );
    _overlayEntry = entry;
    overlay.insert(entry);
    if (initialPosition != null) _updateHover(initialPosition);
  }

  void _startLongPress(LongPressStartDetails details) {
    AppHaptics.medium();
    _openMenu(interactive: false, initialPosition: details.globalPosition);
  }

  void _toggleMenu() {
    if (_overlayEntry == null) {
      _openMenu(interactive: true);
    } else {
      _closeMenu();
    }
  }

  void _updateHover(Offset globalPosition) {
    if (_overlayEntry == null) return;
    final next = _valueAt(globalPosition);
    if (next == _hovered) return;
    _hovered = next;
    _overlayEntry?.markNeedsBuild();
    if (next != null) AppHaptics.selection();
  }

  void _finishLongPress(LongPressEndDetails details) {
    final selected = _valueAt(details.globalPosition);
    if (selected != null) {
      _select(selected);
    } else {
      _closeMenu();
    }
  }

  void _select(T value) {
    _closeMenu();
    if (value == widget.value) return;
    AppHaptics.selection();
    widget.onChanged(value);
  }

  void _closeMenu() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    _menuRect = null;
    _hovered = null;
    _interactive = false;
    entry?.remove();
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.options.firstWhere(
      (item) => item.value == widget.value,
      orElse: () => widget.options.first,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleMenu,
      onLongPressStart: _startLongPress,
      onLongPressMoveUpdate: (details) => _updateHover(details.globalPosition),
      onLongPressEnd: _finishLongPress,
      onLongPressCancel: _closeMenu,
      child: _SearchTypeButton<T>(option: option),
    );
  }
}

class _SearchTypeMenuPopup<T> extends StatelessWidget {
  const _SearchTypeMenuPopup({required this.state});

  final _SearchTypeMenuState<T> state;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Material(
      color: Color.alphaBlend(colors.surface, colors.bg),
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final option in state.widget.options)
              SizedBox(
                height: kMinInteractiveDimension,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: state._hovered == option.value
                        ? colors.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: state._interactive
                          ? () => state._select(option.value)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(option.icon, size: 18, color: colors.text),
                          const SizedBox(width: 10),
                          Text(
                            option.label,
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchTypeButton<T> extends StatelessWidget {
  const _SearchTypeButton({required this.option});

  final SearchTypeOption<T> option;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(option.icon, size: 16, color: colors.text),
        const SizedBox(width: 5),
        Text(
          option.label,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 2),
        Icon(Icons.expand_more, size: 16, color: colors.muted),
      ],
    );
  }
}
