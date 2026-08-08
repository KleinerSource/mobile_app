import 'package:flutter/foundation.dart';

@immutable
class AvdbConfig {
  const AvdbConfig({
    this.enabled = false,
    this.baseUrl = '',
    this.apiKey = '',
  });

  final bool enabled;
  final String baseUrl;
  final String apiKey;

  factory AvdbConfig.fromJson(Map<String, dynamic> json) => AvdbConfig(
        enabled: json['enabled'] == true,
        baseUrl: json['base_url']?.toString() ?? '',
        apiKey: json['api_key']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'base_url': baseUrl,
        'api_key': apiKey,
      };

  bool get hasApiKey => apiKey.trim().isNotEmpty;
}
