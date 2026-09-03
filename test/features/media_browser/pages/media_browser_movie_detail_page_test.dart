import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/i18n/badge_position_provider.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/pages/media_browser_movie_detail_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

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

class _BadgePositionsState extends BadgePositionsNotifier {
  @override
  BadgePositions build() => const BadgePositions();
}

MediaBrowserItem _item(String id, String name) {
  return MediaBrowserItem.fromJson({
    'Id': id,
    'Name': name,
    'Type': 'Movie',
    'ProductionYear': 2024,
    'PrimaryImageTag': 'poster-$id',
  });
}

MediaBrowserItem _multiSourceItem() {
  return MediaBrowserItem.fromJson(const {
    'Id': 'movie-multi',
    'Name': '多片源电影',
    'Type': 'Movie',
    'MediaSources': [
      {
        'Id': 'media-1',
        'Name': 'first.mkv',
        'Path': '/movies/first.mkv',
        'Container': 'mkv',
        'Size': 4096,
      },
      {
        'Id': 'media-2',
        'Name': 'second.mp4',
        'Path': '/movies/second.mp4',
        'Container': 'mp4',
        'Size': 2048,
      },
    ],
  });
}

void main() {
  testWidgets('电影详情页显示 Similar 推荐区块', (tester) async {
    const serverId = 'server-1';
    final movie = _item('movie-1', '电影详情');
    final similar = _item('movie-2', '相似电影');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConfigProvider.overrideWith(
            () => _ServerConfigState(
              const ServerConfig(
                baseUrl: 'http://mb.test',
                activeServerId: serverId,
              ),
            ),
          ),
          mediaBrowserConfigProvider.overrideWithValue(MediaBrowserConfig.emby),
          mediaBrowserServerUrlsProvider.overrideWith(
            (ref) async => MediaBrowserServerUrls(
              config: MediaBrowserConfig.emby,
              baseUrl: 'http://mb.test',
              token: 'test-token',
            ),
          ),
          mediaBrowserItemDetailProvider.overrideWith(
            (ref, request) async => movie,
          ),
          mediaBrowserSimilarProvider.overrideWith(
            (ref, request) async => [similar],
          ),
          privacyShieldProvider.overrideWith(_PrivacyState.new),
          badgePositionsProvider.overrideWith(_BadgePositionsState.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: MediaBrowserMovieDetailPage(itemId: 'movie-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('更多类似'), findsOneWidget);
    expect(find.text('相似电影'), findsWidgets);
  });

  testWidgets('电影详情页显示并切换片源', (tester) async {
    const serverId = 'server-1';
    final movie = _multiSourceItem();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConfigProvider.overrideWith(
            () => _ServerConfigState(
              const ServerConfig(
                baseUrl: 'http://mb.test',
                activeServerId: serverId,
              ),
            ),
          ),
          mediaBrowserConfigProvider.overrideWithValue(MediaBrowserConfig.emby),
          mediaBrowserServerUrlsProvider.overrideWith(
            (ref) async => MediaBrowserServerUrls(
              config: MediaBrowserConfig.emby,
              baseUrl: 'http://mb.test',
              token: 'test-token',
            ),
          ),
          mediaBrowserItemDetailProvider.overrideWith(
            (ref, request) async => movie,
          ),
          mediaBrowserSimilarProvider.overrideWith(
            (ref, request) async => const <MediaBrowserItem>[],
          ),
          privacyShieldProvider.overrideWith(_PrivacyState.new),
          badgePositionsProvider.overrideWith(_BadgePositionsState.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: MediaBrowserMovieDetailPage(itemId: 'movie-multi'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('片源'), findsOneWidget);
    expect(find.text('first.mkv'), findsOneWidget);
    expect(find.text('second.mp4'), findsOneWidget);
    expect(find.textContaining('/movies/second.mp4'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('second.mp4'));
    await tester.pump();

    final group = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(group.groupValue, 'media-2');
  });
}
