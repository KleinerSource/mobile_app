import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_ranking.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/pages/db_online_entity_movies_page.dart';
import 'package:omm/features/db_online/providers/db_online_ranking_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_entity_card.dart';
import 'package:omm/features/db_online/widgets/db_online_filter_options.dart';
import 'package:omm/features/db_online/widgets/db_online_list_filter_sheets.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';

/// dbonline 排行榜页：Top250、日/周/月榜与演员榜。
///
/// 榜单与类型切换沿用筛选 chip 的交互；Top250 额外提供筛选弹层、
/// 无限滚动与一键订阅，与网页端 `/rankings` 保持一致。
class DbOnlineRankingsPage extends ConsumerStatefulWidget {
  const DbOnlineRankingsPage({super.key});

  @override
  ConsumerState<DbOnlineRankingsPage> createState() =>
      _DbOnlineRankingsPageState();
}

enum _Board { top250, daily, weekly, monthly, actors }

class _DbOnlineRankingsPageState extends ConsumerState<DbOnlineRankingsPage> {
  _Board _board = _Board.daily;
  int _contentType = 0;

  // Top250 筛选：'' = 全部，'0'-'3' = 影片类型，'2008'+ = 年份。
  String _top250Value = '';
  int _startRank = 1;
  bool _ignoreWatched = false;

