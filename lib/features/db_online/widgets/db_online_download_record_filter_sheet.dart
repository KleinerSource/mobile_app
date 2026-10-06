import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_download_record.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/sheet_controls.dart';

import 'db_online_download_record_widgets.dart';
import 'db_online_following_widgets.dart';

class DbOnlineDownloadRecordFilterSheet extends StatefulWidget {
  const DbOnlineDownloadRecordFilterSheet({
    super.key,
    required this.filter,
    required this.downloaders,
    required this.isCurrent,
    required this.onChanged,
  });

  final DbOnlineDownloadRecordFilter filter;
  final List<({String value, String label})> downloaders;
  final bool Function() isCurrent;
  final ValueChanged<DbOnlineDownloadRecordFilter> onChanged;

  @override
  State<DbOnlineDownloadRecordFilterSheet> createState() => _FilterState();
}

class _FilterState extends State<DbOnlineDownloadRecordFilterSheet> {
  late DbOnlineDownloadRecordFilter _filter = widget.filter;

  Future<void> _date(bool start) async {
    final value = start ? _filter.startDate : _filter.endDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(value) ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (!mounted || !widget.isCurrent() || selected == null) return;
    final date = selected.toIso8601String().split('T').first;
    _update(
      start
          ? _filter.copyWith(startDate: date)
          : _filter.copyWith(endDate: date),
    );
  }

  void _update(DbOnlineDownloadRecordFilter filter) {
    if (!widget.isCurrent()) return;
    final start = DateTime.tryParse(filter.startDate);
    final end = DateTime.tryParse(filter.endDate);
    if (start != null && end != null && end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(context).dbOnlineDownloadRecordsInvalidDates,
          ),
        ),
      );
      return;
    }
    setState(() => _filter = filter);
    widget.onChanged(filter);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final all = (value: '', label: l.dbOnlineDownloadRecordsAll);
    Widget label(String value) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 3),
      child: Text(value, style: AppText.eyebrow(context)),
    );
    Widget options(
      List<({String value, String label})> values,
      String selected,
      ValueChanged<String> onSelected,
    ) => DbOnlineFollowingButtonRow(
      options: [all, ...values],
      isSelected: (value) => value == selected,
      onSelected: onSelected,
    );
    Widget dateButton(bool start) => OutlinedButton(
      key: ValueKey(start ? 'record-start-date' : 'record-end-date'),
      style: sheetSecondaryButtonStyle(context),
      onPressed: () => _date(start),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            start
                ? l.dbOnlineDownloadRecordsStartDate
                : l.dbOnlineDownloadRecordsEndDate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            start ? _filter.startDate : _filter.endDate,
            maxLines: 2,
            style: AppText.meta(context),
          ),
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: sheetMaxHeight(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              icon: Icons.tune_rounded,
              title: l.dbOnlineDownloadRecordsFilters,
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: dateButton(true)),
                          const SizedBox(width: 10),
                          Expanded(child: dateButton(false)),
                        ],
                      ),
                    ),
                    label(l.dbOnlineDownloadRecordsResourceTypes),
                    DbOnlineFollowingButtonRow(
                      options: [all, ...downloadRecordResourceOptions(l)],
                      isSelected: (value) => value.isEmpty
                          ? _filter.resourceTypes.isEmpty
                          : _filter.resourceTypes.contains(value),
                      onSelected: (value) {
                        final types = _filter.resourceTypes.toSet();
                        if (value.isEmpty) {
                          types.clear();
                        } else if (!types.remove(value)) {
                          types.add(value);
                        }
                        _update(
                          _filter.copyWith(
                            resourceTypes: downloadRecordResourceOptions(l)
                                .map((option) => option.value)
                                .where(types.contains)
                                .toList(),
                          ),
                        );
                      },
                    ),
                    label(l.dbOnlineDownloadRecordsDownloader),
                    options(
                      widget.downloaders,
                      _filter.downloader,
                      (value) => _update(_filter.copyWith(downloader: value)),
                    ),
                    label(l.dbOnlineDownloadRecordsSource),
                    options(
                      downloadRecordSourceOptions(l),
                      _filter.sourceType,
                      (value) => _update(_filter.copyWith(sourceType: value)),
                    ),
                    label(l.dbOnlineDownloadRecordsStatus),
                    options(
                      [
                        (
                          value: 'true',
                          label: l.dbOnlineDownloadRecordsSuccess,
                        ),
                        (
                          value: 'false',
                          label: l.dbOnlineDownloadRecordsFailed,
                        ),
                      ],
                      _filter.status,
                      (value) => _update(_filter.copyWith(status: value)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
