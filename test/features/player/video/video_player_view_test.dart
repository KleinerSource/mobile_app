import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/video/video_player_view.dart';

void main() {
  testWidgets('视频缓冲时显示提示并且不拦截播放器手势', (tester) async {
    final buffering = ValueNotifier(true);
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: buffering,
            builder: (_, isBuffering, __) => Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapped = true,
                  child: const SizedBox.expand(),
                ),
                if (isBuffering)
                  const Positioned.fill(child: VideoPlayerBufferingView()),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('正在缓冲…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    expect(tapped, isTrue);

    buffering.value = false;
    await tester.pump();

    expect(find.text('正在缓冲…'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    buffering.dispose();
  });
}
