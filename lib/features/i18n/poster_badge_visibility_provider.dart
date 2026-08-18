import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

/// 影片详情页海报技术角标类型。
enum PosterBadgeKind {
  codec('编码'),
  hdr('HDR'),
  strm('STRM'),
  subtitle('字幕'),
  crack('破解'),
  resolution('HD / UHD');

  const PosterBadgeKind(this.label);

  final String label;
}

/// 影片详情页海报技术角标显示偏好。
@immutable
class PosterBadgeVisibility {
  const PosterBadgeVisibility({
    this.codec = true,
    this.hdr = true,
    this.strm = true,
    this.subtitle = true,
    this.crack = true,
    this.resolution = true,
  });

  final bool codec;
  final bool hdr;
  final bool strm;
  final bool subtitle;
  final bool crack;
  final bool resolution;

  bool isEnabled(PosterBadgeKind kind) {
    return switch (kind) {
      PosterBadgeKind.codec => codec,
      PosterBadgeKind.hdr => hdr,
      PosterBadgeKind.strm => strm,
      PosterBadgeKind.subtitle => subtitle,
      PosterBadgeKind.crack => crack,
      PosterBadgeKind.resolution => resolution,
    };
  }

  PosterBadgeVisibility copyWith({
    bool? codec,
    bool? hdr,
    bool? strm,
    bool? subtitle,
    bool? crack,
    bool? resolution,
  }) {
    return PosterBadgeVisibility(
      codec: codec ?? this.codec,
      hdr: hdr ?? this.hdr,
      strm: strm ?? this.strm,
      subtitle: subtitle ?? this.subtitle,
      crack: crack ?? this.crack,
      resolution: resolution ?? this.resolution,
    );
  }

  Map<String, dynamic> toJson() => {
        'codec': codec,
        'hdr': hdr,
        'strm': strm,
        'subtitle': subtitle,
        'crack': crack,
        'resolution': resolution,
      };

  factory PosterBadgeVisibility.fromJson(Map<String, dynamic> json) {
    return PosterBadgeVisibility(
      codec: json['codec'] != false,
      hdr: json['hdr'] != false,
      strm: json['strm'] != false,
      subtitle: json['subtitle'] != false,
      crack: json['crack'] != false,
      resolution: json['resolution'] != false,
    );
  }
}

class PosterBadgeVisibilityNotifier
    extends Notifier<PosterBadgeVisibility> {
  static const _key = 'app.posterBadgeVisibility';

  @override
  PosterBadgeVisibility build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null || raw.isEmpty) {
      return const PosterBadgeVisibility();
    }
    try {
      return PosterBadgeVisibility.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const PosterBadgeVisibility();
    }
  }

  Future<void> setEnabled(PosterBadgeKind kind, bool enabled) async {
    final next = switch (kind) {
      PosterBadgeKind.codec => state.copyWith(codec: enabled),
      PosterBadgeKind.hdr => state.copyWith(hdr: enabled),
      PosterBadgeKind.strm => state.copyWith(strm: enabled),
      PosterBadgeKind.subtitle => state.copyWith(subtitle: enabled),
      PosterBadgeKind.crack => state.copyWith(crack: enabled),
      PosterBadgeKind.resolution => state.copyWith(resolution: enabled),
    };
    state = next;
    await ref
        .read(sharedPrefsProvider)
        .setString(_key, jsonEncode(next.toJson()));
  }
}

final posterBadgeVisibilityProvider = NotifierProvider<
    PosterBadgeVisibilityNotifier, PosterBadgeVisibility>(
  PosterBadgeVisibilityNotifier.new,
);
