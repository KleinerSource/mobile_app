import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/modal_transcription_config.dart';
import 'modal_transcription_repository.dart';

final modalTranscriptionRepositoryProvider =
    Provider<ModalTranscriptionRepository>((ref) {
      return ModalTranscriptionRepository(
        ref.watch(requiredApiClientProvider).modalTranscription,
      );
    });

final modalTranscriptionConfigProvider =
    FutureProvider<ModalTranscriptionConfig>((ref) async {
      return ref.watch(modalTranscriptionRepositoryProvider).getConfig();
    });
