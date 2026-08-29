import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/server_avatar.dart';

Widget _wrap({required ServerProject? project, double size = 40}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ServerAvatar(
            displayName: 'NAS',
            avatarUrl: null,
            size: size,
            colors: appColors(context),
            project: project,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('文件源服务器无头像时使用协议图标作为默认头像', (tester) async {
    final cases = <(ServerProject, IconData, String)>[
      (ServerProject.smb, Icons.lan, 'SMB'),
      (ServerProject.webDav, Icons.cloud_outlined, 'DAV'),
      (ServerProject.openList, Icons.hub, 'OL'),
    ];
    for (final (project, icon, badge) in cases) {
      await tester.pumpWidget(_wrap(project: project));
      final iconWidget = tester.widget<Icon>(find.byType(Icon));
      expect(iconWidget.icon, icon, reason: project.name);
      // 首字母不再出现，类型徽标保留。
      expect(find.text('NA'), findsNothing, reason: project.name);
      expect(find.text(badge), findsOneWidget, reason: project.name);
    }
  });

  testWidgets('媒体服务器等其余类型仍用首字母兜底', (tester) async {
    await tester.pumpWidget(_wrap(project: ServerProject.ohMyMedia));
    expect(find.byType(Icon), findsNothing);
    expect(find.text('NA'), findsOneWidget);
  });

  testWidgets('大尺寸头像同样使用协议图标', (tester) async {
    await tester.pumpWidget(_wrap(project: ServerProject.openList, size: 96));
    final iconWidget = tester.widget<Icon>(find.byType(Icon));
    expect(iconWidget.icon, Icons.hub);
    expect(iconWidget.size, greaterThan(38));
  });
}