  bool get _top250HasFilter =>
      _top250Value.isNotEmpty || _startRank != 1 || _ignoreWatched;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final top250Available = ref.watch(dbOnlineTop250AvailableProvider);
    final board = _board == _Board.top250 && !top250Available
        ? _Board.daily
        : _board;
    // 演员榜固定纵向卡片网格，不提供视图切换。
    final showsViewModeToggle = board != _Board.actors;
    final viewMode = ref.watch(mediaServerViewModeProvider);

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              eyebrow: 'DB ONLINE',
              bottomPadding: PageHeader.toolbarTopGap,
              title: Text(
                l.dbOnlineRankingsTitle,
                style: AppText.pageTitle(context),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeaderActionButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: l.dbOnlineRankingAutoTitle,
                    onPressed: () => unawaited(_openAutoConfig()),
                  ),
                  if (board == _Board.top250) ...[
                    const SizedBox(width: 4),
                    HeaderActionButton(
                      icon: Icons.favorite_outline_rounded,
                      tooltip: l.dbOnlineRankingSubscribeAll,
                      color: appColors(context).accent,
                      onPressed: () => unawaited(_confirmSubscribeAll()),
                    ),
                    const SizedBox(width: 4),
                    // 筛选按钮与影片库等其他页面的紧凑筛选样式一致。
                    Tooltip(
                      message: l.dbOnlineLibraryFilters,
                      child: CompactFilterButton(
                        label: '',
                        icon: Icons.tune_rounded,
                        active: _top250HasFilter,
                        onTap: () => unawaited(_showTop250FilterSheet()),
                      ),
                    ),
                  ],
                  if (showsViewModeToggle) ...[
                    const SizedBox(width: 4),
                    const MediaServerViewModeToggle(),
                  ],
                ],
              ),
              // 仅演员榜以圆形按钮收尾，其余榜单末尾是视图切换胶囊。
              alignTrailingToPadding: !showsViewModeToggle,
            ),
            _ChipRow(
              // 还有内容类型行时用块间距，单独成行时由列表间距承接。
              bottom: board == _Board.top250
                  ? PageHeader.aboveListGap
                  : PageHeader.toolbarTopGap,
              children: [
                if (top250Available)
                  CompactFilterButton(
                    label: l.dbOnlineRankingTop250,
                    icon: Icons.emoji_events_outlined,
                    active: _board == _Board.top250,
                    onTap: () => setState(() => _board = _Board.top250),
                  ),
                _boardChip(
                  l.dbOnlineRankingDaily,
                  Icons.wb_sunny_outlined,
                  _Board.daily,
                ),
                _boardChip(
                  l.dbOnlineRankingWeekly,
                  Icons.date_range_outlined,
                  _Board.weekly,
                ),
                _boardChip(
                  l.dbOnlineRankingMonthly,
                  Icons.calendar_month_outlined,
                  _Board.monthly,
                ),
                _boardChip(
                  l.dbOnlineRankingActors,
                  Icons.people_outline_rounded,
                  _Board.actors,
                ),
              ],
            ),
            if (board != _Board.top250)
              _ChipRow(
                children: [
                  for (final (index, label) in _contentTypeLabels(
                    l,
                    board,
                  ).indexed)
                    CompactFilterButton(
                      label: label,
                      active: _contentType == index,
                      onTap: () => setState(() => _contentType = index),
                    ),
                ],
              ),
            Expanded(
              child: switch (board) {
                _Board.top250 => _Top250Board(
                  key: ValueKey(
                    'top250:$_top250Value:$_startRank:$_ignoreWatched',
                  ),
                  typeValue: _top250Value,
                  startRank: _startRank,
                  ignoreWatched: _ignoreWatched,
                  viewMode: viewMode,
                ),
                _Board.actors => _ActorRankingBoard(
                  key: ValueKey('actors:$_contentType'),
                  type: _contentType,
                ),
                _Board.daily ||
                _Board.weekly ||
                _Board.monthly => _MovieRankingBoard(
                  key: ValueKey('${board.name}:$_contentType'),
                  period: board.name,
                  type: _contentType,
                  viewMode: viewMode,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _boardChip(String label, IconData icon, _Board board) =>
      CompactFilterButton(
        label: label,
        icon: icon,
        active: _board == board,
        onTap: () => setState(() {
          _board = board;
          _contentType = _contentType.clamp(0, board == _Board.actors ? 2 : 3);
        }),
      );

  List<String> _contentTypeLabels(AppL10n l, _Board board) => [
    for (final value in ['0', '1', '2', if (board != _Board.actors) '3'])
      dbOnlineCategoryLabel(l, value),
  ];

  Future<void> _showTop250FilterSheet() async {
    final currentYear = DateTime.now().year;
    await showDbOnlineFilterSheet(
      context,
      sections: (l) => [
        DbOnlineFilterSection(
          title: l.dbOnlineCategorySection,
          options: [
            (value: '', label: l.filterAll),
            ...dbOnlineCategoryOptions(l, count: 4),
            for (var year = currentYear; year >= 2008; year--)
              (value: '$year', label: '$year'),
          ],
          selected: _top250Value,
          onSelected: (value) => setState(() => _top250Value = value),
        ),
        DbOnlineFilterSection(
          title: l.dbOnlineRankingStartRank,
          options: [
            for (final rank in const [1, 51, 101, 151, 201])
              (value: '$rank', label: '$rank-${rank + 49}'),
          ],
          selected: '$_startRank',
          onSelected: (value) => setState(() => _startRank = int.parse(value)),
        ),
        DbOnlineFilterSection(
          title: l.dbOnlineRankingIgnoreWatched,
          options: [
            (value: 'true', label: l.dbOnlineRankingIgnoreOn),
            (value: 'false', label: l.dbOnlineRankingIgnoreOff),
          ],
          selected: '$_ignoreWatched',
          onSelected: (value) =>
              setState(() => _ignoreWatched = value == 'true'),
        ),
      ],
    );
  }

  Future<void> _confirmSubscribeAll() async {
    final l = AppL10n.of(context);
    final client = ref.read(requiredApiClientProvider);
    final typeLabel = _top250Value.isEmpty
        ? l.filterAll
        : dbOnlineCategoryLabel(l, _top250Value);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.dbOnlineRankingSubscribeConfirmTitle),
        content: Text(
          '${l.dbOnlineRankingSubscribeConfirmIntro}\n\n'
          '${l.dbOnlineCategorySection}: $typeLabel\n'
          '${l.dbOnlineRankingStartRank}: $_startRank\n'
          '${l.dbOnlineRankingIgnoreWatched}: '
          '${_ignoreWatched ? l.dbOnlineRankingIgnoreOn : l.dbOnlineRankingIgnoreOff}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.close),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.dbOnlineRankingSubscribeAll),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await client.dbOnline.ranking.subscribeTop250(
        type: _top250TypeForRequest(),
        typeValue: _top250Value,
        ignoreWatched: _ignoreWatched,
        startRank: _startRank,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.dbOnlineRankingSubscribeAll),
          content: Text(_subscribeSummary(l, result)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.close),
            ),
          ],
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(localizedErrorMessage(l, error))),
      );
    }
  }

  String _subscribeSummary(AppL10n l, DbOnlineTop250SubscribeResult result) => [
    l.dbOnlineRankingSubscribeAdded(result.added),
    l.dbOnlineRankingSubscribeSkippedSubscribed(result.skippedSubscribed),
    l.dbOnlineRankingSubscribeSkippedBlacklist(result.skippedBlacklist),
    l.dbOnlineRankingSubscribeSkippedLibrary(result.skippedLibrary),
    l.dbOnlineRankingSubscribeSkippedDuplicate(result.skippedDuplicate),
    l.dbOnlineRankingSubscribeSkippedInvalid(result.skippedInvalid),
    l.dbOnlineRankingSubscribeFailed(result.failed),
  ].join('\n');

  String _top250TypeForRequest() => switch (_top250Value) {
    '' => 'all',
    '0' || '1' || '2' || '3' => 'video_type',
    _ => 'year',
  };

  Future<void> _openAutoConfig() async {
    final controller = ref.read(dbOnlineRankingAutoConfigProvider.notifier);
    final cached = ref.read(dbOnlineRankingAutoConfigProvider).value;
    final config =
        cached ??
        await ref
            .read(dbOnlineRankingAutoConfigProvider.future)
            .catchError((_) => const DbOnlineRankingAutoConfig());
    if (!mounted) return;
    await _showAutoConfigSheet(controller, config);
  }

  Future<void> _showAutoConfigSheet(
    DbOnlineRankingAutoConfigController controller,
    DbOnlineRankingAutoConfig initial,
  ) {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var value = initial;

    Future<void> save(BuildContext sheetContext) async {
      final navigator = Navigator.of(sheetContext);
      final sheetL = AppL10n.of(sheetContext);
      try {
        await controller.save(value);
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(content: Text(l.dbOnlineRankingAutoSaved)),
        );
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(sheetL, error))),
        );
      }
    }

    return showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void update(DbOnlineRankingAutoConfig next) {
            value = next;
            setSheetState(() {});
          }

          Future<void> pickTime() async {
            final parts = value.checkTime.split(':');
            final picked = await showTimePicker(
              context: sheetContext,
              initialTime: TimeOfDay(
                hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9,
                minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
              ),
            );
            if (picked == null) return;
            final hh = picked.hour.toString().padLeft(2, '0');
            final mm = picked.minute.toString().padLeft(2, '0');
            update(value.copyWith(checkTime: '$hh:$mm'));
          }

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SheetHeader(
                    icon: Icons.notifications_none_rounded,
                    title: l.dbOnlineRankingAutoTitle,
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Text(
                      l.dbOnlineRankingAutoHint,
                      style: AppText.meta(sheetContext),
                    ),
                  ),
                  SwitchListTile(
                    value: value.enabled,
                    onChanged: (enabled) =>
                        update(value.copyWith(enabled: enabled)),
                    title: Text(
                      l.dbOnlineRankingAutoEnabled,
                      style: AppText.body(sheetContext),
                    ),
                  ),
                  _SheetSectionTitle(title: l.dbOnlineRankingAutoCheckTime),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: CompactFilterButton(
                      label: value.checkTime,
                      icon: Icons.schedule_outlined,
                      active: false,
                      onTap: () => unawaited(pickTime()),
                    ),
                  ),
                  _SheetSectionTitle(title: l.dbOnlineRankingAutoPeriods),
                  _MultiChipRow(
                    labels: [
                      l.dbOnlineRankingDaily,
                      l.dbOnlineRankingWeekly,
                      l.dbOnlineRankingMonthly,
                    ],
                    values: DbOnlineRankingAutoConfig.validPeriods.toList(),
                    selected: value.periods,
                    onToggled: (period, selected) => update(
                      value.copyWith(
                        periods: selected
                            ? [...value.periods, period]
                            : value.periods
                                  .where((item) => item != period)
                                  .toList(),
                      ),
                    ),
                  ),
                  _SheetSectionTitle(title: l.dbOnlineRankingAutoContentTypes),
                  _MultiChipRow(
                    labels: [
                      for (final value in const ['0', '1', '2', '3'])
                        dbOnlineCategoryLabel(l, value),
                    ],
                    values: const ['0', '1', '2', '3'],
                    selected: [for (final type in value.contentTypes) '$type'],
                    onToggled: (typeValue, selected) {
                      final type = int.parse(typeValue);
                      update(
                        value.copyWith(
                          contentTypes: selected
                              ? [...value.contentTypes, type]
                              : value.contentTypes
                                    .where((item) => item != type)
                                    .toList(),
                        ),
                      );
                    },
                  ),
                  _SheetSectionTitle(
                    title: l.dbOnlineRankingAutoTopN(value.topN),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Slider(
                      value: value.topN.toDouble(),
                      min: DbOnlineRankingAutoConfig.minTopN.toDouble(),
                      max: DbOnlineRankingAutoConfig.maxTopN.toDouble(),
                      divisions:
                          DbOnlineRankingAutoConfig.maxTopN -
                          DbOnlineRankingAutoConfig.minTopN,
                      onChanged: (slider) =>
                          update(value.copyWith(topN: slider.round())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => unawaited(save(sheetContext)),
                        child: Text(l.save),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 横向滚动的筛选 chip 行。
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.children,
    this.bottom = PageHeader.aboveListGap,
  });

  final List<Widget> children;

  /// 底部留白；多行 chip 之间传块间距，最后一行保持列表间距。
  final double bottom;

  @override
  Widget build(BuildContext context) {
    // 横向滚动 + Row 自然撑高，chips 文字随系统字体缩放时行高自适应。
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: 7),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

/// 排行榜名次徽章；前三名金/银/铜配色。
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final badgeColor = switch (rank) {
      1 => const Color(0xFFFFB300),
      2 => const Color(0xFF90A4AE),
      3 => const Color(0xFFA1887F),
      _ => colors.bg.withValues(alpha: 0.82),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$rank',
        strutStyle: const StrutStyle(
          fontSize: 11,
          height: 1.0,
          forceStrutHeight: true,
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 带名次徽章的影片卡片。
class _RankedMovieCard extends ConsumerWidget {
  const _RankedMovieCard({
    required this.rank,
    required this.movie,
    this.landscape = false,
    this.compact = false,
  });

  final int rank;
  final DbOnlineMovie movie;
  final bool landscape;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        DbOnlineMovieCard(
          key: ValueKey('rank-$rank-${movie.id}-${movie.number}'),
          movie: movie,
          config: ref.watch(mediaRuntimeConfigProvider),
          width: double.infinity,
          landscape: landscape,
          compact: compact,
          subscriptionActionsEnabled: true,
          // 列表模式升级为预览条目：左封面 + 右预览图翻页。
          previewList: compact,
          onTap: () => openDbOnlineMovieUnawaited(context, movie),
        ),
        Positioned(
          left: compact ? 6 : null,
          right: compact ? null : 6,
          top: 6,
          child: _RankBadge(rank: rank),
        ),
      ],
    );
  }

  /// 横版行的统一行距包装；竖版网格与紧凑列表不需要。
  Widget wrapped() => landscape ? MediaLandscapeListItem(child: this) : this;
}

