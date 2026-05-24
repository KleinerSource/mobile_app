import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

/// 海报上 badge 的目标角
enum BadgeCorner {
  topLeft(value: 'tl', label: '左上'),
  topRight(value: 'tr', label: '右上'),
  bottomLeft(value: 'bl', label: '左下'),
  bottomRight(value: 'br', label: '右下');

  const BadgeCorner({required this.value, required this.label});
  final String value;
  final String label;

  static BadgeCorner fromValue(String? v, BadgeCorner fallback) {
    return BadgeCorner.values.firstWhere(
      (e) => e.value == v,
      orElse: () => fallback,
    );
  }
}

/// 哪种 badge
enum BadgeKind { rating, subtitle, crack, resolution }

@immutable
class BadgePositions {
  const BadgePositions({
    this.rating = BadgeCorner.topRight,
    this.subtitle = BadgeCorner.bottomLeft,
    this.crack = BadgeCorner.bottomLeft,
    this.resolution = BadgeCorner.bottomLeft,
    this.ratingEnabled = true,
    this.subtitleEnabled = true,
    this.crackEnabled = true,
    this.resolutionEnabled = true,
    this.horizontalOffset = 0,
    this.verticalOffset = 0,
  });

  final BadgeCorner rating;
  final BadgeCorner subtitle;
  final BadgeCorner crack;
  final BadgeCorner resolution;
  final bool ratingEnabled;
  final bool subtitleEnabled;
  final bool crackEnabled;
  final bool resolutionEnabled;

  /// 统一左右微调 (-16 ~ 16): 正数往内推
  final int horizontalOffset;

  /// 统一上下微调 (-16 ~ 16): 正数往内推
  final int verticalOffset;

  BadgeCorner of(BadgeKind k) {
    switch (k) {
      case BadgeKind.rating:
        return rating;
      case BadgeKind.subtitle:
        return subtitle;
      case BadgeKind.crack:
        return crack;
      case BadgeKind.resolution:
        return resolution;
    }
  }

  bool isEnabled(BadgeKind k) {
    switch (k) {
      case BadgeKind.rating:
        return ratingEnabled;
      case BadgeKind.subtitle:
        return subtitleEnabled;
      case BadgeKind.crack:
        return crackEnabled;
      case BadgeKind.resolution:
        return resolutionEnabled;
    }
  }

  BadgePositions copyWith({
    BadgeCorner? rating,
    BadgeCorner? subtitle,
    BadgeCorner? crack,
    BadgeCorner? resolution,
    bool? ratingEnabled,
    bool? subtitleEnabled,
    bool? crackEnabled,
    bool? resolutionEnabled,
    int? horizontalOffset,
    int? verticalOffset,
  }) =>
      BadgePositions(
        rating: rating ?? this.rating,
        subtitle: subtitle ?? this.subtitle,
        crack: crack ?? this.crack,
        resolution: resolution ?? this.resolution,
        ratingEnabled: ratingEnabled ?? this.ratingEnabled,
        subtitleEnabled: subtitleEnabled ?? this.subtitleEnabled,
        crackEnabled: crackEnabled ?? this.crackEnabled,
        resolutionEnabled: resolutionEnabled ?? this.resolutionEnabled,
        horizontalOffset: horizontalOffset ?? this.horizontalOffset,
        verticalOffset: verticalOffset ?? this.verticalOffset,
      );

  Map<String, dynamic> toJson() => {
        'rating': rating.value,
        'subtitle': subtitle.value,
        'crack': crack.value,
        'resolution': resolution.value,
        'ratingEnabled': ratingEnabled,
        'subtitleEnabled': subtitleEnabled,
        'crackEnabled': crackEnabled,
        'resolutionEnabled': resolutionEnabled,
        'horizontalOffset': horizontalOffset,
        'verticalOffset': verticalOffset,
      };

  factory BadgePositions.fromJson(Map<String, dynamic> j) => BadgePositions(
        rating: BadgeCorner.fromValue(
            j['rating'] as String?, BadgeCorner.topRight),
        subtitle: BadgeCorner.fromValue(
            j['subtitle'] as String?, BadgeCorner.bottomLeft),
        crack: BadgeCorner.fromValue(
            j['crack'] as String?, BadgeCorner.bottomLeft),
        resolution: BadgeCorner.fromValue(
            j['resolution'] as String?, BadgeCorner.bottomLeft),
        ratingEnabled: j['ratingEnabled'] != false,
        subtitleEnabled: j['subtitleEnabled'] != false,
        crackEnabled: j['crackEnabled'] != false,
        resolutionEnabled: j['resolutionEnabled'] != false,
        horizontalOffset: (j['horizontalOffset'] as num?)?.toInt() ?? 0,
        verticalOffset: (j['verticalOffset'] as num?)?.toInt() ?? 0,
      );
}

class BadgePositionsNotifier extends Notifier<BadgePositions> {
  static const _key = 'app.badgePositions';

  @override
  BadgePositions build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const BadgePositions();
    try {
      return BadgePositions.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const BadgePositions();
    }
  }

  Future<void> _persist(BadgePositions next) async {
    state = next;
    await ref
        .read(sharedPrefsProvider)
        .setString(_key, jsonEncode(next.toJson()));
  }

  Future<void> setKind(BadgeKind k, BadgeCorner v) async {
    final next = switch (k) {
      BadgeKind.rating => state.copyWith(rating: v),
      BadgeKind.subtitle => state.copyWith(subtitle: v),
      BadgeKind.crack => state.copyWith(crack: v),
      BadgeKind.resolution => state.copyWith(resolution: v),
    };
    await _persist(next);
  }

  Future<void> setEnabled(BadgeKind k, bool enabled) async {
    final next = switch (k) {
      BadgeKind.rating => state.copyWith(ratingEnabled: enabled),
      BadgeKind.subtitle => state.copyWith(subtitleEnabled: enabled),
      BadgeKind.crack => state.copyWith(crackEnabled: enabled),
      BadgeKind.resolution => state.copyWith(resolutionEnabled: enabled),
    };
    await _persist(next);
  }

  Future<void> setHorizontalOffset(int v) async {
    await _persist(state.copyWith(horizontalOffset: v.clamp(-16, 16)));
  }

  Future<void> setVerticalOffset(int v) async {
    await _persist(state.copyWith(verticalOffset: v.clamp(-16, 16)));
  }
}

final badgePositionsProvider =
    NotifierProvider<BadgePositionsNotifier, BadgePositions>(
        BadgePositionsNotifier.new);
