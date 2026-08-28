/// OMM 音频资产和字幕转译操作。
abstract interface class OmmAudioOperationsSource {
  Future<Object?> listAssets({int limit = 20, int offset = 0, String? search});

  Future<Object?> deleteAssets(List<int> ids);

  Future<Object?> enqueueTranscriptions(
    List<int> assetIds, {
    bool overwrite = false,
  });

  Future<Object?> listTranscriptions({
    int limit = 100,
    int offset = 0,
    String? status,
  });

  Future<Object?> extractAudio({
    required int movieId,
    String format = 'mp3',
    int bitrateKbps = 192,
  });

  Future<Object?> cancelAudioExtraction(String taskId);

  Future<Object?> cancelSubtitleTranscription(String assetId);

  Future<Object?> retrySubtitleTranscription(String assetId, {bool? overwrite});
}
