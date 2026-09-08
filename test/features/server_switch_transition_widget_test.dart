import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/home/server_switch_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('服务器切换转场可以同时创建多个动画控制器', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ServerSwitchTransitionOverlay()),
      ),
    );

    expect(find.byType(ServerSwitchTransitionOverlay), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
