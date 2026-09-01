import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/pages/media_browser_library_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_continue_watching_section.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/features/media_browser/widgets/media_browser_next_up_section.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/home/home_libraries_section.dart';
import 'package:omm/features/home/home_movie_section.dart';
import 'package:omm/features/home/recommend_carousel.dart';

/// MediaBrowser 首页复用 OMM 首页的氛围背景、半屏折叠 hero、轮播和区块布局。
/// 数据来自「继续观看 / 接下来观看 / 最新入库」，跳转走统一导航入口。
class MediaBrowserHomePage extends ConsumerStatefulWidget {
  const MediaBrowserHomePage({super.key});

  @override
  ConsumerState<MediaBrowserHomePage> createState() =>
      _MediaBrowserHomePageState();
}

class _MediaBrowserHomePageState extends ConsumerState<MediaBrowserHomePage> {
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPagePosition = ValueNotifier(0.0);

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPagePosition.dispose();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    ref.invalidate(mediaBrowserLatestProvider);
    ref.invalidate(mediaBrowserResumeProvider);
    ref.invalidate(mediaBrowserNextUpProvider);
    ref.invalidate(mediaBrowserLibraryStatsProvider);
    await Future.wait([
      ref
          .read(mediaBrowserLatestProvider.future)
          .catchError((_) => const <MediaBrowserItem>[]),
      ref
          .read(mediaBrowserResumeProvider.future)
          .catchError((_) => const <MediaBrowserItem>[]),
      ref
          .read(mediaBrowserNextUpProvider.future)
          .catchError((_) => const <MediaBrowserItem>[]),
      ref
          .read(mediaBrowserLibraryStatsProvider.future)
          .catchError(
            (_) => const MediaBrowserLibraryStats(
              movieCount: 0,
              seriesCount: 0,
              episodeCount: 0,
            ),
          ),
    ]);
  }

  void _syncHeroArts(
    List<MediaBrowserItem> items,
    MediaBrowserServerUrls urls,
  ) {
    final arts = [
      for (final item in items)
        HeroArt(movieId: item.id, url: urls.heroImage(item) ?? ''),
    ];
    final current = _heroArts.value;
    final same =
        current.length == arts.length &&
        [
          for (var i = 0; i < arts.length; i++)
            current[i].movieId == arts[i].movieId &&
                current[i].url == arts[i].url,
        ].every((value) => value);
    if (!same) _heroArts.value = arts;
  }

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(mediaBrowserLatestProvider);
    final resume = ref.watch(mediaBrowserResumeProvider);
    final nextUp = ref.watch(mediaBrowserNextUpProvider);
    final libraryStats = ref.watch(mediaBrowserLibraryStatsProvider);
    final urls = ref.watch(mediaBrowserServerUrlsProvider);

    final heroReady = latest.when(
      loading: () => false,
      error: (_, __) => false,
      data: (items) => items.isNotEmpty,
    );
    latest.whenData((items) {
      if (items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _heroArts.value.isNotEmpty) {
            _heroArts.value = const [];
          }
        });
      } else {
        urls.whenData((value) => _syncHeroArts(items, value));
      }
    });

    final heroMaxHeight = MediaQuery.sizeOf(context).height * 0.5;
    return HomePageScaffold(
      heroArts: _heroArts,
      heroPosition: _heroPagePosition,
      heroReady: heroReady,
      hero: latest.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) => urls.maybeWhen(
          data: (value) => items.isEmpty
              ? const SizedBox.shrink()
              : Stack(
                  children: [
                    Positioned.fill(
                      child: RecommendCarousel.mediaBrowser(
                        items: items,
                        imageUrlBuilder: (item) => value.heroImage(item) ?? '',
                        pagePosition: _heroPagePosition,
                        onItemTap: (context, item) =>
                            openMediaBrowserItem(context, ref, item),
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: HomeGreetingRow(onHero: true),
                    ),
                  ],
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
      heroFallback: Column(
        children: [
          const HomeGreetingRow(onHero: false),
          _MediaBrowserHeroFallback(
            value: latest,
            height: heroMaxHeight,
            onRetry: () => ref.invalidate(mediaBrowserLatestProvider),
          ),
        ],
      ),
      onRefresh: _refreshHome,
      slivers: [
        // -------- 继续观看 · 复用 OMM 宽幅卡片设计，空态静默 --------
        resume.when(
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (items) => items.isEmpty
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : SliverToBoxAdapter(
                  child: MediaBrowserContinueWatchingSection(items: items),
                ),
        ),
        // -------- 接下来观看 · 与继续观看同款宽幅横滑卡片，空态静默 --------
        nextUp.when(
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (items) => items.isEmpty
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : SliverToBoxAdapter(
                  child: MediaBrowserNextUpSection(items: items),
                ),
        ),
        SliverToBoxAdapter(
          child: _MediaBrowserHomeSection(
            title: '最新入库',
            value: latest,
            onRetry: () => ref.invalidate(mediaBrowserLatestProvider),
          ),
        ),
        // -------- 每个媒体库的最近添加 + 媒体库入口卡片 --------
        const _MediaBrowserViewSections(),
        SliverToBoxAdapter(
          child: _MediaBrowserLibraryStats(
            value: libraryStats,
            onRetry: () => ref.invalidate(mediaBrowserLibraryStatsProvider),
          ),
        ),
      ],
      heroMaxHeight: heroMaxHeight,
    );
  }
}

