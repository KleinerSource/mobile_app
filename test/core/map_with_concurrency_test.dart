import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/util/map_with_concurrency.dart';

void main() {
  test('保持顺序且有并发上限', () async {
    var running = 0;
    var peak = 0;
    final result = await mapWithConcurrency(List<int>.generate(20, (i) => i), (
      i,
    ) async {
      running++;
      peak = peak > running ? peak : running;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      running--;
      return i * 2;
    }, concurrency: 4);
    expect(peak, lessThanOrEqualTo(4));
    expect(result, List<int>.generate(20, (i) => i * 2));
  });

  test('空输入返回空列表', () async {
    final result = await mapWithConcurrency<int, int>(
      const <int>[],
      (i) async => i,
    );
    expect(result, isEmpty);
  });
}
