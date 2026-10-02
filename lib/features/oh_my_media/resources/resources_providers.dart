import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/error_codes.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'resources_repository.dart';

final resourcesRepositoryProvider = Provider<ResourcesRepository>((ref) {
  final source = ref.watch(ommMediaSourceProvider);
  if (source == null) {
    throw const SourceException(
      AppErrorCode.ommSourceIdInvalid,
      code: AppErrorCode.ommSourceIdInvalid,
    );
  }
  return ResourcesRepository(source.metadataOperations);
});
