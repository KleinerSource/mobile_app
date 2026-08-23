/// mpv 错误上报的处理方式。
enum PlayerErrorDisposition {
  /// 播放本身失败：切换到全屏错误页并停止播放。
  fatal,

  /// 字幕加载失败：主媒体仍在正常播放，仅提示，不中断播放。
  subtitleWarning,
}

/// 判断一条来自 mpv 错误流的报错应按播放错误还是字幕错误处理。
///
/// 字幕内容由客户端下载后本地加载，接口 404/超时等失败不会进入 mpv；
/// 但 mpv 解析字幕文件失败时仍可能向错误流写入 `cplayer`/`stream` 等
/// 前缀的日志，与主媒体失败的报错难以从文本上区分。因此结合两个信号判定：
/// - [subtitleGuardUntil]：近期是否发起过字幕文件加载（窗口取 15 秒）；
/// - [mainMediaLoaded]：主媒体是否已经完成装载（有时长或音视频轨道）。
///
/// 两者同时成立时把错误降级为字幕提示，避免字幕不可用拖垮正常播放。
PlayerErrorDisposition classifyPlayerError({
  required DateTime? subtitleGuardUntil,
  required DateTime now,
  required bool mainMediaLoaded,
}) {
  if (subtitleGuardUntil != null && now.isBefore(subtitleGuardUntil) && mainMediaLoaded) {
    return PlayerErrorDisposition.subtitleWarning;
  }
  return PlayerErrorDisposition.fatal;
}
