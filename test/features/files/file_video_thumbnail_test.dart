import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:omm/core/api/server_connection.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_source.dart';
import 'package:omm/core/sources/files/file_source_repository.dart';
import 'package:omm/features/files/file_video_thumbnail_decoder.dart';
import 'package:omm/features/files/file_video_thumbnail_service.dart';

final _entry = FileEntry(
  path: const FilePath(sourceId: SourceId('nas'), value: '目录/电影.mkv'),
  name: '电影.mkv',
  type: FileEntryType.file,
  size: 200,
  modifiedAt: DateTime.utc(2026, 10, 8),
  attributes: const {'etag': 'one'},
);
final _repository = FileSourceRepository(_Source());
ServerConnectionLease _lease() =>
    ServerConnectionLease(serverId: 'server', generation: 1);
final _jpeg = img.encodeJpg(img.Image(width: 640, height: 360));

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('时间取总时长10%，未知和零时长不取开头帧', () {
    expect(
      fileVideoThumbnailPosition(const Duration(minutes: 100)),
      const Duration(minutes: 10),
    );
    expect(
      fileVideoThumbnailPosition(const Duration(milliseconds: 500)),
      const Duration(milliseconds: 50),
    );
    expect(fileVideoThumbnailPosition(Duration.zero), isNull);
    expect(fileVideoThumbnailPosition(const Duration(seconds: -1)), isNull);
    expect(
      isVideoThumbnailFrameReady(
        target: const Duration(seconds: 10),
        frameSeconds: 0,
        seeking: false,
      ),
      isFalse,
    );
    expect(
      isVideoThumbnailFrameReady(
        target: const Duration(seconds: 10),
        frameSeconds: 10,
        seeking: true,
      ),
      isFalse,
    );
    expect(
      isVideoThumbnailFrameReady(
        target: const Duration(seconds: 10),
        frameSeconds: 10.04,
        seeking: false,
      ),
      isTrue,
    );
  });

  test('横竖图等比压缩到长边320并输出JPEG', () {
    for (final size in [(640, 360), (240, 720), (100, 50)]) {
      final result = encodeFileVideoThumbnail(
        img.encodePng(img.Image(width: size.$1, height: size.$2)),
      )!;
      expect(result.take(2), [255, 216]);
      final image = img.decodeJpg(result)!;
      expect(image.width, lessThanOrEqualTo(320));
      expect(image.height, lessThanOrEqualTo(320));
      expect(image.width / image.height, closeTo(size.$1 / size.$2, .01));
    }
    expect(encodeFileVideoThumbnail(Uint8List.fromList([1, 2])), isNull);
  });

  test('等待定位后的目标帧才截图，并释放解码器', () async {
    final session = _Session();
    final task = decodeFileVideoThumbnail(
      Uri.parse('http://localhost/video'),
      FileCancellationToken(),
      createSession: () => session,
    );
    await _tick();
    expect(session.seekTo, const Duration(seconds: 10));
    expect(session.captures, 0);
    session.ready.complete(true);
    final bytes = await task;
    expect(img.decodeJpg(bytes!)!.width, 320);
    expect(session.captures, 1);
    expect(session.disposed, isTrue);
  });

  test('定位等待中取消、未知时长取消及无视频轨都释放解码器', () async {
    for (final mode in ['seek', 'unknown', 'audio']) {
      final session = _Session()
        ..durationValue = mode == 'unknown'
            ? Duration.zero
            : const Duration(seconds: 100)
        ..video = mode != 'audio';
      final token = FileCancellationToken();
      final task = decodeFileVideoThumbnail(
        Uri.parse('http://localhost/video'),
        token,
        createSession: () => session,
      );
      await _tick();
      token.cancel();
      expect(await task, isNull);
      expect(session.disposed, isTrue);
      expect(session.captures, 0);
    }
  });

  test('缓存键隔离来源、路径、版本且不泄露路径及凭据', () {
    final key = fileVideoThumbnailKey('server/account', _entry);
    expect(key, isNot(contains('目录')));
    expect(key, isNot(contains('account')));
    expect(fileVideoThumbnailKey('other/account', _entry), isNot(key));
    for (final changed in [
      FileEntry(
        path: _entry.path,
        name: _entry.name,
        type: FileEntryType.file,
        size: 201,
      ),
      FileEntry(
        path: const FilePath(sourceId: SourceId('nas'), value: '其他/电影.mkv'),
        name: _entry.name,
        type: FileEntryType.file,
        size: 200,
      ),
      FileEntry(
        path: _entry.path,
        name: _entry.name,
        type: FileEntryType.file,
        size: 200,
        attributes: const {'etag': 'two'},
      ),
    ]) {
      expect(fileVideoThumbnailKey('server/account', changed), isNot(key));
    }
  });

  test('同文件请求合并，全局串行，最后订阅离开才取消', () async {
    final cache = _Cache();
    final starts = <FileCancellationToken>[];
    final results = <Completer<Uint8List?>>[];
    final service = FileVideoThumbnailService(
      cache: cache,
      generate: (_, __, token) {
        starts.add(token);
        final result = Completer<Uint8List?>();
        results.add(result);
        return result.future;
      },
    );
    addTearDown(service.dispose);
    final lease = _lease();
    FileVideoThumbnailRequest load(String key) => service.load(
      key: key,
      repository: _repository,
      entry: _entry,
      lease: lease,
    );
    final a = load('a');
    final a2 = load('a');
    final b = load('b');
    await _tick();
    expect(starts.length, 1);
    a.release();
    expect(starts.single.isCancelled, isFalse);
    a2.release();
    expect(starts.single.isCancelled, isTrue);
    expect(await a.bytes, isNull);
    expect(starts.length, 1);
    results[0].complete(_jpeg);
    await _tick();
    expect(starts.length, 2);
    expect(cache.data.containsKey('a'), isFalse);
    results[1].complete(_jpeg);
    expect(await b.bytes, _jpeg);
    expect(cache.data['b'], _jpeg);
    b.release();
  });

  test('取消排队任务、切服和超时不保存迟到结果', () async {
    for (final mode in ['lease', 'timeout', 'clear']) {
      final cache = _Cache();
      final result = Completer<Uint8List?>();
      var calls = 0;
      final service = FileVideoThumbnailService(
        cache: cache,
        timeout: const Duration(milliseconds: 20),
        generate: (_, __, ___) {
          calls++;
          return result.future;
        },
      );
      final lease = _lease();
      final a = service.load(
        key: 'a',
        repository: _repository,
        entry: _entry,
        lease: lease,
      );
      final b = service.load(
        key: 'b',
        repository: _repository,
        entry: _entry,
        lease: lease,
      );
      b.release();
      await _tick();
      if (mode == 'lease') lease.cancel();
      if (mode == 'clear') cache.epoch.value++;
      expect(await a.bytes, isNull);
      result.complete(_jpeg);
      await _tick();
      expect(cache.data, isEmpty);
      expect(calls, 1);
      service.dispose();
    }
  });

  test('重新创建服务仍命中持久缓存，失败后允许刷新重试', () async {
    final cache = _Cache();
    var calls = 0;
    for (var i = 0; i < 2; i++) {
      final service = FileVideoThumbnailService(
        cache: cache,
        generate: (_, __, ___) async {
          calls++;
          return _jpeg;
        },
      );
      final request = service.load(
        key: 'same',
        repository: _repository,
        entry: _entry,
        lease: _lease(),
      );
      expect(await request.bytes, _jpeg);
      request.release();
      service.dispose();
    }
    expect(calls, 1);
    final service = FileVideoThumbnailService(
      cache: cache,
      generate: (_, __, ___) async => ++calls == 2 ? null : _jpeg,
    );
    expect(
      await service
          .load(
            key: 'retry',
            repository: _repository,
            entry: _entry,
            lease: _lease(),
          )
          .bytes,
      isNull,
    );
    expect(
      await service
          .load(
            key: 'retry',
            repository: _repository,
            entry: _entry,
            lease: _lease(),
          )
          .bytes,
      _jpeg,
    );
    service.dispose();
  });
}

class _Source implements FileSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements FileVideoThumbnailCache {
  @override
  final ValueNotifier<int> epoch = ValueNotifier(0);
  @override
  bool isClearing = false;
  final data = <String, Uint8List>{};
  @override
  Future<Uint8List?> read(String key) async => data[key];
  @override
  Future<void> write(
    String key,
    Uint8List bytes,
    int epoch,
    bool Function() valid,
  ) async {
    if (valid() && epoch == this.epoch.value) data[key] = bytes;
  }
}

class _Session implements FileVideoFrameSession {
  Duration durationValue = const Duration(seconds: 100);
  bool video = true;
  Duration? seekTo;
  int captures = 0;
  bool disposed = false;
  final ready = Completer<bool>();
  @override
  Future<void> open(Uri uri) async {}
  @override
  Future<Duration> duration() async => durationValue;
  @override
  Future<bool> hasVideo() async => video;
  @override
  Future<void> seek(Duration position) async {
    seekTo = position;
  }

  @override
  Future<bool> frameReady(Duration position) => ready.future;
  @override
  Future<Uint8List?> screenshot() async {
    captures++;
    return _jpeg;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
