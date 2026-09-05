import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

/// 海报上 badge 的目标角
enum BadgeCorner {
  topLeft(value: 'tl'),
  topRight(value: 'tr'),
  bottomLeft(value: 'bl'),
  bottomRight(value: 'br');

  const BadgeCorner({required this.value});
  final String value;

  static BadgeCorner fromValue(String? v, BadgeCorner fallback) {
    return BadgeCorner.values.firstWhere(
      (e) => e.value == v,
      orElse: () => fallback,
    );
  }
}

/// 哪种 badge
enum BadgeKind { rating, content, newResources }

@immutable
class BadgeCornerOffset {
  const BadgeCornerOffset({this.horizontal = 0, this.vertical = 0});

  final int horizontal;
  final int vertical;

  BadgeCornerOffset copyWith({int? horizontal, int? vertical}) =>
      BadgeCornerOffset(
        horizontal: horizontal ?? this.horizontal,
        vertical: vertical ?? this.vertical,
      );

  Map<String, dynamic> toJson() => {
    'horizontal': horizontal,
    'vertical': vertical,
  };

  factory BadgeCornerOffset.fromJson(
    dynamic raw, [
    BadgeCornerOffset fallback = const BadgeCornerOffset(),
  ]) {
    if (raw is! Map) return fallback;
    return BadgeCornerOffset(
      horizontal: (raw['horizontal'] as num?)?.toInt() ?? fallback.horizontal,
      vertical: (raw['vertical'] as num?)?.toInt() ?? fallback.vertical,
    );
  }
}

@immutable
class BadgePositions {
  const BadgePositions({
    this.rating = BadgeCorner.topRight,
    this.contentBadge = BadgeCorner.bottomLeft,
    this.newResources = BadgeCorner.topRight,
    this.ratingEnabled = true,
    this.contentBadgeEnabled = true,
    this.newResourcesEnabled = true,
    this.topLeftOffset = const BadgeCornerOffset(),
    this.topRightOffset = const BadgeCornerOffset(),
    this.bottomLeftOffset = const BadgeCornerOffset(),
    this.bottomRightOffset = const BadgeCornerOffset(),
  });

  final BadgeCorner rating;
  final BadgeCorner contentBadge;
  final BadgeCorner newResources;
  final bool ratingEnabled;
  final bool contentBadgeEnabled;
  final bool newResourcesEnabled;

  final BadgeCornerOffset topLeftOffset;
  final BadgeCornerOffset topRightOffset;
  final BadgeCornerOffset bottomLeftOffset;
  final BadgeCornerOffset bottomRightOffset;

  BadgeCorner of(BadgeKind k) {
    switch (k) {
      case BadgeKind.rating:
        return rating;
      case BadgeKind.content:
        return contentBadge;
      case BadgeKind.newResources:
        return newResources;
    }
  }

  bool isEnabled(BadgeKind k) {
    switch (k) {
      case BadgeKind.rating:
        return ratingEnabled;
      case BadgeKind.content:
        return contentBadgeEnabled;
      case BadgeKind.newResources:
        return newResourcesEnabled;
    }
  }

  BadgeCornerOffset offsetOf(BadgeCorner corner) {
    switch (corner) {
      case BadgeCorner.topLeft:
        return topLeftOffset;
      case BadgeCorner.topRight:
        return topRightOffset;
      case BadgeCorner.bottomLeft:
        return bottomLeftOffset;
      case BadgeCorner.bottomRight:
        return bottomRightOffset;
    }
  }

  BadgePositions copyWith({
    BadgeCorner? rating,
    BadgeCorner? contentBadge,
    BadgeCorner? newResources,
    bool? ratingEnabled,
    bool? contentBadgeEnabled,
    bool? newResourcesEnabled,
    BadgeCornerOffset? topLeftOffset,
    BadgeCornerOffset? topRightOffset,
    BadgeCornerOffset? bottomLeftOffset,
    BadgeCornerOffset? bottomRightOffset,
  }) => BadgePositions(
    rating: rating ?? this.rating,
    contentBadge: contentBadge ?? this.contentBadge,
    newResources: newResources ?? this.newResources,
    ratingEnabled: ratingEnabled ?? this.ratingEnabled,
    contentBadgeEnabled: contentBadgeEnabled ?? this.contentBadgeEnabled,
    newResourcesEnabled: newResourcesEnabled ?? this.newResourcesEnabled,
    topLeftOffset: topLeftOffset ?? this.topLeftOffset,
    topRightOffset: topRightOffset ?? this.topRightOffset,
    bottomLeftOffset: bottomLeftOffset ?? this.bottomLeftOffset,
    bottomRightOffset: bottomRightOffset ?? this.bottomRightOffset,
  );

