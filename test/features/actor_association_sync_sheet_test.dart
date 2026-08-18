import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/services/mappings_api.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/core/models/avdb_config.dart';
import 'package:md_center/core/models/dbo_config.dart';
import 'package:md_center/core/models/mapping_rule.dart';
import 'package:md_center/core/platform/app_theme.dart';
import 'package:md_center/features/actor_associations/actor_associations_providers.dart';
import 'package:md_center/features/actor_associations/actor_associations_repository.dart';
import 'package:md_center/features/actor_associations/widgets/actor_association_sync_sheet.dart';
import 'package:md_center/features/configs/configs_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('数据源以并排选项卡显示且预览请求中可快速往返切换',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = _PendingPreviewRepository();
    final oldDbo = repository.enqueue(ActorDataSource.dbonline);
    final avdb = repository.enqueue(ActorDataSource.avdb);
    final currentDbo = repository.enqueue(ActorDataSource.dbonline);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          dboConfigProvider.overrideWith(
            (ref) async => const DboConfig(
              enabled: true,
              baseUrl: 'https://dbo.example',
              apiKey: 'dbo-key',
            ),
          ),
          avdbConfigProvider.overrideWith(
            (ref) async => const AvdbConfig(
              enabled: true,
              baseUrl: 'https://avdb.example',
              apiKey: 'avdb-key',
            ),
          ),
          actorAssociationsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ActorAssociationSyncSheet(
              actor: MappingRule(
                id: 1,
                mappedValue: '演员 A',
                originalValues: ['演员 A'],
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5 && repository.requests.isEmpty; i++) {
      await tester.pump();
    }

    expect(find.byType(DropdownButtonFormField<ActorDataSource>), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    // 两渠道均启用时三个来源选项并排显示（含混合渠道）
    expect(find.text('混合渠道'), findsOneWidget);
    expect(
      tester.getCenter(find.text('DB Online')).dy,
      tester.getCenter(find.text('AVDB')).dy,
    );
    expect(
      tester.getCenter(find.text('混合渠道')).dy,
      tester.getCenter(find.text('DB Online')).dy,
    );
    expect(repository.requests, [ActorDataSource.dbonline]);

    await tester.tap(find.text('AVDB'));
    await tester.pump();
    await tester.tap(find.text('DB Online'));
    await tester.pump();

    expect(
      repository.requests,
      [
        ActorDataSource.dbonline,
        ActorDataSource.avdb,
        ActorDataSource.dbonline,
      ],
    );
    expect(find.byType(Checkbox), findsNothing);

    oldDbo.complete(_preview('过期 DB Online 结果'));
    await tester.pump();
    expect(find.text('过期 DB Online 结果'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    currentDbo.complete(_preview('当前 DB Online 结果'));
    avdb.complete(_preview('过期 AVDB 结果'));
    await tester.pumpAndSettle();

    expect(find.text('当前 DB Online 结果'), findsOneWidget);
    expect(find.text('过期 AVDB 结果'), findsNothing);

    // 切换到混合渠道：走渐进会话（先部分上屏、后补齐），不再调用 previewSource
    final mixedPartial = repository.enqueueMixedSession();
    final mixedFinal = repository.enqueueMixedSession();
    await tester.tap(find.text('混合渠道'));
    await tester.pump();
    expect(repository.requests.last, ActorDataSource.mixed);

    // 首个渠道（AVDB）先完成：立即上屏，DB Online 按钮显示补齐状态
    mixedPartial.complete(const MixedActorPreviewSession(
      status: 'running',
      pendingSources: ['dbonline'],
      preview: ActorAssocPreview(
        found: true,
        mappedValue: '混合渠道部分结果',
        actorName: '演员 A',
        allAliases: [],
        existingAliases: [],
        newAliases: ['部分新别名'],
      ),
    ));
    await tester.pump();
    expect(find.text('混合渠道部分结果'), findsOneWidget);
    expect(find.textContaining('等待DB Online补齐'), findsNothing);
    expect(find.text('DB Online 查询中'), findsOneWidget);
    final spinningIcon = tester.widget<RotationTransition>(
      find.ancestor(
        of: find.byIcon(Icons.sync),
        matching: find.byType(RotationTransition),
      ),
    );
    expect(spinningIcon.turns, isA<ReverseAnimation>());
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    // 补齐期间仍可确认同步：允许按已合并的数据先行应用
    final pendingButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认添加'),
    );
    expect(pendingButton.onPressed, isNotNull);

    // DB Online 返回未命中：补齐完成，渠道按钮显示错误图标
    mixedFinal.complete(const MixedActorPreviewSession(
      status: 'complete',
      pendingSources: [],
      preview: ActorAssocPreview(
        found: true,
        mappedValue: '混合渠道完整结果',
        actorName: '演员 A',
        allAliases: [],
        existingAliases: [],
        newAliases: ['新别名'],
        externalIds: {'avdb': '290438'},
        notFoundSources: ['dbonline'],
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('混合渠道完整结果'), findsOneWidget);
    expect(find.text('混合渠道部分结果'), findsNothing);
    expect(find.textContaining('等待'), findsNothing);
    expect(find.textContaining('DB Online未找到匹配'), findsNothing);
    expect(find.text('DB Online 无匹配'), findsOneWidget);
    final notFoundIcon = tester.widget<Icon>(
      find.byIcon(Icons.search_off_rounded),
    );
    expect(notFoundIcon.color, AppColors.light.muted);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.text('新别名'), findsOneWidget);
    final readyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认添加'),
    );
    expect(readyButton.onPressed, isNotNull);

    final failedDbo = repository.enqueue(ActorDataSource.dbonline);
    await tester.tap(find.text('DB Online'));
    await tester.pump();
    failedDbo.complete(const ActorAssocPreview(
      found: false,
      mappedValue: '',
      actorName: '演员 A',
      allAliases: [],
      existingAliases: [],
      newAliases: [],
      warnings: ['DB Online 渠道查询失败: 请求超时'],
    ));
    await tester.pumpAndSettle();

    final failedIcons = tester.widgetList<Icon>(
      find.byIcon(Icons.error_outline),
    );
    expect(failedIcons, isNotEmpty);
    expect(
      failedIcons.every((icon) => icon.color == AppColors.light.danger),
      isTrue,
    );
  });

  testWidgets('头像预览未完成时仍提交上游头像地址', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final avatarPreview = Completer<List<int>>();
    final applyCompletion = Completer<void>();
    final repository = _AvatarPreviewRepository(
      avatarPreview.future,
      applyCompletion,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          dboConfigProvider.overrideWith(
            (ref) async => const DboConfig(
              enabled: true,
              baseUrl: 'https://dbo.example',
              apiKey: 'dbo-key',
            ),
          ),
          avdbConfigProvider.overrideWith(
            (ref) async => const AvdbConfig(
              enabled: false,
              baseUrl: '',
              apiKey: '',
            ),
          ),
          actorAssociationsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ActorAssociationSyncSheet(
              actor: MappingRule(
                id: 2,
                mappedValue: '演员 B',
                originalValues: ['演员 B'],
              ),
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 10 && !repository.avatarPreviewRequested; i++) {
      await tester.pump();
    }

    expect(repository.avatarPreviewRequested, isTrue);
    await tester.pump();
    final applyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认添加'),
    );
    expect(applyButton.onPressed, isNotNull);

    await tester.tap(find.text('确认添加'));
    await tester.pump();

    expect(repository.appliedAvatarUrl, 'https://dbo.example/avatar.jpg');
    expect(repository.appliedAvatarOverwrite, isFalse);

    applyCompletion.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('头像候选选择器会在异步头像完成后立即刷新', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final firstAvatar = Completer<List<int>>();
    final secondAvatar = Completer<List<int>>();
    final repository = _AvatarPickerRepository(
      firstAvatar.future,
      secondAvatar.future,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          dboConfigProvider.overrideWith(
            (ref) async => const DboConfig(
              enabled: true,
              baseUrl: 'https://dbo.example',
              apiKey: 'dbo-key',
            ),
          ),
          avdbConfigProvider.overrideWith(
            (ref) async => const AvdbConfig(
              enabled: false,
              baseUrl: '',
              apiKey: '',
            ),
          ),
          actorAssociationsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ActorAssociationSyncSheet(
              actor: MappingRule(
                id: 3,
                mappedValue: '演员 C',
                originalValues: ['演员 C'],
              ),
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 20 && repository.avatarRequests.length < 2; i++) {
      await tester.pump();
    }
    expect(repository.avatarRequests, hasLength(2));
    await tester.pump();
    expect(find.text('标准演员'), findsOneWidget);
    expect(find.text('演员 C'), findsOneWidget);

    final actorLabelTop = tester.getTopLeft(find.text('标准演员')).dy;
    await tester.tapAt(Offset(53, actorLabelTop + 28));
    await tester.pump();
    expect(find.text('选择演员头像'), findsOneWidget);

    firstAvatar.complete(_tinyPng);
    await tester.pump();

    // 主预览的两个 loading 指示器消失，选择器只保留第二张仍在加载的指示器。
    expect(find.byType(CircularProgressIndicator), findsNWidgets(1));
    expect(find.byType(Image), findsNWidgets(2));

    secondAvatar.complete(_tinyPng);
    await tester.pump();
  });
}

const _tinyPng = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x60,
  0x60,
  0x60,
  0x00,
  0x00,
  0x00,
  0x04,
  0x00,
  0x01,
  0x27,
  0x34,
  0x27,
  0x5b,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];

