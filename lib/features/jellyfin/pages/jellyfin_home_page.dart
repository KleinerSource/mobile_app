import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/jellyfin/models/jellyfin_models.dart';
import 'package:omm/features/jellyfin/navigation/jellyfin_navigation.dart';
import 'package:omm/features/jellyfin/providers/jellyfin_providers.dart';
import 'package:omm/features/jellyfin/widgets/jellyfin_item_card.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/home/home_movie_section.dart';
import 'package:omm/features/home/recommend_carousel.dart';

/// Jellyfin 首页复用 OMM 首页的氛围背景、半屏折叠 hero、轮播和区块布局。
/// 数据来自「继续观看 / 接下来观看 / 最新入库」，跳转走统一导航入口。
class JellyfinHomePage extends ConsumerStatefulWidget {
  const JellyfinHomePage({super.key});

  @override
  ConsumerState<JellyfinHomePage> createState() => _JellyfinHomePageState();
}

class _JellyfinHomePageState extends ConsumerState<JellyfinHomePage> {
  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPagePosition = ValueNotifier(0.0);

  @override
  void dispose() {
    _heroArts.dispose();
    _heroPagePosition.dispose();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    ref.invalidate(jellyfinLatestProvider);
    ref.invalidate(jellyfinResumeProvider);
    ref.invalidate(jellyfinNextUpProvider);
    await Future.wait([
      ref.read(jellyfinLatestProvider.future).catchError((_) => const <JellyfinItem>[]),
      ref.read(jellyfinResumeProvider.future).catchError((_) => const <JellyfinItem>[]),
      ref.read(jellyfinNextUpProvider.future).catchError((_) => const <JellyfinItem>[]),
    ]);
  }

  void _syncHeroArts(List<JellyfinItem> items, JellyfinServerUrls urls) {
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
    final latest = ref.watch(jellyfinLatestProvider);
    final resume = ref.watch(jellyfinResumeProvider);
    final nextUp = ref.watch(jellyfinNextUpProvider);
    final urls = ref.watch(jellyfinServerUrlsProvider);

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
                      child: RecommendCarousel.jellyfin(
                        items: items,
                        imageUrlBuilder: (item) => item.backdropImageTags
                            .isEmpty
                            ? value.poster(item.id)
                            : value.backdrop(item.id),
                        pagePosition: _heroPagePosition,
                        onItemTap: openJellyfinItem,
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
          _JellyfinHeroFallback(
            value: latest,
            height: heroMaxHeight,
            onRetry: () => ref.invalidate(jellyfinLatestProvider),
          ),
        ],
      ),
      onRefresh: _refreshHome,
      slivers: [
        SliverToBoxAdapter(
          child: _JellyfinHomeSection(
            title: '继续观看',
            value: resume,
            onRetry: () => ref.invalidate(jellyfinResumeProvider),
            emptyText: '没有进行中的播放',
          ),
        ),
        SliverToBoxAdapter(
          child: _JellyfinHomeSection(
            title: '接下来观看',
            value: nextUp,
            onRetry: () => ref.invalidate(jellyfinNextUpProvider),
            emptyText: '暂无待看剧集',
          ),
        ),
        SliverToBoxAdapter(
          child: _JellyfinHomeSection(
            title: '最新入库',
            value: latest,
            onRetry: () => ref.invalidate(jellyfinLatestProvider),
          ),
        ),
      ],
      heroMaxHeight: heroMaxHeight,
    );
  }
}

/// 首页横向区块：复用 [HomeMovieSection] 的布局，只替换条目卡片。
class _JellyfinHomeSection extends ConsumerWidget {
  const _JellyfinHomeSection({
    required this.title,
    required this.value,
    required this.onRetry,
    this.emptyText = '暂无数据',
  });

  final String title;
  final AsyncValue<List<JellyfinItem>> value;
  final VoidCallback onRetry;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(jellyfinServerUrlsProvider);
    return HomeMovieSection<List<JellyfinItem>, JellyfinItem>(
      title: title,
      value: value,
      itemsOf: (items) => items,
      onRetry: onRetry,
      emptyText: emptyText,
      itemKeyBuilder: (item) => item.id,
      itemBuilder: (context, item) => urls.maybeWhen(
        data: (value) => JellyfinItemCard(
          item: item,
          urls: value,
          width: 132,
          onTap: () => openJellyfinItemUnawaited(context, item),
        ),
        orElse: () => const SizedBox(width: 132),
      ),
    );
  }
}

class _JellyfinHeroFallback extends StatelessWidget {
  const _JellyfinHeroFallback({
    required this.value,
    required this.height,
    required this.onRetry,
  });

  final AsyncValue<List<JellyfinItem>> value;
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
