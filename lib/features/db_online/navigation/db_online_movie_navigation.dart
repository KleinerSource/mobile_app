import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';

/// 详情双主键 key：video_id 优先，缺失时退化为番号。
String dbOnlineDetailKey(String? videoId, String? code) {
  final id = videoId?.trim() ?? '';
  if (id.isNotEmpty) return id;
  return code?.trim() ?? '';
}

/// 打开 dbonline 影片详情。
///
/// 推荐、最新列表和详情中的关联影片都经过同一入口，避免各页面对番号
/// 与 video_id 的回退规则产生差异。详情以 video_id 为主导，无 video_id
/// 的影片退化为番号，由服务端双主键解析。已浏览置灰由详情页自身按
/// detailKey（与卡片隐私键取值一致）记录。
Future<void> openDbOnlineMovie(
  BuildContext context,
  DbOnlineMovie movie,
) async {
  final key = dbOnlineDetailKey(movie.id, movie.number);
  if (key.isEmpty) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DbOnlineMovieDetailPage(detailKey: key),
    ),
  );
}

/// 与页面按钮保持一致的非阻塞导航调用。
void openDbOnlineMovieUnawaited(BuildContext context, DbOnlineMovie movie) {
  unawaited(openDbOnlineMovie(context, movie));
}

/// dbonline 网页端影片详情地址，与网页端路由 `/video/:videoId` 一致：
/// `{base}/video/{video_id}?code={code}`（video_id 主导，番号作辅助参数；
/// 无 video_id 时退化为 `{base}/video/{code}`）。番号与 video_id 均缺失
/// 或地址非法时返回 null，调用方应隐藏分享入口。
String? dbOnlineMovieWebUrl(
  ServerConfig? config, {
  required String code,
  String? videoId,
}) {
  final normalizedCode = code.trim();
  final normalizedVideoId = videoId?.trim() ?? '';
  if (config == null || (normalizedCode.isEmpty && normalizedVideoId.isEmpty)) {
    return null;
  }
  final base = Uri.tryParse(ServerConfig.normalize(config.baseUrl));
  if (base == null || !base.hasScheme || base.host.isEmpty) return null;
  final basePath = base.path == '/' ? '' : base.path;
  final key = normalizedVideoId.isNotEmpty ? normalizedVideoId : normalizedCode;
  return base
      .replace(
        path: '$basePath/video/${Uri.encodeComponent(key)}',
        queryParameters: normalizedVideoId.isEmpty || normalizedCode.isEmpty
            ? null
            : {'code': normalizedCode},
      )
      .toString();
}

/// 拉起系统分享面板，分享影片的网页端地址。地址不可构造（无配置或
/// 番号与 video_id 均缺失）时返回 false，调用方应隐藏分享入口。
Future<bool> shareDbOnlineMovieLink(
  BuildContext context, {
  ServerConfig? config,
  required String code,
  String? videoId,
}) async {
  final url = dbOnlineMovieWebUrl(config, code: code, videoId: videoId);
  if (url == null) return false;
  // iPad 的分享弹层要求锚点矩形，以触发入口的 RenderBox 为弹出原点。
  final renderObject = context.findRenderObject();
  final origin = renderObject is RenderBox
      ? renderObject.localToGlobal(Offset.zero) & renderObject.size
      : null;
  await SharePlus.instance.share(
    ShareParams(text: url, sharePositionOrigin: origin),
  );
  return true;
}
