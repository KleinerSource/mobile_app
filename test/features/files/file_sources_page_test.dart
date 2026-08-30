import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_capabilities.dart';
import 'package:omm/core/sources/files/file_source.dart';
import 'package:omm/core/sources/files/file_source_providers.dart';
import 'package:omm/features/files/file_browser_page.dart';
import 'package:omm/features/files/file_move_start_settings.dart';
import 'package:omm/features/files/file_sources_page.dart';
import 'package:omm/features/settings/app_settings_page.dart';
import 'package:omm/features/settings/server_selection_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
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
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileSourcesPage(),
        ),
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

  testWidgets('文件条目按日期、大小顺序显示并使用元信息配色', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final listing = DirectoryListing(
      currentPath: FilePath(sourceId: sourceId, value: ''),
      breadcrumbs: [FilePath(sourceId: sourceId, value: '')],
      entries: [
        FileEntry(
          path: FilePath(sourceId: sourceId, value: '影片.mkv'),
          name: '影片.mkv',
          type: FileEntryType.file,
          size: 1024,
          modifiedAt: DateTime(2025, 1, 2, 3, 4),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            FileDirectoryRequest(serverId: serverId, sourceId: sourceId),
          ).overrideWith((ref) async => listing),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final metaFinder = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText() == '2025-01-02 03:04 · 1.0 KB',
    );
    expect(metaFinder, findsOneWidget);
    final richText = tester.widget<RichText>(metaFinder).text as TextSpan;
    final meta = richText.children!.single as TextSpan;
    expect(meta.children, hasLength(3));
    expect((meta.children![0] as TextSpan).text, '2025-01-02 03:04');
    expect((meta.children![2] as TextSpan).text, '1.0 KB');
    expect((meta.children![0] as TextSpan).style?.color, AppColors.light.muted);
    expect(
      (meta.children![0] as TextSpan).style?.fontWeight,
      FontWeight.normal,
    );
  });

  testWidgets('右上角菜单提供强制刷新并重新加载目录', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    var listingCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceDescriptorsProvider(serverId).overrideWith(
            (ref) async => [
              const SourceDescriptor(
                id: SourceId('source-one'),
                kind: SourceKind.openList,
                name: 'OpenList 一号',
                serverId: serverId,
                endpoint: 'http://nas-one:5244',
              ),
            ],
          ),
          fileSourceProvider(sourceId.value).overrideWith(
            (ref) async => _KindFileSource(SourceKind.openList),
          ),
          fileDirectoryProvider(
            FileDirectoryRequest(serverId: serverId, sourceId: sourceId),
          ).overrideWith((ref) async {
            listingCalls += 1;
            return _listing(sourceId);
          }),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileSourcesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(listingCalls, 1);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('强制刷新'), findsOneWidget);

    await tester.tap(find.text('强制刷新'));
    await tester.pumpAndSettle();

    expect(listingCalls, 2);
    expect(find.text('影片.mkv'), findsOneWidget);
  });

  testWidgets('SMB 来源的菜单不提供强制刷新', (tester) async {
    final prefs = await _prefs();
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
                endpoint: 'smb://nas-one/share',
              ),
            ],
          ),
          fileSourceProvider(sourceId.value).overrideWith(
            (ref) async => _KindFileSource(SourceKind.smb),
          ),
          fileDirectoryProvider(
            FileDirectoryRequest(serverId: serverId, sourceId: sourceId),
          ).overrideWith((ref) async => _listing(sourceId)),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileSourcesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    expect(find.text('强制刷新'), findsNothing);
    expect(find.text('新建文件夹'), findsOneWidget);
  });

  testWidgets('debug 模式下点击视频先显示播放器选择器', (tester) async {
    final prefs = await _prefs();
    await prefs.setBool('player.debug_mode', true);
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final request = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(request).overrideWith(
            (ref) async => _listing(sourceId),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('影片.mkv'));
    await tester.pumpAndSettle();

    expect(find.text('选择播放器'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player-engine-libmpv')),
      findsOneWidget,
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('选择播放器'), findsNothing);
  });

  testWidgets('大小写 M3U8 文件按视频打开播放器选择器', (tester) async {
    final prefs = await _prefs();
    await prefs.setBool('player.debug_mode', true);
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final request = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(request).overrideWith(
            (ref) async => _listingWithEntry(
              sourceId,
              name: '直播.M3U8',
              mimeType: 'text/plain',
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('直播.M3U8'));
    await tester.pumpAndSettle();

    expect(find.text('选择播放器'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('选择播放器'), findsNothing);
  });

  testWidgets('非 debug 模式下点击视频不显示播放器选择器', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final request = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(request).overrideWith(
            (ref) async => _listing(sourceId),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('影片.mkv'));
    await tester.pumpAndSettle();

    expect(find.text('选择播放器'), findsNothing);
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
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
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

    await tester.tap(find.byTooltip('文件操作').first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.drive_file_rename_outline), findsOneWidget);
    expect(find.byIcon(Icons.drive_file_move_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

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
    expect(find.text('已选 1 项'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byTooltip('批量操作'), findsOneWidget);

    await tester.tap(find.byTooltip('批量操作'));
    await tester.pumpAndSettle();
    expect(find.text('移动'), findsOneWidget);
    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('视频播放进度显示在文件操作按钮左侧且不显示百分比文案', (tester) async {
    final prefs = await _prefs();
    await prefs.setString(
      'file.playback.position.${base64Url.encode(utf8.encode('影片.mkv'))}',
      jsonEncode({'position_sec': 42, 'duration_sec': 300}),
    );
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final request = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            request,
          ).overrideWith((ref) async => _listing(sourceId)),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('已播放'), findsNothing);
    final videoRow = find.ancestor(
      of: find.text('影片.mkv'),
      matching: find.byType(ListTile),
    );
    final progress = find.descendant(
      of: videoRow,
      matching: find.byType(CircularProgressIndicator),
    );
    final fileMenu = find.descendant(
      of: videoRow,
      matching: find.byTooltip('文件操作'),
    );
    expect(progress, findsOneWidget);
    expect(fileMenu, findsOneWidget);
    expect(
      tester.getCenter(progress).dx,
      lessThan(tester.getCenter(fileMenu).dx),
    );
  });

  testWidgets('文件普通移动使用目录选择页而不是路径输入', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final request = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            request,
          ).overrideWith((ref) async => _listingWithHidden(sourceId)),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('文件操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动'));
    await tester.pumpAndSettle();

    expect(find.text('选择目标目录'), findsOneWidget);
    expect(find.byTooltip('选择此目录'), findsOneWidget);
    expect(find.text('目标完整路径'), findsNothing);

    await tester.tap(find.byTooltip('取消选择'));
    await tester.pumpAndSettle();
    expect(find.text('SMB 一号'), findsOneWidget);
  });

  testWidgets('移动文件默认从根目录开始选择目标', (tester) async {
    await _pumpMoveStartFixture(tester);
    expect(find.text('选择目标目录'), findsOneWidget);
    expect(find.text('目录 A'), findsOneWidget);
    expect(find.text('子目录'), findsNothing);
  });

  testWidgets('设置当前目录后移动文件从所在目录开始选择目标', (tester) async {
    await _pumpMoveStartFixture(
      tester,
      startLocation: FileMoveStartLocation.current,
    );
    expect(find.text('选择目标目录'), findsOneWidget);
    expect(find.text('子目录'), findsOneWidget);
    // 面包屑可以一路点回根目录。
    await tester.tap(find.text('根目录'));
    await tester.pumpAndSettle();
    expect(find.text('目录 A'), findsOneWidget);
    expect(find.text('子目录'), findsNothing);
  });

  testWidgets('移动文件起始位置默认在设置中提供切换入口', (tester) async {
    final prefs = await _prefs();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: AppSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.text('移动文件起始位置');
    // 设置项在文件管理器分组里，位于首屏之外，需要滚动到可见。
    await tester.scrollUntilVisible(tile, 200);
    await tester.pumpAndSettle();
    expect(tile, findsOneWidget);
    expect(find.text('当前：根目录'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('当前所在目录'));
    await tester.pumpAndSettle();

    expect(
      container.read(fileMoveStartProvider),
      FileMoveStartLocation.current,
    );
    expect(prefs.getString('file.move_start_location'), 'current');
  });

  testWidgets('文件批量重命名复用统一工具栏并提供替换预览', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final request = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            request,
          ).overrideWith((ref) async => _listing(sourceId)),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('影片.mkv'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('批量操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名').last);
    await tester.pumpAndSettle();

    expect(find.text('批量重命名'), findsOneWidget);
    expect(find.text('查询'), findsOneWidget);
    expect(find.text('替换为'), findsOneWidget);
    expect(find.text('预览'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'MKV');
    await tester.enterText(fields.at(1), 'MP4');
    await tester.pump();
    expect(find.text('影片.MP4'), findsOneWidget);

    final dropdownFields = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString().contains('DropdownButtonFormField'),
    );
    await tester.tap(dropdownFields.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加文本').last);
    await tester.pumpAndSettle();

    final addTextField = tester.getRect(find.byType(TextField));
    final addPositionField = tester.getRect(dropdownFields.last);
    expect(addPositionField.top - addTextField.bottom, closeTo(10, 0.1));

    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(find.text('批量重命名'), findsNothing);
  });

  testWidgets('无法识别的文件点击后使用玻璃面板显示详情', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final request = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            request,
          ).overrideWith((ref) async => _listingWithUnknown(sourceId)),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('未知文件.bin'));
    await tester.pumpAndSettle();
    expect(find.text('文件详情'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);

    // 详情面板不再提供关闭按钮；点遮罩收起。
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('文件详情'), findsNothing);
  });

  testWidgets('可识别文本直接打开文本查看器并格式化 JSON', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final request = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );
    const jsonText = '{"name":"测试","items":[1,2]}';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith(
            (ref) async => _PreviewFileSource(sourceId, jsonText.codeUnits),
          ),
          fileDirectoryProvider(request).overrideWith(
            (ref) async => _listingWithEntry(
              sourceId,
              name: '数据.json',
              mimeType: 'application/json',
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('数据.json'));
    await tester.pumpAndSettle();

    expect(find.text('数据.json'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('可识别图片直接打开图片查看器', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final request = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );
    final png = <int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1f,
      0x15,
      0xc4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9c,
      0x63,
      0xf8,
      0xcf,
      0xf0,
      0x1f,
      0x00,
      0x05,
      0x00,
      0x01,
      0xff,
      0x89,
      0x99,
      0x3d,
      0x1d,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4e,
      0x44,
      0xae,
      0x42,
      0x60,
      0x82,
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(
            sourceId.value,
          ).overrideWith((ref) async => _PreviewFileSource(sourceId, png)),
          fileDirectoryProvider(
            request,
          ).overrideWith((ref) async => _listingWithImages(sourceId)),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('封面.png'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    final viewerFinder = find.byType(InteractiveViewer);
    final viewerCenter = tester.getCenter(viewerFinder);
    final firstFinger = await tester.startGesture(
      viewerCenter + const Offset(-24, 0),
      pointer: 1,
    );
    final secondFinger = await tester.startGesture(
      viewerCenter + const Offset(24, 0),
      pointer: 2,
    );
    await firstFinger.moveBy(const Offset(-36, 0));
    await secondFinger.moveBy(const Offset(36, 0));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      greaterThan(1.0),
    );
    await firstFinger.up();
    await secondFinger.up();
    await tester.pumpAndSettle();

    await tester.tapAt(viewerCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(viewerCenter);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      closeTo(1.0, 0.01),
    );

    await tester.tapAt(viewerCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(viewerCenter);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      closeTo(2.0, 0.01),
    );

    await tester.tapAt(viewerCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(viewerCenter);
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-360, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(0, 360), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
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
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileSourcesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('返回服务器选择'));
    await tester.pumpAndSettle();

    expect(find.text('选择服务器'), findsOneWidget);
    expect(find.text('WebDAV 二号'), findsOneWidget);
  });

  testWidgets('点击根目录面包屑回到文件列表根页而不是服务器选择器', (tester) async {
    final prefs = await _prefs();
    const serverId = 'smb-one';
    final sourceId = SourceId.of('source-one');
    final rootRequest = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );
    final nestedRequest = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
      path: '目录 A',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            rootRequest,
          ).overrideWith((ref) async => _listingWithDirectory(sourceId)),
          fileDirectoryProvider(
            nestedRequest,
          ).overrideWith((ref) async => _listingAt(sourceId, '目录 A', '子目录内容')),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('目录 A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('根目录'));
    await tester.pumpAndSettle();

    expect(find.text('根目录内容'), findsOneWidget);
    expect(find.text('子目录内容'), findsNothing);
    expect(find.byType(ServerSelectionPage), findsNothing);
  });

  testWidgets('WebDAV 根目录面包屑使用与 SMB 相同的文件根页返回逻辑', (tester) async {
    final prefs = await _prefs();
    const serverId = 'webdav-two';
    final sourceId = SourceId.of('webdav-source');
    final rootRequest = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );
    final nestedRequest = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
      path: '/目录 A',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            rootRequest,
          ).overrideWith((ref) async => _webDavListingWithDirectory(sourceId)),
          fileDirectoryProvider(
            nestedRequest,
          ).overrideWith((ref) async => _webDavListingAt(sourceId)),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('目录 A').first);
    await tester.pumpAndSettle();
    expect(find.text('子目录内容'), findsOneWidget);

    await tester.tap(find.text('根目录'));
    await tester.pumpAndSettle();

    expect(find.text('根目录内容'), findsOneWidget);
    expect(find.text('子目录内容'), findsNothing);
    expect(find.byType(ServerSelectionPage), findsNothing);
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

  testWidgets('文件目录使用页面返回栈并可从选择器重新进入服务器', (tester) async {
    final prefs = await _prefs(twoServers: true);
    const serverId = 'smb-one';
    final sourceId = SourceId.of('smb-source');
    final rootRequest = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
    );
    final nestedRequest = FileDirectoryRequest(
      serverId: serverId,
      sourceId: sourceId,
      path: '目录 A',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
          fileDirectoryProvider(
            rootRequest,
          ).overrideWith((ref) async => _listingWithDirectory(sourceId)),
          fileDirectoryProvider(
            nestedRequest,
          ).overrideWith((ref) async => _listingAt(sourceId, '目录 A', '子目录内容')),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('目录 A'));
    await tester.pumpAndSettle();
    expect(find.text('子目录内容'), findsOneWidget);
    expect(find.byType(FileBrowserPage, skipOffstage: false), findsNWidgets(2));

    Future<void> swipeFromEdge() async {
      final gesture = await tester.startGesture(const Offset(2, 300));
      await gesture.moveTo(const Offset(100, 300));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await swipeFromEdge();
    expect(find.text('根目录内容'), findsOneWidget);
    expect(find.text('子目录内容'), findsNothing);
    expect(find.byType(FileBrowserPage), findsOneWidget);

    await swipeFromEdge();
    expect(find.byType(ServerSelectionPage), findsOneWidget);
    expect(find.text('WebDAV 二号'), findsOneWidget);

    await tester.tap(find.text('WebDAV 二号'));
    await tester.pumpAndSettle();
    expect(find.byType(ServerSelectionPage), findsNothing);
    expect(prefs.getString('server.active_server_id'), 'webdav-two');
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
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
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

/// 移动文件起始位置测试夹具：从根目录进入「目录 A」，再在该目录页发起
/// 移动，返回时目录选择器已打开。
Future<void> _pumpMoveStartFixture(
  WidgetTester tester, {
  FileMoveStartLocation? startLocation,
}) async {
  final prefs = await _prefs();
  if (startLocation != null) {
    await prefs.setString('file.move_start_location', startLocation.name);
  }
  const serverId = 'smb-one';
  const sourceId = SourceId('source-one');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        fileSourceProvider(sourceId.value).overrideWith((ref) async => null),
        fileDirectoryProvider(
          const FileDirectoryRequest(serverId: serverId, sourceId: sourceId),
        ).overrideWith(
          (ref) async => const DirectoryListing(
            currentPath: FilePath(sourceId: sourceId, value: ''),
            breadcrumbs: [FilePath(sourceId: sourceId, value: '')],
            entries: [
              FileEntry(
                path: FilePath(sourceId: sourceId, value: '目录 A'),
                name: '目录 A',
                type: FileEntryType.directory,
              ),
            ],
          ),
        ),
        fileDirectoryProvider(
          const FileDirectoryRequest(
            serverId: serverId,
            sourceId: sourceId,
            path: '目录 A',
          ),
        ).overrideWith(
          (ref) async => const DirectoryListing(
            currentPath: FilePath(sourceId: sourceId, value: '目录 A'),
            breadcrumbs: [
              FilePath(sourceId: sourceId, value: ''),
              FilePath(sourceId: sourceId, value: '目录 A'),
            ],
            entries: [
              FileEntry(
                path: FilePath(sourceId: sourceId, value: '目录 A/子目录'),
                name: '子目录',
                type: FileEntryType.directory,
              ),
              FileEntry(
                path: FilePath(sourceId: sourceId, value: '目录 A/影片.mkv'),
                name: '影片.mkv',
                type: FileEntryType.file,
              ),
            ],
          ),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: FileBrowserPage(serverId: serverId, sourceId: sourceId),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('目录 A'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('文件操作').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('移动'));
  await tester.pumpAndSettle();
}

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

DirectoryListing _listingWithUnknown(SourceId sourceId) =>
    _listingWithEntry(sourceId, name: '未知文件.bin');

DirectoryListing _listingWithEntry(
  SourceId sourceId, {
  required String name,
  String? mimeType,
}) => DirectoryListing(
  currentPath: FilePath(sourceId: sourceId, value: ''),
  breadcrumbs: [FilePath(sourceId: sourceId, value: '')],
  entries: [
    FileEntry(
      path: FilePath(sourceId: sourceId, value: name),
      name: name,
      type: FileEntryType.file,
      mimeType: mimeType,
    ),
  ],
);

DirectoryListing _listingWithImages(SourceId sourceId) => DirectoryListing(
  currentPath: FilePath(sourceId: sourceId, value: ''),
  breadcrumbs: [FilePath(sourceId: sourceId, value: '')],
  entries: [
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '封面.png'),
      name: '封面.png',
      type: FileEntryType.file,
      mimeType: 'image/png',
    ),
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '第二张.jpg'),
      name: '第二张.jpg',
      type: FileEntryType.file,
      mimeType: 'image/jpeg',
    ),
  ],
);

