import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/platform/platform.dart';

void main() {
  Widget wrap(TargetPlatform p, Widget child) => MaterialApp(
        theme: ThemeData(platform: p),
        home: child,
      );

  testWidgets('iOS 下渲染 CupertinoPageScaffold', (tester) async {
    await tester.pumpWidget(
      wrap(TargetPlatform.iOS, const AppScaffold(body: SizedBox.shrink())),
    );
    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    expect(find.byType(Scaffold), findsNothing);
  });

  testWidgets('Android 下渲染 Material Scaffold', (tester) async {
    await tester.pumpWidget(
      wrap(TargetPlatform.android, const AppScaffold(body: SizedBox.shrink())),
    );
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('iOS 下 AppTabsShell 渲染 CupertinoTabScaffold', (tester) async {
    await tester.pumpWidget(
      wrap(
        TargetPlatform.iOS,
        AppTabsShell(tabs: [
          AppTabItem(icon: CupertinoIcons.film, label: 'A', body: const SizedBox.shrink()),
          AppTabItem(icon: CupertinoIcons.star, label: 'B', body: const SizedBox.shrink()),
        ]),
      ),
    );
    expect(find.byType(CupertinoTabScaffold), findsOneWidget);
  });

  testWidgets('Android 下 AppTabsShell 渲染 NavigationBar', (tester) async {
    await tester.pumpWidget(
      wrap(
        TargetPlatform.android,
        AppTabsShell(tabs: [
          AppTabItem(icon: Icons.movie, label: 'A', body: const SizedBox.shrink()),
          AppTabItem(icon: Icons.star, label: 'B', body: const SizedBox.shrink()),
        ]),
      ),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
