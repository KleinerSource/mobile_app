import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:md_center/core/api/api_client.dart';
import 'package:md_center/core/api/providers.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/features/search/search_page.dart';
import 'package:md_center/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('切换搜索词时旧请求不会覆盖新结果或留下加载状态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final query = options.queryParameters['search']?.toString() ?? '';
          if (query == '旧') {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
          final item = query == '新'
              ? {'id': 2, 'title': '新结果'}
              : {'id': 1, 'title': '旧结果'};
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'items': [item],
                  'total_count': 1,
                  'limit': 60,
                  'offset': 0,
                },
              },
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: SearchPage()),
        ),
      ),
    );

    final field = find.byType(TextField);
    await tester.enterText(field, '旧');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(field, '新');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('新结果'), findsWidgets);
    expect(find.text('旧结果'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('新结果'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