/// 首页横向区块：复用 [HomeMovieSection] 的布局，只替换条目卡片。
class _MediaBrowserHomeSection extends ConsumerWidget {
  const _MediaBrowserHomeSection({
    required this.title,
    required this.value,
    required this.onRetry,
    this.trailing,
    this.square = false,
  });

  final String title;
  final AsyncValue<List<MediaBrowserItem>> value;
  final VoidCallback onRetry;
  final Widget? trailing;

  /// 音乐库行使用方形专辑封面。
  final bool square;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    return HomeMovieSection<List<MediaBrowserItem>, MediaBrowserItem>(
      title: title,
      value: value,
      itemsOf: (items) => items,
      onRetry: onRetry,
      trailing: trailing,
      itemKeyBuilder: (item) => item.id,
      itemBuilder: (context, item) => urls.maybeWhen(
        data: (value) => MediaBrowserItemCard(
          item: item,
          urls: value,
          width: 132,
          square: square,
          onTap: () => openMediaBrowserItemUnawaited(context, ref, item),
          // 首页无拖选设计（同 OMM 首页）：空操作长按用于压制水波纹，
          // 避免长按松手误触打开详情。
          onLongPress: () {},
        ),
        orElse: () => const SizedBox(width: 132),
      ),
    );
  }
}

