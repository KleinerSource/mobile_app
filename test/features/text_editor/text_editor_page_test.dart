import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/text_editor/text_editor_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('只读模式显示标题且不显示编辑按钮', (tester) async {
    await _pumpViewer(tester, text: '第一行');

    expect(find.text('文本.txt'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('编辑'), findsNothing);
  });

  testWidgets('点击编辑后显示编辑器和连续行号', (tester) async {
    await _pumpViewer(tester, text: '第一行\n第二行\n第三行', onSave: (_) async {});

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '1\n2\n3',
      ),
      findsOneWidget,
    );
  });

  testWidgets('修改文本后保存回调收到完整内容且继续停留在编辑器', (tester) async {
    String? savedText;
    await _pumpViewer(
      tester,
      text: '原始内容',
      onSave: (text) async => savedText = text,
    );

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '第一行\n第二行');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedText, '第一行\n第二行');
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('保存成功'), findsOneWidget);
  });

  testWidgets('保存过程中显示保存中状态', (tester) async {
    final saving = Completer<void>();
    await _pumpViewer(tester, text: '原始内容', onSave: (_) => saving.future);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '修改内容');
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('保存中...'), findsOneWidget);
    saving.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('保存失败后保留编辑状态和未保存状态', (tester) async {
    await _pumpViewer(
      tester,
      text: '原始内容',
      onSave: (_) async => throw StateError('写入失败'),
    );

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '修改内容');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.textContaining('保存失败'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('未保存修改'), findsOneWidget);
  });

  testWidgets('未保存返回时可以取消或放弃修改', (tester) async {
    await _pumpViewer(tester, text: '原始内容', onSave: (_) async {});

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '修改内容');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('放弃修改'), findsOneWidget);
    expect(find.text('保存并离开'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(TextEditorPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.byType(TextEditorPage), findsNothing);
  });

  testWidgets('未保存返回时保存成功后离开', (tester) async {
    String? savedText;
    await _pumpViewer(
      tester,
      text: '原始内容',
      onSave: (text) async => savedText = text,
    );

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '保存后离开');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并离开'));
    await tester.pumpAndSettle();

    expect(savedText, '保存后离开');
    expect(find.byType(TextEditorPage), findsNothing);
  });
}

Future<void> _pumpViewer(
  WidgetTester tester, {
  required String text,
  Future<void> Function(String text)? onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          key: const ValueKey('open-viewer'),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  TextEditorPage(title: '文本.txt', text: text, onSave: onSave),
            ),
          ),
          child: const Text('打开'),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-viewer')));
  await tester.pumpAndSettle();
}
