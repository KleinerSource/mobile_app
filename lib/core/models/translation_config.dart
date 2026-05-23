import 'package:freezed_annotation/freezed_annotation.dart';

part 'translation_config.freezed.dart';
part 'translation_config.g.dart';

@freezed
class TranslationConfig with _$TranslationConfig {
  const factory TranslationConfig({
    @Default(false) bool enabled,
    @JsonKey(name: 'api_url') @Default('') String apiUrl,
    @JsonKey(name: 'api_key') @Default('') String apiKey,
    @JsonKey(name: 'model_name') @Default('gpt-3.5-turbo') String modelName,
    @JsonKey(name: 'source_language') @Default('自动检测') String sourceLanguage,
    @JsonKey(name: 'target_language') @Default('中文') String targetLanguage,
    @JsonKey(name: 'prompt_template') @Default('') String promptTemplate,
  }) = _TranslationConfig;

  factory TranslationConfig.fromJson(Map<String, dynamic> json) =>
      _$TranslationConfigFromJson(json);
}

extension TranslationConfigX on TranslationConfig {
  /// 后端把已存在的 key 用 *** 占位返回 · 检测是否已配置
  bool get hasApiKey => apiKey.contains('*');
}

@freezed
class TranslationModel with _$TranslationModel {
  const factory TranslationModel({
    required String id,
    String? name,
  }) = _TranslationModel;

  factory TranslationModel.fromJson(Map<String, dynamic> json) =>
      _$TranslationModelFromJson(json);
}
