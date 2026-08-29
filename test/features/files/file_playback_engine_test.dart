import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/common/source_descriptor.dart';
import 'package:omm/features/files/file_playback_engine.dart';
import 'package:omm/features/player/playback_engine.dart';

void main() {
  test('iOS SMB 默认使用 libmpv 读取回环代理', () {
    expect(
      filePlaybackEngineKind(sourceKind: SourceKind.smb, isIOS: true),
      PlaybackEngineKind.libmpv,
    );
  });

  test('iOS WebDAV 默认保留 KSPlayer 直连播放', () {
    expect(
      filePlaybackEngineKind(sourceKind: SourceKind.webDav, isIOS: true),
      PlaybackEngineKind.ksPlayer,
    );
  });

  test('调试模式手动选择优先于文件源默认内核', () {
    expect(
      filePlaybackEngineKind(
        sourceKind: SourceKind.smb,
        isIOS: true,
        requested: PlaybackEngineKind.ksPlayer,
      ),
      PlaybackEngineKind.ksPlayer,
    );
  });

  test('非 iOS 返回空以沿用播放设置和会话工厂默认值', () {
    expect(
      filePlaybackEngineKind(sourceKind: SourceKind.smb, isIOS: false),
      isNull,
    );
  });
}
