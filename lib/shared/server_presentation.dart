import '../core/config/server_config.dart';
import '../core/api/server_compatibility.dart';
import '../core/models/system.dart';
import '../l10n/generated/app_localizations.dart';

String? resolveServerAvatarUrl({
  required ServerProfile server,
  required ServerProfileData? profile,
  required bool showUserAvatar,
}) {
  if (server.project == ServerProject.ohMyMedia) return null;
  final isMediaBrowser =
      server.project == ServerProject.emby ||
      server.project == ServerProject.jellyfin;
  final userAvatar = profile?.userAvatarUrl?.trim() ?? '';
  if (showUserAvatar && isMediaBrowser && userAvatar.isNotEmpty) {
    return userAvatar;
  }
  final serverAvatar = profile?.avatarUrl?.trim() ?? '';
  return serverAvatar.isNotEmpty ? serverAvatar : server.avatarUrl;
}

String serverProjectLabel(AppL10n l, ServerProject? project) {
  return switch (project) {
    ServerProject.ohMyMedia => 'Oh My Media',
    ServerProject.dbOnline => 'DB Online',
    ServerProject.emby => 'Emby',
    ServerProject.jellyfin => 'Jellyfin',
    ServerProject.feiniu => l.serverProjectFeiniu,
    ServerProject.stash => 'Stash',
    ServerProject.smb => 'SMB',
    ServerProject.webDav => 'WebDAV',
    ServerProject.openList => 'OpenList',
    null => l.serverProjectDefault,
  };
}