/// 每个媒体库的「最近添加」横排 + 底部媒体库入口卡片。
///
/// 音乐库出「最新专辑」横排（方形封面）；图书/照片等无海报内容的库
/// 不出影片行（入口卡片仍显示）；某个库没有可展示条目时整行隐藏；
/// Views 加载失败/为空时整个区块隐藏。
class _MediaBrowserViewSections extends ConsumerWidget {
  const _MediaBrowserViewSections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(mediaBrowserViewsProvider);
    final urls = ref.watch(mediaBrowserServerUrlsProvider).value;
    return views.maybeWhen(
      data: (list) {
        if (list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final serverId = ref.read(serverConfigProvider)?.activeServerId ?? '';
        final displayable = list
            .where((view) => !isSkippableViewType(view.collectionType))
            .toList(growable: false);
        return SliverMainAxisGroup(
          slivers: [
            for (final view in displayable)
              SliverToBoxAdapter(
                child: _MediaBrowserViewLatestRow(
                  serverId: serverId,
                  view: view,
                ),
              ),
            SliverToBoxAdapter(
              child: HomeLibrariesSection(
                entries: [
                  for (final view in list)
                    HomeLibraryCardEntry(
                      id: view.id,
                      name: view.name,
                      coverUrl: urls?.poster(
                        view.id,
                        maxWidth: 600,
                        tag: view.primaryImageTag,
                      ),
                      onTap: () => _openLibrary(context, view.id),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  void _openLibrary(BuildContext context, String viewId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaBrowserLibraryPage(initialViewId: viewId),
      ),
    );
  }
}

/// 单个媒体库的最近添加横排；没有可展示条目时整行隐藏。
class _MediaBrowserViewLatestRow extends ConsumerWidget {
  const _MediaBrowserViewLatestRow({
    required this.serverId,
    required this.view,
  });

  final String serverId;
  final MediaBrowserItem view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final includeItemTypes = includeItemTypesForView(view.collectionType);
    final value = ref.watch(
      mediaBrowserViewLatestProvider(
        MediaBrowserViewLatestRequest(
          serverId: serverId,
          viewId: view.id,
          includeItemTypes: includeItemTypes,
        ),
      ),
    );
    // 该库没有可展示条目时整行隐藏。
    if (value.hasValue && value.requireValue.isEmpty) {
      return const SizedBox.shrink();
    }
    return _MediaBrowserHomeSection(
      title: view.name,
      value: value,
      square: includeItemTypes == 'MusicAlbum',
      onRetry: () => ref.invalidate(
        mediaBrowserViewLatestProvider(
          MediaBrowserViewLatestRequest(
            serverId: serverId,
            viewId: view.id,
            includeItemTypes: includeItemTypes,
          ),
        ),
      ),
      trailing: _SeeAllButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MediaBrowserLibraryPage(initialViewId: view.id),
          ),
        ),
      ),
    );
  }
}

/// 首页底部的媒体库总量统计。
class _MediaBrowserLibraryStats extends StatelessWidget {
  const _MediaBrowserLibraryStats({required this.value, required this.onRetry});

  final AsyncValue<MediaBrowserLibraryStats> value;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 暗色主题的 surface 是半透明 token，直接覆盖 alpha 会变成亮白底，
    // 反而压低白色数字和灰色标签的对比度。
    final cardColor = isDark
        ? Color.alphaBlend(colors.surfaceAlt, colors.bg)
        : colors.surface.withValues(alpha: 0.72);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : colors.divider;
    return value.when(
      loading: () => const SizedBox(height: 96),
      error: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('统计加载失败', style: TextStyle(color: colors.muted)),
            const SizedBox(width: 8),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
      data: (stats) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _MediaBrowserStatItem(
                    icon: Icons.movie_outlined,
                    label: '总电影',
                    value: stats.movieCount,
                  ),
                ),
                _MediaBrowserStatDivider(color: dividerColor),
                Expanded(
                  child: _MediaBrowserStatItem(
                    icon: Icons.live_tv_outlined,
                    label: '总剧集',
                    value: stats.seriesCount,
                  ),
                ),
                _MediaBrowserStatDivider(color: dividerColor),
                Expanded(
                  child: _MediaBrowserStatItem(
                    icon: Icons.video_library_outlined,
                    label: '总集数',
                    value: stats.episodeCount,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaBrowserStatItem extends StatelessWidget {
  const _MediaBrowserStatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.accent),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: TextStyle(
            color: colors.text,
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: colors.muted, fontSize: 12)),
      ],
    );
  }
}

class _MediaBrowserStatDivider extends StatelessWidget {
  const _MediaBrowserStatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: VerticalDivider(width: 1, thickness: 1, color: color),
    );
  }
}

/// 「查看全部」入口按钮，样式与 OMM 首页一致。
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
      label: const Text(
        '查看全部',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MediaBrowserHeroFallback extends StatelessWidget {
  const _MediaBrowserHeroFallback({
    required this.value,
    required this.height,
    required this.onRetry,
  });

  final AsyncValue<List<MediaBrowserItem>> value;
  final double height;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return SizedBox(
      height: height,
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    toApiException(error).message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Text('暂无数据', style: TextStyle(color: colors.muted)),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
