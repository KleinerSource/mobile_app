import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/platform/app_haptics.dart';

typedef DragSelectionChange<T> = void Function(T id, bool selected);

/// Determines which direction can start a new selection sweep after the
/// initial long press has entered selection mode.
enum DragSelectionLayout { list, grid }

/// Coordinates long-press drag selection for the mounted children below it.
class DragSelectionScope<T> extends StatefulWidget {
  const DragSelectionScope({
    super.key,
    required this.scrollController,
    required this.isSelected,
    required this.onSelectionStart,
    required this.onSelectionChanged,
    required this.onSelectionEnd,
    required this.child,
    this.selectionLayout = DragSelectionLayout.list,
    this.selectionMode = false,
    this.enabled = true,
    this.edgeExtent = 72,
    this.maxAutoScrollSpeed = 720,
  });

  final ScrollController scrollController;
  final bool Function(T id) isSelected;
  final DragSelectionChange<T> onSelectionStart;
  final DragSelectionChange<T> onSelectionChanged;
  final VoidCallback onSelectionEnd;
  final Widget child;
  final DragSelectionLayout selectionLayout;
  final bool selectionMode;
  final bool enabled;
  final double edgeExtent;
  final double maxAutoScrollSpeed;

  @override
  State<DragSelectionScope<T>> createState() => _DragSelectionScopeState<T>();
}

/// Registers one mounted list or grid item with [DragSelectionScope].
class DragSelectionTarget<T> extends StatefulWidget {
  const DragSelectionTarget({
    super.key,
    required this.id,
    required this.child,
    this.selectionIndex,
    this.selectionHandleExtent = 44,
    this.selectionHandleAlignment = Alignment.topLeft,
  });

  final T id;
  final Widget child;

  /// The row-major position of this target in a grid. Null keeps list semantics.
  final int? selectionIndex;

  /// The square hit area in the target's top-left corner used for direct
  /// vertical selection in list mode while the page is already in selection
  /// mode.
  final double selectionHandleExtent;

  /// Alignment of the direct-drag hit area inside the target.
  final Alignment selectionHandleAlignment;

  @override
  State<DragSelectionTarget<T>> createState() => _DragSelectionTargetState<T>();
}

class _DragSelectionScopeState<T> extends State<DragSelectionScope<T>> {
  final _viewportKey = GlobalKey();
  final Map<T, _DragSelectionTargetState<T>> _targets = {};
  final Set<T> _visited = {};
  final Set<T> _activeGridIds = {};
  final Map<T, bool> _gridOriginalValues = {};
  late final Ticker _ticker;

