import 'package:dio/dio.dart';

import 'package:omm/core/api/api_exception.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';

/// MediaBrowser（Emby / Jellyfin）REST API 客户端。
///
/// 两家服务器的接口同构，项目差异全部在 [config]（路径前缀 / 登录头 /
/// token 参数名）。响应是裸 JSON 而非 OMM 的 {success, data} 信封，因此
/// 这里直接解析 dio 返回的 Map，不经过 envelope 解包。鉴权由 dio 拦截器
/// 按项目统一注入（X-Emby-Token / Authorization: MediaBrowser Token）；
/// 播放器和图片内核无法带请求头，改用 config.tokenQueryParam 查询参数。
class MediaBrowserApi {
  MediaBrowserApi(this._dio, this.config);

  final Dio _dio;
  final MediaBrowserConfig config;

  /// 用户名 + 密码登录。
  ///
  /// 认证请求需按 [MediaBrowserConfig.authHeaderName] 声明客户端身份；
  /// [deviceId] 必须跨登录稳定，否则服务器会累积大量设备会话。
  Future<MediaBrowserAuthResult> authenticateByName({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    required String appVersion,
  }) async {
    final normalizedUser = username.trim();
    if (normalizedUser.isEmpty) {
      throw ArgumentError.value(username, 'username', '用户名不能为空');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      config.path('/Users/AuthenticateByName'),
      data: {'Username': normalizedUser, 'Pw': password},
      options: Options(
        headers: {
          config.authHeaderName:
              'MediaBrowser Client="Oh My Media", Device="$deviceName", '
              'DeviceId="$deviceId", Version="$appVersion"',
        },
        extra: const {'skipAuth': true, 'skipRefresh': true, 'skipRetry': true},
      ),
    );
    final data = response.data;
    if (data == null) {
      throw ApiException('登录响应为空');
    }
    return MediaBrowserAuthResult.fromJson(data);
  }

