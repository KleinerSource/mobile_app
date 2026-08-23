import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import 'audio_repository.dart';

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return AudioRepository(ref.watch(requiredApiClientProvider).audio);
});
