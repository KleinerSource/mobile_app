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
}

Future<SharedPreferences> _prefs({bool twoServers = false}) async {
  SharedPreferences.setMockInitialValues({
    'server.servers': jsonEncode([
      _server('smb-one', 'SMB 一号', 'smb://nas-one:445/share-one'),
      if (twoServers) _server('webdav-two', 'WebDAV 二号', 'https://nas-two/dav'),
    ]),
    'server.active_server_id': 'smb-one',
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
