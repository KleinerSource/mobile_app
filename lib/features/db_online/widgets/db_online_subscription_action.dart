import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription_api.dart';
import 'package:omm/features/db_online/pages/db_online_subscriptions_page.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_subscription_repository.dart';
import 'package:omm/features/db_online/widgets/db_online_subscription_status_badge.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/localized_error_message.dart';

class DbOnlineSubscriptionLongPressMenu {
  const DbOnlineSubscriptionLongPressMenu({
    required this.query,
    required this.status,
    required this.entries,
  });

  final DbOnlineSubscriptionStatusQuery query;
  final DbOnlineSubscriptionStatus status;
  final List<GlassMenuEntry<String>> entries;
}

/// 订阅入口按钮。
///
/// [showLabel] 为 true 时渲染详情页操作区的按钮（宽度随父级：与播放
/// 按钮并排等宽或独占整行），订阅后按状态实心填充（与封面角标共用
/// 同一颜色/图标/文案映射：订阅中黄、已完成绿、已跳过红、超期橙），
/// 未订阅为中性描边；否则渲染卡片与搜索行尾部的图标按钮。
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

  /// 长按菜单根据单影片状态查询生成，避免把状态未知误判成未订阅。
  Future<DbOnlineSubscriptionLongPressMenu?> prepareLongPressMenu(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final serverId =
        ref.read(mediaRuntimeConfigProvider)?.activeServerId?.trim() ?? '';
    if (!context.mounted || serverId.isEmpty || id.trim().isEmpty) return null;
    final query = DbOnlineSubscriptionStatusQuery(
      serverId: serverId,
      kind: kind,
      id: id,
      subType: initial['sub_type']?.toString() ?? 'series',
    );
    try {
      final capabilities = await ref.read(
        dbOnlineSubscriptionCapabilitiesProvider(serverId).future,
      );
      if (!context.mounted || !_isCurrent(context, ref, query)) return null;
      if (!capabilities.database) return null;
      final subscription = await ref.read(
        dbOnlineSubscriptionStatusProvider(query).future,
      );
      if (!context.mounted || !_isCurrent(context, ref, query)) return null;
      final l = AppL10n.of(context);
      final actions = _actionOptions(
        l,
        subscribed: subscription.subscribed,
        subscription: subscription,
        showAddAction: true,
      );
      return DbOnlineSubscriptionLongPressMenu(
        query: query,
        status: subscription,
        entries: [
          for (final action in actions)
            GlassMenuEntry<String>.action(
              value: action.$1,
              builder: (context, selected, onTap) => GlassMenuRow(
                label: action.$2,
                icon: action.$3,
                selected: selected,
                foregroundColor: action.$1 == 'cancel'
                    ? appColors(context).danger
                    : null,
                onTap: onTap,
              ),
            ),
        ],
      );
    } catch (error) {
      if (context.mounted && _isCurrent(context, ref, query)) {
        _notify(context, localizedErrorMessage(AppL10n.of(context), error));
      }
      return null;
    }
  }

  Future<void> selectLongPressMenuAction(
    BuildContext context,
    WidgetRef ref,
    DbOnlineSubscriptionLongPressMenu menu,
    String action,
  ) => _openActions(
    context,
    ref,
    menu.query,
    AppL10n.of(context),
    subscribed: menu.status.subscribed,
    subscription: menu.status,
    showAddAction: true,
    selectedAction: action,
  );

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
    // 文案/图标/配色与封面角标共用同一映射：未订阅=中性描边，
    // 其余状态实心填充状态色（订阅中黄、已完成绿、已跳过红、超期橙）。
    final style = dbOnlineSubscriptionStatusStyle(
      l,
      subscribed: subscribed,
      status: subscription?.status ?? '',
      overdue: subscription?.overdue ?? false,
    );
    final actionLabel = style.label;
    final iconData = style.icon;
    final stateColor = style.color;
    // 已完成按钮使用白色文字与图标，其他状态按背景亮度选择前景色。
    final onStateColor = stateColor == null
        ? null
        : subscription?.status == 'completed' && subscription?.overdue != true
        ? Colors.white
        : ThemeData.estimateBrightnessForColor(stateColor) == Brightness.light
        ? const Color(0xFF1A1A22)
        : Colors.white;
    void onPressed() => _openActions(
      context,
      ref,
      query,
      l,
      subscribed: subscribed,
      subscription: subscription,
    );

    // 带标签形态用于详情页操作区，与播放按钮共用 12px 圆角 + Inter 的
    // 规范；订阅后按状态实心填充，未订阅保持中性描边。
    return showLabel
        ? SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: statusLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: stateColor == null
                    ? colors.text
                    : onStateColor,
                backgroundColor: stateColor,
                disabledForegroundColor: colors.muted,
                side: BorderSide(
                  color: stateColor == null
                      ? colors.cardBorder
                      : Colors.transparent,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: statusLoading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.muted,
                      ),
                    )
                  : Icon(iconData, size: 18),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (subscribed) ...[
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down_rounded, size: 18),
                  ],
                ],
              ),
            ),
          )
        : HeaderActionButton(
            tooltip: actionLabel,
            onPressed: onPressed,
            loading: statusLoading,
            icon: iconData,
            color: stateColor ?? colors.muted,
          );
  }

  Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    DbOnlineSubscriptionStatusQuery query,
    AppL10n l, {
    required bool subscribed,
    required DbOnlineSubscriptionStatus? subscription,
    bool showAddAction = false,
    String? selectedAction,
  }) async {
    if (!context.mounted || !_isCurrent(context, ref, query)) return;
    var editing = false;
    if (subscribed || showAddAction) {
      if (kind == 'video' && subscribed && subscription == null) return;
      final actions = _actionOptions(
        l,
        subscribed: subscribed,
        subscription: subscription,
        showAddAction: showAddAction,
      );
      final action =
          selectedAction ??
          await showGlassSheet<String>(
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
                          color: action.$1 == 'cancel'
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
      if (!context.mounted ||
          !_isCurrent(context, ref, query) ||
          action == null) {
        return;
      }
      if (!subscribed && action != 'add') return;
      if (subscribed && action == 'cancel') {
        await _deleteSubscription(context, ref, query, l);
        return;
      }
      if (subscribed && action != 'edit') {
        final currentSubscription = subscription!;
        await _updateVideoSubscriptionStatus(
          context,
          ref,
          query,
          currentSubscription,
          l,
          action == 'restore'
              ? 'pending'
              : action == 'skip'
              ? 'skipped'
              : 'completed',
        );
        return;
      }
      editing = subscribed;
    }

    try {
      final repository = ref.read(dboSubscriptionRepositoryProvider);
      final existing = editing
          ? await _loadSubscription(repository.api, query)
          : <String, dynamic>{};
      if (!context.mounted || !_isCurrent(context, ref, query)) return;
      // 新建时以服务器预设预填下载参数（与网页端创建弹窗一致），
      // 预设垫底、身份字段覆盖；编辑则完全沿用已有订阅数据。
      final presetDefaults = editing
          ? const <String, dynamic>{}
          : await _loadCreatePreset(repository.api);
      if (!context.mounted || !_isCurrent(context, ref, query)) return;
      final details = <String, dynamic>{
        ...presetDefaults,
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
      if (result == null ||
          !context.mounted ||
          !_isCurrent(context, ref, query)) {
        return;
      }
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
      if (!context.mounted || !_isCurrent(context, ref, query)) return;
      ref.invalidate(dbOnlineSubscriptionStatusProvider(query));
      ref.invalidate(dbOnlineMovieSubscriptionStatusesProvider(query.serverId));
      ref.invalidate(dbOnlineSubscriptionListProvider);
      _notify(context, l.dbOnlineSubscriptionActionCompleted);
    } catch (error) {
      if (context.mounted && _isCurrent(context, ref, query)) {
        _notify(context, localizedErrorMessage(l, error));
      }
    }
  }

  List<(String, String, IconData)> _actionOptions(
    AppL10n l, {
    required bool subscribed,
    required DbOnlineSubscriptionStatus? subscription,
    required bool showAddAction,
  }) {
    if (!subscribed) {
      return showAddAction
          ? [
              (
                'add',
                l.dbOnlineSubscriptionAdd,
                Icons.add_circle_outline_rounded,
              ),
            ]
          : const [];
    }
    final state = subscription;
    if (kind == 'video' && state == null) return const [];
    final actions = <(String, String, IconData)>[];
    if (kind == 'video') {
      final currentStatus = state!.status.isEmpty ? 'pending' : state.status;
      if (state.overdue ||
          currentStatus == 'skipped' ||
          currentStatus == 'completed') {
        actions.add((
          'restore',
          l.dbOnlineSubscriptionRestoreAction,
          Icons.restart_alt_rounded,
        ));
      }
      if (currentStatus == 'pending' &&
          state.sourceType != 'video' &&
          !state.overdue) {
        actions.add((
          'skip',
          l.dbOnlineSubscriptionSkipAction,
          Icons.skip_next_rounded,
        ));
      }
      if (currentStatus == 'pending') {
        actions.add((
          'complete',
          l.dbOnlineSubscriptionCompleteAction,
          Icons.done_all_rounded,
        ));
      }
    }
    if (!showAddAction) {
      actions.add(('edit', l.dbOnlineSubscriptionEdit, Icons.edit_outlined));
    }
    actions.add((
      'cancel',
      l.dbOnlineSubscriptionCancelAction,
      Icons.remove_circle_outline_rounded,
    ));
    return actions;
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
      if (!context.mounted || !_isCurrent(context, ref, query)) return;
      ref.invalidate(dbOnlineSubscriptionStatusProvider(query));
      ref.invalidate(dbOnlineMovieSubscriptionStatusesProvider(query.serverId));
      ref.invalidate(dbOnlineSubscriptionListProvider);
      _notify(context, l.dbOnlineSubscriptionActionCompleted);
    } catch (error) {
      if (context.mounted && _isCurrent(context, ref, query)) {
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

  /// 新建订阅时按服务器预设（`GET /subs/preset`）预填下载参数，字段集合
  /// 与网页端 `applyLocalPresetToCreateForm` 一致；预设未启用或拉取失败
  /// 时返回空表沿用默认值。不回填 enabled/active，避免预设停用状态
  /// 影响新订阅的启用开关；after_date 仅影片订阅回填。
  Future<Map<String, dynamic>> _loadCreatePreset(
    DbOnlineSubscriptionApi api,
  ) async {
    try {
      final root = _dataMap(await api.getSubscriptionPreset());
      final preset = _dataMap(root['preset']);
      if (preset['enabled'] != true) return const <String, dynamic>{};
      final overdue =
          (int.tryParse(preset['overdue_days']?.toString() ?? '') ?? 0)
              .clamp(0, 180)
              .toInt();
      final afterDate = preset['after_date']?.toString().trim() ?? '';
      return <String, dynamic>{
        'quality': preset['quality']?.toString() ?? '',
        'require_sub': preset['require_sub'] == true,
        'require_uncensored': preset['require_uncensored'] == true,
        'pre_download_mode': preset['pre_download_mode'] == true,
        'wash_mode': preset['wash_mode'] == true,
        'min_size_mb': preset['min_size_mb'] ?? 0,
        'max_size_mb': preset['max_size_mb'] ?? 0,
        'max_file_count': preset['max_file_count'] ?? 0,
        'overdue_days': overdue,
        if (kind == 'video' && afterDate.isNotEmpty) 'after_date': afterDate,
      };
    } catch (_) {
      return const <String, dynamic>{};
    }
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
            style: FilledButton.styleFrom(
              backgroundColor: appColors(context).danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l.dbOnlineSubscriptionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        !_isCurrent(context, ref, query)) {
      return;
    }
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
      if (!context.mounted || !_isCurrent(context, ref, query)) return;
      ref.invalidate(dbOnlineSubscriptionStatusProvider(query));
      ref.invalidate(dbOnlineMovieSubscriptionStatusesProvider(query.serverId));
      ref.invalidate(dbOnlineSubscriptionListProvider);
      _notify(context, l.dbOnlineSubscriptionActionCompleted);
    } catch (error) {
      if (context.mounted && _isCurrent(context, ref, query)) {
        _notify(context, localizedErrorMessage(l, error));
      }
    }
  }

  bool _isCurrent(
    BuildContext context,
    WidgetRef ref,
    DbOnlineSubscriptionStatusQuery query,
  ) =>
      context.mounted &&
      ref.read(mediaRuntimeConfigProvider)?.activeServerId == query.serverId;

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Map<String, dynamic> _dataMap(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
