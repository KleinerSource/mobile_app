import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/sources/media/omm_audio_operations_source.dart';
import 'audio_models.dart';

/// 音频资产与字幕转译任务的数据仓库。
///
/// 音频提取的实时进度由任务 WebSocket 推送（任务中心），这里只负责
/// 资产列表查询与转译任务的操作。
class AudioRepository {
  AudioRepository(this._api);

  final OmmAudioOperationsSource _api;

  Future<AudioAssetListResult> listAssets({
    int limit = 20,
    int offset = 0,
    String? search,
  }) async {
    final raw = await _api.listAssets(
      limit: limit,
      offset: offset,
      search: search,
    );
    return unwrapStd<AudioAssetListResult>(raw, _decodeList);
  }

  Future<AudioAssetDeleteResult> deleteAssets(List<int> ids) async {
    final raw = await _api.deleteAssets(ids);
    return unwrapStd<AudioAssetDeleteResult>(raw, (data) {
      if (data is! Map) {
        return AudioAssetDeleteResult(message: envelopeMessageOrNull(raw));
      }
      return AudioAssetDeleteResult(
        deleted: [
          for (final value
              in (data['deleted'] is List ? data['deleted'] as List : const []))
            if (int.tryParse(value.toString()) != null)
              int.parse(value.toString()),
        ],
        rejected: [
          for (final value
              in (data['rejected'] is List
                  ? data['rejected'] as List
                  : const []))
            if (value is Map)
              AudioAssetDeleteRejection(
                id: int.tryParse(value['id']?.toString() ?? '') ?? 0,
                message: value['message']?.toString() ?? '',
              ),
        ],
        message: envelopeMessageOrNull(raw),
      );
    });
  }

  Future<TranscriptionEnqueueResult> enqueueTranscriptions(
    List<int> assetIds, {
    bool overwrite = false,
  }) async {
    final raw = await _api.enqueueTranscriptions(
      assetIds,
      overwrite: overwrite,
    );
    return unwrapStd<TranscriptionEnqueueResult>(raw, (data) {
      if (data is! Map) {
        return TranscriptionEnqueueResult(message: envelopeMessageOrNull(raw));
      }
      final items = data['items'] is List ? data['items'] as List : const [];
      final rejected = data['rejected'] is List
          ? data['rejected'] as List
          : const [];
      final accepted = data['accepted'] is List
          ? data['accepted'] as List
          : const [];
      return TranscriptionEnqueueResult(
        accepted: accepted.isNotEmpty ? assetIds.length : items.length,
        rejected: [
          for (final value in rejected)
            if (value is Map)
              TranscriptionEnqueueRejection(
                message: value['message']?.toString() ?? '',
              ),
        ],
        message: envelopeMessageOrNull(raw),
      );
    });
  }

  Future<String?> cancelTranscription(String taskId) async {
    final raw = await _api.cancelSubtitleTranscription(taskId);
    unwrapStd<Object?>(raw, (_) => null);
    return envelopeMessageOrNull(raw);
  }

  Future<String?> retryTranscription(String taskId) async {
    final raw = await _api.retrySubtitleTranscription(taskId);
    unwrapStd<Object?>(raw, (_) => null);
    return envelopeMessageOrNull(raw);
  }

  Future<String?> cancelExtraction(String taskId) async {
    final raw = await _api.cancelAudioExtraction(taskId);
    unwrapStd<Object?>(raw, (_) => null);
    return envelopeMessageOrNull(raw);
  }

  Future<Object?> listTranscriptions({
    int limit = 100,
    int offset = 0,
    String? status,
  }) => _api.listTranscriptions(limit: limit, offset: offset, status: status);

  Future<Object?> extractAudio({
    required int movieId,
    String format = 'mp3',
    int bitrateKbps = 192,
  }) => _api.extractAudio(
    movieId: movieId,
    format: format,
    bitrateKbps: bitrateKbps,
  );

  Future<Object?> cancelExtractionRaw(String taskId) =>
      _api.cancelAudioExtraction(taskId);

  Future<Object?> cancelTranscriptionRaw(String taskId) =>
      _api.cancelSubtitleTranscription(taskId);

  Future<Object?> retryTranscriptionRaw(String taskId) =>
      _api.retrySubtitleTranscription(taskId);
}

AudioAssetListResult _decodeList(Object? data) {
  if (data is! Map) return const AudioAssetListResult();
  return AudioAssetListResult(
    items: [
      for (final value
          in (data['items'] is List ? data['items'] as List : const []))
        if (value is Map) AudioAsset.fromJson(Map<String, dynamic>.from(value)),
    ],
    total: _asInt(data['total']),
    totalBytes: _asInt(data['total_bytes']),
    transcriptionActiveCount: _asInt(data['transcription_active_count']),
  );
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