DirectoryListing _listingWithDirectory(SourceId sourceId) => DirectoryListing(
  currentPath: FilePath(sourceId: sourceId, value: ''),
  breadcrumbs: [FilePath(sourceId: sourceId, value: '')],
  entries: [
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '目录 A'),
      name: '目录 A',
      type: FileEntryType.directory,
    ),
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '根目录内容'),
      name: '根目录内容',
      type: FileEntryType.file,
    ),
  ],
);

DirectoryListing _webDavListingWithDirectory(SourceId sourceId) =>
    DirectoryListing(
      currentPath: FilePath(sourceId: sourceId, value: '/'),
      breadcrumbs: [FilePath(sourceId: sourceId, value: '/')],
      entries: [
        FileEntry(
          path: FilePath(sourceId: sourceId, value: '/目录 A'),
          name: '目录 A',
          type: FileEntryType.directory,
        ),
        FileEntry(
          path: FilePath(sourceId: sourceId, value: '/根目录内容'),
          name: '根目录内容',
          type: FileEntryType.file,
        ),
      ],
    );

DirectoryListing _webDavListingAt(SourceId sourceId) => DirectoryListing(
  currentPath: FilePath(sourceId: sourceId, value: '/目录 A'),
  breadcrumbs: [
    FilePath(sourceId: sourceId, value: '/'),
    FilePath(sourceId: sourceId, value: '/目录 A'),
  ],
  entries: [
    FileEntry(
      path: FilePath(sourceId: sourceId, value: '/目录 A/子目录内容'),
      name: '子目录内容',
      type: FileEntryType.file,
    ),
  ],
);

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

class _KindFileSource implements FileSource {
  _KindFileSource(this.kind);

  final SourceKind kind;

  @override
  SourceDescriptor get descriptor => SourceDescriptor(
    id: const SourceId('source-one'),
    kind: kind,
    name: '测试来源',
  );

  @override
  Set<FileCapability> get capabilities => const {};

  @override
  bool supports(FileCapability capability) => false;
}

class _PreviewFileSource implements FileSource, FileAccessCapability {
  _PreviewFileSource(this.sourceId, this.bytes);

  final SourceId sourceId;
  final List<int> bytes;

  @override
  SourceDescriptor get descriptor =>
      SourceDescriptor(id: sourceId, kind: SourceKind.smb, name: '测试文件来源');

  @override
  Set<FileCapability> get capabilities => const {FileCapability.access};

  @override
  bool supports(FileCapability capability) => capabilities.contains(capability);

  @override
  Future<FileAccess> resolveAccess(FilePath path) async =>
      FileAccess(openStream: () => Stream<List<int>>.value(bytes));
}
