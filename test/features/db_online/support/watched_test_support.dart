import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/features/db_online/pages/db_online_watched_page.dart';
import 'package:omm/features/db_online/providers/db_online_scheduler_provider.dart';

import 'following_test_support.dart';

Map<String, dynamic> watchedMovie(int id, {bool playable = false}) => {
  'id': 'watched-$id',
  'number': 'WATCH-$id',
  'title': '看过影片 $id',
  'can_play': playable,
  'has_cnsub': true,
  'magnets_count': 2,
};
Map<String, dynamic> watchedPayload(List<Map<String, dynamic>> movies) => {
  'success': true,
  'data': {
    'data': {'movies': movies},
  },
};

class WatchedTestBackend extends FollowingTestBackend {
  List<Map<String, dynamic>> movies = [watchedMovie(1)];
  final pages = <int, List<Map<String, dynamic>>>{};
  Map<String, dynamic> preset = {'enabled': false};
  int recheckTotal = 12;

  @override
  Object response(RequestOptions request) {
    if (request.path == '/subs/watched') {
      final page = int.parse(request.queryParameters['page'].toString());
      return watchedPayload(pages[page] ?? (page == 1 ? movies : []));
    }
    if (request.path == '/subs/preset') {
      return {
        'success': true,
        'data': {'preset': preset},
      };
    }
    if (request.path == '/videos/recheck') {
      return {
        'success': true,
        'data': {'total': recheckTotal},
      };
    }
    return super.response(request);
  }
}

class WatchedTestSocket {
  final incoming = StreamController<dynamic>();
  bool closed = false;
  DbOnlineSchedulerSocket get socket => (
    stream: incoming.stream,
    ready: Future<void>.value(),
    close: () async {
      closed = true;
      await incoming.close();
    },
  );
  void send(Map<String, dynamic> message) => incoming.add(jsonEncode(message));
}

class WatchedTestSockets {
  final sockets = <WatchedTestSocket>[];
  final urls = <Uri>[];
  DbOnlineSchedulerSocket connect(Uri uri) {
    urls.add(uri);
    final socket = WatchedTestSocket();
    sockets.add(socket);
    return socket.socket;
  }
}

Future<ProviderContainer> pumpWatchedTest(
  WidgetTester tester,
  WatchedTestBackend backend, {
  Widget page = const DbOnlineWatchedPage(),
  WatchedTestSockets? sockets,
  Locale locale = const Locale('zh'),
  double textScale = 1,
}) => pumpFollowingTest(
  tester,
  backend,
  page,
  retry: (_, _) => null,
  locale: locale,
  textScale: textScale,
  extraOverrides: [
    dbOnlineSchedulerConnectorProvider.overrideWithValue(
      (sockets ?? WatchedTestSockets()).connect,
    ),
  ],
);

Map<String, dynamic> watchedTask({
  bool running = true,
  int completed = 0,
  int total = 12,
  String task = 'video-recheck',
  bool queued = false,
}) => {
  'isRunning': running,
  'taskId': task,
  'progress': {
    'total': total,
    'completed': completed,
    'percent': completed / total * 100,
  },
  'queuedTasks': queued
      ? [
          {'taskId': 'video-recheck'},
        ]
      : [],
};
