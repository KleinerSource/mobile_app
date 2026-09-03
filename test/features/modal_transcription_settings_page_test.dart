import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/services/modal_transcription_api.dart';
import 'package:omm/core/models/modal_transcription_config.dart';
import 'package:omm/features/translation/modal_transcription_providers.dart';
import 'package:omm/features/translation/modal_transcription_repository.dart';
import 'package:omm/features/translation/modal_transcription_settings_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// 模拟服务端行为：保存后回显脱敏令牌，并为新增令牌分配稳定 id。
class _FakeModalRepository extends ModalTranscriptionRepository {
  _FakeModalRepository(this.config) : super(ModalTranscriptionApi(Dio()));

  ModalTranscriptionConfig config;
  final List<Map<String, dynamic>> requests = [];
  int _idSeed = 0;

  @override
  Future<ModalTranscriptionConfig> getConfig() async => config;

  @override
  Future<ModalTranscriptionConfig> saveConfig(
    ModalTranscriptionConfig value,
  ) async {
    requests.add(value.toRequest());
    config = ModalTranscriptionConfig(
      enabled: value.enabled,
      tokens: [
        for (final token in value.tokens)
          ModalTranscriptionToken(
            id: token.id.isNotEmpty ? token.id : 'srv-${++_idSeed}',
            name: token.name,
            tokenIdMasked: token.tokenId.isEmpty ? '' : '********2345',
          ),
      ],
      tokenStrategy: value.tokenStrategy,
      perTokenWorkers: value.perTokenWorkers,
      hasHfToken: value.hasHfToken || value.hfToken.trim().isNotEmpty,
      defaultGpu: value.defaultGpu,
      repoBranch: value.repoBranch,
      maxWorkers: value.maxWorkers,
    );
    return config;
  }
}

Future<_FakeModalRepository> _pumpPage(
  WidgetTester tester,
  ModalTranscriptionConfig initial,
) async {
  // 表单较长：放大测试视口，保证底部保存按钮始终构建。
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = _FakeModalRepository(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        modalTranscriptionRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: ModalTranscriptionSettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _enableAndSave(WidgetTester tester) async {
  await tester.tap(find.byType(Switch));
  await tester.pump();
  await tester.tap(find.text('保存云端转译配置'));
  await tester.pumpAndSettle();
}

/// 慢速左滑令牌行展开操作（不触发热滑直触），并点击指定操作按钮。
Future<void> _swipeAndTap(WidgetTester tester, Finder row, String label) async {
  await tester.timedDrag(
    row,
    const Offset(-150, 0),
    const Duration(milliseconds: 500),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('展示服务端脱敏令牌并按完整目标列表提交', (tester) async {
    final repository = await _pumpPage(
      tester,
      const ModalTranscriptionConfig(
        tokens: [
          ModalTranscriptionToken(
            id: 't1',
            name: '主账号',
            tokenIdMasked: '********2345',
          ),
          ModalTranscriptionToken(
            id: 't2',
            name: '备用账号',
            tokenIdMasked: '********6789',
          ),
        ],
        tokenStrategy: 'fill_first',
        perTokenWorkers: 3,
        hasHfToken: true,
      ),
    );

    expect(find.text('主账号'), findsOneWidget);
    expect(find.text('********2345'), findsOneWidget);
    expect(find.text('备用账号'), findsOneWidget);
    expect(find.text('已配置 2 个 · 上限 20 个'), findsOneWidget);

    await _enableAndSave(tester);

    final request = repository.requests.single;
    // 既有令牌未输入新凭据时只提交稳定 id 与备注；空 HF token 不提交。
    expect(request['tokens'], [
      {'id': 't1', 'name': '主账号'},
      {'id': 't2', 'name': '备用账号'},
    ]);
    expect(request['token_strategy'], 'fill_first');
    expect(request['per_token_workers'], 3);
    expect(request['enabled'], isTrue);
    expect(request.containsKey('hf_token'), isFalse);
    expect(find.text('云端字幕转译配置已保存'), findsOneWidget);
  });

  testWidgets('启用时空令牌被拦截，新增令牌必须填写完整凭据', (tester) async {
    final repository = await _pumpPage(
      tester,
      const ModalTranscriptionConfig(),
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('保存云端转译配置'));
    await tester.pumpAndSettle();

    expect(find.text('启用云端字幕转译时至少需要添加一个 Modal 令牌'), findsOneWidget);
    expect(repository.requests, isEmpty);

    await tester.tap(find.text('添加令牌'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('新增令牌必须同时填写 Token ID 和 Token Secret'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '备注（可选）'), '主账号');
    await tester.enterText(
      find.widgetWithText(TextField, 'Token ID'),
      'ak-main',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Token Secret'),
      'sk-main',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('主账号'), findsOneWidget);
    expect(find.text('新令牌 · 保存后生效'), findsOneWidget);

    await tester.tap(find.text('保存云端转译配置'));
    await tester.pumpAndSettle();

    expect(repository.requests.single['tokens'], [
      {'name': '主账号', 'token_id': 'ak-main', 'token_secret': 'sk-main'},
    ]);
    // 保存成功后以服务端脱敏回显，草稿明文被清空。
    expect(find.text('********2345'), findsOneWidget);
    expect(find.text('新令牌 · 保存后生效'), findsNothing);
  });

  testWidgets('编辑已有令牌留空凭据只提交 id 与备注，删除令牌提交移除', (tester) async {
    final repository = await _pumpPage(
      tester,
      const ModalTranscriptionConfig(
        tokens: [
          ModalTranscriptionToken(
            id: 't1',
            name: '主账号',
            tokenIdMasked: '********2345',
          ),
          ModalTranscriptionToken(
            id: 't2',
            name: '备用账号',
            tokenIdMasked: '********6789',
          ),
        ],
      ),
    );

    await _swipeAndTap(tester, find.text('主账号'), '编辑');
    await tester.pumpAndSettle();

    expect(find.text('编辑令牌'), findsOneWidget);
    expect(find.text('已配置，留空则不修改'), findsNWidgets(2));
    await tester.enterText(find.widgetWithText(TextField, '备注（可选）'), '主账号改');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    await _swipeAndTap(tester, find.text('备用账号'), '删除');
    await tester.pumpAndSettle();

    expect(find.text('备用账号'), findsNothing);
    expect(find.text('已配置 1 个 · 上限 20 个'), findsOneWidget);

    await _enableAndSave(tester);

    expect(repository.requests.single['tokens'], [
      {'id': 't1', 'name': '主账号改'},
    ]);
  });
}
