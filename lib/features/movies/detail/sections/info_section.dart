import 'package:flutter/material.dart';

import '../../../../core/models/movie.dart';
import '../../../../core/ui/tokens.dart';
import '../widgets/info_item_row.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (movie.num != null && movie.num!.isNotEmpty) {
      rows.add(InfoItemRow(icon: Icons.qr_code, label: '番号', value: movie.num!));
    }
    if (movie.year != null) {
      rows.add(InfoItemRow(icon: Icons.calendar_today, label: '年份', value: '${movie.year}'));
    }
    if (movie.rating != null && movie.rating! > 0) {
      rows.add(InfoItemRow(
          icon: Icons.star, label: '评分', value: movie.rating!.toStringAsFixed(1)));
    }
    if (movie.runtime != null && movie.runtime! > 0) {
      rows.add(InfoItemRow(
          icon: Icons.schedule, label: '时长', value: _formatRuntime(movie.runtime!)));
    }
    if (movie.country != null && movie.country!.isNotEmpty) {
      rows.add(InfoItemRow(icon: Icons.public, label: '国家', value: movie.country!));
    }
    final size = movie.fileSize;
    if (size != null && size > 0) {
      rows.add(InfoItemRow(icon: Icons.storage, label: '大小', value: _formatFileSize(size)));
    }
    if (movie.lastDownloadedAt != null && movie.lastDownloadedAt!.isNotEmpty) {
      rows.add(InfoItemRow(
          icon: Icons.cloud_download,
          label: '最近下载',
          value: _formatDate(movie.lastDownloadedAt!)));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }

  String _formatRuntime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '$h 小时 $m 分钟';
    return '$m 分钟';
  }

  String _formatFileSize(int size) {
    if (size >= 1073741824) return '${(size / 1073741824).toStringAsFixed(1)} GB';
    if (size >= 1048576) return '${(size / 1048576).round()} MB';
    if (size >= 1024) return '${(size / 1024).round()} KB';
    return '$size B';
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
