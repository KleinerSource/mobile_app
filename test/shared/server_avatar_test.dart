import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  testWidgets('文件源服务器无头像时使用默认图片头像', (tester) async {
    final cases = <(ServerProject, String, String)>[
      (ServerProject.smb, 'assets/server_avatars/green_folder.png', 'SMB'),
      (ServerProject.webDav, 'assets/server_avatars/red_folder.png', 'DAV'),
      (ServerProject.openList, 'assets/server_avatars/logo.svg', 'OL'),
    ];
    for (final (project, asset, badge) in cases) {
      await tester.pumpWidget(_wrap(project: project));
      if (project == ServerProject.openList) {
        expect(find.byType(SvgPicture), findsOneWidget, reason: project.name);
      } else {
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as AssetImage).assetName,
          asset,
          reason: project.name,
        );
      }
      expect(find.byType(Icon), findsNothing, reason: project.name);
      expect(find.text('NA'), findsNothing, reason: project.name);
      expect(find.text(badge), findsOneWidget, reason: project.name);
    }
  });

  testWidgets('媒体服务器等其余类型仍用首字母兜底', (tester) async {
    await tester.pumpWidget(_wrap(project: ServerProject.ohMyMedia));
    expect(find.byType(Icon), findsNothing);
    expect(find.text('NA'), findsOneWidget);
  });

  testWidgets('大尺寸 OpenList 头像同样使用 SVG 图片', (tester) async {
    await tester.pumpWidget(_wrap(project: ServerProject.openList, size: 96));
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
