import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/models/resource.dart';
import '../../core/models/actor.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/filter_chip.dart';
import '../../shared/poster.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/favorites_providers.dart';
import '../lists/add_to_list_sheet.dart';
import '../movies/movies_providers.dart';
import '../player/player_page.dart';
import '../player/player_queue.dart';
import '../resources/resource_movies_page.dart';
import 'actor_movies_page.dart';
import 'dbo_diff_sheet.dart';
import 'resources_sheet.dart';
import '../resources/resources_repository.dart';
import 'movie_editor_sheet.dart';
import 'thunder_subtitle_sheet.dart';

class MovieDetailPage extends ConsumerWidget {
  const MovieDetailPage({super.key, required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(movieDetailProvider(movieId));
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final c = appColors(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败', style: AppText.sectionTitle(context)),
                const SizedBox(height: 8),
                Text('$e', style: AppText.body(context), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (movie) => _DetailBody(
          movie: movie,
          urlBuilder: urlBuilder,
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.movie, required this.urlBuilder});
  final MovieDetail movie;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final favStatus = ref.watch(favoriteStatusProvider);
    // 初始化收藏状态种子
    if (!favStatus.containsKey(movie.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(favoriteStatusProvider.notifier).seed(movie.id, movie.isFavorited);
      });
    }
    final isFavorited = favStatus[movie.id] ?? movie.isFavorited;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 18),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: isFavorited ? c.accent : null,
                ),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final l = AppL10n.of(context);
                try {
                  final value = await ref
                      .read(favoriteStatusProvider.notifier)
                      .toggle(movie.id);
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                        value ? l.detailFavorited : l.detailUnfavorited),
                    duration: const Duration(seconds: 1),
                  ));
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('操作失败: $e')),
                  );
                }
              },
            ),
            const SizedBox(width: 6),
            _MoreMenuButton(movie: movie),
            const SizedBox(width: 6),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroHeader(movie: movie, urlBuilder: urlBuilder),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: _TitleBlock(movie: movie),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: _ActionRow(movie: movie),
          ),
        ),
        if (movie.plot != null && movie.plot!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              child: Text(
                movie.plot!,
                style: AppText.body(context).copyWith(height: 1.55),
              ),
            ),
          ),
        if (movie.actors.isNotEmpty)
          SliverToBoxAdapter(
            child: _CastSection(actors: movie.actors),
          ),
        // 分组显示 series / genres / tags
        if (movie.series != null)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: '系列',
              items: [movie.series!],
              kind: ResourceKind.series,
              hueOffset: 0,
              prefix: '◇ ',
            ),
          ),
        if (movie.genres.isNotEmpty)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: '分类',
              items: movie.genres,
              kind: ResourceKind.genre,
              hueOffset: 0,
            ),
          ),
        if (movie.tags.isNotEmpty)
          SliverToBoxAdapter(
            child: _TaxonomySection(
              label: '标签',
              items: movie.tags,
              kind: ResourceKind.tag,
              hueOffset: 2,
              prefix: '# ',
            ),
          ),
        SliverToBoxAdapter(
          child: _DetailsTable(movie: movie),
        ),
        SliverToBoxAdapter(
          child: _MediaInfoSection(movieId: movie.id),
        ),
        SliverToBoxAdapter(
          child: _RelatedFilesSection(movie: movie),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.movie, required this.urlBuilder});
  final MovieDetail movie;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    // fanart fallback poster fallback thumb
    final heroUuid = movie.fanartUuid?.isNotEmpty == true
        ? movie.fanartUuid
        : (movie.posterUuid?.isNotEmpty == true ? movie.posterUuid : null);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ---------- 横版主图 (满铺 cover) ----------
        if (heroUuid != null)
          Poster(
            url: urlBuilder(heroUuid),
            title: movie.title,
            year: movie.year,
            aspectRatio: 16 / 9,
            radius: 0,
            imageAlignment: const Alignment(0, -0.6),
          )
        else
          ColoredBox(color: c.surfaceAlt),
        // ---------- 底部渐变让标题区可读 ----------
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.bg.withValues(alpha: 0.0),
                c.bg.withValues(alpha: 0.0),
                c.bg.withValues(alpha: 0.85),
                c.bg,
              ],
              stops: const [0.0, 0.45, 0.85, 1.0],
            ),
          ),
        ),
        // ---------- 顶部小渐变让 AppBar 按钮可读 ----------
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35],
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    const baseStyle = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
      letterSpacing: 1.4,
    );
    final dot = TextSpan(text: '  ·  ', style: baseStyle.copyWith(color: c.muted));
    final spans = <InlineSpan>[];
    void add(InlineSpan s) {
      if (spans.isNotEmpty) spans.add(dot);
      spans.add(s);
    }

    if (movie.year != null) {
      add(TextSpan(text: '${movie.year}', style: baseStyle.copyWith(color: c.muted)));
    }
    if (movie.runtime != null && movie.runtime! > 0) {
      add(TextSpan(
        text: '${movie.runtime} MIN',
        style: baseStyle.copyWith(color: c.accent),
      ));
    }
    if (movie.country != null && movie.country!.isNotEmpty) {
      add(TextSpan(
        text: movie.country!.toUpperCase(),
        style: baseStyle.copyWith(color: c.muted),
      ));
    }
    if (movie.rating != null && movie.rating! > 0) {
      add(TextSpan(
        text: '★ ${movie.rating!.toStringAsFixed(1)}',
        style: baseStyle.copyWith(color: c.warning),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          movie.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.text,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.84,
            height: 1.1,
          ),
        ),
        if (movie.originalTitle != null && movie.originalTitle != movie.title) ...[
          const SizedBox(height: 4),
          Text(
            movie.originalTitle!,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontStyle: FontStyle.italic, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        if (spans.isNotEmpty)
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: spans),
          ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.movie});

  final MovieDetail movie;

  int get _startPositionSec {
    final wr = movie.watchRecord;
    if (wr == null || wr.completed) return 0;
    final r = wr.progressRatio.clamp(0.0, 1.0);
    final runtimeMin = movie.runtime ?? 0;
    if (runtimeMin <= 0 || r <= 0) return 0;
    return (runtimeMin * 60 * r).round();
  }

  List<PlayerQueueItem> get _playerQueue {
    final items = <PlayerQueueItem>[
      PlayerQueueItem(
        movieId: movie.id,
        title: movie.title,
        startPositionSec: _startPositionSec,
        part: movie.moviePart,
      ),
      for (final related in movie.partMovies)
        if (related.id != movie.id)
          PlayerQueueItem(
            movieId: related.id,
            title: related.title,
            part: related.moviePart,
          ),
    ];
    if (items.every((item) => item.part?.isNotEmpty == true)) {
      items.sort(_comparePlayerQueueItems);
    }
    return items;
  }

  int _comparePlayerQueueItems(PlayerQueueItem a, PlayerQueueItem b) {
    final aPart = _partNumber(a.part);
    final bPart = _partNumber(b.part);
    if (aPart == null || bPart == null) return 0;
    return aPart.compareTo(bPart);
  }

  int? _partNumber(String? part) {
    final match = RegExp(r'(\d+)').firstMatch(part ?? '');
    return int.tryParse(match?.group(1) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final playerQueue = _playerQueue;
    final playerQueueIndex =
        playerQueue.indexWhere((item) => item.movieId == movie.id);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () => PlayerPage.open(
              context,
              movieId: movie.id,
              title: movie.title,
              startPositionSec: _startPositionSec,
              queue: playerQueue,
              queueIndex: playerQueueIndex < 0 ? 0 : playerQueueIndex,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.text,
              foregroundColor: c.bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, size: 18),
                const SizedBox(width: 6),
                Text(AppL10n.of(context).detailPlay,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () => AddToListSheet.show(
              context,
              movieId: movie.id,
              movieTitle: movie.title,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.text,
              side: BorderSide(color: c.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              AppL10n.of(context).detailAddList,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _CastSection extends StatelessWidget {
  const _CastSection({required this.actors});
  final List<ActorItem> actors;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Text('演员', style: AppText.sectionTitle(context)),
          ),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: actors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (ctx, i) {
                final a = actors[i];
                final hue = AppHues.all[i % AppHues.all.length];
                return SizedBox(
                  width: 80,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => ActorMoviesPage(actor: a),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppHues.top(hue), AppHues.bottom(hue)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppHues.top(hue).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(a.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first.toString() +
            parts.last.characters.first.toString())
        .toUpperCase();
  }
}

/// 单类 taxonomy 分组 (系列 / 分类 / 标签),带 label + Wrap 多彩 chips。
/// 每个 chip 点击跳 ResourceMoviesPage 按该维度过滤。
class _TaxonomySection extends StatelessWidget {
  const _TaxonomySection({
    required this.label,
    required this.items,
    required this.kind,
    this.hueOffset = 0,
    this.prefix = '',
  });

  final String label;
  final List<ResourceItem> items;
  final ResourceKind kind;
  final int hueOffset;
  final String prefix;

  void _open(BuildContext context, ResourceItem r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResourceMoviesPage(kind: kind, resource: r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.sectionTitle(context),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < items.length; i++)
                HueChip(
                  label: '$prefix${items[i].name}',
                  hue: AppHues.all[(i + hueOffset) % AppHues.all.length],
                  onTap: () => _open(context, items[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 相关文件 section · 优先展示 related_files (含 label+path),
/// fallback 显示单条 file_path。
class _RelatedFilesSection extends StatelessWidget {
  const _RelatedFilesSection({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final files = <({String label, String path})>[];
    if (movie.relatedFiles.isNotEmpty) {
      for (final f in movie.relatedFiles) {
        files.add((label: f.label ?? f.type ?? '文件', path: f.path));
      }
    } else if (movie.filePath != null && movie.filePath!.isNotEmpty) {
      files.add((label: '影片', path: movie.filePath!));
    }
    if (files.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件路径', style: AppText.sectionTitle(context)),
          const SizedBox(height: 12),
          for (var i = 0; i < files.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < files.length - 1
                    ? Border(bottom: BorderSide(color: c.divider))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    files[i].label,
                    style: TextStyle(
                      color: c.muted,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    files[i].path,
                    style: TextStyle(
                      color: c.text2,
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final rows = <List<String>>[];
    if (movie.num != null && movie.num!.isNotEmpty) rows.add(['番号', movie.num!]);
    if (movie.country != null && movie.country!.isNotEmpty) {
      rows.add(['产地', movie.country!]);
    }
    if (movie.fileSize != null && movie.fileSize! > 0) {
      rows.add(['文件大小', _formatBytes(movie.fileSize!)]);
    }
    if (movie.moviePart != null && movie.moviePart!.isNotEmpty) {
      rows.add(['分卷', movie.moviePart!]);
    }
    if (movie.lastDownloadedAt != null && movie.lastDownloadedAt!.isNotEmpty) {
      rows.add(['下载时间', movie.lastDownloadedAt!]);
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('详细信息', style: AppText.sectionTitle(context)),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? Border(bottom: BorderSide(color: c.divider))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      rows[i][0].toUpperCase(),
                      style: TextStyle(
                        color: c.muted,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i][1],
                      style: TextStyle(
                        color: c.text,
                        fontFamily: rows[i][0] == 'File' ? 'monospace' : 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: rows[i][0] == 'File' ? 11.5 : 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(2)} ${units[unit]}';
}

/// 媒体技术信息 section (容器/视频/音频)
class _MediaInfoSection extends ConsumerWidget {
  const _MediaInfoSection({required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mediaInfoProvider(movieId));
    return async.maybeWhen(
      data: (info) {
        if (info == null) return const SizedBox.shrink();
        final c = appColors(context);
        final rows = <List<String>>[];
        if (info.container != null) rows.add(['容器', info.container!]);
        if (info.videoCodec != null) {
          final parts = <String>[info.videoCodec!];
          if (info.videoWidth != null && info.videoHeight != null) {
            parts.add('${info.videoWidth}×${info.videoHeight}');
          }
          if (info.videoFrameRate != null) {
            parts.add('${info.videoFrameRate!.toStringAsFixed(2)} fps');
          }
          rows.add(['视频', parts.join(' · ')]);
        }
        if (info.audioCodec != null) {
          final parts = <String>[info.audioCodec!];
          if (info.audioChannels != null) parts.add('${info.audioChannels} ch');
          rows.add(['音频', parts.join(' · ')]);
        }
        if (info.durationSec != null && info.durationSec! > 0) {
          final s = info.durationSec!.round();
          final h = s ~/ 3600;
          final m = (s % 3600) ~/ 60;
          final sec = s % 60;
          rows.add([
            '时长',
            h > 0
                ? '${h}h ${m.toString().padLeft(2, '0')}m ${sec.toString().padLeft(2, '0')}s'
                : '${m}m ${sec.toString().padLeft(2, '0')}s'
          ]);
        }
        if (info.bitRate != null && info.bitRate! > 0) {
          rows.add(['码率', '${(info.bitRate! / 1000).round()} kbps']);
        }
        if (rows.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('媒体信息', style: AppText.sectionTitle(context)),
              const SizedBox(height: 14),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          r[0],
                          style: TextStyle(
                            color: c.muted,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r[1],
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ============ More menu (... popup) ============
class _MoreMenuButton extends ConsumerWidget {
  const _MoreMenuButton({required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    return PopupMenuButton<String>(
      tooltip: '更多',
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_horiz, size: 18),
      ),
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            await MovieEditorSheet.show(context, movie);
            break;
          case 'subtitle':
            await ThunderSubtitleSheet.show(context, movie.id);
            break;
          case 'resources':
            await ResourcesSheet.show(
              context,
              movie: movie,
            );
            break;
          case 'dbo_meta':
            await DboDiffSheet.show(context, movie);
            break;
          case 'sync_nfo':
            await _confirmAndRun(
              context,
              ref,
              title: '同步到 NFO',
              message: '把当前元数据写入磁盘 NFO 文件?',
              run: () =>
                  ref.read(moviesRepositoryProvider).syncNfo(movie.id),
              successMsg: '已同步到 NFO',
            );
            break;
          case 'refresh_nfo':
            await _confirmAndRun(
              context,
              ref,
              title: 'NFO 重载',
              message: '从磁盘 NFO 重新加载,会覆盖当前元数据。',
              run: () =>
                  ref.read(moviesRepositoryProvider).refreshFromNfo(movie.id),
              successMsg: '已从 NFO 重载',
              refreshDetail: true,
            );
            break;
          case 'delete':
            await _confirmDelete(context, ref, movie);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 17),
            SizedBox(width: 10),
            Text('编辑'),
          ]),
        ),
        const PopupMenuItem(
          value: 'subtitle',
          child: Row(children: [
            Icon(Icons.subtitles_outlined, size: 17),
            SizedBox(width: 10),
            Text('字幕下载'),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'dbo_meta',
          child: Row(children: [
            Icon(Icons.cloud_download_outlined, size: 17),
            SizedBox(width: 10),
            Text('从 DBO 拉元数据'),
          ]),
        ),
        const PopupMenuItem(
          value: 'resources',
          child: Row(children: [
            Icon(Icons.link, size: 17),
            SizedBox(width: 10),
            Text('在线资源 (磁力/ED2K)'),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'sync_nfo',
          child: Row(children: [
            Icon(Icons.upload_outlined, size: 17),
            SizedBox(width: 10),
            Text('同步到 NFO'),
          ]),
        ),
        const PopupMenuItem(
          value: 'refresh_nfo',
          child: Row(children: [
            Icon(Icons.refresh, size: 17),
            SizedBox(width: 10),
            Text('NFO 重载'),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 17, color: c.danger),
            const SizedBox(width: 10),
            Text('删除', style: TextStyle(color: c.danger)),
          ]),
        ),
      ],
    );
  }

  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required Future<void> Function() run,
    required String successMsg,
    bool refreshDetail = false,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await run();
      messenger.showSnackBar(SnackBar(
        content: Text(successMsg),
        duration: const Duration(seconds: 1),
      ));
      if (refreshDetail) {
        // ignore: unused_result
        ref.refresh(movieDetailProvider(movie.id));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败: ${toApiException(e).message}')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MovieDetail movie,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除影片'),
        content: Text(
          '确定删除「${movie.title}」?\n影片文件、海报、剧照、NFO 等关联资源都会被删除,且不可恢复。',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref.read(moviesRepositoryProvider).deleteMovie(movie.id);
      messenger.showSnackBar(const SnackBar(
        content: Text('已删除'),
        duration: Duration(seconds: 1),
      ));
      // 返回上一页
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: ${toApiException(e).message}')),
      );
    }
  }
}
