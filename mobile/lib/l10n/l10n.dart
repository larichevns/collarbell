import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  /// Strings of the current locale: `context.l10n.petsTitle`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
