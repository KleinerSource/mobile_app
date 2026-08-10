import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/features/security/security_pin_pad.dart';

void main() {
  testWidgets('解锁模式填满六位自动提交并清空输入', (tester) async {
    final submitted = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecurityPinPad(
            autoSubmit: true,
            onCompleted: (pin) async {
              submitted.add(pin);
            },
          ),
        ),
      ),
    );

    for (final digit in '123456'.split('')) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();

    expect(submitted, ['123456']);
    expect(find.text('确认'), findsNothing);

    for (final digit in '654321'.split('')) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();

    expect(submitted, ['123456', '654321']);
  });
}
