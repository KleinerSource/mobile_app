import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/top_snack_bar.dart';

void main() {
  testWidgets('SnackBar 兼容调用会以悬浮 MaterialBanner 显示', (tester) async {
    const bodyKey = ValueKey<String>('body');
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => TopSnackBarMessenger(
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('页面')),
          body: Center(
            key: bodyKey,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('顶部通知')),
                ),
                child: const Text('显示'),
              ),
            ),
          ),
        ),
      ),
    );

    final bodyTop = tester.getTopLeft(find.byKey(bodyKey)).dy;
    await tester.tap(find.text('显示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text('顶部通知'), findsOneWidget);
    final bannerTop = tester.getTopLeft(find.byType(MaterialBanner)).dy;
    final scaffoldCenter = tester.getRect(find.byType(Scaffold)).center.dy;
    expect(bannerTop, lessThan(scaffoldCenter));
    expect(tester.getTopLeft(find.byKey(bodyKey)).dy, bodyTop);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
  });
}
