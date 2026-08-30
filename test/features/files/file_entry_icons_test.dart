import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/features/files/file_entry_icons.dart';

void main() {
  FileEntry entry(
    String name, {
    FileEntryType type = FileEntryType.file,
    String? mimeType,
  }) {
    return FileEntry(
      path: FilePath(sourceId: const SourceId('test'), value: name),
      name: name,
      type: type,
      mimeType: mimeType,
    );
  }

  test('preview icon frame uses a 16:9 aspect ratio', () {
    expect(
      fileEntryPreviewIconWidth / fileEntryPreviewIconHeight,
      closeTo(16 / 9, 0.0001),
    );
  });

  test('maps file entries to the supplied placeholder assets', () {
    expect(
      fileIconPlaceholderAssetFor(
        entry('Movies', type: FileEntryType.directory),
      ),
      'assets/file_icons/folder_placeholder.png',
    );
    expect(
      fileIconPlaceholderAssetFor(entry('clip.mp4')),
      'assets/file_icons/video_placeholder.png',
    );
    expect(
      fileIconPlaceholderAssetFor(entry('photo.jpg', mimeType: 'image/jpeg')),
      'assets/file_icons/image_placeholder.png',
    );
    expect(
      fileIconPlaceholderAssetFor(entry('captions.srt')),
      'assets/file_icons/document_placeholder.png',
    );
    expect(
      fileIconPlaceholderAssetFor(entry('mystery.bin')),
      'assets/file_icons/unknown_placeholder.png',
    );
  });

  test('maps compact mode video, text, and image icons', () {
    expect(
      fileIconAssetWhenPreviewDisabledFor(entry('clip.mp4')),
      'assets/file_icons/video_file_icon.png',
    );
    expect(
      fileIconAssetWhenPreviewDisabledFor(entry('notes.txt')),
      'assets/file_icons/text_file_icon.png',
    );
    expect(
      fileIconAssetWhenPreviewDisabledFor(entry('photo.jpg')),
      'assets/file_icons/image_file_icon.png',
    );
    expect(fileIconAssetWhenPreviewDisabledFor(entry('mystery.bin')), isNull);
  });

  test('recognizes common archive, office, and audio file types', () {
    expect(fileTypeIconFor(entry('backup.cab')), FileTypeIcon.archive);
    expect(fileTypeIconFor(entry('backup.zip')), FileTypeIcon.archive);
    expect(fileTypeIconFor(entry('backup.rar')), FileTypeIcon.archive);
    expect(fileTypeIconFor(entry('backup.7z')), FileTypeIcon.archive);
    expect(fileTypeIconFor(entry('manual.pdf')), FileTypeIcon.pdf);
    expect(fileTypeIconFor(entry('slides.pptx')), FileTypeIcon.presentation);
    expect(fileTypeIconFor(entry('budget.xlsm')), FileTypeIcon.spreadsheet);
    expect(fileTypeIconFor(entry('report.docx')), FileTypeIcon.document);
    expect(fileTypeIconFor(entry('song.mp3')), FileTypeIcon.audio);
    expect(
      fileTypeIconFor(entry('unknown', mimeType: 'application/pdf')),
      FileTypeIcon.pdf,
    );
    expect(
      fileTypeIconFor(
        entry(
          'unknown',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ),
      FileTypeIcon.spreadsheet,
    );
  });

  test('maps the new compact file type icons', () {
    expect(
      fileIconAssetWhenPreviewDisabledFor(entry('archive.zip')),
      'assets/file_icons/archive_file_icon.png',
    );
    expect(
      fileIconAssetWhenPreviewDisabledFor(entry('manual.pdf')),
      'assets/file_icons/pdf_file_icon.png',
    );
    expect(
      fileIconAssetWhenPreviewDisabledFor(entry('slides.ppt')),
      'assets/file_icons/presentation_file_icon.png',
    );
    expect(
      fileIconAssetWhenPreviewDisabledFor(entry('budget.xlsx')),
      'assets/file_icons/spreadsheet_file_icon.png',
    );
    expect(
      fileIconAssetWhenPreviewDisabledFor(entry('report.doc')),
      'assets/file_icons/document_file_icon.png',
    );
    expect(
      fileIconAssetWhenPreviewDisabledFor(entry('song.mp3')),
      'assets/file_icons/audio_file_icon.png',
    );
  });
}
