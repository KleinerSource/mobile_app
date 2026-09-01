import 'package:dio/dio.dart';

import 'package:omm/core/api/api_exception.dart';
import 'package:omm/features/emby/models/emby_models.dart';

/// Emby REST API 客户端。
///
/// Emby 的接口挂在根路径的 /emby 前缀下（dio baseUrl 已按项目分支处理），
/// 响应是裸 JSON 而非 OMM 的 {success, data} 信封，因此这里直接解析
/// dio 返回的 Map，不经过 envelope 解包。鉴权由 dio 拦截器统一注入
/// X-Emby-Token；播放器和图片内核无法带请求头，改用 api_key 查询参数。
class EmbyApi {
  EmbyApi(this._dio);

  final Dio _dio;

  /// 用户名 + 密码登录。
  ///
  /// Emby 要求认证请求携带 X-Emby-Authorization 声明客户端身份；
  /// [deviceId] 必须跨登录稳定，否则服务器会累积大量设备会话。
  Future<EmbyAuthResult> authenticateByName({
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
      '/emby/Users/AuthenticateByName',
      data: {'Username': normalizedUser, 'Pw': password},
      options: Options(
        headers: {
          'X-Emby-Authorization':
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
    return EmbyAuthResult.fromJson(data);
  }

  /// 用当前令牌取登录用户，用于启动时校验会话有效性。
  Future<EmbyUser> currentUser() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/emby/Users/Me',
      options: Options(
        extra: const {'skipRefresh': true, 'skipRetry': true},
      ),
    );
    final data = response.data;
    if (data == null) {
      throw ApiException('用户信息响应为空');
    }
    return EmbyUser.fromJson(data);
  }

  /// 当前用户可见的媒体库（Views）。
  Future<List<EmbyItem>> views(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/emby/Users/${_segment(userId)}/Views',
    );
    return _items(response.data);
  }

