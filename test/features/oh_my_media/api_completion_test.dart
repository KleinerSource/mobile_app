import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/library.dart';
import 'package:omm/features/oh_my_media/libraries/library_editor_page.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/core/sources/media/omm_media_operations_adapter.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/features/oh_my_media/configs/ffmpeg_tools_page.dart';
import 'package:omm/features/oh_my_media/configs/omm_admin_repository.dart';
import 'package:omm/features/oh_my_media/configs/omm_maintenance_page.dart';
import 'package:omm/features/oh_my_media/configs/schedule_settings_page.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_editor_sheet.dart';
import 'package:omm/features/oh_my_media/movie_detail/poster_crop_controller.dart';
import 'package:omm/features/oh_my_media/resources/entity_merge_sheet.dart';
import 'package:omm/features/oh_my_media/resources/resources_providers.dart';
import 'package:omm/features/oh_my_media/resources/resources_repository.dart';
import 'package:omm/features/oh_my_media/resources/resource_list_page.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
);

class _Backend implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  FutureOr<Object?> Function(RequestOptions)? respond;
  final fixtures = <String, Object?>{
    '/schedule': {
      'enabled': true,
      'times': ['03:00', '12:30'],
    },
    '/maintenance/orphaned-count': {
      'movie_tags_count': 2,
      'movie_actors_count': 1,
    },
    '/maintenance/cleanup-orphans': {
      'movie_tags_deleted': 2,
      'movie_actors_deleted': 1,
    },
    '/ffmpeg/status': {'ffmpeg_ok': false, 'ffprobe_ok': false},
    '/ffmpeg/env': {
      'os': 'linux',
      'arch': 'amd64',
      'supported': true,
      'target_dir': '/data/ffmpeg',
    },
    '/ffmpeg/gpu-detect': {'gpu': 'Test GPU', 'effective_hwaccel': 'vaapi'},
    '/ffmpeg/install/status': {'running': false, 'done': false},
    '/ffmpeg/install': {'running': true, 'stage': 'downloading'},
  };
  ApiClient client() => ApiClient(
    Dio(BaseOptions(baseUrl: 'https://test.local'))..httpClientAdapter = this,
  );
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final value = respond == null
        ? fixtures[options.path]
        : await respond!(options);
    if (value is ResponseBody) return value;
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': value}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  int count(String path, [String? method]) => requests
      .where((r) => r.path == path && (method == null || r.method == method))
      .length;
}

ResponseBody _error(String message) => ResponseBody.fromString(
  jsonEncode({'success': false, 'message': message}),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);