/// 日/周/月榜：一次性加载全量。
class _MovieRankingBoard extends ConsumerWidget {
  const _MovieRankingBoard({
    super.key,
    required this.period,
    required this.type,
    required this.viewMode,
  });

  final String period;
  final int type;
  final MediaViewMode viewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final serverId =
        ref.watch(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    final request = DbOnlineRankingPageRequest(
      serverId: serverId,
      period: period,
      type: type,
    );
    final movies = ref.watch(dbOnlineRankingPageProvider(request));
    return movies.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: localizedErrorMessage(l, error),
        onRetry: () => ref.invalidate(dbOnlineRankingPageProvider(request)),
      ),
      data: (page) {
        if (page.movies.isEmpty) {
          return EmptyView(message: l.dbOnlineNoData);
        }
        return CustomScrollView(
          // 接入 Tab 级 PrimaryScrollController，状态栏点击可回顶。
          primary: true,
          slivers: [
            SliverPadding(
              padding: MediaListLayout.contentPadding.copyWith(bottom: 120),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final delegate = SliverChildBuilderDelegate(
                    (context, index) => _RankedMovieCard(
                      rank: index + 1,
                      movie: page.movies[index],
                      landscape: viewMode == MediaViewMode.landscape,
                      compact: viewMode == MediaViewMode.list,
                    ).wrapped(),
                    childCount: page.movies.length,
                  );
                  if (viewMode == MediaViewMode.list) {
                    return SliverList(delegate: delegate);
                  }
                  return SliverGrid(
                    gridDelegate: viewMode == MediaViewMode.landscape
                        ? const MediaLandscapeGridDelegate()
                        : const MediaGridDelegate(),
                    delegate: delegate,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Top250 榜：分页加载；筛选与一键订阅入口在页头右上角。
class _Top250Board extends ConsumerStatefulWidget {
  const _Top250Board({
    super.key,
    required this.typeValue,
    required this.startRank,
    required this.ignoreWatched,
    required this.viewMode,
  });

  final String typeValue;
  final int startRank;
  final bool ignoreWatched;
  final MediaViewMode viewMode;

  @override
  ConsumerState<_Top250Board> createState() => _Top250BoardState();
}

class _Top250BoardState extends ConsumerState<_Top250Board> {
  static const _pageSize = 25;

  final _requests = PagedRequestCoordinator();
  final _pagingController = PagingController<int, DbOnlineMovie>(
    firstPageKey: 1,
  );

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _requests.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    final pageRequest = _requests.begin(page);
    if (pageRequest == null) return;
    try {
      final result = await ref.read(
        dbOnlineTop250PageProvider(
          DbOnlineTop250PageRequest(
            serverId:
                ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
            typeValue: widget.typeValue,
            startRank: widget.startRank,
            ignoreWatched: widget.ignoreWatched,
            page: page,
            limit: _pageSize,
          ),
        ).future,
      );
      if (!pageRequest.isCurrent || !mounted) return;

      final current = _pagingController.itemList ?? const <DbOnlineMovie>[];
      final seen = <String>{for (final movie in current) _movieKey(movie)};
      final items = result.movies
          .where((movie) => seen.add(_movieKey(movie)))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.movies.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, page + 1);
      }
    } catch (error) {
      if (!pageRequest.isCurrent || !mounted) return;
      _pagingController.error = localizedErrorMessage(
        AppL10n.of(context),
        error,
      );
    } finally {
      pageRequest.finish();
    }
  }

  String _movieKey(DbOnlineMovie movie) {
    final id = movie.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'number:${movie.number.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);

    return CustomScrollView(
      // 接入 Tab 级 PrimaryScrollController，状态栏点击可回顶。
      primary: true,
      slivers: [
        SliverPadding(
          padding: MediaListLayout.contentPadding.copyWith(bottom: 120),
          sliver: widget.viewMode == MediaViewMode.portrait
              ? PagedSliverGrid<int, DbOnlineMovie>(
                  pagingController: _pagingController,
                  showNoMoreItemsIndicatorAsGridChild: false,
                  gridDelegate: const MediaGridDelegate(),
                  builderDelegate: _pagedDelegate(l),
                )
              : widget.viewMode == MediaViewMode.landscape
              ? MediaLandscapePagedSliver<int, DbOnlineMovie>(
                  pagingController: _pagingController,
                  builderDelegate: _pagedDelegate(l),
                )
              : PagedSliverList<int, DbOnlineMovie>(
                  pagingController: _pagingController,
                  builderDelegate: _pagedDelegate(l),
                ),
        ),
      ],
    );
  }

  PagedChildBuilderDelegate<DbOnlineMovie> _pagedDelegate(AppL10n l) =>
      PagedChildBuilderDelegate<DbOnlineMovie>(
        itemBuilder: (context, movie, index) => _RankedMovieCard(
          rank: movie.ranking ?? widget.startRank + index,
          movie: movie,
          landscape: widget.viewMode == MediaViewMode.landscape,
          compact: widget.viewMode == MediaViewMode.list,
        ).wrapped(),
        firstPageProgressIndicatorBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        firstPageErrorIndicatorBuilder: (_) => ErrorView(
          message: _pagingController.error?.toString() ?? l.loadFailed,
          onRetry: _pagingController.refresh,
        ),
        newPageErrorIndicatorBuilder: (_) =>
            PaginationRetry(onRetry: _pagingController.retryLastFailedRequest),
        noItemsFoundIndicatorBuilder: (_) =>
            EmptyView(message: l.dbOnlineNoData),
        noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
      );
}

/// 演员榜：一次性加载全量。
class _ActorRankingBoard extends ConsumerWidget {
  const _ActorRankingBoard({super.key, required this.type});

  final int type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final serverId =
        ref.watch(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    final request = DbOnlineRankingActorsRequest(
      serverId: serverId,
      type: type,
    );
    final actors = ref.watch(dbOnlineRankingActorsProvider(request));
    return actors.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: localizedErrorMessage(l, error),
        onRetry: () => ref.invalidate(dbOnlineRankingActorsProvider(request)),
      ),
      data: (value) {
        if (value.actors.isEmpty) {
          return EmptyView(message: l.dbOnlineNoData);
        }
        return CustomScrollView(
          // 接入 Tab 级 PrimaryScrollController，状态栏点击可回顶。
          primary: true,
          slivers: [
            SliverPadding(
              padding: MediaListLayout.contentPadding.copyWith(bottom: 120),
              sliver: SliverGrid(
                // 与演员搜索结果一致的三列纵向卡片网格。
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ActorRankingCard(
                    actor: value.actors[index],
                    rank: index + 1,
                  ),
                  childCount: value.actors.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActorRankingCard extends StatelessWidget {
  const _ActorRankingCard({required this.actor, required this.rank});

  final DbOnlineRankingActor actor;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return DbOnlineEntityCard(
      id: actor.id,
      name: actor.name,
      label: l.searchModeActorSearch,
      icon: Icons.person_outline_rounded,
      imageUrl: actor.avatarUrl,
      uncensored: actor.uncensored,
      metaText: actor.otherName ?? actor.nameZht,
      subscriptionKind: 'actor',
      subscriptionData: {
        'actor_avatar': actor.avatarUrl ?? '',
        'other_name': actor.otherName ?? '',
      },
      topLeftBadge: _RankBadge(rank: rank),
      onTap: () => unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => DbOnlineEntityMoviesPage(
              kind: 'actor',
              id: actor.id,
              title: actor.name,
            ),
          ),
        ),
      ),
    );
  }
}

/// 排行榜自动订阅配置弹层的小节标题。
class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: AppText.eyebrow(context)),
      ),
    );
  }
}

class _MultiChipRow extends StatelessWidget {
  const _MultiChipRow({
    required this.labels,
    required this.values,
    required this.selected,
    required this.onToggled,
  });

  final List<String> labels;
  final List<String> values;
  final List<String> selected;
  final void Function(String value, bool selected) onToggled;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            CompactFilterButton(
              label: labels[i],
              active: selected.contains(values[i]),
              onTap: () => onToggled(values[i], !selected.contains(values[i])),
            ),
          ],
        ],
      ),
    );
  }
}
