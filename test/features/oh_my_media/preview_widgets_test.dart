import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/api/services/configs_api.dart';
import 'package:omm/core/api/services/configs_extended_api.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/preview.dart';
import 'package:omm/core/models/preview_config.dart';
import 'package:omm/core/sources/media/media_source.dart';
import 'package:omm/core/sources/media/omm_media_operations_source.dart';
import 'package:omm/features/oh_my_media/configs/configs_providers.dart';
import 'package:omm/features/oh_my_media/configs/configs_repository.dart';
import 'package:omm/features/oh_my_media/configs/preview_settings_page.dart';
import 'package:omm/features/oh_my_media/movie_detail/preview_status_card.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('预览设置页加载配置并保存编辑后的值', (tester) async {
    final repository = _FakeConfigsRepository(
      const PreviewConfig(segments: 24, segmentDuration: 1.5),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configsRepositoryProvider.overrideWithValue(repository),
          previewConfigProvider.overrideWith((ref) async => repository.current),
        ],
        child: _localizedApp(const PreviewSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('预览生成'), findsOneWidget);
    expect(find.text('配置预览视频、Sprite 和 VTT 的生成策略。'), findsOneWidget);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller?.text, '24');
    expect(fields[1].controller?.text, '1.5');

    await tester.scrollUntilVisible(
      find.byType(SettingsSaveButton),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(SettingsSaveButton));
    await tester.pumpAndSettle();

    expect(repository.saved?.segments, 24);
    expect(find.text('预览配置已保存'), findsOneWidget);
  });

  testWidgets('预览状态卡片展示资产状态和进行中的细粒度进度', (tester) async {
    final task = const PreviewTask(
      taskId: 'preview-running',
      status: 'running',
      totalCount: 1,
      currentMovieId: 7,
      currentMovieTitle: '长视频',
      progress: 42.5,
    );
    final repository = _FakeMediaRepository(
      PreviewStatus(
        movieId: 7,
        sourceState: 'ready',
        assets: const {
          'video': PreviewAssetStatus(ready: true),
          'sprite': PreviewAssetStatus(ready: true),
          'vtt': PreviewAssetStatus(ready: false),
        },
        task: task,
      ),
      task: task,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConfigProvider.overrideWith(
            () => _ServerConfigState(_ommConfig),
          ),
          mediaRepositoryProvider.overrideWithValue(repository),
        ],
        child: _localizedApp(
          const Scaffold(
            body: PreviewStatusCard(
              movieId: 7,
              movieTitle: '长视频',
              filePath: '/media/movie.mp4',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('预览资产'), findsOneWidget);
    expect(find.text('预览视频'), findsOneWidget);
    expect(find.text('Sprite'), findsOneWidget);
    expect(find.text('VTT'), findsOneWidget);
    expect(find.text('42.5%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('生成预览'), findsNothing);
    expect(find.text('重新生成'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('不支持的 strm 源文件禁用预览生成', (tester) async {
    final repository = _FakeMediaRepository(
      const PreviewStatus(movieId: 8, sourceState: 'unsupported'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConfigProvider.overrideWith(
            () => _ServerConfigState(_ommConfig),
          ),
          mediaRepositoryProvider.overrideWithValue(repository),
        ],
        child: _localizedApp(
          const Scaffold(
            body: PreviewStatusCard(
              movieId: 8,
              movieTitle: '流媒体占位',
              filePath: '/media/movie.strm',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('源文件不支持预览生成'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}

Widget _localizedApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    locale: const Locale('zh'),
    home: child,
  );
}

class _FakeConfigsRepository extends ConfigsRepository {
  _FakeConfigsRepository(this.current)
    : super(ConfigsApi(Dio()), ConfigsExtendedApi(Dio()));

  PreviewConfig current;
  PreviewConfig? saved;

  @override
  Future<PreviewConfig> getPreview() async => current;

  @override
  Future<PreviewConfig> savePreview(PreviewConfig config) async {
    current = config;
    saved = config;
    return config;
  }
}

class _FakeMediaRepository extends MediaRepository {
  _FakeMediaRepository(this.status, {PreviewTask? task})
    : task = task ?? status.task,
      super(
        catalog: _NoopCatalogSource(),
        details: _NoopMovieDetailSource(),
        operations: _NoopOmmOperationsSource(),
      );

  PreviewStatus status;
  final PreviewTask? task;

  @override
  Future<PreviewStatus> previewStatus(int id, {String? taskId}) async => status;

  @override
  Future<PreviewTask> previewTask(String taskId) async => task!;
}

class _NoopCatalogSource implements CatalogSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoopMovieDetailSource implements MovieDetailSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoopOmmOperationsSource implements OmmMediaOperationsSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

const _ommConfig = ServerConfig(
  baseUrl: 'https://omm.example',
  lines: [
    ServerLine(id: 'omm-line', name: '主线路', baseUrl: 'https://omm.example'),
  ],
  servers: [
    ServerProfile(
      id: 'omm',
      name: 'OMM',
      lines: [
        ServerLine(id: 'omm-line', name: '主线路', baseUrl: 'https://omm.example'),
      ],
      activeLineId: 'omm-line',
      projectName: 'oh-my-media',
    ),
  ],
  activeServerId: 'omm',
);
