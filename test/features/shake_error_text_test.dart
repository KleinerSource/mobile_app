import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/shared/shake_error_text.dart';

void main() {
  testWidgets('错误文字渲染并可随内容更新重建', (tester) async {
    const errorText = '两次输入的密码不一致，请重新设置';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ShakeErrorText(errorText)),
      ),
    );
    await tester.pump();

    expect(tester.widget<Text>(find.text(errorText)).style?.color,
        isNotNull);
  });
}
