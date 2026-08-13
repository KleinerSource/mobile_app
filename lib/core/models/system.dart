import 'package:flutter/foundation.dart';

@immutable
class ServerProfileData {
  const ServerProfileData({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  factory ServerProfileData.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    final avatar = json['avatar_url']?.toString().trim() ?? '';
    return ServerProfileData(
      name: name,
      avatarUrl: avatar.isEmpty ? null : avatar,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (avatarUrl != null && avatarUrl!.isNotEmpty)
          'avatar_url': avatarUrl,
      };
}

@immutable
class ScheduleStatus {
  const ScheduleStatus({
    required this.enabled,
    required this.times,
    this.nextRunAt,
    this.lastFiredAt,
    this.lastSkippedReason = '',
  });

  final bool enabled;
  final List<String> times;
  final DateTime? nextRunAt;
  final DateTime? lastFiredAt;
  final String lastSkippedReason;

  factory ScheduleStatus.fromJson(Map<String, dynamic> json) => ScheduleStatus(
        enabled: json['enabled'] == true,
        times: json['times'] is List
            ? (json['times'] as List).map((e) => e.toString()).toList()
            : const [],
        nextRunAt: _date(json['next_run_at']),
        lastFiredAt: _date(json['last_fired_at']),
        lastSkippedReason: json['last_skipped_reason']?.toString() ?? '',
      );
}

@immutable
class Downloader {
  const Downloader({
    required this.name,
    required this.displayName,
    this.enabled = true,
    this.capabilities = const {},
  });

  final String name;
  final String displayName;
  final bool enabled;
  final Map<String, dynamic> capabilities;

  factory Downloader.fromJson(Map<String, dynamic> json) => Downloader(
        name: json['name']?.toString() ?? '',
        displayName:
            json['display_name']?.toString() ?? json['name']?.toString() ?? '',
        enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
        capabilities: json['capabilities'] is Map
            ? Map<String, dynamic>.from(json['capabilities'] as Map)
            : const {},
      );
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());
