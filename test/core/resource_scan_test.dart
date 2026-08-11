import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/resource_scan.dart';

void main() {
  test('资源扫描任务解析进度和终态', () {
    final task = ResourceScanTask.fromJson(const {
      'task_id': 'task-1',
      'status': 'running',
      'movie_ids': [1, 2],
      'total_count': 4,
      'current_index': 2,
      'current_movie': 'ABC-123',
      'success_count': 2,
      'failed_count': 0,
      'new_movie_count': 1,
      'errors': [],
    });

    expect(task.taskId, 'task-1');
    expect(task.progressRatio, 0.5);
    expect(task.isActive, isTrue);
    expect(task.newMovieCount, 1);
  });

  test('资源扫描启动结果解析跳过影片', () {
    final result = ResourceScanStartResult.fromJson(const {
      'task_id': 'task-2',
      'accepted_count': 3,
      'skipped_count': 1,
      'skipped_ids': [9],
    });

    expect(result.taskId, 'task-2');
    expect(result.acceptedCount, 3);
    expect(result.skippedIds, const [9]);
  });
}
