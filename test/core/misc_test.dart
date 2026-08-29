// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/core/app_version_test.dart
//   - test/core/app_haptics_test.dart
//   - test/core/map_with_concurrency_test.dart
//   - test/core/file_operation_tracker_test.dart
//   - test/core/resource_scan_test.dart
//   - test/core/url_resolver_test.dart

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/models/resource_scan.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/files/file_entry.dart';
import 'package:omm/core/sources/files/file_operation.dart';
import 'package:omm/core/sources/files/file_source_repository.dart';
import 'package:omm/core/util/map_with_concurrency.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== 原 test/core/app_version_test.dart ====================
void _main_0() {
  test('版本号包含 pubspec 注入的构建号', () {
    expect(formatAppVersion('0.1.4', '5'), '0.1.4+5');
  });

  test('版本号已包含构建号时不会重复拼接', () {
    expect(formatAppVersion('0.1.4+5', '5'), '0.1.4+5');
  });

  test('缺少构建号时只显示版本号', () {
    expect(formatAppVersion('0.1.4', ''), '0.1.4');
  });
}

// ==================== 原 test/core/app_haptics_test.dart ====================
void _main_1() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wrapToggle 保留禁用回调语义', () {
    expect(AppHaptics.wrapToggle(null), isNull);
  });

  test('wrapToggle 只调用一次实际开关回调', () {
    var value = false;
    final onChanged = AppHaptics.wrapToggle((next) => value = next);

    onChanged!(true);

    expect(value, isTrue);
  });

  test('震动强度支持关闭和三档并可从偏好读取', () async {
    SharedPreferences.setMockInitialValues({
      AppHaptics.preferenceKey: HapticIntensity.high.storageValue,
    });
    final prefs = await SharedPreferences.getInstance();

    AppHaptics.configureFromPreferences(prefs);

    expect(HapticIntensity.values, hasLength(4));
    expect(AppHaptics.intensity, HapticIntensity.high);
    expect(HapticIntensity.fromStorage('off'), HapticIntensity.off);
    expect(HapticIntensity.fromStorage('unknown'), HapticIntensity.standard);

    AppHaptics.setIntensity(HapticIntensity.standard);
  });

  test('关闭档位不会调用系统震动接口', () async {
    var hapticCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticCalls++;
      return null;
    });

    AppHaptics.setIntensity(HapticIntensity.off);
    AppHaptics.selection();
    AppHaptics.light();
    AppHaptics.medium();
    await Future<void>.delayed(Duration.zero);

    expect(hapticCalls, 0);
    AppHaptics.setIntensity(HapticIntensity.standard);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('各反馈类型随强度档位统一升降', () async {
    final effects = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        effects.add(call.arguments as String? ?? '');
      }
      return null;
    });

    // selection 与 light 共用轻反馈映射，此处用 light 代表并避开节流。
    AppHaptics.setIntensity(HapticIntensity.low);
    AppHaptics.light();
    AppHaptics.medium();
    AppHaptics.error();
    AppHaptics.setIntensity(HapticIntensity.standard);
    AppHaptics.light();
    AppHaptics.medium();
    AppHaptics.error();
    AppHaptics.setIntensity(HapticIntensity.high);
    AppHaptics.light();
    AppHaptics.medium();
    AppHaptics.error();
    await Future<void>.delayed(Duration.zero);

    expect(effects, [
      // low：轻=选择点，中=轻击，错误不降级=中击。
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      // standard：轻=轻击，中=中击，错误=重击。
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
      // high：轻=中击，中=重击，错误顶格=重击。
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.heavyImpact',
    ]);

    AppHaptics.setIntensity(HapticIntensity.standard);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

// ==================== 原 test/core/map_with_concurrency_test.dart ====================
void _main_2() {
  test('保持顺序且有并发上限', () async {
    var running = 0;
    var peak = 0;
    final result = await mapWithConcurrency(List<int>.generate(20, (i) => i), (
      i,
    ) async {
      running++;
      peak = peak > running ? peak : running;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      running--;
      return i * 2;
    }, concurrency: 4);
    expect(peak, lessThanOrEqualTo(4));
    expect(result, List<int>.generate(20, (i) => i * 2));
  });

  test('空输入返回空列表', () async {
    final result = await mapWithConcurrency<int, int>(
      const <int>[],
      (i) async => i,
    );
    expect(result, isEmpty);
  });
}

// ==================== 原 test/core/file_operation_tracker_test.dart ====================
void _main_3() {
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
      FileOperationKind.upload,
      source: source,
      destination: destination,
    );
    tracker.progress(id, const FileTransferProgress(transferred: 5, total: 10));
    tracker.complete(id, FileOperationKind.upload);
    await Future<void>.delayed(Duration.zero);

    expect(events.map((event) => event.status), [
      FileOperationStatus.running,
      FileOperationStatus.running,
      FileOperationStatus.completed,
    ]);
    expect(events[1].kind, FileOperationKind.upload);
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

// ==================== 原 test/core/resource_scan_test.dart ====================
void _main_4() {
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

// ==================== 原 test/core/url_resolver_test.dart ====================
void _main_5() {
  const config = ServerConfig(baseUrl: 'https://media.example/oh-my-media');

  test('相对 API 地址保留反向代理前缀', () {
    expect(
      resolveServerUrl(config, '/api/movies/id/7/stream.m3u8?quality=1080p'),
      'https://media.example/oh-my-media/api/movies/id/7/stream.m3u8?quality=1080p',
    );
  });

  test('图片路径自动补齐 API 前缀', () {
    expect(
      resolveApiUrl(config, '/images/poster-1'),
      'https://media.example/oh-my-media/api/images/poster-1',
    );
  });

  test('HLS token 追加且保留画质 query', () {
    final url = appendQueryToken(
      'https://media.example/oh-my-media/api/stream.m3u8?quality=720p',
      'access.token',
    );
    expect(url, contains('quality=720p'));
    expect(url, contains('token=access.token'));
  });

  test('外部 .strm 地址原样保留', () {
    const external = 'https://cdn.example/video.mp4?sig=abc';
    expect(resolveProtectedUrl(config, external, 'access.token'), external);
  });

  test('区分外部 .strm 地址与本地播放地址', () {
    expect(
      isExternalUrl(config, 'https://cdn.example/video.mp4?sig=abc'),
      isTrue,
    );
    expect(
      isExternalUrl(config, '/api/movies/id/7/stream?mode=direct'),
      isFalse,
    );
    expect(
      isExternalUrl(
        config,
        'https://media.example/oh-my-media/api/movies/id/7/stream',
      ),
      isFalse,
    );
  });

  test('同服务器绝对地址追加 token', () {
    const local = 'https://media.example/api/movies/id/7/stream?mode=direct';
    expect(
      resolveProtectedUrl(config, local, 'access.token'),
      '$local&token=access.token',
    );
  });

  test('预览图相对地址解析为带鉴权参数的服务器地址', () {
    expect(
      resolveProtectedUrl(
        config,
        '/api/movies/id/7/extrafanart/preview-1.jpg',
        'access.token',
      ),
      'https://media.example/oh-my-media/api/movies/id/7/extrafanart/preview-1.jpg?token=access.token',
    );
  });
}

void main() {
  group('app_version', _main_0);
  group('app_haptics', _main_1);
  group('map_with_concurrency', _main_2);
  group('file_operation_tracker', _main_3);
  group('resource_scan', _main_4);
  group('url_resolver', _main_5);
}
