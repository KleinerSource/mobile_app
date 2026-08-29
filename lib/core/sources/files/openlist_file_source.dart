import 'package:webdav_client/webdav_client.dart' as webdav;

import '../../platform/app_log_store.dart';
import '../common/source_descriptor.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import 'file_entry.dart';
import 'openlist_api.dart';
import 'webdav_file_source.dart';

/// OpenList（AList v3 兼容）文件源。
///
/// 文件管理完全复用 WebDAV：OpenList 在 `/dav` 暴露标准 WebDAV，
/// 浏览、传输、变更和访问全部继承 [WebDavFileSource]。REST API 只保留
/// 强制刷新——WebDAV 读取的是服务端缓存的目录，强制刷新先用
/// `/api/fs/list` 的 `refresh` 参数要求服务端绕过缓存重读后端存储，
/// 再走常规 WebDAV 列目录。
class OpenListFileSource extends WebDavFileSource {
  OpenListFileSource._({
    required super.client,
    required super.sourceId,
    required super.descriptor,
    required super.connection,
    required OpenListClient apiClient,
    required String apiRootPath,
  }) : _apiClient = apiClient,
       _apiRootPath = apiRootPath;

  final OpenListClient _apiClient;

  /// `/dav` 之内的根路径，用于把来源路径映射回实例内的 API 路径。
  final String _apiRootPath;

  static Future<OpenListFileSource> connect({
    required String id,
    required String name,
    required OpenListConnectionOptions options,
    String? serverId,
  }) async {
    final client = webdav.newClient(
      options.uri,
      user: options.user,
      password: options.password,
    );
    client.setConnectTimeout(options.timeoutMilliseconds);
    client.setSendTimeout(options.timeoutMilliseconds);
    client.setReceiveTimeout(options.timeoutMilliseconds);
    await client.ping();
    final apiClient = OpenListClient(options);
    try {
      await apiClient.ensureAuthenticated();
    } on OpenListException catch (error) {
      await apiClient.dispose();
      throw FileSourceException(
        'OpenList 连接失败：${error.message}',
        statusCode: 401,
        cause: error,
      );
    }
    final sourceId = SourceId.of(id);
    return OpenListFileSource._(
      client: client,
      sourceId: sourceId,
      descriptor: SourceDescriptor(
        id: sourceId,
        kind: SourceKind.openList,
        name: name,
        serverId: serverId,
        endpoint: options.uri,
      ),
      connection: WebDavConnectionOptions(
        uri: options.uri,
        port: options.port,
        user: options.user,
        password: options.password,
        timeoutMilliseconds: options.timeoutMilliseconds,
      ),
      apiClient: apiClient,
      apiRootPath: normalizeWebDavPath(options.path),
    );
  }

  @override
  Future<DirectoryListing> listDirectory(
    FilePath path, {
    bool refresh = false,
  }) async {
    if (refresh) {
      // 强制刷新是尽力而为的缓存失效：REST 通知失败时不阻塞浏览，
      // 后续 WebDAV 列目录照常执行。
      try {
        await _apiClient.refreshDirectory(
          _apiPath(normalizeWebDavPath(path.value)),
        );
      } catch (error) {
        appLog('[OpenListFileSource] 强制刷新 API 失败，降级为普通刷新: $error');
      }
    }
    return super.listDirectory(path);
  }

  String _apiPath(String value) {
    final root = _apiRootPath;
    if (root == '/') return value;
    return normalizeWebDavPath('$root${value == '/' ? '' : value}');
  }

  @override
  Future<void> dispose() async {
    await _apiClient.dispose();
    await super.dispose();
  }
}
