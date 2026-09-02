import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';

class _FakeMediaBrowserSource implements MediaBrowserMediaSource {
  final calls = <String>[];
  Map<String, dynamic>? updatedOptions;

  @override
  Future<List<MediaBrowserLibrary>> virtualFolders() async {
    calls.add('virtualFolders');
    return const <MediaBrowserLibrary>[];
  }

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
    updatedOptions = {...options, 'Enabled': enabled};
  }

  @override
  Future<void> refreshLibrary() async {
    calls.add('refresh');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('MediaBrowserMediaRepository 透传媒体库管理操作', () async {
    final source = _FakeMediaBrowserSource();
    final repository = MediaBrowserMediaRepository(source);

    expect(await repository.virtualFolders(), isEmpty);
    await repository.addVirtualFolder(
      name: '电影库',
      collectionType: 'movies',
      paths: const ['/media/movies'],
    );
    await repository.renameVirtualFolder(name: '电影库', newName: '影片库');
    await repository.addMediaPath(libraryName: '影片库', path: '/media/films');
    await repository.removeMediaPath(libraryName: '影片库', path: '/media/movies');
    await repository.updateVirtualFolderOptions(
      id: 'library-1',
      enabled: false,
      options: const {'EnableRealtimeMonitor': true},
    );
    await repository.removeVirtualFolder('影片库');
    await repository.refreshLibrary();

    expect(source.calls, [
      'virtualFolders',
      'add:电影库:movies:/media/movies',
      'rename:电影库->影片库',
      'addPath:影片库:/media/films',
      'removePath:影片库:/media/movies',
      'options:library-1:false',
      'remove:影片库',
      'refresh',
    ]);
    expect(source.updatedOptions, {
      'EnableRealtimeMonitor': true,
      'Enabled': false,
    });
  });
}
