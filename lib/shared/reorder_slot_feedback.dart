import 'package:flutter/widgets.dart';

import '../core/platform/app_haptics.dart';

/// 拖拽换位触感控制器。
///
/// ReorderableListView 只负责换位动画，跨行时没有反馈；这里在拖拽期间
/// 每帧读取各行 RenderBox 位置估算落点槽位，槽位变化时给一次与滑动
/// 选择一致的 selection 轻反馈。宿主在 onReorderStart/onReorderEnd 之间
/// 启停，并把每行包进 [ReorderableRowGeometry] 完成注册。
class ReorderSlotFeedback {
  /// 行几何注册表（rowId → 行 context），拖拽期间按帧读取各行 RenderBox
  /// 位置，用于估算拖拽落点槽位。
  final Map<String, BuildContext> _rowContexts = {};
  String? _draggingId;
  BuildContext? _dragProxyContext;
  int _lastDragSlot = 0;

  void registerRow(String rowId, BuildContext context) {
    _rowContexts[rowId] = context;
  }

  /// 守卫式注销：同名行可能正在 overlay 代理与列表间迁移，只移除自己的注册。
  void unregisterRow(String rowId, BuildContext context) {
    if (_rowContexts[rowId] == context) _rowContexts.remove(rowId);
  }

  void startDrag(String rowId, int initialSlot) {
    _draggingId = rowId;
    _dragProxyContext = null;
    _lastDragSlot = initialSlot;
    _scheduleTick();
  }

  void endDrag() {
    _draggingId = null;
    _dragProxyContext = null;
  }

  void _scheduleTick() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  void _tick() {
    final rowId = _draggingId;
    if (rowId == null) return;
    // 首帧注册的一定是 overlay 中的拖拽代理；代理卸载说明拖拽已被取消
    // 或落定（取消路径不触发 onReorderEnd，靠 mounted 自愈停止轮询）。
    final proxyContext = _dragProxyContext ??= _rowContexts[rowId];
    final proxyObject = proxyContext?.findRenderObject();
    if (proxyContext == null ||
        !proxyContext.mounted ||
        proxyObject is! RenderBox ||
        !proxyObject.attached) {
      _draggingId = null;
      _dragProxyContext = null;
      return;
    }
    // 拖拽行（overlay 中的代理）中心越过哪一行，就落在哪个位置。
    final proxyCenter =
        proxyObject.localToGlobal(Offset.zero).dy +
        proxyObject.size.height / 2;
    var slot = 0;
    for (final entry in _rowContexts.entries) {
      if (entry.key == rowId) continue;
      final box = entry.value.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final center = box.localToGlobal(Offset.zero).dy + box.size.height / 2;
      if (proxyCenter > center) slot++;
    }
    if (slot != _lastDragSlot) {
      _lastDragSlot = slot;
      AppHaptics.selection();
    }
    _scheduleTick();
  }
}

/// 向宿主注册行 context 的透明包装：拖拽换位反馈按帧读取各行的
/// RenderBox 位置来估算落点槽位。拖起时行 widget 会被移入 overlay 代理，
/// 注册随之迁移，落定后由列表原位重新注册。
class ReorderableRowGeometry extends StatefulWidget {
  const ReorderableRowGeometry({
    super.key,
    required this.rowId,
    required this.onRegister,
    required this.onUnregister,
    required this.child,
  });

  final String rowId;
  final void Function(String rowId, BuildContext context) onRegister;
  final void Function(String rowId, BuildContext context) onUnregister;
  final Widget child;

  @override
  State<ReorderableRowGeometry> createState() => _ReorderableRowGeometryState();
}

class _ReorderableRowGeometryState extends State<ReorderableRowGeometry> {
  @override
  void initState() {
    super.initState();
    widget.onRegister(widget.rowId, context);
  }

  @override
  void dispose() {
    widget.onUnregister(widget.rowId, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
