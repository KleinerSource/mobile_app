import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/jellyfin/models/jellyfin_models.dart';
import 'package:omm/features/jellyfin/navigation/jellyfin_navigation.dart';
import 'package:omm/features/jellyfin/providers/jellyfin_providers.dart';
import 'package:omm/features/jellyfin/widgets/jellyfin_item_card.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/pagination_footer.dart';

/// Jellyfin 搜索页。
///
/// 搜索框和结果网格沿用 OMM/Emby 搜索页的交互结构；Jellyfin 的
/// SearchTerm 同时命中电影和剧集，结果卡片按类型跳转对应详情。
class JellyfinSearchPage extends ConsumerStatefulWidget {
  const JellyfinSearchPage({super.key});

  @override
  ConsumerState<JellyfinSearchPage> createState() => _JellyfinSearchPageState();
}

class _JellyfinSearchPageState extends ConsumerState<JellyfinSearchPage> {
  final _controller = TextEditingController();
  String _submittedQuery = '';
  int _searchSerial = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
  }

  void _submitSearch([String? value]) {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) {
      if (_submittedQuery.isNotEmpty) {
        setState(() {
          _submittedQuery = '';
          _searchSerial++;
        });
      }
      return;
    }
    setState(() {
      _submittedQuery = query;
      _searchSerial++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);

    // 独立路由进入时页面自身就是 Material 根：无 Scaffold 会让 debug
    // 构建的文本出现黄色双下划线。底色由 FrostedBase 自绘，保持透明。
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlowBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('JELLYFIN', style: AppText.eyebrow(context)),
                    const SizedBox(height: 3),
                    Text(l.searchFind, style: AppText.pageTitle(context)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.cardBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search_rounded, size: 18, color: colors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: '搜索电影、剧集…',
                            hintStyle: TextStyle(
                              color: colors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                            isCollapsed: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: _onChanged,
                          onSubmitted: _submitSearch,
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: colors.muted,
                          ),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _submittedQuery = '';
                              _searchSerial++;
                            });
                          },
                        ),
                      IconButton(
                        tooltip: '搜索',
                        icon: Icon(Icons.search, size: 18, color: colors.muted),
                        onPressed: _submitSearch,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _submittedQuery.isEmpty
                    ? _JellyfinSearchEmptyHint(hint: l.searchEmpty)
                    : _JellyfinSearchResults(
                        key: ValueKey('$_submittedQuery:$_searchSerial'),
                        query: _submittedQuery,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JellyfinSearchEmptyHint extends StatelessWidget {
  const _JellyfinSearchEmptyHint({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: colors.muted2),
          const SizedBox(height: 12),
          Text(
            hint,
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _JellyfinSearchResults extends ConsumerStatefulWidget {
  const _JellyfinSearchResults({super.key, required this.query});

  final String query;

  @override
  ConsumerState<_JellyfinSearchResults> createState() =>
      _JellyfinSearchResultsState();
}

class _JellyfinSearchResultsState
    extends ConsumerState<_JellyfinSearchResults> {
  static const _pageSize = 24;

  final _pagingController = PagingController<int, JellyfinItem>(
    firstPageKey: 0,
  );
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int startIndex) async {
    try {
      final result = await ref.read(
        jellyfinItemPageProvider(
          JellyfinItemPageRequest(
            serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
            includeItemTypes: 'Movie,Series,Episode',
            recursive: true,
            searchTerm: widget.query,
            sortBy: 'SortName',
            sortOrder: 'Ascending',
            startIndex: startIndex,
            limit: _pageSize,
          ),
        ).future,
      );
      if (!mounted) return;

      final current = _pagingController.itemList ?? const <JellyfinItem>[];
      final seen = <String>{for (final item in current) item.id};
      final items = result.items
          .where((item) => seen.add(item.id))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.items.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, startIndex + _pageSize);
      }
    } catch (error) {
      if (!mounted) return;
      _pagingController.error = toApiException(error).message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = ref.watch(jellyfinServerUrlsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final itemWidth = (width - 44 - 20) / 3;

    return CustomScrollView(
      controller: _scrollController,
      primary: false,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
          sliver: PagedSliverGrid<int, JellyfinItem>(
            pagingController: _pagingController,
            showNoMoreItemsIndicatorAsGridChild: false,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
            ),
            builderDelegate: PagedChildBuilderDelegate<JellyfinItem>(
              itemBuilder: (context, item, _) => urls.maybeWhen(
                data: (value) => JellyfinItemCard(
                  key: ValueKey(item.id),
                  item: item,
                  urls: value,
                  width: itemWidth,
                  onTap: () => openJellyfinItemUnawaited(context, item),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              firstPageProgressIndicatorBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              firstPageErrorIndicatorBuilder: (_) => ErrorView(
                message: _pagingController.error?.toString() ?? '加载失败',
                onRetry: _pagingController.refresh,
              ),
              newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                onRetry: _pagingController.retryLastFailedRequest,
              ),
              noItemsFoundIndicatorBuilder: (_) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '没有找到相关内容',
                    style: AppText.meta(context),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
            ),
          ),
        ),
      ],
    );
  }
}
