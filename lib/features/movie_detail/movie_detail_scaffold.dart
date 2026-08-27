import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/platform/app_theme.dart';
import '../../shared/actor_detail_header.dart';
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
