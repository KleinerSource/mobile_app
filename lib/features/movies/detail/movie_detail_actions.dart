import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/movie.dart';
import '../../../core/ui/tokens.dart';
import '../movies_providers.dart';

class MovieDetailActions extends ConsumerStatefulWidget {
  const MovieDetailActions({super.key, required this.movie});
  final MovieDetail movie;

  @override
  ConsumerState<MovieDetailActions> createState() => _MovieDetailActionsState();
}

class _MovieDetailActionsState extends ConsumerState<MovieDetailActions> {
  bool _favoriteLoading = false;
  bool _watchedLoading = false;

  Future<void> _toggleFavorite() async {
    setState(() => _favoriteLoading = true);
    try {
      await ref.read(moviesRepositoryProvider).toggleFavorite(widget.movie.id);
      ref.invalidate(movieDetailProvider(widget.movie.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏操作失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _favoriteLoading = false);
    }
  }

  Future<void> _toggleWatched() async {
    final current = widget.movie.watchRecord?.completed ?? false;
    setState(() => _watchedLoading = true);
    try {
      await ref.read(moviesRepositoryProvider).markWatched(widget.movie.id, !current);
      ref.invalidate(movieDetailProvider(widget.movie.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('观看状态更新失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _watchedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final favorited = widget.movie.isFavorited;
    final completed = widget.movie.watchRecord?.completed ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _favoriteLoading ? null : _toggleFavorite,
              style: FilledButton.styleFrom(
                backgroundColor: favorited ? c.surface : c.brand,
                foregroundColor: favorited ? c.text : c.brandOn,
              ),
              icon: _favoriteLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(favorited ? Icons.favorite : Icons.favorite_outline),
              label: Text(favorited ? '已收藏' : '收藏'),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: FilledButton.icon(
              onPressed: _watchedLoading ? null : _toggleWatched,
              style: FilledButton.styleFrom(
                backgroundColor: completed ? c.surface : c.brand,
                foregroundColor: completed ? c.text : c.brandOn,
              ),
              icon: _watchedLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(completed
                      ? Icons.check_circle
                      : Icons.check_circle_outline),
              label: Text(completed ? '已看完' : '标记看完'),
            ),
          ),
        ],
      ),
    );
  }
}
