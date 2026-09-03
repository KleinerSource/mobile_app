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
        'MediaStreams': [
          {
            'Index': 0,
            'Type': 'Video',
            'Width': 1920,
            'Height': 1080,
            'VideoRangeType': 'SDR',
            'Codec': 'h264',
          },
        ],
      },
      {
        'Id': 'media-2',
        'Name': 'second.mp4',
        'Path': '/movies/second.mp4',
        'Container': 'mp4',
        'Size': 2048,
        'MediaStreams': [
          {
            'Index': 0,
            'Type': 'Video',
            'Width': 3840,
            'Height': 2160,
            'VideoRangeType': 'HDR10',
            'Codec': 'hevc',
          },
        ],
      },
    ],
  });
}

MediaBrowserItem _feiniuMultiSourceItem() {
  return MediaBrowserItem.fromJson(const {
    'Id': 'feiniu-multi-source',
    'Name': '飞牛多片源电影',
    'Type': 'Movie',
    'MediaSources': [
      {
        'Id': 'feiniu-source-1',
        'Name': '1080p.mkv',
        'Path': '/movies/1080p.mkv',
        'MediaStreams': [
          {
            'Index': 0,
            'Type': 'Video',
            'Height': 1080,
            'VideoRangeType': 'SDR',
          },
        ],
      },
      {
        'Id': 'feiniu-source-2',
        'Name': '4K.mkv',
        'Path': '/movies/4K.mkv',
        'MediaStreams': [
          {
            'Index': 0,
            'Type': 'Video',
            'Height': 2160,
            'VideoRangeType': 'HDR10',
          },
        ],
      },
      {
        'Id': 'feiniu-source-3',
        'Name': '720p.mkv',
        'Path': '/movies/720p.mkv',
        'MediaStreams': [
          {'Index': 0, 'Type': 'Video', 'Height': 720, 'VideoRangeType': 'SDR'},
        ],
      },
    ],
    'AdditionalParts': [
      {'Id': 'feiniu-part-2', 'Name': '4K.mkv'},
      {'Id': 'feiniu-part-3', 'Name': '720p.mkv'},
    ],
  });
}

MediaBrowserItem _multiPartItem() {
  return MediaBrowserItem.fromJson(const {
    'Id': 'movie-parts',
    'Name': '分集电影',
    'Type': 'Movie',
    'MediaSources': [
      {
        'Id': 'source-cd1',
        'Name': 'CD1.mkv',
        'Path': '/movies/CD1.mkv',
        'Container': 'mkv',
      },
    ],
    'AdditionalParts': [
      {
        'Id': 'part-cd2',
        'Name': 'CD2.mp4',
        'RunTimeTicks': 5000000000,
        'MediaSources': [
          {
            'Id': 'source-cd2',
            'Name': 'CD2.mp4',
            'Path': '/movies/CD2.mp4',
            'Container': 'mp4',
            'Size': 2048,
          },
        ],
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
    expect(find.text('1080 SDR'), findsOneWidget);
    expect(find.text('4K HDR10'), findsOneWidget);
    expect(find.byType(RadioGroup<String>), findsNothing);
    expect(find.byType(RadioListTile<String>), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4K HDR10'));
    await tester.pump();

    expect(find.text('H.265 (HEVC)'), findsWidgets);
  });

  testWidgets('长按片源卡片显示文件详情', (tester) async {
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

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('4K HDR10'));
    await tester.pumpAndSettle();

    expect(find.text('second.mp4'), findsOneWidget);
    expect(find.text('/movies/second.mp4'), findsOneWidget);
    expect(find.text('H.265 (HEVC)'), findsOneWidget);
  });

  testWidgets('单片源不显示片源选择器', (tester) async {
    const serverId = 'server-1';
    final movie = MediaBrowserItem.fromJson(const {
      'Id': 'movie-single',
      'Name': '单片源电影',
      'Type': 'Movie',
      'MediaSources': [
        {
          'Id': 'media-single',
          'Name': 'single.mkv',
          'Path': '/movies/single.mkv',
          'Container': 'mkv',
          'MediaStreams': [
            {
              'Index': 0,
              'Type': 'Video',
              'Width': 1920,
              'Height': 1080,
              'VideoRangeType': 'SDR',
              'Codec': 'h264',
            },
          ],
        },
      ],
    });

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
          home: MediaBrowserMovieDetailPage(itemId: 'movie-single'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('片源'), findsNothing);
    expect(find.text('1080 SDR'), findsNothing);
  });

  testWidgets('没有视频流信息时片源摘要显示未知', (tester) async {
    const serverId = 'server-1';
    final movie = MediaBrowserItem.fromJson(const {
      'Id': 'movie-unknown-source',
      'Name': '未知片源电影',
      'Type': 'Movie',
      'MediaSources': [
        {'Id': 'media-unknown-1', 'Name': 'unknown-1.mkv'},
        {'Id': 'media-unknown-2', 'Name': 'unknown-2.mkv'},
      ],
    });

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
          home: MediaBrowserMovieDetailPage(itemId: 'movie-unknown-source'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('未知'), findsNWidgets(2));
  });

  testWidgets('电影详情页显示横向分集卡片并可切换单独分集', (tester) async {
    const serverId = 'server-1';
    final movie = _multiPartItem();

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
          home: MediaBrowserMovieDetailPage(itemId: 'movie-parts'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分集'), findsOneWidget);
    expect(find.text('连续播放全部分集'), findsNothing);
    expect(find.text('CD1.mkv'), findsOneWidget);
    expect(find.text('CD2.mp4'), findsOneWidget);
    expect(find.byType(RadioGroup<String>), findsNothing);
    expect(find.byType(RadioListTile<String>), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('CD2.mp4'));
    await tester.pump();

    expect(find.textContaining('/movies/CD2.mp4'), findsOneWidget);
  });

  testWidgets('飞牛多片源不重复显示分集选择器', (tester) async {
    const serverId = 'server-1';
    final movie = _feiniuMultiSourceItem();

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
          mediaBrowserConfigProvider.overrideWithValue(
            MediaBrowserConfig.feiniu,
          ),
          mediaBrowserServerUrlsProvider.overrideWith(
            (ref) async => MediaBrowserServerUrls(
              config: MediaBrowserConfig.feiniu,
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
          home: MediaBrowserMovieDetailPage(itemId: 'feiniu-multi-source'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('片源'), findsOneWidget);
    expect(find.text('分集'), findsNothing);
    expect(find.text('连续播放全部分集'), findsNothing);
    expect(find.text('1080 SDR'), findsOneWidget);
    expect(find.text('4K HDR10'), findsOneWidget);
    expect(find.text('720 SDR'), findsOneWidget);
    expect(find.byType(RadioGroup<String>), findsNothing);
    expect(find.byType(RadioListTile<String>), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });
}
