/// Emby / Jellyfin PlaybackInfo 请求携带的客户端能力声明（DeviceProfile）。
///
/// 服务器依据该 profile 决定播放策略：声明 HTTP 直连与 HLS 转码能力后，
/// 无法直连的媒体（或用户强制转码）会拿到 TranscodingUrl，「转码播放」
/// 不再因响应缺少转码地址而静默降级为直连。字段取两家服务器的公共子集，
/// 未识别的字段会被服务端忽略。
Map<String, Object?> playbackDeviceProfile() => const {
  'MaxStreamingBitrate': 120000000,
  'MaxStaticBitrate': 120000000,
  'MusicStreamingTranscodingBitrate': 320000,
  'DirectPlayProtocols': ['Http'],
  'TranscodingProfiles': [
    {
      'Type': 'Video',
      'Protocol': 'hls',
      'Container': 'ts',
      'VideoCodec': 'h264,hevc,h265',
      'AudioCodec': 'aac,mp3,ac3,eac3,opus,flac,vorbis',
      'BreakOnNonKeyFrames': true,
    },
    {'Type': 'Audio', 'Protocol': 'http', 'Container': 'mp3', 'AudioCodec': 'mp3'},
  ],
  'SubtitleProfiles': [
    {'Format': 'srt', 'Method': 'External'},
    {'Format': 'subrip', 'Method': 'External'},
    {'Format': 'vtt', 'Method': 'External'},
    {'Format': 'ass', 'Method': 'External'},
    {'Format': 'ssa', 'Method': 'External'},
    {'Format': 'pgs', 'Method': 'Embed'},
    {'Format': 'pgssub', 'Method': 'Embed'},
  ],
};
