import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/files/file_thumbnail_loader.dart';

void main() {
  test('最多两个下载，释放条目取消流并启动排队条目', () async {
    final loader = FileThumbnailLoader();
    final streams = List.generate(3, (_) => StreamController<List<int>>());
    var started = 0;
    var canceled = 0;
    final requests = List.generate(3, (index) {
      streams[index].onCancel = () => canceled++;
      return loader.load((token) async {
        started++;
        return streams[index].stream;
      });
    });
    await Future<void>.delayed(Duration.zero);
    expect(started, 2);
    requests.first.release();
    expect(await requests.first.bytes, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(started, 3);
    expect(canceled, 1);
    streams[1].add([1, 2]);
    await streams[1].close();
    expect(await requests[1].bytes, [1, 2]);
    loader.dispose();
    expect(await requests[2].bytes, isNull);
    await streams[0].close();
    await streams[2].close();
  });

  test('销毁后排队任务不会开始，下载异常不会堵住队列', () async {
    final loader = FileThumbnailLoader();
    final failed = loader.load((_) async => throw StateError('offline'));
    await expectLater(failed.bytes, throwsStateError);
    loader.dispose();
    var started = false;
    final request = loader.load((_) async {
      started = true;
      return const Stream<List<int>>.empty();
    });
    expect(await request.bytes, isNull);
    expect(started, isFalse);
  });
}
