import '../../core/api/envelope.dart';
import '../../core/api/services/modal_transcription_api.dart';
import '../../core/models/modal_transcription_config.dart';

class ModalTranscriptionRepository {
  ModalTranscriptionRepository(this._api);

  final ModalTranscriptionApi _api;

  Future<ModalTranscriptionConfig> getConfig() async {
    final raw = await _api.getConfig();
    return unwrapStd<ModalTranscriptionConfig>(raw, (data) {
      if (data is Map) {
        return ModalTranscriptionConfig.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      return const ModalTranscriptionConfig();
    });
  }

  Future<ModalTranscriptionConfig> saveConfig(
    ModalTranscriptionConfig config,
  ) async {
    final raw = await _api.saveConfig(config.toRequest());
    return unwrapStd<ModalTranscriptionConfig>(raw, (data) {
      if (data is Map) {
        return ModalTranscriptionConfig.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      return config;
    });
  }
}
