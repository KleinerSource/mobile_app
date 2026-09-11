import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/error_codes.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'audio_repository.dart';

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  final source = ref.watch(ommMediaSourceProvider);
  if (source == null) {
    throw const SourceException(
      AppErrorCode.ommSourceIdInvalid,
      code: AppErrorCode.ommSourceIdInvalid,
    );
  }
  final operations = source.audioOperations;
  return AudioRepository(operations);
});
