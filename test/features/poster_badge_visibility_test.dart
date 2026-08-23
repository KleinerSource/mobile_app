import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/features/i18n/poster_badge_visibility_provider.dart';
import 'package:md_center/features/movie_detail/cover_badges.dart';
import 'package:md_center/features/settings/poster_badge_display_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('海报角标默认全部显示', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final visibility = container.read(posterBadgeVisibilityProvider);
    for (final kind in PosterBadgeKind.values) {
      expect(visibility.isEnabled(kind), isTrue);
    }
  });

  test('海报角标显示开关可以持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(posterBadgeVisibilityProvider.notifier)
        .setEnabled(PosterBadgeKind.hdr, false);

    expect(container.read(posterBadgeVisibilityProvider).hdr, isFalse);
    expect(
      prefs.getString('app.posterBadgeVisibility'),
      contains('"hdr":false'),
    );
  });

  testWidgets('海报角标预览会随开关实时更新', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: PosterBadgeDisplayPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HEVC'), findsOneWidget);

    final codecTile = find.byKey(const ValueKey('poster-badge-codec'));
    await tester.scrollUntilVisible(codecTile, 300);
    await tester.tap(
      find.descendant(of: codecTile, matching: find.byType(Switch)),
    );
    await tester.pump();

    expect(find.text('HEVC'), findsNothing);
  });

  testWidgets('海报角标使用彩色背景并以白色显示文字和图标', (tester) async {
    const badge = CoverBadgeSpec(
      PosterBadgeKind.codec,
      'HEVC',
      Color(0xFF059669),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: CoverBadgeRow(badges: [badge])),
        ),
      ),
    );

    final badgeText = tester.widget<Text>(find.text('HEVC'));
    expect(badgeText.style?.color, Colors.white);

    final badgeIcon = tester.widget<Icon>(find.byIcon(Icons.memory_outlined));
    expect(badgeIcon.color, Colors.white);

    final badgeContainer = tester.widget<Container>(
      find.ancestor(of: find.text('HEVC'), matching: find.byType(Container)),
    );
    expect((badgeContainer.decoration! as BoxDecoration).color, badge.color);
  });
}
