import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/update/update_installer.dart';
import 'package:md_center/core/update/update_models.dart';
import 'package:md_center/core/update/update_service.dart';

void main() {
  test('版本号支持语义版本和 build 号比较', () {
    final current = AppReleaseVersion.parse('0.1.60+67');
    final nextPatch = AppReleaseVersion.parse('md_center_0.1.61+68.apk');
    final nextBuild = AppReleaseVersion.parse('v0.1.60+68');

    expect(current.display, '0.1.60+67');
    expect(nextPatch.compareTo(current), greaterThan(0));
    expect(nextBuild.compareTo(current), greaterThan(0));
    expect(AppReleaseVersion.tryParse('latest'), isNull);
  });

  test('GitHub 地址规范化并生成 Release API 地址', () {
    final repository = GitHubRepository.parse(
      'https://github.com/KleinerSource/mobile_app/releases',
    );

    expect(
      repository.canonicalUrl,
      'https://github.com/KleinerSource/mobile_app',
    );
    expect(
      repository.releasesApiUrl,
      'https://api.github.com/repos/KleinerSource/mobile_app/releases?per_page=100',
    );
    expect(
      repository.releaseTagApiUrl(UpdatePlatform.ios),
      'https://api.github.com/repos/KleinerSource/mobile_app/releases/tags/latest',
    );
    expect(
      repository.releaseTagApiUrl(UpdatePlatform.android),
      'https://api.github.com/repos/KleinerSource/mobile_app/releases/tags/latest-android',
    );
    expect(
      () => GitHubRepository.parse('https://example.com/owner/repo'),
      throwsFormatException,
    );
  });

  test('iOS 安装器 URI 会正确编码 GitHub IPA 下载地址', () {
    const downloadUrl =
        'https://github.com/KleinerSource/mobile_app/releases/download/'
        'latest/md_center_0.1.64+71.ipa';

    final installerUrl = IosUpdateInstaller.installUri(downloadUrl);

    expect(installerUrl.scheme, 'apple-magnifier');
    expect(installerUrl.host, 'install');
    expect(installerUrl.queryParameters['url'], downloadUrl);
  });

  test('按平台从不同 Release 中选择最高版本产物', () {
    final releases = [
      GitHubRelease.fromJson(const {
        'tag_name': 'latest',
        'name': 'iOS build',
        'published_at': '2026-08-10T05:20:00Z',
        'assets': [
          {
            'name': 'md_center_0.1.60+67.ipa',
            'browser_download_url': 'https://github.com/o/r/releases/ipa',
            'size': 100,
          },
        ],
      }),
      GitHubRelease.fromJson(const {
        'tag_name': 'latest-android',
        'name': 'Android build',
        'published_at': '2026-08-10T05:21:00Z',
        'assets': [
          {
            'name': 'md_center_0.1.60+67.apk',
            'browser_download_url': 'https://github.com/o/r/releases/apk',
            'size': 200,
          },
        ],
      }),
      GitHubRelease.fromJson(const {
        'tag_name': 'v0.1.59+66',
        'name': 'Older Android build',
        'published_at': '2026-08-09T05:21:00Z',
        'assets': [
          {
            'name': 'md_center_0.1.59+66.apk',
            'browser_download_url': 'https://github.com/o/r/releases/old',
            'size': 180,
          },
        ],
      }),
    ];

    final ios = GitHubUpdateService.selectLatestCandidate(
      releases,
      UpdatePlatform.ios,
    );
    final android = GitHubUpdateService.selectLatestCandidate(
      releases,
      UpdatePlatform.android,
    );

    expect(
      ios?.version,
      const AppReleaseVersion(major: 0, minor: 1, patch: 60, build: 67),
    );
    expect(ios?.asset.name, 'md_center_0.1.60+67.ipa');
    expect(android?.asset.name, 'md_center_0.1.60+67.apk');
  });

  test('滚动 Release 标签中的 IPA 资产可识别', () {
    final release = GitHubRelease.fromJson(const {
      'tag_name': 'latest',
      'name': 'Latest unsigned iOS build',
      'assets': [
        {
          'name': 'md_center_0.1.73+80.ipa',
          'browser_download_url':
              'https://github.com/o/r/releases/download/latest/md_center_0.1.73%2B80.ipa',
          'size': 100,
        },
      ],
    });

    final candidate = GitHubUpdateService.selectLatestCandidate([
      release,
    ], UpdatePlatform.ios);

    expect(candidate?.asset.name, 'md_center_0.1.73+80.ipa');
    expect(
      candidate?.version,
      const AppReleaseVersion(major: 0, minor: 1, patch: 73, build: 80),
    );
  });

  test('更新说明会移除滚动构建元数据并保留实际内容', () {
    final release = GitHubRelease.fromJson(const {
      'tag_name': 'latest',
      'body': '''版本: 0.12.5+204

本次构建包含以下更新：

fix: 修复服务器切换卡住
 - 增加快速鉴权路径

commit: [d1081e5](https://github.com/example/mobile_app/commit/d1081e5)
run: [308](https://github.com/example/mobile_app/actions/runs/123)''',
    });

    expect(release.updateNotes, 'fix: 修复服务器切换卡住\n - 增加快速鉴权路径');
  });

  test('没有更新说明时返回空内容', () {
    final release = GitHubRelease.fromJson(const {
      'tag_name': 'latest',
      'body': '本次构建包含以下更新：\n\ncommit: abc\nrun: 1',
    });

    expect(release.updateNotes, isEmpty);
  });
}
