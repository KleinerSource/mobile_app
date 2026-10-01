import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo_media_source_adapter.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/features/db_online/widgets/db_online_resource_sheets.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  const magnetUrl = 'magnet:?xt=urn:btih:0123456789abcdef';
  const ed2kUrl = 'ed2k://|file|ABC-001.mp4|1024|0123456789abcdef|/';
  const actors = [
    DbOnlinePerson(externalId: 'actor-1', name: '演员甲', gender: '♀'),
    DbOnlinePerson(name: '演员乙'),
  ];

  Future<_DownloadAdapter> pumpResources(
    WidgetTester tester, {
    List<DbOnlinePerson> movieActors = actors,
  }) async {
    final adapter = _DownloadAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(DbOnlineApi(dio))),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: DbOnlineResourcesSheet(
              movie: DbOnlineMovieDetail(
                code: ' ABC-001 ',
                title: ' 示例影片 ',
                date: ' 2026-10-01 ',
                actors: movieActors,
                magnets: const [
                  DbOnlineMagnet(name: '磁链资源', magnet: magnetUrl),
                ],
                ed2ks: const [DbOnlineEd2k(name: 'ED2K 资源', ed2k: ed2kUrl)],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return adapter;
  }

  for (final protocol in ['magnet', 'ed2k']) {
    testWidgets('$protocol 推送下载器时演员序列化为对象数组', (tester) async {
      final adapter = await pumpResources(tester);
      if (protocol == 'ed2k') {
        await tester.tap(find.text('ED2K (1)'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip('推送下载'));
      await tester.pumpAndSettle();

      final request = adapter.downloadRequests.single;
      expect(request['downloader'], 'test-downloader');
      expect(request['urls'], [protocol == 'magnet' ? magnetUrl : ed2kUrl]);
      expect(request['video_info'], {
        'code': 'ABC-001',
        'title': '示例影片',
        'date': '2026-10-01',
        'actors': [
          {'external_id': 'actor-1', 'name': '演员甲', 'gender': '♀'},
          {'name': '演员乙', 'gender': ''},
        ],
      });
      expect(
        (request['record_resources'] as List).single['resource_protocol'],
        protocol,
      );
      expect(find.text('下载任务已添加'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('无演员信息时仍可推送下载器', (tester) async {
    final adapter = await pumpResources(tester, movieActors: const []);

    await tester.tap(find.byTooltip('推送下载'));
    await tester.pumpAndSettle();

    final videoInfo = adapter.downloadRequests.single['video_info'] as Map;
    expect(videoInfo['actors'], isEmpty);
    expect(find.text('下载任务已添加'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DownloadAdapter implements HttpClientAdapter {
  final downloadRequests = <Map<String, dynamic>>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.uri.path) {
      '/api/downloaders' => {
        'downloaders': [
          {
            'name': 'test-downloader',
            'display_name': '测试下载器',
            'ed2k_enabled': true,
          },
        ],
      },
      '/api/video/ABC-001/download-history' => {'magnets': {}, 'ed2ks': {}},
      _ => {'magnets': [], 'ed2ks': []},
    };
    final downloading = options.uri.path == '/api/download';
    if (downloading) {
      final bytes = await requestStream!.expand((chunk) => chunk).toList();
      downloadRequests.add(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        if (downloading) 'message': '下载任务已添加',
        'data': downloading ? {'downloader': 'test-downloader'} : data,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
