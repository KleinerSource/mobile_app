import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/sources/files/file_entry.dart';
import 'file_entry_icons.dart';
import 'file_thumbnail_loader.dart';

class FileImageThumbnail extends StatefulWidget {
  const FileImageThumbnail({
    super.key,
    required this.entry,
    required this.loader,
    required this.download,
  });

  final FileEntry entry;
  final FileThumbnailLoader loader;
  final FileThumbnailDownload download;

  @override
  State<FileImageThumbnail> createState() => _FileImageThumbnailState();
}

class _FileImageThumbnailState extends State<FileImageThumbnail> {
  late FileThumbnailRequest _request;
  ImageProvider? _image;

  void _release() {
    _request.release();
    final image = _image;
    _image = null;
    // MemoryImage 的缓存键持有原始字节，条目退出时也要从全局图片缓存移除。
    if (image != null) unawaited(image.evict());
  }

  @override
  void initState() {
    super.initState();
    _request = widget.loader.load(widget.download);
  }

  @override
  void didUpdateWidget(covariant FileImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.path != widget.entry.path ||
        oldWidget.entry.size != widget.entry.size ||
        oldWidget.entry.modifiedAt != widget.entry.modifiedAt ||
        oldWidget.loader != widget.loader) {
      _release();
      _request = widget.loader.load(widget.download);
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: fileEntryPreviewIconWidth,
      height: fileEntryPreviewIconHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FutureBuilder<Uint8List?>(
          key: ObjectKey(_request),
          future: _request.bytes,
          builder: (context, snapshot) {
            final data = snapshot.connectionState == ConnectionState.done
                ? snapshot.data
                : null;
            if (data == null || data.isEmpty) {
              return FileEntryIconPlaceholder(entry: widget.entry);
            }
            final image = ResizeImage(
              MemoryImage(data),
              width: (fileEntryPreviewIconWidth * pixelRatio).ceil(),
              height: (fileEntryPreviewIconHeight * pixelRatio).ceil(),
            );
            if (_image != image) {
              final previous = _image;
              _image = image;
              if (previous != null) unawaited(previous.evict());
            }
            return Image(
              image: image,
              width: fileEntryPreviewIconWidth,
              height: fileEntryPreviewIconHeight,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  FileEntryIconPlaceholder(entry: widget.entry),
            );
          },
        ),
      ),
    );
  }
}
