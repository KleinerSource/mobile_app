import 'package:flutter_test/flutter_test.dart';

import 'package:omm/shared/preview/preview_scrub_controller.dart';

void main() {
  test('加载期间结束拖动时使用最后位置并在 seek 后续播', () async {
    var ready = false;
    final events = <String>[];
    final seekPositions = <Offset>[];
    final controller = PreviewScrubController(
      ensurePreview: () async => ready = true,
      isReady: () => ready,
      pause: () async => events.add('pause'),
      play: () async => events.add('play'),
      seek: (position) async {
        seekPositions.add(position);
        events.add('seek');
      },
    );

    controller.start(const Offset(12, 0));
    controller.update(const Offset(178, 0));
    controller.end();
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(events, ['pause', 'seek', 'play']);
    expect(seekPositions, [const Offset(178, 0)]);
    controller.dispose();
  });
}
