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
