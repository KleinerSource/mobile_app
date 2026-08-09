import 'package:flutter_test/flutter_test.dart';

import '../../tool/version_policy.dart';

void main() {
  test('功能提交递增 patch 版本', () {
    expect(shouldBumpPatchForCommit('feat: 添加演员关联管理'), isTrue);
    expect(shouldBumpPatchForCommit('fix: 修复播放器进度同步'), isTrue);
    expect(shouldBumpPatchForCommit('refactor: 统一设置页样式'), isTrue);
  });

  test('编译失败修复只递增 build 版本', () {
    expect(shouldBumpPatchForCommit('fix: 修复 flutter analyze 错误'), isFalse);
    expect(shouldBumpPatchForCommit('fix: 修复 iOS Xcode 编译失败'), isFalse);
    expect(shouldBumpPatchForCommit('fix(build): 修复 Android 构建错误'), isFalse);
    expect(shouldBumpPatchForCommit('fix: 修复 CI 构建失败 [build-fix]'), isFalse);
  });

  test('纯 CI 变更不递增 patch', () {
    expect(shouldBumpPatchForCommit('ci: 调整版本号递增逻辑'), isFalse);
    expect(shouldBumpPatchForCommit('chore: 更新 GitHub Actions'), isFalse);
    expect(shouldBumpPatchForCommit('test: 增加版本策略测试'), isFalse);
  });
}
