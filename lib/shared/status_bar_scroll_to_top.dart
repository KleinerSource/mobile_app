import 'dart:async';

import 'package:flutter/widgets.dart';

/// 标记 IndexedStack 中当前激活的 Tab。
///
/// iOS 状态栏点击会广播给所有存活的 [WidgetsBindingObserver]，而主框架的
/// 各 Tab 页常驻 [IndexedStack]。用本组件包住每个 Tab 后，
/// [StatusBarScrollToTop] 只在所属 Tab 激活时响应回顶，避免后台 Tab 跟着滚。
class ActiveTabScope extends InheritedWidget {
  const ActiveTabScope({super.key, required this.active, required super.child});

  final bool active;

  /// 无祖先 [ActiveTabScope] 时视为激活（普通路由页面不需要标记）。
  static bool isActive(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ActiveTabScope>();
    return scope?.active ?? true;
  }

  @override
  bool updateShouldNotify(ActiveTabScope oldWidget) =>
      active != oldWidget.active;
}

/// 统一管理 iOS 状态栏点击回顶。
///
/// 页面的主滚动区应包在本组件内：内部的纵向滚动视图不传 `controller`
/// （iOS 上自动继承）或设置 `primary: true`，即可连接到本组件提供的
/// [PrimaryScrollController]，状态栏点击时整体滚回顶部。需要自定义控制器
/// 的页面（分页位置恢复、拖拽多选等）通过 [scrollController] 注入，行为不变。
///
/// 与直接依赖路由级 PrimaryScrollController 的方式相比，本组件额外处理了
/// 两个场景：
/// - 页面自身持有 ScrollController 时仍能回顶（框架默认机制只认
///   PrimaryScrollController，显式传入 controller 的滚动视图不会挂接）；
/// - 常驻 [IndexedStack] 的 Tab 页通过 [ActiveTabScope] 区分激活状态。
///
/// 动画参数（420ms easeOutCubic）为全应用统一标准，从当前位置连续滚回
/// 顶部；animateTo 会中止当前的惯性滚动，避免先闪回再开始动画。
class StatusBarScrollToTop extends StatefulWidget {
  const StatusBarScrollToTop({
    super.key,
    this.scrollController,
    required this.child,
  });

  /// 注入页面自有的控制器；省略时组件自建并管理生命周期。
  final ScrollController? scrollController;

  final Widget child;

  @override
  State<StatusBarScrollToTop> createState() => _StatusBarScrollToTopState();
}

class _StatusBarScrollToTopState extends State<StatusBarScrollToTop>
    with WidgetsBindingObserver {
  ScrollController? _ownedController;

  ScrollController get _controller =>
      widget.scrollController ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.scrollController == null) {
      _ownedController = ScrollController();
    }
  }

  @override
  void didUpdateWidget(covariant StatusBarScrollToTop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController == null && widget.scrollController != null) {
      _ownedController?.dispose();
      _ownedController = null;
    } else if (oldWidget.scrollController != null &&
        widget.scrollController == null) {
      _ownedController = ScrollController();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  void handleStatusBarTap() {
    super.handleStatusBarTap();
    final route = ModalRoute.of(context);
    if ((route != null && !route.isCurrent) ||
        !ActiveTabScope.isActive(context) ||
        !_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    if (position.pixels <= position.minScrollExtent) {
      return;
    }
    unawaited(
      _controller.animateTo(
        position.minScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _controller,
      child: widget.child,
    );
  }
}
