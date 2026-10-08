import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_source_providers.dart';
import 'package:omm/features/files/file_browser_page.dart';
import 'package:omm/features/files/file_browser_preferences.dart';
import 'package:omm/features/files/file_entry_icons.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = SourceId('filter-source');
const _labels = ['视频', '音乐', '图片', '字幕', '其他'];

FileEntry _entry(
  String name, {
  bool directory = false,
  String? mime,
  int? size,
}) => FileEntry(
  path: FilePath(sourceId: _source, value: name),
  name: name,
  type: directory ? FileEntryType.directory : FileEntryType.file,
  mimeType: mime,
  size: size,
);

List<FileEntry> _entries() => [
  _entry('子目录', directory: true),
  _entry('.隐藏目录', directory: true),
  _entry('A.mp4', size: 30),
  _entry('B.mkv', size: 10),
  _entry('音乐.flac'),
  _entry('图片.png'),
  _entry('字幕.srt'),
  _entry('说明.txt'),
  _entry('.隐藏.mp4'),
];

Future<ProviderContainer> _pumpBrowser(
  WidgetTester tester, {
  List<FileEntry>? entries,
  FileBrowserPreferences preferences = const FileBrowserPreferences(),
  bool directoryPicker = false,
  Size size = const Size(800, 1000),
  double textScale = 1,
  VoidCallback? onList,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await FileBrowserPreferencesRepository(prefs).save('server', preferences);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        fileSourceProvider(_source.value).overrideWith((ref) async => null),
        for (final path in ['', '子目录'])
          fileDirectoryProvider(
            FileDirectoryRequest(
              serverId: 'server',
              sourceId: _source,
              path: path,
            ),
          ).overrideWith((ref) async {
            onList?.call();
            return DirectoryListing(
              currentPath: FilePath(sourceId: _source, value: path),
              entries: path.isEmpty
                  ? entries ?? _entries()
                  : [_entry('子文件.mp4'), _entry('子音乐.mp3')],
            );
          }),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: FileBrowserPage(
          serverId: 'server',
          sourceId: _source,
          directoryPicker: directoryPicker,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(FileBrowserPage)),
  );
}

Future<void> _openFilter(WidgetTester tester) async {
  await tester.tap(find.byTooltip('更多'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('类型筛选'));
  await tester.tap(find.text('类型筛选'));
  await tester.pumpAndSettle();
}

Future<void> _toggle(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _closeMenu(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 4));
  await tester.pumpAndSettle();
}

bool _checked(WidgetTester tester, String label) => tester
    .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, label))
    .value!;

