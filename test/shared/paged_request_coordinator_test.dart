import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/paged_request_coordinator.dart';

void main() {
  test('页码从1开始时仅首屏完成刷新，旧首屏不能结束新刷新', () async {
    final requests = PagedRequestCoordinator(firstPageKey: 1);
    final old = requests.begin(1)!;
    late PagedRequest current;
    final done = requests.refresh(() => current = requests.begin(1)!);
    var completed = false;
    unawaited(done.then((_) => completed = true));
    old.finish();
    requests.begin(2)!.finish();
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    current.finish();
    await done;
    expect(completed, isTrue);
    requests.dispose();
  });

  test('页码刷新失败收尾与切换查询均释放等待', () async {
    final requests = PagedRequestCoordinator(firstPageKey: 1);
    late PagedRequest first;
    final failed = requests.refresh(() => first = requests.begin(1)!);
    try {
      throw StateError('请求失败');
    } catch (_) {
      expect(first.isCurrent, isTrue);
    } finally {
      first.finish();
    }
    await failed;
    final switched = requests.refresh(() => first = requests.begin(1)!);
    requests.invalidate();
    await switched;
    expect(first.isCurrent, isFalse);
    final disposed = requests.refresh(() => first = requests.begin(1)!);
    requests.dispose();
    await disposed;
    expect(first.isCurrent, isFalse);
  });

  for (final firstKey in [0, 1]) {
    test('替换刷新仅由最新首屏结束，首键=$firstKey', () async {
      final requests = PagedRequestCoordinator(firstPageKey: firstKey);
      late PagedRequest old;
      final previous = requests.refresh(() => old = requests.begin(firstKey)!);
      requests.invalidate();
      late PagedRequest current;
      final next = requests.refresh(() => current = requests.begin(firstKey)!);
      var completed = false;
      unawaited(next.then((_) => completed = true));
      await previous;
      old.finish();
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(current.isCurrent, isTrue);
      current.finish();
      await next;
      requests.dispose();
    });
  }

  for (final fails in [false, true]) {
    test('请求 helper 去重并隔离旧${fails ? '失败' : '成功'}', () async {
      final requests = PagedRequestCoordinator();
      final old = Completer<int>();
      final latest = Completer<int>();
      final applied = <int>[];
      final errors = <Object>[];
      final first = requests.execute(
        key: 0,
        load: () => old.future,
        onSuccess: applied.add,
        onError: errors.add,
      );
      var duplicateLoaded = false;
      await requests.execute(
        key: 0,
        load: () async {
          duplicateLoaded = true;
          return 3;
        },
        onSuccess: applied.add,
        onError: errors.add,
      );
      expect(duplicateLoaded, isFalse);
      late Future<void> loading;
      final refreshed = requests.refresh(() {
        loading = requests.execute(
          key: 0,
          load: () => latest.future,
          onSuccess: applied.add,
          onError: errors.add,
        );
      });
      if (fails) {
        old.completeError(StateError('旧失败'));
      } else {
        old.complete(1);
      }
      await first;
      expect(applied, isEmpty);
      expect(errors, isEmpty);
      expect(requests.begin(0), isNull);
      latest.complete(2);
      await loading;
      await refreshed;
      expect(applied, [2]);
      requests.dispose();
    });
  }

  test('请求 helper 销毁后不回写，当前解析失败结束刷新且允许重试', () async {
    final requests = PagedRequestCoordinator();
    final errors = <Object>[];
    final refreshed = requests.refresh(() {
      unawaited(
        requests.execute<int>(
          key: 0,
          load: () async => 1,
          onSuccess: (_) => throw const FormatException('无效响应'),
          onError: errors.add,
        ),
      );
    });
    await refreshed;
    expect(errors.single, isA<FormatException>());
    final pending = Completer<int>();
    final loading = requests.execute(
      key: 0,
      load: () => pending.future,
      onSuccess: (_) => fail('销毁后不能回写'),
      onError: errors.add,
    );
    requests.dispose();
    pending.completeError(StateError('迟到失败'));
    await loading;
    expect(errors, hasLength(1));
  });

  test('同页请求去重，筛选变化后旧请求不能回写或释放新请求', () {
    final requests = PagedRequestCoordinator();
    final old = requests.begin(0)!;
    expect(requests.begin(0), isNull);
    requests.invalidate();
    final current = requests.begin(0)!;
    expect(old.isCurrent, isFalse);
    old.finish();
    expect(requests.begin(0), isNull);
    expect(current.isCurrent, isTrue);
    current.finish();
    expect(requests.begin(0), isNotNull);
  });

  test('刷新等待真实首屏完成，重复刷新共享等待', () async {
    final requests = PagedRequestCoordinator();
    late PagedRequest first;
    var reloads = 0;
    final done = requests.refresh(() {
      reloads++;
      first = requests.begin(0)!;
    });
    expect(identical(done, requests.refresh(() => reloads++)), isTrue);
    var completed = false;
    unawaited(done.then((_) => completed = true));
    requests.begin(30)!.finish();
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    first.finish();
    await done;
    expect(reloads, 1);
    expect(completed, isTrue);
  });

  test('销毁结束刷新并拒绝旧成功和旧失败回调', () async {
    final requests = PagedRequestCoordinator();
    late PagedRequest first;
    final done = requests.refresh(() => first = requests.begin(0)!);
    requests.dispose();
    await done;
    expect(first.isCurrent, isFalse);
    expect(requests.begin(0), isNull);
    first.finish();
  });
}
