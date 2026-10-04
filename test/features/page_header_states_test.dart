import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/avdb_config.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/features/oh_my_media/configs/configs_providers.dart';
import 'package:omm/features/oh_my_media/configs/avdb_settings_page.dart';
import 'package:omm/features/oh_my_media/configs/dbo_settings_page.dart';
import 'package:omm/features/oh_my_media/configs/ffmpeg_settings_page.dart';
import 'package:omm/features/oh_my_media/configs/preview_settings_page.dart';
import 'package:omm/features/security/security_providers.dart';
import 'package:omm/features/security/security_repository.dart';
import 'package:omm/features/security/security_settings_page.dart';
import 'package:omm/features/settings/access_control_page.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/translation/translation_providers.dart';
import 'package:omm/features/translation/translation_settings_page.dart';
import 'package:omm/features/translation/modal_transcription_providers.dart';
import 'package:omm/features/translation/modal_transcription_settings_page.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/media_browser/pages/media_browser_movie_detail_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_album_detail_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_series_detail_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_collection_detail_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_detail_scaffold.dart';

class _PendingSecurity extends SecurityController {
  _PendingSecurity(this.ready);
  final Future<void> ready;
  @override
  Future<SecuritySettings> build() async {
    await ready;
    throw StateError('测试请求失败');
  }
}

Future<Never> _failure(Future<void> ready) async {
  await ready;
  throw StateError('测试请求失败');
}

ApiClient _pendingClient(Future<void> ready) {
  final dio = Dio(BaseOptions(baseUrl: 'https://headers.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        await ready;
        handler.reject(DioException(requestOptions: options, error: '测试请求失败'));
      },
    ),
  );
  return ApiClient(dio);
}

