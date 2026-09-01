import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/features/i18n/badge_position_provider.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/pages/media_browser_favorites_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/poster.dart';

class _PrivacyState extends PrivacyShieldNotifier {
  _PrivacyState(this.enabled);

  final bool enabled;

  @override
  bool build() => enabled;
}

class _BadgePositionsState extends BadgePositionsNotifier {
  _BadgePositionsState(this.value);

  final BadgePositions value;

  @override
  BadgePositions build() => value;
}

/// 只实现收藏夹用到的两个方法，其余成员走默认 noSuchMethod（不应被调用）。
class _UnusedSource implements MediaBrowserMediaSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingRepo extends MediaBrowserMediaRepository {
  _RecordingRepo({required this.page}) : super(_UnusedSource());

  MediaBrowserItemPage page;
  final pageRequests = <Map<String, Object?>>[];
  final markFavoriteCalls = <(String, bool)>[];

  @override
  Future<MediaBrowserItemPage> itemPage({
    String? parentId,
    String? includeItemTypes,
    bool? recursive,
    String? searchTerm,
    String? sortBy,
    String? sortOrder,
    int? startIndex,
    int? limit,
    bool? isFavorite,
  }) async {
    pageRequests.add({
      'includeItemTypes': includeItemTypes,
      'recursive': recursive,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
      'startIndex': startIndex,
      'limit': limit,
      'isFavorite': isFavorite,
    });
    return page;
  }

  @override
  Future<MediaBrowserItem> markFavorite(String itemId, bool favorite) async {
    markFavoriteCalls.add((itemId, favorite));
    return _item(itemId, '条目 $itemId');
  }
}

MediaBrowserItem _item(String id, String name) {
  return MediaBrowserItem.fromJson({
    'Id': id,
    'Name': name,
    'Type': 'Movie',
    'ProductionYear': 2024,
    'RunTimeTicks': 54000000000,
    'UserData': const {'IsFavorite': true},
  });
}

MediaBrowserItemPage _page(List<MediaBrowserItem> items) {
  return MediaBrowserItemPage(
    items: items,
    total: items.length,
    startIndex: 0,
    limit: 24,
  );
}

Future<void> _pumpFavorites(WidgetTester tester, _RecordingRepo repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        mediaBrowserConfigProvider.overrideWithValue(MediaBrowserConfig.emby),
        mediaBrowserServerUrlsProvider.overrideWith(
          (ref) async => MediaBrowserServerUrls(
            config: MediaBrowserConfig.emby,
            baseUrl: 'http://mb.test',
            token: 't',
          ),
        ),
        mediaBrowserMediaRepositoryProvider.overrideWithValue(repo),
        privacyShieldProvider.overrideWith(() => _PrivacyState(false)),
        badgePositionsProvider.overrideWith(
          () => _BadgePositionsState(const BadgePositions()),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: MediaBrowserFavoritesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _longPress(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('加载收藏列表：请求带 IsFavorite 过滤，展示条目与计数', (tester) async {
    final repo = _RecordingRepo(
      page: _page([_item('a', '收藏条目 A'), _item('b', '收藏条目 B')]),
    );
    await _pumpFavorites(tester, repo);

    expect(find.text('收藏条目 A'), findsWidgets);
    expect(find.text('收藏条目 B'), findsWidgets);
    expect(find.text('2 个条目'), findsOneWidget);

    expect(repo.pageRequests, hasLength(1));
    expect(repo.pageRequests.single['isFavorite'], isTrue);
    expect(repo.pageRequests.single['recursive'], isTrue);
    expect(repo.pageRequests.single['sortBy'], 'DateCreated');
    expect(repo.pageRequests.single['sortOrder'], 'Descending');
    expect(
      repo.pageRequests.single['includeItemTypes'],
      'Movie,Series,Episode,MusicAlbum,Audio',
    );
  });

  testWidgets('类型 chip 切换后按新类型重新请求', (tester) async {
    final repo = _RecordingRepo(page: _page([_item('a', '收藏条目 A')]));
    await _pumpFavorites(tester, repo);

    await tester.tap(find.text('电影'));
    await tester.pumpAndSettle();

    expect(repo.pageRequests, hasLength(2));
    expect(repo.pageRequests.last['includeItemTypes'], 'Movie');
  });

  testWidgets('空收藏显示空态引导', (tester) async {
    final repo = _RecordingRepo(page: _page(const []));
    await _pumpFavorites(tester, repo);

    expect(find.text('还没有收藏的内容'), findsOneWidget);
    expect(find.text('在详情页点击 ♡ 加入收藏'), findsOneWidget);
    expect(find.text('暂无收藏'), findsOneWidget);
  });

  testWidgets('长按进入多选，批量移除调用 markFavorite 并乐观更新', (tester) async {
    final repo = _RecordingRepo(
      page: _page([_item('a', '收藏条目 A'), _item('b', '收藏条目 B')]),
    );
    await _pumpFavorites(tester, repo);

    // 标题文本在海报占位符与卡片标题处各出现一次，用首行 Poster 定位。
    await _longPress(tester, find.byType(Poster).first);
    expect(find.text('1 已选'), findsOneWidget);

    await tester.tap(find.text('移除收藏'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '移除'));
    await tester.pumpAndSettle();

    expect(repo.markFavoriteCalls, [('a', false)]);
    expect(find.text('1 个条目'), findsOneWidget);
    expect(find.text('收藏条目 A'), findsNothing);
    expect(find.text('收藏条目 B'), findsWidgets);
  });

  testWidgets('列表模式左滑整行移除单个收藏', (tester) async {
    final repo = _RecordingRepo(
      page: _page([_item('a', '收藏条目 A'), _item('b', '收藏条目 B')]),
    );
    await _pumpFavorites(tester, repo);

    // 筛选行是横向 ListView，视图切换按钮默认在可视区外，先滚动到位。
    await tester.ensureVisible(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Poster).first, const Offset(-360, 0));
    await tester.pumpAndSettle();

    expect(repo.markFavoriteCalls, [('a', false)]);
    expect(find.text('1 个条目'), findsOneWidget);
    expect(find.text('收藏条目 B'), findsWidgets);
  });

  testWidgets('卡片开启 showFavoriteBadge 时已收藏条目显示心形角标', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final item = _item('a', '已收藏条目');
    Widget harness({bool showBadge = false}) {
      return ProviderScope(
        overrides: [
          privacyShieldProvider.overrideWith(() => _PrivacyState(false)),
          badgePositionsProvider.overrideWith(
            () => _BadgePositionsState(const BadgePositions()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: MediaBrowserItemCard(
                item: item,
                urls: MediaBrowserServerUrls(
                  config: MediaBrowserConfig.emby,
                  baseUrl: 'http://mb.test',
                  token: 't',
                ),
                width: 132,
                showFavoriteBadge: showBadge,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(harness());
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);

    await tester.pumpWidget(harness(showBadge: true));
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
