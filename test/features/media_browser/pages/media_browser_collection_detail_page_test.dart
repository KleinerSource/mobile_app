import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_config.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/core/sources/media/media_models.dart' as media_models;
import 'package:omm/features/media_browser/pages/media_browser_collection_detail_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_movie_detail_page.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_detail_scaffold.dart';

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

class _PrivacyState extends PrivacyShieldNotifier {
  @override
  bool build() => false;
}

class _UnusedMediaBrowserSource implements MediaBrowserMediaSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingMediaBrowserRepository extends MediaBrowserMediaRepository {
  _RecordingMediaBrowserRepository(this.items)
    : super(_UnusedMediaBrowserSource());

  final List<MediaBrowserItem> items;
  media_models.MediaQuery? lastQuery;

  @override
  Future<MediaBrowserItemPage> itemPage(media_models.MediaQuery query) async {
    lastQuery = query;
    return MediaBrowserItemPage(
      items: items,
      total: items.length,
      startIndex: query.offset,
      limit: query.limit,
    );
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final pushedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
}

class _OpenCollectionButton extends ConsumerWidget {
  const _OpenCollectionButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () =>
          unawaited(openMediaBrowserItem(context, ref, _collection())),
      child: const Text('打开合集'),
    );
  }
}

MediaBrowserItem _collection() => MediaBrowserItem.fromJson(const {
  'Id': 'collection-1',
  'Name': '示例合集',
  'Type': 'BoxSet',
  'ProductionYear': 2024,
  'Overview': '合集简介',
  'ImageTags': {'Primary': 'collection-poster'},
  'BackdropImageTags': ['collection-backdrop'],
});

MediaBrowserItem _movie() => MediaBrowserItem.fromJson(const {
  'Id': 'movie-1',
  'Name': '合集电影',
  'Type': 'Movie',
  'ProductionYear': 2020,
  'ImageTags': {'Primary': 'movie-poster'},
});

MediaBrowserItem _series() => MediaBrowserItem.fromJson(const {
  'Id': 'series-1',
  'Name': '合集剧集',
  'Type': 'Series',
  'ProductionYear': 2021,
  'ImageTags': {'Primary': 'series-poster'},
});

Future<_RecordingMediaBrowserRepository> _pumpCollectionPage(
  WidgetTester tester, {
  required MediaBrowserConfig config,
  required List<MediaBrowserItem> items,
  Locale locale = const Locale('zh'),
  _RecordingNavigatorObserver? observer,
  bool openFromLibrary = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final collection = _collection();
  final repository = _RecordingMediaBrowserRepository(items);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(preferences),
        serverConfigProvider.overrideWith(
          () => _ServerConfigState(
            const ServerConfig(
              baseUrl: 'http://media-browser.test',
              activeServerId: 'media-browser-server',
            ),
          ),
        ),
        mediaBrowserConfigProvider.overrideWithValue(config),
        mediaBrowserServerUrlsProvider.overrideWith(
          (ref) async => MediaBrowserServerUrls(
            config: config,
            baseUrl: 'http://media-browser.test',
            token: 'test-token',
          ),
        ),
        mediaBrowserMediaRepositoryProvider.overrideWithValue(repository),
        mediaBrowserItemDetailProvider.overrideWith(
          (ref, request) async => collection,
        ),
        privacyShieldProvider.overrideWith(_PrivacyState.new),
      ],
      child: MaterialApp(
        navigatorObservers: [if (observer != null) observer],
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: locale,
        home: openFromLibrary
            ? const _OpenCollectionButton()
            : const MediaBrowserCollectionDetailPage(
                collectionId: 'collection-1',
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  for (final config in [MediaBrowserConfig.emby, MediaBrowserConfig.jellyfin]) {
    testWidgets('${config.displayName} 合集详情显示 Hero 和影片列表并可点击', (tester) async {
      final observer = _RecordingNavigatorObserver();
      final repository = await _pumpCollectionPage(
        tester,
        config: config,
        items: [_movie(), _series()],
        observer: observer,
      );

      final query = repository.lastQuery;
      expect(query, isNotNull);
      expect(query!.offset, 0);
      expect(query.limit, 24);
      expect(query.sortBy, 'SortName');
      expect(query.orderBy, 'asc');
      expect(query.filters, {
        'parentId': 'collection-1',
        'includeItemTypes': 'Movie,Series',
        'recursive': false,
      });
      expect(find.text('示例合集'), findsWidgets);
      expect(find.text('合集电影'), findsOneWidget);
      expect(find.text('合集剧集'), findsOneWidget);

      final hero = tester.widget<MovieDetailHero>(find.byType(MovieDetailHero));
      expect(hero.title, '示例合集');
      expect(hero.imageUrl, contains('/Images/Backdrop'));
      expect(hero.imageUrl, contains('collection-backdrop'));

      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('合集电影'));
      await tester.pumpAndSettle();

      expect(observer.pushedRoutes, hasLength(2));
      expect(find.byType(MediaBrowserMovieDetailPage), findsOneWidget);

      Navigator.of(
        tester.element(find.byType(MediaBrowserMovieDetailPage)),
      ).pop();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('从媒体库进入合集后仍可打开合集影片详情', (tester) async {
    final observer = _RecordingNavigatorObserver();
    await _pumpCollectionPage(
      tester,
      config: MediaBrowserConfig.jellyfin,
      items: [_movie()],
      observer: observer,
      openFromLibrary: true,
    );

    await tester.tap(find.text('打开合集'));
    await tester.pumpAndSettle();
    expect(find.text('示例合集'), findsWidgets);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('合集电影'));
    await tester.pumpAndSettle();

    expect(observer.pushedRoutes, hasLength(3));
    expect(find.byType(MediaBrowserMovieDetailPage), findsOneWidget);
  });

  testWidgets('合集没有影片时显示中英文空状态', (tester) async {
    await _pumpCollectionPage(
      tester,
      config: MediaBrowserConfig.emby,
      items: const [],
      locale: const Locale('en'),
    );
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    expect(find.text('No items in this collection'), findsOneWidget);

    await _pumpCollectionPage(
      tester,
      config: MediaBrowserConfig.emby,
      items: const [],
    );
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    expect(find.text('此合集暂无影片'), findsOneWidget);
  });
}
