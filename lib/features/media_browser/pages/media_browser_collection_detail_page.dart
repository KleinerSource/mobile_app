import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/media_models.dart' as media_models;
import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_cast_section.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/media_metadata_widgets.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/movie_detail_components.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'package:omm/shared/pagination_footer.dart';

/// MediaBrowser 合集详情页：合集信息 + 合集内影片列表。
///
/// Emby/Jellyfin 的合集是 `BoxSet` 条目，成员通过通用 Items 接口的
/// `ParentId` 查询。页面不改变已有封面和 Hero 图地址构造方式。
class MediaBrowserCollectionDetailPage extends ConsumerStatefulWidget {
  const MediaBrowserCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final String collectionId;

  @override
  ConsumerState<MediaBrowserCollectionDetailPage> createState() =>
      _MediaBrowserCollectionDetailPageState();
}

class _MediaBrowserCollectionDetailPageState
    extends ConsumerState<MediaBrowserCollectionDetailPage> {
  static const _pageSize = 24;
  static const _viewModeKey = 'media_browser.library.view_mode.v1';

  final _heroArts = ValueNotifier<List<HeroArt>>(const []);
  final _heroPosition = ValueNotifier(0.0);
  final _requests = PagedRequestCoordinator();
  final _controller = PagingController<int, MediaBrowserItem>(firstPageKey: 0);
  MediaViewMode _viewMode = MediaViewMode.portrait;
  Completer<void>? _refreshCompleter;

  String get _collectionId => widget.collectionId;

  @override
  void initState() {
    super.initState();
    _viewMode = mediaViewModeFromPreference(
      ref.read(sharedPrefsProvider).getString(_viewModeKey),
    );
    _controller.addPageRequestListener(_fetchPage);
  }

  @override
  void didUpdateWidget(covariant MediaBrowserCollectionDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId) {
      _controller.refresh();
    }
  }

  @override
  void dispose() {
    _completeRefresh();
    _requests.dispose();
    _controller.dispose();
    _heroArts.dispose();
    _heroPosition.dispose();
    super.dispose();
  }

  void _syncHeroArt(MediaBrowserItem collection, MediaBrowserServerUrls? urls) {
    final art = HeroArt(
      movieId: collection.id,
      url: urls?.heroImage(collection) ?? '',
      imageHeaders: urls?.imageHeaders,
    );
    final current = _heroArts.value;
    if (current.length == 1 &&
        current.first.movieId == art.movieId &&
        current.first.url == art.url) {
      return;
    }
    _heroArts.value = [art];
  }

  Future<void> _setViewMode(MediaViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await ref.read(sharedPrefsProvider).setString(_viewModeKey, mode.name);
  }

  Future<void> _fetchPage(int startIndex) async {
    final pageRequest = _requests.begin(startIndex);
    if (pageRequest == null) return;
    try {
      final result = await readMediaBrowserItemPage(
        ref,
        MediaBrowserItemPageRequest(
          serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
          query: media_models.MediaQuery(
            offset: startIndex,
            limit: _pageSize,
            sortBy: 'SortName',
            orderBy: 'asc',
            filters: {
              'parentId': _collectionId,
              'includeItemTypes': 'Movie,Series',
              'recursive': false,
            },
          ),
        ),
      );
      if (!pageRequest.isCurrent || !mounted) return;

      final current = _controller.itemList ?? const <MediaBrowserItem>[];
      final seen = <String>{for (final item in current) item.id};
      final items = result.items
          .where((item) => seen.add(item.id))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.items.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _controller.appendLastPage(items);
      } else {
        _controller.appendPage(items, startIndex + _pageSize);
      }
    } catch (error) {
      if (!pageRequest.isCurrent || !mounted) return;
      _controller.error = toApiException(error).message;
    } finally {
      pageRequest.finish();
      if (startIndex == _controller.firstPageKey) _completeRefresh();
    }
  }

  Future<void> _refresh() {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _refreshCompleter = completer;
    _requests.invalidate();
    _controller.refresh();
    // PagingController 通常会触发监听器；这里补发首屏请求以覆盖首屏尚未
    // 建立监听的情况，PagedRequestCoordinator 会去重同一页请求。
    unawaited(_fetchPage(_controller.firstPageKey));
    return completer.future;
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  Future<void> _refreshAll() async {
    ref.invalidate(
      mediaBrowserItemDetailProvider(
        MediaBrowserItemDetailRequest(
          serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
          itemId: _collectionId,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _openItem(MediaBrowserItem item) async {
    await openMediaBrowserItem(context, ref, item);
  }

  @override
  Widget build(BuildContext context) {
    final serverId = ref.watch(serverConfigProvider)?.activeServerId ?? '';
    final detail = ref.watch(
      mediaBrowserItemDetailProvider(
        MediaBrowserItemDetailRequest(
          serverId: serverId,
          itemId: _collectionId,
        ),
      ),
    );
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    final colors = appColors(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: toApiException(error).message,
          onRetry: () => ref.invalidate(
            mediaBrowserItemDetailProvider(
              MediaBrowserItemDetailRequest(
                serverId: serverId,
                itemId: _collectionId,
              ),
            ),
          ),
        ),
        data: (collection) {
          _syncHeroArt(collection, urls.value);
          return MovieDetailScaffold(
            onRefresh: _refreshAll,
            heroArts: _heroArts,
            heroPosition: _heroPosition,
            hero: MovieDetailHero(
              imageUrl: urls.value?.heroImage(collection),
              title: collection.name,
              year: collection.productionYear,
              imageHeaders: urls.value?.imageHeaders,
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
                  child: MovieDetailTitle(
                    title: collection.name,
                    originalTitle: collection.originalTitle,
                    year: collection.productionYear,
                    runtime: collection.runtimeMinutes > 0
                        ? collection.runtimeMinutes
                        : null,
                    rating: collection.communityRating,
                  ),
                ),
              ),
              if (collection.overview?.trim().isNotEmpty == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                    child: MovieDetailPlot(plot: collection.overview!),
                  ),
                ),
              if (collection.genres.isNotEmpty)
                SliverToBoxAdapter(
                  child: MediaTaxonomySection(
                    title: AppL10n.of(context).mediaBrowserGenres,
                    items: collection.genres,
                    ids: collection.genreIds,
                    onTapWithId: (genreId, genreName) =>
                        openMediaBrowserGenreWorks(
                          context,
                          genreId: genreId,
                          genreName: genreName,
                        ),
                  ),
                ),
              if (collection.tags.isNotEmpty)
                SliverToBoxAdapter(
                  child: MediaTaxonomySection(
                    title: AppL10n.of(context).movieEditorTag,
                    items: collection.tags,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppL10n.of(context).mediaBrowserCollectionItems,
                          style: AppText.sectionTitle(context),
                        ),
                      ),
                      MediaViewModeToggle(
                        mode: _viewMode,
                        onChanged: (mode) => unawaited(_setViewMode(mode)),
                      ),
                    ],
                  ),
                ),
              ),
              _buildItemsSliver(context, urls),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemsSliver(
    BuildContext context,
    AsyncValue<MediaBrowserServerUrls> urls,
  ) {
    return urls.maybeWhen(
      data: (value) {
        final width = MediaQuery.sizeOf(context).width;
        final crossAxisCount = width >= 1100
            ? 6
            : width >= 820
            ? 5
            : width >= 600
            ? 4
            : 3;
        const horizontalPadding = 44.0;
        const spacing = 10.0;
        final itemWidth =
            ((width - horizontalPadding) - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final delegate = PagedChildBuilderDelegate<MediaBrowserItem>(
          itemBuilder: (context, item, index) {
            if (_viewMode == MediaViewMode.landscape) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: MediaBrowserLandscapeCard(
                  item: item,
                  urls: value,
                  width: width - horizontalPadding,
                  onTap: () => unawaited(_openItem(item)),
                ),
              );
            }
            if (_viewMode == MediaViewMode.list) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MediaBrowserListRow(
                  item: item,
                  urls: value,
                  onTap: () => unawaited(_openItem(item)),
                ),
              );
            }
            return MediaBrowserItemCard(
              item: item,
              urls: value,
              width: itemWidth,
              onTap: () => unawaited(_openItem(item)),
            );
          },
          firstPageProgressIndicatorBuilder: (_) => Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: CircularProgressIndicator(
                color: appColors(context).accent,
              ),
            ),
          ),
          newPageProgressIndicatorBuilder: (_) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          ),
          firstPageErrorIndicatorBuilder: (_) => ErrorView.list(
            retryLabel: AppL10n.of(context).mediaBrowserRetry,
            message:
                _controller.error?.toString() ?? AppL10n.of(context).loadFailed,
            onRetry: _controller.retryLastFailedRequest,
          ),
          newPageErrorIndicatorBuilder: (_) =>
              PaginationRetry(onRetry: _controller.retryLastFailedRequest),
          noItemsFoundIndicatorBuilder: (_) => MediaBrowserEmptyPlaceholder(
            text: AppL10n.of(context).mediaBrowserNoCollectionItems,
          ),
          noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
        );
        if (_viewMode == MediaViewMode.portrait) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: PagedSliverGrid<int, MediaBrowserItem>(
              pagingController: _controller,
              showNoMoreItemsIndicatorAsGridChild: false,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: MediaCardTemplate.gridChildAspectRatio,
                mainAxisSpacing: 14,
                crossAxisSpacing: spacing,
              ),
              builderDelegate: delegate,
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          sliver: PagedSliverList<int, MediaBrowserItem>(
            pagingController: _controller,
            builderDelegate: delegate,
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView.list(
          message: toApiException(error).message,
          onRetry: () => ref.invalidate(mediaBrowserServerUrlsProvider),
        ),
      ),
      orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}
