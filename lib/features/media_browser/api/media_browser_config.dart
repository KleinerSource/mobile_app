import 'package:omm/core/api/server_compatibility.dart';

/// Emby / Jellyfin（MediaBrowser 协议）的服务器差异配置。
///
/// 两家服务器的接口同构，差异全部收敛在这里：路径前缀、登录身份头、
/// 无头内核的 token 查询参数名，以及是否存在按 token 反查用户的
/// /Users/Me 端点。
class MediaBrowserConfig {
  const MediaBrowserConfig({
    required this.project,
    required this.pathPrefix,
    required this.authHeaderName,
    required this.tokenQueryParam,
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

  /// 播放器 / 图片内核无法带请求头时的 token 查询参数名。
  ///
  /// Emby 用 api_key；Jellyfin 用 ApiKey（小写 api_key 自 Jellyfin 12 起
  /// 默认禁用）。
  final String tokenQueryParam;

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
  };

  static const emby = MediaBrowserConfig(
    project: ServerProject.emby,
    pathPrefix: '/emby',
    authHeaderName: 'X-Emby-Authorization',
    tokenQueryParam: 'api_key',
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
    sourceId: 'jellyfin',
    brandLabel: 'JELLYFIN',
    displayName: 'Jellyfin',
    supportsCurrentUser: true,
  );
}
