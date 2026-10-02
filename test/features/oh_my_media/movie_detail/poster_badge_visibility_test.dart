import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/i18n/poster_badge_visibility_provider.dart';
import 'package:omm/features/settings/poster_badge_display_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: PosterBadgeDisplayPage(),
        ),
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

}
