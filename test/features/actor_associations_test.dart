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

  test('两渠道均可用时提供混合渠道来源', () {
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
          apiKey: '***key',
        ),
      ),
      [
        ActorDataSource.dbonline,
        ActorDataSource.avdb,
        ActorDataSource.mixed,
      ],
    );
    // 单渠道可用时不提供混合渠道
    expect(
      configuredActorDataSources(
        dbonline: const DboConfig(
          enabled: true,
          baseUrl: 'https://dbo.example',
          apiKey: '***key',
        ),
      ),
      [ActorDataSource.dbonline],
    );
  });

  test('混合来源序列化与反序列化', () {
    expect(ActorDataSource.mixed.value, 'mixed');
    expect(ActorDataSource.mixed.label, '混合渠道');
    expect(actorDataSourceFromValue(' mixed '), ActorDataSource.mixed);
    expect(actorDataSourceFromValue('unknown'), isNull);
  });

  test('混合渠道渐进会话快照解析状态、待补齐渠道与预览', () {
    const preview = ActorAssocPreview(
      found: true,
      mappedValue: '演员 A',
      actorName: '演员 A',
      allAliases: [],
      existingAliases: [],
      newAliases: [],
      externalIds: {'avdb': '290438'},
    );
    final running = MixedActorPreviewSession.fromJson({
      'status': 'running',
      'pending_sources': ['dbonline'],
      'preview': {
        'found': true,
        'mapped_value': '演员 A',
        'actor_name': '演员 A',
        'external_ids': {'avdb': '290438'},
      },
    });
    expect(running.running, isTrue);
    expect(running.pendingSources, ['dbonline']);
    expect(running.preview?.found, isTrue);
    expect(running.preview?.externalIds['avdb'], '290438');

    final failed = MixedActorPreviewSession.fromJson({
      'status': 'failed',
      'error': '混合渠道查询失败：dbo down；avdb down',
    });
    expect(failed.failed, isTrue);
    expect(failed.preview, isNull);
    expect(failed.error, contains('dbo down'));

    const complete = MixedActorPreviewSession(
      status: 'complete',
      pendingSources: [],
      preview: preview,
    );
    expect(complete.complete, isTrue);
    expect(complete.pendingSources, isEmpty);
  });

  test('演员同步预览解析混合渠道的多来源身份与警告', () {
    final preview = ActorAssocPreview.fromJson({
      'found': true,
      'actor_name': '演员 A',
      'mapped_value': '演员 A',
      'all_aliases': <String>[],
      'existing_aliases': <String>[],
      'new_aliases': <String>[],
      'external_ids': {'dbonline': 'MW44', 'avdb': '290438'},
      'warnings': ['DB Online 渠道未找到匹配演员'],
      'avatar_choices': [
        {
          'source_url': '/api/image?url=a.png',
          'download_url': '/api/image?url=a.png',
          'source': 'dbonline',
        },
      ],
    });

    expect(preview.externalIds['dbonline'], 'MW44');
    expect(preview.externalIds['avdb'], '290438');
    expect(preview.warnings, ['DB Online 渠道未找到匹配演员']);
    expect(preview.avatarChoices.first.source, 'dbonline');
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
