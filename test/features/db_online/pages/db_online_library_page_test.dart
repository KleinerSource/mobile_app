import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/dbo_media_source_adapter.dart';
import 'package:omm/features/db_online/pages/db_online_library_page.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  testWidgets('影片库分类和排序会使用对应的 tags 请求参数', (tester) async {
    const config = ServerConfig(baseUrl: 'https://example.test');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final requests = <Map<String, String>>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
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
                  'movies': [
                    {
                      'id': 'movie-1',
                      'number': 'ABC-001',
                      'title': '影片库测试影片',
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
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(client.dbOnline)),
          ),
          sharedPrefsProvider.overrideWithValue(prefs),
          serverConfigProvider.overrideWith(() => _ServerConfigState(config)),
          privacyShieldProvider.overrideWith(_PrivacyState.new),
        ],
        child: const MaterialApp(home: Scaffold(body: DbOnlineLibraryPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, isNotEmpty);
    expect(requests.last['filter_by'], '0:t:p::::');
    expect(requests.last['sort_by'], 'update');
    expect(requests.last['order_by'], 'desc');
    expect(find.text('最近更新'), findsNothing);
    expect(find.text('筛选'), findsNothing);

    const categories = [('无码', '1'), ('欧美', '2'), ('FC2', '3'), ('动漫', '4')];
    for (final (label, value) in categories) {
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(requests.last['filter_by'], '$value:t:p::::');
    }

    await tester.tap(find.byIcon(Icons.sort_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最新上架'));
    await tester.pumpAndSettle();
    expect(requests.last['sort_by'], 'release');
    expect(requests.last['order_by'], 'desc');

    await tester.tap(find.byIcon(Icons.sort_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('降序'));
    await tester.pumpAndSettle();
    expect(requests.last['sort_by'], 'release');
    expect(requests.last['order_by'], 'asc');
  });
}
