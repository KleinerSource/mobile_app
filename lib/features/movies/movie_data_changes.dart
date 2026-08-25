/// 影片数据变更计数器(进程内全局快照)。
///
/// 详情页链路上的真实变更点(编辑元数据、裁剪封面、播放器上报进度、删除、
/// 收藏切换、确认新资源等)由 repository 层递增对应计数;列表与首页在进入
/// 详情页前记录快照,返回后对比:没有任何计数变化时直接沿用已有缓存,
/// 不触发刷新,避免盲目刷新导致封面等资源被重复请求。
///
/// 刻意做成纯静态计数而非 Riverpod provider:播放器在 dispose 的异步链路中
/// 也要能安全递增,且使用方只需"前后对比",不需要监听重建。
class MovieDataChanges {
  const MovieDataChanges._(this.metadata, this.images, this.progress);

  /// 元数据(标题/标签/收藏状态/新资源标记等)变更计数。
  final int metadata;

  /// 封面等图片内容变更计数(同 UUID 下服务器替换了图片)。
  final int images;

  /// 播放进度上报计数。
  final int progress;

  static int _metadata = 0;
  static int _images = 0;
  static int _progress = 0;

  /// 记录当前计数快照,通常在进入详情页前调用。
  static MovieDataChanges snapshot() =>
      MovieDataChanges._(_metadata, _images, _progress);

  /// 任何一类计数发生变化(元数据 / 封面 / 播放进度)。
  bool changedSince(MovieDataChanges before) =>
      metadata != before.metadata ||
      images != before.images ||
      progress != before.progress;

  /// 会影响列表卡片与封面展示的计数发生变化(元数据 / 封面)。
  bool displayChangedSince(MovieDataChanges before) =>
      metadata != before.metadata || images != before.images;

  /// 封面图片内容被替换,需要刷新图片缓存。
  bool imagesChangedSince(MovieDataChanges before) => images != before.images;

  /// 播放器实际上报过播放进度。
  bool progressChangedSince(MovieDataChanges before) =>
      progress != before.progress;

  static void bumpMetadata() => _metadata++;

  static void bumpImages() => _images++;

  static void bumpProgress() => _progress++;
}
