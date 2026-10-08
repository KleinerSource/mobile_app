import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/core/sources/media/dbo_media_source_adapter.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/features/db_online/widgets/db_online_resource_sheets.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/resource_panel_components.dart';

const _localPath = '/api/subtitle/find/ABC-001';
const _thunderPath = '/api/subtitle/external/search/ABC-001';

void main() {
  for (final local in [false, true]) {
    for (final thunder in [false, true]) {
      testWidgets('字幕组合 $local / $thunder 仅双类型显示 tabs', (tester) async {
        final adapter = _SubtitleAdapter(local: local, thunder: thunder);
        await _pumpSheet(tester, adapter);

        expect(
          find.byType(ResourcePanelTabButton),
          local && thunder ? findsNWidgets(2) : findsNothing,
        );
        if (local) {
          expect(find.text('本地.srt'), findsOneWidget);
          if (thunder) {
            await tester.tap(find.text('迅雷字幕（1）'));
            await tester.pumpAndSettle();
            expect(find.text('迅雷.srt'), findsOneWidget);
            await tester.drag(find.byType(ListView), const Offset(250, 0));
            await tester.pumpAndSettle();
            expect(find.text('本地.srt'), findsOneWidget);
          }
        } else if (thunder) {
          expect(find.text('迅雷.srt'), findsOneWidget);
          await tester.drag(find.byType(ListView), const Offset(250, 0));
          await tester.pumpAndSettle();
          expect(find.text('迅雷.srt'), findsOneWidget);
        } else {
          expect(find.text('没有找到匹配的字幕'), findsOneWidget);
          expect(find.byIcon(Icons.subtitles_off), findsOneWidget);
          expect(find.byIcon(Icons.error_outline), findsNothing);
          expect(find.text('0'), findsNothing);
          expect(find.text('重试'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final pendingPath in [_localPath, _thunderPath]) {
    testWidgets('$pendingPath 未完成时不提前显示无字幕', (tester) async {
      final pending = Completer<void>();
      final adapter = _SubtitleAdapter(local: false, thunder: false)
        ..pending[pendingPath] = pending;
      await _pumpSheet(tester, adapter, settle: false);

      expect(find.byType(ResourcePanelTabButton), findsNothing);
      expect(find.text('没有找到匹配的字幕'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();

      expect(find.text('没有找到匹配的字幕'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('刷新重新查询隐藏类型并更新 tabs 和默认内容', (tester) async {
    final adapter = _SubtitleAdapter(local: true, thunder: true);
    await _pumpSheet(tester, adapter);
    await tester.tap(find.text('迅雷字幕（1）'));
    await tester.pumpAndSettle();

    adapter.thunder = false;
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ResourcePanelTabButton), findsNothing);
    expect(find.text('本地.srt'), findsOneWidget);

    adapter.local = false;
    adapter.thunder = true;
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ResourcePanelTabButton), findsNothing);
    expect(find.text('迅雷.srt'), findsOneWidget);

    adapter.local = true;
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ResourcePanelTabButton), findsNWidgets(2));
    expect(find.text('迅雷.srt'), findsOneWidget);
    expect(adapter.requests.where((path) => path == _localPath), hasLength(4));
    expect(
      adapter.requests.where((path) => path == _thunderPath),
      hasLength(4),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('双空刷新后自动展示新出现的迅雷字幕', (tester) async {
    final adapter = _SubtitleAdapter(local: false, thunder: false);
    await _pumpSheet(tester, adapter);

    adapter.thunder = true;
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();

    expect(find.text('迅雷.srt'), findsOneWidget);
    expect(find.byType(ResourcePanelTabButton), findsNothing);
    expect(find.text('没有找到匹配的字幕'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final failedPath in [_localPath, _thunderPath]) {
    testWidgets('$failedPath 真实业务错误仍显示并可恢复', (tester) async {
      final adapter = _SubtitleAdapter(local: false, thunder: false)
        ..errors[failedPath] = '字幕功能未启用';
      await _pumpSheet(tester, adapter);

      expect(find.byType(ResourcePanelTabButton), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('字幕功能未启用'), findsOneWidget);
      expect(find.text('没有找到匹配的字幕'), findsNothing);

      adapter.errors.clear();
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(find.text('没有找到匹配的字幕'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpSheet(
  WidgetTester tester,
  _SubtitleAdapter adapter, {
  bool settle = true,
}) async {
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
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: Scaffold(body: DbOnlineSubtitleSheet(code: 'ABC-001')),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

class _SubtitleAdapter implements HttpClientAdapter {
  _SubtitleAdapter({required this.local, required this.thunder});

  bool local;
  bool thunder;
  final errors = <String, String>{};
  final pending = <String, Completer<void>>{};
  final requests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    requests.add(path);
    await pending[path]?.future;
    final error = errors[path];
    final data = path == _localPath
        ? {
            'files': [
              if (local) {'id': 'local-1', 'name': '本地.srt'},
            ],
          }
        : {
            'items': [
              if (thunder)
                {'name': '迅雷.srt', 'url': 'https://example.test/sub.srt'},
            ],
          };
    return ResponseBody.fromString(
      jsonEncode({
        'code': error == null ? 0 : -1,
        'msg': error ?? 'success',
        if (error == null) 'data': data,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
