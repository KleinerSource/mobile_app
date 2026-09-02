import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/server_avatar.dart';

Widget _wrap({
  required ServerProject? project,
  double size = 40,
  bool showBackground = true,
}) {
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
            showBackground: showBackground,
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
      (ServerProject.openList, 'assets/server_avatars/openlist.svg', 'OL'),
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

  testWidgets('SMB 和 WebDAV 文件夹头像内容缩小 20%', (tester) async {
    for (final project in [ServerProject.smb, ServerProject.webDav]) {
      await tester.pumpWidget(_wrap(project: project));
      final contentSize = tester.getSize(find.byType(ClipOval));
      final imageSize = tester.getSize(find.byType(Image));
      expect(imageSize.width, closeTo(contentSize.width * 0.8, 0.1));
      expect(imageSize.height, closeTo(contentSize.height * 0.8, 0.1));
    }
  });

  testWidgets('DBO 服务器无头像时使用默认图片头像', (tester) async {
    await tester.pumpWidget(_wrap(project: ServerProject.dbOnline));
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/server_avatars/dbonline.jpg',
    );
    expect(find.text('DBO'), findsOneWidget);
    expect(find.text('NA'), findsNothing);
  });

  testWidgets('OMM 服务器无头像时使用项目图标', (tester) async {
    await tester.pumpWidget(_wrap(project: ServerProject.ohMyMedia));
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/server_avatars/oh_my_media.png',
    );
    expect(find.text('OMM'), findsOneWidget);
    expect(find.text('NA'), findsNothing);
  });

  testWidgets('飞牛影视服务器无头像时使用默认图片头像', (tester) async {
    await tester.pumpWidget(_wrap(project: ServerProject.feiniu));
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/server_avatars/fnos.png',
    );
    expect(find.text('FN'), findsOneWidget);
    expect(find.text('NA'), findsNothing);
  });

  testWidgets('未识别服务器类型仍用首字母兜底', (tester) async {
    await tester.pumpWidget(_wrap(project: null));
    expect(find.byType(Icon), findsNothing);
    expect(find.text('NA'), findsOneWidget);
  });

  testWidgets('大尺寸 OpenList 头像同样使用 SVG 图片', (tester) async {
    await tester.pumpWidget(_wrap(project: ServerProject.openList, size: 96));
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('可关闭快捷入口头像的紫色背景', (tester) async {
    await tester.pumpWidget(
      _wrap(project: ServerProject.ohMyMedia, showBackground: false),
    );

    final decorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any((decoration) => decoration.gradient != null),
      isFalse,
    );
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('项目 badge 不拦截头像点击和长按', (tester) async {
    var tapped = false;
    var longPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GestureDetector(
              onTap: () => tapped = true,
              onLongPress: () => longPressed = true,
              child: Builder(
                builder: (context) => ServerAvatar(
                  displayName: 'NAS',
                  avatarUrl: null,
                  size: 40,
                  colors: appColors(context),
                  project: ServerProject.smb,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final badgeCenter = tester.getCenter(find.text('SMB'));
    await tester.tapAt(badgeCenter);
    expect(tapped, isTrue);

    final longPressGesture = await tester.startGesture(badgeCenter);
    await tester.pump(kLongPressTimeout);
    await longPressGesture.up();
    expect(longPressed, isTrue);
  });
}
