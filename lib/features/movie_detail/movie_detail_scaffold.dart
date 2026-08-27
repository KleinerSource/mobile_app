import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/platform/app_theme.dart';
import '../../shared/actor_detail_header.dart';
import '../../shared/poster.dart';
import '../home/hero_backdrop.dart';

/// 影片详情页的统一页面骨架。
///
/// OMM 与 dbonline 的数据来源不同，但详情页的沉浸式封面、滚动行为、
/// 氛围背景和悬浮返回栏保持一致。业务页面只提供实际存在的 sliver，
/// 缺失模块不会留下空容器。
class MovieDetailScaffold extends StatelessWidget {
  const MovieDetailScaffold({
    super.key,
    required this.hero,
    required this.heroArts,
    required this.heroPosition,
    required this.slivers,
    this.actions = const <Widget>[],
    this.heroMaxHeight = 320,
  });

  final Widget hero;
  final ValueListenable<List<HeroArt>> heroArts;
  final ValueListenable<double> heroPosition;
  final List<Widget> slivers;
  final List<Widget> actions;
  final double heroMaxHeight;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final maxHeight = heroMaxHeight.clamp(240.0, 480.0).toDouble();
    final minHeight = maxHeight * 0.62;
    final statusBarTop = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        HeroBackdrop(arts: heroArts, position: heroPosition),
        CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: false,
              delegate: CollapsibleHeroDelegate(
                minHeight: minHeight,
                maxHeight: maxHeight,
                child: KeyedSubtree(
                  key: const ValueKey('detail-hero'),
                  child: hero,
                ),
              ),
            ),
            ...slivers,
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(6, statusBarTop + 6, 6, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, size: 18),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                if (actions.isNotEmpty) ...[const Spacer(), ...actions],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 详情内容区块的统一排版容器。
///
/// 业务数据为空时由调用方不构造该区块，避免显示没有内容的标题。
class MovieDetailSection extends StatelessWidget {
  const MovieDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.bottom = 28,
  });

  final String title;
  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.sectionTitle(context)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// OMM 详情页统一横版封面组件。
///
/// dbonline 只负责提供图片地址和可用角标，渐隐、占位、顶部渐变与 OMM
/// 保持同一套实现；没有图片时只显示统一占位色块。
class MovieDetailHero extends StatelessWidget {
  const MovieDetailHero({
    super.key,
    required this.title,
    this.imageUrl,
    this.year,
    this.imageAlignment = const Alignment(0, -0.6),
    this.bottomOverlay,
    this.onTap,
  });

  final String title;
  final String? imageUrl;
  final int? year;
  final Alignment imageAlignment;
  final Widget? bottomOverlay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final hasImage = imageUrl?.trim().isNotEmpty == true;
    Widget child = Stack(
      fit: StackFit.expand,
      children: [
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.45, 1.0],
          ).createShader(bounds),
          child: hasImage
              ? Poster(
                  url: imageUrl,
                  title: title,
                  year: year,
                  aspectRatio: 16 / 9,
                  radius: 0,
                  imageAlignment: imageAlignment,
                )
              : ColoredBox(color: colors.surfaceAlt),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35],
            ),
          ),
        ),
        if (bottomOverlay != null)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: bottomOverlay,
            ),
          ),
        if (onTap != null)
          Positioned(
            top: 12,
            right: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: '查看封面大图',
                onPressed: onTap,
                icon: const Icon(
                  Icons.open_in_full_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
      ],
    );
    if (onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }
    return child;
  }
}

/// OMM 详情页统一标题、原名及年份/时长/评分信息排版。
class MovieDetailTitle extends StatelessWidget {
  const MovieDetailTitle({
    super.key,
    required this.title,
    this.originalTitle,
    this.year,
    this.runtime,
    this.rating,
  });

  final String title;
  final String? originalTitle;
  final int? year;
  final int? runtime;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    const baseStyle = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
      letterSpacing: 1.4,
    );
    final dot = TextSpan(
      text: '  ·  ',
      style: baseStyle.copyWith(color: colors.muted),
    );
    final spans = <InlineSpan>[];
    void add(InlineSpan span) {
      if (spans.isNotEmpty) spans.add(dot);
      spans.add(span);
    }

    if (year != null) {
      add(
        TextSpan(
          text: '$year',
          style: baseStyle.copyWith(color: colors.muted),
        ),
      );
    }
    if (runtime != null && runtime! > 0) {
      add(
        TextSpan(
          text: '$runtime MIN',
          style: baseStyle.copyWith(color: colors.accent),
        ),
      );
    }
    if (rating != null && rating! > 0) {
      add(
        TextSpan(
          text: '★ ${rating!.toStringAsFixed(1)}',
          style: baseStyle.copyWith(color: colors.warning),
        ),
      );
    }

    final normalizedOriginal = originalTitle?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.84,
            height: 1.1,
          ),
        ),
        if (normalizedOriginal.isNotEmpty && normalizedOriginal != title) ...[
          const SizedBox(height: 4),
          Text(
            normalizedOriginal,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (spans.isNotEmpty)
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: spans),
          ),
      ],
    );
  }
}
