import 'dart:io';

/// 打包前的固定快速集；完整回归仍由独立工作流执行。
const _testFiles = [
  'test/core/api_network_test.dart',
  'test/core/models_test.dart',
  'test/core/server_config_test.dart',
  'test/core/auth_test.dart',
  'test/core/server_runtime_test.dart',
  'test/core/totp_code_test.dart',
  'test/shared/paged_request_coordinator_test.dart',
  'test/shared/auto_preview_controller_test.dart',
  'test/features/security_test.dart',
  'test/features/player/common/player_queue_test.dart',
  'test/tool/version_policy_test.dart',
  'test/tool/prepare_native_test.dart',
];

Future<void> main() async {
  final process = await Process.start(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    ['test', '--no-pub', '--reporter', 'expanded', ..._testFiles],
    workingDirectory: Directory.fromUri(Platform.script.resolve('../')).path,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  exitCode = await process.exitCode;
}
