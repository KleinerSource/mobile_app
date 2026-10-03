import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:omm/core/api/providers.dart';
import 'package:omm/core/api/server_connection.dart';
import 'package:omm/core/api/url_resolver.dart';

typedef DbOnlineSchedulerSocket = ({
  Stream<dynamic> stream,
  Future<void> ready,
  Future<void> Function() close,
});
typedef DbOnlineSchedulerConnector = DbOnlineSchedulerSocket Function(Uri uri);

final dbOnlineSchedulerConnectorProvider = Provider<DbOnlineSchedulerConnector>(
  (ref) => (uri) {
    final channel = WebSocketChannel.connect(uri);
    return (
      stream: channel.stream,
      ready: channel.ready,
      close: () async {
        await channel.sink.close();
      },
    );
  },
);

class DbOnlineSchedulerSnapshot {
  const DbOnlineSchedulerSnapshot({
    this.connected = false,
    this.taskId = '',
    this.running = false,
    this.total = 0,
    this.completed = 0,
    this.percent = 0,
    this.queued = const [],
    this.completionRevision = 0,
    this.connectionRevision = 0,
  });
  final bool connected;
  final String taskId;
  final bool running;
  final int total;
  final int completed;
  final double percent;
  final List<String> queued;
  final int completionRevision;
  final int connectionRevision;

  bool get rechecking => taskId == 'video-recheck' && running;
  bool get recheckQueued => queued.contains('video-recheck');

  DbOnlineSchedulerSnapshot connection(bool connected, {bool opened = false}) =>
      DbOnlineSchedulerSnapshot(
        connected: connected,
        taskId: taskId,
        running: running,
        total: total,
        completed: completed,
        percent: percent,
        queued: queued,
        completionRevision: completionRevision,
        connectionRevision: connectionRevision + (opened ? 1 : 0),
      );

  DbOnlineSchedulerSnapshot update(Map<dynamic, dynamic> raw) {
    final progress = raw['progress'];
    int number(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;
    final task = raw['taskId']?.toString() ?? '';
    final active = raw['isRunning'] == true;
    final pending = raw['queuedTasks'];
    final nextQueued = pending is List
        ? pending
              .whereType<Map>()
              .map((item) => item['taskId']?.toString() ?? '')
              .toList()
        : <String>[];
    final finished =
        (rechecking && !(task == 'video-recheck' && active)) ||
        (recheckQueued &&
            !nextQueued.contains('video-recheck') &&
            !(task == 'video-recheck' && active));
    return DbOnlineSchedulerSnapshot(
      connected: connected,
      taskId: task,
      running: active,
      total: progress is Map ? number(progress['total']) : 0,
      completed: progress is Map ? number(progress['completed']) : 0,
      percent: progress is Map
          ? (double.tryParse(progress['percent']?.toString() ?? '') ?? 0).clamp(
              0,
              100,
            )
          : 0,
      queued: nextQueued,
      completionRevision: completionRevision + (finished ? 1 : 0),
      connectionRevision: connectionRevision,
    );
  }
}

/// DBO 广播为裸 camelCase 状态，不能交给 OMM 的任务历史协议解析。
class DbOnlineSchedulerConnection {
  DbOnlineSchedulerConnection({
    required this.uri,
    required this.connect,
    this.reconnectDelay = const Duration(seconds: 2),
  });
  final Uri uri;
  final DbOnlineSchedulerConnector connect;
  final Duration reconnectDelay;
  final _events = StreamController<DbOnlineSchedulerSnapshot>();
  DbOnlineSchedulerSnapshot _snapshot = const DbOnlineSchedulerSnapshot();
  DbOnlineSchedulerSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnect;
  bool _closed = false;
  int _generation = 0;

  Stream<DbOnlineSchedulerSnapshot> get stream => _events.stream;

  void start() => unawaited(_open());

  Future<void> _open() async {
    if (_closed) return;
    final generation = ++_generation;
    var receivedSnapshot = false;
    try {
      final socket = connect(uri);
      _socket = socket;
      _subscription = socket.stream.listen(
        (raw) {
          if (_closed || generation != _generation) return;
          try {
            final data = jsonDecode(raw.toString());
            if (data is Map && data['isRunning'] is bool) {
              _snapshot = _snapshot.update(data);
              if (!receivedSnapshot) {
                receivedSnapshot = true;
                _snapshot = _snapshot.connection(true, opened: true);
              }
              _events.add(_snapshot);
            }
          } on FormatException {
            // 单条异常广播不影响连接和后续状态。
          }
        },
        onError: (Object _, StackTrace __) => _disconnect(generation),
        onDone: () => _disconnect(generation),
      );
      await socket.ready;
      if (_closed || generation != _generation) return;
      _snapshot = _snapshot.connection(true);
      _events.add(_snapshot);
    } catch (_) {
      _disconnect(generation);
    }
  }

  void _disconnect(int generation) {
    if (_closed || generation != _generation) return;
    _generation++;
    final subscription = _subscription;
    final socket = _socket;
    _subscription = null;
    _socket = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (socket != null) unawaited(socket.close());
    _snapshot = _snapshot.connection(false);
    _events.add(_snapshot);
    _reconnect?.cancel();
    _reconnect = Timer(reconnectDelay, _open);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _reconnect?.cancel();
    final subscription = _subscription;
    final socket = _socket;
    if (subscription != null) unawaited(subscription.cancel());
    if (socket != null) unawaited(socket.close());
    unawaited(_events.close());
  }
}

final dbOnlineSchedulerProvider = StreamProvider.autoDispose
    .family<DbOnlineSchedulerSnapshot, String>((ref, serverId) {
      final client = ref.watch(requiredApiClientProvider);
      final config = client.config;
      if (config == null || config.activeServerId != serverId) {
        throw const ServerConnectionClosedException();
      }
      final http = Uri.parse(resolveServerUrl(config, '/ws/scheduler/status'));
      final connection = DbOnlineSchedulerConnection(
        uri: http.replace(scheme: http.scheme == 'https' ? 'wss' : 'ws'),
        connect: ref.watch(dbOnlineSchedulerConnectorProvider),
      );
      ref.onDispose(connection.close);
      connection.start();
      return connection.stream;
    });
