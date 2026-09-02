import 'package:flutter/foundation.dart';

import 'source_id.dart';

enum SourceKind { omm, dbo, emby, jellyfin, feiniu, smb, webDav, openList }

@immutable
class SourceDescriptor {
  const SourceDescriptor({
    required this.id,
    required this.kind,
    required this.name,
    this.serverId,
    this.endpoint,
  });

  final SourceId id;
  final SourceKind kind;
  final String name;
  final String? serverId;
  final String? endpoint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceDescriptor &&
          other.id == id &&
          other.kind == kind &&
          other.name == name &&
          other.serverId == serverId &&
          other.endpoint == endpoint;

  @override
  int get hashCode => Object.hash(id, kind, name, serverId, endpoint);
}
