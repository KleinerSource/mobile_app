import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_source_providers.dart';
import 'package:omm/features/files/file_manager_shell.dart';
import 'package:omm/features/settings/settings_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('文件管理器悬浮导航只包含文件管理和设置', (tester) async {
    await _pumpShell(tester);

    final tabBar = tester.widget<FloatingTabBar<void>>(
      find.byType(FloatingTabBar<void>),
    );
    expect(tabBar.tabs, hasLength(2));
    expect(tabBar.tabs.map((tab) => tab.label), ['文件管理', '设置']);
    expect(find.text('文件管理'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsNWidgets(2));
  });

  testWidgets('进入多级目录后悬浮导航仍然显示', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.text('目录 A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('目录 B'));
    await tester.pumpAndSettle();

    expect(find.text('深层文件.txt'), findsOneWidget);
    expect(find.byType(FloatingTabBar<void>), findsOneWidget);
    expect(find.text('文件管理'), findsOneWidget);
  });

  testWidgets('系统返回在文件管理器内先返回上一级目录', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.text('目录 A'));
    await tester.pumpAndSettle();
    expect(find.text('目录 B'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('目录 A'), findsOneWidget);
    expect(find.text('根目录文件.txt'), findsOneWidget);
  });

  testWidgets('切换设置再回到文件管理时保留当前目录', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.text('目录 A'));
    await tester.pumpAndSettle();
    expect(find.text('目录 B'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('服务器列表'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.folder_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('目录 B'), findsOneWidget);
    expect(find.text('根目录文件.txt'), findsNothing);
  });

  testWidgets('文件管理器设置页隐藏服务器设置和退出登录', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('服务器列表'), findsOneWidget);
    expect(find.text('应用设置'), findsOneWidget);
    expect(find.text('服务器设置'), findsNothing);
    expect(find.text('退出登录'), findsNothing);
  });

  testWidgets('文件详情面板使用根 Navigator 位于悬浮导航之上', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.text('未知文件.bin'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('文件详情'), findsOneWidget);
    expect(find.byType(FloatingTabBar<void>), findsOneWidget);

    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
    expect(find.text('文件详情'), findsNothing);
  });
}

Future<void> _pumpShell(WidgetTester tester) async {
  final prefs = await _prefs();
  const serverId = 'file-server';
  const sourceId = SourceId('file-source');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appPackageInfoProvider.overrideWith(
          (_) async => PackageInfo(
            appName: 'Oh-My-Media',
            packageName: 'com.ohmymedia.omm',
            version: '0.0.0',
            buildNumber: '0',
          ),
        ),
        fileSourceDescriptorsProvider(serverId).overrideWith(
          (ref) async => [
            const SourceDescriptor(
              id: sourceId,
              kind: SourceKind.smb,
              name: '测试文件来源',
              serverId: serverId,
              endpoint: 'smb://test/share',
            ),
          ],
        ),
        fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
        fileDirectoryProvider(
          const FileDirectoryRequest(serverId: serverId, sourceId: sourceId),
        ).overrideWith((ref) async => _rootListing(sourceId)),
        fileDirectoryProvider(
          const FileDirectoryRequest(
            serverId: serverId,
            sourceId: sourceId,
            path: '目录 A',
          ),
        ).overrideWith((ref) async => _levelOneListing(sourceId)),
        fileDirectoryProvider(
          const FileDirectoryRequest(
            serverId: serverId,
            sourceId: sourceId,
            path: '目录 A/目录 B',
          ),
        ).overrideWith((ref) async => _levelTwoListing(sourceId)),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: FileManagerShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({
    'server.servers': jsonEncode([
      {
        'id': 'file-server',
        'name': '文件服务器',
        'lines': [
          {
            'id': 'file-server-line',
            'name': '主线路',
            'base_url': 'smb://test/share',
          },
        ],
        'active_line_id': 'file-server-line',
        'project_name': 'smb',
      },
    ]),
    'server.active_server_id': 'file-server',
  });
  return SharedPreferences.getInstance();
}

DirectoryListing _rootListing(SourceId sourceId) => DirectoryListing(
  currentPath: FilePath(sourceId: sourceId, value: ''),
  breadcrumbs: [FilePath(sourceId: sourceId, value: '')],
  entries: [
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '目录 A'),
      name: '目录 A',
      type: FileEntryType.directory,
    ),
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '根目录文件.txt'),
      name: '根目录文件.txt',
      type: FileEntryType.file,
    ),
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '未知文件.bin'),
      name: '未知文件.bin',
      type: FileEntryType.file,
    ),
  ],
);

DirectoryListing _levelOneListing(SourceId sourceId) => DirectoryListing(
  currentPath: FilePath(sourceId: sourceId, value: '目录 A'),
  breadcrumbs: [
    FilePath(sourceId: sourceId, value: ''),
    FilePath(sourceId: sourceId, value: '目录 A'),
  ],
  entries: [
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '目录 A/目录 B'),
      name: '目录 B',
      type: FileEntryType.directory,
    ),
  ],
);

DirectoryListing _levelTwoListing(SourceId sourceId) => DirectoryListing(
  currentPath: FilePath(sourceId: sourceId, value: '目录 A/目录 B'),
  breadcrumbs: [
    FilePath(sourceId: sourceId, value: ''),
    FilePath(sourceId: sourceId, value: '目录 A'),
    FilePath(sourceId: sourceId, value: '目录 A/目录 B'),
  ],
  entries: [
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '目录 A/目录 B/深层文件.txt'),
      name: '深层文件.txt',
      type: FileEntryType.file,
    ),
  ],
);
