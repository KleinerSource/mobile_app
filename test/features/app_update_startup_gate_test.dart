import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/update/update_repository.dart';
import 'package:omm/features/settings/app_update_startup_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('鉴权与安全锁就绪后才执行启动更新检查', (tester) async {
    SharedPreferences.setMockInitialValues({
      UpdateSettingsRepository.githubRepositoryKey:
          'https://github.com/example/mobile_app',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    var checkCount = 0;

    Widget app(bool enabled) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: StartupUpdateGate(
          enabled: enabled,
          startDelay: Duration.zero,
          retryDelays: const [Duration.zero],
          retryAfterFailure: const Duration(hours: 1),
          checkForUpdate: (_, __) async {
            checkCount++;
            return true;
          },
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    await tester.pumpWidget(app(false));
    await tester.pump();
    expect(checkCount, 0);

    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(checkCount, 1);
  });

  testWidgets('更新源在启动门控创建后就绪仍会自动检查', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    var checkCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: StartupUpdateGate(
            enabled: true,
            startDelay: Duration.zero,
            retryDelays: const [Duration.zero],
            retryAfterFailure: const Duration(hours: 1),
            checkForUpdate: (_, __) async {
              checkCount++;
              return true;
            },
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(checkCount, 0);

    await container
        .read(updateRepositoryUrlProvider.notifier)
        .save('https://github.com/example/mobile_app');
    await tester.pumpAndSettle();
    expect(checkCount, 1);
  });
}
