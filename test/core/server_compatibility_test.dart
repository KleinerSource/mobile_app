import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/server_compatibility.dart';

void main() {
  test('最低版本满足要求', () {
    expect(isSupportedServerVersion('1.3.32'), isTrue);
    expect(isSupportedServerVersion('1.3.33'), isTrue);
    expect(isSupportedServerVersion('1.10.0'), isTrue);
  });

  test('低于最低版本或格式非法时拒绝', () {
    expect(isSupportedServerVersion('1.3.31'), isFalse);
    expect(isSupportedServerVersion('1.3.32-beta'), isFalse);
    expect(isSupportedServerVersion('dev'), isFalse);
  });

  test('项目名称和版本均正确时通过', () {
    final info = requireCompatibleServerVersion({
      'success': true,
      'data': {
        'project_name': 'md_center',
        'version': '1.3.32',
      },
    });

    expect(info.projectName, 'md_center');
    expect(info.version, '1.3.32');
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
        'data': {'project_name': 'md_center', 'version': '1.3.31'},
      }),
      throwsA(isA<ServerCompatibilityException>()),
    );
  });
}
