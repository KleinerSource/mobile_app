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
    .family<bool, DbOnlineSubscriptionStatusQuery>((ref, query) {
      return ref.watch(dboSubscriptionRepositoryProvider).isSubscribed(query);
    });
