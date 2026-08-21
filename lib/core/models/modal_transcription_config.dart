import 'package:flutter/foundation.dart';

/// Modal 云端字幕转译配置。
///
/// 服务端返回的凭据是脱敏值，真正的 token 只在保存时由输入框临时提交。
@immutable
class ModalTranscriptionConfig {
  const ModalTranscriptionConfig({
    this.enabled = false,
    this.modalTokenId = '',
    this.modalTokenSecret = '',
    this.hfToken = '',
    this.hasModalTokenId = false,
    this.hasModalTokenSecret = false,
    this.hasHfToken = false,
    this.defaultGpu = 'T4',
    this.defaultModel = 'chickenrice',
    this.repoBranch = 'v1.10',
    this.defaultFormats = const ['srt'],
    this.maxWorkers = 1,
  });

  factory ModalTranscriptionConfig.fromJson(Map<String, dynamic> json) {
    final formats = json['default_formats'];
    final hasModalTokenId = json['has_modal_token_id'] == true;
    final hasModalTokenSecret = json['has_modal_token_secret'] == true;
    final hasHfToken = json['has_hf_token'] == true;
    final parsedFormats = formats is List
        ? formats
              .map((value) => value.toString().trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return ModalTranscriptionConfig(
      enabled: json['enabled'] == true,
      // 服务端返回的是脱敏值；不能把它们当作新凭据再次提交。
      modalTokenId: hasModalTokenId ? '' : _stringValue(json['modal_token_id']),
      modalTokenSecret: hasModalTokenSecret
          ? ''
          : _stringValue(json['modal_token_secret']),
      hfToken: hasHfToken ? '' : _stringValue(json['hf_token']),
      hasModalTokenId: hasModalTokenId,
      hasModalTokenSecret: hasModalTokenSecret,
      hasHfToken: hasHfToken,
      defaultGpu: _stringValue(json['default_gpu'], fallback: 'T4'),
      defaultModel: _stringValue(
        json['default_model'],
        fallback: 'chickenrice',
      ),
      repoBranch: _stringValue(json['repo_branch'], fallback: 'v1.10'),
      defaultFormats: parsedFormats.isEmpty ? const ['srt'] : parsedFormats,
      maxWorkers: _intValue(json['max_workers'], fallback: 1),
    );
  }

  final bool enabled;
  final String modalTokenId;
  final String modalTokenSecret;
  final String hfToken;
  final bool hasModalTokenId;
  final bool hasModalTokenSecret;
  final bool hasHfToken;
  final String defaultGpu;
  final String defaultModel;
  final String repoBranch;
  final List<String> defaultFormats;
  final int maxWorkers;

  ModalTranscriptionConfig copyWith({
    bool? enabled,
    String? modalTokenId,
    String? modalTokenSecret,
    String? hfToken,
    bool? hasModalTokenId,
    bool? hasModalTokenSecret,
    bool? hasHfToken,
    String? defaultGpu,
    String? defaultModel,
    String? repoBranch,
    List<String>? defaultFormats,
    int? maxWorkers,
  }) {
    return ModalTranscriptionConfig(
      enabled: enabled ?? this.enabled,
      modalTokenId: modalTokenId ?? this.modalTokenId,
      modalTokenSecret: modalTokenSecret ?? this.modalTokenSecret,
      hfToken: hfToken ?? this.hfToken,
      hasModalTokenId: hasModalTokenId ?? this.hasModalTokenId,
      hasModalTokenSecret: hasModalTokenSecret ?? this.hasModalTokenSecret,
      hasHfToken: hasHfToken ?? this.hasHfToken,
      defaultGpu: defaultGpu ?? this.defaultGpu,
      defaultModel: defaultModel ?? this.defaultModel,
      repoBranch: repoBranch ?? this.repoBranch,
      defaultFormats: defaultFormats ?? this.defaultFormats,
      maxWorkers: maxWorkers ?? this.maxWorkers,
    );
  }

  /// 生成服务端增量更新请求，空 token 不提交，以保留已有凭据。
  Map<String, dynamic> toRequest() {
    final request = <String, dynamic>{
      'enabled': enabled,
      'default_gpu': defaultGpu,
      'default_model': 'chickenrice',
      'repo_branch': repoBranch,
      'default_formats': const ['srt'],
      'max_workers': maxWorkers,
    };
    if (modalTokenId.trim().isNotEmpty) {
      request['modal_token_id'] = modalTokenId.trim();
    }
    if (modalTokenSecret.trim().isNotEmpty) {
      request['modal_token_secret'] = modalTokenSecret.trim();
    }
    if (hfToken.trim().isNotEmpty) {
      request['hf_token'] = hfToken.trim();
    }
    return request;
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _intValue(Object? value, {required int fallback}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
