import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/library.dart';
import 'libraries_repository.dart';

final librariesRepositoryProvider = Provider<LibrariesRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return LibrariesRepository(client.libraries, client.librariesExtended);
});

/// 首页 用 · 只取启用的 (轻量)
final librariesProvider = FutureProvider<List<LibraryItem>>((ref) async {
  return ref.watch(librariesRepositoryProvider).list(enabledOnly: true);
});

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