  Offset? _pointerPosition;
  Offset? _lastPointerPosition;
  int? _selectionIndex;
  bool _dragging = false;
  bool _selectionValue = true;
  Duration? _lastTickElapsed;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick);
  }

  @override
  void didUpdateWidget(covariant DragSelectionScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _dragging) {
      _finishSelection();
    }
  }

  @override
  void dispose() {
    _dragging = false;
    _stopTicker();
    _ticker.dispose();
    _targets.clear();
    super.dispose();
  }

  void _register(_DragSelectionTargetState<T> target) {
    _targets[target.widget.id] = target;
    if (_dragging) _updateAutoScroll();
  }

  bool get _selectionMode => widget.selectionMode;

  DragSelectionLayout get _selectionLayout => widget.selectionLayout;

  void _unregister(_DragSelectionTargetState<T> target, T id) {
    if (identical(_targets[id], target)) {
      _targets.remove(id);
    }
  }

  void _startSelection(
    _DragSelectionTargetState<T> target,
    Offset globalPosition,
  ) {
    if (!widget.enabled || _dragging) return;

    final id = target.widget.id;
    _dragging = true;
    _pointerPosition = globalPosition;
    _lastPointerPosition = globalPosition;
    _selectionIndex = target.widget.selectionIndex;
    _selectionValue = !widget.isSelected(id);
    _visited
      ..clear()
      ..add(id);
    _activeGridIds.clear();
    _gridOriginalValues.clear();
    if (_selectionIndex != null) {
      _activeGridIds.add(id);
      _gridOriginalValues[id] = widget.isSelected(id);
    }

    if (mounted) setState(() {});
    AppHaptics.medium();
    widget.onSelectionStart(id, _selectionValue);
    _updateAutoScroll();
  }

  void _updateSelection(Offset globalPosition) {
    if (!_dragging) return;

    final previousPosition = _lastPointerPosition;
    _pointerPosition = globalPosition;
    if (_selectionIndex != null) {
      _applyGridRangeAt(globalPosition);
    } else if (previousPosition != null) {
      _applyAlongPath(previousPosition, globalPosition);
    }
    _lastPointerPosition = globalPosition;
    _updateAutoScroll();
  }

  void _finishSelection() {
    if (!_dragging) return;
    _dragging = false;
    _pointerPosition = null;
    _lastPointerPosition = null;
    _selectionIndex = null;
    _visited.clear();
    _activeGridIds.clear();
    _gridOriginalValues.clear();
    _lastTickElapsed = null;
    _stopTicker();
    if (mounted) setState(() {});
    widget.onSelectionEnd();
  }

  void _applyAlongPath(Offset from, Offset to) {
    final targets = List<_DragSelectionTargetState<T>>.of(_targets.values);
    for (final target in targets) {
      final id = target.widget.id;
      if (_visited.contains(id)) continue;

      final rect = target.globalRect;
      if (rect == null || !_segmentIntersectsRect(from, to, rect)) continue;

      _applyTarget(target);
    }
  }

  void _applyGridRangeAt(Offset position) {
    final startIndex = _selectionIndex;
    final target = _targetAt(position);
    final endIndex = target?.widget.selectionIndex;
    if (startIndex == null || endIndex == null) return;

    final first = math.min(startIndex, endIndex);
    final last = math.max(startIndex, endIndex);
    final nextActiveIds = <T>{};
    final targets = List<_DragSelectionTargetState<T>>.of(_targets.values);
    for (final candidate in targets) {
      final index = candidate.widget.selectionIndex;
      if (index == null || index < first || index > last) continue;
      nextActiveIds.add(candidate.widget.id);
    }

    for (final id in List<T>.of(_activeGridIds)) {
      if (nextActiveIds.contains(id)) continue;
      _deactivateGridId(id);
    }

    for (final candidate in targets) {
      if (nextActiveIds.contains(candidate.widget.id)) {
        _activateGridTarget(candidate);
      }
    }
  }

  _DragSelectionTargetState<T>? _targetAt(Offset position) {
    for (final target in _targets.values) {
      final rect = target.globalRect;
      if (rect != null && rect.contains(position)) return target;
    }
    return null;
  }

  void _applyTarget(_DragSelectionTargetState<T> target) {
    final id = target.widget.id;
    if (!_visited.add(id)) return;

    _applyTargetValue(target, _selectionValue);
  }

  void _activateGridTarget(_DragSelectionTargetState<T> target) {
    final id = target.widget.id;
    if (!_activeGridIds.add(id)) return;

    _gridOriginalValues.putIfAbsent(id, () => widget.isSelected(id));
    _applyTargetValue(target, _selectionValue);
  }

  void _deactivateGridId(T id) {
    if (!_activeGridIds.remove(id)) return;

    if (_gridOriginalValues.containsKey(id)) {
      _applySelectionValue(id, _gridOriginalValues[id]!);
    }
  }

  void _applyTargetValue(_DragSelectionTargetState<T> target, bool selected) {
    _applySelectionValue(target.widget.id, selected);
  }

  void _applySelectionValue(T id, bool selected) {
    if (widget.isSelected(id) == selected) return;

    AppHaptics.selection();
    widget.onSelectionChanged(id, selected);
  }

  bool _segmentIntersectsRect(Offset from, Offset to, Rect rect) {
    final expanded = rect.inflate(3);
    if (expanded.contains(from) || expanded.contains(to)) return true;

    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    var start = 0.0;
    var end = 1.0;

    bool clip(double p, double q) {
      if (p == 0) return q >= 0;
      final ratio = q / p;
      if (p < 0) {
        if (ratio > end) return false;
        if (ratio > start) start = ratio;
      } else {
        if (ratio < start) return false;
        if (ratio < end) end = ratio;
      }
      return true;
    }

    return clip(-dx, from.dx - expanded.left) &&
        clip(dx, expanded.right - from.dx) &&
        clip(-dy, from.dy - expanded.top) &&
        clip(dy, expanded.bottom - from.dy);
  }

  void _applyAtPointer() {
    final pointer = _pointerPosition;
    if (pointer == null) return;

    if (_selectionIndex != null) {
      _applyGridRangeAt(pointer);
      return;
    }

    final targets = List<_DragSelectionTargetState<T>>.of(_targets.values);
    for (final target in targets) {
      final id = target.widget.id;
      if (_visited.contains(id)) continue;

      final rect = target.globalRect;
      if (rect == null || !rect.contains(pointer)) continue;

      _applyTarget(target);
    }
  }

  Rect? _viewportRect() {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  double _edgeProgress(Rect viewport, double y) {
    final edge = math.min(widget.edgeExtent, viewport.height / 2);
    if (edge <= 0) return 0;

    if (y < viewport.top + edge) {
      return -((viewport.top + edge - y) / edge).clamp(0.0, 1.0);
    }
    if (y > viewport.bottom - edge) {
      return ((y - (viewport.bottom - edge)) / edge).clamp(0.0, 1.0);
    }
    return 0;
  }

  void _updateAutoScroll() {
    final pointer = _pointerPosition;
    final viewport = _viewportRect();
    final canScroll =
        widget.scrollController.hasClients &&
        _dragging &&
        pointer != null &&
        viewport != null &&
        _edgeProgress(viewport, pointer.dy) != 0;

    if (canScroll) {
      if (!_ticker.isActive) {
        _lastTickElapsed = null;
        _ticker.start();
      }
    } else {
      _stopTicker();
    }
  }

  void _stopTicker() {
    if (_ticker.isActive) _ticker.stop();
    _lastTickElapsed = null;
  }

  void _onTick(Duration elapsed) {
    if (!_dragging || !widget.scrollController.hasClients) {
      _stopTicker();
      return;
    }

    final pointer = _pointerPosition;
    final viewport = _viewportRect();
    if (pointer == null || viewport == null) {
      _stopTicker();
      return;
    }

    final edgeProgress = _edgeProgress(viewport, pointer.dy);
    if (edgeProgress == 0) {
      _stopTicker();
      return;
    }

    final previousElapsed = _lastTickElapsed;
    _lastTickElapsed = elapsed;
    final elapsedSeconds = previousElapsed == null
        ? 1 / 60
        : (elapsed - previousElapsed).inMicroseconds /
              Duration.microsecondsPerSecond;
    final frameSeconds = elapsedSeconds.clamp(0.0, 0.05).toDouble();
    final speed =
        widget.maxAutoScrollSpeed * edgeProgress.abs() * edgeProgress.abs();
    final position = widget.scrollController.position;
    final direction = edgeProgress < 0 ? -1.0 : 1.0;
    final next = (position.pixels + direction * speed * frameSeconds)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if (next == position.pixels) {
      _stopTicker();
      return;
    }
    widget.scrollController.jumpTo(next);
    _applyAtPointer();
  }

  @override
  Widget build(BuildContext context) {
    return _DragSelectionInherited<T>(
      state: this,
      selectionLayout: widget.selectionLayout,
      selectionMode: widget.selectionMode,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            _updateAutoScroll();
          }
          return false;
        },
        child: SizedBox(key: _viewportKey, child: widget.child),
      ),
    );
  }
}

