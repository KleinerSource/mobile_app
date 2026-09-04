import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/platform/app_theme.dart';

void main() {
  test('媒体管理器使用既有服务器徽标色', () {
    expect(
      mediaManagerAccentForProject(ServerProject.ohMyMedia),
      const Color(0xFF7C4DFF),
    );
    expect(
      mediaManagerAccentForProject(ServerProject.dbOnline),
      const Color(0xFF0E7490),
    );
    expect(
      mediaManagerAccentForProject(ServerProject.emby),
      const Color(0xFF52B54B),
    );
    expect(
      mediaManagerAccentForProject(ServerProject.jellyfin),
      const Color(0xFFAA5CC3),
    );
    expect(
      mediaManagerAccentForProject(ServerProject.feiniu),
      const Color(0xFF2979FF),
    );
    expect(
      mediaManagerAccentForProject(ServerProject.stash),
      const Color(0xFF394B59),
    );
  });

  test('未选择媒体管理器时回退到 OMM 色值', () {
    expect(mediaManagerAccentForProject(null), AppColors.light.accent);
    expect(
      buildAppTheme(Brightness.dark).colorScheme.primary,
      AppColors.dark.accent,
    );
    expect(
      buildAppTheme(
        Brightness.light,
        project: ServerProject.smb,
      ).colorScheme.primary,
      AppColors.light.accent,
    );
  });

  testWidgets('ColorScheme 与 appColors 使用同一动态强调色', (tester) async {
    for (final brightness in Brightness.values) {
      for (final project in [
        ServerProject.dbOnline,
        ServerProject.emby,
        ServerProject.jellyfin,
        ServerProject.feiniu,
        ServerProject.stash,
      ]) {
        Color? resolvedAccent;
        final theme = buildAppTheme(brightness, project: project);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                resolvedAccent = appColors(context).accent;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(resolvedAccent, theme.colorScheme.primary);
        expect(resolvedAccent, theme.colorScheme.secondary);
      }
    }
  });

  testWidgets('服务器类型变更后主题强调色更新', (tester) async {
    final project = ValueNotifier<ServerProject?>(ServerProject.emby);
    Color? resolvedAccent;

    await tester.pumpWidget(
      ValueListenableBuilder<ServerProject?>(
        valueListenable: project,
        builder: (context, value, child) => MaterialApp(
          theme: buildAppTheme(Brightness.light, project: value),
          home: Builder(
            builder: (context) {
              resolvedAccent = appColors(context).accent;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(resolvedAccent, const Color(0xFF52B54B));

    project.value = ServerProject.dbOnline;
    await tester.pumpAndSettle();
    expect(resolvedAccent, const Color(0xFF0E7490));
    project.dispose();
  });

  testWidgets('没有主题扩展时保持裸 MaterialApp 的 OMM 色板', (tester) async {
    Color? resolvedAccent;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolvedAccent = appColors(context).accent;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolvedAccent, AppColors.light.accent);
  });
}
