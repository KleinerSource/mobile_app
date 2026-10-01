import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription.dart';
import 'package:omm/features/db_online/repositories/dbo_subscription_repository.dart';

final dboSubscriptionRepositoryProvider =
    Provider.autoDispose<DboSubscriptionRepository>((ref) {
      final client = ref.watch(requiredApiClientProvider);
      return DboSubscriptionRepository(
        api: client.dbOnline.subscriptions,
        activeServerId: client.config?.activeServerId ?? '',
      );
    });

final dbOnlineSubscriptionCapabilitiesProvider = FutureProvider.autoDispose
    .family<DbOnlineSubscriptionCapabilities, String>((ref, serverId) {
      return ref
          .watch(dboSubscriptionRepositoryProvider)
          .capabilities(serverId);
    });

final dbOnlineSubscriptionListProvider = FutureProvider.autoDispose
    .family<DbOnlineSubscriptionPage, DbOnlineSubscriptionQuery>((ref, query) {
      return ref.watch(dboSubscriptionRepositoryProvider).list(query);
    });

final dbOnlineSubscriptionStatusProvider = FutureProvider.autoDispose
    .family<DbOnlineSubscriptionStatus, DbOnlineSubscriptionStatusQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(dboSubscriptionRepositoryProvider)
          .subscriptionStatus(query);
    });

class DbOnlineMovieSubscriptionStatusesNotifier
    extends Notifier<Map<String, DbOnlineSubscriptionStatus>> {
  DbOnlineMovieSubscriptionStatusesNotifier(this.serverId);

  final String serverId;
  final Set<String> _pendingCodes = <String>{};
  Timer? _batchTimer;
  bool _loading = false;

  @override
  Map<String, DbOnlineSubscriptionStatus> build() {
    ref.watch(dboSubscriptionRepositoryProvider);
    ref.onDispose(() => _batchTimer?.cancel());
    return const <String, DbOnlineSubscriptionStatus>{};
  }

  void check(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty || state.containsKey(normalized.toUpperCase())) {
      return;
    }
    _pendingCodes.add(normalized);
    _scheduleBatch();
  }

  void _scheduleBatch() {
    if (_loading || _pendingCodes.isEmpty) return;
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 100), _loadBatch);
  }

  Future<void> _loadBatch() async {
    _batchTimer = null;
    if (_loading || _pendingCodes.isEmpty || !ref.mounted) return;
    _loading = true;
    final codes = _pendingCodes.take(50).toList(growable: false);
    _pendingCodes.removeAll(codes);
    try {
      final result = await ref
          .read(dboSubscriptionRepositoryProvider)
          .videoSubscriptionStatuses(serverId: serverId, codes: codes);
      if (!ref.mounted) return;
      state = {
        ...state,
        for (final entry in result.entries)
          entry.key.toUpperCase(): entry.value,
      };
    } catch (_) {
      if (!ref.mounted) return;
      state = {
        ...state,
        for (final code in codes)
          code.toUpperCase(): const DbOnlineSubscriptionStatus(
            subscribed: false,
            sourceType: 'video',
            status: '',
            active: false,
          ),
      };
    } finally {
      _loading = false;
      if (ref.mounted) _scheduleBatch();
    }
  }
}

final dbOnlineMovieSubscriptionStatusesProvider =
    NotifierProvider.family<
      DbOnlineMovieSubscriptionStatusesNotifier,
      Map<String, DbOnlineSubscriptionStatus>,
      String
    >(DbOnlineMovieSubscriptionStatusesNotifier.new);

final dbOnlineSubscriptionAutoSyncProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, serverId) async {
      final repository = ref.watch(dboSubscriptionRepositoryProvider);
      repository.checkServer(serverId);
      final raw = await repository.api.getAutoSync();
      final root = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final data = root['data'];
      return data is Map ? Map<String, dynamic>.from(data) : root;
    });
