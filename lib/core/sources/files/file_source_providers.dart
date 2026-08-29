import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_session_repository.dart';
import '../../config/server_config_provider.dart';
import '../common/source_descriptor.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import 'file_source.dart';
import 'file_source_config.dart';
import 'file_entry.dart';
import 'file_source_repository.dart';
import 'openlist_api.dart';
import 'openlist_file_source.dart';
import 'smb_file_source.dart';
import 'webdav_file_source.dart';

final fileSourceConfigRepositoryProvider = Provider<FileSourceConfigRepository>(
  (ref) => FileSourceConfigRepository(ref.watch(sharedPrefsProvider)),
);

final fileSourceConfigsProvider = Provider<List<FileSourceConfig>>(
  (ref) => ref.watch(fileSourceConfigRepositoryProvider).loadAll(),
);

final fileSourceCredentialsRepositoryProvider =
    Provider<FileSourceCredentialsRepository>(
      (ref) => FileSourceCredentialsRepository(store: SecureAuthTokenStore()),
    );

final fileSourceRegistryProvider =
    FutureProvider.autoDispose<FileSourceRegistry>((ref) async {
      final activeServerId = ref.watch(serverConfigProvider)?.activeServerId;
      final configs = ref
          .watch(fileSourceConfigsProvider)
          .where((config) => config.serverId == activeServerId)
          .toList(growable: false);
      final credentials = ref.watch(fileSourceCredentialsRepositoryProvider);
      final registry = FileSourceRegistry(const []);
      ref.onDispose(() => unawaited(registry.dispose()));
      try {
        for (final config in configs.where((item) => item.enabled)) {
          registry.register(
            await FileSourceConnector(credentials).connect(config),
          );
        }
        return registry;
      } catch (_) {
        await registry.dispose();
        rethrow;
      }
    });

final fileSourceProvider = FutureProvider.autoDispose
    .family<FileSource?, String>((ref, sourceId) async {
      final registry = await ref.watch(fileSourceRegistryProvider.future);
      return registry.find(SourceId.of(sourceId));
    });

final fileSourceDescriptorsProvider = FutureProvider.autoDispose
    .family<List<SourceDescriptor>, String>((ref, serverId) async {
      final registry = await ref.watch(fileSourceRegistryProvider.future);
      _checkFileServerScope(ref, serverId);
      return registry.sources
          .map((source) => source.descriptor)
          .toList(growable: false);
    });

final fileSourceRepositoryProvider = FutureProvider.autoDispose
    .family<FileSourceRepository, String>((ref, sourceId) async {
      final source = await ref.watch(fileSourceProvider(sourceId).future);
      if (source == null) {
        throw const FileSourceException(
          '文件来源不存在或未连接',
          code: 'source_not_found',
        );
      }
      final repository = FileSourceRepository(source);
      return repository;
    });

class FileDirectoryRequest {
  const FileDirectoryRequest({
    required this.serverId,
    required this.sourceId,
    this.path = '',
  });

  final String serverId;
  final SourceId sourceId;
  final String path;

  @override
  bool operator ==(Object other) =>
      other is FileDirectoryRequest &&
      other.serverId == serverId &&
      other.sourceId == sourceId &&
      other.path == path;

  @override
  int get hashCode => Object.hash(serverId, sourceId, path);
}

final fileDirectoryProvider = FutureProvider.autoDispose
    .family<DirectoryListing, FileDirectoryRequest>((ref, request) async {
      _checkFileServerScope(ref, request.serverId);
      final repository = await ref.watch(
        fileSourceRepositoryProvider(request.sourceId.value).future,
      );
      // 下拉刷新前由页面置位（ref.read 而非 watch，避免标志复位触发重建），
      // 用于让 OpenList 等带服务端缓存的来源强制绕过缓存。
      final refresh = ref.read(
        fileDirectoryForceRefreshProvider(request.sourceId.value),
      );
      return repository.listDirectory(
        FilePath(sourceId: request.sourceId, value: request.path),
        refresh: refresh,
      );
    });

/// 目录强制刷新标志（按 sourceId）。页面在下拉刷新前置位，
/// [fileDirectoryProvider] 重新执行时读取一次。
final fileDirectoryForceRefreshProvider = StateProvider.family<bool, String>(
  (_, _) => false,
);

void _checkFileServerScope(Ref ref, String serverId) {
  final activeServerId = ref.read(serverConfigProvider)?.activeServerId ?? '';
  if (serverId != activeServerId) {
    throw const SourceException('文件请求已过期，请重新加载当前服务器');
  }
}

class FileSourceConnector {
  const FileSourceConnector(this.credentials);

  final FileSourceCredentialsRepository credentials;

  Future<FileSource> connect(FileSourceConfig config) async {
    if (!config.isValid) {
      throw const FileSourceException('文件来源配置无效', code: 'invalid_config');
    }
    final reference = config.credentialRef.trim();
    final secret =
        await credentials.read(reference) ?? const FileSourceCredentials();
    try {
      final FileSource source = switch (config.protocol) {
        FileSourceProtocol.smb => await SmbFileSource.connect(
          id: config.id,
          name: config.name,
          options: SmbConnectionOptions(
            host: config.host,
            port: config.port,
            path: config.path,
            user: secret.user,
            password: secret.password,
            domain: secret.domain,
            workers: config.smbWorkers,
            timeoutSeconds: (config.timeoutMilliseconds / 1000).ceil(),
          ),
          serverId: config.serverId,
        ),
        FileSourceProtocol.webDav => await WebDavFileSource.connect(
          id: config.id,
          name: config.name,
          options: WebDavConnectionOptions(
            uri: config.uri!,
            port: config.port,
            user: secret.user,
            password: secret.password,
            timeoutMilliseconds: config.timeoutMilliseconds,
          ),
          serverId: config.serverId,
        ),
        FileSourceProtocol.openList => await OpenListFileSource.connect(
          id: config.id,
          name: config.name,
          options: OpenListConnectionOptions(
            uri: config.uri!,
            port: config.port,
            path: config.path,
            user: secret.user,
            password: secret.password,
            timeoutMilliseconds: config.timeoutMilliseconds,
          ),
          serverId: config.serverId,
        ),
      };
      return source;
    } on SourceException {
      rethrow;
    } catch (error) {
      throw FileSourceException('文件来源连接失败', cause: error);
    }
  }
}
