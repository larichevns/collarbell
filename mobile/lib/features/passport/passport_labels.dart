import '../../l10n/l10n.dart';
import 'passport.dart';

String passportModelLabel(AppLocalizations l10n, PassportModel model) =>
    switch (model) {
      PassportModel.eu2014 => l10n.passportModelEu2014,
      PassportModel.eu2026 => l10n.passportModelEu2026,
      PassportModel.other => l10n.passportModelOther,
    };

/// A contact as lines of text: name, address, phone, email.
String contactLines(PassportContact contact) => [
  contact.name,
  contact.address,
  contact.phone,
  contact.email,
].whereType<String>().join('\n');
