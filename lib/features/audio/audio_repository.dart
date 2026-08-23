import '../../core/api/envelope.dart';
import '../../core/api/services/audio_api.dart';
import 'audio_models.dart';

/// 音频资产与字幕转译任务的数据仓库。
///
/// 音频提取的实时进度由任务 WebSocket 推送（任务中心），这里只负责
/// 资产列表查询与转译任务的操作。
class AudioRepository {
  AudioRepository(this._api);

  final AudioApi _api;

  Future<AudioAssetListResult> listAssets({
    int limit = 20,
    int offset = 0,
    String? search,
  }) async {
    final raw = await _api.listAssets(limit: limit, offset: offset, search: search);
    return unwrapStd<AudioAssetListResult>(raw, _decodeList);
  }

  Future<AudioAssetDeleteResult> deleteAssets(List<int> ids) async {
    final raw = await _api.deleteAssets(ids);
    return unwrapStd<AudioAssetDeleteResult>(raw, (data) {
      if (data is! Map) return const AudioAssetDeleteResult();
      return AudioAssetDeleteResult(
        deleted: [
          for (final value in (data['deleted'] is List ? data['deleted'] as List : const []))
            if (int.tryParse(value.toString()) != null) int.parse(value.toString()),
        ],
        rejected: [
          for (final value
              in (data['rejected'] is List ? data['rejected'] as List : const []))
            if (value is Map)
              AudioAssetDeleteRejection(
                id: int.tryParse(value['id']?.toString() ?? '') ?? 0,
                message: value['message']?.toString() ?? '',
              ),
        ],
      );
    });
  }

  Future<TranscriptionEnqueueResult> enqueueTranscriptions(
    List<int> assetIds, {
    bool overwrite = false,
  }) async {
    final raw = await _api.enqueueTranscriptions(assetIds, overwrite: overwrite);
    return unwrapStd<TranscriptionEnqueueResult>(raw, (data) {
      if (data is! Map) return const TranscriptionEnqueueResult();
      final items = data['items'] is List ? data['items'] as List : const [];
      final rejected = data['rejected'] is List ? data['rejected'] as List : const [];
      return TranscriptionEnqueueResult(
        accepted: items.length,
        rejected: [
          for (final value in rejected)
            if (value is Map)
              TranscriptionEnqueueRejection(
                message: value['message']?.toString() ?? '',
              ),
        ],
      );
    });
  }

  /// [assetId] 为音频资产 ID。
  Future<void> cancelTranscription(int assetId) async {
    final raw = await _api.cancelSubtitleTranscription(assetId.toString());
    unwrapStd<Object?>(raw, (_) => null);
  }

  /// [assetId] 为音频资产 ID。
  Future<void> retryTranscription(
    int assetId, {
    bool? overwrite,
  }) async {
    final raw = await _api.retrySubtitleTranscription(
      assetId.toString(),
      overwrite: overwrite,
    );
    unwrapStd<Object?>(raw, (_) => null);
  }

  Future<void> cancelExtraction(String taskId) async {
    final raw = await _api.cancelAudioExtraction(taskId);
    unwrapStd<Object?>(raw, (_) => null);
  }
}

AudioAssetListResult _decodeList(Object? data) {
  if (data is! Map) return const AudioAssetListResult();
  return AudioAssetListResult(
    items: [
      for (final value in (data['items'] is List ? data['items'] as List : const []))
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
