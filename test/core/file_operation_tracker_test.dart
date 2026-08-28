import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_operation.dart';
import 'package:omm/core/sources/files/file_source_repository.dart';

void main() {
  test('Tracker 保留操作类型、路径和最新传输进度', () async {
    final tracker = FileOperationTracker(sourceId: const SourceId('smb-main'));
    final events = <FileOperation>[];
    final subscription = tracker.events.listen(events.add);
    final source = const FilePath(
      sourceId: SourceId('smb-main'),
      value: 'videos/movie.mkv',
    );
    final destination = const FilePath(
      sourceId: SourceId('smb-main'),
      value: 'backup/movie.mkv',
    );

    final id = tracker.start(
      FileOperationKind.download,
      source: source,
      destination: destination,
    );
    tracker.progress(id, const FileTransferProgress(transferred: 5, total: 10));
    tracker.complete(id, FileOperationKind.download);
    await Future<void>.delayed(Duration.zero);

    expect(events.map((event) => event.status), [
      FileOperationStatus.running,
      FileOperationStatus.running,
      FileOperationStatus.completed,
    ]);
    expect(events[1].kind, FileOperationKind.download);
    expect(events[1].source, source);
    expect(events[1].destination, destination);
    expect(events[1].progress?.transferred, 5);
    expect(tracker.operation(id)?.status, FileOperationStatus.completed);

    await subscription.cancel();
    await tracker.dispose();
  });

  test('取消后的传输统一发出 canceled 状态', () async {
    final tracker = FileOperationTracker(sourceId: const SourceId('webdav'));
    final events = <FileOperation>[];
    final subscription = tracker.events.listen(events.add);
    final id = tracker.start(FileOperationKind.upload);

    tracker.cancel(id);
    tracker.fail(
      id,
      FileOperationKind.upload,
      const FileSourceException('上传已取消', code: 'canceled'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(events.last.status, FileOperationStatus.canceled);
    expect(events.last.kind, FileOperationKind.upload);
    expect(tracker.operation(id)?.status, FileOperationStatus.canceled);

    await subscription.cancel();
    await tracker.dispose();
  });
}
