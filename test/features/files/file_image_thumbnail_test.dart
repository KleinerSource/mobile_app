import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/features/files/file_entry_icons.dart';
import 'package:omm/features/files/file_image_thumbnail.dart';
import 'package:omm/features/files/file_thumbnail_loader.dart';

FileEntry _entry() => const FileEntry(
  path: FilePath(sourceId: SourceId('files-1'), value: 'photo.png'),
  name: 'photo.png',
  type: FileEntryType.file,
  size: 68,
);

void main() {
  for (final size in [const Size(512, 256), const Size(256, 512)]) {
    testWidgets('图片 $size 加载前后保持占位轮廓，解码不拉伸', (tester) async {
      final loader = FileThumbnailLoader();
      addTearDown(loader.dispose);
      final download = Completer<Stream<List<int>>>();
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: FileImageThumbnail(
                entry: _entry(),
                loader: loader,
                download: (_) => download.future,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/file_icons/image_placeholder.png'),
          tester.element(find.byType(FileImageThumbnail)),
        );
      });
      await tester.pumpAndSettle();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      expect(boundary.size, const Size(64, 36));
      final before = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData();
        image.dispose();
        return data!;
      });
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        download.complete(Stream.value(bytes!.buffer.asUint8List()));
      });
      await tester.pumpAndSettle();
      final provider = tester.widget<Image>(find.byType(Image)).image;
      await tester.runAsync(() async {
        await precacheImage(provider, tester.element(find.byType(Image)));
      });
      await tester.pumpAndSettle();
      final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
      expect(decoded.width / decoded.height, closeTo(size.aspectRatio, 0.02));
      final after = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData();
        image.dispose();
        return data!;
      });
      var changedPixels = 0;
      for (var i = 3; i < before!.lengthInBytes; i += 4) {
        if ((before.getUint8(i) >= 128) != (after!.getUint8(i) >= 128)) {
          changedPixels++;
        }
      }
      // 允许资源抗锯齿与圆角裁切在边缘有少量像素差异。
      expect(changedPixels / (before.lengthInBytes / 4), lessThan(0.02));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('缩略图按像素比解码，同一文件重建不下载，卸载移除字节缓存键', (tester) async {
    final loader = FileThumbnailLoader();
    addTearDown(loader.dispose);
    var downloads = 0;
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
    );
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: FileImageThumbnail(
            entry: _entry(),
            loader: loader,
            download: (_) async {
              downloads++;
              return Stream.value(bytes);
            },
          ),
        ),
      ),
    );
    await pump();
    await tester.pumpAndSettle();
    final provider =
        tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect(provider.width, (fileEntryPreviewIconWidth * 2).ceil());
    expect(provider.height, (fileEntryPreviewIconHeight * 2).ceil());
    await pump();
    await tester.pumpAndSettle();
    expect(downloads, 1);
    final key = await provider.obtainKey(ImageConfiguration.empty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(PaintingBinding.instance.imageCache.containsKey(key), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('请求未完成时卸载条目取消文件传输', (tester) async {
    final loader = FileThumbnailLoader();
    final stream = StreamController<List<int>>();
    FileCancellationToken? cancellation;
    await tester.pumpWidget(
      MaterialApp(
        home: FileImageThumbnail(
          entry: _entry(),
          loader: loader,
          download: (token) async {
            cancellation = token;
            return stream.stream;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(cancellation!.isCancelled, isTrue);
    await tester.pump();
    unawaited(stream.close());
    await tester.pump();
    loader.dispose();
    expect(tester.takeException(), isNull);
  });
}
