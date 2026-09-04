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
import 'package:omm/features/media_browser/pages/media_browser_library_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
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

/// 只实现影片库用到的成员，其余走默认 noSuchMethod（不应被调用）。
class _UnusedSource implements MediaBrowserMediaSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingRepo extends MediaBrowserMediaRepository {
  _RecordingRepo({
    required this.page,
    this.libraryViews = const [],
    this.itemPageDelay = Duration.zero,
  }) : super(_UnusedSource());

  MediaBrowserItemPage page;
  final List<MediaBrowserItem> libraryViews;
  final Duration itemPageDelay;
  final itemPageCalls = <(String?, String?)>[];
  final markFavoriteCalls = <(String, bool)>[];
  final markPlayedCalls = <(String, bool)>[];

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
    String? personIds,
    String? tagIds,
  }) async {
    itemPageCalls.add((parentId, includeItemTypes));
    if (itemPageDelay > Duration.zero) {
      await Future<void>.delayed(itemPageDelay);
    }
    return page;
  }

  @override
  Future<List<MediaBrowserItem>> views() async => libraryViews;

  @override
  Future<MediaBrowserItem> markFavorite(String itemId, bool favorite) async {
    markFavoriteCalls.add((itemId, favorite));
    return _item(itemId, '条目 $itemId');
  }

  @override
  Future<MediaBrowserItem> markPlayed(String itemId, bool played) async {
    markPlayedCalls.add((itemId, played));
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
    'UserData': const {'IsFavorite': false},
  });
}

Future<void> _pumpLibrary(
  WidgetTester tester,
  _RecordingRepo repo, {
  String? initialViewId,
}) async {
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
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: MediaBrowserLibraryPage(initialViewId: initialViewId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MediaBrowserItem _libraryView(String id, {String collectionType = 'movies'}) {
  return MediaBrowserItem.fromJson({
    'Id': id,
    'Name': '电影库',
    'Type': 'CollectionFolder',
    'CollectionType': collectionType,
  });
}

Future<void> _longPress(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('长按进入拖选，批量收藏调用 markFavorite', (tester) async {
    final repo = _RecordingRepo(
      page: MediaBrowserItemPage(
        items: [_item('a', '影片甲'), _item('b', '影片乙'), _item('c', '影片丙')],
        total: 3,
        startIndex: 0,
        limit: 24,
      ),
    );
    await _pumpLibrary(tester, repo);

    expect(find.text('影片甲'), findsWidgets);

    // 标题在海报占位符与卡片标题各出现一次，用首行 Poster 定位。
    // 一次连续手势：长按进入选择（勾选首张）→ 拖到第二张实时增选。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Poster).first),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('1 已选'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.byType(Poster).at(1)));
    await tester.pump();
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    await gesture.up();
    await tester.pump();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();

    expect(repo.markFavoriteCalls, hasLength(2));
    expect(
      repo.markFavoriteCalls.toSet(),
      {'a', 'b'}.map((id) => (id, true)).toSet(),
    );
    expect(find.text('已更新 2 个条目'), findsOneWidget);
    // 批量完成后退出选择模式。
    expect(find.text('全选'), findsNothing);
  });

  testWidgets('批量标记已走调用 markPlayed', (tester) async {
    final repo = _RecordingRepo(
      page: MediaBrowserItemPage(
        items: [_item('a', '影片甲')],
        total: 1,
        startIndex: 0,
        limit: 24,
      ),
    );
    await _pumpLibrary(tester, repo);

    await _longPress(tester, find.byType(Poster).first);
    await tester.tap(find.text('标记为已看'));
    await tester.pumpAndSettle();

    expect(repo.markPlayedCalls, [('a', true)]);
    expect(repo.markFavoriteCalls, isEmpty);
  });

  testWidgets('从指定媒体库进入后仍能加载首屏条目', (tester) async {
    final repo = _RecordingRepo(
      page: MediaBrowserItemPage(
        items: [_item('a', '影片甲')],
        total: 1,
        startIndex: 0,
        limit: 24,
      ),
      libraryViews: [_libraryView('library-1')],
      itemPageDelay: const Duration(milliseconds: 50),
    );
    await _pumpLibrary(tester, repo, initialViewId: 'library-1');
    expect(find.text('影片甲'), findsWidgets);
    expect(repo.itemPageCalls, contains(('library-1', 'Movie,Series')));
  });

  testWidgets('从音乐媒体库进入后仍能加载首屏条目', (tester) async {
    final repo = _RecordingRepo(
      page: MediaBrowserItemPage(
        items: [_item('a', '专辑甲')],
        total: 1,
        startIndex: 0,
        limit: 24,
      ),
      libraryViews: [_libraryView('music-library', collectionType: 'music')],
      itemPageDelay: const Duration(milliseconds: 50),
    );
    await _pumpLibrary(tester, repo, initialViewId: 'music-library');

    expect(find.text('专辑甲'), findsWidgets);
    expect(repo.itemPageCalls, contains(('music-library', 'MusicAlbum')));
  });
}
