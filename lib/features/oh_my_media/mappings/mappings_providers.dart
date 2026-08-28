import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/models/mapping_rule.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'mappings_repository.dart';

final mappingsRepositoryProvider = Provider<MappingsRepository>((ref) {
  final source = ref.watch(ommMediaSourceProvider);
  if (source == null) {
    throw StateError('当前服务器不是 OMM，无法访问映射规则');
  }
  return MappingsRepository(source.metadataOperations);
});

class MappingsListKey {
  const MappingsListKey({required this.type, this.search, this.status = 'all'});

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
      return ref
          .watch(mappingsRepositoryProvider)
          .list(key.type, search: key.search, status: key.status);
    });
