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
}
