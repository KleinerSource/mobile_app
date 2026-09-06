import 'package:omm/core/api/server_compatibility.dart';

/// Emby / Jellyfin（MediaBrowser 协议）的服务器差异配置。
///
/// 两家服务器的接口同构，差异全部收敛在这里：路径前缀、登录身份头、
/// 图片与原生流的 token 查询参数名、Emby 兼容 token 参数，以及是否存在按 token
/// 反查用户的 /Users/Me 端点。
class MediaBrowserConfig {
  const MediaBrowserConfig({
    required this.project,
    required this.pathPrefix,
    required this.authHeaderName,
    required this.tokenQueryParam,
    required this.streamStaticQueryParam,
    this.streamTokenQueryParam,
    this.secondaryTokenQueryParam,
    required this.sourceId,
    required this.brandLabel,
    required this.displayName,
    required this.supportsCurrentUser,
  });

  final ServerProject project;

  /// 接口路径前缀：Emby 挂在 /emby 下，Jellyfin 用根路径。
  final String pathPrefix;

  /// 登录请求声明客户端身份的头名；头的值两家相同（MediaBrowser ...）。
  final String authHeaderName;

  /// 图片内核无法带请求头时的 token 查询参数名。
  ///
  /// Emby 用 api_key；Jellyfin 用 ApiKey（小写 api_key 自 Jellyfin 12 起
  /// 默认禁用）。
  final String tokenQueryParam;

  /// 原生流端点使用的 static 查询参数名。Emby 要求使用 `Static`，
  /// Jellyfin 原生流也使用 `Static`。
  final String streamStaticQueryParam;

  /// 原生流端点的主要 token 查询参数名；为空时复用 [tokenQueryParam]。
  /// Jellyfin 图片使用 `ApiKey`，原生流使用 `api_key`。
  final String? streamTokenQueryParam;

  /// 原生流端点需要的兼容 token 参数；Emby 与 Jellyfin 当前都拼接
  /// `X-Emby-Token`。
  final String? secondaryTokenQueryParam;

  Map<String, String> streamTokenQueryParameters(String token) {
    final value = token.trim();
    if (value.isEmpty) return const <String, String>{};
    final streamTokenName = streamTokenQueryParam?.trim();
    final primaryName = streamTokenName == null || streamTokenName.isEmpty
        ? tokenQueryParam
        : streamTokenName;
    return {
      primaryName: value,
      if (secondaryTokenQueryParam?.trim().isNotEmpty == true)
        secondaryTokenQueryParam!: value,
    };
  }

  /// 媒体源注册表里的 SourceId：'emby' / 'jellyfin'。
  final String sourceId;

  /// 页面 eyebrow 品牌标签：'EMBY' / 'JELLYFIN'。
  final String brandLabel;

  /// 错误文案里的服务器显示名。
  final String displayName;

  /// 是否支持 /Users/Me（按 token 反查用户）。
  ///
  /// Jellyfin 支持；Emby 实测返回 500，只能按持久化用户 ID 查
  /// /Users/{Id}。
  final bool supportsCurrentUser;

  String path(String relative) => '$pathPrefix$relative';

  /// 按服务器项目取配置；非 MediaBrowser 项目返回 null。
  static const Map<ServerProject, MediaBrowserConfig> byProject = {
    ServerProject.emby: emby,
    ServerProject.jellyfin: jellyfin,
    ServerProject.feiniu: feiniu,
    ServerProject.stash: stash,
  };

  static const emby = MediaBrowserConfig(
    project: ServerProject.emby,
    pathPrefix: '/emby',
    authHeaderName: 'X-Emby-Authorization',
    tokenQueryParam: 'api_key',
    streamStaticQueryParam: 'Static',
    secondaryTokenQueryParam: 'X-Emby-Token',
    sourceId: 'emby',
    brandLabel: 'EMBY',
    displayName: 'Emby',
    supportsCurrentUser: false,
  );

  static const jellyfin = MediaBrowserConfig(
    project: ServerProject.jellyfin,
    pathPrefix: '',
    authHeaderName: 'Authorization',
    tokenQueryParam: 'ApiKey',
    streamStaticQueryParam: 'Static',
    streamTokenQueryParam: 'api_key',
    secondaryTokenQueryParam: 'X-Emby-Token',
    sourceId: 'jellyfin',
    brandLabel: 'JELLYFIN',
    displayName: 'Jellyfin',
    supportsCurrentUser: true,
  );

  static const feiniu = MediaBrowserConfig(
    project: ServerProject.feiniu,
    pathPrefix: '/v',
    authHeaderName: 'Authorization',
    tokenQueryParam: 'token',
    streamStaticQueryParam: 'static',
    sourceId: 'feiniu',
    brandLabel: 'FEINIU',
    displayName: '飞牛影视',
    supportsCurrentUser: true,
  );

  static const stash = MediaBrowserConfig(
    project: ServerProject.stash,
    pathPrefix: '',
    authHeaderName: 'ApiKey',
    tokenQueryParam: 'ApiKey',
    streamStaticQueryParam: 'static',
    sourceId: 'stash',
    brandLabel: 'STASH',
    displayName: 'Stash',
    supportsCurrentUser: false,
  );
}
