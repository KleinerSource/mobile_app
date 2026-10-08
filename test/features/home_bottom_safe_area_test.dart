import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/home/home_movie_section.dart';

void main() {
  testWidgets(
    'OMM, DBO, and MediaBrowser home scroll area extends under bottom inset',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final heroArts = ValueNotifier<List<HeroArt>>(const []);
      final heroPosition = ValueNotifier(0.0);
      addTearDown(heroArts.dispose);
      addTearDown(heroPosition.dispose);
      const lastContentKey = ValueKey<String>('home-last-content');

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.only(bottom: 34),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: Scaffold(
              body: HomePageScaffold(
                heroArts: heroArts,
                heroPosition: heroPosition,
                heroReady: false,
                hero: const SizedBox.shrink(),
                heroFallback: const SizedBox(height: 100),
                onRefresh: () async {},
                heroMaxHeight: 400,
                slivers: const [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 700,
                      child: ColoredBox(key: lastContentKey, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final scaffold = tester.getRect(find.byType(Scaffold));
      final safeArea = find.byType(SafeArea).first;
      expect(tester.getRect(safeArea).bottom, scaffold.bottom);

      final scrollView = find.byType(CustomScrollView);
      await tester.drag(scrollView, const Offset(0, -2000));
      await tester.pumpAndSettle();

      final lastContent = tester.getRect(find.byKey(lastContentKey));
      expect(lastContent.bottom, lessThanOrEqualTo(scaffold.bottom - 100));
      expect(lastContent.top, lessThan(scaffold.bottom));
    },
  );
}
