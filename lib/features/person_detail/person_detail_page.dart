import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/models/mapping_rule.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/actor_avatar.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../actor_associations/widgets/actor_association_sync_sheet.dart';
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
  });

  final int actorId;
  final String name;
  final String? actorType;
  final String? biography;
  final String? avatarPath;

  @override
  ConsumerState<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends ConsumerState<PersonDetailPage> {
  late String _biography;
  String? _avatarCacheBust;

  @override
  void initState() {
    super.initState();
    _biography = widget.biography?.trim() ?? '';
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
    if (synced == true && mounted) {
      ref.invalidate(_actorMoviesProvider(widget.actorId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final hue = (widget.name.codeUnits.fold(0, (a, b) => a + b) * 31) % 360;

    final movies = ref.watch(_actorMoviesProvider(widget.actorId));

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: CustomScrollView(
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
                  tooltip: '数据源同步',
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
                                color: AppHues.top(hue).withValues(alpha: 0.4),
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
                child: Text('Filmography', style: AppText.sectionTitle(context)),
              ),
            ),
            movies.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('加载失败: $e', style: AppText.body(context)),
                ),
              ),
              data: (items) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => MovieCard(
                      movie: items[i],
                      posterUrlBuilder: urlBuilder,
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }
}

final _actorMoviesProvider =
    FutureProvider.family<List<MovieListItem>, int>((ref, actorId) async {
  final repo = ref.watch(moviesRepositoryProvider);
  final filter = MovieFilter(actorIds: [actorId], sortBy: 'year', sortOrder: 'desc');
  final page = await repo.list(filter, limit: 60, offset: 0);
  return page.items;
});
