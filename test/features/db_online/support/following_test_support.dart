import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo_media_source_adapter.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

class FollowingTestBackend {
  final requests = <RequestOptions>[];
  bool database = true;
  bool onlineQuery = true;
  bool onlineAccount = true;
  bool subscribed = false;
  int refreshFailed = 0;
  FutureOr<Object?> Function(RequestOptions request)? respond;
  final presets = <Map<String, dynamic>>[];
  final users = <Map<String, dynamic>>[];

  Dio dio(String baseUrl) {
    final dio = Dio(BaseOptions(baseUrl: '$baseUrl/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          requests.add(request);
          final custom = respond == null ? null : await respond!(request);
          final data = custom ?? response(request);
          handler.resolve(
            Response<dynamic>(requestOptions: request, data: data),
          );
        },
      ),
    );
    return dio;
  }

  Object response(RequestOptions request) {
    final body = request.data is Map
        ? Map<String, dynamic>.from(request.data as Map)
        : <String, dynamic>{};
    Object? data;
    switch (request.path) {
      case '/health':
        data = {
          'capabilities': {
            'database': database,
            'online_query': onlineQuery,
            'online_account': onlineAccount,
          },
        };
      case '/options/categories':
        data = [
          {'external_id': '1', 'name': '风格一'},
          {'external_id': '2', 'name': '风格二'},
        ];
      case '/following/presets':
        if (request.method == 'POST') {
          final item = {'id': presets.length + 1, ...body};
          presets.add(item);
          data = item;
        } else {
          data = List.of(presets);
        }
      case '/following/presets/reorder':
        final ids = (body['ids'] as List).cast<int>();
        presets.sort(
          (a, b) => ids.indexOf(a['id']).compareTo(ids.indexOf(b['id'])),
        );
        data = {};
      case '/following/users':
        if (request.method == 'POST') {
          final id = body['user_id'];
          final exists = users.any((item) => item['user_id'] == id);
          final item = {'user_id': id, 'username': '用户$id'};
          if (!exists) users.add(item);
          data = {...item, 'created': !exists};
        } else if (request.method == 'DELETE') {
          users.removeWhere(
            (item) => (body['user_ids'] as List).contains(item['user_id']),
          );
          data = {};
        } else {
          data = List.of(users);
        }
      case '/following/users/refresh':
        data = {'users': users.reversed.toList(), 'failed': refreshFailed};
      case '/subs/status':
        final ids = body['external_ids'] ?? body['codes'] ?? <String>[];
        data = {for (final id in ids as List) id.toString(): subscribed};
      case '/series-subs':
        if (request.method == 'POST') subscribed = true;
        data = {};
      case '/downloaders':
        data = {
          'downloaders': [
            {'name': 'test', 'display_name': '测试下载器', 'ed2k_enabled': true},
          ],
        };
      case '/subs/tags':
        data = {
          'movies': [
            {
              'id': 'film',
              'number': 'ABC-001',
              'title': '关注影片',
              'has_cnsub': true,
              'magnets_count': 2,
              'can_play': true,
            },
          ],
          'has_more': false,
        };
      default:
        if (request.path.startsWith('/following/presets/')) {
          final id = int.parse(request.path.split('/').last);
          if (request.method == 'DELETE') {
            presets.removeWhere((item) => item['id'] == id);
            data = {};
          } else {
            final index = presets.indexWhere((item) => item['id'] == id);
            presets[index] = {'id': id, ...body};
            data = presets[index];
          }
        } else if (request.path.startsWith('/series-subs/')) {
          if (request.method == 'DELETE') subscribed = false;
          data = {
            'external_id': request.path.split('/').last,
            'series_name': '风格一',
            'sub_type': 'follow',
            'active': true,
          };
        } else if (request.path.endsWith('/download-history')) {
          data = {'magnets': {}, 'ed2ks': {}};
        } else {
          data = {};
        }
    }
    return {'success': true, 'data': data};
  }

  List<RequestOptions> to(String path) =>
      requests.where((item) => item.path == path).toList();
}

ServerConfig followingTestConfig(String id) {
  final servers = [
    for (final value in ['a', 'b'])
      ServerProfile(
        id: value,
        name: value,
        lines: [
          ServerLine(
            id: '$value-line',
            name: '主线路',
            baseUrl: 'https://$value.test',
          ),
        ],
        activeLineId: '$value-line',
        projectName: 'db_online',
      ),
  ];
  return ServerConfig(
    baseUrl: 'https://$id.test',
    servers: servers,
    lines: servers.firstWhere((server) => server.id == id).lines,
    activeServerId: id,
  );
}

class FollowingTestServerState extends ServerConfigNotifier {
  @override
  ServerConfig build() => followingTestConfig('a');
  void select(String id) {
    state = followingTestConfig(id);
    ref
        .read(serverRuntimeProvider.notifier)
        .commit(ServerRuntimeLane.media, id);
  }
}

class _FollowingRuntimeState extends ServerRuntimeController {
  @override
  ServerRuntimeState build() => const ServerRuntimeState(
    media: ServerRuntimeSlotState(
      serverId: 'a',
      phase: ServerRuntimePhase.ready,
    ),
    visibleLane: ServerRuntimeLane.media,
  );
}

class _PrivacyState extends PrivacyShieldNotifier {
  @override
  bool build() => false;
}

Future<ProviderContainer> pumpFollowingTest(
  WidgetTester tester,
  FollowingTestBackend backend,
  Widget page, {
  Duration? Function(int, Object)? retry,
  Locale locale = const Locale('zh'),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: retry,
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverConfigProvider.overrideWith(FollowingTestServerState.new),
        serverRuntimeProvider.overrideWith(_FollowingRuntimeState.new),
        privacyShieldProvider.overrideWith(_PrivacyState.new),
        requiredApiClientProvider.overrideWith((ref) {
          final config = ref.watch(mediaRuntimeConfigProvider)!;
          final dio = backend.dio(config.baseUrl);
          ref.onDispose(dio.close);
          return ApiClient(dio, config: config);
        }),
        dboMediaRepositoryProvider.overrideWith(
          (ref) => DboMediaRepository(
            DboMediaSourceAdapter(
              ref.watch(requiredApiClientProvider).dbOnline,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: page,
      ),
    ),
  );
  await pumpFollowingFrames(tester);
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> pumpFollowingFrames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Map<String, dynamic> followingReview(
  int id,
  String title, {
  String resourceName = '评论磁链',
  String hash = 'ABCDEF',
}) => {
  'review_id': id,
  'created_at': '2026-10-01T01:02:00Z',
  'movie': {'id': '$id', 'number': 'ABC-00$id', 'title': title},
  'magnets': [
    {'magnet': 'magnet:?xt=urn:btih:$hash', 'name': resourceName},
  ],
  'ed2ks': [],
};