ResponseBody _image() => ResponseBody.fromBytes(
  _png,
  200,
  headers: {
    Headers.contentTypeHeader: ['image/png'],
  },
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget page,
  ApiClient client,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final source = OmmMediaSourceAdapter(client);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requiredApiClientProvider.overrideWithValue(client),
        ommMediaSourceProvider.overrideWithValue(source),
        resourcesRepositoryProvider.overrideWithValue(
          ResourcesRepository(source.metadataOperations),
        ),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                if (page is MovieEditorSheet) {
                  MovieEditorSheet.show(context, page.movie);
                } else if (page is EntityMergeSheet) {
                  EntityMergeSheet.show(context, page.kind, page.items);
                } else {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => page));
                }
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> _tap(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  test('预检查参数匹配后端契约；保留演员重命名检查', () async {
    final backend = _Backend()
      ..respond = (r) => {
        'has_conflict': true,
        'can_merge': false,
        'conflict_info': {'existing_item_id': 9},
      };
    final source = OmmMediaOperationsAdapter(backend.client());
    final repo = ResourcesRepository(source);
    expect(
      (await repo.checkRename(ResourceKind.genre, 7, '目标'))['has_conflict'],
      isTrue,
    );
    expect(
      (await repo.checkMerge(ResourceKind.tag, [1, 2], '目标'))['can_merge'],
      isFalse,
    );
    await source.checkResourceRename('actors', {
      'item_id': 5,
      'new_name': '演员',
    });
    expect(backend.requests.map((r) => r.path), [
      '/genres/rename/check',
      '/tags/merge/check',
      '/actors/rename/check',
    ]);
    expect(backend.requests[0].data, {'item_id': 7, 'new_name': '目标'});
    expect(backend.requests[1].data, {
      'source_ids': [1, 2],
      'target_name': '目标',
    });
  });

  test('封面按字节获取；预览和保存上传同一 cover_file 且保持三态字段', () async {
    final backend = _Backend()
      ..respond = (r) => r.path.endsWith('/watermark') ? {} : _image();
    final source = OmmMediaOperationsAdapter(backend.client());
    const movie = MediaRef(sourceId: SourceId('omm'), value: '7');
    final bytes = await source.fetchDbonlineCover(movie);
    expect(bytes, _png);
    await source.previewPosterCrop(movie, cropOffset: .25, coverBytes: bytes);
    await source.applyPosterCrop(
      movie,
      cropOffset: .25,
      coverBytes: bytes,
      syncParts: true,
      subtitle: false,
    );
    expect(backend.requests.first.responseType, ResponseType.bytes);
    final preview = backend.requests[1].data as FormData;
    final save = backend.requests[2].data as FormData;
    expect(preview.files.single.key, 'cover_file');
    expect(preview.files.single.value.length, _png.length);
    expect(Map.fromEntries(preview.fields), {'crop_offset': '0.25'});
    expect(Map.fromEntries(save.fields), {
      'crop_offset': '0.25',
      'sync_parts': 'true',
      'subtitle': 'false',
    });
  });

  test('封面 JSON 失败不能被当成图片字节；关闭连接不再发送请求', () async {
    final backend = _Backend()..respond = (_) => _error('未配置 DBOnline');
    final client = backend.client();
    final source = OmmMediaOperationsAdapter(client);
    const movie = MediaRef(sourceId: SourceId('omm'), value: '7');
    await expectLater(source.fetchDbonlineCover(movie), throwsA(anything));
    client.close();
    await expectLater(source.fetchDbonlineCover(movie), throwsA(anything));
    expect(backend.requests, hasLength(1));
  });

  test('旧管理连接晚到结果丢弃，关闭后不再写入', () async {
    final pending = Completer<Object?>();
    final backend = _Backend()..respond = (_) => pending.future;
    final repo = OmmAdminRepository(backend.client());
    final request = repo.orphanedCount();
    final rejected = expectLater(request, throwsA(anything));
    repo.close();
    pending.complete({'movie_tags_count': 1});
    await rejected;
    await expectLater(repo.cleanupOrphans(), throwsA(anything));
    expect(backend.requests, hasLength(1));
  });

  for (final canMerge in [true, false]) {
    testWidgets('合并前必须通过检查：$canMerge', (tester) async {
      final backend = _Backend()
        ..respond = (r) => r.path.endsWith('/check')
            ? {'can_merge': canMerge, 'message': '目标冲突'}
            : {};
      await _pump(
        tester,
        const EntityMergeSheet(
          kind: ResourceKind.tag,
          items: [
            ResourceItem(id: 1, name: 'A'),
            ResourceItem(id: 2, name: 'B'),
          ],
        ),
        backend.client(),
      );
      await _tap(tester, '确认合并');
      expect(backend.count('/tags/merge/check'), 1);
      expect(backend.count('/tags/merge'), canMerge ? 1 : 0);
      if (!canMerge) expect(find.text('目标冲突'), findsOneWidget);
    });
  }

  testWidgets('清理取消不请求，确认后显示数量并刷新', (tester) async {
    final backend = _Backend();
    await _pump(tester, const OmmMaintenancePage(), backend.client());
    expect(find.text('3'), findsOneWidget);
    await _tap(tester, '清理孤立关联');
    await _tap(tester, '取消');
    expect(backend.count('/maintenance/cleanup-orphans'), 0);
    await _tap(tester, '清理孤立关联');
    await _tap(tester, '确定');
    expect(backend.count('/maintenance/cleanup-orphans'), 1);
    expect(find.text('已清理 3 条关联记录'), findsOneWidget);
  });

  testWidgets('定时扫描保留时刻并提交开关；可删除时刻', (tester) async {
    final backend = _Backend();
    backend.respond = (r) =>
        r.method == 'PUT' ? r.data : backend.fixtures[r.path];
    await _pump(tester, const ScheduleSettingsPage(), backend.client());
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    tester
        .widget<InputChip>(find.widgetWithText(InputChip, '03:00'))
        .onDeleted!();
    await tester.pumpAndSettle();
    await _tap(tester, '保存设置');
    final request = backend.requests.singleWhere((r) => r.method == 'PUT');
    expect(request.data, {
      'enabled': false,
      'times': ['12:30'],
    });
  });

  testWidgets('FFmpeg 已可用但没有安装任务记录时显示可用并禁用重复安装', (tester) async {
    final backend = _Backend();
    backend.fixtures['/ffmpeg/status'] = {
      'ffmpeg_ok': true,
      'ffprobe_ok': true,
      'ffmpeg_path': '/usr/bin/ffmpeg',
      'ffprobe_path': '/usr/bin/ffprobe',
    };
    await _pump(tester, const FfmpegToolsPage(), backend.client());
    expect(find.text('可用'), findsOneWidget);
    expect(find.text('未开始安装'), findsNothing);
    expect(find.text('可用\n/usr/bin/ffmpeg'), findsOneWidget);
    expect(find.text('可用\n/usr/bin/ffprobe'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '下载并安装 FFmpeg'),
          )
          .onPressed,
      isNull,
    );
    expect(backend.count('/ffmpeg/install'), 0);
  });

  for (final availability in [(false, false), (true, false), (false, true)]) {
    testWidgets('FFmpeg 检测缺少工具 $availability 时仍允许安装', (tester) async {
      final backend = _Backend();
      backend.fixtures['/ffmpeg/status'] = {
        'ffmpeg_ok': availability.$1,
        'ffprobe_ok': availability.$2,
      };
      await _pump(tester, const FfmpegToolsPage(), backend.client());
      expect(find.text('未开始安装'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '下载并安装 FFmpeg'),
            )
            .onPressed,
        isNotNull,
      );
    });
  }

  testWidgets('FFmpeg 检测已可用时仍保留正在运行及失败的安装任务状态', (tester) async {
    final backend = _Backend();
    await _pump(tester, const FfmpegToolsPage(), backend.client());
    backend.fixtures['/ffmpeg/status'] = {
      'ffmpeg_ok': true,
      'ffprobe_ok': true,
    };
    backend.fixtures['/ffmpeg/install/status'] = {
      'running': true,
      'done': false,
      'stage': 'downloading',
    };
    await _tap(tester, '刷新状态');
    expect(find.text('下载中'), findsOneWidget);
    expect(find.text('未开始安装'), findsNothing);
    backend.fixtures['/ffmpeg/install/status'] = {
      'running': false,
      'done': true,
      'stage': 'failed',
      'error': '下载失败',
    };
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('安装失败'), findsOneWidget);
    expect(find.text('下载失败'), findsOneWidget);

    // 服务器重启后没有任务历史，仍应以现有可执行文件的检测结果为准。
    backend.fixtures['/ffmpeg/install/status'] = {
      'running': false,
      'done': false,
    };
    await _tap(tester, '刷新状态');
    expect(find.text('可用'), findsOneWidget);
    expect(find.text('安装失败'), findsNothing);
    expect(find.text('未开始安装'), findsNothing);
    expect(backend.count('/ffmpeg/install'), 0);
  });

  testWidgets('FFmpeg 不支持环境禁用安装；退出后停止轮询', (tester) async {
    final backend = _Backend();
    backend.fixtures['/ffmpeg/env'] = {
      'supported': false,
      'reason': 'unsupported',
    };
    await _pump(tester, const FfmpegToolsPage(), backend.client());
    expect(find.text('unsupported'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '下载并安装 FFmpeg'),
          )
          .onPressed,
      isNull,
    );
    expect(backend.count('/ffmpeg/install'), 0);
  });

  testWidgets('FFmpeg 安装确认、轮询终态及退出后不再请求', (tester) async {
    final backend = _Backend();
    await _pump(tester, const FfmpegToolsPage(), backend.client());
    await _tap(tester, '下载并安装 FFmpeg');
    await _tap(tester, '确定');
    backend.fixtures['/ffmpeg/install/status'] = {
      'running': false,
      'done': true,
      'stage': 'done',
    };
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('安装完成'), findsOneWidget);
    expect(backend.count('/ffmpeg/install'), 1);
    expect(backend.count('/ffmpeg/status'), 2);
    final count = backend.requests.length;
    Navigator.of(tester.element(find.byType(FfmpegToolsPage))).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(backend.requests.length, count);
  });

  testWidgets('服务器切换关闭正在确认的清理，不能写入新连接', (tester) async {
    final backend = _Backend();
    final client = backend.client();
    final container = await _pump(tester, const OmmMaintenancePage(), client);
    await _tap(tester, '清理孤立关联');
    container.updateOverrides([
      requiredApiClientProvider.overrideWithValue(_Backend().client()),
      ommMediaSourceProvider.overrideWithValue(OmmMediaSourceAdapter(client)),
      resourcesRepositoryProvider.overrideWithValue(
        ResourcesRepository(OmmMediaOperationsAdapter(client)),
      ),
      sharedPrefsProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(backend.count('/maintenance/cleanup-orphans'), 0);
  });

  testWidgets('封面获取仅做预览，取消不修改，保存携带封面文件', (tester) async {
    final backend = _Backend();
    backend.respond = (r) =>
        r.path.endsWith('/cover') || r.path.endsWith('/preview')
        ? _image()
        : {'id': 7, 'title': '测试影片'};
    await _pump(
      tester,
      const MovieEditorSheet(
        movie: MovieDetail(id: 7, title: '测试影片', num: 'ABC-007'),
      ),
      backend.client(),
    );
    await _tap(tester, '从 DBOnline 获取封面');
    expect(find.byType(PosterCropController), findsOneWidget);
    expect(backend.count('/movies/id/7/poster/watermark'), 0);
    Navigator.of(tester.element(find.byType(MovieEditorSheet))).pop();
    await tester.pumpAndSettle();
    expect(backend.requests.where((r) => r.method == 'PATCH'), isEmpty);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _tap(tester, '从 DBOnline 获取封面');
    await _tap(tester, '保存');
    expect(backend.count('/movies/id/7/poster/watermark'), 1);
    expect(
      backend.requests.singleWhere((r) => r.path.endsWith('/watermark')).data,
      isA<FormData>(),
    );
  });
  for (final choice in ['取消', '继续重命名（自动编号）', '确认合并']) {
    testWidgets('重命名冲突选择 $choice 决定是否写入或合并', (tester) async {
      final backend = _Backend();
      backend.respond = (r) {
        if (r.path == '/tags' && r.method == 'GET') {
          return [
            {'id': 1, 'name': 'A', 'movie_count': 1},
          ];
        }
        if (r.path == '/tags/rename/check') {
          return {
            'has_conflict': true,
            'can_auto_merge': true,
            'message': '名称已存在',
            'conflict_info': {'existing_item_id': 9, 'existing_item_name': 'B'},
          };
        }
        if (r.path == '/tags/merge/check') return {'can_merge': true};
        if (r.path == '/tags/1') return {'id': 1, 'name': 'B (1)'};
        return {};
      };
      await _pump(
        tester,
        const ResourceListPage(kind: ResourceKind.tag),
        backend.client(),
      );
      tester
          .widget<SwipeActionCell>(find.byType(SwipeActionCell).first)
          .actions
          .first
          .onPressed();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'B');
      await _tap(tester, '保存');
      expect(find.text('名称已存在'), findsOneWidget);
      expect(backend.count('/tags/rename/check'), 1);
      expect(backend.count('/tags/1', 'PATCH'), 0);
      await _tap(tester, choice);
      expect(
        backend.count('/tags/1', 'PATCH'),
        choice.startsWith('继续') ? 1 : 0,
      );
      expect(backend.count('/tags/merge'), choice == '确认合并' ? 1 : 0);
      if (choice == '确认合并') {
        expect(
          backend.requests.singleWhere((r) => r.path == '/tags/merge').data,
          {
            'source_ids': [1, 9],
            'target_name': 'B',
          },
        );
      }
    });
  }

  testWidgets('维护加载失败可重试，确认清理后防止重复提交', (tester) async {
    final pending = Completer<Object?>();
    final backend = _Backend();
    var fail = true;
    backend.respond = (r) {
      if (r.path == '/maintenance/orphaned-count' && fail) {
        return _error('统计不可用');
      }
      if (r.path == '/maintenance/cleanup-orphans') return pending.future;
      return backend.fixtures[r.path];
    };
    await _pump(tester, const OmmMaintenancePage(), backend.client());
    expect(find.text('统计不可用'), findsOneWidget);
    fail = false;
    await _tap(tester, '刷新状态');
    await _tap(tester, '清理孤立关联');
    await _tap(tester, '确定');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '清理孤立关联'))
          .onPressed,
      isNull,
    );
    expect(backend.count('/maintenance/cleanup-orphans'), 1);
    pending.complete({'movie_tags_count': 1});
    await tester.pumpAndSettle();
    expect(find.text('统计不可用'), findsNothing);
  });

  testWidgets('FFmpeg 运行期间退出会取消轮询', (tester) async {
    final backend = _Backend();
    await _pump(tester, const FfmpegToolsPage(), backend.client());
    await _tap(tester, '下载并安装 FFmpeg');
    await _tap(tester, '确定');
    Navigator.of(tester.element(find.byType(FfmpegToolsPage))).pop();
    await tester.pumpAndSettle();
    final count = backend.requests.length;
    await tester.pump(const Duration(seconds: 10));
    expect(backend.requests.length, count);
  });

  testWidgets('目录详情读取服务端路径和最后扫描时间，不修改表单', (tester) async {
    final backend = _Backend()
      ..respond = (_) => {
        'id': 8,
        'name': '目录 A',
        'path': '/server/latest',
        'enabled': true,
        'last_scan_time': '2026-10-07T03:00:00Z',
      };
    await _pump(
      tester,
      const LibraryEditorPage(
        library: LibraryItem(
          id: 7,
          name: '库 A',
          directories: [DirectoryItem(id: 8, path: '/original')],
        ),
      ),
      backend.client(),
    );
    await tester.tap(find.byTooltip('目录详情'));
    await tester.pumpAndSettle();
    expect(backend.requests.single.path, '/libraries/id/7/directories/8');
    expect(find.text('/server/latest'), findsOneWidget);
    expect(find.text('2026-10-07T03:00:00Z'), findsOneWidget);
    await _tap(tester, '确定');
    expect(find.text('/original'), findsOneWidget);
  });

  testWidgets('FFmpeg 手动刷新后旧轮询晚到不能覆盖终态', (tester) async {
    final backend = _Backend();
    final pending = Completer<Object?>();
    var calls = 0;
    backend.respond = (r) {
      if (r.path == '/ffmpeg/install/status' && ++calls == 2) {
        return pending.future;
      }
      return backend.fixtures[r.path];
    };
    await _pump(tester, const FfmpegToolsPage(), backend.client());
    await _tap(tester, '下载并安装 FFmpeg');
    await _tap(tester, '确定');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    backend.fixtures['/ffmpeg/install/status'] = {
      'running': false,
      'done': true,
      'stage': 'done',
    };
    await _tap(tester, '刷新状态');
    expect(find.text('安装完成'), findsOneWidget);
    pending.complete({'running': true, 'stage': 'downloading'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('安装完成'), findsOneWidget);
    final count = backend.requests.length;
    await tester.pump(const Duration(seconds: 3));
    expect(backend.requests.length, count);
  });
}
