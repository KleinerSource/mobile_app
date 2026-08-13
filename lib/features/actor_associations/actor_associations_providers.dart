import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import 'actor_associations_repository.dart';

final actorAssociationsRepositoryProvider =
    Provider<ActorAssociationsRepository>((ref) {
  final client = ref.watch(requiredApiClientProvider);
  return ActorAssociationsRepository(
    client.mappings,
    actorsApi: client.actors,
  );
});
