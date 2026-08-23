import 'package:flutter/foundation.dart';

/// 音频资产行上内嵌的字幕转译信息。
///
/// 取消/重试接口的 id 传音频资产 ID（与 WS scheduler_status 的 taskId 同源）。
@immutable
class AudioTranscription {
  const AudioTranscription({
    this.status = '',
    this.stage = '',
    this.percent = 0,
    this.message = '',
    this.errorMessage = '',
    this.downloadUrl = '',
  });

  factory AudioTranscription.fromJson(Object? raw) {
    if (raw is! Map) return const AudioTranscription();
    return AudioTranscription(
      status: _asString(raw['status']),
      stage: _asString(raw['stage']),
      percent: _asDouble(raw['percent']),
      message: _asString(raw['message']),
      errorMessage: _asString(raw['error_message']),
      downloadUrl: _asString(raw['download_url']),
    );
  }

  final String status;
  final String stage;
  final double percent;
  final String message;
  final String errorMessage;
  final String downloadUrl;

  bool get isActive => status == 'queued' || status == 'running';

  bool get isDone => status == 'completed' || status == 'skipped';

  bool get isFailed => status == 'failed';

  bool get isCanceled => status == 'canceled';

  int get clampedPercent => percent.clamp(0, 100).round();

  static const stageLabels = <String, String>{
    'queued': '排队中',
    'starting': '启动中',
    'connecting': '连接 Modal',
    'sandbox': '创建云端环境',
    'preparing': '准备模型',
    'uploading': '上传音频',
    'transcribing': '云端转译',
    'downloading': '下载字幕',
    'registering': '登记字幕',
    'completed': '完成',
    'failed': '失败',
    'canceled': '已取消',
    'skipped': '已跳过',
  };

  String get stageLabel {
    if (stage.isNotEmpty) return stageLabels[stage] ?? stage;
    return isActive ? '转译中' : status;
  }
}

/// 已提取的音频资产。
@immutable
class AudioAsset {
  const AudioAsset({
    required this.id,
    this.movieId = 0,
    this.movieTitle = '',
    this.movieFileName = '',
    this.fileName = '',
    this.subtitleTranslated = false,
    this.format = '',
    this.codec = '',
    this.bitrateKbps = 0,
    this.durationSec = 0,
    this.fileSize = 0,
    this.fileExists = false,
    this.transcription,
  });

  factory AudioAsset.fromJson(Map<String, dynamic> json) {
    return AudioAsset(
      id: _asInt(json['id']),
      movieId: _asInt(json['movie_id']),
      movieTitle: _asString(json['movie_title']),
      movieFileName: _asString(json['movie_file_name']),
      fileName: _asString(json['file_name']),
      subtitleTranslated: json['subtitle_translated'] == true,
      format: _asString(json['format']),
      codec: _asString(json['codec']),
      bitrateKbps: _asInt(json['bitrate_kbps']),
      durationSec: _asDouble(json['duration_sec']),
      fileSize: _asInt(json['file_size']),
      fileExists: json['file_exists'] == true,
      transcription: json['transcription'] == null
          ? null
          : AudioTranscription.fromJson(json['transcription']),
    );
  }

  final int id;
  final int movieId;
  final String movieTitle;
  final String movieFileName;
  final String fileName;
  final bool subtitleTranslated;
  final String format;
  final String codec;
  final int bitrateKbps;
  final double durationSec;
  final int fileSize;
  final bool fileExists;
  final AudioTranscription? transcription;

  AudioTranscription get transcriptionView => transcription ?? const AudioTranscription();

  /// 字幕转译完成：行内转译状态优先，其次回退到资产标记。
  bool get isTranscriptionDone =>
      transcriptionView.isDone || (subtitleTranslated && !transcriptionView.isFailed);

  bool get isTranscriptionActive => transcriptionView.isActive;

  String get displayTitle =>
      movieTitle.isNotEmpty ? movieTitle : (movieFileName.isNotEmpty ? movieFileName : '影片 #$movieId');

  String get formatLabel {
    final value = format.trim();
    if (value.isEmpty) return '-';
    return switch (value.toLowerCase()) {
      'mp3' => 'MP3',
      'm4a' || 'aac' => 'M4A / AAC',
      'opus' => 'Opus',
      _ => value.toUpperCase(),
    };
  }
}

/// GET /audios 的列表结果。
@immutable
class AudioAssetListResult {
  const AudioAssetListResult({
    this.items = const [],
    this.total = 0,
    this.totalBytes = 0,
    this.transcriptionActiveCount = 0,
  });

  final List<AudioAsset> items;
  final int total;
  final int totalBytes;
  final int transcriptionActiveCount;
}

/// 删除音频资产被拒的单条原因。
@immutable
class AudioAssetDeleteRejection {
  const AudioAssetDeleteRejection({required this.id, required this.message});

  final int id;
  final String message;
}

/// POST /audios/delete 的结果。
@immutable
class AudioAssetDeleteResult {
  const AudioAssetDeleteResult({this.deleted = const [], this.rejected = const []});

  final List<int> deleted;
  final List<AudioAssetDeleteRejection> rejected;
}

/// 字幕转译入队被拒的单条原因。
@immutable
class TranscriptionEnqueueRejection {
  const TranscriptionEnqueueRejection({required this.message});

  final String message;
}

/// POST /audios/transcriptions 的入队结果。
@immutable
class TranscriptionEnqueueResult {
  const TranscriptionEnqueueResult({this.accepted = 0, this.rejected = const []});

  final int accepted;
  final List<TranscriptionEnqueueRejection> rejected;
}

String _asString(Object? value) {
  return value?.toString().trim() ?? '';
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
