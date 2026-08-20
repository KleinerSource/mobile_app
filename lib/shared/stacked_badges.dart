import 'package:flutter/material.dart';

/// 叠加徽章堆 · 与 Web 端一致的多徽章分组交互。
///
/// 收起时所有徽章统一为堆面(首个)徽章的宽度,按 [expandUpward] 方向
/// 错位 [peek] 露出彩色边缘;点按后展开内容以 OverlayPortal 浮层呈现,
/// 底部锚定在叠堆位置向上(或向下)拉起,不改变布局占位,
/// 兄弟徽章位置保持不动。
///
/// 展开浮层不设全屏遮罩,空白处的触摸直接穿透到下层列表/页面:
/// 滑动滚动、点击其他控件均不被拦截;触摸堆外任意位置(按下即)或
/// 祖先滚动开始时自动收起。所有徽章堆共享同一 TapRegion 分组,
/// 点开一个再点另一个时已展开的保持不动,各堆独立开合。
class StackedBadges extends StatefulWidget {
  const StackedBadges({
    super.key,
    required this.children,
    this.tooltip,
    this.peek = 5.0,
    this.spacing = 6.0,
    this.expandUpward = true,
  });

  /// 徽章列表,首个为堆面(收起时完整可见)
  final List<Widget> children;

  /// 叠堆整体的长按提示
  final String? tooltip;

  /// 收起时每层错位露出的边缘高度
  final double peek;

  /// 展开后徽章间距
  final double spacing;

  /// 展开方向: true 向上(适合底部角落), false 向下(适合顶部角落)
  final bool expandUpward;

  @override
  State<StackedBadges> createState() => _StackedBadgesState();
}

/// 所有徽章堆共享的 TapRegion 分组: 各堆的堆面与展开浮层视为同一区域,
/// 点击另一个堆只开合目标堆,不触发其余堆的 onTapOutside 收起。
final Object _stackedBadgesTapGroup = Object();

class _StackedBadgesState extends State<StackedBadges> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  bool _expanded = false;
  ScrollPosition? _watchedPosition;

  void _toggle() {
    if (_expanded) {
      _collapse();
    } else {
      setState(() => _expanded = true);
      _overlayController.show();
      // 监听祖先滚动: 从堆面/浮层本身开始拖动时,堆外触摸收起不生效,由这里兜底
      _watchedPosition = Scrollable.maybeOf(context)?.position
        ?..addListener(_onAncestorScroll);
    }
  }

  void _collapse() {
    if (!mounted || !_expanded) return;
    _unwatchPosition();
    setState(() => _expanded = false);
    _overlayController.hide();
  }

  void _onAncestorScroll() => _collapse();

  void _unwatchPosition() {
    _watchedPosition?.removeListener(_onAncestorScroll);
    _watchedPosition = null;
  }

  @override
  void dispose() {
    _unwatchPosition();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    if (widget.children.length == 1) return widget.children.single;

    final collapsed = widget.tooltip == null
        ? _buildCollapsed()
        : Tooltip(message: widget.tooltip!, child: _buildCollapsed());

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildOverlay,
      child: TapRegion(
        groupId: _stackedBadgesTapGroup,
        onTapOutside: (_) => _collapse(),
        child: CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(onTap: _toggle, child: collapsed),
        ),
      ),
    );
  }

  /// 收起: 堆面徽章(非定位)决定叠堆宽度,后方徽章先声明绘制在下层,
  /// 拉伸到堆面宽度(FittedBox 缩放过宽内容)并按层错位露出边缘。
  /// 展开时仅保留堆面占位(展开内容由浮层绘制,避免边缘条透出间隙)。
  Widget _buildCollapsed() {
    if (_expanded) return widget.children.first;

    final direction = widget.expandUpward ? -1.0 : 1.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = widget.children.length - 1; i >= 1; i--)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Transform.translate(
              offset: Offset(0, direction * widget.peek * i),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: widget.children[i],
              ),
            ),
          ),
        widget.children.first,
      ],
    );
  }

  /// 展开浮层: 列锚定在叠堆底部向上拉起(或向下展开),
  /// 各徽章恢复自然宽度。浮层只覆盖自身范围,空白处的触摸穿透到
  /// 下层页面(可正常滚动);触摸堆外任意位置时经共享 TapRegion 收起。
  Widget _buildOverlay(BuildContext context) {
    final ordered = widget.expandUpward
        ? widget.children.reversed.toList()
        : widget.children;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) SizedBox(height: widget.spacing),
          ordered[i],
        ],
      ],
    );

    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _layerLink,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor:
            widget.expandUpward ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(0, widget.expandUpward ? 0 : widget.spacing),
        child: TapRegion(
          groupId: _stackedBadgesTapGroup,
          child: GestureDetector(
            // 浮层仅占自身范围: 点按或在其上起手拖动都收起,
            // 不把点击透传到下方内容
            behavior: HitTestBehavior.opaque,
            onTap: _collapse,
            onPanStart: (_) => _collapse(),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: column,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    (widget.expandUpward ? 1.0 : -1.0) * 6.0 * (1.0 - t),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
