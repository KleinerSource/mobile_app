import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/main/media_manager_shell.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

void main() {
  testWidgets('媒体管理器首页长按可打开服务器快捷切换菜单', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const firstLine = ServerLine(
      id: 'media-server-one-line',
      name: '主线路',
      baseUrl: 'https://media-one.example',
    );
    const secondLine = ServerLine(
      id: 'media-server-two-line',
      name: '主线路',
      baseUrl: 'https://media-two.example',
    );
    final firstServer = const ServerProfile(
      id: 'media-server-one',
      name: '媒体服务器一',
      lines: [firstLine],
      activeLineId: 'media-server-one-line',
      projectName: 'db_online',
    );
    final secondServer = const ServerProfile(
      id: 'media-server-two',
      name: '媒体服务器二',
      lines: [secondLine],
      activeLineId: 'media-server-two-line',
      projectName: 'db_online',
    );
    final config = ServerConfig(
      baseUrl: 'https://media-one.example',
      lines: const [firstLine],
      servers: [firstServer, secondServer],
      activeServerId: firstServer.id,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverConfigProvider.overrideWith(() => _ServerConfigState(config)),
          dbOnlineRecommendProvider.overrideWith(
            (ref) async => const <DbOnlineMovie>[],
          ),
          dbOnlineLatestUpdatedProvider.overrideWith(
            (ref) async => const <DbOnlineMovie>[],
          ),
          dbOnlineLatestReleasedProvider.overrideWith(
            (ref) async => const <DbOnlineMovie>[],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: MediaManagerShell(),
        ),
      ),
    );
    await tester.pump();

    final tabBar = tester.widget<FloatingTabBar<Object?>>(
      find.byType(FloatingTabBar<Object?>),
    );
    expect(tabBar.tabs.first.quickMenuEntries, hasLength(2));

    final homeIcon = find.descendant(
      of: find.byType(FloatingTabBar<Object?>),
      matching: find.byIcon(Icons.home_rounded),
    );
    final homeAnchor = find.ancestor(
      of: homeIcon,
      matching: find.byType(GlassMenuAnchor<Object?>),
    );
    expect(homeAnchor, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(homeAnchor));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    expect(find.text('媒体服务器二'), findsOneWidget);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
