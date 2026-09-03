import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/actor_detail_header.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'movie_detail_formatters.dart';

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
                  tooltip: AppL10n.of(context).back,
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

/// 详情页横滑区块的通栏容器。
///
/// 标题单独保留 22 横向留白,滚动列表由调用方铺满屏宽,并把 22 的
/// 起止位置放进滚动器内部的 padding:静止时首卡与标题对齐,滚动时
/// 卡片可以一直拖到屏幕边缘,不被外层边距锁住。
class MovieDetailFullBleedSection extends StatelessWidget {
  const MovieDetailFullBleedSection({
    super.key,
    required this.header,
    required this.child,
    this.bottom = 28,
    this.gap = 14,
  });

  final Widget header;
  final Widget child;
  final double bottom;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: EdgeInsets.fromLTRB(22, 0, 22, gap), child: header),
          child,
        ],
      ),
    );
  }
}

/// 详情页简介的统一折叠与展开交互。
///
/// 预览最多显示三行，点击后在可滚动弹窗中查看完整内容。
class MovieDetailPlot extends StatelessWidget {
  const MovieDetailPlot({super.key, required this.plot});

  final String plot;

  Future<void> _showFullPlot(BuildContext context) {
    final normalizedPlot = normalizeMoviePlot(plot);
    final l = AppL10n.of(context);
    return showGlassDialog<void>(
      context: context,
      title: Text(l.detailPlotTitle),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.58,
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              normalizedPlot,
              style: AppText.body(context).copyWith(height: 1.55),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final normalizedPlot = normalizeMoviePlot(plot);
    final l = AppL10n.of(context);

    return Semantics(
      button: true,
      label: l.detailPlotViewFull,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: colors.accent.withValues(alpha: 0.08),
          highlightColor: colors.surfaceAlt.withValues(alpha: 0.28),
          onTap: () => unawaited(_showFullPlot(context)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              normalizedPlot,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(context).copyWith(height: 1.55),
            ),
          ),
        ),
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
    this.imageHeaders,
  });

  final String title;
  final String? imageUrl;
  final int? year;
  final Alignment imageAlignment;
  final Widget? bottomOverlay;
  final Map<String, String>? imageHeaders;

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
                  httpHeaders: imageHeaders,
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
      ],
    );
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
        SelectionArea(
          child: Text(
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
        ),
        if (normalizedOriginal.isNotEmpty && normalizedOriginal != title) ...[
          const SizedBox(height: 4),
          SelectionArea(
            child: Text(
              normalizedOriginal,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
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
