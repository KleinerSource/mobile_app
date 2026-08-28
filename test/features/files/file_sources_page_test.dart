import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_source_providers.dart';
import 'package:omm/features/files/file_browser_page.dart';
import 'package:omm/features/files/file_sources_page.dart';
import 'package:omm/features/settings/server_selection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('文件服务器直接打开自己的根目录而不显示来源 URL 列表', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final listing = _listing(sourceId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceDescriptorsProvider(serverId).overrideWith(
            (ref) async => [
              const SourceDescriptor(
                id: SourceId('source-one'),
                kind: SourceKind.smb,
                name: 'SMB 一号',
                serverId: serverId,
                endpoint: 'smb://nas-one/share',
              ),
            ],
          ),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            FileDirectoryRequest(serverId: serverId, sourceId: sourceId),
          ).overrideWith((ref) async => listing),
        ],
        child: const MaterialApp(home: FileSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选择一个文件来源'), findsNothing);
    expect(find.byType(FileBrowserPage), findsOneWidget);
    expect(find.text('目录 A'), findsOneWidget);
    expect(find.text('影片.mkv'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    expect(
      tester.widget<FileBrowserPage>(find.byType(FileBrowserPage)).serverId,
      serverId,
    );
  });

  testWidgets('文件浏览页使用更多菜单管理列表，并支持隐藏文件和多选', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            FileDirectoryRequest(serverId: serverId, sourceId: sourceId),
          ).overrideWith((ref) async => _listingWithHidden(sourceId)),
        ],
        child: MaterialApp(
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byTooltip('更多'), findsOneWidget);
    expect(find.byTooltip('文件操作'), findsNWidgets(2));
    expect(find.text('.隐藏文件'), findsNothing);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('新建文件夹'), findsOneWidget);
    expect(find.text('选择'), findsOneWidget);
    expect(find.text('显示隐藏文件'), findsOneWidget);
    expect(find.text('名称排序 ↑'), findsOneWidget);
    expect(find.text('日期排序'), findsOneWidget);
    expect(find.text('大小排序'), findsOneWidget);
    expect(find.text('类别排序'), findsOneWidget);

    await tester.tap(find.text('显示隐藏文件'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('.隐藏文件'), findsOneWidget);

    await tester.longPress(find.text('影片.mkv'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsNWidgets(2));
    expect(find.byTooltip('删除所选'), findsOneWidget);
  });

  testWidgets('文件浏览页可以返回服务器选择器', (tester) async {
    final prefs = await _prefs(twoServers: true);
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceDescriptorsProvider(serverId).overrideWith(
            (ref) async => [
              const SourceDescriptor(
                id: SourceId('source-one'),
                kind: SourceKind.smb,
                name: 'SMB 一号',
                serverId: serverId,
              ),
            ],
          ),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            FileDirectoryRequest(serverId: serverId, sourceId: sourceId),
          ).overrideWith((ref) async => _listing(sourceId)),
        ],
        child: const MaterialApp(home: FileSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('返回服务器选择'));
    await tester.pumpAndSettle();

    expect(find.text('选择服务器'), findsOneWidget);
    expect(find.text('WebDAV 二号'), findsOneWidget);
  });

  testWidgets('SMB 子目录边缘返回先回到根目录，再打开服务器选择器', (tester) async {
    await _testNestedEdgeBack(
      tester,
      serverId: 'smb-one',
      serverName: 'SMB 一号',
    );
  });

  testWidgets('WebDAV 子目录边缘返回先回到根目录，再打开服务器选择器', (tester) async {
    await _testNestedEdgeBack(
      tester,
      serverId: 'webdav-two',
      serverName: 'WebDAV 二号',
    );
  });
}

Future<void> _testNestedEdgeBack(
  WidgetTester tester, {
  required String serverId,
  required String serverName,
}) async {
  final prefs = await _prefs(twoServers: true, activeServerId: serverId);
  final sourceId = SourceId.of('$serverId-source');
  final rootRequest = FileDirectoryRequest(
    serverId: serverId,
    sourceId: sourceId,
  );
  final nestedRequest = FileDirectoryRequest(
    serverId: serverId,
    sourceId: sourceId,
    path: '子目录',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
        fileDirectoryProvider(
          rootRequest,
        ).overrideWith((ref) async => _listingAt(sourceId, '', '根目录内容')),
        fileDirectoryProvider(
          nestedRequest,
        ).overrideWith((ref) async => _listingAt(sourceId, '子目录', '子目录内容')),
      ],
      child: MaterialApp(
        home: FileBrowserPage(
          serverId: serverId,
          sourceId: sourceId,
          initialPath: '子目录',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('子目录内容'), findsOneWidget);

  Future<void> swipeFromEdge() async {
    final gesture = await tester.startGesture(const Offset(2, 300));
    await gesture.moveTo(const Offset(100, 300));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  await swipeFromEdge();
  expect(find.text('根目录内容'), findsOneWidget);
  expect(find.text('子目录内容'), findsNothing);

  await swipeFromEdge();
  expect(find.byType(ServerSelectionPage), findsOneWidget);
  expect(find.text(serverName), findsOneWidget);
}

Future<SharedPreferences> _prefs({
  bool twoServers = false,
  String activeServerId = 'smb-one',
}) async {
  SharedPreferences.setMockInitialValues({
    'server.servers': jsonEncode([
      _server('smb-one', 'SMB 一号', 'smb://nas-one:445/share-one'),
      if (twoServers || activeServerId == 'webdav-two')
        _server('webdav-two', 'WebDAV 二号', 'https://nas-two/dav'),
    ]),
    'server.active_server_id': activeServerId,
  });
  return SharedPreferences.getInstance();
}

Map<String, dynamic> _server(String id, String name, String baseUrl) => {
  'id': id,
  'name': name,
  'lines': [
    {'id': '$id-line', 'name': '主线路', 'base_url': baseUrl},
  ],
  'active_line_id': '$id-line',
  'project_name': baseUrl.startsWith('smb') ? 'smb' : 'webdav',
};

DirectoryListing _listing(SourceId sourceId) => DirectoryListing(
  currentPath: FilePath(sourceId: sourceId, value: ''),
  breadcrumbs: [FilePath(sourceId: sourceId, value: '')],
  entries: [
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '目录 A'),
      name: '目录 A',
      type: FileEntryType.directory,
    ),
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '影片.mkv'),
      name: '影片.mkv',
      type: FileEntryType.file,
      size: 1024,
    ),
  ],
);

DirectoryListing _listingWithHidden(SourceId sourceId) {
  final listing = _listing(sourceId);
  return DirectoryListing(
    currentPath: listing.currentPath,
    breadcrumbs: listing.breadcrumbs,
    entries: [
      ...listing.entries,
      FileEntry(
        path: FilePath(sourceId: sourceId, value: '.隐藏文件'),
        name: '.隐藏文件',
        type: FileEntryType.file,
        isHidden: true,
      ),
    ],
  );
}

DirectoryListing _listingAt(SourceId sourceId, String path, String name) =>
    DirectoryListing(
      currentPath: FilePath(sourceId: sourceId, value: path),
      breadcrumbs: [
        FilePath(sourceId: sourceId, value: ''),
        if (path.isNotEmpty) FilePath(sourceId: sourceId, value: path),
      ],
      entries: [
        FileEntry(
          path: FilePath(
            sourceId: sourceId,
            value: path.isEmpty ? name : '$path/$name',
          ),
          name: name,
          type: FileEntryType.file,
        ),
      ],
    );
