import 'package:freezed_annotation/freezed_annotation.dart';

part 'dbo_config.freezed.dart';
part 'dbo_config.g.dart';

@freezed
class DboConfig with _$DboConfig {
  const factory DboConfig({
    @JsonKey(name: 'base_url') @Default('') String baseUrl,
    @JsonKey(name: 'api_key') @Default('') String apiKey,
    @JsonKey(name: 'max_age_months') @Default(0) int maxAgeMonths,
  }) = _DboConfig;

  factory DboConfig.fromJson(Map<String, dynamic> json) =>
      _$DboConfigFromJson(json);
}

extension DboConfigX on DboConfig {
  bool get hasApiKey => apiKey.contains('*');
}
