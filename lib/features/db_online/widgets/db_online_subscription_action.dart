import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/db_online/pages/db_online_subscriptions_page.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_subscription_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';

class DbOnlineSubscriptionAction extends ConsumerWidget {
  const DbOnlineSubscriptionAction({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
    this.initial = const <String, dynamic>{},
    this.showLabel = false,
  });

  final String kind;
  final String id;
  final String title;
  final Map<String, dynamic> initial;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId =
        ref.watch(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    final capabilities = ref.watch(
      dbOnlineSubscriptionCapabilitiesProvider(serverId),
    );
    final databaseEnabled = capabilities.when(
      data: (value) => value.database,
      loading: () => false,
      error: (_, _) => false,
    );
    if (id.trim().isEmpty || !databaseEnabled) {
      return const SizedBox.shrink();
    }

    final query = DbOnlineSubscriptionStatusQuery(
      serverId: serverId,
      kind: kind,
      id: id,
      subType: initial['sub_type']?.toString() ?? 'series',
    );
    final status = ref.watch(dbOnlineSubscriptionStatusProvider(query));
    final statusLoading = status.when(
      data: (_) => false,
      loading: () => true,
      error: (_, _) => false,
    );
    final subscription = status.when(
      data: (value) => value,
      loading: () => null,
      error: (_, _) => null,
    );
    final subscribed = subscription?.subscribed ?? false;
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final actionLabel = !subscribed
        ? l.dbOnlineSubscriptionAdd
        : subscription!.overdue
        ? l.dbOnlineSubscriptionOverdue
        : switch (subscription.status) {
            'completed' => l.dbOnlineSubscriptionCompleted,
            'skipped' => l.dbOnlineSubscriptionSkipped,
            _ => l.dbOnlineSubscriptionSubscribed,
          };
    final icon = statusLoading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            subscribed ? Icons.check_circle_rounded : Icons.add_circle_outline,
            color: subscribed ? colors.accent : colors.muted,
          );
    void onPressed() => _openActions(
      context,
      ref,
      query,
      l,
      subscribed: subscribed,
      subscription: subscription,
    );

