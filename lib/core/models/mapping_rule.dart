import 'package:freezed_annotation/freezed_annotation.dart';

part 'mapping_rule.freezed.dart';
part 'mapping_rule.g.dart';

/// 映射规则:
///   original_values: ["原值1", "原值2"]
///   mapped_value: "目标值" · 为空表示「删除规则」(扫描时直接丢弃)
@freezed
abstract class MappingRule with _$MappingRule {
  const factory MappingRule({
    required int id,
    @JsonKey(name: 'original_values')
    @Default(<String>[])
    List<String> originalValues,
    @JsonKey(name: 'mapped_value') String? mappedValue,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _MappingRule;

  factory MappingRule.fromJson(Map<String, dynamic> json) =>
      _$MappingRuleFromJson(json);
}

extension MappingRuleX on MappingRule {
  bool get isDelete => mappedValue == null || mappedValue!.isEmpty;
  String get originalDisplay => originalValues.join(' / ');
}
