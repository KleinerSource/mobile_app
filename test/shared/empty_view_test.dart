import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/empty_view.dart';

void main() {
  testWidgets('空态文案居中并使用统一的垂直补偿', (tester) async {
    const message = '没有找到符合条件的影片';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmptyView(message: message)),
      ),
    );

    final text = tester.widget<Text>(find.text(message));
    expect(text.textAlign, TextAlign.center);

    final transform = tester.widget<Transform>(
      find.ancestor(of: find.text(message), matching: find.byType(Transform)),
    );
    expect(transform.transform.getTranslation().y, -48);
  });
}
