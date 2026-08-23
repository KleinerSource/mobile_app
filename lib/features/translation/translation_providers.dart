import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/translation_config.dart';
import 'translation_repository.dart';

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepository(
    ref.watch(requiredApiClientProvider).translation,
  );
});

final translationConfigProvider = FutureProvider<TranslationConfig>((
  ref,
) async {
  return ref.watch(translationRepositoryProvider).getConfig();
});
