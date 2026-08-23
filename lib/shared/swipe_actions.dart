import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';

import '../core/platform/app_haptics.dart';

/// 页面级左滑展开协调器：持有的值是当前展开行的 cellKey，同一时刻只展开一行。
typedef SwipeActionGroup = ValueNotifier<Object?>;

/// 左滑展开后显露的单个操作。
class SwipeActionData {
  const SwipeActionData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
}

/// 列表行左滑展开操作，操作按钮贴右缘排在卡片下方。
///
/// 位移始终由一个像素控制器表示：拖动直接修改当前值，松手后用速度投影
/// 在收起、按钮区展开和整行三个落点中选择目标。整行提交固定执行
/// [actions.first]，与 iOS 列表滑动操作的默认语义一致。
class SwipeActionCell extends StatefulWidget {
  const SwipeActionCell({
    super.key,
    required this.group,
    required this.cellKey,
    required this.actions,
    required this.enabled,
    required this.child,
    this.actionBorderRadius = BorderRadius.zero,
    this.allowsFullSwipe = true,
  });

  final SwipeActionGroup group;
  final Object cellKey;
  final List<SwipeActionData> actions;
  final bool enabled;
  final Widget child;

  /// 操作整块的圆角，应与所在行的可见圆角一致。
  final BorderRadius actionBorderRadius;

  /// 是否允许继续左滑至整行并执行 [actions.first]。
  final bool allowsFullSwipe;

  @override
  State<SwipeActionCell> createState() => _SwipeActionCellState();
}

enum _SwipeState { closed, dragging, open, committing }

