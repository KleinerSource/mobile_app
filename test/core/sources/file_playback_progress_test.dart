import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omm/core/sources/files/file_playback_progress.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('按文件名保存并读取续播位置，忽略目录和服务器', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);

    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 42,
      durationSec: 300,
    );

    final progress = repository.load('aaa.mp4');
    expect(progress?.positionSec, 42);
    expect(progress?.durationSec, 300);
    expect(progress?.percentage, 14);
    expect(repository.load('different-server/aaa.mp4')?.percentage, 14);
    expect(repository.load(r'other-directory\aaa.mp4')?.percentage, 14);
    expect(repository.load('bbb.mp4'), isNull);
  });

  test('播放到末尾附近会清除续播位置', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);

    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 285,
      durationSec: 300,
    );

    expect(repository.load('aaa.mp4'), isNull);
  });

  test('播放进度小于5%时不保存续播记录，并清除已有记录', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);

    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 42,
      durationSec: 300,
    );
    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 14,
      durationSec: 300,
    );

    expect(repository.load('aaa.mp4'), isNull);
  });

  test('播放进度达到5%时才保存续播记录', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);

    await repository.savePosition(
      fileName: 'aaa.mp4',
      positionSec: 15,
      durationSec: 300,
    );

    expect(repository.load('aaa.mp4')?.positionSec, 15);
  });

  test('已有的低于5%续播记录不会被恢复', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = FilePlaybackProgressRepository(prefs);
    final key =
        'file.playback.position.${base64Url.encode(utf8.encode('aaa.mp4'))}';
    await prefs.setString(
      key,
      jsonEncode({'position_sec': 14, 'duration_sec': 300}),
    );

    expect(repository.load('aaa.mp4'), isNull);
  });
}
