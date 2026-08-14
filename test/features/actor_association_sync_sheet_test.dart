import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/services/mappings_api.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/core/models/avdb_config.dart';
import 'package:md_center/core/models/dbo_config.dart';
import 'package:md_center/core/models/mapping_rule.dart';
import 'package:md_center/features/actor_associations/actor_associations_providers.dart';
import 'package:md_center/features/actor_associations/actor_associations_repository.dart';
import 'package:md_center/features/actor_associations/widgets/actor_association_sync_sheet.dart';
import 'package:md_center/features/configs/configs_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('数据源以并排 Checkbox 显示且预览请求中可快速往返切换',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = _PendingPreviewRepository();
    final oldDbo = repository.enqueue(ActorDataSource.dbonline);
    final avdb = repository.enqueue(ActorDataSource.avdb);
    final currentDbo = repository.enqueue(ActorDataSource.dbonline);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          dboConfigProvider.overrideWith(
            (ref) async => const DboConfig(
              enabled: true,
              baseUrl: 'https://dbo.example',
              apiKey: 'dbo-key',
            ),
          ),
          avdbConfigProvider.overrideWith(
            (ref) async => const AvdbConfig(
              enabled: true,
              baseUrl: 'https://avdb.example',
              apiKey: 'avdb-key',
            ),
          ),
          actorAssociationsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ActorAssociationSyncSheet(
              actor: MappingRule(
                id: 1,
                mappedValue: '演员 A',
                originalValues: ['演员 A'],
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5 && repository.requests.isEmpty; i++) {
      await tester.pump();
    }

    expect(find.byType(DropdownButtonFormField<ActorDataSource>), findsNothing);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(
      tester.getCenter(find.text('DB Online')).dy,
      tester.getCenter(find.text('AVDB')).dy,
    );
    expect(repository.requests, [ActorDataSource.dbonline]);

    await tester.tap(find.text('AVDB'));
    await tester.pump();
    await tester.tap(find.text('DB Online'));
    await tester.pump();

    expect(
      repository.requests,
      [
        ActorDataSource.dbonline,
        ActorDataSource.avdb,
        ActorDataSource.dbonline,
      ],
    );
    final checkboxes = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .map((checkbox) => checkbox.value)
        .toList(growable: false);
    expect(checkboxes, [true, false]);

    oldDbo.complete(_preview('过期 DB Online 结果'));
    await tester.pump();
    expect(find.text('过期 DB Online 结果'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    currentDbo.complete(_preview('当前 DB Online 结果'));
    avdb.complete(_preview('过期 AVDB 结果'));
    await tester.pumpAndSettle();

    expect(find.text('当前 DB Online 结果'), findsOneWidget);
    expect(find.text('过期 AVDB 结果'), findsNothing);
  });
}

ActorAssocPreview _preview(String mappedValue) {
  return ActorAssocPreview(
    found: true,
    mappedValue: mappedValue,
    actorName: '演员 A',
    allAliases: const [],
    existingAliases: const [],
    newAliases: const [],
  );
}

class _PendingPreviewRepository extends ActorAssociationsRepository {
  _PendingPreviewRepository() : super(MappingsApi(Dio()));

  final List<ActorDataSource> requests = [];
  final Map<ActorDataSource, List<Completer<ActorAssocPreview>>> _pending = {
    ActorDataSource.dbonline: [],
    ActorDataSource.avdb: [],
  };

  Completer<ActorAssocPreview> enqueue(ActorDataSource source) {
    final completer = Completer<ActorAssocPreview>();
    _pending[source]!.add(completer);
    return completer;
  }

  @override
  Future<ActorAssocPreview> previewSource(
    String actorName, {
    ActorDataSource source = ActorDataSource.dbonline,
  }) {
    requests.add(source);
    return _pending[source]!.removeAt(0).future;
  }
}
