import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:omm/core/api/server_connection.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_source.dart';
import 'package:omm/core/sources/files/file_source_providers.dart';
import 'package:omm/core/sources/files/file_source_repository.dart';
import 'package:omm/features/files/file_image_preview_settings.dart';
import 'package:omm/features/files/file_image_thumbnail.dart';
import 'package:omm/features/files/file_favorites.dart';
import 'package:omm/features/files/file_browser_page.dart';
import 'package:omm/features/files/file_browser_preferences.dart';
import 'package:omm/features/files/file_entry_icons.dart';
import 'package:omm/features/files/file_video_preview_settings.dart';
import 'package:omm/features/files/file_video_thumbnail.dart';
import 'package:omm/features/files/file_video_thumbnail_providers.dart';
import 'package:omm/features/files/file_video_thumbnail_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  for (final action in ['选择模式', '类型过滤', '排序', '收藏']) {
    testWidgets('$action 保留已显示图片和视频，不重读预览', (tester) async {
      SharedPreferences.setMockInitialValues({
        'file.image_preview_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final fixture = _Fixture(cached: true);
      addTearDown(fixture.dispose);
      final source = _ImageSource();
      final entries = [
        for (final name in ['a.txt', 'b.jpg', 'c.mp4'])
          FileEntry(
            path: FilePath(sourceId: const SourceId('nas'), value: name),
            name: name,
            type: FileEntryType.file,
          ),
      ];
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          fileSourceProvider('nas').overrideWith((ref) async => source),
          fileDirectoryProvider(
            const FileDirectoryRequest(
              serverId: 'server',
              sourceId: SourceId('nas'),
            ),
          ).overrideWith(
            (ref) async => DirectoryListing(
              currentPath: const FilePath(sourceId: SourceId('nas'), value: ''),
              entries: entries,
            ),
          ),
          fileVideoThumbnailServiceProvider.overrideWithValue(fixture.service),
          fileVideoThumbnailSourceProvider('nas').overrideWith(
            (ref) async => FileVideoThumbnailSource(
              FileSourceRepository(source),
              fixture.lease,
              'source',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: FileBrowserPage(
              serverId: 'server',
              sourceId: SourceId('nas'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      for (final element
          in find
              .byWidgetPredicate(
                (widget) => widget is Image && widget.image is ResizeImage,
              )
              .evaluate()
              .toList()) {
        await tester.runAsync(
          () => precacheImage((element.widget as Image).image, element),
        );
      }
      await tester.pumpAndSettle();
      final imageFinder = find.byType(FileImageThumbnail);
      final videoFinder = find.byType(FileVideoThumbnail);
      final imageState = tester.state(imageFinder);
      final videoState = tester.state(videoFinder);
      ImageProvider preview(Finder finder) => tester
          .widget<Image>(
            find.descendant(
              of: finder,
              matching: find.byWidgetPredicate(
                (widget) => widget is Image && widget.image is ResizeImage,
              ),
            ),
          )
          .image;
      final image = preview(imageFinder);
      final video = preview(videoFinder);
      final cache = fixture.service.cache as _Cache;
      final reads = cache.reads.length;
      void expectRetained() {
        expect(tester.state(imageFinder), same(imageState));
        expect(tester.state(videoFinder), same(videoState));
        expect(preview(imageFinder), same(image));
        expect(preview(videoFinder), same(video));
        expect(source.downloads, 1);
        expect(cache.reads.length, reads);
      }

      final preferences = container.read(
        fileBrowserPreferencesProvider('server').notifier,
      );
      switch (action) {
        case '选择模式':
          await tester.longPress(find.text('b.jpg'));
          await tester.pump();
          expectRetained();
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('批量操作'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('全选').last);
          await tester.pump();
          expectRetained();
          await tester.tap(find.byIcon(Icons.close).first);
        case '类型过滤':
          preferences.toggleType(FileFilterType.other);
        case '排序':
          preferences.setSort(FileBrowserSortField.name);
        case '收藏':
          for (final entry in entries.skip(1)) {
            container
                .read(fileFavoritesProvider('server').notifier)
                .toggle(entry);
          }
      }
      await tester.pump();
      expectRetained();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expectRetained();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('文件页刷新保留缓存图、只重试未获取视频，筛选和图片开关独立', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    const cachedEntry = FileEntry(
      path: FilePath(sourceId: SourceId('nas'), value: 'cached.mp4'),
      name: 'cached.mp4',
      type: FileEntryType.file,
    );
    final cache = fixture.service.cache as _Cache;
    final cachedKey = fileVideoThumbnailKey('source', cachedEntry);
    cache.values[cachedKey] = img.encodeJpg(img.Image(width: 100, height: 200));
    final source = _Source();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        fileSourceProvider('nas').overrideWith((ref) async => source),
        fileDirectoryProvider(
          const FileDirectoryRequest(
            serverId: 'server',
            sourceId: SourceId('nas'),
          ),
        ).overrideWith(
          (ref) async => const DirectoryListing(
            currentPath: FilePath(sourceId: SourceId('nas'), value: ''),
            entries: [
              cachedEntry,
              FileEntry(
                path: FilePath(sourceId: SourceId('nas'), value: 'movie.mp4'),
                name: 'movie.mp4',
                type: FileEntryType.file,
              ),
              FileEntry(
                path: FilePath(sourceId: SourceId('nas'), value: 'photo.jpg'),
                name: 'photo.jpg',
                type: FileEntryType.file,
              ),
            ],
          ),
        ),
        fileVideoThumbnailServiceProvider.overrideWithValue(fixture.service),
        fileVideoThumbnailSourceProvider('nas').overrideWith(
          (ref) async => FileVideoThumbnailSource(
            FileSourceRepository(source),
            fixture.lease,
            'source',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: FileBrowserPage(serverId: 'server', sourceId: SourceId('nas')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(fixture.starts, ['movie.mp4']);
    expect(find.byType(FileVideoThumbnail), findsNWidgets(2));
    expect(container.read(fileImagePreviewProvider), isFalse);
    container
        .read(fileBrowserPreferencesProvider('server').notifier)
        .toggleType(FileFilterType.video);
    await tester.pumpAndSettle();
    expect(fixture.tokens.single.isCancelled, isTrue);
    expect(find.byType(FileVideoThumbnail), findsNothing);
    expect(find.text('photo.jpg'), findsOneWidget);
    container
        .read(fileBrowserPreferencesProvider('server').notifier)
        .toggleType(FileFilterType.video);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(fixture.starts.length, 2);
    final cachedThumbnail = find.byWidgetPredicate(
      (widget) => widget is FileVideoThumbnail && widget.entry == cachedEntry,
    );
    final cachedImageFinder = find.descendant(
      of: cachedThumbnail,
      matching: find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is ResizeImage,
      ),
    );
    final cachedImage = tester.widget<Image>(cachedImageFinder).image;
    expect(cachedImage, isA<ResizeImage>());
    final cacheReads = cache.reads.where((key) => key == cachedKey).length;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    await refresh;
    await tester.pump(const Duration(milliseconds: 250));
    expect(fixture.tokens[1].isCancelled, isTrue);
    expect(fixture.starts.length, 3);
    expect(tester.widget<Image>(cachedImageFinder).image, same(cachedImage));
    expect(cache.reads.where((key) => key == cachedKey).length, cacheReads);
    await container.read(fileVideoPreviewProvider.notifier).setEnabled(false);
    await tester.pumpAndSettle();
    expect(find.byType(FileVideoThumbnail), findsNothing);
    expect(fixture.tokens.last.isCancelled, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  test('视频预览默认开启，独立于图片且重建后保持设置', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    expect(container.read(fileVideoPreviewProvider), isTrue);
    expect(container.read(fileImagePreviewProvider), isFalse);
    await container.read(fileVideoPreviewProvider.notifier).setEnabled(false);
    await container.read(fileImagePreviewProvider.notifier).setEnabled(true);
    container.dispose();
    container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    expect(container.read(fileVideoPreviewProvider), isFalse);
    expect(container.read(fileImagePreviewProvider), isTrue);
    container.dispose();
  });

  testWidgets('只为视口内稳定250ms的条目抽帧，离屏取消且不会启动预构建条目', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.widget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 249));
    expect(fixture.starts, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(fixture.starts, ['0.mp4']);
    fixture.scroll.jumpTo(1000);
    await tester.pump();
    await tester.pump();
    expect(fixture.tokens.first.isCancelled, isTrue);
    await tester.pump(const Duration(milliseconds: 249));
    expect(fixture.starts.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(fixture.starts, ['0.mp4', '10.mp4']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(fixture.tokens.last.isCancelled, isTrue);
  });

  testWidgets('快速滚动停稳后才开始，切换标签和后台取消并可恢复', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.widget());
    await tester.pump();
    for (var i = 1; i <= 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      fixture.scroll.jumpTo(i * 100);
      await tester.pump();
      expect(fixture.starts, isEmpty);
    }
    await tester.pump(const Duration(milliseconds: 250));
    expect(fixture.starts, ['5.mp4']);
    fixture.active.value = false;
    await tester.pump();
    await tester.pump();
    expect(fixture.tokens.single.isCancelled, isTrue);
    fixture.active.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(fixture.starts.length, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(fixture.tokens.last.isCancelled, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(fixture.starts.length, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('页面被覆盖时取消；返回后重试，关闭开关即取消', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.widget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    fixture.navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('详情'))),
    );
    await tester.pumpAndSettle();
    expect(fixture.tokens.single.isCancelled, isTrue);
    fixture.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(fixture.starts.length, 2);
    fixture.enabled.value = false;
    await tester.pump();
    await tester.pump();
    expect(fixture.tokens.last.isCancelled, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('失败条目本次浏览不反复解码，清除失败集合后可重试', (tester) async {
    final fixture = _Fixture(fail: true);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.widget(count: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(fixture.starts.length, 1);
    expect(fixture.failures.length, 1);
    fixture.active.value = false;
    await tester.pump();
    fixture.active.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fixture.starts.length, 1);
    fixture.failures.clear();
    fixture.enabled.value = false;
    await tester.pump();
    fixture.enabled.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(fixture.starts.length, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('缓存图直接显示为等比预览，切服移除旧图', (tester) async {
    final fixture = _Fixture(cached: true);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.widget(count: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(fixture.starts, isEmpty);
    final image = tester.widget<Image>(
      find
          .descendant(
            of: find.byType(FileVideoThumbnail),
            matching: find.byType(Image),
          )
          .first,
    );
    expect(image.image, isA<ResizeImage>());
    expect(image.fit, BoxFit.cover);
    expect((image.image as ResizeImage).policy, ResizeImagePolicy.fit);
    fixture.lease.cancel();
    fixture.active.value = false;
    await tester.pump();
    expect(
      tester
          .widget<Image>(
            find
                .descendant(
                  of: find.byType(FileVideoThumbnail),
                  matching: find.byType(Image),
                )
                .first,
          )
          .image,
      isNot(isA<ResizeImage>()),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('手动清理使已显示的视频预览失效，恢复可见后重新取图', (tester) async {
    final fixture = _Fixture(cached: true);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.widget(count: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    final finder = find
        .descendant(
          of: find.byType(FileVideoThumbnail),
          matching: find.byType(Image),
        )
        .first;
    final before = tester.widget<Image>(finder).image;
    expect(before, isA<ResizeImage>());
    fixture.active.value = false;
    await tester.pump();
    final cache = fixture.service.cache as _Cache;
    final reads = cache.reads.length;
    cache.epoch.value++;
    await tester.pump();
    expect(tester.widget<Image>(finder).image, isNot(isA<ResizeImage>()));
    expect(cache.reads.length, reads);
    fixture.active.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(cache.reads.length, greaterThan(reads));
    expect(tester.widget<Image>(finder).image, isA<ResizeImage>());
    expect(tester.widget<Image>(finder).image, isNot(same(before)));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

class _Fixture {
  _Fixture({bool fail = false, bool cached = false}) {
    service = FileVideoThumbnailService(
      cache: _Cache(cached),
      generate: (_, entry, token) {
        starts.add(entry.name);
        tokens.add(token);
        return fail
            ? Future.value(null)
            : token.whenCancelled.then((_) => null);
      },
    );
  }
  final scroll = ScrollController();
  final active = ValueNotifier(true);
  final enabled = ValueNotifier(true);
  final navigator = GlobalKey<NavigatorState>();
  final lease = ServerConnectionLease(serverId: 'server', generation: 1);
  final failures = <String>{};
  final starts = <String>[];
  final tokens = <FileCancellationToken>[];
  late final FileVideoThumbnailService service;
  Widget widget({int count = 30}) => ProviderScope(
    overrides: [
      fileVideoThumbnailServiceProvider.overrideWithValue(service),
      fileVideoThumbnailSourceProvider('nas').overrideWith(
        (ref) async => FileVideoThumbnailSource(
          FileSourceRepository(_Source()),
          lease,
          'source',
        ),
      ),
    ],
    child: MaterialApp(
      navigatorKey: navigator,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 200,
            child: ValueListenableBuilder(
              valueListenable: active,
              builder: (_, value, __) => TickerMode(
                enabled: value,
                child: ValueListenableBuilder(
                  valueListenable: enabled,
                  builder: (_, value, __) => ListView.builder(
                    controller: scroll,
                    itemCount: count,
                    itemExtent: 100,
                    itemBuilder: (_, index) => Center(
                      child: FileVideoThumbnail(
                        key: ValueKey(index),
                        failures: failures,
                        scrollController: scroll,
                        enabled: value,
                        entry: FileEntry(
                          path: FilePath(
                            sourceId: const SourceId('nas'),
                            value: '$index.mp4',
                          ),
                          name: '$index.mp4',
                          type: FileEntryType.file,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  void dispose() {
    service.dispose();
    scroll.dispose();
    active.dispose();
    enabled.dispose();
  }
}

class _Source implements FileSource {
  @override
  SourceDescriptor get descriptor => const SourceDescriptor(
    id: SourceId('nas'),
    kind: SourceKind.webDav,
    name: 'NAS',
    serverId: 'server',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageSource extends _Source implements FileTransferCapability {
  int downloads = 0;
  @override
  Stream<List<int>> download(
    FilePath path, {
    FileTransferOptions options = const FileTransferOptions(),
  }) {
    downloads++;
    return Stream.value(img.encodeJpg(img.Image(width: 160, height: 100)));
  }
}

class _Cache implements FileVideoThumbnailCache {
  _Cache(this.cached);
  final bool cached;
  final values = <String, Uint8List>{};
  final reads = <String>[];
  @override
  final ValueNotifier<int> epoch = ValueNotifier(0);
  @override
  bool get isClearing => false;
  @override
  Future<Uint8List?> read(String key) async {
    reads.add(key);
    return values[key] ??
        (cached ? img.encodeJpg(img.Image(width: 100, height: 200)) : null);
  }

  @override
  Future<void> write(
    String key,
    Uint8List bytes,
    int epoch,
    bool Function() valid,
  ) async {}
}
