import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message ?? AppL10n.of(context).commonNoData),
      ),
    );
  }
}
