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

IconData fileIconFor(FileEntry entry) {
  return switch (fileTypeIconFor(entry)) {
    FileTypeIcon.text => Icons.description_outlined,
    FileTypeIcon.video => Icons.movie_outlined,
    FileTypeIcon.image => Icons.image_outlined,
    FileTypeIcon.subtitle => Icons.closed_caption_outlined,
    FileTypeIcon.other =>
      (entry.mimeType?.trim().toLowerCase().startsWith('audio/') ?? false)
          ? Icons.music_note_outlined
          : Icons.insert_drive_file_outlined,
  };
}

Color fileIconColorFor(FileEntry entry, Brightness brightness) {
  final hue = switch (fileTypeIconFor(entry)) {
    FileTypeIcon.text => AppHues.sky,
    FileTypeIcon.video => AppHues.coral,
    FileTypeIcon.image => AppHues.mint,
    FileTypeIcon.subtitle => AppHues.solar,
    FileTypeIcon.other => AppHues.lavender,
  };
  return AppHues.chipText(hue, brightness);
}
