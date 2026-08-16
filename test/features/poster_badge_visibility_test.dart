import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/features/i18n/poster_badge_visibility_provider.dart';
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

    expect(
      container.read(posterBadgeVisibilityProvider).hdr,
      isFalse,
    );
    expect(prefs.getString('app.posterBadgeVisibility'), contains('"hdr":false'));
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

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(find.text('HEVC'), findsNothing);
  });
}
