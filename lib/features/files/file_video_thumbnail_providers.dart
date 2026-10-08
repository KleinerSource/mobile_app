import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/server_connection.dart';
import '../../core/sources/common/source_descriptor.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../core/sources/files/file_source_repository.dart';
import 'file_video_thumbnail_service.dart';

final fileVideoThumbnailServiceProvider = Provider<FileVideoThumbnailService>((
  ref,
) {
  final service = FileVideoThumbnailService(
    cache: AppFileVideoThumbnailCache(),
  );
  ref.onDispose(service.dispose);
  return service;
});

class FileVideoThumbnailSource {
  const FileVideoThumbnailSource(this.repository, this.lease, this.identity);
  final FileSourceRepository repository;
  final ServerConnectionLease lease;
  final String identity;
}

final fileVideoThumbnailSourceProvider = FutureProvider.autoDispose
    .family<FileVideoThumbnailSource?, String>((ref, sourceId) async {
      final connection = ref.watch(fileServerConnectionProvider);
      final lease = connection.lease;
      if (lease == null || !connection.accepts(lease.serverId)) return null;
      final repository = await ref.watch(
        fileSourceRepositoryProvider(sourceId).future,
      );
      if (!ref.mounted || !lease.isActive) return null;
      final kind = repository.source.descriptor.kind;
      if (kind != SourceKind.webDav && kind != SourceKind.smb) return null;
      final config = ref
          .read(fileSourceConfigRepositoryProvider)
          .find(sourceId);
      if (config == null || config.serverId != lease.serverId) return null;
      final credentials = await ref
          .read(fileSourceCredentialsRepositoryProvider)
          .read(config.credentialRef);
      if (!ref.mounted || !lease.isActive) return null;
      final identity = sha256
          .convert(
            utf8.encode(
              jsonEncode([
                config.serverId,
                config.id,
                config.protocol.name,
                config.host,
                config.port,
                config.path,
                config.uri,
                config.credentialRef,
                credentials?.user,
                credentials?.domain,
              ]),
            ),
          )
          .toString();
      return FileVideoThumbnailSource(repository, lease, identity);
    });
