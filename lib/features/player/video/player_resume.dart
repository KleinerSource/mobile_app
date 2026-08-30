import '../../../core/models/watch_record.dart';

int resolveResumePosition({
  required bool enabled,
  required int explicitPositionSec,
  WatchRecord? record,
}) {
  if (!enabled) return 0;
  if (explicitPositionSec > 0) return explicitPositionSec;
  return record?.resumePositionSec ?? 0;
}
