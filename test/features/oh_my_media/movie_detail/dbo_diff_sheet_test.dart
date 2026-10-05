import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/sources/media/media_models.dart' as source_models;
import 'package:omm/core/sources/media/media_source.dart';
import 'package:omm/core/sources/media/omm_media_operations_source.dart';
import 'package:omm/features/oh_my_media/movie_detail/dbo_diff_sheet.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// DB Online 元数据 diff sheet 的底部操作行（全选/应用）与列表共用一个
/// Column，主按钮又在 Row 中按内容自适应宽度。这里的回归测试保证差异项
/// 很多时操作行不会被挤出屏幕，用户始终能确认选择。
void main() {
  testWidgets('差异项很多时底部操作按钮仍在屏幕内且可用', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final metadata = <String, dynamic>{
      'title': '远端标题',
      'plot': '远端简介' * 40,
      'score': 8.8,
      'duration': 120,
      'date': '2023-01-01',
      'series': {'name': '系列A'},
      'director': {'name': '导演甲', 'external_id': 'd1'},
      'maker': {'name': '片商乙', 'external_id': 'm1'},
      'categories': [for (var i = 0; i < 12; i++) {'name': '类别$i'}],
      'actors': [
        for (var i = 0; i < 80; i++) {'name': '演员$i', 'gender': '♀'},
      ],
    };
    final repository = MediaRepository(
      catalog: _NoopCatalog(),
      details: _NoopDetails(),
      operations: _FakeOps(metadata),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mediaRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () =>
                      DboDiffSheet.show(context, const MovieDetail(id: 1)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'sheet 布局不应产生约束断言或溢出');

    final applyButton = find.byType(FilledButton).last;
    expect(applyButton, findsOneWidget);
    final rect = tester.getRect(applyButton);
    expect(
      rect.bottom,
      lessThan(844),
      reason: '应用按钮必须完整出现在屏幕内，否则用户无法确认选择',
    );
    expect(rect.top, greaterThan(0));
    expect(find.text('请选择字段'), findsOneWidget);

    // 参考信息（导演/片商）纯展示，不提供任何跳转入口。
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
    expect(find.text('导演甲'), findsOneWidget);
    expect(find.text('片商乙'), findsOneWidget);

    await tester.tap(find.text('全选').first);
    await tester.pumpAndSettle();
    expect(find.text('清空'), findsAtLeastNWidgets(1));
  });
}

class _FakeOps implements OmmMediaOperationsSource {
  _FakeOps(this.metadata);

  final Map<String, dynamic> metadata;

  @override
  Future<Map<String, dynamic>> getDbonlineMetadata(
    source_models.MediaRef movie,
  ) async => metadata;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopCatalog implements CatalogSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopDetails implements MovieDetailSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
