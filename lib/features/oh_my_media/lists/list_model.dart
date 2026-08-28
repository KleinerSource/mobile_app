import 'dart:convert';

import 'package:omm/core/platform/app_theme.dart';

/// 本地虚拟集合 · 仅客户端存 (SharedPreferences)
class FavoriteList {
  FavoriteList({
    required this.id,
    required this.name,
    required this.hue,
    this.builtin = false,
    this.locked = false,
    List<int>? movieIds,
  }) : movieIds = movieIds ?? <int>[];

  final String id;
  String name;
  int hue;
  final bool builtin;

  /// After Hours 隐私 list · 启用后需 PIN 解锁才可见
  bool locked;
  List<int> movieIds;

  int get count => movieIds.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hue': hue,
    'builtin': builtin,
    'locked': locked,
    'movie_ids': movieIds,
  };

  static FavoriteList fromJson(Map<String, dynamic> j) => FavoriteList(
    id: j['id'] as String,
    name: j['name'] as String,
    hue: (j['hue'] as num?)?.toInt() ?? AppHues.lavender,
    builtin: j['builtin'] == true,
    locked: j['locked'] == true,
    movieIds: ((j['movie_ids'] as List?) ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList(),
  );

  FavoriteList copy() => FavoriteList(
    id: id,
    name: name,
    hue: hue,
    builtin: builtin,
    locked: locked,
    movieIds: List<int>.from(movieIds),
  );

  static List<FavoriteList> defaults() => [
    FavoriteList(
      id: 'all_time_best',
      name: '最爱',
      hue: AppHues.coral,
      builtin: true,
    ),
    FavoriteList(
      id: 'after_hours',
      name: '私藏',
      hue: AppHues.sky,
      builtin: true,
      locked: true,
    ),
  ];

  static String encodeAll(List<FavoriteList> lists) =>
      jsonEncode(lists.map((l) => l.toJson()).toList());

  static List<FavoriteList> decodeAll(String raw) {
    final list = jsonDecode(raw);
    if (list is! List) return defaults();
    return list
        .whereType<Map>()
        .map((m) => FavoriteList.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}
