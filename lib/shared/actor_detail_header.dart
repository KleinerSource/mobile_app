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
/// - 头像照片 cover 满铺头图,顶部对齐
/// - 上部保持清晰;自 40% 分界线起单一渐变淡出为透明,
///   透出页面底层同图的大模糊毛玻璃(含全页统一遮罩),
///   不叠加任何额外渐变层,分界两侧同源,不会出现分割线
///   处理方式与首页/影片详情的"溶入式渐隐"不同
/// - 演员名称 + 影片数量压在头图底部的毛玻璃区,影片列表紧随其后,
///   进入页面即可见到列表首行
/// - 底缘轻微羽化,与页面头像大模糊氛围背景无缝相接
/// - 无头像或加载失败时回退为姓名色相渐变基调
class ActorHeroHeader extends ConsumerWidget {
  const ActorHeroHeader({
    super.key,
    required this.actorId,
    required this.name,
    required this.hue,
    this.actorType,
    this.movieCount,
    this.avatarPath,
    this.cacheBust,
  });

  final int actorId;
  final String name;
  final int hue;
  final String? actorType;
  final int? movieCount;
  final String? avatarPath;
  final String? cacheBust;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final avatarUrl = config == null
        ? null
        : actorAvatarUrl(config, actorId, cacheBust: cacheBust);
    // 与 ActorAvatar 同语义: 仅在头像路径为空字符串时跳过请求
    final shouldLoadImage = avatarPath == null || avatarPath!.trim().isNotEmpty;

    // 头图内容 · 色相渐变基调 + 纵向封面全高(contain · 顶对齐)
    final content = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppHues.top(hue), AppHues.bottom(hue)],
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
              color: AppHues.highlight(hue),
            ),
          ),
        ),
        if (avatarUrl != null && shouldLoadImage)
          CachedNetworkImage(
            imageUrl: avatarUrl,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面层 · 上部清晰,自 40% 分界线起单一渐变淡出为透明,
        // 透出页面底层同图的大模糊毛玻璃(含全页统一遮罩)。
        // 不做原地模糊、不叠加任何色调罩: 分界两侧为同一底层,
        // 结构上不会出现分割线
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
        Positioned(
          left: 22,
          right: 22,
          bottom: 14,
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ActorAvatar(
                  actorId: actorId,
                  name: name,
                  hue: hue,
                  size: 52,
                  avatarPath: avatarPath,
                  cacheBust: cacheBust,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (actorType?.trim().isNotEmpty == true)
                          _ActorPill(label: actorType!.trim()),
                        _ActorPill(label: '${movieCount ?? '—'} 部影片'),
                      ],
                    ),
                  ],
                ),
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
