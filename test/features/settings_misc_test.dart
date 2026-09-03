// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/haptic_settings_test.dart
//   - test/features/file_image_preview_settings_test.dart
//   - test/features/shake_error_text_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/features/files/file_image_preview_settings.dart';
import 'package:omm/features/settings/haptic_settings.dart';
import 'package:omm/shared/shake_error_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

// ==================== 原 test/features/haptic_settings_test.dart ====================
void _main_0() {
  test('震动强度可以持久化并恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = HapticSettingsRepository(prefs);

    await repository.save(HapticIntensity.low);

    expect(repository.load(), HapticIntensity.low);
  });
}

// ==================== 原 test/features/file_image_preview_settings_test.dart ====================
void _main_1() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('图片预览默认关闭并可持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(fileImagePreviewProvider), isFalse);

    await container.read(fileImagePreviewProvider.notifier).setEnabled(true);

    expect(container.read(fileImagePreviewProvider), isTrue);
    expect(prefs.getBool('file.image_preview_enabled'), isTrue);

    final restoredContainer = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(restoredContainer.dispose);

    expect(restoredContainer.read(fileImagePreviewProvider), isTrue);
  });
}

// ==================== 原 test/features/shake_error_text_test.dart ====================
void _main_2() {
  testWidgets('错误文字渲染并可随内容更新重建', (tester) async {
    const errorText = '两次输入的密码不一致，请重新设置';

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: Scaffold(body: ShakeErrorText(errorText)),
      ),
    );
    await tester.pump();

    expect(tester.widget<Text>(find.text(errorText)).style?.color, isNotNull);
  });
}

void main() {
  group('haptic_settings', _main_0);
  group('file_image_preview_settings', _main_1);
  group('shake_error_text', _main_2);
}