void main() {
  test('五类按既有后缀和 MIME 识别，字幕优先于普通文本', () {
    for (final sample in <(String, String?, FileFilterType)>[
      ('电影.MKV', null, FileFilterType.video),
      ('直播.M3U8', 'audio/x-mpegurl', FileFilterType.video),
      ('歌曲.FLAC', null, FileFilterType.music),
      ('照片.HEIC', null, FileFilterType.image),
      ('无后缀视频', ' VIDEO/MP4 ', FileFilterType.video),
      ('无后缀音频', 'audio/mpeg', FileFilterType.music),
      ('无后缀图片', 'image/png', FileFilterType.image),
      ('无后缀字幕', 'application/x-subrip', FileFilterType.subtitle),
      ('无后缀字幕', 'text/vtt', FileFilterType.subtitle),
      ('字幕.ASS', 'text/plain', FileFilterType.subtitle),
      ('字幕.SUP', 'application/octet-stream', FileFilterType.subtitle),
      ('说明.txt', 'text/plain', FileFilterType.other),
      ('歌词.lrc', null, FileFilterType.other),
      ('影片.nfo', null, FileFilterType.other),
      ('文档.pdf', null, FileFilterType.other),
      ('压缩.zip', null, FileFilterType.other),
      ('代码.dart', null, FileFilterType.other),
      ('无扩展名', null, FileFilterType.other),
    ]) {
      expect(
        fileFilterTypeFor(_entry(sample.$1, mime: sample.$2)),
        sample.$3,
        reason: sample.$1,
      );
    }
  });

  testWidgets('更多菜单内折叠六项，连续勾选即时生效且不重新请求目录', (tester) async {
    var requests = 0;
    await _pumpBrowser(tester, onList: () => requests++);
    expect(find.text('A.mp4'), findsOneWidget);
    expect(find.text('.隐藏.mp4'), findsNothing);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('类型筛选'), findsOneWidget);
    expect(find.text('显示隐藏文件'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('全选'), findsNothing);
    await _toggle(tester, '类型筛选');
    expect(find.byType(CheckboxListTile), findsNWidgets(6));
    for (final label in _labels) {
      expect(_checked(tester, label), isTrue);
    }
    expect(_checked(tester, '显示隐藏文件'), isFalse);

    await _toggle(tester, '视频');
    await _toggle(tester, '字幕');
    expect(find.text('A.mp4'), findsNothing);
    expect(find.text('B.mkv'), findsNothing);
    expect(find.text('字幕.srt'), findsNothing);
    expect(find.text('音乐.flac'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(6));
    await _toggle(tester, '显示隐藏文件');
    expect(find.text('.隐藏目录'), findsOneWidget);
    expect(find.text('.隐藏.mp4'), findsNothing);
    expect(requests, 1);

    await _toggle(tester, '类型筛选');
    expect(find.byType(CheckboxListTile), findsNothing);
    await _toggle(tester, '类型筛选');
    expect(_checked(tester, '视频'), isFalse);
    await _closeMenu(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    await _toggle(tester, '类型筛选');
    expect(_checked(tester, '字幕'), isFalse);
    expect(_checked(tester, '显示隐藏文件'), isTrue);
  });

  testWidgets('全部取消只保留目录，进入子目录与返回共享筛选', (tester) async {
    await _pumpBrowser(tester);
    await _openFilter(tester);
    for (final label in _labels) {
      await _toggle(tester, label);
    }
    await _closeMenu(tester);
    expect(find.byTooltip('文件操作'), findsOneWidget);
    expect(find.text('子目录'), findsOneWidget);
    expect(find.text('.隐藏目录'), findsNothing);
    await tester.tap(find.text('子目录'));
    await tester.pumpAndSettle();
    expect(find.text('没有符合筛选条件的文件'), findsOneWidget);
    await _openFilter(tester);
    for (final label in _labels) {
      expect(_checked(tester, label), isFalse);
    }
    await _toggle(tester, '音乐');
    await _closeMenu(tester);
    expect(find.text('子音乐.mp3'), findsOneWidget);
    expect(find.text('子文件.mp4'), findsNothing);
    await tester.tap(find.byTooltip('返回上一级'));
    await tester.pumpAndSettle();
    expect(find.text('音乐.flac'), findsOneWidget);
    expect(find.text('A.mp4'), findsNothing);
  });

  testWidgets('筛选与排序及批量全选使用同一可见列表', (tester) async {
    await _pumpBrowser(
      tester,
      preferences: const FileBrowserPreferences(
        selectedTypes: {FileFilterType.video},
      ),
    );
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('大小排序'),
        matching: find.byWidgetPredicate(
          (widget) => widget is CheckedPopupMenuItem,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('B.mkv')).dy,
      lessThan(tester.getTopLeft(find.text('A.mp4')).dy),
    );
    expect(find.text('音乐.flac'), findsNothing);
    await tester.longPress(find.text('A.mp4'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('批量操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    expect(find.text('已选 3 项'), findsOneWidget);
  });

  testWidgets('空目录保持原提示，目录选择器忽略类型筛选', (tester) async {
    await _pumpBrowser(
      tester,
      entries: [],
      preferences: const FileBrowserPreferences(selectedTypes: {}),
    );
    expect(find.text('此目录为空'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpBrowser(
      tester,
      directoryPicker: true,
      preferences: const FileBrowserPreferences(selectedTypes: {}),
    );
    expect(find.text('子目录'), findsOneWidget);
    expect(find.text('A.mp4'), findsOneWidget);
    expect(find.byTooltip('更多'), findsNothing);
  });

  testWidgets('窄屏大字体展开后可滚动到全部子项与原排序项', (tester) async {
    await _pumpBrowser(tester, size: const Size(320, 568), textScale: 2);
    await _openFilter(tester);
    for (final label in [..._labels, '显示隐藏文件']) {
      await _toggle(tester, label);
      expect(tester.takeException(), isNull);
    }
    expect(_checked(tester, '显示隐藏文件'), isTrue);
    await tester.ensureVisible(find.text('类别排序'));
    await tester.tap(
      find.ancestor(
        of: find.text('类别排序'),
        matching: find.byWidgetPredicate(
          (widget) => widget is CheckedPopupMenuItem,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
