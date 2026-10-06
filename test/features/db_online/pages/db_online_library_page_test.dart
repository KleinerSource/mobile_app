import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/pages/db_online_library_page.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/db_online/widgets/db_online_ranking_preview_card.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/shared/media_list_layout.dart';

class _PrivacyState extends PrivacyShieldNotifier {
  @override
  bool build() => false;
}

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

void main() {
  testWidgets('本地影片库使用 videos 接口并传递资源、评分和排序参数', (tester) async {
    const config = ServerConfig(baseUrl: 'https://example.test');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final requests = <Map<String, String>>[];
    final requestPaths = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestPaths.add(options.path);
          requests.add(
            options.queryParameters.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          );
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'videos': [
                    {
                      'id': 'movie-1',
                      'number': 'ABC-001',
                      'title': '影片库测试影片',
                      'score': 4.5,
                      'can_play': true,
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final client = ApiClient(dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          sharedPrefsProvider.overrideWithValue(prefs),
          serverConfigProvider.overrideWith(() => _ServerConfigState(config)),
          privacyShieldProvider.overrideWith(_PrivacyState.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: DbOnlineLibraryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DB ONLINE'), findsOneWidget);
    expect(find.text('DBONLINE'), findsNothing);
    expect(requests, isNotEmpty);
    expect(requests.last, {
      'page': '1',
      'pageSize': '24',
      'sort': 'created',
      'order': 'desc',
    });
    expect(find.text('影片库测试影片'), findsOneWidget);
    expect(find.text('4.5'), findsNothing);
    expect(find.text('最近更新'), findsNothing);
    expect(find.text('筛选'), findsNothing);

    const resources = [
      ('全部', ''),
      ('有磁链', 'm'),
      ('字幕', 'c'),
      ('无资源', 'n'),
      ('已入库', 'l'),
    ];
    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();
    for (final (label, value) in resources) {
      await tester.ensureVisible(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(requests.last['filter'], value.isEmpty ? isNull : value);
      expect(requests.last.containsKey('user_score'), isFalse);
    }

    const scores = [
      ('5 星', '5'),
      ('4 星', '4'),
      ('3 星', '3'),
      ('2 星', '2'),
      ('1 星', '1'),
      ('无评分', '-1'),
    ];
    for (final (label, value) in scores) {
      await tester.ensureVisible(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(requests.last['user_score'], value);
      expect(requests.last['filter'], 'l');
    }

    const communityScores = [
      ('5 星', '5'),
      ('4 星', '4'),
      ('3 星', '3'),
      ('2 星', '2'),
      ('1 星', '1'),
    ];
    for (final (label, value) in communityScores) {
      await tester.ensureVisible(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(requests.last['min_score'], value);
      expect(requests.last['user_score'], '-1');
      expect(requests.last['filter'], 'l');
    }

    Navigator.of(tester.element(find.text('资源类型').first)).pop();
    await tester.pumpAndSettle();

    // 排序并入统一筛选弹层：点击未选字段以升序选中，点击已选字段切换方向。
    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();
    const sorts = [('发布日期', 'date'), ('更新时间', 'updated'), ('入库时间', 'created')];
    for (final (label, value) in sorts) {
      await tester.ensureVisible(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(requests.last['sort'], value);
      expect(requests.last['order'], 'asc');
      expect(requests.last['filter'], 'l');
      expect(requests.last['user_score'], '-1');
      expect(requests.last['min_score'], '1');
    }

    // 再次点击已选中的「入库时间」切换为降序。
    await tester.ensureVisible(find.text('入库时间').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('入库时间').first);
    await tester.pumpAndSettle();
    expect(requests.last['sort'], 'created');
    expect(requests.last['order'], 'desc');
    Navigator.of(tester.element(find.text('排序').first)).pop();
    await tester.pumpAndSettle();
    expect(requestPaths, everyElement('/videos'));

    for (final icon in [
      Icons.crop_landscape_rounded,
      Icons.view_list_rounded,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(DbOnlineMovieCard));
      final page = tester.getRect(find.byType(DbOnlineLibraryPage));
      expect(card.left - page.left, 22);
      if (icon == Icons.crop_landscape_rounded) {
        expect(
          card.width,
          closeTo(
            MediaListLayout.landscapeCardWidthForWidth(
              page.width - MediaListLayout.padding.horizontal,
            ),
            0.001,
          ),
        );
      } else {
        expect(page.right - card.right, 22);
      }
      if (icon == Icons.view_list_rounded) {
        // 列表模式渲染预览条目：左侧 92px 竖版封面 + 右侧预览/回退大图。
        expect(find.byType(DbOnlineRankingPreviewCard), findsOneWidget);
        final cover = tester.getSize(
          find
              .descendant(
                of: find.byType(DbOnlineRankingPreviewCard),
                matching: find.byType(Poster),
              )
              .first,
        );
        expect(cover, const Size(92, 138));
      }
      expect(tester.takeException(), isNull);
    }
  });
}
