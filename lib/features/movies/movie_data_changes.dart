/// 影片数据变更计数器(进程内快照)。
///
/// 详情页链路上的真实变更点(编辑元数据、裁剪封面、播放器上报进度、删除、
/// 收藏切换、确认新资源等)由 repository 层递增对应计数。影片列表在进入
/// 某部影片详情页前记录该影片的快照,返回后只对比这部影片;没有真实变更时
/// 直接沿用已有缓存,不触发刷新,避免盲目刷新导致封面等资源被重复请求。
///
/// 刻意做成纯静态计数而非 Riverpod provider:播放器在 dispose 的异步链路中
/// 也要能安全递增,且使用方只需"前后对比",不需要监听重建。
class MovieDataChanges {
  const MovieDataChanges._(
    this.metadata,
    this.images,
    this.progress,
    this._movieId,
  );

  /// 元数据(标题/标签/收藏状态/新资源标记等)变更计数。
  final int metadata;

  /// 封面等图片内容变更计数(同 UUID 下服务器替换了图片)。
  final int images;

  /// 播放进度上报计数。
  final int progress;

  final int? _movieId;

  static int _metadata = 0;
  static int _images = 0;
  static int _progress = 0;

  static final Map<int, int> _movieMetadata = <int, int>{};
  static final Map<int, int> _movieImages = <int, int>{};
  static final Map<int, int> _movieProgress = <int, int>{};

  /// 记录当前计数快照。
  ///
  /// 传入 [movieId] 时只观察该影片,避免其他影片的后台变更让当前列表
  /// 在返回时误刷新;不传时用于包含多部影片的页面范围快照。
  static MovieDataChanges snapshot({int? movieId}) => MovieDataChanges._(
    movieId == null ? _metadata : (_movieMetadata[movieId] ?? 0),
    movieId == null ? _images : (_movieImages[movieId] ?? 0),
    movieId == null ? _progress : (_movieProgress[movieId] ?? 0),
    movieId,
  );

  /// 读取与当前快照相同范围的最新值。
  MovieDataChanges get latest => snapshot(movieId: _movieId);

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

  static void bumpMetadata({int? movieId}) {
    _metadata++;
    if (movieId != null) {
      _movieMetadata[movieId] = (_movieMetadata[movieId] ?? 0) + 1;
    }
  }

  static void bumpImages({int? movieId}) {
    _images++;
    if (movieId != null) {
      _movieImages[movieId] = (_movieImages[movieId] ?? 0) + 1;
    }
  }

  static void bumpProgress({int? movieId}) {
    _progress++;
    if (movieId != null) {
      _movieProgress[movieId] = (_movieProgress[movieId] ?? 0) + 1;
    }
  }
}
