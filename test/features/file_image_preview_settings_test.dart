import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/files/file_image_preview_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