ActorAssocPreview _preview(String mappedValue) {
  return ActorAssocPreview(
    found: true,
    mappedValue: mappedValue,
    actorName: '演员 A',
    allAliases: const [],
    existingAliases: const [],
    newAliases: const [],
  );
}

class _PendingPreviewRepository extends ActorAssociationsRepository {
  _PendingPreviewRepository() : super(MappingsApi(Dio()));

  final List<ActorDataSource> requests = [];
  final Map<ActorDataSource, List<Completer<ActorAssocPreview>>> _pending = {
    ActorDataSource.dbonline: [],
    ActorDataSource.avdb: [],
    ActorDataSource.mixed: [],
  };
  // 混合渠道渐进会话：每次轮询消费一个快照（running→complete 依次出队）
  final List<Completer<MixedActorPreviewSession>> _mixedSessions = [];

  Completer<ActorAssocPreview> enqueue(ActorDataSource source) {
    final completer = Completer<ActorAssocPreview>();
    _pending[source]!.add(completer);
    return completer;
  }

  Completer<MixedActorPreviewSession> enqueueMixedSession() {
    final completer = Completer<MixedActorPreviewSession>();
    _mixedSessions.add(completer);
    return completer;
  }

  @override
  Future<ActorAssocPreview> previewSource(
    String actorName, {
    ActorDataSource source = ActorDataSource.dbonline,
  }) {
    requests.add(source);
    return _pending[source]!.removeAt(0).future;
  }

