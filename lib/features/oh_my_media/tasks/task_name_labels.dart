import 'package:omm/l10n/generated/app_localizations.dart';
import 'task_model.dart';

/// 任务名/任务消息的展示层翻译。
///
/// 任务的 `name` 字段同时用于行为判断（canCancel / canRetry / 图标与
/// 颜色分流等），模型层字面值不可改动，因此仅在展示处把已知任务名
/// 映射为本地化文案；未知任务名（如服务器下发的自定义名称）原样返回。
String taskNameLabel(AppL10n l, String name) {
  switch (name) {
    case '字幕转译':
      return l.taskNameTranscribe;
    case '目录扫描':
      return l.taskNameScan;
    case '音频提取':
      return l.taskNameAudioExtract;
    case 'NFO 同步':
      return l.taskNameNfoSync;
    case '资源扫描':
      return l.taskNameResourceScan;
    case '演员关联同步':
      return l.taskNameActorSync;
    case '后台任务':
      return l.taskNameFallback;
    default:
      return name;
  }
}

/// 客户端生成的任务消息码 -> 本地化文案；服务器原文原样返回。
String taskMessageLabel(AppL10n l, String message) {
  if (message.startsWith(kTaskMsgScanQueuedAtPrefix)) {
    final position = int.tryParse(
      message.substring(kTaskMsgScanQueuedAtPrefix.length),
    );
    if (position != null) return l.taskMsgScanQueuedAt(position);
  }
  switch (message) {
    case kTaskMsgScanPreparing:
      return l.taskMsgScanPreparing;
    case kTaskMsgScanQueued:
      return l.taskMsgScanQueued;
    case kTaskMsgCanceled:
      return l.taskMsgCanceled;
    case kTaskMsgRequeued:
      return l.taskMsgRequeued;
    default:
      return message;
  }
}

/// 取消/重试失败的兜底错误码 -> 本地化文案；服务器原文原样返回。
String taskErrorLabel(AppL10n l, String message) {
  switch (message) {
    case kTaskErrCancelTranscribe:
      return l.taskErrCancelTranscribe;
    case kTaskErrCancelExtract:
      return l.taskErrCancelExtract;
    case kTaskErrRetryTranscribe:
      return l.taskErrRetryTranscribe;
    default:
      return message;
  }
}
