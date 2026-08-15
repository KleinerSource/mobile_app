import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/mappings/mappings_repository.dart';

void main() {
  test('映射规则筛选状态使用后端约定值', () {
    expect(normalizeMappingStatus('all'), 'all');
    expect(normalizeMappingStatus('convert'), 'active');
    expect(normalizeMappingStatus('delete'), 'empty');
  });
}
