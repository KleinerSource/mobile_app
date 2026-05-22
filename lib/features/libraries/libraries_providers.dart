import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/library.dart';
import 'libraries_repository.dart';

final librariesRepositoryProvider = Provider<LibrariesRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return LibrariesRepository(client.libraries);
});

final librariesProvider = FutureProvider<List<LibraryItem>>((ref) async {
  return ref.watch(librariesRepositoryProvider).list();
});
