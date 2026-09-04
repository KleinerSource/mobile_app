import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/media_metadata_widgets.dart';
import 'package:omm/shared/movie_detail_components.dart';

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('公共标题元信息统一显示并隐藏缺失字段', (tester) async {
    await tester.pumpWidget(
      _app(
        const MovieDetailTitle(
          title: '示例电影',
          originalTitle: 'Original Movie',
          year: 2024,
          runtime: 120,
          rating: 8.5,
        ),
      ),
    );

    expect(find.text('示例电影'), findsOneWidget);
    expect(find.text('Original Movie'), findsOneWidget);
    final meta = tester
        .widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('2024'),
          ),
        )
        .text
        .toPlainText();
    expect(meta, contains('2024'));
    expect(meta, contains('120'));
    expect(meta, contains('8.5'));

    await tester.pumpWidget(_app(const MovieDetailTitle(title: '仅标题')));
    expect(find.text('仅标题'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('2024'),
      ),
      findsNothing,
    );
  });

  testWidgets('分类和标签分开展示并过滤空值重复项', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            MediaTaxonomySection(title: '分类', items: ['科幻', ' ', '科幻', '悬疑']),
            MediaTaxonomySection(title: '标签', items: ['标签一']),
          ],
        ),
      ),
    );

    expect(find.text('分类'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('科幻'), findsOneWidget);
    expect(find.text('悬疑'), findsOneWidget);
    expect(find.text('标签一'), findsOneWidget);
    expect(find.byType(HueChip), findsNWidgets(3));
  });

  testWidgets('演员点击回调由调用方接收', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        CastSection(
          entries: [CastEntry(name: '演员一', onTap: () => tapped = true)],
        ),
      ),
    );

    await tester.tap(find.text('演员一'));
    expect(tapped, isTrue);
  });
}
