import '../../core/sources/common/source_descriptor.dart';
import '../player/playback_engine.dart';

/// 选择文件源的默认播放内核。
///
/// WebDAV 是原生 HTTP(S) 地址，iOS 上继续使用 KSPlayer；SMB 没有可供
/// 播放器使用的 HTTP URL，OpenList 的网盘直链则存在跨域、Cookie、
/// User-Agent 等播放内核难以满足的限制，两者统一通过 Dart 提供的本机
/// HTTP 回环代理播放，优先使用项目原本的 libmpv 内核，避免 KSPlayer
/// 原生层在回环地址尚未发起请求时一直停留在准备状态。
PlaybackEngineKind? filePlaybackEngineKind({
  required SourceKind sourceKind,
  required bool isIOS,
  PlaybackEngineKind? requested,
}) {
  if (requested != null || !isIOS) return requested;
  return sourceKind == SourceKind.smb || sourceKind == SourceKind.openList
      ? PlaybackEngineKind.libmpv
      : PlaybackEngineKind.ksPlayer;
}
