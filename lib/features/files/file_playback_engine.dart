import '../../core/sources/common/source_descriptor.dart';
import '../player/playback_engine.dart';

/// 选择文件源的默认播放内核。
///
/// WebDAV 与 OpenList 是原生 HTTP(S) 地址，iOS 上继续使用 KSPlayer；SMB
/// 只能通过 Dart 提供的本机 HTTP 回环代理，优先使用项目原本的 libmpv
/// 内核，避免 KSPlayer 原生层在回环地址尚未发起请求时一直停留在准备
/// 状态。网盘直链等要求自定义 User-Agent 的资源同样要走回环代理
/// （[loopback]）：播放内核（尤其 iOS 系统内核）改不掉这类请求头，
/// 由代理侧代发。
PlaybackEngineKind? filePlaybackEngineKind({
  required SourceKind sourceKind,
  required bool isIOS,
  PlaybackEngineKind? requested,
  bool loopback = false,
}) {
  if (requested != null || !isIOS) return requested;
  if (loopback || sourceKind == SourceKind.smb) {
    return PlaybackEngineKind.libmpv;
  }
  return PlaybackEngineKind.ksPlayer;
}
