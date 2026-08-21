import 'package:flutter/foundation.dart';

const _roundRobin = 'round_robin';
const _fillFirst = 'fill_first';

/// Modal 云端字幕转译配置。
///
/// 支持多个 Modal 账号令牌：服务端返回的凭据是脱敏值，真正的
/// token 只在保存时由输入框临时提交；令牌列表是“完整目标列表”，
/// 未出现在提交列表里的既有令牌会被服务端移除。
@immutable
class ModalTranscriptionConfig {
  const ModalTranscriptionConfig({
    this.enabled = false,
    this.tokens = const [],
    this.tokenStrategy = _roundRobin,
    this.perTokenWorkers = 0,
    this.hfToken = '',
    this.hasHfToken = false,
    this.defaultGpu = 'T4',
    this.defaultModel = 'chickenrice',
    this.repoBranch = 'v1.10',
    this.defaultFormats = const ['srt'],
    this.maxWorkers = 1,
  });

  static const int maxTokenCount = 20;
  static const List<String> tokenStrategies = [_roundRobin, _fillFirst];

  factory ModalTranscriptionConfig.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'];
    final strategy = _stringValue(json['token_strategy']);
    return ModalTranscriptionConfig(
      enabled: json['enabled'] == true,
      tokens: tokens is List
          ? [
              for (final entry in tokens)
                if (entry is Map)
                  ModalTranscriptionToken.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
            ]
          : const [],
      tokenStrategy: tokenStrategies.contains(strategy)
          ? strategy
          : _roundRobin,
      perTokenWorkers: _intValue(
        json['per_token_workers'],
        fallback: 0,
      ).clamp(0, 10),
      // 服务端返回的是脱敏值；不能把它们当作新凭据再次提交。
      hfToken: json['has_hf_token'] == true
          ? ''
          : _stringValue(json['hf_token']),
      hasHfToken: json['has_hf_token'] == true,
      defaultGpu: _stringValue(json['default_gpu'], fallback: 'T4'),
      defaultModel: _stringValue(
        json['default_model'],
        fallback: 'chickenrice',
      ),
      repoBranch: _stringValue(json['repo_branch'], fallback: 'v1.10'),
      defaultFormats: const ['srt'],
      maxWorkers: _intValue(json['max_workers'], fallback: 1).clamp(1, 10),
    );
  }

  final bool enabled;
  final List<ModalTranscriptionToken> tokens;

  /// 任务分配策略：round_robin 轮询分配，fill_first 填充优先。
  final String tokenStrategy;

  /// 单令牌并发上限（0-10），0 表示跟随 maxWorkers。
  final int perTokenWorkers;
  final String hfToken;
  final bool hasHfToken;
  final String defaultGpu;
  final String defaultModel;
  final String repoBranch;
  final List<String> defaultFormats;
  final int maxWorkers;

  ModalTranscriptionConfig copyWith({
    bool? enabled,
    List<ModalTranscriptionToken>? tokens,
    String? tokenStrategy,
    int? perTokenWorkers,
    String? hfToken,
    bool? hasHfToken,
    String? defaultGpu,
    String? defaultModel,
    String? repoBranch,
    List<String>? defaultFormats,
    int? maxWorkers,
  }) {
    return ModalTranscriptionConfig(
      enabled: enabled ?? this.enabled,
      tokens: tokens ?? this.tokens,
      tokenStrategy: tokenStrategy ?? this.tokenStrategy,
      perTokenWorkers: perTokenWorkers ?? this.perTokenWorkers,
      hfToken: hfToken ?? this.hfToken,
      hasHfToken: hasHfToken ?? this.hasHfToken,
      defaultGpu: defaultGpu ?? this.defaultGpu,
      defaultModel: defaultModel ?? this.defaultModel,
      repoBranch: repoBranch ?? this.repoBranch,
      defaultFormats: defaultFormats ?? this.defaultFormats,
      maxWorkers: maxWorkers ?? this.maxWorkers,
    );
  }

  /// 生成服务端增量更新请求。
  ///
  /// 令牌条目按后端规则序列化：既有令牌只带稳定 id 与备注，用户
  /// 输入的新凭据才会附带提交；空 HF token 不提交以保留旧值。
  Map<String, dynamic> toRequest() {
    final request = <String, dynamic>{
      'enabled': enabled,
      'tokens': [for (final token in tokens) token.toEntryJson()],
      'token_strategy': tokenStrategy,
      'per_token_workers': perTokenWorkers,
      'default_gpu': defaultGpu,
      'default_model': 'chickenrice',
      'repo_branch': repoBranch,
      'default_formats': const ['srt'],
      'max_workers': maxWorkers,
    };
    if (hfToken.trim().isNotEmpty) {
      request['hf_token'] = hfToken.trim();
    }
    return request;
  }
}

/// 单个 Modal 账号令牌的草稿条目。
///
/// [id] 非空表示服务端已存在的令牌（编辑时凭据留空即保留原值），
/// 为空表示待新增的令牌（保存时必须同时提供凭据）。
/// [tokenId]/[tokenSecret] 只保存用户本次输入的明文草稿，
/// 服务端响应重建后即被清空，不会把脱敏值误当作新凭据。
@immutable
class ModalTranscriptionToken {
  const ModalTranscriptionToken({
    this.id = '',
    this.name = '',
    this.tokenIdMasked = '',
    this.tokenId = '',
    this.tokenSecret = '',
  });

  factory ModalTranscriptionToken.fromJson(Map<String, dynamic> json) {
    return ModalTranscriptionToken(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      tokenIdMasked: _stringValue(json['token_id_masked']),
    );
  }

  final String id;
  final String name;
  final String tokenIdMasked;
  final String tokenId;
  final String tokenSecret;

  bool get isExisting => id.isNotEmpty;

  ModalTranscriptionToken copyWith({
    String? id,
    String? name,
    String? tokenIdMasked,
    String? tokenId,
    String? tokenSecret,
  }) {
    return ModalTranscriptionToken(
      id: id ?? this.id,
      name: name ?? this.name,
      tokenIdMasked: tokenIdMasked ?? this.tokenIdMasked,
      tokenId: tokenId ?? this.tokenId,
      tokenSecret: tokenSecret ?? this.tokenSecret,
    );
  }

  Map<String, dynamic> toEntryJson() {
    final entry = <String, dynamic>{
      if (isExisting) 'id': id,
      'name': name.trim(),
    };
    if (tokenId.trim().isNotEmpty) entry['token_id'] = tokenId.trim();
    if (tokenSecret.trim().isNotEmpty) {
      entry['token_secret'] = tokenSecret.trim();
    }
    return entry;
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
