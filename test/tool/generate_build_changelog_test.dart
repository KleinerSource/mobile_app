import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_build_changelog.dart';

void main() {
  group('提交过滤', () {
    test('merge 提交与版本号提交不进入日志', () {
      expect(isMergeCommitSubject('Merge branch \'master\' of somewhere'), isTrue);
      expect(isMergeCommitSubject('Merge pull request #3 from fork/branch'), isTrue);
      expect(isMergeCommitSubject('merge branch dev'), isTrue);
      expect(isMergeCommitSubject('feat: 新功能'), isFalse);
      expect(isBuildMetadataCommit('chore: bump build metadata to 0.1.0+1 [skip ci]'), isTrue);
      expect(isBuildMetadataCommit('chore: 其他杂项'), isFalse);

      expect(
        changelogEntryLines(
          const ChangelogCommit(
            subject: 'Merge branch \'master\' of https://example.com/repo',
            body: '',
          ),
        ),
        isEmpty,
      );
      expect(
        changelogEntryLines(
          const ChangelogCommit(
            subject: 'chore: bump build metadata to 0.113.5+893 [skip ci]',
            body: '',
          ),
        ),
        isEmpty,
      );
    });

    test('主题命中 GitHub 源信息时整条提交跳过', () {
      expect(
        changelogEntryLines(
          const ChangelogCommit(subject: 'fix: 处理 github.com/foo 链接', body: ''),
        ),
        isEmpty,
      );
      expect(
        changelogEntryLines(
          const ChangelogCommit(subject: 'chore: 同步 KleinerSource 配置', body: ''),
        ),
        isEmpty,
      );
    });

    test('主题尾部 PR 引用被去除', () {
      expect(sanitizeChangelogSubject('feat: 支持新播放器 (#12)'), 'feat: 支持新播放器');
      expect(sanitizeChangelogSubject('fix: 修复 (#1) (#2)'), 'fix: 修复');
      expect(sanitizeChangelogSubject('feat: 普通主题'), 'feat: 普通主题');
    });
  });

  group('正文净化与归一化', () {
    test('丢弃尾注、issue 引用与含源信息的行', () {
      final lines = changelogEntryLines(
        const ChangelogCommit(
          subject: 'feat(db_online): 重构订阅入口',
          body: '订阅按钮改为整宽描边样式\n'
              'Co-authored-by: Someone <someone@example.com>\n'
              'Signed-off-by: Dev <dev@example.com>\n'
              'Closes #42\n'
              'fixes #7\n'
              '参考 https://github.com/foo/bar 实现\n'
              '与媒体库操作按钮视觉统一\n',
        ),
      );
      expect(lines, [
        'feat(db_online): 重构订阅入口',
        ' - 订阅按钮改为整宽描边样式',
        ' - 与媒体库操作按钮视觉统一',
      ]);
    });

    test('既有 Markdown 列表归一化为短横线，空行仅保留正文内部', () {
      final lines = changelogEntryLines(
        const ChangelogCommit(
          subject: 'feat: 多行正文',
          body: '\n- 第一项\n\n  - 第二项\n\n\n',
        ),
      );
      expect(lines, ['feat: 多行正文', ' - 第一项', '', ' - 第二项']);
    });

    test('纯空白正文不产生任何行', () {
      expect(
        changelogEntryLines(
          const ChangelogCommit(subject: 'fix: 小修复', body: ' \n\t\n'),
        ),
        ['fix: 小修复'],
      );
    });
  });

  group('日志汇总与源文件渲染', () {
    test('条目之间以空行分隔，全部被过滤时为空', () {
      final notes = buildChangelogNotes(const [
        ChangelogCommit(subject: 'fix(a): 修复一', body: '说明'),
        ChangelogCommit(subject: 'chore: bump build metadata to 0.1.0+2', body: ''),
        ChangelogCommit(
          subject: 'Merge branch \'master\' of https://example.com/repo',
          body: '',
        ),
        ChangelogCommit(subject: 'feat(b): 功能二', body: ''),
      ]);
      expect(notes, 'fix(a): 修复一\n - 说明\n\nfeat(b): 功能二');

      expect(
        buildChangelogNotes(const [
          ChangelogCommit(
            subject: 'Merge pull request #1 from fork/branch',
            body: '',
          ),
        ]),
        '',
      );
    });

    test('Dart 字符串字面量正确转义', () {
      expect(dartStringLiteral("a'b"), "'a\\'b'");
      expect(dartStringLiteral(r'a\b'), "'a\\\\b'");
      expect(dartStringLiteral(r'a$b'), r"'a\$b'");
      expect(dartStringLiteral('a\nb'), "'a\\nb'");
    });

    test('渲染出的源文件包含版本与日志常量', () {
      final source = renderBuildChangelogSource(
        version: '0.113.5+893',
        notes: 'fix(x): 修复',
      );
      expect(source, contains("kBuildChangelogVersion = '0.113.5+893'"));
      expect(source, contains("kBuildChangelogNotes = 'fix(x): 修复'"));
      expectNoGithubSourceInfo(source);
    });
  });

  group('最终断言拦截泄露', () {
    test('包含 GitHub 域名或仓库身份串时抛出', () {
      expect(
        () => assertNoGithubSourceInfo("const a = 'https://github.com/x/y';"),
        throwsFormatException,
      );
      expect(
        () => assertNoGithubSourceInfo("const a = 'KleinerSource';"),
        throwsFormatException,
      );
      expect(
        () => assertNoGithubSourceInfo("const a = 'someone@users.noreply.github.com';"),
        throwsFormatException,
      );
      expect(
        () => assertNoGithubSourceInfo("const a = '正常内容';"),
        returnsNormally,
      );
    });
  });
}

void expectNoGithubSourceInfo(String source) {
  expect(containsGithubSourceInfo(source), isFalse);
}
