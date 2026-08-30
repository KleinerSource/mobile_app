import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/video/player_engine_picker.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('播放器测试选择器显示两个内核并返回选择结果', (tester) async {
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
                    PlaybackEngineKind.ksPlayer,
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
    expect(find.text('KSPlayer'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    await tester.tap(find.byKey(const ValueKey('player-engine-ksplayer')));
    await tester.pumpAndSettle();

    expect(selected, PlaybackEngineKind.ksPlayer);
  });

  testWidgets('默认播放器排在最前并显示「默认」角标', (tester) async {
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
                    PlaybackEngineKind.ksPlayer,
                  ],
                  defaultEngineKind: PlaybackEngineKind.ksPlayer,
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
    expect(find.text('默认'), findsOneWidget);

    // KSPlayer 是默认内核，应排在 libmpv 前面。
    final ksPlayerCenter = tester.getCenter(
      find.byKey(const ValueKey('player-engine-ksplayer')),
    );
    final libmpvCenter = tester.getCenter(
      find.byKey(const ValueKey('player-engine-libmpv')),
    );
    expect(ksPlayerCenter.dy, lessThan(libmpvCenter.dy));

    // 「默认」角标应位于 KSPlayer 条目上。
    final badgeCenter = tester.getCenter(find.text('默认'));
    final ksPlayerRect = tester.getRect(
      find.byKey(const ValueKey('player-engine-ksplayer')),
    );
    expect(ksPlayerRect.contains(badgeCenter), isTrue);

    await tester.tap(find.byKey(const ValueKey('player-engine-libmpv')));
    await tester.pumpAndSettle();

    expect(selected, PlaybackEngineKind.libmpv);
  });
}
