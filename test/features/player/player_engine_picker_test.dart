import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/features/player/playback_engine.dart';
import 'package:md_center/features/player/player_engine_picker.dart';
import 'package:md_center/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('播放器测试选择器显示两个本地化内核并返回选择结果', (tester) async {
    PlaybackEngineKind? selected;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await showPlaybackEnginePicker(
                  context,
                  engineKinds: const [
                    PlaybackEngineKind.libmpv,
                    PlaybackEngineKind.avPlayer,
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('选择播放器'), findsOneWidget);
    expect(find.text('仅用于本次播放，不会修改默认设置'), findsOneWidget);
    expect(find.text('libmpv'), findsOneWidget);
    expect(find.text('原生'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player-engine-avplayer')));
    await tester.pumpAndSettle();

    expect(selected, PlaybackEngineKind.avPlayer);
  });
}
