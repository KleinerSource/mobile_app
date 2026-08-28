import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/sheet_controls.dart';

void main() {
  testWidgets('sheetMaxHeight 为灵动岛设备保留顶部状态栏和更大的余量', (tester) async {
    double? actual;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: Builder(
          builder: (context) {
            actual = sheetMaxHeight(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(actual, 733);
  });
}
