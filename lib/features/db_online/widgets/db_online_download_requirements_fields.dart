import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_watched.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// 两种面板共用下载条件和控件；实体标识、启用及超期仍由订阅面板管理。
class DbOnlineDownloadRequirementsController extends ChangeNotifier {
  DbOnlineDownloadRequirementsController([
    DbOnlineRecheckRequirements initial = const DbOnlineRecheckRequirements(),
  ]) {
    load(initial);
  }

  final minimum = TextEditingController();
  final maximum = TextEditingController();
  final fileCount = TextEditingController();
  final afterDate = TextEditingController();
  String quality = '';
  bool requireSub = false;
  bool requireUncensored = false;
  bool preDownloadMode = false;
  bool washMode = false;

  void load(DbOnlineRecheckRequirements value) {
    quality = value.quality;
    requireSub = value.requireSub;
    requireUncensored = value.requireUncensored;
    preDownloadMode = value.preDownloadMode;
    washMode = value.washMode;
    minimum.text = _number(value.minSizeMb);
    maximum.text = _number(value.maxSizeMb);
    fileCount.text = value.maxFileCount.toString();
    afterDate.text = value.afterDate;
    notifyListeners();
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  void update({
    String? quality,
    bool? requireSub,
    bool? requireUncensored,
    bool? preDownloadMode,
    bool? washMode,
  }) {
    this.quality = quality ?? this.quality;
    this.requireSub = requireSub ?? this.requireSub;
    this.requireUncensored = requireUncensored ?? this.requireUncensored;
    this.preDownloadMode = preDownloadMode ?? this.preDownloadMode;
    this.washMode = washMode ?? this.washMode;
    notifyListeners();
  }

  DbOnlineRecheckRequirements get value => DbOnlineRecheckRequirements(
    quality: quality,
    requireSub: requireSub,
    requireUncensored: requireUncensored,
    preDownloadMode: preDownloadMode,
    washMode: washMode,
    minSizeMb: double.tryParse(minimum.text.trim()) ?? 0,
    maxSizeMb: double.tryParse(maximum.text.trim()) ?? 0,
    maxFileCount: int.tryParse(fileCount.text.trim()) ?? 0,
    afterDate: afterDate.text.trim(),
  );

  String? validationMessage(AppL10n l) {
    final min = double.tryParse(minimum.text.trim());
    final max = double.tryParse(maximum.text.trim());
    if (min == null ||
        max == null ||
        !min.isFinite ||
        !max.isFinite ||
        min < 0 ||
        max < 0 ||
        (max != 0 && max < min)) {
      return l.dbOnlineWatchedInvalidSize;
    }
    final count = int.tryParse(fileCount.text.trim());
    if (count == null || count < 0 || count > 10) {
      return l.dbOnlineWatchedInvalidFiles;
    }
    final date = afterDate.text.trim();
    if (date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      if (date.length != 10 ||
          parsed == null ||
          !parsed.toIso8601String().startsWith(date)) {
        return l.dbOnlineWatchedInvalidDate;
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (final field in [minimum, maximum, fileCount, afterDate]) {
      field.dispose();
    }
    super.dispose();
  }
}

class DbOnlineDownloadRequirementsFields extends StatelessWidget {
  const DbOnlineDownloadRequirementsFields({
    super.key,
    required this.controller,
    this.enabled = true,
    this.qualityTrailing,
  });

  final DbOnlineDownloadRequirementsController controller;
  final bool enabled;
  final Widget? qualityTrailing;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppL10n.of(context);
      final c = controller;
      final dark = Theme.of(context).brightness == Brightness.dark;
      final primary = dark ? const Color(0xFF00F3FF) : const Color(0xFF0099AA);
      final info = dark ? const Color(0xFF4A9EFF) : const Color(0xFF3B82F6);
      final warning = dark ? const Color(0xFFFFC107) : const Color(0xFFF59E0B);
      final secondary = dark
          ? const Color(0xFFA855F7)
          : const Color(0xFF9333EA);

      Widget title(String value) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          value,
          style: AppText.meta(context).copyWith(fontWeight: FontWeight.w700),
        ),
      );
      Widget choice(
        String label,
        bool selected,
        Color color,
        VoidCallback action,
      ) => OutlinedButton(
        onPressed: enabled ? action : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? color : color.withValues(alpha: 0.55),
          backgroundColor: selected
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          side: BorderSide(
            color: color.withValues(alpha: selected ? 0.75 : 0.3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
      Widget field(
        TextEditingController ctrl,
        String label, {
        bool date = false,
      }) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          enabled: enabled,
          keyboardType: date ? TextInputType.datetime : TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title(l.dbOnlineSubscriptionDownloadMode),
          Row(
            children: [
              Expanded(
                child: choice(
                  l.dbOnlineSubscriptionStrictMode,
                  !c.preDownloadMode,
                  primary,
                  () => c.update(preDownloadMode: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: choice(
                  l.dbOnlineSubscriptionPreDownload,
                  c.preDownloadMode,
                  info,
                  () => c.update(preDownloadMode: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          title(l.dbOnlineSubscriptionQuality),
          Row(
            children: [
              Expanded(
                child: choice(
                  l.dbOnlineSubscriptionQualityNormal,
                  c.quality.isEmpty,
                  const Color(0xFF8B95A8),
                  () => c.update(quality: ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: choice(
                  l.dbOnlineSubscriptionQualityHd,
                  c.quality == 'hd',
                  primary,
                  () => c.update(quality: 'hd'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: choice(
                  l.dbOnlineSubscriptionQualityUhd,
                  c.quality == 'uhd',
                  info,
                  () => c.update(quality: 'uhd'),
                ),
              ),
            ],
          ),
          if (qualityTrailing != null) qualityTrailing!,
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              choice(
                l.dbOnlineSubscriptionSubtitle,
                c.requireSub,
                warning,
                () => c.update(requireSub: !c.requireSub),
              ),
              choice(
                l.dbOnlineSubscriptionUncensored,
                c.requireUncensored,
                const Color(0xFFFF0050),
                () => c.update(requireUncensored: !c.requireUncensored),
              ),
              choice(
                l.dbOnlineSubscriptionWashMode,
                c.washMode,
                secondary,
                () => c.update(washMode: !c.washMode),
              ),
            ],
          ),
          const SizedBox(height: 12),
          title(l.dbOnlineSubscriptionFileSize),
          Row(
            children: [
              Expanded(
                child: field(c.minimum, l.dbOnlineSubscriptionMinimumSize),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: field(c.maximum, l.dbOnlineSubscriptionMaximumSize),
              ),
            ],
          ),
          title(l.dbOnlineSubscriptionOtherLimits),
          Row(
            children: [
              Expanded(
                child: field(c.fileCount, l.dbOnlineSubscriptionMaxFiles),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: field(
                  c.afterDate,
                  l.dbOnlineSubscriptionStartDate,
                  date: true,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
