import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/error_codes.dart';
import 'package:omm/l10n/generated/app_localizations_zh.dart';
import 'package:omm/shared/localized_error_message.dart';

void main() {
  final l = AppL10nZh();

  test('本地错误码显示本地化文本', () {
    expect(
      localizedErrorMessage(
        l,
        ApiException('', code: AppErrorCode.requestTimeout),
      ),
      '请求超时，请稍后重试',
    );
    expect(
      localizedErrorMessage(
        l,
        ApiException('', code: AppErrorCode.networkUnavailable),
      ),
      '网络连接失败，请检查网络连接',
    );
  });

  test('错误码放在 ApiException message 中时也显示本地化文本', () {
    expect(
      localizedErrorMessage(l, ApiException(AppErrorCode.requestTimeout)),
      '请求超时，请稍后重试',
    );
    expect(
      localizedErrorMessage(l, ApiException(AppErrorCode.networkUnavailable)),
      '网络连接失败，请检查网络连接',
    );
  });

  test('OMM 线路错误汇总中的客户端错误码显示本地化文本', () {
    expect(
      localizedErrorMessage(
        l,
        '主线路：${AppErrorCode.requestTimeout}\n备用线路：${AppErrorCode.networkUnavailable}',
        translateEmbeddedErrorCodes: true,
      ),
      '主线路：请求超时，请稍后重试\n备用线路：网络连接失败，请检查网络连接',
    );
  });

  test('服务端业务消息保持原样', () {
    const message = '重复番号影片信息已应用到数据库';
    expect(localizedErrorMessage(l, ApiException(message)), message);
  });

  test('任务消息中的错误码显示本地化文本', () {
    expect(localizedErrorMessage(l, AppErrorCode.requestTimeout), '请求超时，请稍后重试');
    expect(
      localizedErrorMessage(l, AppErrorCode.networkUnavailable),
      '网络连接失败，请检查网络连接',
    );
  });
}
