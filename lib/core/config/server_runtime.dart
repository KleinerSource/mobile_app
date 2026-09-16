import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/server_compatibility.dart';
import 'server_config.dart';
import 'server_config_provider.dart';

enum ServerRuntimeLane { media, files }

enum ServerRuntimePhase { idle, connecting, ready }

@immutable
class ServerRuntimeSlotState {
  const ServerRuntimeSlotState({
    this.serverId,
    this.phase = ServerRuntimePhase.idle,
    this.generation = 0,
  });

  final String? serverId;
  final ServerRuntimePhase phase;
  final int generation;

  bool get hasServer => serverId?.isNotEmpty == true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerRuntimeSlotState &&
          other.serverId == serverId &&
          other.phase == phase &&
          other.generation == generation;

  @override
  int get hashCode => Object.hash(serverId, phase, generation);
}

@immutable
class ServerRuntimeState {
  const ServerRuntimeState({
    this.media = const ServerRuntimeSlotState(),
    this.files = const ServerRuntimeSlotState(),
    this.visibleLane,
  });

  final ServerRuntimeSlotState media;
  final ServerRuntimeSlotState files;
  final ServerRuntimeLane? visibleLane;

  ServerRuntimeSlotState slot(ServerRuntimeLane lane) =>
      lane == ServerRuntimeLane.media ? media : files;

  String? serverIdFor(ServerRuntimeLane lane) => slot(lane).serverId;

  String? get visibleServerId =>
      visibleLane == null ? null : serverIdFor(visibleLane!);

  bool get hasAnyServer => media.hasServer || files.hasServer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerRuntimeState &&
          other.media == media &&
          other.files == files &&
          other.visibleLane == visibleLane;

  @override
  int get hashCode => Object.hash(media, files, visibleLane);
}

final serverRuntimeProvider =
    NotifierProvider<ServerRuntimeController, ServerRuntimeState>(
      ServerRuntimeController.new,
    );

class ServerRuntimeController extends Notifier<ServerRuntimeState> {
  @override
  ServerRuntimeState build() {
    ref.listen<ServerConfig?>(serverConfigProvider, (_, config) {
      if (config == null) {
        clearAll();
        return;
      }
      final ids = config.servers.map((server) => server.id).toSet();
      if (state.media.serverId case final id? when !ids.contains(id)) {
        clearLane(ServerRuntimeLane.media);
      }
      if (state.files.serverId case final id? when !ids.contains(id)) {
        clearLane(ServerRuntimeLane.files);
      }
    });
    return const ServerRuntimeState();
  }

  void beginSwitch(ServerRuntimeLane lane, String serverId) {
    final normalized = serverId.trim();
    if (normalized.isEmpty) return;
    final current = state.slot(lane);
    _replaceSlot(
      lane,
      ServerRuntimeSlotState(
        serverId: normalized,
        phase: ServerRuntimePhase.connecting,
        generation: current.generation + 1,
      ),
    );
  }

  void commit(ServerRuntimeLane lane, String serverId) {
    final normalized = serverId.trim();
    if (normalized.isEmpty) return;
    final current = state.slot(lane);
    _replaceSlot(
      lane,
      ServerRuntimeSlotState(
        serverId: normalized,
        phase: ServerRuntimePhase.ready,
        generation: current.generation,
      ),
      visibleLane: lane,
    );
  }

  void showLane(ServerRuntimeLane lane) {
    if (!state.slot(lane).hasServer || state.visibleLane == lane) return;
    state = ServerRuntimeState(
      media: state.media,
      files: state.files,
      visibleLane: lane,
    );
  }

  void restore(
    ServerRuntimeLane lane,
    String? serverId, {
    ServerRuntimeLane? visibleLane,
  }) {
    final normalized = serverId?.trim() ?? '';
    final current = state.slot(lane);
    _replaceSlot(
      lane,
      normalized.isEmpty
          ? ServerRuntimeSlotState(generation: current.generation + 1)
          : ServerRuntimeSlotState(
              serverId: normalized,
              phase: ServerRuntimePhase.ready,
              generation: current.generation + 1,
            ),
      visibleLane: visibleLane,
    );
  }

  void clearLane(ServerRuntimeLane lane) {
    final current = state.slot(lane);
    final other = lane == ServerRuntimeLane.media
        ? ServerRuntimeLane.files
        : ServerRuntimeLane.media;
    final nextVisible = state.visibleLane == lane
        ? (state.slot(other).hasServer ? other : null)
        : state.visibleLane;
    _replaceSlot(
      lane,
      ServerRuntimeSlotState(generation: current.generation + 1),
      visibleLane: nextVisible,
      preserveVisibleWhenNull: false,
    );
  }

  void clearAll() {
    state = ServerRuntimeState(
      media: ServerRuntimeSlotState(generation: state.media.generation + 1),
      files: ServerRuntimeSlotState(generation: state.files.generation + 1),
    );
  }

  void _replaceSlot(
    ServerRuntimeLane lane,
    ServerRuntimeSlotState slot, {
    ServerRuntimeLane? visibleLane,
    bool preserveVisibleWhenNull = true,
  }) {
    state = ServerRuntimeState(
      media: lane == ServerRuntimeLane.media ? slot : state.media,
      files: lane == ServerRuntimeLane.files ? slot : state.files,
      visibleLane: visibleLane ??
          (preserveVisibleWhenNull ? state.visibleLane : null),
    );
  }
}

final mediaRuntimeConfigProvider = Provider<ServerConfig?>((ref) {
  final config = ref.watch(serverConfigProvider);
  final serverId = ref.watch(
    serverRuntimeProvider.select((runtime) => runtime.media.serverId),
  );
  return config?.scopedTo(serverId);
});

final fileRuntimeConfigProvider = Provider<ServerConfig?>((ref) {
  final config = ref.watch(serverConfigProvider);
  final serverId = ref.watch(
    serverRuntimeProvider.select((runtime) => runtime.files.serverId),
  );
  return config?.scopedTo(serverId);
});

final visibleRuntimeConfigProvider = Provider<ServerConfig?>((ref) {
  final lane = ref.watch(
    serverRuntimeProvider.select((runtime) => runtime.visibleLane),
  );
  return switch (lane) {
    ServerRuntimeLane.media => ref.watch(mediaRuntimeConfigProvider),
    ServerRuntimeLane.files => ref.watch(fileRuntimeConfigProvider),
    null => null,
  };
});

ServerRuntimeLane runtimeLaneForProject(ServerProject project) =>
    project.isFileSource ? ServerRuntimeLane.files : ServerRuntimeLane.media;
