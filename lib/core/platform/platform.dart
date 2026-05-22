import 'package:flutter/material.dart';

export 'app_action_sheet.dart';
export 'app_dialog.dart';
export 'app_nav_bar.dart';
export 'app_scaffold.dart';
export 'app_search_field.dart';
export 'app_tab_bar.dart';
export 'app_theme.dart';

bool isCupertino(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;
