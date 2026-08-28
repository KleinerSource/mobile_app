import 'dart:async';

/// Optional lifecycle contract for sources that own sockets or protocol
/// clients.  Registries call it when their scoped instance is disposed.
abstract interface class SourceLifecycle {
  FutureOr<void> dispose();
}
