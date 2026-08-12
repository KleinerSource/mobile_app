import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/actor.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../actor_associations/widgets/actor_association_sync_sheet.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';
import 'movie_detail_page.dart';

/// 演员/导演下的影片列表
class ActorMoviesPage extends ConsumerStatefulWidget {
  const ActorMoviesPage({super.key, required this.actor});
  final ActorItem actor;

  @override
  ConsumerState<ActorMoviesPage> createState() => _ActorMoviesPageState();
}

class _ActorMoviesPageState extends ConsumerState<ActorMoviesPage> {
  static const _pageSize = 30;
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  int? _totalCount;
  late String _currentBiography;

  @override
  void initState() {
    super.initState();
    _currentBiography = widget.actor.biography?.trim() ?? '';
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    try {
      final filter = MovieFilter(
        actorIds: [widget.actor.id],
        sortBy: 'created_at',
        sortOrder: 'desc',
      );
      final page = await ref
          .read(moviesRepositoryProvider)
          .list(filter, limit: _pageSize, offset: offset);
      if (mounted) setState(() => _totalCount = page.totalCount);
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  Future<void> _syncActor() async {
    final actor = widget.actor;
    final rule = MappingRule(
      id: actor.id,
      mappedValue: actor.name,
      originalValues: [actor.name],
    );
    final synced = await ActorAssociationSyncSheet.show(
      context,
      rule,
      currentBiography: _currentBiography,
      onBiographyApplied: (biography) {
        if (mounted) setState(() => _currentBiography = biography);
      },
    );
    if (synced == true && mounted) {
      _controller.refresh();
    }
  }

  int get _hue {
    return (widget.actor.name.codeUnits.fold(0, (a, b) => a + b) * 31) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: c.bg,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, size: 18),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: [
                  IconButton(
                    tooltip: '数据源同步',
                    icon: const Icon(Icons.cloud_sync_outlined),
                    onPressed: _syncActor,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _ActorHero(
                    actor: widget.actor,
                    hue: _hue,
                    count: _totalCount,
                  ),
                ),
              ),
              if (_currentBiography.isNotEmpty)
                SliverToBoxAdapter(
                  child: _ActorBiography(biography: _currentBiography),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          '相关影片',
                          style: AppText.sectionTitle(context),
                        ),
                      ),
                      if (_totalCount != null)
                        Text(
                          '${_totalCount!} 部',
                          style: AppText.meta(context),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 80),
                sliver: PagedSliverGrid<int, MovieListItem>(
                  pagingController: _controller,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  builderDelegate: PagedChildBuilderDelegate<MovieListItem>(
                    itemBuilder: (ctx, m, idx) => MovieCard(
                      movie: m,
                      posterUrlBuilder: urlBuilder,
                      onTap: () => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => MovieDetailPage(movieId: m.id),
                        ),
                      ),
                    ),
                    firstPageProgressIndicatorBuilder: (_) =>
                        const Center(child: CupertinoActivityIndicator()),
                    firstPageErrorIndicatorBuilder: (_) => ErrorView(
                      message: _controller.error?.toString() ?? '加载失败',
                      onRetry: () => _controller.refresh(),
                    ),
                    noItemsFoundIndicatorBuilder: (_) =>
                        const EmptyView(message: '没有该演员的影片'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActorHero extends StatelessWidget {
  const _ActorHero({required this.actor, required this.hue, this.count});
  final ActorItem actor;
  final int hue;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppHues.top(hue), AppHues.bottom(hue)],
        ),
      ),
      child: Stack(
        children: [
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '演员资料',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    actor.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                      letterSpacing: -0.9,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (actor.actorType?.trim().isNotEmpty == true)
                        _HeroPill(label: actor.actorType!.trim()),
                      _HeroPill(label: '${count ?? '—'} 部影片'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

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

class _ActorBiography extends StatelessWidget {
  const _ActorBiography({required this.biography});

  final String biography;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Text(biography, style: AppText.body(context)),
    );
  }
}
