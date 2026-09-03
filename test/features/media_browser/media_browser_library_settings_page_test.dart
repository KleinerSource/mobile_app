import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/pages/media_browser_library_settings_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

class _FakeMediaBrowserSource implements MediaBrowserMediaSource {
  _FakeMediaBrowserSource({required this.user, required this.libraries});

  final MediaBrowserUser user;
  final List<MediaBrowserLibrary> libraries;
  final calls = <String>[];
  Map<String, dynamic>? options;

  @override
  Future<MediaBrowserUser> currentUser() async => user;

  @override
  Future<List<MediaBrowserLibrary>> virtualFolders() async => libraries;

  @override
  Future<void> addVirtualFolder({
    required String name,
    required String collectionType,
    required List<String> paths,
  }) async {
    calls.add('add:$name:$collectionType:${paths.join('|')}');
  }

  @override
  Future<void> removeVirtualFolder(String name) async {
    calls.add('remove:$name');
  }

  @override
  Future<void> renameVirtualFolder({
    required String name,
    required String newName,
  }) async {
    calls.add('rename:$name->$newName');
  }

  @override
  Future<void> addMediaPath({
    required String libraryName,
    required String path,
  }) async {
    calls.add('addPath:$libraryName:$path');
  }

  @override
  Future<void> removeMediaPath({
    required String libraryName,
    required String path,
  }) async {
    calls.add('removePath:$libraryName:$path');
  }

  @override
  Future<void> updateVirtualFolderOptions({
    required String id,
    required bool enabled,
    Map<String, dynamic> options = const <String, dynamic>{},
  }) async {
    calls.add('options:$id:$enabled');
    this.options = {...options, 'Enabled': enabled};
  }

  @override
  Future<void> refreshLibrary({String? libraryId}) async {
    calls.add('refresh:${libraryId ?? 'all'}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _library = MediaBrowserLibrary(
  id: 'library-1',
  name: '旧库',
  collectionType: 'movies',
  paths: ['/media/a', '/media/b'],
  enabled: true,
  libraryOptions: {
    'EnableRealtimeMonitor': true,
    'MetadataSavers': ['Nfo'],
  },
);

void main() {
  testWidgets('非管理员隐藏媒体库写操作并提示使用管理员账号', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaBrowserConfigProvider.overrideWithValue(MediaBrowserConfig.emby),
          mediaBrowserCurrentUserProvider.overrideWith(
            (_) async => const MediaBrowserUser(id: 'user-1', name: '普通用户'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: MediaBrowserLibrarySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('需要管理员账号'), findsOneWidget);
    expect(find.text('添加'), findsNothing);
    expect(find.byTooltip('刷新'), findsNothing);
  });

  testWidgets('管理员编辑媒体库按差异提交并只触发一次刷新', (tester) async {
    final source = _FakeMediaBrowserSource(
      user: const MediaBrowserUser(id: 'admin-1', name: '管理员', isAdmin: true),
      libraries: const [_library],
    );
    final repository = MediaBrowserMediaRepository(source);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaBrowserConfigProvider.overrideWithValue(MediaBrowserConfig.emby),
          mediaBrowserMediaRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: MediaBrowserLibraryEditorPage(library: _library),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), '新库');
    await tester.enterText(fields.at(2), '/media/c');
    await tester.tap(find.byType(Switch));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();

    expect(source.calls, [
      'rename:旧库->新库',
      'removePath:新库:/media/b',
      'addPath:新库:/media/c',
      'options:library-1:false',
      'refresh:all',
    ]);
    expect(source.options, {
      'EnableRealtimeMonitor': true,
      'MetadataSavers': ['Nfo'],
      'Enabled': false,
    });
    expect(find.byType(MediaBrowserLibraryEditorPage), findsNothing);
  });

  testWidgets('管理员删除媒体库需要二次确认并刷新服务器', (tester) async {
    final source = _FakeMediaBrowserSource(
      user: const MediaBrowserUser(id: 'admin-1', name: '管理员', isAdmin: true),
      libraries: const [_library],
    );
    final repository = MediaBrowserMediaRepository(source);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaBrowserConfigProvider.overrideWithValue(
            MediaBrowserConfig.jellyfin,
          ),
          mediaBrowserMediaRepositoryProvider.overrideWithValue(repository),
          mediaBrowserCurrentUserProvider.overrideWith(
            (_) async => const MediaBrowserUser(
              id: 'admin-1',
              name: '管理员',
              isAdmin: true,
            ),
          ),
          mediaBrowserVirtualFoldersProvider.overrideWith(
            (_) async => const [_library],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: MediaBrowserLibrarySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.timedDrag(
      find.byType(SwipeActionCell),
      const Offset(-120, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除').hitTestable(), findsOneWidget);
    await tester.tap(find.text('删除').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('删除媒体库'), findsOneWidget);
    expect(find.textContaining('服务器上的媒体文件不会被删除'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(source.calls, ['remove:旧库', 'refresh:all']);
  });

  testWidgets('媒体库卡片隐藏路径并通过左滑刷新服务器', (tester) async {
    final source = _FakeMediaBrowserSource(
      user: const MediaBrowserUser(id: 'admin-1', name: '管理员', isAdmin: true),
      libraries: const [_library],
    );
    final repository = MediaBrowserMediaRepository(source);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaBrowserConfigProvider.overrideWithValue(
            MediaBrowserConfig.jellyfin,
          ),
          mediaBrowserMediaRepositoryProvider.overrideWithValue(repository),
          mediaBrowserCurrentUserProvider.overrideWith(
            (_) async => const MediaBrowserUser(
              id: 'admin-1',
              name: '管理员',
              isAdmin: true,
            ),
          ),
          mediaBrowserVirtualFoldersProvider.overrideWith(
            (_) async => const [_library],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: MediaBrowserLibrarySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('旧库'));
    await tester.pumpAndSettle();
    expect(find.text('编辑媒体库'), findsOneWidget);
    Navigator.of(
      tester.element(find.byType(MediaBrowserLibraryEditorPage)),
    ).pop();
    await tester.pumpAndSettle();

    expect(find.text('/media/a'), findsNothing);
    expect(find.text('/media/b'), findsNothing);
    expect(find.byType(SwipeActionCell), findsOneWidget);

    await tester.timedDrag(
      find.byType(SwipeActionCell),
      const Offset(-120, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(find.text('刷新').hitTestable(), findsOneWidget);
    expect(find.text('停用').hitTestable(), findsOneWidget);
    expect(find.text('删除').hitTestable(), findsOneWidget);

    await tester.tap(find.text('刷新').hitTestable());
    await tester.pumpAndSettle();

    expect(source.calls, ['refresh:all']);
    expect(find.text('已开始刷新「旧库」'), findsOneWidget);
  });

  testWidgets('服务器返回 401/403 时显示明确的权限错误', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaBrowserConfigProvider.overrideWithValue(MediaBrowserConfig.emby),
          mediaBrowserCurrentUserProvider.overrideWith(
            (_) async => const MediaBrowserUser(
              id: 'admin-1',
              name: '管理员',
              isAdmin: true,
            ),
          ),
          mediaBrowserVirtualFoldersProvider.overrideWith((_) async {
            throw const SourceException('服务器拒绝访问（403）', statusCode: 403);
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: MediaBrowserLibrarySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('服务器拒绝访问（403）'), findsOneWidget);
  });
}