  /// 启动时校验令牌是否仍有效。
  ///
  /// Jellyfin 支持按 token 反查用户（/Users/Me）；Emby 没有该端点
  /// （实测返回 500），只能用登录时持久化的 [persistedUserId] 查
  /// /Users/{Id}，为空时抛 ArgumentError。
  Future<MediaBrowserUser> validateSession(String? persistedUserId) async {
    if (config.supportsCurrentUser) {
      return _userFrom(_p('/Users/Me'));
    }
    final normalized = persistedUserId?.trim() ?? '';
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        persistedUserId,
        'persistedUserId',
        '用户 ID 不能为空',
      );
    }
    return _userFrom(_p('/Users/${Uri.encodeComponent(normalized)}'));
  }

  /// 当前用户可见的媒体库（Views）。
  Future<List<MediaBrowserItem>> views(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _p('/Users/${_segment(userId)}/Views'),
    );
    return _items(response.data);
  }

  /// 管理端虚拟媒体库列表。
  Future<List<MediaBrowserLibrary>> virtualFolders() async {
    final response = await _dio.get<Object>(_p('/Library/VirtualFolders'));
    final data = response.data;
    final rawItems = data is List
        ? data
        : data is Map && data['Items'] is List
        ? data['Items'] as List
        : const <Object?>[];
    return rawItems
        .whereType<Map>()
        .map(
          (raw) => MediaBrowserLibrary.fromJson(
            Map<String, dynamic>.from(raw),
          ),
        )
        .where((library) => library.name.isNotEmpty)
        .toList(growable: false);
  }

  /// 创建虚拟媒体库。Emby/Jellyfin 通过查询参数接收名称、类型和路径。
  Future<void> addVirtualFolder({
    required String name,
    required String collectionType,
    required List<String> paths,
  }) async {
    final normalizedName = name.trim();
    final normalizedType = collectionType.trim();
    final normalizedPaths = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', '媒体库名称不能为空');
    }
    if (normalizedType.isEmpty) {
      throw ArgumentError.value(collectionType, 'collectionType', '媒体库类型不能为空');
    }
    if (normalizedPaths.isEmpty) {
      throw ArgumentError.value(paths, 'paths', '至少需要一个媒体路径');
    }
    await _dio.post<void>(
      _p('/Library/VirtualFolders'),
      queryParameters: {
        'name': normalizedName,
        'collectionType': normalizedType,
        'paths': normalizedPaths.join(','),
        'refreshLibrary': false,
      },
    );
  }

  /// 删除虚拟媒体库。
  Future<void> removeVirtualFolder(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', '媒体库名称不能为空');
    }
    await _dio.delete<void>(
      _p('/Library/VirtualFolders'),
      queryParameters: {'name': normalized, 'refreshLibrary': false},
    );
  }

  /// 重命名虚拟媒体库。
  Future<void> renameVirtualFolder({
    required String name,
    required String newName,
  }) async {
    final normalizedName = name.trim();
    final normalizedNewName = newName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', '媒体库名称不能为空');
    }
    if (normalizedNewName.isEmpty) {
      throw ArgumentError.value(newName, 'newName', '媒体库名称不能为空');
    }
    await _dio.post<void>(
      _p('/Library/VirtualFolders/Name'),
      queryParameters: {
        'name': normalizedName,
        'newName': normalizedNewName,
        'refreshLibrary': false,
      },
    );
  }

  /// 为虚拟媒体库添加一个媒体路径。
  Future<void> addMediaPath({
    required String libraryName,
    required String path,
  }) async {
    final normalizedName = libraryName.trim();
    final normalizedPath = path.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(libraryName, 'libraryName', '媒体库名称不能为空');
    }
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', '媒体路径不能为空');
    }
    await _dio.post<void>(
      _p('/Library/VirtualFolders/Paths'),
      data: {'Name': normalizedName, 'Path': normalizedPath},
      queryParameters: {'refreshLibrary': false},
    );
  }

  /// 从虚拟媒体库移除一个媒体路径。
  Future<void> removeMediaPath({
    required String libraryName,
    required String path,
  }) async {
    final normalizedName = libraryName.trim();
    final normalizedPath = path.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(libraryName, 'libraryName', '媒体库名称不能为空');
    }
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', '媒体路径不能为空');
    }
    await _dio.delete<void>(
      _p('/Library/VirtualFolders/Paths'),
      queryParameters: {
        'name': normalizedName,
        'path': normalizedPath,
        'refreshLibrary': false,
      },
    );
  }

  /// 更新虚拟媒体库启用状态，并保留服务器返回的其它 LibraryOptions。
  Future<void> updateVirtualFolderOptions({
    required String id,
    required bool enabled,
    Map<String, dynamic> options = const <String, dynamic>{},
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'id', '媒体库 ID 不能为空');
    }
    final updatedOptions = <String, dynamic>{...options, 'Enabled': enabled};
    await _dio.post<void>(
      _p('/Library/VirtualFolders/LibraryOptions'),
      data: {'Id': normalizedId, 'LibraryOptions': updatedOptions},
    );
  }

  /// 触发一次全局媒体库刷新。
  Future<void> refreshLibrary() => _dio.post<void>(_p('/Library/Refresh'));

  /// 通用条目分页查询。参数命名与服务器一致，仅保留移动端用到的子集。
  Future<MediaBrowserItemPage> items(
    String userId, {
    String? parentId,
    String? includeItemTypes,
    bool? recursive,
    String? searchTerm,
    String? sortBy,
    String? sortOrder,
    int? startIndex,
    int? limit,
    bool? isFavorite,
    List<String>? filters,
    List<String>? fields,
    String? personIds,
  }) {
    return _itemPage(_p('/Users/${_segment(userId)}/Items'), <String, dynamic>{
      if (parentId?.trim().isNotEmpty == true) 'ParentId': parentId!.trim(),
      if (includeItemTypes?.trim().isNotEmpty == true)
        'IncludeItemTypes': includeItemTypes!.trim(),
      if (recursive != null) 'Recursive': recursive,
      if (searchTerm?.trim().isNotEmpty == true)
        'SearchTerm': searchTerm!.trim(),
      if (sortBy?.trim().isNotEmpty == true) 'SortBy': sortBy!.trim(),
      if (sortOrder?.trim().isNotEmpty == true) 'SortOrder': sortOrder!.trim(),
      if (startIndex != null && startIndex >= 0) 'StartIndex': startIndex,
      if (limit != null && limit > 0) 'Limit': limit,
      if (isFavorite != null) 'Filters': isFavorite ? 'IsFavorite' : null,
      if (filters != null && filters.isNotEmpty) 'Filters': filters.join(','),
      if (fields != null && fields.isNotEmpty) 'Fields': fields.join(','),
      if (personIds?.trim().isNotEmpty == true) 'PersonIds': personIds!.trim(),
    });
  }

  /// 首页媒体库统计：只请求一条数据，使用服务端返回的总数。
  Future<MediaBrowserLibraryStats> libraryStats(String userId) async {
    final pages = await Future.wait<MediaBrowserItemPage>([
      items(userId, includeItemTypes: 'Movie', recursive: true, limit: 1),
      items(userId, includeItemTypes: 'Series', recursive: true, limit: 1),
      items(userId, includeItemTypes: 'Episode', recursive: true, limit: 1),
    ]);
    return MediaBrowserLibraryStats(
      movieCount: pages[0].total,
      seriesCount: pages[1].total,
      episodeCount: pages[2].total,
    );
  }

  /// 单条详情，返回完整字段（Overview/People/MediaSources 等）。
  Future<MediaBrowserItem> item(String userId, String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(itemId, 'itemId', '条目 ID 不能为空');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      _p('/Users/${_segment(userId)}/Items/${_segment(normalized)}'),
    );
    final data = response.data;
    if (data == null) {
      throw ApiException('条目详情响应为空');
    }
    return MediaBrowserItem.fromJson(data);
  }

  /// 首页「最新入库」。该接口直接返回数组，不带分页包装。
  Future<List<MediaBrowserItem>> latestMedia(
    String userId, {
    String? parentId,
    String? includeItemTypes,
    int limit = 16,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      _p('/Users/${_segment(userId)}/Items/Latest'),
      queryParameters: <String, dynamic>{
        if (parentId?.trim().isNotEmpty == true) 'ParentId': parentId!.trim(),
        if (includeItemTypes?.trim().isNotEmpty == true)
          'IncludeItemTypes': includeItemTypes!.trim(),
        'Limit': limit,
        'EnableImages': true,
      },
    );
    final data = response.data;
    if (data == null) return const <MediaBrowserItem>[];
    return data
        .whereType<Map>()
        .map((raw) => MediaBrowserItem.fromJson(Map<String, dynamic>.from(raw)))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  /// 首页「继续观看」（未看完的有进度条目）。
  Future<MediaBrowserItemPage> resumeItems(String userId, {int limit = 12}) {
    return _itemPage(
      _p('/Users/${_segment(userId)}/Items/Resume'),
      <String, dynamic>{'MediaTypes': 'Video', 'Limit': limit},
    );
  }

  /// 剧集「下一集」（每个系列取下一待看集）。
  Future<MediaBrowserItemPage> nextUp(
    String userId, {
    String? parentId,
    int limit = 12,
  }) {
    return _itemPage(_p('/Shows/NextUp'), <String, dynamic>{
      'UserId': userId,
      if (parentId?.trim().isNotEmpty == true) 'ParentId': parentId!.trim(),
      'Limit': limit,
    });
  }

  /// 剧集的季列表。
  Future<List<MediaBrowserItem>> seasons(String userId, String seriesId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _p('/Shows/${_segment(seriesId)}/Seasons'),
      queryParameters: {'UserId': userId},
    );
    return _items(response.data);
  }

  /// 某一季的集列表，按季内序号排序。
  ///
  /// 路径必须是 [seriesId]：Jellyfin 严格按路径 ID 查找剧集，传季 ID 会 404；
  /// 季通过 [seasonId] 查询参数过滤（Emby/Jellyfin 通用写法）。
  Future<MediaBrowserItemPage> episodes(
    String userId,
    String seriesId,
    String seasonId,
  ) {
    return _itemPage(
      _p('/Shows/${_segment(seriesId)}/Episodes'),
      <String, dynamic>{
        'UserId': userId,
        'SeasonId': seasonId,
        'Fields': 'Overview,MediaSources',
        'SortBy': 'ParentIndexNumber,IndexNumber',
      },
    );
  }

  /// 播放信息：媒体源、轨道与服务器生成的转码地址。
  ///
  /// [deviceProfile] 声明客户端直连/转码能力，服务器据此决定是否返回
  /// TranscodingUrl；不传则服务器视为全能力直连客户端。
  Future<MediaBrowserPlaybackInfo> playbackInfo(
    String userId,
    String itemId, {
    String? mediaSourceId,
    Map<String, Object?>? deviceProfile,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _p('/Items/${_segment(itemId)}/PlaybackInfo'),
      queryParameters: <String, dynamic>{
        'UserId': userId,
        if (mediaSourceId?.trim().isNotEmpty == true)
          'MediaSourceId': mediaSourceId!.trim(),
        'AutoOpenLiveStream': true,
      },
      data: {if (deviceProfile != null) 'DeviceProfile': deviceProfile},
      options: Options(
        // 播放决策不需要 GET 重试语义，失败直接上抛。
        extra: const {'skipRetry': true},
      ),
    );
    final data = response.data;
    if (data == null) {
      throw ApiException('播放信息响应为空');
    }
    return MediaBrowserPlaybackInfo.fromJson(data);
  }

  /// 收藏 / 取消收藏，返回带最新 UserData 的条目。
  Future<MediaBrowserItem> markFavorite(
    String userId,
    String itemId,
    bool favorite,
  ) async {
    final response = favorite
        ? await _dio.post<Map<String, dynamic>>(
            _p('/Users/${_segment(userId)}/FavoriteItems/${_segment(itemId)}'),
          )
        : await _dio.delete<Map<String, dynamic>>(
            _p('/Users/${_segment(userId)}/FavoriteItems/${_segment(itemId)}'),
          );
    final data = response.data;
    if (data == null) {
      throw ApiException('收藏状态响应为空');
    }
    return MediaBrowserItem.fromJson(data);
  }

  /// 标记已看 / 未看，返回带最新 UserData 的条目。
  Future<MediaBrowserItem> markPlayed(
    String userId,
    String itemId,
    bool played,
  ) async {
    final response = played
        ? await _dio.post<Map<String, dynamic>>(
            _p('/Users/${_segment(userId)}/PlayedItems/${_segment(itemId)}'),
          )
        : await _dio.delete<Map<String, dynamic>>(
            _p('/Users/${_segment(userId)}/PlayedItems/${_segment(itemId)}'),
          );
    final data = response.data;
    if (data == null) {
      throw ApiException('观看状态响应为空');
    }
    return MediaBrowserItem.fromJson(data);
  }

  /// 播放会话上报：开始 / 进度 / 结束。
  ///
  /// 进度按 100ns tick 上报；退出时的 Stopped 报告决定服务器端的
  /// 「继续观看」位置。
  Future<void> reportPlaybackStart({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) {
    return _reportPlayback(
      _p('/Sessions/Playing'),
      itemId,
      positionTicks,
      playSessionId: playSessionId,
    );
  }

  Future<void> reportPlaybackProgress({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
    bool isPaused = false,
  }) {
    return _reportPlayback(
      _p('/Sessions/Playing/Progress'),
      itemId,
      positionTicks,
      playSessionId: playSessionId,
      isPaused: isPaused,
    );
  }

  Future<void> reportPlaybackStopped({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) {
    return _reportPlayback(
      _p('/Sessions/Playing/Stopped'),
      itemId,
      positionTicks,
      playSessionId: playSessionId,
    );
  }

  /// 直链播放地址。static=true 返回原始文件，seek 由播放器通过
  /// HTTP Range 完成；token 查询参数让无请求头能力的内核也能访问。
  static String streamUrl({
    required MediaBrowserConfig config,
    required String baseUrl,
    required String itemId,
    String? mediaSourceId,
    String? token,
  }) {
    return _buildStreamUrl(
      config: config,
      baseUrl: baseUrl,
      path: '/Videos/${Uri.encodeComponent(itemId)}/stream',
      mediaSourceId: mediaSourceId,
      token: token,
    );
  }

  /// 音频直链播放地址，与 [streamUrl] 同构（static=true 原始文件）。
  static String audioStreamUrl({
    required MediaBrowserConfig config,
    required String baseUrl,
    required String itemId,
    String? mediaSourceId,
    String? token,
  }) {
    return _buildStreamUrl(
      config: config,
      baseUrl: baseUrl,
      path: '/Audio/${Uri.encodeComponent(itemId)}/stream',
      mediaSourceId: mediaSourceId,
      token: token,
    );
  }

  static String _buildStreamUrl({
    required MediaBrowserConfig config,
    required String baseUrl,
    required String path,
    String? mediaSourceId,
    String? token,
  }) {
    final query = <String, String>{
      'static': 'true',
      if (mediaSourceId?.trim().isNotEmpty == true)
        'MediaSourceId': mediaSourceId!.trim(),
      if (token?.trim().isNotEmpty == true)
        config.tokenQueryParam: token!.trim(),
    };
    return _buildUrl(baseUrl, config.path(path), query);
  }

  /// 外挂字幕直连下载地址（服务器转成 WebVTT）。字幕由播放页用 Dio 下载
  /// 后交给 mpv 本地加载，不进图片缓存，URL 带 token 无缓存失稳问题。
  static String subtitleStreamUrl({
    required MediaBrowserConfig config,
    required String baseUrl,
    required String itemId,
    required String mediaSourceId,
    required int streamIndex,
    String? token,
  }) {
    final query = <String, String>{
      if (token?.trim().isNotEmpty == true)
        config.tokenQueryParam: token!.trim(),
    };
    return _buildUrl(
      baseUrl,
      config.path(
        '/Videos/${Uri.encodeComponent(itemId)}'
        '/${Uri.encodeComponent(mediaSourceId)}'
        '/Subtitles/${Uri.encodeComponent(streamIndex.toString())}/Stream.vtt',
      ),
      query,
    );
  }

  /// 音频歌词。Emby / Jellyfin 的返回格式不同（Jellyfin 10.9+ 返回
  /// LyricsDto 结构，老版本或 Emby 可能返回纯 LRC 文本），这里只负责
  /// 取回原始响应，格式判定交给调用方；失败允许静默（歌词是增强信息）。
  Future<Object?> lyrics(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) return null;
    final response = await _dio.get<Object>(
      _p('/Audio/${_segment(normalized)}/Lyrics'),
      options: Options(
        // 服务器未提供歌词时通常 404，上抛由调用方决定是否回退。
        extra: const {'skipRetry': true, 'skipRefresh': true},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    return response.data;
  }

  /// 海报 / 背景图地址。
  ///
  /// 图片端点在默认配置下免鉴权，缓存用的 URL 不拼 token：磁盘缓存以
  /// 整条 URL 为 key，token 轮换（401 刷新、重登）会让全部图片缓存集体
  /// 失效。[tag] 是服务器侧的图片版本号，参与拼接后服务器换图 → URL 变化
  /// → 旧缓存自然失效，而不是 30 天内一直命中旧图。仅绕过图片缓存、
  /// 直连下载的场景（如通知栏封面的裸 Dio）才通过 [token] 补鉴权兜底。
  static String imageUrl({
    required MediaBrowserConfig config,
    required String baseUrl,
    required String itemId,
    String imageType = 'Primary',
    int? maxWidth,
    String? tag,
    String? token,
  }) {
    final query = <String, String>{
      if (maxWidth != null && maxWidth > 0) 'maxWidth': maxWidth.toString(),
      'quality': '90',
      if (tag?.trim().isNotEmpty == true) 'tag': tag!.trim(),
      if (token?.trim().isNotEmpty == true)
        config.tokenQueryParam: token!.trim(),
    };
    return _buildUrl(
      baseUrl,
      config.path(
        '/Items/${Uri.encodeComponent(itemId)}/Images/${Uri.encodeComponent(imageType)}',
      ),
      query,
    );
  }

  /// 服务器返回的 TranscodingUrl 是相对路径，转成可播放的绝对地址。
  static String resolveUrl(String baseUrl, String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.hasScheme) return rawUrl;
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$normalizedBase${rawUrl.trim().startsWith('/') ? '' : '/'}${rawUrl.trim()}';
  }

  Future<MediaBrowserUser> _userFrom(String path) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      options: Options(extra: const {'skipRefresh': true, 'skipRetry': true}),
    );
    final data = response.data;
    if (data == null) {
      throw ApiException('用户信息响应为空');
    }
    return MediaBrowserUser.fromJson(data);
  }

  String _p(String relative) => config.path(relative);

  Future<void> _reportPlayback(
    String path,
    String itemId,
    int positionTicks, {
    String? playSessionId,
    bool isPaused = false,
  }) async {
    await _dio.post<dynamic>(
      path,
      data: <String, dynamic>{
        'ItemId': itemId,
        'PositionTicks': positionTicks,
        if (playSessionId?.trim().isNotEmpty == true)
          'PlaySessionId': playSessionId!.trim(),
        'IsPaused': isPaused,
      },
      options: Options(extra: const {'skipRetry': true}),
    );
  }

  Future<MediaBrowserItemPage> _itemPage(
    String path,
    Map<String, dynamic> query,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    final data = response.data;
    if (data == null) {
      throw ApiException('条目列表响应为空');
    }
    return MediaBrowserItemPage.fromJson(data);
  }

  List<MediaBrowserItem> _items(Map<String, dynamic>? data) {
    if (data == null) return const <MediaBrowserItem>[];
    final rawItems = data['Items'];
    if (rawItems is! List) return const <MediaBrowserItem>[];
    return rawItems
        .whereType<Map>()
        .map((raw) => MediaBrowserItem.fromJson(Map<String, dynamic>.from(raw)))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  static String _buildUrl(
    String baseUrl,
    String path,
    Map<String, String> query,
  ) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse(
      '$normalizedBase$path',
    ).replace(queryParameters: query).toString();
  }
}

String _segment(String value) => Uri.encodeComponent(value.trim());
