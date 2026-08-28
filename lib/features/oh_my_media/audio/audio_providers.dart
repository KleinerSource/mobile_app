import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/sources/media/media_source_providers.dart';
import 'audio_repository.dart';

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  final source = ref.watch(ommMediaSourceProvider);
  if (source == null) {
    throw StateError('当前服务器不是 OMM，无法访问音频资产');
  }
  final operations = source.audioOperations;
  return AudioRepository(operations);
});
