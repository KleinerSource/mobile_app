import 'package:omm/l10n/generated/app_localizations.dart';
import 'task_model.dart';

/// 任务名和客户端消息的展示层翻译。
String taskNameLabel(AppL10n l, String name) {
  switch (name) {
    case '字幕转译':
      return l.taskNameTranscribe;
    case '目录扫描':
      return l.taskNameScan;
    case '增量扫描':
      return l.taskNameIncrementalScan;
    case '全量扫描':
      return l.taskNameFullScan;
    case '定时增量扫描':
      return l.taskNameScheduledScan;
    case '音频提取':
      return l.taskNameAudioExtract;
    case 'NFO 同步':
      return l.taskNameNfoSync;
    case '资源扫描':
      return l.taskNameResourceScan;
    case '演员关联同步':
      return l.taskNameActorSync;
    case '预览生成':
      return l.taskNamePreview;
    case '预览图下载':
      return l.taskNamePreviewDownload;
    case '重复番号合并':
      return l.taskNameDuplicateMerge;
    case '后台任务':
      return l.taskNameFallback;
    default:
      return name;
  }
}

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
