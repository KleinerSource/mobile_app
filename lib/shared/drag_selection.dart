import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/platform/app_haptics.dart';

typedef DragSelectionChange<T> = void Function(T id, bool selected);

enum _DragSelectionAxis { horizontal, vertical }

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
    this.selectionRow,
  });

  final T id;
  final Widget child;

  /// The row occupied by this target in a grid. Null keeps list semantics.
  final int? selectionRow;

  @override
  State<DragSelectionTarget<T>> createState() => _DragSelectionTargetState<T>();
}

class _DragSelectionScopeState<T> extends State<DragSelectionScope<T>> {
  static const _directionThreshold = 10.0;

  final _viewportKey = GlobalKey();
  final Map<T, _DragSelectionTargetState<T>> _targets = {};
  final Set<T> _visited = {};
  late final Ticker _ticker;

  Offset? _pointerPosition;
  Offset? _lastPointerPosition;
  Offset? _selectionStartPosition;
  int? _selectionRow;
  _DragSelectionAxis? _selectionAxis;
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
    _selectionStartPosition = globalPosition;
    _selectionRow = target.widget.selectionRow;
    _selectionAxis = null;
    _selectionValue = !widget.isSelected(id);
    _visited
      ..clear()
      ..add(id);

    AppHaptics.medium();
    widget.onSelectionStart(id, _selectionValue);
    _updateAutoScroll();
  }

  void _updateSelection(Offset globalPosition) {
    if (!_dragging) return;

    final previousPosition = _lastPointerPosition;
    _pointerPosition = globalPosition;
    if (previousPosition != null) {
      final directionLocked = _lockSelectionAxis(globalPosition);
      final from = directionLocked
          ? (_selectionStartPosition ?? previousPosition)
          : previousPosition;

      if (_selectionAxis == _DragSelectionAxis.vertical) {
        _applyRowsAlongPath(from.dy, globalPosition.dy);
      } else if (_selectionAxis == _DragSelectionAxis.horizontal) {
        _applyAlongPath(from, globalPosition, row: _selectionRow);
      } else {
        _applyAlongPath(from, globalPosition, row: _selectionRow);
      }
    }
    _lastPointerPosition = globalPosition;
    _updateAutoScroll();
  }

  void _finishSelection() {
    if (!_dragging) return;
    _dragging = false;
    _pointerPosition = null;
    _lastPointerPosition = null;
    _selectionStartPosition = null;
    _selectionRow = null;
    _selectionAxis = null;
    _visited.clear();
    _lastTickElapsed = null;
    _stopTicker();
    widget.onSelectionEnd();
  }

  bool _lockSelectionAxis(Offset position) {
    if (_selectionRow == null || _selectionAxis != null) return false;

    final start = _selectionStartPosition;
    if (start == null) return false;

    final delta = position - start;
    if (delta.distance < _directionThreshold) return false;

    _selectionAxis = delta.dx.abs() >= delta.dy.abs()
        ? _DragSelectionAxis.horizontal
        : _DragSelectionAxis.vertical;
    return true;
  }

  void _applyAlongPath(Offset from, Offset to, {int? row}) {
    final targets = List<_DragSelectionTargetState<T>>.of(_targets.values);
    for (final target in targets) {
      final id = target.widget.id;
      if (_visited.contains(id)) continue;
      if (row != null && target.widget.selectionRow != row) continue;

      final rect = target.globalRect;
      if (rect == null || !_segmentIntersectsRect(from, to, rect)) continue;

      _applyTarget(target);
    }
  }

  void _applyRowsAlongPath(double fromY, double toY) {
    final rows = <int, List<_DragSelectionTargetState<T>>>{};
    final rowBounds = <int, Rect>{};

    for (final target in _targets.values) {
      final row = target.widget.selectionRow;
      final rect = target.globalRect;
      if (row == null || rect == null) continue;

      rows.putIfAbsent(row, () => <_DragSelectionTargetState<T>>[]).add(target);
      rowBounds[row] = rowBounds[row]?.expandToInclude(rect) ?? rect;
    }

    final top = math.min(fromY, toY);
    final bottom = math.max(fromY, toY);
    for (final entry in rows.entries) {
      final bounds = rowBounds[entry.key]!;
      final expanded = bounds.inflate(3);
      if (bottom < expanded.top || top > expanded.bottom) continue;
      for (final target in entry.value) {
        _applyTarget(target);
      }
    }
  }

  void _applyTarget(_DragSelectionTargetState<T> target) {
    final id = target.widget.id;
    if (!_visited.add(id)) return;

    AppHaptics.selection();
    widget.onSelectionChanged(id, _selectionValue);
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

    if (_selectionAxis == _DragSelectionAxis.vertical) {
      _applyRowsAlongPath(pointer.dy, pointer.dy);
      return;
    }

    final targets = List<_DragSelectionTargetState<T>>.of(_targets.values);
    for (final target in targets) {
      final id = target.widget.id;
      if (_visited.contains(id)) continue;
      if (_selectionAxis == _DragSelectionAxis.horizontal &&
          _selectionRow != null &&
          target.widget.selectionRow != _selectionRow) {
        continue;
      }

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
  const _DragSelectionInherited({required this.state, required super.child});

  final _DragSelectionScopeState<T> state;

  @override
  bool updateShouldNotify(_DragSelectionInherited<T> oldWidget) =>
      !identical(state, oldWidget.state);
}

class _DragSelectionTargetState<T> extends State<DragSelectionTarget<T>> {
  _DragSelectionScopeState<T>? _scope;

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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: scope == null
          ? null
          : (details) => scope._startSelection(this, details.globalPosition),
      onLongPressMoveUpdate: scope == null
          ? null
          : (details) => scope._updateSelection(details.globalPosition),
      onLongPressEnd: scope == null ? null : (_) => scope._finishSelection(),
      onLongPressCancel: scope?._finishSelection,
      child: widget.child,
    );
  }
}
