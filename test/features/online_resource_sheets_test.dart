import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/features/db_online/widgets/db_online_resource_sheets.dart';
import 'package:omm/features/oh_my_media/movie_detail/resources_sheet.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/resource_panel_components.dart';

typedef _Resources = ({
  List<Map<String, dynamic>> magnets,
  List<Map<String, dynamic>> ed2ks,
  List<String> warnings,
});

const _empty = (
  magnets: <Map<String, dynamic>>[],
  ed2ks: <Map<String, dynamic>>[],
  warnings: <String>[],
);
const _downloaders = [(name: 'thunder', displayName: '迅雷', ed2kEnabled: true)];
const _ed2kUrl = 'ed2k://|file|TEST-001.mp4|1024|0123456789abcdef|/';

_Resources _resources({int magnets = 0, bool ed2k = false}) => (
  magnets: List.generate(
    magnets,
    (index) => {
      'name': '磁链资源 $index',
      'magnet':
          'magnet:?xt=urn:btih:${(index + 1).toRadixString(16).padLeft(40, '0')}',
    },
  ),
  ed2ks: [
    if (ed2k) {'name': 'ED2K 资源', 'ed2k': _ed2kUrl},
  ],
  warnings: [],
);

void main() {
  for (final dbo in [false, true]) {
    final module = dbo ? 'DBO' : 'OMM';

    Future<void> pumpSheet(WidgetTester tester, _Fixture fixture) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            if (dbo)
              dboMediaRepositoryProvider.overrideWithValue(
                _DboRepository(fixture),
              )
            else
              mediaRepositoryProvider.overrideWithValue(
                _OmmRepository(fixture),
              ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: dbo
                  ? DbOnlineResourcesSheet(movie: fixture.movie)
                  : const ResourcesSheet(
                      movie: MovieDetail(id: 1, title: '测试影片', num: 'TEST-001'),
                    ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    for (final magnets in [0, 1]) {
      for (final ed2k in [false, true]) {
        testWidgets('$module 资源组合 $magnets / $ed2k 决定 tabs 是否显示', (
          tester,
        ) async {
          final fixture = _Fixture(_resources(magnets: magnets, ed2k: ed2k));
          await pumpSheet(tester, fixture);
          await tester.pumpAndSettle();

          expect(find.text('在线资源'), findsOneWidget);
          expect(
            find.byType(ResourcePanelTabButton),
            magnets > 0 && ed2k ? findsNWidgets(2) : findsNothing,
          );
          if (magnets > 0) {
            expect(find.text('磁链资源 0'), findsOneWidget);
          } else if (ed2k) {
            expect(find.text('ED2K 资源'), findsOneWidget);
            await tester.drag(find.byType(ListView), const Offset(200, 0));
            await tester.pumpAndSettle();
            expect(find.text('ED2K 资源'), findsOneWidget);
            await tester.tap(find.byTooltip('推送下载'));
            await tester.pumpAndSettle();
            expect(fixture.downloads.single['urls'], [_ed2kUrl]);
            expect(fixture.downloads.single['protocol'], 'ed2k');
          } else {
            expect(find.text('没有磁力资源'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('$module 左右滑动与点击同步，切换后下载 ED2K', (tester) async {
      final fixture = _Fixture(_resources(magnets: 1, ed2k: true));
      await pumpSheet(tester, fixture);
      await tester.pumpAndSettle();
      final initialHeight = tester
          .getSize(find.byType(ResourcePanelSwipeArea))
          .height;
      expect(initialHeight, lessThan(300));

      await tester.drag(find.byType(ListView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('ED2K 资源'), findsOneWidget);
      expect(
        tester
            .widget<ResourcePanelTabButton>(
              find.widgetWithText(ResourcePanelTabButton, 'ED2K (1)'),
            )
            .active,
        isTrue,
      );

      await tester.drag(find.byType(ListView), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(find.text('磁链资源 0'), findsOneWidget);
      await tester.tap(find.text('ED2K (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('推送下载'));
      await tester.pumpAndSettle();
      expect(fixture.downloads.single['urls'], [_ed2kUrl]);
      expect(fixture.downloads.single['protocol'], 'ed2k');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$module 延迟返回另一类资源后显示 tabs 并保留当前资源', (tester) async {
      final fixture = _Fixture(_resources(ed2k: true))
        ..custom = Completer<_Resources>();
      await pumpSheet(tester, fixture);
      expect(find.byType(ResourcePanelTabButton), findsNothing);
      expect(find.text('ED2K 资源'), findsOneWidget);

      fixture.custom!.complete(_resources(magnets: 1));
      await tester.pumpAndSettle();
      expect(find.byType(ResourcePanelTabButton), findsNWidgets(2));
      expect(find.text('ED2K 资源'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(find.text('磁链资源 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$module 刷新移除当前资源类型后隐藏 tabs 并展示剩余资源', (tester) async {
      final fixture = _Fixture(_resources(magnets: 1, ed2k: true));
      await pumpSheet(tester, fixture);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ED2K (1)'));
      await tester.pumpAndSettle();

      fixture.resources = _resources(magnets: 1);
      await tester.tap(find.byTooltip('刷新'));
      await tester.pumpAndSettle();
      expect(find.byType(ResourcePanelTabButton), findsNothing);
      expect(find.text('磁链资源 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$module 长列表纵向滚动不会切换资源类型', (tester) async {
      await pumpSheet(tester, _Fixture(_resources(magnets: 30, ed2k: true)));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0));
      expect(
        tester
            .widget<ResourcePanelTabButton>(
              find.widgetWithText(ResourcePanelTabButton, '磁力 (30)'),
            )
            .active,
        isTrue,
      );
      expect(find.text('ED2K 资源'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Fixture {
  _Fixture(this.resources);
  _Resources resources;
  Completer<_Resources>? custom;
  final downloads = <Map<String, dynamic>>[];

  DbOnlineExternalResources external(_Resources value) =>
      DbOnlineExternalResources(
        magnets: value.magnets
            .map(
              (item) => DbOnlineMagnet(
                name: item['name'] as String,
                magnet: item['magnet'] as String,
              ),
            )
            .toList(),
        ed2ks: value.ed2ks
            .map(
              (item) => DbOnlineEd2k(
                name: item['name'] as String,
                ed2k: item['ed2k'] as String,
              ),
            )
            .toList(),
      );

  DbOnlineMovieDetail get movie {
    final items = external(resources);
    return DbOnlineMovieDetail(
      code: 'TEST-001',
      title: '测试影片',
      magnets: items.magnets,
      ed2ks: items.ed2ks,
    );
  }

  void record(List<String> urls, List<Map<String, dynamic>> recordResources) {
    downloads.add({
      'urls': urls,
      'protocol': recordResources.single['resource_protocol'],
    });
  }
}

class _OmmRepository implements MediaRepository {
  _OmmRepository(this.fixture);
  final _Fixture fixture;

  @override
  Future<_Resources> getResourcesBySource(int id, String source) async =>
      source == 'detail'
      ? fixture.resources
      : source == 'custom'
      ? await fixture.custom?.future ?? _empty
      : _empty;

  @override
  Future<List<({String name, String displayName, bool? ed2kEnabled})>>
  getDownloaders() async => _downloaders;

  @override
  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  getDownloadHistory(int id) async =>
      (magnets: <String, String>{}, ed2ks: <String, String>{});

  @override
  Future<({String message, String lastDownloadedAt})> pushDownload({
    required List<String> urls,
    required String downloader,
    required int movieId,
    Map<String, dynamic>? videoInfo,
    List<Map<String, dynamic>> recordResources = const [],
    String savePath = '',
  }) async {
    fixture.record(urls, recordResources);
    return (message: '下载任务已添加', lastDownloadedAt: '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _DboRepository implements DboMediaRepository {
  _DboRepository(this.fixture);
  final _Fixture fixture;

  @override
  Future<DbOnlineMovieDetail> getMovieDetail(
    String key, {
    bool refresh = true,
  }) async => fixture.movie;

  @override
  Future<DbOnlineExternalResources> getCustomResources(String code) async =>
      fixture.external(await fixture.custom?.future ?? _empty);

  @override
  Future<DbOnlineExternalResources> getNyaaResources(String code) async =>
      fixture.external(_empty);

  @override
  Future<List<({String name, String displayName, bool? ed2kEnabled})>>
  getDownloaders() async => _downloaders;

  @override
  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  getDownloadHistory(String code) async =>
      (magnets: <String, String>{}, ed2ks: <String, String>{});

  @override
  Future<({String message, String downloader})> pushDownload({
    required List<String> urls,
    required String downloader,
    required Map<String, dynamic> videoInfo,
    required List<Map<String, dynamic>> recordResources,
  }) async {
    fixture.record(urls, recordResources);
    return (message: '下载任务已添加', downloader: downloader);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