  @override
  Future<String> startMixedPreviewSession(String actorName) {
    requests.add(ActorDataSource.mixed);
    return Future.value('mixed-task-${_mixedSessions.length}');
  }

  @override
  Future<MixedActorPreviewSession> getMixedPreviewSession(String taskId) {
    if (_mixedSessions.isEmpty) {
      return Future.error(StateError('没有待返回的混合渠道会话快照'));
    }
    return _mixedSessions.removeAt(0).future;
  }
}

class _AvatarPreviewRepository extends ActorAssociationsRepository {
  _AvatarPreviewRepository(this.avatarPreviewFuture, this.applyCompletion)
      : super(MappingsApi(Dio()));

  final Future<List<int>> avatarPreviewFuture;
  final Completer<void> applyCompletion;
  bool avatarPreviewRequested = false;
  String? appliedAvatarUrl;
  bool? appliedAvatarOverwrite;

  @override
  Future<ActorAssocPreview> previewSource(
    String actorName, {
    ActorDataSource source = ActorDataSource.dbonline,
  }) {
    return Future.value(
      const ActorAssocPreview(
        found: true,
        mappedValue: '演员 B',
        actorName: '演员 B',
        allAliases: [],
        existingAliases: [],
        newAliases: [],
        avatarUrl: 'https://dbo.example/avatar.jpg',
      ),
    );
  }

  @override
  Future<List<int>> previewAvatar(
    String avatarUrl, {
    ActorDataSource source = ActorDataSource.dbonline,
  }) {
    avatarPreviewRequested = true;
    return avatarPreviewFuture;
  }

  @override
  Future<bool> applySource({
    required String mappedValue,
    required List<String> originalValues,
    ActorDataSource source = ActorDataSource.dbonline,
    String? biography,
    String? avatarUrl,
    bool avatarOverwrite = false,
    String? avatarSource,
    Map<String, String>? externalIds,
  }) async {
    appliedAvatarUrl = avatarUrl;
    appliedAvatarOverwrite = avatarOverwrite;
    await applyCompletion.future;
    return true;
  }
}

class _AvatarPickerRepository extends ActorAssociationsRepository {
  _AvatarPickerRepository(this.firstAvatar, this.secondAvatar)
      : super(MappingsApi(Dio()));

  final Future<List<int>> firstAvatar;
  final Future<List<int>> secondAvatar;
  final List<String> avatarRequests = [];

  @override
  Future<ActorAssocPreview> previewSource(
    String actorName, {
    ActorDataSource source = ActorDataSource.dbonline,
  }) {
    return Future.value(
      const ActorAssocPreview(
        found: true,
        mappedValue: '演员 C',
        actorName: '演员 C',
        allAliases: [],
        existingAliases: [],
        newAliases: [],
        avatarChoices: [
          ActorAssociationAvatarChoice(
            downloadUrl: 'https://dbo.example/avatar-1.jpg',
          ),
          ActorAssociationAvatarChoice(
            downloadUrl: 'https://dbo.example/avatar-2.jpg',
          ),
        ],
      ),
    );
  }

  @override
  Future<List<int>> previewAvatar(
    String avatarUrl, {
    ActorDataSource source = ActorDataSource.dbonline,
  }) {
    avatarRequests.add(avatarUrl);
    return avatarUrl.endsWith('avatar-1.jpg') ? firstAvatar : secondAvatar;
  }
}
