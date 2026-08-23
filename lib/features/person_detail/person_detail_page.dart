import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/actor_avatar.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../../shared/pagination_footer.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../../shared/status_bar_scroll_to_top.dart';
import '../actor_associations/widgets/actor_association_sync_sheet.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

/// 演员 / 导演详情页 · 大头像 + 作品集 (用 actor_ids filter 反查)
class PersonDetailPage extends ConsumerStatefulWidget {
  const PersonDetailPage({
    super.key,
    required this.actorId,
    required this.name,
    this.actorType,
    this.biography,
    this.avatarPath,
    this.onUpdated,
  });

  final int actorId;
  final String name;
  final String? actorType;
  final String? biography;
  final String? avatarPath;
  final Future<void> Function()? onUpdated;

  @override
  ConsumerState<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends ConsumerState<PersonDetailPage> {
  static const _pageSize = 60;

  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MovieListItem>(
    _controller,
  );
  late String _biography;
  String? _avatarCacheBust;
  int? _totalCount;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _biography = widget.biography?.trim() ?? '';
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    final requestSerial = _requestSerial;
    try {
      final filter = MovieFilter(
        actorIds: [widget.actorId],
        sortBy: 'year',
        sortOrder: 'desc',
      );
      final page = await ref
          .read(moviesRepositoryProvider)
          .list(filter, limit: _pageSize, offset: offset);
      if (!mounted || requestSerial != _requestSerial) return;

      setState(() => _totalCount = page.totalCount);
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
      _scrollRestorer.restoreAfterPage(_scrollController);
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = toApiException(error).message;
    }
  }

  Future<void> _syncActor() async {
    final synced = await ActorAssociationSyncSheet.show(
      context,
      MappingRule(
        id: widget.actorId,
        mappedValue: widget.name,
        originalValues: [widget.name],
      ),
      currentBiography: _biography,
      onBiographyApplied: (biography) {
        if (mounted) setState(() => _biography = biography.trim());
      },
      onAvatarApplied: () {
        if (mounted) {
          setState(() {
            _avatarCacheBust = DateTime.now().microsecondsSinceEpoch.toString();
          });
        }
      },
    );
    if (synced != true || !mounted) return;
    _reload(preserveScroll: true);
    await widget.onUpdated?.call();
  }

  void _reload({bool preserveScroll = false}) {
    _requestSerial++;
    _scrollRestorer.prepare(_scrollController, preserve: preserveScroll);
    _controller.refresh();
  }

  Future<void> _openMovie(int movieId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)),
    );
    if (mounted) _reload(preserveScroll: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final hue = (widget.name.codeUnits.fold(0, (a, b) => a + b) * 31) % 360;

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: StatusBarScrollToTop(
          scrollController: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: c.bg,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: [
                  IconButton(
                    tooltip: '同步演员关联',
                    icon: const Icon(Icons.cloud_sync_outlined),
                    onPressed: _syncActor,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppHues.top(
                                    hue,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 28,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ActorAvatar(
                              actorId: widget.actorId,
                              name: widget.name,
                              hue: hue,
                              size: 110,
                              avatarPath: widget.avatarPath,
                              cacheBust: _avatarCacheBust,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(widget.name, style: AppText.pageTitle(context)),
                          if (widget.actorType != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              widget.actorType!.toUpperCase(),
                              style: TextStyle(
                                color: c.muted,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_biography.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                    child: Text(_biography, style: AppText.body(context)),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          'Filmography',
                          style: AppText.sectionTitle(context),
                        ),
                      ),
                      if (_totalCount != null)
                        Text('${_totalCount!} 部', style: AppText.meta(context)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                sliver: PagedSliverGrid<int, MovieListItem>(
                  pagingController: _controller,
                  showNoMoreItemsIndicatorAsGridChild: false,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  builderDelegate: PagedChildBuilderDelegate<MovieListItem>(
                    itemBuilder: (ctx, movie, _) => MovieCard(
                      movie: movie,
                      posterUrlBuilder: urlBuilder,
                      onTap: () => unawaited(_openMovie(movie.id)),
                    ),
                    firstPageProgressIndicatorBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    firstPageErrorIndicatorBuilder: (_) => ErrorView(
                      message: _controller.error?.toString() ?? '加载失败',
                      onRetry: _controller.refresh,
                    ),
                    newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                      onRetry: _controller.retryLastFailedRequest,
                    ),
                    noItemsFoundIndicatorBuilder: (_) =>
                        const EmptyView(message: '没有该演员的影片'),
                    noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }
}
