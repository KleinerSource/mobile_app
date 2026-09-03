import 'package:omm/l10n/generated/app_localizations.dart';

import 'list_model.dart';

String favoriteListDisplayName(AppL10n l, FavoriteList list) {
  return switch (list.id) {
    'all_time_best'
        when _isBuiltinName(list.name, const {'最爱', 'All-time best'}) =>
      l.favoriteListAllTimeBest,
    'after_hours' when _isBuiltinName(list.name, const {'私藏', 'Private'}) =>
      l.favoriteListAfterHours,
    _ => list.name,
  };
}

bool _isBuiltinName(String name, Set<String> defaults) =>
    defaults.contains(name.trim());
