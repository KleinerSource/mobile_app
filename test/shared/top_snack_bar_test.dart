import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/top_snack_bar.dart';

void main() {
  testWidgets('顶部通知居中并支持点击和上滑关闭', (tester) async {
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
    final bannerCenter = tester.getCenter(find.byType(MaterialBanner)).dx;
    final scaffoldRect = tester.getRect(find.byType(Scaffold));
    expect(bannerTop, lessThan(scaffoldRect.center.dy));
    expect(bannerCenter, closeTo(scaffoldRect.center.dx, 0.1));
    expect(tester.getTopLeft(find.byKey(bodyKey)).dy, bodyTop);

    await tester.tap(find.text('顶部通知'));
    await tester.pump();
    expect(find.byType(MaterialBanner), findsNothing);

    await tester.tap(find.text('显示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MaterialBanner), findsOneWidget);

    await tester.fling(find.byType(MaterialBanner), const Offset(0, -80), 500);
    await tester.pump();
    expect(find.byType(MaterialBanner), findsNothing);
  });
}
