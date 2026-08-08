import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/watch_record.dart';
import 'package:md_center/features/player/player_resume.dart';

void main() {
  const record = WatchRecord(
    lastPositionSec: 123.4,
    durationSec: 600,
    completed: false,
  );

  test('自动续播使用服务端最后位置', () {
    expect(
      resolveResumePosition(
        enabled: true,
        explicitPositionSec: 0,
        record: record,
      ),
      123,
    );
  });

  test('显式位置优先于服务端记录', () {
    expect(
      resolveResumePosition(
        enabled: true,
        explicitPositionSec: 45,
        record: record,
      ),
      45,
    );
  });

  test('关闭续播或已完成影片从头开始', () {
    expect(
      resolveResumePosition(
        enabled: false,
        explicitPositionSec: 0,
        record: record,
      ),
      0,
    );
    expect(
      WatchRecord(
        lastPositionSec: 580,
        durationSec: 600,
        completed: true,
      ).resumePositionSec,
      0,
    );
  });
}
