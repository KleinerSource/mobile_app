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
      'biography_changed': false,
    });

    expect(preview.biography, '演员简介');
    expect(preview.biographyChanged, isFalse);
  });

  test('演员同步预览解析头像地址和本地存在状态', () {
    final preview = ActorAssocPreview.fromJson({
      'found': true,
      'actor_name': '演员 A',
      'mapped_value': '演员 A',
      'all_aliases': <String>[],
      'existing_aliases': <String>[],
      'new_aliases': <String>[],
      'avatar_url': '  https://example.com/avatar.jpg  ',
      'avatar_exists': true,
      'avatar_choices': [
        {
          'source_url': 'https://avdb.example/one.jpg',
          'download_url': ' https://cdn.example/actors/avatar/one ',
        },
        {
          'source_url': 'https://avdb.example/two.jpg',
          'download_url': 'https://cdn.example/actors/avatar/two',
        },
        {
          'source_url': 'https://avdb.example/two.jpg',
          'download_url': 'https://cdn.example/actors/avatar/two',
        },
      ],
    });

    expect(preview.avatarUrl, 'https://example.com/avatar.jpg');
    expect(preview.avatarExists, isTrue);
    expect(preview.avatarChoices, hasLength(3));
    expect(preview.avatarChoices.first.downloadUrl,
        'https://cdn.example/actors/avatar/one');
    expect(preview.avatarChoices[1].sourceUrl,
        'https://avdb.example/two.jpg');
  });

  test('演员同步预览没有头像地址时保持空头像状态', () {
    final preview = ActorAssocPreview.fromJson({
      'found': true,
      'actor_name': '演员 A',
      'mapped_value': '演员 A',
      'all_aliases': <String>[],
      'existing_aliases': <String>[],
      'new_aliases': <String>[],
      'avatar_exists': false,
    });

    expect(preview.avatarUrl, isEmpty);
    expect(preview.avatarExists, isFalse);
  });

  test('演员简介相同或仅换行差异时不需要重复同步', () {
    expect(
      ActorAssociationsRepository.biographyNeedsSync(
        '演员简介\r\n',
        ' 演员简介\n',
      ),
      isFalse,
    );
    expect(
      ActorAssociationsRepository.biographyNeedsSync('旧简介', '新简介'),
      isTrue,
    );
    expect(
      ActorAssociationsRepository.biographyNeedsSync('已有简介', ''),
      isFalse,
    );
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
