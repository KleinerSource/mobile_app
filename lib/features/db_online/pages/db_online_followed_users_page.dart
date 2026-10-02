import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/features/db_online/providers/db_online_following_providers.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_following_widgets.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/paged_selection.dart';
import 'package:omm/shared/sheet_controls.dart';

import 'db_online_review_resources_page.dart';

class DbOnlineFollowedUsersPage extends ConsumerStatefulWidget {
  const DbOnlineFollowedUsersPage({super.key, required this.serverId});
  final String serverId;

  @override
  ConsumerState<DbOnlineFollowedUsersPage> createState() =>
      _FollowedUsersState();
}

class _FollowedUsersState extends ConsumerState<DbOnlineFollowedUsersPage> {
  final _scroll = ScrollController();
  late final _selection = PagedSelectionController<DbOnlineFollowedUser>(
    idOf: (user) => user.userId,
  )..addModeListener(_modeChanged);
  List<DbOnlineFollowedUser>? _refreshedUsers;
  bool _busy = false;
  bool get _current =>
      mounted && isDbOnlineFollowingServer(ref, widget.serverId);

  @override
  void dispose() {
    _selection.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _modeChanged() {
    if (mounted) setState(() {});
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _reload() async {
    final l = AppL10n.of(context);
    if (!_current) return;
    try {
      final capabilityProvider = dbOnlineSubscriptionCapabilitiesProvider(
        widget.serverId,
      );
      if (ref.read(capabilityProvider).hasError) {
        ref.invalidate(capabilityProvider);
      }
      final capabilities = await ref.read(capabilityProvider.future);
      if (!_current || !capabilities.database) return;
      ref.invalidate(dbOnlineFollowedUsersProvider(widget.serverId));
      final users = await ref.read(
        dbOnlineFollowedUsersProvider(widget.serverId).future,
      );
      if (_current) setState(() => _refreshedUsers = users);
    } catch (error) {
      if (_current) _notify(localizedErrorMessage(l, error));
    }
  }

  Future<void> _refreshUsers() async {
    final l = AppL10n.of(context);
    if (_busy || !_current) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(dbOnlineFollowingApiProvider(widget.serverId))
          .refreshUsers();
      if (!_current) return;
      setState(() => _refreshedUsers = result.users);
      // 服务端刷新返回的排列就是列表顺序，不按客户端姓名或日期重排。
      ref.invalidate(dbOnlineFollowedUsersProvider(widget.serverId));
      _notify(
        result.failed > 0
            ? l.dbOnlineFollowingRefreshPartialFailed(result.failed)
            : l.dbOnlineFollowingRefreshSuccess,
      );
    } catch (error) {
      if (_current) _notify(localizedErrorMessage(l, error));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final l = AppL10n.of(context);
    final form = GlobalKey<FormState>();
    final id = TextEditingController();
    final value = await showGlassDialog<String>(
      context: context,
      title: Text(l.dbOnlineFollowingAddUser),
      content: Form(
        key: form,
        child: TextFormField(
          controller: id,
          autofocus: true,
          decoration: sheetInputDecoration(
            context,
            labelText: l.dbOnlineFollowingUserId,
          ),
          validator: (value) => value?.trim().isNotEmpty == true
              ? null
              : l.dbOnlineFollowingUserIdRequired,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(l.dbOnlineSubscriptionCancel),
        ),
        TextButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.of(context, rootNavigator: true).pop(id.text.trim());
            }
          },
          child: Text(l.dbOnlineFollowingFollowUser),
        ),
      ],
    );
    if (value != null && _current) {
      setState(() => _busy = true);
      try {
        final user = await ref
            .read(dbOnlineFollowingApiProvider(widget.serverId))
            .followUser(value);
        if (_current) {
          _notify(
            user.created
                ? l.dbOnlineFollowingUserAdded
                : l.dbOnlineFollowingUserExists,
          );
          await _reload();
        }
      } catch (error) {
        if (_current) _notify(localizedErrorMessage(l, error));
      } finally {
        if (_current) setState(() => _busy = false);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    id.dispose();
  }

  Future<void> _remove(List<String> ids) async {
    if (ids.isEmpty || _busy || !_current) return;
    final l = AppL10n.of(context);
    final confirmed = await showGlassDialog<bool>(
      context: context,
      title: Text(l.dbOnlineFollowingUnfollowUser),
      content: Text(l.dbOnlineFollowingUnfollowConfirm(ids.length)),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text(l.dbOnlineSubscriptionCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: appColors(context).danger,
          ),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text(l.dbOnlineFollowingUnfollowUser),
        ),
      ],
    );
    if (confirmed != true || !_current) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dbOnlineFollowingApiProvider(widget.serverId))
          .unfollowUsers(ids);
      if (!_current) return;
      _selection.exit();
      await _reload();
    } catch (error) {
      if (_current) _notify(localizedErrorMessage(l, error));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  void _openResources({DbOnlineFollowedUser? user, bool latest = false}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DbOnlineReviewResourcesPage(
          serverId: widget.serverId,
          userId: user?.userId ?? 'latest_reviews',
          username: user?.username ?? '',
          latest: latest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final capabilities = ref.watch(
      dbOnlineSubscriptionCapabilitiesProvider(widget.serverId),
    );
    final database = capabilities.asData?.value.database == true;
    final online = capabilities.asData?.value.onlineQuery == true;
    final users = database
        ? ref.watch(dbOnlineFollowedUsersProvider(widget.serverId))
        : null;
    final items =
        _refreshedUsers ?? users?.asData?.value ?? <DbOnlineFollowedUser>[];
    return PagedSelectionPopScope(
      selection: _selection,
      child: DbOnlineFollowingLayout(
        title: l.dbOnlineFollowingUsers,
        scrollController: _scroll,
        actions: [
          DbOnlineFollowingActionIcon(
            icon: Icons.person_add_alt_rounded,
            tooltip: l.dbOnlineFollowingAddUser,
            onPressed: database && !_busy ? _add : null,
          ),
          DbOnlineFollowingActionIcon(
            icon: Icons.refresh_rounded,
            tooltip: l.dbOnlineFollowingRefreshUsers,
            busy: _busy,
            onPressed:
                database && capabilities.asData?.value.onlineAccount == true
                ? _refreshUsers
                : null,
          ),
        ],
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _reload,
              child: PagedSelectionScope<DbOnlineFollowedUser>(
                selection: _selection,
                scrollController: _scroll,
                layout: DragSelectionLayout.list,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 140),
                  children: [
                    GlassPanel(
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_outline_rounded),
                        title: Text(l.dbOnlineFollowingLatestReviews),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: online && !_selection.isActive
                            ? () => _openResources(latest: true)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (capabilities.isLoading ||
                        users?.isLoading == true && _refreshedUsers == null)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (capabilities.hasError ||
                        users?.hasError == true && _refreshedUsers == null)
                      ErrorView(
                        message: localizedErrorMessage(
                          l,
                          capabilities.error ?? users!.error!,
                        ),
                        onRetry: _reload,
                      )
                    else if (!database)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          l.dbOnlineSubscriptionFeatureRequiresDatabase,
                        ),
                      )
                    else if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(l.dbOnlineFollowingNoUsers),
                      )
                    else
                      GlassPanel(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < items.length;
                              index++
                            ) ...[
                              if (index > 0)
                                Divider(
                                  height: 1,
                                  color: appColors(context).divider,
                                ),
                              PagedSelectionItem<DbOnlineFollowedUser>(
                                selection: _selection,
                                item: items[index],
                                cardBuilder: (context, user, selected) => ListTile(
                                  leading: _selection.isActive
                                      ? Checkbox(
                                          value: selected,
                                          onChanged: _busy
                                              ? null
                                              : (_) => _selection.toggle(
                                                  user.userId,
                                                ),
                                        )
                                      : const Icon(
                                          Icons.person_outline_rounded,
                                        ),
                                  title: Row(
                                    children: [
                                      Flexible(child: Text(user.displayName)),
                                      if (user.hasUpdate)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: Tooltip(
                                            message:
                                                l.dbOnlineFollowingUpdatedToday,
                                            child: Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: appColors(context).accent,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    [
                                          user.userId,
                                          formatDbOnlineFollowingDate(
                                            user.latestReviewAt,
                                          ),
                                        ]
                                        .where((value) => value.isNotEmpty)
                                        .join(' · '),
                                  ),
                                  trailing: _selection.isActive
                                      ? null
                                      : IconButton(
                                          tooltip:
                                              l.dbOnlineFollowingUnfollowUser,
                                          color: appColors(context).danger,
                                          icon: const Icon(
                                            Icons.person_remove_outlined,
                                            size: 20,
                                          ),
                                          onPressed: _busy
                                              ? null
                                              : () => _remove([user.userId]),
                                        ),
                                  onTap: _busy
                                      ? null
                                      : _selection.isActive
                                      ? () => _selection.toggle(user.userId)
                                      : online
                                      ? () => _openResources(user: user)
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            PagedSelectionToolbar<DbOnlineFollowedUser>(
              selection: _selection,
              onSelectAll: () => _selection.selectAll(items),
              actionsBuilder: (selected) => [
                EntityBatchAction(
                  icon: Icons.person_remove_outlined,
                  label: l.dbOnlineFollowingUnfollowUser,
                  color: appColors(context).danger,
                  onTap: selected.isEmpty || _busy
                      ? null
                      : () => _remove(selected.cast<String>().toList()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
