import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/core/api/server_compatibility.dart';

void main() {
  test('带 /v 的线路优先使用飞牛版本接口', () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requests.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/v/api/v1/sys/version') {
        request.response.write(
          jsonEncode({
            'code': 0,
            'data': {'version': '0.8.0', 'mediasrvVersion': '1.0.0'},
          }),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      request.response.close();
    });

    try {
      final result = await probeServerLine(
        ServerLine(
          id: 'feiniu-v',
          name: '飞牛影视',
          baseUrl: 'http://127.0.0.1:${server.port}/v',
        ),
      );

      expect(result.success, isTrue);
      expect(result.versionInfo?.project, ServerProject.feiniu);
      expect(requests, ['/v/api/v1/sys/version']);
    } finally {
      await server.close(force: true);
    }
  });

  test('已知飞牛项目的根地址线路只使用飞牛版本接口', () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requests.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/v/api/v1/sys/version') {
        request.response.write(
          jsonEncode({
            'code': 0,
            'data': {'version': '0.8.0'},
          }),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      request.response.close();
    });

    try {
      final result = await ServerLineProbeCoordinator().probe(
        ServerLine(
          id: 'feiniu-root',
          name: '飞牛影视',
          baseUrl: 'http://127.0.0.1:${server.port}',
        ),
        expectedProjectName: ServerProject.feiniu.projectName,
      );

      expect(result.success, isTrue);
      expect(result.versionInfo?.project, ServerProject.feiniu);
      expect(requests, ['/v/api/v1/sys/version']);
    } finally {
      await server.close(force: true);
    }
  });

  test('已知 Emby 项目不请求通用 /api/version', () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requests.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/System/Info/Public') {
        request.response.write(
          jsonEncode({'Version': '4.8.0.80', 'ProductName': 'Emby Server'}),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      request.response.close();
    });

    try {
      final result = await ServerLineProbeCoordinator().probe(
        ServerLine(
          id: 'emby',
          name: 'Emby',
          baseUrl: 'http://127.0.0.1:${server.port}',
        ),
        expectedProjectName: ServerProject.emby.projectName,
      );

      expect(result.success, isTrue);
      expect(result.versionInfo?.project, ServerProject.emby);
      expect(requests, ['/System/Info/Public']);
    } finally {
      await server.close(force: true);
    }
  });

  test('已知 Jellyfin 项目不请求通用 /api/version', () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requests.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/System/Info/Public') {
        request.response.write(
          jsonEncode({'Version': '10.8.0', 'ProductName': 'Jellyfin Server'}),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      request.response.close();
    });

    try {
      final result = await ServerLineProbeCoordinator().probe(
        ServerLine(
          id: 'jellyfin',
          name: 'Jellyfin',
          baseUrl: 'http://127.0.0.1:${server.port}',
        ),
        expectedProjectName: ServerProject.jellyfin.projectName,
      );

      expect(result.success, isTrue);
      expect(result.versionInfo?.project, ServerProject.jellyfin);
      expect(requests, ['/System/Info/Public']);
    } finally {
      await server.close(force: true);
    }
  });
}