  /// 通用条目分页查询。参数命名与 Emby 一致，仅保留移动端用到的子集。
  Future<EmbyItemPage> items(
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
  }) {
    return _itemPage(
      '/emby/Users/${_segment(userId)}/Items',
      <String, dynamic>{
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
      },
    );
  }

  /// 单条详情，返回完整字段（Overview/People/MediaSources 等）。
  Future<EmbyItem> item(String userId, String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(itemId, 'itemId', '条目 ID 不能为空');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/emby/Users/${_segment(userId)}/Items/${_segment(normalized)}',
    );
    final data = response.data;
    if (data == null) {
      throw ApiException('条目详情响应为空');
    }
    return EmbyItem.fromJson(data);
  }

  /// 首页「最新入库」。该接口直接返回数组，不带分页包装。
  Future<List<EmbyItem>> latestMedia(
    String userId, {
    String? parentId,
    String? includeItemTypes,
    int limit = 16,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/emby/Users/${_segment(userId)}/Items/Latest',
      queryParameters: <String, dynamic>{
        if (parentId?.trim().isNotEmpty == true) 'ParentId': parentId!.trim(),
        if (includeItemTypes?.trim().isNotEmpty == true)
          'IncludeItemTypes': includeItemTypes!.trim(),
        'Limit': limit,
        'EnableImages': true,
      },
    );
    final data = response.data;
    if (data == null) return const <EmbyItem>[];
    return data
        .whereType<Map>()
        .map((raw) => EmbyItem.fromJson(Map<String, dynamic>.from(raw)))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  /// 首页「继续观看」（未看完的有进度条目）。
  Future<EmbyItemPage> resumeItems(String userId, {int limit = 12}) {
    return _itemPage(
      '/emby/Users/${_segment(userId)}/Items/Resume',
      <String, dynamic>{
        'MediaTypes': 'Video',
        'Limit': limit,
      },
    );
  }

  /// 剧集「下一集」（每个系列取下一待看集）。
  Future<EmbyItemPage> nextUp(String userId, {String? parentId, int limit = 12}) {
    return _itemPage(
      '/emby/Shows/NextUp',
      <String, dynamic>{
        'UserId': userId,
        if (parentId?.trim().isNotEmpty == true) 'ParentId': parentId!.trim(),
        'Limit': limit,
      },
    );
  }

  /// 剧集的季列表。
  Future<List<EmbyItem>> seasons(String userId, String seriesId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/emby/Shows/${_segment(seriesId)}/Seasons',
      queryParameters: {'UserId': userId},
    );
    return _items(response.data);
  }

  /// 某一季的集列表，按季内序号排序。
  Future<EmbyItemPage> episodes(String userId, String seasonId) {
    return _itemPage(
      '/emby/Shows/${_segment(seasonId)}/Episodes',
      <String, dynamic>{
        'UserId': userId,
        'Fields': 'Overview,MediaSources',
        'SortBy': 'ParentIndexNumber,IndexNumber',
      },
    );
  }

  /// 播放信息：媒体源、轨道与服务器生成的转码地址。
  Future<EmbyPlaybackInfo> playbackInfo(
    String userId,
    String itemId, {
    String? mediaSourceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/emby/Items/${_segment(itemId)}/PlaybackInfo',
      queryParameters: <String, dynamic>{
        'UserId': userId,
        if (mediaSourceId?.trim().isNotEmpty == true)
          'MediaSourceId': mediaSourceId!.trim(),
        'AutoOpenLiveStream': true,
      },
      data: {},
      options: Options(
        // 播放决策不需要 GET 重试语义，失败直接上抛。
        extra: const {'skipRetry': true},
      ),
    );
    final data = response.data;
    if (data == null) {
      throw ApiException('播放信息响应为空');
    }
    return EmbyPlaybackInfo.fromJson(data);
  }

  /// 收藏 / 取消收藏，返回带最新 UserData 的条目。
  Future<EmbyItem> markFavorite(
    String userId,
    String itemId,
    bool favorite,
  ) async {
    final response = favorite
        ? await _dio.post<Map<String, dynamic>>(
            '/emby/Users/${_segment(userId)}/FavoriteItems/${_segment(itemId)}',
          )
        : await _dio.delete<Map<String, dynamic>>(
            '/emby/Users/${_segment(userId)}/FavoriteItems/${_segment(itemId)}',
          );
    final data = response.data;
    if (data == null) {
      throw ApiException('收藏状态响应为空');
    }
    return EmbyItem.fromJson(data);
  }

  /// 标记已看 / 未看，返回带最新 UserData 的条目。
  Future<EmbyItem> markPlayed(
    String userId,
    String itemId,
    bool played,
  ) async {
    final response = played
        ? await _dio.post<Map<String, dynamic>>(
            '/emby/Users/${_segment(userId)}/PlayedItems/${_segment(itemId)}',
          )
        : await _dio.delete<Map<String, dynamic>>(
            '/emby/Users/${_segment(userId)}/PlayedItems/${_segment(itemId)}',
          );
    final data = response.data;
    if (data == null) {
      throw ApiException('观看状态响应为空');
    }
    return EmbyItem.fromJson(data);
  }

  /// 播放会话上报：开始 / 进度 / 结束。
  ///
  /// 进度按 Emby 的 100ns tick 上报；退出时的 Stopped 报告决定服务器端
  /// 的「继续观看」位置。
  Future<void> reportPlaybackStart({
    required String itemId,
    required int positionTicks,
    String? playSessionId,
  }) {
    return _reportPlayback(
      '/emby/Sessions/Playing',
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
      '/emby/Sessions/Playing/Progress',
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
      '/emby/Sessions/Playing/Stopped',
      itemId,
      positionTicks,
      playSessionId: playSessionId,
    );
  }

  /// 直链播放地址。static=true 返回原始文件，seek 由播放器通过
  /// HTTP Range 完成；api_key 让无请求头能力的内核也能访问。
  static String streamUrl({
    required String baseUrl,
    required String itemId,
    String? mediaSourceId,
    String? token,
  }) {
    final query = <String, String>{
      'static': 'true',
      if (mediaSourceId?.trim().isNotEmpty == true)
        'MediaSourceId': mediaSourceId!.trim(),
      if (token?.trim().isNotEmpty == true) 'api_key': token!.trim(),
    };
    return _buildUrl(
      baseUrl,
      '/emby/Videos/${Uri.encodeComponent(itemId)}/stream',
      query,
    );
  }

  /// 海报 / 背景图地址。图片端点在默认配置下免鉴权，api_key 仅作兜底。
  static String imageUrl({
    required String baseUrl,
    required String itemId,
    String imageType = 'Primary',
    int? maxWidth,
    String? token,
  }) {
    final query = <String, String>{
      if (maxWidth != null && maxWidth > 0) 'maxWidth': maxWidth.toString(),
      'quality': '90',
      if (token?.trim().isNotEmpty == true) 'api_key': token!.trim(),
    };
    return _buildUrl(
      baseUrl,
      '/emby/Items/${Uri.encodeComponent(itemId)}/Images/${Uri.encodeComponent(imageType)}',
      query,
    );
  }

  /// 服务器返回的 TranscodingUrl 是相对路径，转成可播放的绝对地址。
  static String resolveEmbyUrl(String baseUrl, String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.hasScheme) return rawUrl;
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$normalizedBase${rawUrl.trim().startsWith('/') ? '' : '/'}${rawUrl.trim()}';
  }

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

  Future<EmbyItemPage> _itemPage(
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
    return EmbyItemPage.fromJson(data);
  }

  List<EmbyItem> _items(Map<String, dynamic>? data) {
    if (data == null) return const <EmbyItem>[];
    final rawItems = data['Items'];
    if (rawItems is! List) return const <EmbyItem>[];
    return rawItems
        .whereType<Map>()
        .map((raw) => EmbyItem.fromJson(Map<String, dynamic>.from(raw)))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  static String _buildUrl(String baseUrl, String path, Map<String, String> query) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(
      queryParameters: query,
    ).toString();
  }
}

String _segment(String value) => Uri.encodeComponent(value.trim());
