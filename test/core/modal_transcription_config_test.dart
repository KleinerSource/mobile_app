import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/modal_transcription_config.dart';

void main() {
  test('解析多令牌响应：脱敏凭据不进入草稿，策略与并发字段带回退', () {
    final loaded = ModalTranscriptionConfig.fromJson(const {
      'enabled': false,
      'tokens': [
        {'id': 'tok-1', 'name': '主账号', 'token_id_masked': '********2345'},
        {'id': 'tok-2', 'name': '备用', 'token_id_masked': ''},
      ],
      'token_strategy': 'round_robin',
      'per_token_workers': 4,
      'has_hf_token': true,
      'hf_token': '********abcd',
      'default_gpu': 'H100',
      'repo_branch': 'v1.8',
      'max_workers': 6,
    });

    expect(loaded.tokens, hasLength(2));
    expect(loaded.tokens.first.isExisting, isTrue);
    expect(loaded.tokens.first.tokenId, isEmpty);
    expect(loaded.tokens.first.tokenSecret, isEmpty);
    expect(loaded.tokens.last.tokenIdMasked, isEmpty);
    expect(loaded.hfToken, isEmpty);
    expect(loaded.perTokenWorkers, 4);
    expect(loaded.defaultGpu, 'H100');
    expect(loaded.maxWorkers, 6);
  });

  test('旧版单令牌响应可解析：未知策略回退轮询，字段越界收敛', () {
    final legacy = ModalTranscriptionConfig.fromJson(const {
      'enabled': true,
      'modal_token_id': '********2345',
      'has_modal_token_id': true,
      'token_strategy': 'unknown',
      'per_token_workers': 99,
      'max_workers': 0,
    });

    expect(legacy.tokens, isEmpty);
    expect(legacy.tokenStrategy, 'round_robin');
    expect(legacy.perTokenWorkers, 10);
    expect(legacy.maxWorkers, 1);
    // 旧字段不会被序列化进新协议请求。
    final request = legacy.toRequest();
    expect(request.containsKey('modal_token_id'), isFalse);
    expect(request['tokens'], isEmpty);
  });

  test('新增令牌条目序列化：无 id，凭据按需附带', () {
    const token = ModalTranscriptionToken(
      name: ' 主账号 ',
      tokenId: ' ak-1 ',
      tokenSecret: ' sk-1 ',
    );

    expect(token.isExisting, isFalse);
    expect(token.toEntryJson(), {
      'name': '主账号',
      'token_id': 'ak-1',
      'token_secret': 'sk-1',
    });

    const partial = ModalTranscriptionToken(
      id: 'tok-9',
      name: '只改备注',
      tokenId: '',
      tokenSecret: ' sk-9 ',
    );
    expect(partial.toEntryJson(), {
      'id': 'tok-9',
      'name': '只改备注',
      'token_secret': 'sk-9',
    });
  });

  test('令牌 copyWith 保留未变更字段', () {
    const source = ModalTranscriptionToken(
      id: 'tok-1',
      name: '主账号',
      tokenIdMasked: '********2345',
      tokenSecret: 'sk-1',
    );
    final renamed = source.copyWith(name: '新备注');

    expect(renamed.id, 'tok-1');
    expect(renamed.tokenIdMasked, '********2345');
    expect(renamed.tokenSecret, 'sk-1');
    expect(renamed.name, '新备注');
  });
}