  Map<String, dynamic> toJson() => {
    'rating': rating.value,
    'contentBadge': contentBadge.value,
    'newResources': newResources.value,
    'ratingEnabled': ratingEnabled,
    'contentBadgeEnabled': contentBadgeEnabled,
    'newResourcesEnabled': newResourcesEnabled,
    'cornerOffsets': {
      for (final corner in BadgeCorner.values)
        corner.value: offsetOf(corner).toJson(),
    },
  };

  factory BadgePositions.fromJson(Map<String, dynamic> j) {
    final rawOffsets = j['cornerOffsets'];

    BadgeCornerOffset readOffset(BadgeCorner corner) {
      final raw = rawOffsets is Map ? rawOffsets[corner.value] : null;
      return BadgeCornerOffset.fromJson(raw);
    }

    return BadgePositions(
      rating: BadgeCorner.fromValue(
        j['rating'] as String?,
        BadgeCorner.topRight,
      ),
      contentBadge: BadgeCorner.fromValue(
        j['contentBadge'] as String?,
        BadgeCorner.bottomLeft,
      ),
      newResources: BadgeCorner.fromValue(
        j['newResources'] as String?,
        BadgeCorner.topRight,
      ),
      ratingEnabled: j['ratingEnabled'] != false,
      contentBadgeEnabled: j['contentBadgeEnabled'] != false,
      newResourcesEnabled: j['newResourcesEnabled'] != false,
      topLeftOffset: readOffset(BadgeCorner.topLeft),
      topRightOffset: readOffset(BadgeCorner.topRight),
      bottomLeftOffset: readOffset(BadgeCorner.bottomLeft),
      bottomRightOffset: readOffset(BadgeCorner.bottomRight),
    );
  }
}

class BadgePositionsNotifier extends Notifier<BadgePositions> {
  static const _key = 'app.badgePositions';

  @override
  BadgePositions build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const BadgePositions();
    try {
      return BadgePositions.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
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
      BadgeKind.content => state.copyWith(contentBadge: v),
      BadgeKind.newResources => state.copyWith(newResources: v),
    };
    await _persist(next);
  }

  Future<void> setEnabled(BadgeKind k, bool enabled) async {
    final next = switch (k) {
      BadgeKind.rating => state.copyWith(ratingEnabled: enabled),
      BadgeKind.content => state.copyWith(contentBadgeEnabled: enabled),
      BadgeKind.newResources => state.copyWith(newResourcesEnabled: enabled),
    };
    await _persist(next);
  }

  Future<void> setContentBadgePosition(BadgeCorner corner) async {
    await _persist(state.copyWith(contentBadge: corner));
  }

  Future<void> setContentBadgeEnabled(bool enabled) async {
    await _persist(state.copyWith(contentBadgeEnabled: enabled));
  }

  Future<void> setHorizontalOffset(BadgeCorner corner, int v) async {
    final offset = state.offsetOf(corner);
    final nextOffset = offset.copyWith(horizontal: v.clamp(-16, 16));
    await _persist(_withOffset(state, corner, nextOffset));
  }

  Future<void> setVerticalOffset(BadgeCorner corner, int v) async {
    final offset = state.offsetOf(corner);
    final nextOffset = offset.copyWith(vertical: v.clamp(-16, 16));
    await _persist(_withOffset(state, corner, nextOffset));
  }

  BadgePositions _withOffset(
    BadgePositions positions,
    BadgeCorner corner,
    BadgeCornerOffset offset,
  ) {
    return switch (corner) {
      BadgeCorner.topLeft => positions.copyWith(topLeftOffset: offset),
      BadgeCorner.topRight => positions.copyWith(topRightOffset: offset),
      BadgeCorner.bottomLeft => positions.copyWith(bottomLeftOffset: offset),
      BadgeCorner.bottomRight => positions.copyWith(bottomRightOffset: offset),
    };
  }
}

final badgePositionsProvider =
    NotifierProvider<BadgePositionsNotifier, BadgePositions>(
      BadgePositionsNotifier.new,
    );
