import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/mapping_rule.dart';
import 'mappings_repository.dart';

final mappingsRepositoryProvider = Provider<MappingsRepository>((ref) {
  return MappingsRepository(ref.watch(requiredApiClientProvider).mappings);
});

class MappingsListKey {
  const MappingsListKey({
    required this.type,
    this.search,
    this.status = 'all',
  });

  final MappingType type;
  final String? search;
  final String status;

  @override
  bool operator ==(Object other) =>
      other is MappingsListKey &&
      other.type == type &&
      other.search == search &&
      other.status == status;

  @override
  int get hashCode => Object.hash(type, search, status);
}

final mappingsListProvider = FutureProvider.autoDispose
    .family<List<MappingRule>, MappingsListKey>((ref, key) async {
  return ref.watch(mappingsRepositoryProvider).list(
        key.type,
        search: key.search,
        status: key.status,
      );
});
