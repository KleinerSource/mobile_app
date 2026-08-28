import 'package:omm/core/models/actor.dart';

/// 演员列表折叠子行的关联成员。仅展示名称，不携带影片数。
class ActorAssociationMember {
  const ActorAssociationMember({
    required this.id,
    required this.name,
    this.biography,
    this.avatarPaths,
  });

  final int id;
  final String name;
  final String? biography;

  /// 后端 avatar_path 数组(按序多张头像)
  final List<String>? avatarPaths;

  static ActorAssociationMember? tryParse(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    final name = (json['name'] as String?)?.trim() ?? '';
    if (id == null || name.isEmpty) return null;
    final pathsRaw = json['avatar_path'];
    return ActorAssociationMember(
      id: id,
      name: name,
      biography: json['biography'] as String?,
      avatarPaths: pathsRaw is List
          ? [for (final e in pathsRaw.whereType<String>()) e]
          : null,
    );
  }

  /// 子行的编辑/删除复用主行流程，需要转成 ActorItem。
  ActorItem get asActorItem => ActorItem(
    id: id,
    name: name,
    biography: biography,
    avatarPaths: avatarPaths,
  );
}

/// 演员管理列表行：主演员 + 折叠的关联成员（collapse_associations 响应）。
class ActorRow {
  const ActorRow({
    required this.actor,
    this.members = const <ActorAssociationMember>[],
  });

  final ActorItem actor;
  final List<ActorAssociationMember> members;

  int get id => actor.id;
  bool get hasMembers => members.isNotEmpty;

  /// 从 /actors 列表响应中解析主行与各自行携带的 association_members。
  /// raw 为接口原始 envelope（含 data 数组），items 为已解析的 ActorItem。
  static List<ActorRow> parseRows(Object? raw, List<ActorItem> items) {
    final membersByActorId = <int, List<ActorAssociationMember>>{};
    if (raw is Map && raw['data'] is List) {
      for (final entry in (raw['data']! as List).whereType<Map>()) {
        final map = Map<String, dynamic>.from(entry);
        final id = (map['id'] as num?)?.toInt();
        final membersRaw = map['association_members'];
        if (id == null || membersRaw is! List) continue;
        final members = <ActorAssociationMember>[];
        for (final item in membersRaw.whereType<Map>()) {
          final member = ActorAssociationMember.tryParse(
            Map<String, dynamic>.from(item),
          );
          if (member != null) members.add(member);
        }
        if (members.isNotEmpty) membersByActorId[id] = members;
      }
    }
    return [
      for (final actor in items)
        ActorRow(
          actor: actor,
          members:
              membersByActorId[actor.id] ?? const <ActorAssociationMember>[],
        ),
    ];
  }
}
