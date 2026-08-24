import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/api_client.dart';
import 'package:md_center/core/api/providers.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/core/models/actor.dart';
import 'package:md_center/core/models/avdb_config.dart';
import 'package:md_center/core/models/dbo_config.dart';
import 'package:md_center/features/configs/configs_providers.dart';
import 'package:md_center/features/movies/movies_providers.dart';
import 'package:md_center/features/person_detail/person_detail_page.dart';
import 'package:md_center/l10n/generated/app_localizations.dart';
import 'package:md_center/shared/actor_detail_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('同步演员关联后重新拉取演员头像数组刷新封面', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(_buildFakeClient()),
          sharedPrefsProvider.overrideWithValue(prefs),
          imageUrlBuilderProvider.overrideWithValue((uuid) => ''),
          dboConfigProvider.overrideWith(
            (ref) async => const DboConfig(
              enabled: true,
              baseUrl: 'https://dbo.example',
              apiKey: 'dbo-key',
            ),
          ),
          avdbConfigProvider.overrideWith(
            (ref) async =>
                const AvdbConfig(enabled: false, baseUrl: '', apiKey: ''),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: PersonDetailPage(
            actor: ActorItem(
              id: 7,
              name: '演员 10',
              // 同步前: 明确无头像,封面不应发起任何头像请求
              avatarPaths: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    ActorHeroHeader heroHeader() =>
        tester.widget<ActorHeroHeader>(find.byType(ActorHeroHeader));
    expect(heroHeader().avatarPaths, isEmpty);
    expect(heroHeader().cacheBust, isNull);

    await tester.tap(find.byTooltip('同步演员关联'));
    await tester.pumpAndSettle();
    // 预览返回 1 张头像候选,默认选中后可提交
    await tester.tap(find.widgetWithText(FilledButton, '确认添加'));
    await tester.pumpAndSettle();

    // 应用成功返回后页面重新拉取演员详情:
    // 头像数组从空更新为后端最新值,并换新缓存版本强制封面重载
    expect(heroHeader().avatarPaths, hasLength(2));
    expect(heroHeader().cacheBust, isNotNull);
    // 作品集同步刷新不受影响
    expect(find.byType(PersonDetailPage), findsOneWidget);
  });
}

ApiClient _buildFakeClient() {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final data = _fakeResponse(options.method, options.uri.path);
        if (data == null) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: '未处理的测试请求: ${options.method} ${options.uri.path}',
            ),
          );
          return;
        }
        handler.resolve(Response<dynamic>(requestOptions: options, data: data));
      },
    ),
  );
  return ApiClient(dio);
}

Object? _fakeResponse(String method, String path) {
  final normalizedPath = path.startsWith('/api') ? path.substring(4) : path;

  if (method == 'GET' && normalizedPath == '/actors/7') {
    return {
      'success': true,
      'data': {
        'id': 7,
        'name': '演员 10',
        // 同步下载后后端写入的两张头像
        'avatar_path': ['people/10/a.jpg', 'people/10/b.jpg'],
        'movie_count': 1,
      },
    };
  }

  if (method == 'GET' && normalizedPath == '/movies') {
    return {
      'success': true,
      'data': {
        'items': [
          {'id': 101, 'title': '影片 1', 'year': 2024},
        ],
        'total_count': 1,
        'limit': 30,
        'offset': 0,
      },
    };
  }

  if (method == 'POST' &&
      normalizedPath == '/mappings/actors/external-sync/preview') {
    return {
      'success': true,
      'data': {
        'found': true,
        'mapped_value': '演员 10',
        'actor_name': '演员 10',
        'all_aliases': const [],
        'existing_aliases': const [],
        'new_aliases': const [],
        'biography': '',
        'avatar_url': 'https://dbo.example/avatar/1.jpg',
        'avatar_exists': false,
        'avatar_choices': [
          {
            'download_url': 'https://dbo.example/avatar/1.jpg',
            'source_url': 'https://dbo.example/avatar/1.jpg',
            'source': 'dbonline',
          },
        ],
      },
    };
  }

  if (method == 'POST' && normalizedPath == '/actors/avatar/preview') {
    // 1x1 透明 PNG · sheet 内 Image.memory 需要可解码的图片字节
    return const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
  }

  if (method == 'POST' &&
      normalizedPath == '/mappings/actors/external-sync/apply') {
    return {'success': true, 'data': null};
  }

  return null;
}
