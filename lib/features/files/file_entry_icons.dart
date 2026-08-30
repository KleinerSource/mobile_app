import 'package:flutter/material.dart';

import '../../core/platform/app_theme.dart';
import '../../core/sources/files/file_entry.dart';

/// 文件类型图标与配色工具。文件浏览页与收藏列表页共用。
enum FileTypeIcon { text, video, image, subtitle, other }

const _videoFileExtensions = <String>{
  'mp4',
  'mkv',
  'webm',
  'mov',
  'avi',
  'm4v',
  'ts',
  'm2ts',
  'm3u8',
};

const _imageFileExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
};

const _subtitleFileExtensions = <String>{
  'srt',
  'vtt',
  'ass',
  'ssa',
  'sub',
  'idx',
  'sup',
  'smi',
  'sami',
  'ttml',
};

const _textFileExtensions = <String>{
  'txt',
  'json',
  'csv',
  'xml',
  'html',
  'htm',
  'css',
  'js',
  'ts',
  'yaml',
  'yml',
  'md',
  'log',
};

FileTypeIcon fileTypeIconFor(FileEntry entry) {
  final mime = entry.mimeType?.trim().toLowerCase() ?? '';
  final extension = fileExtensionFor(entry.name);

  if (_isSubtitleMimeType(mime) ||
      _subtitleFileExtensions.contains(extension)) {
    return FileTypeIcon.subtitle;
  }
  if (mime.startsWith('video/') || _videoFileExtensions.contains(extension)) {
    return FileTypeIcon.video;
  }
  if (mime.startsWith('image/') || _imageFileExtensions.contains(extension)) {
    return FileTypeIcon.image;
  }
  if (mime.startsWith('text/') ||
      mime == 'application/json' ||
      mime == 'application/xml' ||
      mime == 'application/javascript' ||
      _textFileExtensions.contains(extension)) {
    return FileTypeIcon.text;
  }
  return FileTypeIcon.other;
}

bool _isSubtitleMimeType(String mime) =>
    mime == 'text/vtt' ||
    mime == 'application/x-subrip' ||
    mime == 'application/ttml+xml' ||
    mime == 'application/ass' ||
    mime == 'application/x-ass' ||
    mime == 'text/x-ssa';

String? fileExtensionFor(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1).toLowerCase();
}

/// 文件条目的现代化图标徽章。
///
/// 用统一的圆角色块承载文件类型图标，收藏状态以左上角浮动星标表示。
/// [child] 用于在同一徽章中承载图片缩略图。
class FileEntryIconBadge extends StatelessWidget {
  const FileEntryIconBadge({
    super.key,
    required this.entry,
    this.child,
    this.isFavorite = false,
    this.width = 44,
    this.height = 44,
  });

  final FileEntry entry;
  final Widget? child;
  final bool isFavorite;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = appColors(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = fileIconColorFor(entry, theme.brightness);
    final radius = width >= 60 ? 12.0 : 14.0;
    final badge = DecoratedBox(
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: isDark ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: iconColor.withValues(alpha: isDark ? 0.34 : 0.18),
        ),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child:
            child ??
            Center(
              child: Icon(
                entry.isDirectory ? Icons.folder_rounded : fileIconFor(entry),
                color: iconColor,
                size: width >= 60 ? 24 : 22,
              ),
            ),
      ),
    );

    if (!isFavorite) return badge;

    final starColor = AppHues.chipText(AppHues.solar, theme.brightness);
    final starSurface = isDark ? const Color(0xFF2C293A) : Colors.white;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        badge,
        Positioned(
          left: -5,
          top: -5,
          child: Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              color: starSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: c.bg.withValues(alpha: isDark ? 0.9 : 0.75),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(Icons.star_rounded, color: starColor, size: 13),
          ),
        ),
      ],
    );
  }
}

IconData fileIconFor(FileEntry entry) {
  return switch (fileTypeIconFor(entry)) {
    FileTypeIcon.text => Icons.article_rounded,
    FileTypeIcon.video => Icons.movie_rounded,
    FileTypeIcon.image => Icons.photo_rounded,
    FileTypeIcon.subtitle => Icons.subtitles_rounded,
    FileTypeIcon.other =>
      (entry.mimeType?.trim().toLowerCase().startsWith('audio/') ?? false)
          ? Icons.audio_file_rounded
          : Icons.insert_drive_file_rounded,
  };
}

Color fileIconColorFor(FileEntry entry, Brightness brightness) {
  final hue = entry.isDirectory
      ? AppHues.sky
      : switch (fileTypeIconFor(entry)) {
          FileTypeIcon.text => AppHues.sky,
          FileTypeIcon.video => AppHues.coral,
          FileTypeIcon.image => AppHues.mint,
          FileTypeIcon.subtitle => AppHues.solar,
          FileTypeIcon.other => AppHues.lavender,
        };
  return AppHues.chipText(hue, brightness);
}
