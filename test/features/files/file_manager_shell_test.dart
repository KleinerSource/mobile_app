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
import 'package:omm/features/files/file_browser_page.dart';
import 'package:omm/features/files/file_entry_icons.dart';
import 'package:omm/features/files/file_favorites.dart';
import 'package:omm/features/files/file_favorites_page.dart';
import 'package:omm/features/files/file_manager_shell.dart';
import 'package:omm/features/settings/settings_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('文件管理器悬浮导航包含文件管理、收藏与设置', (tester) async {
    await _pumpShell(tester);

    final tabBar = tester.widget<FloatingTabBar<void>>(
      find.byType(FloatingTabBar<void>),
    );
    expect(tabBar.tabs, hasLength(3));
    expect(tabBar.tabs.map((tab) => tab.label), ['文件管理', '收藏', '设置']);
    expect(find.text('文件管理'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsNWidgets(2));
  });

  testWidgets('收藏 Tab 展示独立收藏列表并可取消收藏', (tester) async {
    await _pumpShell(
      tester,
      favorites: [
        _favorite('目录 A/收藏目录', directory: true),
        _favorite('目录 A/目录 B/深层文件.txt'),
      ],
    );

    await tester.tap(find.byIcon(Icons.star_rounded).last);
    await tester.pumpAndSettle();

    final page = find.byType(FileFavoritesPage);
    expect(
      find.descendant(of: page, matching: find.text('收藏目录')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: page, matching: find.text('深层文件.txt')),
      findsOneWidget,
    );
    // 文件条目的副标题显示完整位置。
    expect(
      find.descendant(of: page, matching: find.text('目录 A/目录 B/深层文件.txt')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: page, matching: find.byTooltip('取消收藏')).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: page, matching: find.text('收藏目录')),
      findsNothing,
    );

    await tester.tap(
      find.descendant(of: page, matching: find.byTooltip('取消收藏')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: page, matching: find.textContaining('还没有收藏')),
      findsOneWidget,
    );
  });

  testWidgets('点击收藏目录切回文件 Tab 并逐级打开目录', (tester) async {
    await _pumpShell(tester, favorites: [_favorite('目录 A', directory: true)]);

    await tester.tap(find.byIcon(Icons.star_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(FileFavoritesPage),
            matching: find.text('目录 A'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('目录 B'), findsOneWidget);
    expect(find.text('根目录文件.txt'), findsNothing);
    // 被覆盖的下层根页面在导航栈中仍然保留。
    expect(find.byType(FileBrowserPage, skipOffstage: false), findsNWidgets(2));
  });

  testWidgets('点击收藏文件回到文件 Tab 并自动打开', (tester) async {
    await _pumpShell(tester, favorites: [_favorite('未知文件.bin')]);

    await tester.tap(find.byIcon(Icons.star_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(FileFavoritesPage),
            matching: find.text('未知文件.bin'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    // 根目录文件定位后自动打开详情面板。
    expect(find.text('根目录文件.txt'), findsOneWidget);
    expect(find.text('文件详情'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('已收藏条目在浏览列表中带星标且根目录无收藏分区', (tester) async {
    await _pumpShell(tester, favorites: [_favorite('目录 A', directory: true)]);

    final browser = find.byType(FileBrowserPage);
    expect(
      find.descendant(of: browser, matching: find.byIcon(Icons.star_rounded)),
      findsOneWidget,
    );
    final favoriteBadge = find.descendant(
      of: browser,
      matching: find.byWidgetPredicate(
        (widget) => widget is FileEntryIconBadge && widget.isFavorite,
      ),
    );
    expect(favoriteBadge, findsOneWidget);
    final favoriteStar = find.descendant(
      of: favoriteBadge,
      matching: find.byIcon(Icons.star_rounded),
    );
    expect(favoriteStar, findsOneWidget);
    expect(
      tester.getTopLeft(favoriteStar).dx,
      lessThan(tester.getTopLeft(favoriteBadge).dx + 16),
    );
    expect(
      tester.getTopLeft(favoriteStar).dy,
      lessThan(tester.getTopLeft(favoriteBadge).dy + 16),
    );
    expect(
      find.descendant(of: browser, matching: find.text('全部文件')),
      findsNothing,
    );
  });

  testWidgets('目录选择器从底部导航进入收藏并手动提交子目录', (tester) async {
    final prefs = await _prefs();
    await FileFavoritesRepository(
      prefs,
    ).save('file-server', [_favorite('目录 A/目标目录', directory: true)]);
    const serverId = 'file-server';
    const sourceId = SourceId('file-source');
    FilePath? picked;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            const FileDirectoryRequest(serverId: serverId, sourceId: sourceId),
          ).overrideWith((ref) async => _rootListing(sourceId)),
          fileDirectoryProvider(
            const FileDirectoryRequest(
              serverId: serverId,
              sourceId: sourceId,
              path: '目录 A/目标目录',
            ),
          ).overrideWith((ref) async => _favoriteTargetListing(sourceId)),
          fileDirectoryProvider(
            const FileDirectoryRequest(
              serverId: serverId,
              sourceId: sourceId,
              path: '目录 A/目标目录/子目录',
            ),
          ).overrideWith((ref) async => _favoriteTargetChildListing(sourceId)),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    picked = await Navigator.of(context).push<FilePath>(
                      MaterialPageRoute<FilePath>(
                        builder: (_) => const FileMoveDestinationPage(
                          serverId: serverId,
                          sourceId: sourceId,
                          initialPath: '',
                        ),
                      ),
                    );
                  },
                  child: const Text('打开选择器'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开选择器'));
    await tester.pumpAndSettle();
    expect(find.text('收藏的目录'), findsNothing);

    await tester.tap(find.byIcon(Icons.star_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('目标目录'), findsOneWidget);

    await tester.tap(find.text('目标目录'));
    await tester.pumpAndSettle();
    expect(find.text('子目录'), findsOneWidget);
    expect(picked, isNull);

    await tester.tap(find.text('子目录'));
    await tester.pumpAndSettle();
    expect(find.text('此目录为空'), findsOneWidget);
    expect(picked, isNull);

    await tester.tap(find.byTooltip('选择此目录'));
    await tester.pumpAndSettle();
    expect(picked?.value, '目录 A/目标目录/子目录');
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

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text('服务器列表'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.folder_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('目录 B'), findsOneWidget);
    expect(find.text('根目录文件.txt'), findsNothing);
  });

  testWidgets('文件管理器设置页隐藏服务器设置和退出登录', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.byIcon(Icons.settings_rounded));
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

Future<void> _pumpShell(
  WidgetTester tester, {
  List<FileFavorite> favorites = const [],
}) async {
  final prefs = await _prefs();
  if (favorites.isNotEmpty) {
    await FileFavoritesRepository(prefs).save('file-server', favorites);
  }
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

FileFavorite _favorite(String path, {bool directory = false}) {
  return FileFavorite(
    sourceId: 'file-source',
    path: path,
    name: path.split('/').where((part) => part.isNotEmpty).last,
    isDirectory: directory,
    addedAtMilliseconds: 1000,
  );
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

DirectoryListing _favoriteTargetListing(SourceId sourceId) => DirectoryListing(
  currentPath: FilePath(sourceId: sourceId, value: '目录 A/目标目录'),
  breadcrumbs: [
    FilePath(sourceId: sourceId, value: ''),
    FilePath(sourceId: sourceId, value: '目录 A'),
    FilePath(sourceId: sourceId, value: '目录 A/目标目录'),
  ],
  entries: [
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '目录 A/目标目录/子目录'),
      name: '子目录',
      type: FileEntryType.directory,
    ),
  ],
);

DirectoryListing _favoriteTargetChildListing(SourceId sourceId) =>
    DirectoryListing(
      currentPath: FilePath(sourceId: sourceId, value: '目录 A/目标目录/子目录'),
      breadcrumbs: [
        FilePath(sourceId: sourceId, value: ''),
        FilePath(sourceId: sourceId, value: '目录 A'),
        FilePath(sourceId: sourceId, value: '目录 A/目标目录'),
        FilePath(sourceId: sourceId, value: '目录 A/目标目录/子目录'),
      ],
      entries: const [],
    );
