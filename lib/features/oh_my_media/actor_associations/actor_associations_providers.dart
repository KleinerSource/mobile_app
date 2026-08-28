import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/sources/media/media_source_providers.dart';
import 'actor_associations_repository.dart';

final actorAssociationsRepositoryProvider =
    Provider<ActorAssociationsRepository>((ref) {
      final source = ref.watch(ommMediaSourceProvider);
      if (source == null) {
        throw StateError('当前服务器不是 OMM，无法访问演员关联');
      }
      return ActorAssociationsRepository(source.metadataOperations);
    });
