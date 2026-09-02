import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/pages/media_browser_home_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

const _serverConfig = ServerConfig(
  baseUrl: 'http://media.test',
  activeServerId: 'server-1',
);

MediaBrowserServerUrls _serverUrls() => MediaBrowserServerUrls(
  config: MediaBrowserConfig.jellyfin,
  baseUrl: _serverConfig.baseUrl,
);

List<dynamic> _baseOverrides({
  required Future<List<MediaBrowserItem>> Function() latest,
  required Future<List<MediaBrowserItem>> Function() resume,
  required Future<List<MediaBrowserItem>> Function() nextUp,
  required Future<MediaBrowserLibraryStats> Function() stats,
}) {
  return [
    serverConfigProvider.overrideWith(() => _ServerConfigState(_serverConfig)),
    mediaBrowserConfigProvider.overrideWithValue(MediaBrowserConfig.jellyfin),
    mediaBrowserServerUrlsProvider.overrideWith((ref) async => _serverUrls()),
    mediaBrowserViewsProvider.overrideWith(
      (ref) async => const <MediaBrowserItem>[],
    ),
    mediaBrowserLatestProvider.overrideWith((ref) => latest()),
    mediaBrowserResumeProvider.overrideWith((ref) => resume()),
    mediaBrowserNextUpProvider.overrideWith((ref) => nextUp()),
    mediaBrowserLibraryStatsProvider.overrideWith((ref) => stats()),
  ];
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<dynamic> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: List.from(overrides),
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: MediaBrowserHomePage(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('核心首页数据完成前不启动统计，完成后统计卡片独立加载', (tester) async {
    final latest = Completer<List<MediaBrowserItem>>();
    final resume = Completer<List<MediaBrowserItem>>();
    final nextUp = Completer<List<MediaBrowserItem>>();
    final stats = Completer<MediaBrowserLibraryStats>();
    var statsCalls = 0;

    await _pumpHome(
      tester,
      overrides: _baseOverrides(
        latest: () => latest.future,
        resume: () => resume.future,
        nextUp: () => nextUp.future,
        stats: () {
          statsCalls++;
          return stats.future;
        },
      ),
    );

    expect(statsCalls, 0);

    latest.complete(const []);
    resume.complete(const []);
    nextUp.complete(const []);
    await tester.pump();

    expect(find.text('最新入库'), findsOneWidget);
    expect(statsCalls, 1);

    stats.complete(
      const MediaBrowserLibraryStats(
        movieCount: 12,
        seriesCount: 34,
        episodeCount: 567,
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pump();
    expect(find.text('总电影'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('567'), findsOneWidget);
  });

  testWidgets('下拉刷新不等待未完成的统计请求', (tester) async {
    final latestRefresh = Completer<List<MediaBrowserItem>>();
    final resumeRefresh = Completer<List<MediaBrowserItem>>();
    final nextUpRefresh = Completer<List<MediaBrowserItem>>();
    final stats = Completer<MediaBrowserLibraryStats>();
    var latestCalls = 0;
    var resumeCalls = 0;
    var nextUpCalls = 0;
    var statsCalls = 0;

    await _pumpHome(
      tester,
      overrides: _baseOverrides(
        latest: () {
          latestCalls++;
          return latestCalls == 1
              ? Future.value(const <MediaBrowserItem>[])
              : latestRefresh.future;
        },
        resume: () {
          resumeCalls++;
          return resumeCalls == 1
              ? Future.value(const <MediaBrowserItem>[])
              : resumeRefresh.future;
        },
        nextUp: () {
          nextUpCalls++;
          return nextUpCalls == 1
              ? Future.value(const <MediaBrowserItem>[])
              : nextUpRefresh.future;
        },
        stats: () {
          statsCalls++;
          return stats.future;
        },
      ),
    );
    await tester.pump();
    expect(statsCalls, 1);

    final refreshFuture = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pump();

    latestRefresh.complete(const []);
    resumeRefresh.complete(const []);
    nextUpRefresh.complete(const []);
    await tester.pump();
    await tester.pumpAndSettle();

    await expectLater(refreshFuture, completes);
    // 统计在核心请求完成后才会重新发起；刷新 Future 不等待这次请求。
    expect(statsCalls, 2);
  });

  testWidgets('统计失败不影响首页，并可单独重试', (tester) async {
    final firstStats = Completer<MediaBrowserLibraryStats>();
    final retryStats = Completer<MediaBrowserLibraryStats>();
    var statsCalls = 0;

    await _pumpHome(
      tester,
      overrides: _baseOverrides(
        latest: () => Future.value(const <MediaBrowserItem>[]),
        resume: () => Future.value(const <MediaBrowserItem>[]),
        nextUp: () => Future.value(const <MediaBrowserItem>[]),
        stats: () {
          statsCalls++;
          return statsCalls == 1 ? firstStats.future : retryStats.future;
        },
      ),
    );
    await tester.pump();
    expect(statsCalls, 1);

    firstStats.completeError(StateError('stats unavailable'));
    await tester.pump();
    await tester.pump();
    expect(find.text('统计加载失败'), findsOneWidget);
    expect(find.text('最新入库'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(statsCalls, 2);

    retryStats.complete(
      const MediaBrowserLibraryStats(
        movieCount: 1,
        seriesCount: 2,
        episodeCount: 3,
      ),
    );
    await tester.pump();
    expect(find.text('统计加载失败'), findsNothing);
  });
}