Future<void> _openPage(
  WidgetTester tester,
  Widget page,
  List<Override> overrides,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs), ...overrides],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('根页面'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        child: const Text('上一页'),
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => page)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('根页面'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('上一页'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _checkReturn(WidgetTester tester) async {
  expect(find.byTooltip('返回').hitTestable(), findsOneWidget);
  await tester.tap(find.byTooltip('返回'));
  await tester.pumpAndSettle();
  expect(find.text('上一页'), findsOneWidget);
  expect(find.text('根页面'), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  final settings = <(Widget, Override Function(Future<void>))>[
    (
      const AvdbSettingsPage(),
      (ready) => avdbConfigProvider.overrideWith((ref) => _failure(ready)),
    ),
    (
      const DboSettingsPage(),
      (ready) => dboConfigProvider.overrideWith((ref) => _failure(ready)),
    ),
    (
      const FfmpegSettingsPage(),
      (ready) => ffmpegConfigProvider.overrideWith((ref) => _failure(ready)),
    ),
    (
      const PreviewSettingsPage(),
      (ready) => previewConfigProvider.overrideWith((ref) => _failure(ready)),
    ),
    (
      const TranslationSettingsPage(),
      (ready) =>
          translationConfigProvider.overrideWith((ref) => _failure(ready)),
    ),
    (
      const ModalTranscriptionSettingsPage(),
      (ready) => modalTranscriptionConfigProvider.overrideWith(
        (ref) => _failure(ready),
      ),
    ),
    (
      const SecuritySettingsPage(),
      (ready) => securityControllerProvider.overrideWith(
        () => _PendingSecurity(ready),
      ),
    ),
    (
      const AccessControlPage(),
      (ready) =>
          requiredApiClientProvider.overrideWithValue(_pendingClient(ready)),
    ),
  ];
  for (final entry in settings) {
    for (final failed in [false, true]) {
      testWidgets(
        entry.$1.runtimeType.toString() + (failed ? ' 失败时可返回' : ' 加载时可返回'),
        (tester) async {
          final ready = Completer<void>();
          await _openPage(tester, entry.$1, [entry.$2(ready.future)]);
          if (failed) {
            ready.complete();
            await tester.pumpAndSettle();
            expect(find.byType(CircularProgressIndicator), findsNothing);
          }
          expect(find.byType(SettingsSubPageHeader), findsOneWidget);
          await _checkReturn(tester);
          if (!ready.isCompleted) ready.complete();
          await tester.pump();
        },
      );
    }
  }

  for (final page in [
    const MovieDetailPage(movieId: 1, acknowledgeNewResources: false),
    const DbOnlineMovieDetailPage(detailKey: 'HEADER-001'),
    const MediaBrowserMovieDetailPage(itemId: '1'),
    const MediaBrowserAlbumDetailPage(albumId: '1'),
    const MediaBrowserSeriesDetailPage(seriesId: '1'),
    const MediaBrowserCollectionDetailPage(collectionId: '1'),
  ]) {
    for (final failed in [false, true]) {
      testWidgets(
        page.runtimeType.toString() + (failed ? ' 失败时有标题和返回' : ' 加载时有标题和返回'),
        (tester) async {
          final ready = Completer<void>();
          await _openPage(tester, page, [
            movieDetailProvider.overrideWith(
              (ref, id) => _failure(ready.future),
            ),
            dbOnlineMovieDetailProvider.overrideWith((ref, request) async* {
              await ready.future;
              yield* Stream.error(StateError('测试请求失败'));
            }),
            mediaBrowserItemDetailProvider.overrideWith(
              (ref, request) => _failure(ready.future),
            ),
            mediaBrowserSimilarProvider.overrideWith(
              (ref, request) async => [],
            ),
          ]);
          if (failed) {
            ready.complete();
            await tester.pumpAndSettle();
            expect(find.byType(CircularProgressIndicator), findsNothing);
          }
          expect(find.byType(MovieDetailNavigationBar), findsOneWidget);
          final bar = tester.widget<MovieDetailNavigationBar>(
            find.byType(MovieDetailNavigationBar),
          );
          expect(bar.title, isNotEmpty);
          await _checkReturn(tester);
          if (!ready.isCompleted) ready.complete();
          await tester.pump();
        },
      );
    }
  }

  testWidgets('配置加载成功后仅保留一个抬头，返回位置不变', (tester) async {
    final config = Completer<AvdbConfig>();
    await _openPage(tester, const AvdbSettingsPage(), [
      avdbConfigProvider.overrideWith((ref) => config.future),
    ]);
    final before = tester.getRect(find.byTooltip('返回'));
    config.complete(const AvdbConfig());
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSubPageHeader), findsOneWidget);
    expect(tester.getRect(find.byTooltip('返回')), before);
    await _checkReturn(tester);
  });

  for (final page in [
    const MovieDetailPage(movieId: 1, acknowledgeNewResources: false),
    const DbOnlineMovieDetailPage(detailKey: 'HEADER-001'),
    const MediaBrowserMovieDetailPage(itemId: '1'),
    const MediaBrowserAlbumDetailPage(albumId: '1'),
    const MediaBrowserSeriesDetailPage(seriesId: '1'),
    const MediaBrowserCollectionDetailPage(collectionId: '1'),
  ]) {
    testWidgets('$page 从失败到重试加载及成功均保留导航抬头', (tester) async {
      final first = Completer<void>();
      final second = Completer<void>();
      var requests = 0;
      Future<void> load() async {
        if (requests++ == 0) {
          await first.future;
          throw StateError('测试请求失败');
        }
        await second.future;
      }

      await _openPage(tester, page, [
        movieDetailProvider.overrideWith((ref, id) async {
          await load();
          return MovieDetail(id: id, title: '成功后的详情标题');
        }),
        extraFanartsProvider.overrideWith((ref, id) async => []),
        dbOnlineMovieDetailProvider.overrideWith((ref, request) async* {
          await load();
          yield const DbOnlineMovieDetail(
            code: 'HEADER-001',
            title: '成功后的详情标题',
          );
        }),
        mediaBrowserItemDetailProvider.overrideWith((ref, request) async {
          await load();
          return const MediaBrowserItem(
            id: '1',
            name: '成功后的详情标题',
            type: 'Movie',
          );
        }),
        mediaBrowserSimilarProvider.overrideWith((ref, request) async => []),
        mediaBrowserSeasonsProvider.overrideWith((ref, request) async => []),
        mediaBrowserEpisodesProvider.overrideWith(
          (ref, request) async => const MediaBrowserItemPage(
            items: [],
            total: 0,
            startIndex: 0,
            limit: 24,
          ),
        ),
        mediaBrowserAlbumTracksProvider.overrideWith(
          (ref, request) async => [],
        ),
      ]);
      final before = tester.getRect(find.byTooltip('返回'));
      first.complete();
      await tester.pumpAndSettle();
      expect(find.byType(MovieDetailNavigationBar), findsOneWidget);
      expect(tester.getRect(find.byTooltip('返回')), before);
      if (page is MovieDetailPage) {
        ProviderScope.containerOf(
          tester.element(find.byType(MovieDetailPage)),
        ).invalidate(movieDetailProvider(1));
      } else {
        await tester.tap(find.widgetWithText(FilledButton, '重试'));
      }
      await tester.pump();
      expect(find.byType(MovieDetailNavigationBar), findsOneWidget);
      expect(requests, 2);
      expect(tester.getRect(find.byTooltip('返回')), before);
      second.complete();
      await tester.pumpAndSettle();
      expect(find.byType(MovieDetailNavigationBar), findsOneWidget);
      final navigation = find.byType(MovieDetailNavigationBar);
      final isMovie =
          page is MovieDetailPage ||
          page is DbOnlineMovieDetailPage ||
          page is MediaBrowserMovieDetailPage;
      expect(
        tester.widget<MovieDetailNavigationBar>(navigation).title,
        isMovie ? isNull : '成功后的详情标题',
      );
      if (isMovie) {
        expect(
          find.descendant(
            of: navigation,
            matching: find.textContaining('成功后的详情标题', findRichText: true),
          ),
          findsNothing,
        );
        expect(
          find.textContaining('成功后的详情标题', findRichText: true),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: navigation,
            matching: find.byType(HeaderActionButton),
          ),
          findsWidgets,
        );
      }
      expect(tester.getRect(find.byTooltip('返回')), before);
      expect(requests, 2);
      await _checkReturn(tester);
    });
  }
}
