import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/emby/models/emby_models.dart';
import 'package:omm/features/emby/navigation/emby_navigation.dart';
import 'package:omm/features/emby/pages/emby_library_page.dart';
import 'package:omm/features/emby/providers/emby_providers.dart';
import 'package:omm/features/emby/widgets/emby_continue_watching_section.dart';
import 'package:omm/features/emby/widgets/emby_item_card.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/home/home_libraries_section.dart';
import 'package:omm/features/home/home_movie_section.dart';
import 'package:omm/features/home/recommend_carousel.dart';

/// Emby 首页复用 OMM 首页的氛围背景、半屏折叠 hero、轮播和区块布局。
/// 数据来自「继续观看 / 接下来观看 / 最新入库」，跳转走统一导航入口。
class EmbyHomePage extends ConsumerStatefulWidget {
  const EmbyHomePage({super.key});

  @override
  ConsumerState<EmbyHomePage> createState() => _EmbyHomePageState();
}

class _EmbyHomePageState extends ConsumerState<EmbyHomePage> {
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPagePosition = ValueNotifier(0.0);

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPagePosition.dispose();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    ref.invalidate(embyLatestProvider);
    ref.invalidate(embyResumeProvider);
    ref.invalidate(embyNextUpProvider);
    await Future.wait([
      ref.read(embyLatestProvider.future).catchError((_) => const <EmbyItem>[]),
      ref.read(embyResumeProvider.future).catchError((_) => const <EmbyItem>[]),
      ref.read(embyNextUpProvider.future).catchError((_) => const <EmbyItem>[]),
    ]);
  }

  void _syncHeroArts(List<EmbyItem> items, EmbyServerUrls urls) {
    final arts = [
      for (final item in items)
        HeroArt(
          movieId: item.id,
          url: item.backdropImageTags.isEmpty
              ? (item.primaryImageTag == null ? '' : urls.poster(item.id))
              : urls.backdrop(item.id),
        ),
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
    final latest = ref.watch(embyLatestProvider);
    final resume = ref.watch(embyResumeProvider);
    final nextUp = ref.watch(embyNextUpProvider);
    final urls = ref.watch(embyServerUrlsProvider);

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
                      child: RecommendCarousel.emby(
                        items: items,
                        imageUrlBuilder: (item) => item.backdropImageTags
                            .isEmpty
                            ? value.poster(item.id)
                            : value.backdrop(item.id),
                        pagePosition: _heroPagePosition,
                        onItemTap: openEmbyItem,
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
          _EmbyHeroFallback(
            value: latest,
            height: heroMaxHeight,
            onRetry: () => ref.invalidate(embyLatestProvider),
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
                  child: EmbyContinueWatchingSection(items: items),
                ),
        ),
        // -------- 接下来观看 · 空态静默 --------
        nextUp.when(
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (items) => items.isEmpty
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : SliverToBoxAdapter(
                  child: _EmbyHomeSection(
                    title: '接下来观看',
                    value: AsyncValue.data(items),
                    onRetry: () => ref.invalidate(embyNextUpProvider),
                  ),
                ),
        ),
        SliverToBoxAdapter(
          child: _EmbyHomeSection(
            title: '最新入库',
            value: latest,
            onRetry: () => ref.invalidate(embyLatestProvider),
          ),
        ),
        // -------- 每个媒体库的最近添加 + 媒体库入口卡片 --------
        const _EmbyViewSections(),
      ],
      heroMaxHeight: heroMaxHeight,
    );
  }
}

/// 首页横向区块：复用 [HomeMovieSection] 的布局，只替换条目卡片。
class _EmbyHomeSection extends ConsumerWidget {
  const _EmbyHomeSection({
    required this.title,
    required this.value,
    required this.onRetry,
    this.trailing,
  });

  final String title;
  final AsyncValue<List<EmbyItem>> value;
  final VoidCallback onRetry;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(embyServerUrlsProvider);
    return HomeMovieSection<List<EmbyItem>, EmbyItem>(
      title: title,
      value: value,
      itemsOf: (items) => items,
      onRetry: onRetry,
      trailing: trailing,
      itemKeyBuilder: (item) => item.id,
      itemBuilder: (context, item) => urls.maybeWhen(
        data: (value) => EmbyItemCard(
          item: item,
          urls: value,
          width: 132,
          onTap: () => openEmbyItemUnawaited(context, item),
        ),
        orElse: () => const SizedBox(width: 132),
      ),
    );
  }
}

/// 每个媒体库的「最近添加」横排 + 底部媒体库入口卡片。
///
/// 音乐/图书等无海报内容的库不出影片行（入口卡片仍显示）；某个库没有
/// 可展示条目时整行隐藏；Views 加载失败/为空时整个区块隐藏。
class _EmbyViewSections extends ConsumerWidget {
  const _EmbyViewSections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(embyViewsProvider);
    final urls = ref.watch(embyServerUrlsProvider).value;
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
                child: _EmbyViewLatestRow(serverId: serverId, view: view),
              ),
            SliverToBoxAdapter(
              child: HomeLibrariesSection(
                entries: [
                  for (final view in list)
                    HomeLibraryCardEntry(
                      id: view.id,
                      name: view.name,
                      coverUrl: urls?.poster(view.id, maxWidth: 600),
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
        builder: (_) => EmbyLibraryPage(initialViewId: viewId),
      ),
    );
  }
}

/// 单个媒体库的最近添加横排；没有可展示条目时整行隐藏。
class _EmbyViewLatestRow extends ConsumerWidget {
  const _EmbyViewLatestRow({required this.serverId, required this.view});

  final String serverId;
  final EmbyItem view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final includeItemTypes = includeItemTypesForView(view.collectionType);
    final value = ref.watch(
      embyViewLatestProvider(
        EmbyViewLatestRequest(
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
    return _EmbyHomeSection(
      title: view.name,
      value: value,
      onRetry: () => ref.invalidate(
        embyViewLatestProvider(
          EmbyViewLatestRequest(
            serverId: serverId,
            viewId: view.id,
            includeItemTypes: includeItemTypes,
          ),
        ),
      ),
      trailing: _SeeAllButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EmbyLibraryPage(initialViewId: view.id),
          ),
        ),
      ),
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

class _EmbyHeroFallback extends StatelessWidget {
  const _EmbyHeroFallback({
    required this.value,
    required this.height,
    required this.onRetry,
  });

  final AsyncValue<List<EmbyItem>> value;
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
