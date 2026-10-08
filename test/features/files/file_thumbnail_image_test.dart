import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/files/file_thumbnail_image.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets('首帧才淡入，重建与缓存命中不重播（减少动态效果：$reducedMotion）', (tester) async {
      final provider = MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
        ),
      );
      final firstFrame = Completer<ImageInfo>();
      PaintingBinding.instance.imageCache.putIfAbsent(
        provider,
        () => OneFrameImageStreamCompleter(firstFrame.future),
      );
      addTearDown(provider.evict);
      Widget preview(ImageProvider? image) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Center(
            child: SizedBox(
              width: 96,
              height: 54,
              child: FileThumbnailImage(
                image: image,
                placeholder: const ColoredBox(
                  key: ValueKey('placeholder'),
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(preview(provider));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
      expect(find.byType(RawImage), findsNothing);

      final decoded = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(2, 2);
        picture.dispose();
        return image;
      });
      firstFrame.complete(ImageInfo(image: decoded!));
      await tester.pump();
      await tester.pump();
      final fade = find
          .ancestor(
            of: find.byType(RawImage),
            matching: find.byType(FadeTransition),
          )
          .first;
      double opacity() => tester.widget<FadeTransition>(fade).opacity.value;
      if (!reducedMotion) {
        expect(opacity(), 0);
        await tester.pump(const Duration(milliseconds: 60));
        expect(opacity(), allOf(greaterThan(0), lessThan(1)));
        final inProgress = opacity();
        await tester.pumpWidget(preview(provider));
        expect(opacity(), inProgress);
        await tester.pump(const Duration(milliseconds: 120));
      } else {
        await tester.pump();
      }
      expect(opacity(), 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('placeholder')), findsNothing);
      await tester.pumpWidget(preview(provider));
      expect(opacity(), 1);

      // 清除当前来源后不保留旧画面；再次挂载已解码缓存图无需重新淡入。
      await tester.pumpWidget(preview(null));
      expect(find.byType(RawImage), findsNothing);
      await tester.pumpWidget(preview(provider));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(find.byType(AnimatedSwitcher), findsNothing);
      expect(find.byKey(const ValueKey('placeholder')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