    return showLabel
        ? OutlinedButton.icon(
            onPressed: statusLoading ? null : onPressed,
            icon: icon,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel),
                if (subscribed) ...[
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
                ],
              ],
            ),
          )
        : IconButton(
            tooltip: actionLabel,
            onPressed: statusLoading ? null : onPressed,
            icon: icon,
          );
  }

  Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    DbOnlineSubscriptionStatusQuery query,
    AppL10n l, {
    required bool subscribed,
    required DbOnlineSubscriptionStatus? subscription,
  }) async {
    var editing = false;
    if (subscribed) {
      final state = subscription;
      if (state == null) return;
      final currentStatus = state.status.isEmpty ? 'pending' : state.status;
      final actions = <(String, String, IconData)>[];
      if (kind == 'video') {
        if (state.overdue ||
            currentStatus == 'skipped' ||
            currentStatus == 'completed') {
          actions.add((
            'restore',
            l.dbOnlineSubscriptionPendingStatus,
            Icons.restart_alt_rounded,
          ));
        }
        if (currentStatus == 'pending' &&
            state.sourceType != 'video' &&
            !state.overdue) {
          actions.add((
            'skip',
            l.dbOnlineSubscriptionSkipped,
            Icons.skip_next_rounded,
          ));
        }
        if (currentStatus != 'completed') {
          actions.add((
            'complete',
            l.dbOnlineSubscriptionCompleted,
            Icons.done_all_rounded,
          ));
        }
      }
      actions.add(('edit', l.dbOnlineSubscriptionEdit, Icons.edit_outlined));
      actions.add((
        'remove',
        l.dbOnlineSubscriptionRemove,
        Icons.remove_circle_outline_rounded,
      ));
      final action = await showGlassSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: actions
                .map(
                  (action) => ListTile(
                    leading: Icon(
                      action.$3,
                      color: action.$1 == 'remove'
                          ? appColors(context).danger
                          : null,
                    ),
                    title: Text(action.$2),
                    onTap: () => Navigator.pop(context, action.$1),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );
      if (!context.mounted || action == null) return;
      if (action == 'remove') {
        await _deleteSubscription(context, ref, query, l);
        return;
      }
      if (action != 'edit') {
        await _updateVideoSubscriptionStatus(
          context,
          ref,
          query,
          state,
          l,
          action == 'restore'
              ? 'pending'
              : action == 'skip'
              ? 'skipped'
              : 'completed',
        );
        return;
      }
      editing = true;
    }

    try {
      final repository = ref.read(dboSubscriptionRepositoryProvider);
      final existing = editing
          ? await _loadSubscription(repository.api, query)
          : <String, dynamic>{};
      if (!context.mounted) return;
      final details = <String, dynamic>{
        ...existing,
        ...initial,
        switch (kind) {
          'video' => 'video_code',
          'actor' => 'actor_id',
          _ => 'external_id',
        }: id,
        switch (kind) {
          'video' => 'video_title',
          'actor' => 'actor_name',
          _ => 'series_name',
        }: title,
        if (kind == 'series') 'sub_type': query.subType,
      };
      final result = await showDbOnlineSubscriptionEditor(
        context,
        kind: kind,
        initial: details,
        isEdit: editing,
      );
      if (result == null || !context.mounted) return;
      switch (kind) {
        case 'video':
          if (editing) {
            await repository.api.updateVideoSubscription(id, result);
          } else {
            await repository.api.createVideoSubscription(result);
          }
        case 'actor':
          if (editing) {
            await repository.api.updateActorSubscription(id, result);
          } else {
            await repository.api.createActorSubscription(result);
          }
        case 'series':
          if (editing) {
            await repository.api.updateSeriesSubscription(
              id,
              result,
              subType: query.subType,
            );
          } else {
            await repository.api.createSeriesSubscription(result);
          }
      }
      if (!context.mounted) return;
      ref.invalidate(dbOnlineSubscriptionStatusProvider(query));
      ref.invalidate(dbOnlineMovieSubscriptionStatusesProvider(query.serverId));
      ref.invalidate(dbOnlineSubscriptionListProvider);
      _notify(context, l.dbOnlineSubscriptionActionCompleted);
    } catch (error) {
      if (context.mounted) {
        _notify(context, localizedErrorMessage(l, error));
      }
    }
  }

  Future<void> _updateVideoSubscriptionStatus(
    BuildContext context,
    WidgetRef ref,
    DbOnlineSubscriptionStatusQuery query,
    DbOnlineSubscriptionStatus subscription,
    AppL10n l,
    String nextStatus,
  ) async {
    try {
      final api = ref.read(dboSubscriptionRepositoryProvider).api;
      if (nextStatus == 'completed' && subscription.sourceType == 'video') {
        await api.updateVideoSubscription(query.id, {'mark_completed': true});
      } else {
        if (subscription.sourceType != 'video' &&
            subscription.sourceId == null) {
          throw StateError('Subscription source ID is unavailable.');
        }
        await api.updateSubscriptionVideoStatus({
          'source_type': subscription.sourceType,
          if (subscription.sourceType != 'video')
            'source_id': subscription.sourceId,
          'video_code': query.id,
          'status': nextStatus,
        });
      }
      if (!context.mounted) return;
      ref.invalidate(dbOnlineSubscriptionStatusProvider(query));
      ref.invalidate(dbOnlineMovieSubscriptionStatusesProvider(query.serverId));
      ref.invalidate(dbOnlineSubscriptionListProvider);
      _notify(context, l.dbOnlineSubscriptionActionCompleted);
    } catch (error) {
      if (context.mounted) {
        _notify(context, localizedErrorMessage(l, error));
      }
    }
  }

  Future<Map<String, dynamic>> _loadSubscription(
    dynamic api,
    DbOnlineSubscriptionStatusQuery query,
  ) async {
    final payload = switch (kind) {
      'actor' => await api.actorSubscription(id),
      'series' => await api.seriesSubscription(id, subType: query.subType),
      _ => await api.videoSubscriptions(
        filter: 'all',
        page: 1,
        limit: 100,
        keyword: id,
      ),
    };
    final data = _dataMap(payload);
    if (kind != 'video') return data;
    final items = data['items'];
    if (items is List) {
      for (final item in items) {
        final value = _dataMap(item);
        if (value['video_code']?.toString() == id) return value;
      }
    }
    return <String, dynamic>{};
  }

  Future<void> _deleteSubscription(
    BuildContext context,
    WidgetRef ref,
    DbOnlineSubscriptionStatusQuery query,
    AppL10n l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.dbOnlineSubscriptionDelete),
        content: Text(l.dbOnlineSubscriptionDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.dbOnlineSubscriptionCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.dbOnlineSubscriptionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final api = ref.read(dboSubscriptionRepositoryProvider).api;
      switch (kind) {
        case 'video':
          await api.deleteVideoSubscription(id);
        case 'actor':
          await api.deleteActorSubscription(id);
        case 'series':
          await api.deleteSeriesSubscription(id, subType: query.subType);
      }
      if (!context.mounted) return;
      ref.invalidate(dbOnlineSubscriptionStatusProvider(query));
      ref.invalidate(dbOnlineMovieSubscriptionStatusesProvider(query.serverId));
      ref.invalidate(dbOnlineSubscriptionListProvider);
      _notify(context, l.dbOnlineSubscriptionActionCompleted);
    } catch (error) {
      if (context.mounted) {
        _notify(context, localizedErrorMessage(l, error));
      }
    }
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Map<String, dynamic> _dataMap(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
