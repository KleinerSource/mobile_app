import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/update/update_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('更新仓库地址可以保存、读取和清空', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = UpdateSettingsRepository(prefs);

    expect(repository.loadRepository(), isNull);
    await repository.saveRepository(' https://github.com/owner/repository ');
    expect(repository.loadRepository(), 'https://github.com/owner/repository');

    await repository.saveRepository(null);
    expect(repository.loadRepository(), isNull);
  });
}
