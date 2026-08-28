import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/library.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_providers.dart';

void main() {
  group('decodeCoverImageBase64', () {
    test('空值返回 null', () {
      expect(decodeCoverImageBase64(null), isNull);
      expect(decodeCoverImageBase64(''), isNull);
    });

    test('纯 base64 正常解码', () {
      final bytes = decodeCoverImageBase64(base64Encode([1, 2, 3]));
      expect(bytes, isNotNull);
      expect(bytes!, equals([1, 2, 3]));
    });

    test('兼容 data:image/jpeg;base64 前缀', () {
      final raw = 'data:image/jpeg;base64,${base64Encode([9, 9, 9, 9])}';
      final bytes = decodeCoverImageBase64(raw);
      expect(bytes, isNotNull);
      expect(bytes!, equals([9, 9, 9, 9]));
    });

    test('非法输入返回 null 而非抛错', () {
      expect(decodeCoverImageBase64('!!!not-base64!!!'), isNull);
    });
  });

  test('LibraryItem 解析后端内联的 cover_image_base64', () {
    const b64 = 'aGVsbG8=';
    final lib = LibraryItem.fromJson(const {
      'id': 7,
      'name': '我的媒体库',
      'file_count': 12,
      'cover_image_base64': b64,
    });
    expect(lib.coverImageBase64, b64);
    expect(lib.fileCount, 12);
  });

  test('LibraryItem 无封面时字段为空且可正常解析', () {
    final lib = LibraryItem.fromJson(const {'id': 1, 'name': '空库'});
    expect(lib.coverImageBase64, isNull);
  });
}
