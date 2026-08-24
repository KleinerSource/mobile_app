import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/server_config_provider.dart';
import '../core/platform/app_theme.dart';
import 'actor_avatar.dart';

/// 演员名 → 稳定色相 · 两个演员详情页共用,同一演员在两处色调一致。
int actorHueFromName(String name) {
  return (name.codeUnits.fold(0, (a, b) => a + b) * 31) % 360;
}

/// 演员详情统一折叠头 · 折叠数学与首页/影片详情的 hero delegate 相同:
/// 展开高度 [maxHeight](整屏),上滑先收窄到 [minHeight](62%) 再整体推出屏外。
class ActorHeroDelegate extends SliverPersistentHeaderDelegate {
  ActorHeroDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final height = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(ActorHeroDelegate oldDelegate) =>
      minHeight != oldDelegate.minHeight ||
      maxHeight != oldDelegate.maxHeight ||
      child != oldDelegate.child;
}

/// 演员详情统一头图 · 封面显示在版面上部(约 42% 屏高):
/// - 头像照片 cover 满铺头图,顶部对齐;多张时自动淡入淡出轮播
///   (无指示条、禁止手动),并通过 [pagePosition] 驱动页面氛围背景
///   以相同的交叉淡化节奏跟随切换
/// - 上部保持清晰;自 40% 分界线起单一渐变淡出为透明,
///   透出页面底层同图的大模糊毛玻璃(含全页统一遮罩),
///   不叠加任何额外渐变层,分界两侧同源,不会出现分割线
/// - 演员名称 + 影片数量压在头图底部的毛玻璃区,影片列表紧随其后,
///   进入页面即可见到列表首行
/// - 无头像或加载失败时回退为姓名色相渐变基调
class ActorHeroHeader extends ConsumerStatefulWidget {
  const ActorHeroHeader({
    super.key,
    required this.actorId,
    required this.name,
    required this.hue,
    this.actorType,
    this.avatarPaths,
    this.cacheBust,
    this.pagePosition,
  });

  final int actorId;
  final String name;
  final int hue;
  final String? actorType;

  /// 后端 avatar_path 数组 · null 视为尝试第一张,空数组为无头像
  final List<String>? avatarPaths;
  final String? cacheBust;

  /// 轮播连续页位 [0, count) · 由自动轮播的淡入进度驱动
  final ValueNotifier<double>? pagePosition;

  @override
  ConsumerState<ActorHeroHeader> createState() => _ActorHeroHeaderState();
}

class _ActorHeroHeaderState extends ConsumerState<ActorHeroHeader>
    with TickerProviderStateMixin {
  static const _autoplayInterval = Duration(seconds: 5);
  static const _fadeDuration = Duration(milliseconds: 800);

  late final AnimationController _fade;
  Timer? _autoplay;
  int _previousIndex = 0;
  int _index = 0;

  /// 封面张数: null → 1(仍尝试第一张), 空数组 → 0
  int get _coverCount {
    final paths = widget.avatarPaths;
    return paths == null ? 1 : paths.length;
  }

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    )..addListener(_syncPagePosition);
    _startAutoplay();
  }

  @override
  void didUpdateWidget(covariant ActorHeroHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 张数变化后重置索引并重启定时;回落到单张/零张时停止轮播
    final count = _coverCount;
    if (count <= 1) {
      _stopAutoplay();
      if (_index != 0 || _previousIndex != 0 || _fade.isAnimating) {
        _fade.stop();
        setState(() {
          _index = 0;
          _previousIndex = 0;
        });
        _syncPagePosition();
      }
    } else {
      if (_index >= count) _index %= count;
      if (_previousIndex >= count) _previousIndex %= count;
      _startAutoplay();
    }
  }

  @override
  void dispose() {
    _stopAutoplay();
    _fade.dispose();
    super.dispose();
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    if (_coverCount <= 1) return;
    _autoplay = Timer.periodic(_autoplayInterval, (_) => _advance());
  }

  void _stopAutoplay() {
    _autoplay?.cancel();
    _autoplay = null;
  }

  /// 自动切换到下一张: 旧封面保持,新封面淡入覆盖
  void _advance() {
    if (!mounted || _coverCount <= 1 || _fade.isAnimating) return;
    setState(() {
      _previousIndex = _index;
      _index = (_index + 1) % _coverCount;
    });
    _fade.forward(from: 0);
  }

  /// 把"基座索引 + 淡入进度"的连续页位同步给氛围背景,
  /// 使底层交叉淡化节奏与封面淡入一致
  void _syncPagePosition() {
    final notifier = widget.pagePosition;
    if (notifier == null || _coverCount == 0) return;
    final raw = _previousIndex + _fade.value;
    if ((notifier.value - raw).abs() > 0.001) {
      notifier.value = raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final count = _coverCount;

    Widget coverImage(int index) {
      if (config == null) return const SizedBox.shrink();
      return CachedNetworkImage(
        imageUrl: actorAvatarUrl(
          config,
          widget.actorId,
          cacheBust: widget.cacheBust,
          index: index,
        ),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    // 封面层 · 多张时自动淡入淡出: 基座保持上一张,新张淡入覆盖
    // (无 PageView、无指示条,用户不可手动干预)
    final Widget covers;
    if (count > 1) {
      covers = Stack(
        fit: StackFit.expand,
        children: [
          coverImage(_previousIndex),
          FadeTransition(opacity: _fade, child: coverImage(_index)),
        ],
      );
    } else if (count == 1) {
      covers = coverImage(0);
    } else {
      covers = const SizedBox.shrink();
    }

    final content = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppHues.top(widget.hue), AppHues.bottom(widget.hue)],
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: -60,
          width: 240,
          height: 240,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppHues.highlight(widget.hue),
            ),
          ),
        ),
        covers,
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面层 · 上部清晰,自 40% 分界线起单一渐变淡出为透明,
        // 透出页面底层同图的大模糊毛玻璃(含全页统一遮罩)
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.40, 1.0],
          ).createShader(bounds),
          child: content,
        ),
        // 顶部小渐变让悬浮按钮/状态栏文字可读
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black38, Colors.transparent],
              stops: [0.0, 0.35],
            ),
          ),
        ),
        // 信息层 · 压在头图底部的毛玻璃区,影片列表紧随其后
        // (封面已在展示演员照片,不再重复圆形头像)
        Positioned(
          left: 22,
          right: 22,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.7,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              // 影片数量由下方 Filmography 列表标题展示,这里只保留类型
              if (widget.actorType?.trim().isNotEmpty == true)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [_ActorPill(label: widget.actorType!.trim())],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActorPill extends StatelessWidget {
  const _ActorPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
