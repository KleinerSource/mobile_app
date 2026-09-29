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
    final subscribed = status.when(
      data: (value) => value,
      loading: () => false,
      error: (_, _) => false,
    );
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final icon = statusLoading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            subscribed ? Icons.check_circle_rounded : Icons.add_circle_outline,
            color: subscribed ? colors.accent : colors.muted,
          );
    void onPressed() =>
        _openActions(context, ref, query, l, subscribed: subscribed);

    return showLabel
        ? OutlinedButton.icon(
            onPressed: statusLoading ? null : onPressed,
            icon: icon,
            label: Text(
              subscribed
                  ? l.dbOnlineSubscriptionSubscribed
                  : l.dbOnlineSubscriptionAdd,
            ),
          )
        : IconButton(
            tooltip: subscribed
                ? l.dbOnlineSubscriptionSubscribed
                : l.dbOnlineSubscriptionAdd,
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
  }) async {
    var editing = false;
    if (subscribed) {
      final action = await showGlassSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l.dbOnlineSubscriptionEdit),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: Text(l.dbOnlineSubscriptionRemove),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted || action == null) return;
      editing = action == 'edit';
      if (!editing) {
        await _deleteSubscription(context, ref, query, l);
        return;
      }
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
