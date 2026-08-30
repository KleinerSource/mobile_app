import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/video/player_error_view.dart';

void main() {
  test('播放错误摘要会压缩空白并截断长堆栈', () {
    const message =
        'PlatformException(code=17,\n\nVideoTracks are not even playable.\nStacktrace: ... )';

    final summary = summarizePlayerError(message, maxLength: 42);

    expect(summary, contains('PlatformException(code=17, VideoTracks'));
    expect(summary, endsWith('…'));
    expect(summary.length, lessThanOrEqualTo(43));
  });

  testWidgets('错误页默认只显示摘要，详情可滚动查看并提供复制导出', (tester) async {
    const message =
        'PlatformException(code=17, VideoTracks are not even playable. '
        'Stacktrace: Runner 0x00000000 ... additional native frames ... '
        'Runner 0x00000001 ... additional native frames ... '
        'Runner 0x00000002 ... additional native frames ... )';
    var copied = false;
    var exported = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerErrorView(
            message: message,
            onRetry: () {},
            onCopy: () async => copied = true,
            onExport: () async => exported = true,
            onExit: () {},
          ),
        ),
      ),
    );

    expect(find.text('播放失败'), findsOneWidget);
    expect(find.text(message), findsNothing);

    await tester.tap(find.text('查看详情'));
    await tester.pumpAndSettle();
    expect(find.text('完整错误详情'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);

    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(copied, isTrue);

    await tester.tap(find.text('查看详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出'));
    await tester.pumpAndSettle();
    expect(exported, isTrue);
  });
}
