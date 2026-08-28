import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/platform/app_haptics.dart';
import '../core/platform/app_theme.dart';

/// BottomSheet 可占用的最大总高度。
///
/// 状态栏/灵动岛下方额外保留的视觉缓冲，避免拖拽把手卡在系统区域附近。
const sheetTopClearance = 64.0;

/// 底部面板必须始终为顶部状态栏保留安全区和一段可见余量，确保公共拖拽
/// 把手不会贴到状态栏或被系统区域遮挡。实际高度仍由业务内容决定。
double sheetMaxHeight(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  return (mediaQuery.size.height -
          mediaQuery.viewPadding.top -
          sheetTopClearance)
      .clamp(0.0, mediaQuery.size.height)
      .toDouble();
}

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

const _sheetDragTouchSlop = 10.0;
const _sheetDragDismissDistance = 120.0;
const _sheetDragDismissVelocity = 900.0;

enum _SheetScrollState { unknown, atTop, awayFromTop }

class _SheetScrollableSnapshot {
  _SheetScrollableSnapshot({required this.context, required this.atTop});

  final BuildContext context;
  bool atTop;
}

/// 统一协调 BottomSheet 与内部滚动控件的下拉手势。
///
/// 原生 BottomSheet 的垂直拖拽识别器会和 ListView/SingleChildScrollView
/// 争夺同一个手势。这里监听原始指针事件，在无滚动内容或当前滚动控件位于
/// 顶部时让面板跟手下移；滚动控件处于中部时则完全交给滚动控件处理。
class SheetDragCoordinator extends StatefulWidget {
  const SheetDragCoordinator({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<SheetDragCoordinator> createState() => _SheetDragCoordinatorState();
}

class _SheetDragCoordinatorState extends State<SheetDragCoordinator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settleController;
  final List<_SheetScrollableSnapshot> _scrollables = [];

  int? _pointer;
  VelocityTracker? _velocityTracker;
  Offset? _lastPointerPosition;
  double? _eligibleDragStartY;
  double _dragOffset = 0;
  bool _draggingSheet = false;
  BuildContext? _activeScrollableContext;
  _SheetScrollState _scrollState = _SheetScrollState.unknown;

  double _settleFrom = 0;

  @override
  void initState() {
    super.initState();
    _settleController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          if (!mounted) return;
          setState(() {
            _dragOffset = _settleFrom * (1 - _settleController.value);
          });
        });
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  bool _isAtTop(ScrollMetrics metrics) {
    return metrics.extentBefore <= 0.5;
  }

  bool _containsGlobalPosition(BuildContext context, Offset position) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final localPosition = renderObject.globalToLocal(position);
    return (Offset.zero & renderObject.size).contains(localPosition);
  }

  _SheetScrollableSnapshot? _snapshotForPosition(Offset position) {
    for (var index = _scrollables.length - 1; index >= 0; index--) {
      final snapshot = _scrollables[index];
      if (_containsGlobalPosition(snapshot.context, position)) return snapshot;
    }
    return null;
  }

  void _setScrollState(_SheetScrollState next) {
    final previous = _scrollState;
    if (previous == next) return;

    // 列表从中部被持续下拉到顶部后，下一段向下移动才应该开始拖面板；
    // 重置基线可以避免面板把前一段列表滚动距离算进去而突然跳动。
    if (_pointer != null &&
        previous == _SheetScrollState.awayFromTop &&
        next == _SheetScrollState.atTop &&
        !_draggingSheet) {
      _eligibleDragStartY = _lastPointerPosition?.dy;
    }
    _scrollState = next;
  }

  void _recordScrollableSnapshot(
    BuildContext notificationContext,
    ScrollMetrics metrics,
  ) {
    final atTop = _isAtTop(metrics);
    final existingIndex = _scrollables.indexWhere(
      (snapshot) => identical(snapshot.context, notificationContext),
    );
    if (existingIndex == -1) {
      _scrollables.add(
        _SheetScrollableSnapshot(context: notificationContext, atTop: atTop),
      );
    } else {
      _scrollables[existingIndex].atTop = atTop;
    }

    if (_pointer != null) {
      final isActive = identical(_activeScrollableContext, notificationContext);
      final canBecomeActive =
          _activeScrollableContext == null &&
          _lastPointerPosition != null &&
          _containsGlobalPosition(notificationContext, _lastPointerPosition!);
      if (isActive || canBecomeActive) {
        _activeScrollableContext = notificationContext;
        _setScrollState(
          atTop ? _SheetScrollState.atTop : _SheetScrollState.awayFromTop,
        );
      }
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.enabled || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final notificationContext = notification.context;
    if (notificationContext != null) {
      _recordScrollableSnapshot(notificationContext, notification.metrics);
    }
    return false;
  }

  bool _handleScrollMetricsNotification(
    ScrollMetricsNotification notification,
  ) {
    if (!widget.enabled || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final notificationContext = notification.context;
    _recordScrollableSnapshot(notificationContext, notification.metrics);
    return false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;

    _settleController.stop();
    final snapshot = _snapshotForPosition(event.position);
    _pointer = event.pointer;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _lastPointerPosition = event.position;
    _eligibleDragStartY = event.position.dy;
    _draggingSheet = false;
    _activeScrollableContext = snapshot?.context;
    _scrollState = snapshot == null
        ? _SheetScrollState.unknown
        : (snapshot.atTop
              ? _SheetScrollState.atTop
              : _SheetScrollState.awayFromTop);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || _lastPointerPosition == null) return;

    final previousPosition = _lastPointerPosition!;
    _lastPointerPosition = event.position;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final deltaY = event.position.dy - previousPosition.dy;

    if (!_draggingSheet) {
      final startY = _eligibleDragStartY;
      if (startY == null ||
          _scrollState == _SheetScrollState.awayFromTop ||
          event.position.dy - startY <= _sheetDragTouchSlop) {
        return;
      }

      _draggingSheet = true;
      _settleController.stop();
      _dragOffset = event.position.dy - startY - _sheetDragTouchSlop;
      setState(() {});
      return;
    }

    _dragOffset = (_dragOffset + deltaY).clamp(0.0, double.infinity).toDouble();
    setState(() {});
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;

    final wasDragging = _draggingSheet;
    final dragOffset = _dragOffset;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final velocity = wasDragging
        ? (_velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0.0)
        : 0.0;
    _resetPointerState();
    if (!wasDragging) return;

    // 使用指针速度估计识别明显的向下甩动，距离阈值仍是主要关闭条件。
    final shouldDismiss =
        dragOffset >= _sheetDragDismissDistance ||
        velocity >= _sheetDragDismissVelocity;
    if (shouldDismiss) {
      Navigator.of(context).pop();
    } else {
      _animateBack();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    final wasDragging = _draggingSheet;
    _resetPointerState();
    if (wasDragging) _animateBack();
  }

  void _resetPointerState() {
    _pointer = null;
    _velocityTracker = null;
    _lastPointerPosition = null;
    _eligibleDragStartY = null;
    _draggingSheet = false;
    _activeScrollableContext = null;
    _scrollState = _SheetScrollState.unknown;
  }

  void _animateBack() {
    if (!mounted || _dragOffset <= 0) return;
    _settleFrom = _dragOffset;
    _settleController
      ..stop()
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _handleScrollMetricsNotification,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
