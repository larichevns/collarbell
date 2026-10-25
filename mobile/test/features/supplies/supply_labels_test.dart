// How amounts of supplies read: doses rounded before their form is picked,
// so a tiny remainder of arithmetic never shows as "1 doses".
import 'package:collarbell/features/supplies/supply.dart';
import 'package:collarbell/features/supplies/supply_labels.dart';
import 'package:collarbell/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations ru;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ru = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  test('doses that round to a whole number read as whole doses', () {
    expect(supplyAmount(en, SupplyUnit.dose, 1.004), en.supplyDoses(1));
    expect(supplyAmount(ru, SupplyUnit.dose, 4.998), ru.supplyDoses(5));
    expect(supplyAmount(en, SupplyUnit.dose, 3), en.supplyDoses(3));
    // A real fraction stays one.
    expect(
      supplyAmount(en, SupplyUnit.dose, 1.5),
      en.supplyDosesFraction('1.5'),
    );
  });
}