class _SwipeActionCellState extends State<SwipeActionCell>
    with TickerProviderStateMixin {
  static const _actionWidth = 78.0;
  static const _decelerationRate = 0.998;
  static const _settleSpring = SpringDescription(
    mass: 1,
    stiffness: 440,
    damping: 42,
  );
  static const _reducedMotionDuration = Duration(milliseconds: 90);

  late final AnimationController _offset = AnimationController(
    vsync: this,
    upperBound: double.infinity,
  );

  _SwipeState _state = _SwipeState.closed;
  double _rowWidth = 0;
  double _dragStartX = 0;
  double _dragStartOffset = 0;
  bool _preparedFullSwipe = false;
  bool _didPrepareHaptic = false;
  int _animationGeneration = 0;

  double get _actionExtent => widget.actions.length * _actionWidth;

  bool get _canSwipe => widget.enabled && widget.actions.isNotEmpty;

  bool get _hasFullSwipe => widget.allowsFullSwipe && _rowWidth > _actionExtent;

  double get _maxOffset => _hasFullSwipe ? _rowWidth : _actionExtent;

  double get _fullSwipeThreshold =>
      _actionExtent + (_rowWidth - _actionExtent) / 2;

  /// 速度投影只有在操作区完全露出后再继续拖过一个动作宽度才可提交。
  /// 行较窄时以全滑临界点为上限，避免短距离快甩误执行默认动作。
  double get _minimumProjectedFullSwipeOffset {
    final extendedReveal = _actionExtent + _actionWidth;
    return extendedReveal < _fullSwipeThreshold
        ? extendedReveal
        : _fullSwipeThreshold;
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void initState() {
    super.initState();
    widget.group.addListener(_handleGroupChange);
  }

  @override
  void didUpdateWidget(covariant SwipeActionCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.group != widget.group) {
      oldWidget.group.removeListener(_handleGroupChange);
      if (oldWidget.group.value == oldWidget.cellKey) {
        oldWidget.group.value = null;
      }
      widget.group.addListener(_handleGroupChange);
      if (widget.group.value == widget.cellKey) {
        widget.group.value = null;
      }
      _collapseImmediately();
    }

    final mustClose =
        oldWidget.cellKey != widget.cellKey ||
        _actionsChanged(oldWidget.actions, widget.actions) ||
        oldWidget.allowsFullSwipe != widget.allowsFullSwipe ||
        !widget.enabled ||
        widget.actions.isEmpty;
    if (mustClose) {
      if (widget.group.value == widget.cellKey) widget.group.value = null;
      _collapseImmediately();
    }
  }

  @override
  void dispose() {
    widget.group.removeListener(_handleGroupChange);
    _stopAnimation();
    _offset.dispose();
    super.dispose();
  }

  bool _actionsChanged(
    List<SwipeActionData> previous,
    List<SwipeActionData> next,
  ) {
    if (previous.length != next.length) return true;
    for (var i = 0; i < previous.length; i++) {
      final oldAction = previous[i];
      final newAction = next[i];
      if (oldAction.icon != newAction.icon ||
          oldAction.label != newAction.label ||
          oldAction.color != newAction.color) {
        return true;
      }
    }
    return false;
  }

  void _stopAnimation() {
    _animationGeneration++;
    if (_offset.isAnimating) _offset.stop(canceled: true);
  }

  void _collapseImmediately() {
    _stopAnimation();
    _state = _SwipeState.closed;
    _preparedFullSwipe = false;
    _didPrepareHaptic = false;
    _offset.value = 0;
  }

  void _handleGroupChange() {
    if (!mounted || _state == _SwipeState.committing) return;
    if (_state == _SwipeState.dragging &&
        widget.group.value == widget.cellKey) {
      return;
    }
    final target = widget.group.value == widget.cellKey ? _actionExtent : 0.0;
    if ((target - _offset.value).abs() < 0.01) {
      _state = target == 0 ? _SwipeState.closed : _SwipeState.open;
      return;
    }
    _animateTo(target);
  }

  void _animateTo(
    double target, {
    double velocity = 0,
    bool committing = false,
  }) {
    _stopAnimation();
    final generation = _animationGeneration;
    _state = committing
        ? _SwipeState.committing
        : target == 0
        ? _SwipeState.closed
        : target == _actionExtent
        ? _SwipeState.open
        : _state;

    final animation = _reduceMotion
        ? _offset.animateTo(
            target,
            duration: _reducedMotionDuration,
            curve: Curves.easeOut,
          )
        : _offset.animateWith(
            SpringSimulation(_settleSpring, _offset.value, target, velocity),
          );
    animation.orCancel.then<void>(
      (_) {
        if (!mounted || generation != _animationGeneration || committing) {
          return;
        }
        _state = target == 0 ? _SwipeState.closed : _SwipeState.open;
        if (target == 0 && widget.group.value == widget.cellKey) {
          widget.group.value = null;
        } else if (target == _actionExtent &&
            widget.group.value != widget.cellKey) {
          widget.group.value = widget.cellKey;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (error is! TickerCanceled) {
          Error.throwWithStackTrace(error, stackTrace);
        }
      },
    );
  }

  void _handleDragStart(DragStartDetails details) {
    if (!_canSwipe || _state == _SwipeState.committing) return;
    _stopAnimation();
    _state = _SwipeState.dragging;
    _dragStartX = details.globalPosition.dx;
    _dragStartOffset = _offset.value.clamp(0.0, _maxOffset);
    _preparedFullSwipe = false;
    _didPrepareHaptic = false;
    if (widget.group.value != widget.cellKey) {
      widget.group.value = widget.cellKey;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_state != _SwipeState.dragging) return;
    final rawOffset =
        _dragStartOffset - (details.globalPosition.dx - _dragStartX);
    final next = rawOffset.clamp(0.0, _maxOffset).toDouble();
    _offset.value = next;

    final prepared = _hasFullSwipe && next >= _fullSwipeThreshold;
    if (prepared && !_didPrepareHaptic) {
      _didPrepareHaptic = true;
      AppHaptics.selection();
    }
    _preparedFullSwipe = prepared;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_state != _SwipeState.dragging) return;
    _finishDrag(-(details.primaryVelocity ?? 0));
  }

  void _handleDragCancel() {
    if (_state != _SwipeState.dragging) return;
    _finishDrag(0);
  }

  void _finishDrag(double openingVelocity) {
    final projected =
        _offset.value +
        openingVelocity / 1000 * _decelerationRate / (1 - _decelerationRate);
    final targets = <double>[0, _actionExtent];
    final hasFullSwipeIntent =
        _preparedFullSwipe || _offset.value >= _minimumProjectedFullSwipeOffset;
    if (_hasFullSwipe && hasFullSwipeIntent) targets.add(_rowWidth);

    var target = targets.first;
    if (_preparedFullSwipe && projected >= _fullSwipeThreshold) {
      target = _rowWidth;
    } else {
      var distance = (projected - target).abs();
      for (final candidate in targets.skip(1)) {
        final candidateDistance = (projected - candidate).abs();
        if (candidateDistance < distance) {
          target = candidate;
          distance = candidateDistance;
        }
      }
    }
    _preparedFullSwipe = false;

    if (target == _rowWidth && _hasFullSwipe) {
      _commitFullSwipe(openingVelocity);
      return;
    }

    if (target == 0 && widget.group.value == widget.cellKey) {
      widget.group.value = null;
    }
    _animateTo(target, velocity: openingVelocity);
  }

  Future<void> _commitFullSwipe(double openingVelocity) async {
    if (!_hasFullSwipe || _state == _SwipeState.committing) return;
    final onPressed = widget.actions.first.onPressed;
    _state = _SwipeState.committing;
    _stopAnimation();
    if (widget.group.value == widget.cellKey) widget.group.value = null;
    AppHaptics.medium();

    try {
      final fill = _reduceMotion
          ? _offset.animateTo(
              _rowWidth,
              duration: _reducedMotionDuration,
              curve: Curves.easeOut,
            )
          : _offset.animateWith(
              SpringSimulation(
                _settleSpring,
                _offset.value,
                _rowWidth,
                openingVelocity,
              ),
            );
      onPressed();
      if (!mounted || _state != _SwipeState.committing) return;

      await fill.orCancel;
      if (!mounted || _state != _SwipeState.committing) return;

      final close = _reduceMotion
          ? _offset.animateTo(
              0,
              duration: _reducedMotionDuration,
              curve: Curves.easeOut,
            )
          : _offset.animateWith(
              SpringSimulation(_settleSpring, _offset.value, 0, 0),
            );
      await close.orCancel;
    } on TickerCanceled {
      return;
    } finally {
      if (mounted && _state == _SwipeState.committing) {
        _state = _SwipeState.closed;
      }
    }
  }

  void _close() {
    if (_state == _SwipeState.committing) return;
    if (widget.group.value == widget.cellKey) {
      widget.group.value = null;
    } else {
      _animateTo(0);
    }
  }

  void _performAction(int index) {
    if (!_canSwipe ||
        index < 0 ||
        index >= widget.actions.length ||
        _state == _SwipeState.committing) {
      return;
    }
    AppHaptics.selection();
    _close();
    widget.actions[index].onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final semanticsActions = <CustomSemanticsAction, VoidCallback>{
      if (_canSwipe)
        for (var i = 0; i < widget.actions.length; i++)
          CustomSemanticsAction(label: widget.actions[i].label): () =>
              _performAction(i),
    };

    return Semantics(
      customSemanticsActions: semanticsActions,
      child: GestureDetector(
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _canSwipe ? _handleDragStart : null,
        onHorizontalDragUpdate: _canSwipe ? _handleDragUpdate : null,
        onHorizontalDragEnd: _canSwipe ? _handleDragEnd : null,
        onHorizontalDragCancel: _canSwipe ? _handleDragCancel : null,
        child: AnimatedBuilder(
          animation: _offset,
          child: widget.child,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                _rowWidth = constraints.maxWidth;
                final offset = _offset.value.clamp(0.0, _maxOffset).toDouble();
                final panelWidth = offset > _actionExtent
                    ? offset
                    : _actionExtent;
                final rawActionLayer = _buildActionLayer(offset, panelWidth);
                final actionLayer =
                    widget.actionBorderRadius == BorderRadius.zero
                    ? rawActionLayer
                    : ClipRRect(
                        borderRadius: widget.actionBorderRadius,
                        child: rawActionLayer,
                      );
                final content = offset > 0.5
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _close,
                        child: AbsorbPointer(child: child),
                      )
                    : child!;

                return ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      if (_canSwipe && offset > 0.001)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: constraints.maxWidth - offset,
                          width: panelWidth,
                          child: actionLayer,
                        ),
                      Transform.translate(
                        offset: Offset(-offset, 0),
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: content,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionLayer(double offset, double panelWidth) {
    if (widget.actions.length == 1) {
      return _buildAction(
        0,
        _actionWidth + (offset - _actionExtent).clamp(0.0, double.infinity),
      );
    }

    final extra = (offset - _actionExtent).clamp(0.0, double.infinity);
    final fullProgress = _rowWidth <= _actionExtent
        ? 0.0
        : (extra / (_rowWidth - _actionExtent)).clamp(0.0, 1.0);
    final defaultWidth =
        _actionWidth + extra + fullProgress * (_actionExtent - _actionWidth);
    final fixedStart = offset > _actionExtent ? offset - _actionExtent : 0.0;
    var cursor = fixedStart;
    final children = <Widget>[];
    for (var index = widget.actions.length - 1; index >= 1; index--) {
      children.add(
        Positioned(
          left: cursor,
          top: 0,
          bottom: 0,
          width: _actionWidth,
          child: _buildAction(index, _actionWidth),
        ),
      );
      cursor += _actionWidth;
    }
    children.add(
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: defaultWidth,
        child: _buildAction(0, defaultWidth),
      ),
    );

    return SizedBox(
      width: panelWidth,
      child: Stack(clipBehavior: Clip.hardEdge, children: children),
    );
  }

  Widget _buildAction(int index, double width) {
    final action = widget.actions[index];
    return IgnorePointer(
      ignoring: _offset.value < _actionExtent - 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _performAction(index),
        child: Container(
          width: width,
          color: action.color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, size: 20, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
