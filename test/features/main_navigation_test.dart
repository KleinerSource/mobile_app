import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_source_providers.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/files/file_manager_shell.dart';
import 'package:omm/features/main/media_manager_shell.dart';
import 'package:omm/features/settings/server_selection_page.dart';
import 'package:omm/features/security/security_providers.dart';
import 'package:omm/features/security/security_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/main.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

class _AuthenticatedAuthState extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState(phase: AuthPhase.authenticated);
}

class _UnlockedSecurityState extends SecurityController {
  @override
  Future<SecuritySettings> build() async => const SecuritySettings.empty();
}

void main() {
  testWidgets('媒体首页长按滑动选择文件服务器不会回到服务器选择器', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const mediaLine = ServerLine(
      id: 'media-line',
      name: '媒体线路',
      baseUrl: 'https://media.example',
    );
    const fileLine = ServerLine(
      id: 'file-line',
      name: '文件线路',
      baseUrl: 'smb://file.example/share',
    );
    final mediaServer = ServerProfile(
      id: 'media-server',
      name: '媒体服务器',
      lines: const [mediaLine],
      activeLineId: mediaLine.id,
      projectName: 'db_online',
    );
    final fileServer = ServerProfile(
      id: 'file-server',
      name: '文件服务器',
      lines: const [fileLine],
      activeLineId: fileLine.id,
      projectName: 'smb',
    );
    final config = ServerConfig(
      baseUrl: mediaLine.baseUrl,
      lines: const [mediaLine],
      servers: [mediaServer, fileServer],
      activeServerId: mediaServer.id,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverConfigProvider.overrideWith(() => _ServerConfigState(config)),
          authControllerProvider.overrideWith(_AuthenticatedAuthState.new),
          securityControllerProvider.overrideWith(_UnlockedSecurityState.new),
          dbOnlineRecommendProvider.overrideWith(
            (ref) async => const <DbOnlineMovie>[],
          ),
          dbOnlineLatestUpdatedProvider.overrideWith(
            (ref) async => const <DbOnlineMovie>[],
          ),
          dbOnlineLatestReleasedProvider.overrideWith(
            (ref) async => const <DbOnlineMovie>[],
          ),
          fileSourceDescriptorsProvider('file-server').overrideWith(
            (ref) async => [
              const SourceDescriptor(
                id: SourceId('file-source'),
                kind: SourceKind.smb,
                name: '测试文件来源',
                serverId: 'file-server',
                endpoint: 'smb://file.example/share',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: OmmApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(MediaManagerShell), findsOneWidget);
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
    final fileServerEntry = find.text('文件服务器').last;
    expect(fileServerEntry, findsOneWidget);
    await gesture.moveTo(tester.getCenter(fileServerEntry));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(FileManagerShell), findsOneWidget);
    expect(find.byType(MediaManagerShell), findsNothing);
    expect(
      find.byType(ServerSelectionPage, skipOffstage: false),
      findsOneWidget,
    );
  });
}
