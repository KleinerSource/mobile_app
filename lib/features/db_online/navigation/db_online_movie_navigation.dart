import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';

/// 打开 dbonline 影片详情。
///
/// 推荐、最新列表和详情中的关联影片都经过同一入口，避免各页面对番号
/// 与 video_id 的回退规则产生差异。番号与 video_id 同时携带：同一番号
/// 在数据库中可能对应多条影片，video_id 用于服务端消歧，缺失时才会
/// 退化为纯番号匹配。
Future<void> openDbOnlineMovie(
  BuildContext context,
  DbOnlineMovie movie,
) async {
  final code = movie.number.trim();
  final videoId = movie.id.trim();
  if (code.isEmpty && videoId.isEmpty) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => code.isNotEmpty
          ? DbOnlineMovieDetailPage(
              code: code,
              videoId: videoId.isNotEmpty && videoId != code ? videoId : null,
            )
          : DbOnlineMovieDetailPage.byVideoId(videoId: videoId),
    ),
  );
}

/// 与页面按钮保持一致的非阻塞导航调用。
void openDbOnlineMovieUnawaited(BuildContext context, DbOnlineMovie movie) {
  unawaited(openDbOnlineMovie(context, movie));
}

/// dbonline 网页端影片详情地址，与网页端路由 `/video/:code` 一致：
/// `{base}/video/{code}?video_id={videoId}`。番号缺失或地址非法时返回
/// null，调用方应隐藏分享入口。
String? dbOnlineMovieWebUrl(
  ServerConfig? config, {
  required String code,
  String? videoId,
}) {
  final normalizedCode = code.trim();
  if (config == null || normalizedCode.isEmpty) return null;
  final base = Uri.tryParse(ServerConfig.normalize(config.baseUrl));
  if (base == null || !base.hasScheme || base.host.isEmpty) return null;
  final basePath = base.path == '/' ? '' : base.path;
  final normalizedVideoId = videoId?.trim() ?? '';
  return base
      .replace(
        path: '$basePath/video/${Uri.encodeComponent(normalizedCode)}',
        queryParameters: normalizedVideoId.isEmpty
            ? null
            : {'video_id': normalizedVideoId},
      )
      .toString();
}

/// 复制影片的网页端地址并提示。地址不可构造（无配置或无番号）时返回
/// false，调用方可以据此忽略本次操作。
Future<bool> copyDbOnlineMovieLink(
  BuildContext context, {
  ServerConfig? config,
  required String code,
  String? videoId,
}) async {
  final url = dbOnlineMovieWebUrl(config, code: code, videoId: videoId);
  if (url == null) return false;
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppL10n.of(context).dbOnlineLinkCopied(url)),
      ),
    );
  }
  return true;
}
