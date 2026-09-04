import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_scaffold.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('简介弹窗关闭时不会退出详情页', (tester) async {
    final plot = List.filled(
      5,
      '这是一段用于测试的完整简介，内容足够长，可以超过详情页中简介展示的三行限制。',
    ).join();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: MovieDetailPlot(plot: plot)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MovieDetailPlot));
    await tester.pumpAndSettle();
    expect(find.text('关闭'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(find.text('关闭'), findsNothing);
    expect(find.byType(MovieDetailPlot), findsOneWidget);
  });

  testWidgets('三行以内的简介不显示弹窗且不响应点击', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: Scaffold(
          body: SizedBox(width: 160, child: MovieDetailPlot(plot: '这是一段简短简介。')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    await tester.tap(find.byType(MovieDetailPlot));
    await tester.pumpAndSettle();

    expect(find.text('关闭'), findsNothing);
  });
}
