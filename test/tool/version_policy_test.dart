import 'package:flutter_test/flutter_test.dart';

import '../../tool/version_policy.dart';

void main() {
  test('功能提交递增第二位并重置第三位', () {
    expect(
      versionBumpForCommit('feat: 添加演员关联管理'),
      VersionBump.feature,
    );
    expect(versionBumpForCommit('remove: 删除旧的播放器入口'), VersionBump.feature);
    expect(versionBumpForCommit('enhance: 增强字幕调节能力'), VersionBump.feature);
    expect(versionBumpForCommit('删除: 移除旧的播放器入口'), VersionBump.feature);
    expect(versionBumpForCommit('增强: 增加字幕调节能力'), VersionBump.feature);
    expect(versionBumpForCommit('新增功能: 添加服务器多线路'), VersionBump.feature);
    expect(nextAppVersion('0.1.111+125', VersionBump.feature), '0.2.0+126');
  });

  test('优化、改进和修复提交只递增第三位', () {
    expect(
      versionBumpForCommit('fix: 修复播放器进度同步'),
      VersionBump.bugFix,
    );
    expect(nextAppVersion('0.2.0+126', VersionBump.bugFix), '0.2.1+127');
    expect(
      shouldBumpPatchForCommit('refactor: 统一设置页样式'),
      isTrue,
    );
    expect(
      versionBumpForCommit('优化: 调整预览图灯箱交互'),
      VersionBump.bugFix,
    );
    expect(versionBumpForCommit('改进: 优化字幕设置布局'), VersionBump.bugFix);
    expect(versionBumpForCommit('refactor: 统一播放器状态处理'), VersionBump.bugFix);
    expect(nextAppVersion('0.2.0+126', VersionBump.bugFix), '0.2.1+127');
  });

  test('不同递增类型都会继续堆叠 build 号', () {
    expect(nextAppVersion('0.2.0+126', VersionBump.feature), '0.3.0+127');
    expect(nextAppVersion('0.3.0+127', VersionBump.bugFix), '0.3.1+128');
    expect(nextAppVersion('0.3.1+128', VersionBump.buildOnly), '0.3.1+129');
  });

  test('编译失败修复只递增 build 版本', () {
    expect(
      versionBumpForCommit('fix: 修复 flutter analyze 错误'),
      VersionBump.buildOnly,
    );
    expect(
      versionBumpForCommit('fix: 修复 iOS Xcode 编译失败'),
      VersionBump.buildOnly,
    );
    expect(
      versionBumpForCommit('fix(build): 修复 Android 构建错误'),
      VersionBump.buildOnly,
    );
    expect(
      nextAppVersion('0.2.1+127', VersionBump.buildOnly),
      '0.2.1+128',
    );
    expect(
      versionBumpForCommit('fix: 修复 CI 构建失败 [build-fix]'),
      VersionBump.buildOnly,
    );
  });

  test('纯 CI 变更不递增 patch', () {
    expect(shouldBumpPatchForCommit('ci: 调整版本号递增逻辑'), isFalse);
    expect(shouldBumpPatchForCommit('chore: 更新 GitHub Actions'), isFalse);
    expect(shouldBumpPatchForCommit('test: 增加版本策略测试'), isFalse);
  });
}
