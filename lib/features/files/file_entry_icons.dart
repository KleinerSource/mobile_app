import 'package:flutter/material.dart';

import '../../core/platform/app_theme.dart';
import '../../core/sources/files/file_entry.dart';

/// 文件类型图标与配色工具。文件浏览页与收藏列表页共用。
enum FileTypeIcon {
  text,
  video,
  image,
  archive,
  pdf,
  presentation,
  spreadsheet,
  document,
  audio,
  code,
  other,
}

const _videoFileExtensions = <String>{
  'mp4',
  'mkv',
  'webm',
  'mov',
  'avi',
  'm4v',
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

const _textFileExtensions = <String>{'txt', 'csv', 'md', 'log'};

const _codeFileExtensions = <String>{
  'json',
  'yaml',
  'yml',
  'toml',
  'ini',
  'conf',
  'config',
  'env',
  'properties',
  'xml',
  'html',
  'htm',
  'css',
  'scss',
  'sass',
  'less',
  'js',
  'jsx',
  'ts',
  'tsx',
  'dart',
  'java',
  'kt',
  'kts',
  'swift',
  'py',
  'rb',
  'go',
  'rs',
  'c',
  'h',
  'cc',
  'cpp',
  'cxx',
  'hpp',
  'cs',
  'php',
  'sh',
  'bash',
  'zsh',
  'fish',
  'ps1',
  'bat',
  'cmd',
  'sql',
  'vue',
  'svelte',
};

const _archiveFileExtensions = <String>{
  'zip',
  'rar',
  '7z',
  'cab',
  'tar',
  'gz',
  'gzip',
  'bz2',
  'bzip2',
  'xz',
  'tgz',
  'tbz',
  'tbz2',
  'z',
  'lzh',
  'arj',
  'ace',
  'jar',
};

const _pdfFileExtensions = <String>{'pdf'};

const _presentationFileExtensions = <String>{
  'ppt',
  'pptx',
  'pptm',
  'pps',
  'ppsx',
  'ppsm',
  'pot',
  'potx',
  'potm',
  'odp',
};

const _spreadsheetFileExtensions = <String>{
  'xls',
  'xlsx',
  'xlsm',
  'xlsb',
  'xlt',
  'xltx',
  'xltm',
  'ods',
};

const _documentFileExtensions = <String>{
  'doc',
  'docx',
  'docm',
  'dot',
  'dotx',
  'dotm',
  'odt',
  'rtf',
};

const _audioFileExtensions = <String>{
  'mp3',
  'm4a',
  'aac',
  'flac',
  'wav',
  'ogg',
  'oga',
  'opus',
  'wma',
  'aif',
  'aiff',
  'ape',
  'alac',
  'amr',
  'mid',
  'midi',
};

const _archiveMimeTypes = <String>{
  'application/zip',
  'application/x-zip-compressed',
  'application/vnd.rar',
  'application/x-rar-compressed',
  'application/x-7z-compressed',
  'application/vnd.ms-cab-compressed',
  'application/x-cab',
  'application/x-tar',
  'application/gzip',
  'application/x-gzip',
  'application/x-bzip2',
  'application/x-xz',
  'application/java-archive',
  'application/vnd.android.package-archive',
};

const _presentationMimeTypes = <String>{
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/vnd.openxmlformats-officedocument.presentationml.slideshow',
  'application/vnd.ms-powerpoint.presentation.macroenabled.12',
  'application/vnd.ms-powerpoint.slideshow.macroenabled.12',
  'application/vnd.oasis.opendocument.presentation',
};

const _spreadsheetMimeTypes = <String>{
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-excel.sheet.macroenabled.12',
  'application/vnd.ms-excel.sheet.binary.macroenabled.12',
  'application/vnd.oasis.opendocument.spreadsheet',
};

const _documentMimeTypes = <String>{
  'application/msword',
  'application/vnd.ms-word',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.template',
  'application/vnd.ms-word.document.macroenabled.12',
  'application/vnd.oasis.opendocument.text',
  'application/rtf',
  'text/rtf',
};

const _codeMimeTypes = <String>{
  'application/json',
  'application/ld+json',
  'application/javascript',
  'application/x-javascript',
  'text/javascript',
  'application/yaml',
  'application/x-yaml',
  'text/yaml',
  'text/x-yaml',
  'application/toml',
  'text/x-toml',
  'application/xml',
};

const _folderPlaceholderAsset = 'assets/file_icons/folder_placeholder.png';
const _documentPlaceholderAsset = 'assets/file_icons/document_placeholder.png';
const _videoPlaceholderAsset = 'assets/file_icons/video_placeholder.png';
const _imagePlaceholderAsset = 'assets/file_icons/image_placeholder.png';
const _unknownPlaceholderAsset = 'assets/file_icons/unknown_placeholder.png';
const _videoFileIconAsset = 'assets/file_icons/video_file_icon.png';
const _textFileIconAsset = 'assets/file_icons/text_file_icon.png';
const _imageFileIconAsset = 'assets/file_icons/image_file_icon.png';
const _archiveFileIconAsset = 'assets/file_icons/archive_file_icon.png';
const _pdfFileIconAsset = 'assets/file_icons/pdf_file_icon.png';
const _presentationFileIconAsset =
    'assets/file_icons/presentation_file_icon.png';
const _spreadsheetFileIconAsset = 'assets/file_icons/spreadsheet_file_icon.png';
const _documentFileIconAsset = 'assets/file_icons/document_file_icon.png';
const _audioFileIconAsset = 'assets/file_icons/audio_file_icon.png';
const _codeFileIconAsset = 'assets/file_icons/code_file_icon.png';

const fileEntryPreviewIconWidth = 64.0;
const fileEntryPreviewIconHeight = 36.0;

FileTypeIcon fileTypeIconFor(FileEntry entry) {
  final mime = entry.mimeType?.trim().toLowerCase() ?? '';
  final extension = fileExtensionFor(entry.name);

  if (extension == 'nfo') return FileTypeIcon.other;
  if (_isSubtitleMimeType(mime) ||
      _subtitleFileExtensions.contains(extension)) {
    return FileTypeIcon.text;
  }
  if (mime.startsWith('video/') || _videoFileExtensions.contains(extension)) {
    return FileTypeIcon.video;
  }
  if (mime.startsWith('image/') || _imageFileExtensions.contains(extension)) {
    return FileTypeIcon.image;
  }
  if (_archiveMimeTypes.contains(mime) ||
      _archiveFileExtensions.contains(extension)) {
    return FileTypeIcon.archive;
  }
  if (mime == 'application/pdf' || _pdfFileExtensions.contains(extension)) {
    return FileTypeIcon.pdf;
  }
  if (_presentationMimeTypes.contains(mime) ||
      _presentationFileExtensions.contains(extension)) {
    return FileTypeIcon.presentation;
  }
  if (_spreadsheetMimeTypes.contains(mime) ||
      _spreadsheetFileExtensions.contains(extension)) {
    return FileTypeIcon.spreadsheet;
  }
  if (_documentMimeTypes.contains(mime) ||
      _documentFileExtensions.contains(extension)) {
    return FileTypeIcon.document;
  }
  if (mime.startsWith('audio/') || _audioFileExtensions.contains(extension)) {
    return FileTypeIcon.audio;
  }
  if (_codeMimeTypes.contains(mime) ||
      _codeFileExtensions.contains(extension)) {
    return FileTypeIcon.code;
  }
  if (mime.startsWith('text/') || _textFileExtensions.contains(extension)) {
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

/// 文件条目的图标容器。
///
/// 仅提供统一尺寸约束和收藏状态浮标，不额外叠加背景、边框或圆角外壳。
/// [child] 用于承载文件图标或图片缩略图。
class FileEntryIconBadge extends StatelessWidget {
  const FileEntryIconBadge({
    super.key,
    required this.entry,
    required this.child,
    this.isFavorite = false,
    this.width = 44,
    this.height = 44,
  });

  final FileEntry entry;
  final Widget child;
  final bool isFavorite;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = appColors(context);
    final isDark = theme.brightness == Brightness.dark;
    final badge = SizedBox(width: width, height: height, child: child);

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

class FileEntryIconAsset extends StatelessWidget {
  const FileEntryIconAsset({super.key, required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}

/// 图片预览模式下使用的文件类型占位图。
class FileEntryIconPlaceholder extends StatelessWidget {
  const FileEntryIconPlaceholder({super.key, required this.entry});

  final FileEntry entry;

  @override
  Widget build(BuildContext context) {
    return FileEntryIconAsset(assetPath: fileIconPlaceholderAssetFor(entry));
  }
}

String fileIconPlaceholderAssetFor(FileEntry entry) {
  if (entry.isDirectory) return _folderPlaceholderAsset;
  return switch (fileTypeIconFor(entry)) {
    FileTypeIcon.video => _videoPlaceholderAsset,
    FileTypeIcon.image => _imagePlaceholderAsset,
    FileTypeIcon.text ||
    FileTypeIcon.archive ||
    FileTypeIcon.pdf ||
    FileTypeIcon.presentation ||
    FileTypeIcon.spreadsheet ||
    FileTypeIcon.document ||
    FileTypeIcon.audio ||
    FileTypeIcon.code => _documentPlaceholderAsset,
    FileTypeIcon.other => _unknownPlaceholderAsset,
  };
}

/// 关闭图片预览时使用的类型图标；未知类型使用统一未知图标。
String fileIconAssetWhenPreviewDisabledFor(FileEntry entry) {
  if (entry.isDirectory) return _folderPlaceholderAsset;
  return switch (fileTypeIconFor(entry)) {
    FileTypeIcon.video => _videoFileIconAsset,
    FileTypeIcon.text => _textFileIconAsset,
    FileTypeIcon.image => _imageFileIconAsset,
    FileTypeIcon.archive => _archiveFileIconAsset,
    FileTypeIcon.pdf => _pdfFileIconAsset,
    FileTypeIcon.presentation => _presentationFileIconAsset,
    FileTypeIcon.spreadsheet => _spreadsheetFileIconAsset,
    FileTypeIcon.document => _documentFileIconAsset,
    FileTypeIcon.audio => _audioFileIconAsset,
    FileTypeIcon.code => _codeFileIconAsset,
    FileTypeIcon.other => _unknownPlaceholderAsset,
  };
}
