import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/library.dart';
import 'libraries_repository.dart';

final librariesRepositoryProvider = Provider<LibrariesRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return LibrariesRepository(client.libraries, client.librariesExtended);
});

/// 首页 用 · 只取启用的 (轻量,不含封面 base64)
final librariesProvider = FutureProvider<List<LibraryItem>>((ref) async {
  return ref
      .watch(librariesRepositoryProvider)
      .list(enabledOnly: true, withCover: false);
});

/// 首页媒体库封面 · 单独拉取 with_cover 列表并解码为图片字节,
/// 到达后叠加到已渲染的卡片上 (对齐 web Dashboard 的渐进式加载)
final libraryCoverImagesProvider =
    FutureProvider<Map<int, Uint8List>>((ref) async {
  final libs = await ref
      .watch(librariesRepositoryProvider)
      .list(enabledOnly: true, withCover: true);
  final covers = <int, Uint8List>{};
  for (final lib in libs) {
    final bytes = decodeCoverImageBase64(lib.coverImageBase64);
    if (bytes != null) covers[lib.id] = bytes;
  }
  return covers;
});

/// 解码后端内联的封面 base64 · 兼容 data: 前缀,非法输入返回 null
Uint8List? decodeCoverImageBase64(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  var data = raw;
  final comma = data.indexOf(',');
  if (data.startsWith('data:') && comma > 0) {
    data = data.substring(comma + 1);
  }
  try {
    final bytes = base64Decode(data);
    return bytes.isEmpty ? null : bytes;
  } on FormatException {
    return null;
  }
}

/// 管理页用 · 含禁用,带 cover
final librariesAllProvider = FutureProvider<List<LibraryItem>>((ref) async {
  return ref
      .watch(librariesRepositoryProvider)
      .list(enabledOnly: false, withCover: true);
});

/// 单个媒体库详情 (含 directories)
final libraryDetailProvider =
    FutureProvider.family<LibraryItem, int>((ref, id) async {
  return ref.watch(librariesRepositoryProvider).detail(id);
});

/// 单个媒体库的目录列表
final directoriesProvider =
    FutureProvider.family<List<DirectoryItem>, int>((ref, libId) async {
  return ref.watch(librariesRepositoryProvider).listDirectories(libId);
});
