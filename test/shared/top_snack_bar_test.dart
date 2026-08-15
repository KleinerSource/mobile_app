import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/top_snack_bar.dart';

void main() {
  testWidgets('SnackBar 兼容调用会在顶部显示通知', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TopSnackBarMessenger(
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('页面')),
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('顶部通知')),
              ),
              child: const Text('显示'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('显示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text('顶部通知'), findsOneWidget);
    final bannerTop = tester.getTopLeft(find.byType(MaterialBanner)).dy;
    final scaffoldCenter = tester.getRect(find.byType(Scaffold)).center.dy;
    expect(bannerTop, lessThan(scaffoldCenter));

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
  });
}
