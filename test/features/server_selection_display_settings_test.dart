import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/system.dart';
import 'package:omm/features/settings/app_settings_page.dart';
import 'package:omm/features/settings/server_selection_display_settings.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('连接页显示设置默认开启、可独立修改并持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(serverSelectionShowUsernameProvider), isTrue);
    expect(container.read(serverSelectionShowAvatarProvider), isTrue);

    await container
        .read(serverSelectionShowUsernameProvider.notifier)
        .setEnabled(false);
    expect(container.read(serverSelectionShowUsernameProvider), isFalse);
    expect(container.read(serverSelectionShowAvatarProvider), isTrue);
    expect(
      prefs.getBool(ServerSelectionShowUsernameNotifier.preferenceKey),
      isFalse,
    );

    await container
        .read(serverSelectionShowAvatarProvider.notifier)
        .setEnabled(false);
    expect(container.read(serverSelectionShowAvatarProvider), isFalse);
    expect(
      prefs.getBool(ServerSelectionShowAvatarNotifier.preferenceKey),
      isFalse,
    );

    final restored = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(restored.dispose);
    expect(restored.read(serverSelectionShowUsernameProvider), isFalse);
    expect(restored.read(serverSelectionShowAvatarProvider), isFalse);
  });

  test('用户头像地址仅保留在运行时资料，不写入资料缓存 JSON', () {
    const profile = ServerProfileData(
      name: 'Alice',
      avatarUrl: 'https://server.example/logo.png',
      userAvatarUrl:
          'https://server.example/Users/alice/Images/Primary?ApiKey=secret',
    );

    expect(profile.toJson(), {
      'name': 'Alice',
      'avatar_url': 'https://server.example/logo.png',
    });
  });

  testWidgets('应用设置通用分组显示并可分别切换两个开关', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: AppSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final usernameText = find.text('连接页显示用户名');
    final avatarText = find.text('连接页显示用户头像');
    expect(usernameText, findsOneWidget);
    expect(avatarText, findsOneWidget);

    final usernameTile = find.ancestor(
      of: usernameText,
      matching: find.byType(SettingsTile),
    );
    final avatarTile = find.ancestor(
      of: avatarText,
      matching: find.byType(SettingsTile),
    );
    final usernameSwitch = find.descendant(
      of: usernameTile,
      matching: find.byType(SettingsSwitch),
    );
    final avatarSwitch = find.descendant(
      of: avatarTile,
      matching: find.byType(SettingsSwitch),
    );
    expect(usernameSwitch, findsOneWidget);
    expect(avatarSwitch, findsOneWidget);

    await tester.ensureVisible(usernameSwitch);
    await tester.tap(usernameSwitch);
    await tester.pump();
    expect(
      prefs.getBool(ServerSelectionShowUsernameNotifier.preferenceKey),
      isFalse,
    );
    expect(
      prefs.getBool(ServerSelectionShowAvatarNotifier.preferenceKey),
      isNull,
    );

    await tester.ensureVisible(avatarSwitch);
    await tester.tap(avatarSwitch);
    await tester.pump();
    expect(
      prefs.getBool(ServerSelectionShowAvatarNotifier.preferenceKey),
      isFalse,
    );
  });
}
