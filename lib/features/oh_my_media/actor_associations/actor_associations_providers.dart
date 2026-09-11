import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/error_codes.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'actor_associations_repository.dart';

final actorAssociationsRepositoryProvider =
    Provider<ActorAssociationsRepository>((ref) {
      final source = ref.watch(ommMediaSourceProvider);
      if (source == null) {
        throw const SourceException(
          AppErrorCode.ommSourceIdInvalid,
          code: AppErrorCode.ommSourceIdInvalid,
        );
      }
      return ActorAssociationsRepository(source.metadataOperations);
    });
