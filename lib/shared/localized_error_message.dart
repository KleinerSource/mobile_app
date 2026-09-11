import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/error_codes.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/core/update/update_service.dart';

/// 将客户端生成的错误码翻译成当前语言；服务端返回的业务消息保持原样。
///
/// 异常可能来自 Riverpod、Dio 或 Source 层，因此统一先经过
/// [toApiException] 归一化。只有带 [AppErrorCode] 的客户端兜底错误才会被
/// 翻译，未知消息不会被客户端擅自改写。
String localizedErrorMessage(
  AppL10n l,
  Object error, {
  String? fallback,
  bool translateEmbeddedErrorCodes = false,
}) {
  if (error is UpdateException) return l.errorUpdateFailed;
  final normalized = toApiException(error);
  final localized = _localizedCode(l, normalized.code, normalized);
  if (localized != null) return localized;

  final message = normalized.message.trim();
  if (translateEmbeddedErrorCodes) {
    final embedded = _localizedLineErrorDetails(l, message);
    if (embedded != null) return embedded;
  }
  if (message.isNotEmpty) return message;
  return fallback ?? l.errorOperationFailed;
}

String? _localizedCode(AppL10n l, String? code, ApiException error) {
  return switch (code) {
    AppErrorCode.operationFailed => l.errorOperationFailed,
    AppErrorCode.responseFormatInvalid => l.errorResponseFormatInvalid,
    AppErrorCode.responseDataMissing => l.errorResponseDataMissing,
    AppErrorCode.requestTimeout => l.errorRequestTimeout,
    AppErrorCode.networkUnavailable => l.errorNetworkUnavailable,
    AppErrorCode.routeNotFound => _routeNotFoundMessage(l, error),
    AppErrorCode.validationFailed => l.errorValidationFailed,
    AppErrorCode.httpError => l.errorHttpStatus(error.status ?? 0),
    AppErrorCode.authenticationRequired => l.errorAuthenticationRequired,
    AppErrorCode.fileTransferCanceled => l.errorFileTransferCanceled,
    AppErrorCode.fileSourceNotFound => l.errorFileSourceNotFound,
    AppErrorCode.fileTransferFailed => l.errorFileTransferFailed,
    AppErrorCode.fileTargetExists => l.fileTargetExists,
    AppErrorCode.fileRangeUnsupported => l.errorFileRangeUnsupported,
    AppErrorCode.updateFailed => l.errorUpdateFailed,
    AppErrorCode.connectionClosed => l.errorConnectionClosed,
    AppErrorCode.serverCompatibility => l.errorServerCompatibility,
    AppErrorCode.mediaSourceReferenceInvalid =>
      l.errorMediaSourceReferenceInvalid,
    AppErrorCode.mediaLibraryNotFound => l.errorMediaLibraryNotFound,
    AppErrorCode.feiniuRequestFailed => l.errorFeiniuRequestFailed,
    AppErrorCode.stashApiKeyInvalid => l.errorStashApiKeyInvalid,
    AppErrorCode.stashRequestFailed => l.errorStashRequestFailed,
    AppErrorCode.stashGraphqlFailed => l.errorStashGraphqlFailed,
    AppErrorCode.unsupportedSourceCapability =>
      l.errorUnsupportedSourceCapability,
    AppErrorCode.previewSegmentsInvalid => l.errorPreviewSegmentsInvalid,
    AppErrorCode.previewSegmentDurationInvalid =>
      l.errorPreviewSegmentDurationInvalid,
    AppErrorCode.previewExcludeInvalid => l.errorPreviewExcludeInvalid,
    AppErrorCode.previewPresetInvalid => l.errorPreviewPresetInvalid,
    AppErrorCode.previewSpriteIntervalInvalid =>
      l.errorPreviewSpriteIntervalInvalid,
    AppErrorCode.previewSpriteMinimumInvalid =>
      l.errorPreviewSpriteMinimumInvalid,
    AppErrorCode.previewSpriteMaximumInvalid =>
      l.errorPreviewSpriteMaximumInvalid,
    AppErrorCode.previewSpriteSizeInvalid => l.errorPreviewSpriteSizeInvalid,
    AppErrorCode.ommRequestFailed => l.errorOmmRequestFailed,
    AppErrorCode.ommTranscodeStatusFailed => l.errorOmmTranscodeStatusFailed,
    AppErrorCode.ommSubtitleInvalid => l.errorOmmSubtitleInvalid,
    AppErrorCode.ommSubtitleFetchFailed => l.errorOmmSubtitleFetchFailed,
    AppErrorCode.ommResponseInvalid => l.errorOmmResponseInvalid,
    AppErrorCode.ommLibraryResponseInvalid => l.errorOmmLibraryResponseInvalid,
    AppErrorCode.ommFolderResponseInvalid => l.errorOmmFolderResponseInvalid,
    AppErrorCode.ommPathValidationResponseInvalid =>
      l.errorOmmPathValidationResponseInvalid,
    AppErrorCode.ommScanTaskIdMissing => l.errorOmmScanTaskIdMissing,
    AppErrorCode.ommBatchScanResponseInvalid =>
      l.errorOmmBatchScanResponseInvalid,
    AppErrorCode.ommLibraryIdMissing => l.errorOmmLibraryIdMissing,
    AppErrorCode.ommFolderIdMissing => l.errorOmmFolderIdMissing,
    AppErrorCode.ommSourceIdInvalid => l.errorOmmSourceIdInvalid,
    AppErrorCode.ommIdInvalid => l.errorOmmIdInvalid,
    AppErrorCode.unsupportedResourceType => l.errorUnsupportedResourceType,
    AppErrorCode.taskResponseInvalid => l.errorTaskResponseInvalid,
    AppErrorCode.taskIdMissing => l.errorTaskIdMissing,
    AppErrorCode.previewTaskIdRequired => l.errorPreviewTaskIdRequired,
    AppErrorCode.actorMappingLoadFailed => l.errorActorMappingLoadFailed,
    AppErrorCode.previewTaskCreateFailed => l.errorPreviewTaskCreateFailed,
    AppErrorCode.previewTaskStatusInvalid => l.errorPreviewTaskStatusInvalid,
    AppErrorCode.avatarContentEmpty => l.errorAvatarContentEmpty,
    _ => null,
  };
}

