import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_scaffold.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('简介弹窗关闭时不会退出详情页', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: MovieDetailPlot(plot: '这是一段用于测试的完整简介。')),
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
}
