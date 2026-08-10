import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/avdb_config.dart';
import 'package:md_center/core/models/dbo_config.dart';
import 'package:md_center/features/actor_associations/actor_associations_repository.dart';

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
}
