import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/avdb_config.dart';
import 'package:omm/core/models/dbo_config.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/features/oh_my_media/actors/actor_management_page.dart';
import 'package:omm/features/oh_my_media/configs/configs_providers.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/person_detail/person_detail_page.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('同步演员关联返回演员管理后保持原始滚动位置', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final client = _buildFakeClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          ommMediaSourceProvider.overrideWithValue(
            OmmMediaSourceAdapter(client),
          ),
          sharedPrefsProvider.overrideWithValue(prefs),
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
          privacyShieldProvider.overrideWith(
            _DisabledPrivacyShieldNotifier.new,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: ActorManagementPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final listFinder = find.byType(CustomScrollView);
    expect(listFinder, findsOneWidget);
    await tester.drag(listFinder, const Offset(0, -900));
    await tester.pumpAndSettle();

    final visibleActor = find.byWidgetPredicate(
      (widget) =>
          widget is Text && RegExp(r'^演员 \d+$').hasMatch(widget.data ?? ''),
    );
    expect(visibleActor, findsWidgets);
    await tester.ensureVisible(visibleActor.first);
    await tester.pumpAndSettle();

    final before = _scrollOffset(tester, listFinder);
    expect(before, greaterThan(0));
    await tester.tap(visibleActor.first);
    await tester.pumpAndSettle();
    expect(find.byType(PersonDetailPage), findsOneWidget);

    final filmographyMovie = find.byType(MovieCard);
    expect(filmographyMovie, findsOneWidget);
    await tester.tap(filmographyMovie);
    await tester.pumpAndSettle();
    expect(find.byType(MovieDetailPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(MovieDetailPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(PersonDetailPage), findsOneWidget);

    await tester.tap(find.byTooltip('同步演员关联'));
    await tester.pumpAndSettle();
    expect(find.text('演员别名'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '确认添加'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(PersonDetailPage), findsNothing);
    final after = _scrollOffset(tester, listFinder);
    expect(after, closeTo(before, 1));
  });
}

double _scrollOffset(WidgetTester tester, Finder finder) {
  return tester.widget<CustomScrollView>(finder).controller!.offset;
}

ApiClient _buildFakeClient() {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.uri.path;
        final data = _fakeResponse(options.method, path);
        if (data == null) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: '未处理的测试请求: ${options.method} $path',
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

  if (method == 'GET' && normalizedPath == '/actors') {
    final actors = [
      for (var i = 1; i <= 100; i++)
        {'id': i, 'name': '演员 $i', 'movie_count': i},
    ];
    return {
      'success': true,
      'data': actors,
      'total_count': actors.length,
      'limit': 100,
      'offset': 0,
    };
  }

  if (method == 'GET' && normalizedPath == '/movies') {
    return {
      'success': true,
      'data': {
        'items': const [
          {'id': 101, 'title': '影片 1', 'year': 2024},
        ],
        'total_count': 1,
        'limit': 60,
        'offset': 0,
      },
    };
  }

  if (method == 'GET' && normalizedPath == '/movies/id/101') {
    return {
      'success': true,
      'data': const {'id': 101, 'title': '影片 1', 'year': 2024},
    };
  }

  if (method == 'GET' && normalizedPath == '/movies/id/101/media-info') {
    return {'success': true, 'data': const <String, dynamic>{}};
  }

  if (method == 'POST' &&
      normalizedPath == '/mappings/actors/external-sync/preview') {
    return {
      'success': true,
      'data': {
        'found': true,
        'mapped_value': '演员 10',
        'actor_name': '演员 10',
        'all_aliases': ['演员别名'],
        'existing_aliases': const [],
        'new_aliases': ['演员别名'],
        'biography': '',
        'avatar_url': '',
        'avatar_exists': false,
      },
    };
  }

  if (method == 'POST' &&
      normalizedPath == '/mappings/actors/external-sync/apply') {
    return {'success': true, 'data': null};
  }

  if (method == 'GET' && normalizedPath == '/mappings/type/actors') {
    return {
      'success': true,
      'data': const [],
      'total_count': 0,
      'limit': 100,
      'offset': 0,
    };
  }

  return null;
}

class _DisabledPrivacyShieldNotifier extends PrivacyShieldNotifier {
  @override
  bool build() => false;
}