class _DragSelectionInherited<T> extends InheritedWidget {
  const _DragSelectionInherited({
    required this.state,
    required this.selectionLayout,
    required this.selectionMode,
    required super.child,
  });

  final _DragSelectionScopeState<T> state;
  final DragSelectionLayout selectionLayout;
  final bool selectionMode;

  @override
  bool updateShouldNotify(_DragSelectionInherited<T> oldWidget) =>
      !identical(state, oldWidget.state) ||
      selectionLayout != oldWidget.selectionLayout ||
      selectionMode != oldWidget.selectionMode;
}

class _DragSelectionTargetState<T> extends State<DragSelectionTarget<T>> {
  _DragSelectionScopeState<T>? _scope;
  Offset? _pointerDownPosition;

  Rect? get globalRect {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextScope = context
        .dependOnInheritedWidgetOfExactType<_DragSelectionInherited<T>>()
        ?.state;
    if (identical(_scope, nextScope)) return;
    _scope?._unregister(this, widget.id);
    _scope = nextScope;
    _scope?._register(this);
  }

  @override
  void didUpdateWidget(covariant DragSelectionTarget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _scope?._unregister(this, oldWidget.id);
      _scope?._register(this);
    }
  }

  @override
  void dispose() {
    _scope?._unregister(this, widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    if (scope == null) return widget.child;

    // The first gesture is always a long press. These direct recognizers may
    // be installed when that gesture changes the page into selection mode,
    // but they cannot join the already active pointer's gesture arena. They
    // are therefore ready for the next touch as soon as the mode is entered.
    final directDragEnabled = scope._selectionMode;
    return Listener(
      onPointerDown: (event) => _pointerDownPosition = event.position,
      onPointerUp: (_) {
        _pointerDownPosition = null;
        scope._finishSelection();
      },
      onPointerCancel: (_) {
        _pointerDownPosition = null;
        scope._finishSelection();
      },
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: <Type, GestureRecognizerFactory>{
          _SelectionLongPressRecognizer:
              GestureRecognizerFactoryWithHandlers<
                _SelectionLongPressRecognizer
              >(
                () => _SelectionLongPressRecognizer(
                  allowSelection: () =>
                      !scope._selectionMode || scope._dragging,
                ),
                (recognizer) {
                  recognizer.onLongPressStart = (details) {
                    scope._startSelection(this, details.globalPosition);
                  };
                  recognizer.onLongPressMoveUpdate = (details) {
                    scope._updateSelection(details.globalPosition);
                  };
                  recognizer.onLongPressEnd = (_) {
                    scope._finishSelection();
                  };
                  recognizer.onLongPressCancel = scope._finishSelection;
                },
              ),
          if (directDragEnabled &&
              scope._selectionLayout == DragSelectionLayout.grid)
            _SelectionHorizontalDragRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _SelectionHorizontalDragRecognizer
                >(_SelectionHorizontalDragRecognizer.new, (recognizer) {
                  recognizer.onStart = (details) {
                    _startDirectSelection(scope, details.globalPosition);
                  };
                  recognizer.onUpdate = (details) {
                    scope._updateSelection(details.globalPosition);
                  };
                  recognizer.onEnd = (_) {
                    scope._finishSelection();
                  };
                  recognizer.onCancel = scope._finishSelection;
                }),
          if (directDragEnabled &&
              scope._selectionLayout == DragSelectionLayout.list)
            _SelectionVerticalDragRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _SelectionVerticalDragRecognizer
                >(
                  () => _SelectionVerticalDragRecognizer(
                    isPointerInHandle: (position) =>
                        _isPointerInSelectionHandle(
                          position,
                          widget.selectionHandleExtent,
                        ),
                  ),
                  (recognizer) {
                    recognizer.onStart = (details) {
                      _startDirectSelection(scope, details.globalPosition);
                    };
                    recognizer.onUpdate = (details) {
                      scope._updateSelection(details.globalPosition);
                    };
                    recognizer.onEnd = (_) {
                      scope._finishSelection();
                    };
                    recognizer.onCancel = scope._finishSelection;
                  },
                ),
        },
        child: widget.child,
      ),
    );
  }

  void _startDirectSelection(
    _DragSelectionScopeState<T> scope,
    Offset currentPosition,
  ) {
    scope._startSelection(this, _pointerDownPosition ?? currentPosition);
    // Drag recognizers report the position at which the direction threshold
    // was crossed in onStart. Apply that whole first segment immediately so a
    // fast first move cannot skip mounted targets between touch-down and the
    // first drag update.
    scope._updateSelection(currentPosition);
  }

  bool _isPointerInSelectionHandle(Offset globalPosition, double extent) {
    final rect = globalRect;
    if (rect == null) return false;

    final handleWidth = math.min(extent, rect.width);
    final handleHeight = math.min(extent, rect.height);
    final horizontalSpace = rect.width - handleWidth;
    final verticalSpace = rect.height - handleHeight;
    return Rect.fromLTWH(
      rect.left + horizontalSpace * (widget.selectionHandleAlignment.x + 1) / 2,
      rect.top + verticalSpace * (widget.selectionHandleAlignment.y + 1) / 2,
      handleWidth,
      handleHeight,
    ).contains(globalPosition);
  }
}

/// A horizontal recognizer used by cards after selection mode is active.
/// Once it wins the arena, its updates continue to report vertical movement,
/// so a horizontal-then-vertical sweep remains one uninterrupted selection.
class _SelectionHorizontalDragRecognizer
    extends HorizontalDragGestureRecognizer {}

/// A vertical recognizer used by list items after selection mode is active.
/// It only joins the arena from the checkbox-sized area at the target's
/// top-left corner; other vertical gestures remain owned by the scroll view.
class _SelectionVerticalDragRecognizer extends VerticalDragGestureRecognizer {
  _SelectionVerticalDragRecognizer({required this.isPointerInHandle});

  final bool Function(Offset position) isPointerInHandle;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (!super.isPointerAllowed(event)) return false;
    return isPointerInHandle(event.position);
  }
}

/// Keeps the long-press recognizer in the arena for the gesture that entered
/// selection mode, while rejecting new long presses once the mode is active.
class _SelectionLongPressRecognizer extends LongPressGestureRecognizer {
  _SelectionLongPressRecognizer({required this.allowSelection});

  final bool Function() allowSelection;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (!allowSelection()) return false;
    return super.isPointerAllowed(event);
  }
}
