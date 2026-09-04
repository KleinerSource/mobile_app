import 'package:omm/core/api/server_compatibility.dart';

import '../models/media_browser_models.dart';
import 'feiniu_api.dart';
import 'media_browser_api.dart';
import 'media_browser_config.dart';

/// 媒体服务器 URL 构造器（Emby/Jellyfin 与 fnos 共用接口）。
///
/// 海报/背景地址在 build 中同步拼接，不拼 token（图片端点不使用 token
/// 查询参数，缓存 key 保持稳定）；图片版本由原生资源路径和宽度参数决定。
/// 直链与图片请求头随 Provider 重建刷新登录态。
///
/// 两套协议的 URL 规则不同，由工厂按 [MediaBrowserConfig.project]
/// 分派到对应实现；Emby 与 Jellyfin 的差异继续由 [MediaBrowserConfig]
/// 配置驱动（见 [MediaBrowserApi.imageUrl]）。
abstract class MediaBrowserServerUrls {
  const MediaBrowserServerUrls._({
    required this.baseUrl,
    this.token,
    this.cookie,
  });

  final String baseUrl;
  final String? token;
  final String? cookie;

  bool get isReady => baseUrl.trim().isNotEmpty;

  /// 视频/音频直链请求头；Emby/Jellyfin 直链免头，fnos 沿用网页端的
  /// Authorization 与客户端标识头。
  Map<String, String> get directHeaders;

  /// 图片请求头。飞牛图片资源通过会话鉴权，URL 本身不拼 token。
  Map<String, String> get imageHeaders;

  String poster(String itemId, {int maxWidth = 440, String? tag});

  String backdrop(String itemId, {int maxWidth = 1280, String? tag});

  String thumb(String itemId, {int maxWidth = 440, String? tag});

  /// 短预览视频地址。只有支持预览视频的来源返回非空地址。
  String? preview(String? path) => null;

  /// 带 token 的封面直连地址，供绕过图片缓存、用无鉴权裸 Dio 下载的
  /// 场景（通知栏封面）；产物是按 itemId 命名的临时文件，不存在缓存
  /// key 失稳问题。
  String authedPoster(String itemId, {int maxWidth = 600, String? tag});

  /// 演员头像地址；无头像信息时返回 null（显示渐变首字占位）。
  String? personImage(MediaBrowserPerson person);

  String stream(String itemId, {String? mediaSourceId});

  String audioStream(String itemId, {String? mediaSourceId});

  /// 条目首选展示图（首页/详情 Hero、继续观看宽卡共用）：有背景图取
  /// Backdrop，否则有海报取 Primary，两者皆无返回 null。带 image tag，
  /// 服务器换图后 URL 变化，旧缓存自然失效。
  ///
  /// 逐项跳过空路径，避免某个来源把空的背景 tag 放在首位时直接遮掉
  /// 后面的可用海报。Stash 的 tag 已由适配器按 screenshot → webp 顺序提供。
  String? heroImage(MediaBrowserItem item) {
    for (final tag in item.backdropImageTags) {
      if (tag.trim().isEmpty) continue;
      final url = backdrop(item.id, tag: tag).trim();
      if (url.isNotEmpty) return url;
    }
    final primaryTag = item.primaryImageTag?.trim() ?? '';
    if (primaryTag.isNotEmpty) {
      final url = poster(item.id, tag: primaryTag).trim();
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  /// 条目缩略图（分集列表等窄幅场景）：有 Thumb 图用 Thumb，否则退回
  /// Primary。分集一般只有 Primary 静帧——直接请求 Thumb 端点会 404，
  /// 即使有 Thumb 图，tag 也必须与图类型一致，配错同样被拒绝。
  String? thumbnail(MediaBrowserItem item, {int maxWidth = 440}) {
    if (item.thumbImageTag != null) {
      return thumb(item.id, tag: item.thumbImageTag, maxWidth: maxWidth);
    }
    if (item.primaryImageTag != null) {
      return poster(item.id, tag: item.primaryImageTag, maxWidth: maxWidth);
    }
    return null;
  }

  /// 按服务器项目分派实现：fnos 走资源路径解析，其余（Emby/Jellyfin）
  /// 走 /Items/{id}/Images 端点。
  factory MediaBrowserServerUrls({
    required MediaBrowserConfig config,
    required String baseUrl,
    String? token,
    String? cookie,
  }) {
    if (config.project == ServerProject.feiniu) {
      return _FeiniuServerUrls(baseUrl: baseUrl, token: token, cookie: cookie);
    }
    if (config.project == ServerProject.stash) {
      return _StashServerUrls(baseUrl: baseUrl, token: token);
    }
    return _EmbyJellyfinServerUrls(
      config: config,
      baseUrl: baseUrl,
      token: token,
    );
  }
}

/// Emby / Jellyfin：人物也是一条 Item，直接用
/// /Items/{personId}/Images/Primary 取头像。
class _EmbyJellyfinServerUrls extends MediaBrowserServerUrls {
  const _EmbyJellyfinServerUrls({
    required this.config,
    required super.baseUrl,
    super.token,
  }) : super._();

  final MediaBrowserConfig config;

  @override
  Map<String, String> get directHeaders => const <String, String>{};

  @override
  Map<String, String> get imageHeaders => const <String, String>{};

  @override
  String poster(String itemId, {int maxWidth = 440, String? tag}) =>
      MediaBrowserApi.imageUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        imageType: 'Primary',
        maxWidth: maxWidth,
        tag: tag,
      );

  @override
  String backdrop(String itemId, {int maxWidth = 1280, String? tag}) =>
      MediaBrowserApi.imageUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        imageType: 'Backdrop',
        maxWidth: maxWidth,
        tag: tag,
      );

