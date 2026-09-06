import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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
