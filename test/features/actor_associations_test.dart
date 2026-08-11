import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/avdb_config.dart';
import 'package:md_center/core/models/dbo_config.dart';
import 'package:md_center/features/actor_associations/actor_associations_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('演员同步来源只使用已启用且已配置 API Key 的数据源', () {
    expect(
      configuredActorDataSources(
        dbonline: const DboConfig(
          enabled: true,
          baseUrl: 'https://dbo.example',
          apiKey: '***key',
        ),
        avdb: const AvdbConfig(
          enabled: true,
          baseUrl: 'https://avdb.example',
        ),
      ),
      [ActorDataSource.dbonline],
    );
  });

  test('演员同步预览解析 AVDB 简介', () {
    final preview = ActorAssocPreview.fromJson({
      'found': true,
      'actor_name': '演员 A',
      'mapped_value': '演员 A',
      'biography': '  演员简介  ',
      'all_aliases': <String>[],
      'existing_aliases': <String>[],
      'new_aliases': <String>[],
    });

    expect(preview.biography, '演员简介');
  });

  test('演员同步来源记忆上次选择', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(
      ActorAssociationsRepository.loadRememberedSource(prefs),
      isNull,
    );
    await ActorAssociationsRepository.rememberSource(
      prefs,
      ActorDataSource.avdb,
    );

    expect(
      ActorAssociationsRepository.loadRememberedSource(prefs),
      ActorDataSource.avdb,
    );
  });
}
