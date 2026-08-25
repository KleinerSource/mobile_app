import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';

void main() {
  test('最低版本满足要求', () {
    expect(isSupportedServerVersion('2.0.0'), isTrue);
    expect(isSupportedServerVersion('2.0.1'), isTrue);
    expect(isSupportedServerVersion('2.10.0'), isTrue);
  });

  test('低于最低版本或格式非法时拒绝', () {
    expect(isSupportedServerVersion('1.5.99'), isFalse);
    expect(isSupportedServerVersion('1.9.0-beta'), isFalse);
    expect(isSupportedServerVersion('dev'), isFalse);
  });

  test('项目名称和版本均正确时通过', () {
    final info = requireCompatibleServerVersion({
      'success': true,
      'data': {'project_name': 'oh-my-media', 'version': '2.0.0'},
    });

    expect(info.projectName, 'oh-my-media');
    expect(info.version, '2.0.0');
  });

  test('项目名称错误时拒绝', () {
    expect(
      () => requireCompatibleServerVersion({
        'success': true,
        'data': {'project_name': 'other_project', 'version': '9.9.9'},
      }),
      throwsA(isA<ServerCompatibilityException>()),
    );
  });

  test('版本过低时拒绝', () {
    expect(
      () => requireCompatibleServerVersion({
        'success': true,
        'data': {'project_name': 'oh-my-media', 'version': '1.5.9'},
      }),
      throwsA(isA<ServerCompatibilityException>()),
    );
  });
}
