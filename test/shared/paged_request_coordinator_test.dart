import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/paged_request_coordinator.dart';

void main() {
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