  @override
  String thumb(String itemId, {int maxWidth = 440, String? tag}) =>
      MediaBrowserApi.imageUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        imageType: 'Thumb',
        maxWidth: maxWidth,
        tag: tag,
      );

  @override
  String authedPoster(String itemId, {int maxWidth = 600, String? tag}) =>
      MediaBrowserApi.imageUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        maxWidth: maxWidth,
        tag: tag,
        token: token,
      );

  @override
  String? personImage(MediaBrowserPerson person) {
    // People 条目自带 PrimaryImageTag；无 tag 说明无头像。
    final tag = person.primaryImageTag?.trim() ?? '';
    if (tag.isEmpty) return null;
    return MediaBrowserApi.imageUrl(
      config: config,
      baseUrl: baseUrl,
      itemId: person.id,
      maxWidth: 240,
      tag: tag,
    );
  }

  @override
  String stream(String itemId, {String? mediaSourceId}) =>
      MediaBrowserApi.streamUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        mediaSourceId: mediaSourceId,
        token: token,
      );

  @override
  String audioStream(String itemId, {String? mediaSourceId}) =>
      MediaBrowserApi.audioStreamUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        mediaSourceId: mediaSourceId,
        token: token,
      );
}

/// fnos（飞牛）：图片使用 sys/img 资源路径，宽度通过 w 查询参数传递；
/// 直链使用 media/range。
class _FeiniuServerUrls extends MediaBrowserServerUrls {
  const _FeiniuServerUrls({required super.baseUrl, super.token, super.cookie})
    : super._();

  @override
  Map<String, String> get directHeaders =>
      FeiniuApi.mediaHeaders(token, cookie);

  @override
  Map<String, String> get imageHeaders => directHeaders;

  String _asset(String? tag, {required int width}) =>
      FeiniuApi.resolveAssetUrl(baseUrl, tag, width: width);

  int _posterWidth(int width) => width == 440 ? 400 : width;

  @override
  String poster(String itemId, {int maxWidth = 440, String? tag}) =>
      _asset(tag, width: _posterWidth(maxWidth));

  @override
  String backdrop(String itemId, {int maxWidth = 1280, String? tag}) =>
      _asset(tag, width: maxWidth);

  @override
  String thumb(String itemId, {int maxWidth = 440, String? tag}) =>
      _asset(tag, width: _posterWidth(maxWidth));

  @override
  String authedPoster(String itemId, {int maxWidth = 600, String? tag}) =>
      _asset(tag, width: maxWidth);

  @override
  String? personImage(MediaBrowserPerson person) {
    final path = person.profilePath?.trim() ?? '';
    return path.isEmpty ? null : _asset(path, width: 240);
  }

  @override
  String stream(String itemId, {String? mediaSourceId}) =>
      FeiniuApi.mediaRangeUrl(baseUrl, mediaSourceId ?? itemId);

  @override
  String audioStream(String itemId, {String? mediaSourceId}) =>
      FeiniuApi.mediaRangeUrl(baseUrl, mediaSourceId ?? itemId);
}

/// Stash 的图片地址来自 ScenePaths，通常是相对服务器根地址的资源路径；
/// 图片和直链播放均通过 ApiKey 请求头鉴权。
class _StashServerUrls extends MediaBrowserServerUrls {
  const _StashServerUrls({required super.baseUrl, super.token}) : super._();

  @override
  Map<String, String> get directHeaders => _apiKeyHeaders;

  @override
  Map<String, String> get imageHeaders => _apiKeyHeaders;

  Map<String, String> get _apiKeyHeaders {
    final value = token?.trim() ?? '';
    return value.isEmpty ? const {} : {'ApiKey': value};
  }

  String _asset(String? path) {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri?.hasScheme == true && uri?.host.isNotEmpty == true) {
      return value;
    }
    return Uri.parse(baseUrl).resolve(value).toString();
  }

  @override
  String poster(String itemId, {int maxWidth = 440, String? tag}) =>
      _asset(tag);

  @override
  String backdrop(String itemId, {int maxWidth = 1280, String? tag}) =>
      _asset(tag);

  @override
  String thumb(String itemId, {int maxWidth = 440, String? tag}) => _asset(tag);

  @override
  String? preview(String? path) {
    final value = _asset(path);
    return value.isEmpty ? null : value;
  }

  @override
  String authedPoster(String itemId, {int maxWidth = 600, String? tag}) =>
      _asset(tag);

  @override
  String? personImage(MediaBrowserPerson person) => null;

  @override
  String stream(String itemId, {String? mediaSourceId}) =>
      _asset(mediaSourceId);

  @override
  String audioStream(String itemId, {String? mediaSourceId}) =>
      _asset(mediaSourceId);
}