/// 线路探测失败会由 OMM 选择器拼成“线路名：错误码”的多行明细。
/// 仅当每一行都符合这个客户端生成的结构时才翻译，避免改写服务端业务消息。
String? _localizedLineErrorDetails(AppL10n l, String message) {
  if (message.isEmpty) return null;
  final lines = message.split('\n');
  final localizedLines = <String>[];
  for (final line in lines) {
    final separator = line.indexOf('：');
    if (separator <= 0) return null;
    final prefix = line.substring(0, separator).trim();
    final rawCode = line.substring(separator + 1).trim();
    if (prefix.isEmpty || rawCode.isEmpty) return null;
    final code = toApiException(rawCode).code;
    final localized = _localizedCode(
      l,
      code,
      ApiException(rawCode, code: code),
    );
    if (localized == null) return null;
    localizedLines.add('${line.substring(0, separator + 1)}$localized');
  }
  return localizedLines.join('\n');
}

String localizedErrorMessageWithCode(AppL10n l, String message, String? code) {
  return localizedErrorMessage(l, ApiException(message, code: code));
}

String _routeNotFoundMessage(AppL10n l, ApiException error) {
  final details = error.details;
  final method = details?['method']?.toString().trim() ?? '';
  final target = details?['target']?.toString().trim() ?? '';
  if (method.isEmpty || target.isEmpty) return l.errorRouteNotFoundGeneric;
  return l.errorRouteNotFound(method, target);
}
