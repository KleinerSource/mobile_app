import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/actor_detail_header.dart';
import 'hero_backdrop.dart';
import 'server_switcher.dart';

/// 首页统一的问候和服务器切换行。
///
/// 两个项目只替换数据源，顶部布局、状态栏避让和切换器保持一致。
class HomeGreetingRow extends StatelessWidget {
  const HomeGreetingRow({super.key, required this.onHero});

  final bool onHero;

  String _greeting(AppL10n l) {
    final hour = DateTime.now().hour;
    if (hour < 5) return l.greetingNight;
    if (hour < 12) return l.greetingMorning;
    if (hour < 18) return l.greetingAfternoon;
    if (hour < 22) return l.greetingEvening;
    return l.greetingNight;
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 12 + topInset, 22, 0),
      child: Row(
        children: [
          Expanded(
            child: onHero
                ? IgnorePointer(
                    child: Text(
                      _greeting(l),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.24,
                      ),
                    ),
                  )
                : Text(
                    _greeting(l),
                    style: TextStyle(
                      color: colors.muted,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.24,
                    ),
                  ),
          ),
          const HomeServerSwitcher(),
        ],
      ),
    );
  }
}

/// OMM 与 dbonline 共用的首页滚动骨架。
///
/// [hero]、[heroFallback] 和 [slivers] 只承载数据源差异；氛围背景、
/// 折叠高度、下拉刷新及底部留白由此处统一维护。
class HomePageScaffold extends StatelessWidget {
  const HomePageScaffold({
    super.key,
    required this.heroArts,
    required this.heroPosition,
    required this.heroReady,
    required this.hero,
    required this.heroFallback,
    required this.onRefresh,
    required this.slivers,
    this.heroMaxHeight,
  });

  final ValueListenable<List<HeroArt>> heroArts;
  final ValueListenable<double> heroPosition;
  final bool heroReady;
  final Widget hero;
  final Widget heroFallback;
  final Future<void> Function() onRefresh;
  final List<Widget> slivers;
  final double? heroMaxHeight;

  @override
  Widget build(BuildContext context) {
    final maxHeight = heroMaxHeight ?? MediaQuery.sizeOf(context).height * 0.5;
    final minHeight = maxHeight * 0.62;
    return Stack(
      fit: StackFit.expand,
      children: [
        HeroBackdrop(arts: heroArts, position: heroPosition),
        SafeArea(
          top: false,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (heroReady)
                  SliverPersistentHeader(
                    pinned: false,
                    delegate: CollapsibleHeroDelegate(
                      minHeight: minHeight,
                      maxHeight: maxHeight,
                      child: hero,
                    ),
                  )
                else
                  SliverToBoxAdapter(child: heroFallback),
                ...slivers,
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// OMM 首页横向影片区块的统一布局。
///
/// [D] 是数据源返回的数据容器（例如分页结果或纯列表），[I] 是影片项。
/// 页面只负责把不同数据源适配成 [itemsOf]，标题、状态和横向滚动布局保持一致。
class HomeMovieSection<D, I> extends StatelessWidget {
  const HomeMovieSection({
    super.key,
    required this.title,
    required this.value,
    required this.itemsOf,
    required this.itemBuilder,
    required this.onRetry,
    this.trailing,
    this.itemWidth = 132,
    this.rowHeight = 268,
    this.emptyText = '暂无数据',
    this.itemKeyBuilder,
  });

  final String title;
  final AsyncValue<D> value;
  final List<I> Function(D data) itemsOf;
  final Widget Function(BuildContext context, I item) itemBuilder;
  final VoidCallback onRetry;
  final Widget? trailing;
  final double itemWidth;
  final double rowHeight;
  final String emptyText;
  final Object Function(I item)? itemKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(title, style: AppText.sectionTitle(context)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 14),
          value.when(
            loading: () => SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: colors.accent),
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        toApiException(error).message,
                        style: TextStyle(color: colors.muted),
                      ),
                    ),
                    TextButton(onPressed: onRetry, child: const Text('重试')),
                  ],
                ),
              ),
            ),
            data: (data) {
              final items = itemsOf(data);
              if (items.isEmpty) {
                return SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      emptyText,
                      style: TextStyle(color: colors.muted),
                    ),
                  ),
                );
              }
              return HomeMovieRow<I>(
                items: items,
                itemWidth: itemWidth,
                height: rowHeight,
                itemKeyBuilder: itemKeyBuilder,
                itemBuilder: itemBuilder,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 首页横向影片列表，OMM 与其他数据源共用同一尺寸和滚动行为。
class HomeMovieRow<I> extends StatelessWidget {
  const HomeMovieRow({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.itemWidth = 132,
    this.height = 268,
    this.itemKeyBuilder,
  });

  final List<I> items;
  final Widget Function(BuildContext context, I item) itemBuilder;
  final double itemWidth;
  final double height;
  final Object Function(I item)? itemKeyBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          key: ValueKey(itemKeyBuilder?.call(items[index]) ?? items[index]),
          width: itemWidth,
          child: itemBuilder(context, items[index]),
        ),
      ),
    );
  }
}
