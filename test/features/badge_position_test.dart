import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/features/i18n/badge_position_provider.dart';
import 'package:omm/features/settings/badge_position_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('旧版全局偏移会迁移到四个角落', () {
    final positions = BadgePositions.fromJson(const {
      'horizontalOffset': 5,
      'verticalOffset': -3,
    });

    for (final corner in BadgeCorner.values) {
      final offset = positions.offsetOf(corner);
      expect(offset.horizontal, 5);
      expect(offset.vertical, -3);
    }
    expect(positions.newResources, BadgeCorner.topRight);
    expect(positions.newResourcesEnabled, isTrue);
  });

  test('新资源角落和四角偏移可以独立持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(badgePositionsProvider.notifier);
    await notifier.setKind(BadgeKind.newResources, BadgeCorner.bottomLeft);
    await notifier.setHorizontalOffset(BadgeCorner.bottomLeft, 9);
    await notifier.setVerticalOffset(BadgeCorner.bottomLeft, -4);

    final positions = container.read(badgePositionsProvider);
    expect(positions.newResources, BadgeCorner.bottomLeft);
    expect(positions.offsetOf(BadgeCorner.bottomLeft).horizontal, 9);
    expect(positions.offsetOf(BadgeCorner.bottomLeft).vertical, -4);
    expect(positions.offsetOf(BadgeCorner.topRight).horizontal, 0);
    expect(positions.offsetOf(BadgeCorner.topRight).vertical, 0);

    final saved =
        jsonDecode(prefs.getString('app.badgePositions')!)
            as Map<String, dynamic>;
    expect(saved['newResources'], 'bl');
    expect(saved['cornerOffsets']['bl']['horizontal'], 9);
    expect(saved['cornerOffsets']['bl']['vertical'], -4);
  });

  testWidgets('新资源图标使用对应角落的独立偏移', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
      'app.badgePositions': jsonEncode(
        const BadgePositions(
          newResources: BadgeCorner.bottomLeft,
          bottomLeftOffset: BadgeCornerOffset(horizontal: 10, vertical: -2),
        ).toJson(),
      ),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                child: MovieCard(
                  movie: const MovieListItem(
                    id: 1,
                    title: 'A',
                    hasNewResources: true,
                  ),
                  posterUrlBuilder: (_) => '',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final icon = find.byIcon(Icons.auto_awesome_rounded);
    expect(icon, findsOneWidget);
    final positioned = tester.widget<Positioned>(
      find.ancestor(of: icon, matching: find.byType(Positioned)),
    );
    expect(positioned.left, 16);
    expect(positioned.bottom, 4);
    expect(positioned.top, isNull);
    expect(positioned.right, isNull);
  });

  testWidgets('角标预览固定在设置列表顶部', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: BadgePositionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final preview = find.byType(MovieCard);
    expect(preview, findsOneWidget);
    final initialTop = tester.getTopLeft(preview).dy;
    final scrollable = find.byType(Scrollable);
    final scrollState = tester.state<ScrollableState>(scrollable);
    expect(scrollState.position.maxScrollExtent, greaterThan(0));

    scrollState.position.jumpTo(
      scrollState.position.maxScrollExtent < 500
          ? scrollState.position.maxScrollExtent
          : 500,
    );
    await tester.pump();

    expect(find.text('左右'), findsWidgets);
    final labelCenter = tester.getCenter(find.text('左右').first).dy;
    final sliderCenter = tester.getCenter(find.byType(Slider).first).dy;
    final valueCenter = tester.getCenter(find.text('0').first).dy;
    expect(labelCenter, closeTo(sliderCenter, 1));
    expect(valueCenter, closeTo(sliderCenter, 1));

    expect(tester.getTopLeft(preview).dy, initialTop);
  });
}
