import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/envelope.dart';

void main() {
  group('unwrapStd', () {
    test('success=true 返回 data', () {
      final out = unwrapStd<Map<String, dynamic>>({
        'success': true,
        'message': 'ok',
        'data': {'x': 1},
      }, (d) => Map<String, dynamic>.from(d as Map));
      expect(out, {'x': 1});
    });

    test('success=false 抛 ApiException', () {
      expect(
        () => unwrapStd<int>({
          'success': false,
          'message': '不行',
          'data': null,
        }, (d) => d as int),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', '不行')),
      );
    });

    test('success=false 支持 dbonline error 字段', () {
      expect(
        () => unwrapStd<void>({
          'success': false,
          'error': '密码错误',
          'data': null,
        }, (_) {}),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', '密码错误'),
        ),
      );
    });
  });

  group('unwrapMovieList', () {
    test('解出 PagedResult', () {
      final raw = {
        'success': true,
        'message': 'ok',
        'data': {
          'items': [
            {'id': 1},
            {'id': 2},
          ],
          'total_count': 42,
          'limit': 20,
          'offset': 0,
        },
      };
      final out = unwrapMovieList<int>(raw, (item) => item['id'] as int);
      expect(out.items, [1, 2]);
      expect(out.totalCount, 42);
      expect(out.limit, 20);
      expect(out.offset, 0);
    });
  });

  group('unwrapTopLevelList', () {
    test('从 data 数组解出 PagedResult', () {
      final raw = {
        'success': true,
        'message': 'ok',
        'data': [
          {'id': 'a'},
          {'id': 'b'},
        ],
        'total_count': 2,
        'limit': 50,
        'offset': 0,
      };
      final out = unwrapTopLevelList<String>(
        raw,
        (item) => item['id'] as String,
      );
      expect(out.items, ['a', 'b']);
      expect(out.totalCount, 2);
    });
  });

  test('解出有界选项结果和 has_more', () {
    final out = unwrapOptions<int>({
      'success': true,
      'message': 'ok',
      'data': [
        {'id': 1},
      ],
      'has_more': true,
      'limit': 100,
      'offset': 200,
    }, (item) => item['id'] as int);
    expect(out.items, [1]);
    expect(out.hasMore, isTrue);
    expect(out.limit, 100);
    expect(out.offset, 200);
  });
}
