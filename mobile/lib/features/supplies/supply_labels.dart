import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../care/care_labels.dart' show formatDecimal;
import 'supply.dart';

String supplyCategoryLabel(AppLocalizations l10n, SupplyCategory category) =>
    switch (category) {
      SupplyCategory.dryFood => l10n.supplyCategoryDryFood,
      SupplyCategory.wetFood => l10n.supplyCategoryWetFood,
      SupplyCategory.treats => l10n.supplyCategoryTreats,
      SupplyCategory.litter => l10n.supplyCategoryLitter,
      SupplyCategory.medication => l10n.supplyCategoryMedication,
      SupplyCategory.other => l10n.supplyCategoryOther,
    };

IconData supplyCategoryIcon(SupplyCategory category) => switch (category) {
  SupplyCategory.dryFood => Symbols.rice_bowl_rounded,
  SupplyCategory.wetFood => Symbols.soup_kitchen_rounded,
  SupplyCategory.treats => Symbols.cookie_rounded,
  SupplyCategory.litter => Symbols.layers_rounded,
  SupplyCategory.medication => Symbols.medication_rounded,
  SupplyCategory.other => Symbols.inventory_2_rounded,
};

/// The unit as the user picks it in the form: grams and kilograms,
/// millilitres and litres are the same unit for the server.
enum SupplyInputUnit { gram, kilogram, milliliter, liter, piece, dose }

SupplyUnit storedUnit(SupplyInputUnit unit) => switch (unit) {
  SupplyInputUnit.gram || SupplyInputUnit.kilogram => SupplyUnit.gram,
  SupplyInputUnit.milliliter || SupplyInputUnit.liter => SupplyUnit.milliliter,
  SupplyInputUnit.piece => SupplyUnit.piece,
  SupplyInputUnit.dose => SupplyUnit.dose,
};

/// How many stored units one input unit is: 1000 grams in a kilogram.
double inputFactor(SupplyInputUnit unit) => switch (unit) {
  SupplyInputUnit.kilogram || SupplyInputUnit.liter => 1000,
  _ => 1,
};

/// The input unit an amount reads best in: 2000 g as 2 kg, 400 g as 400 g.
SupplyInputUnit inputUnitFor(SupplyUnit unit, double amount) => switch (unit) {
  SupplyUnit.gram =>
    amount >= 1000 && (amount % 100) == 0
        ? SupplyInputUnit.kilogram
        : SupplyInputUnit.gram,
  SupplyUnit.milliliter =>
    amount >= 1000 && (amount % 100) == 0
        ? SupplyInputUnit.liter
        : SupplyInputUnit.milliliter,
  SupplyUnit.piece => SupplyInputUnit.piece,
  SupplyUnit.dose => SupplyInputUnit.dose,
};

String supplyInputUnitLabel(AppLocalizations l10n, SupplyInputUnit unit) =>
    switch (unit) {
      SupplyInputUnit.gram => l10n.portionUnitGrams,
      SupplyInputUnit.kilogram => l10n.supplyUnitKg,
      SupplyInputUnit.milliliter => l10n.portionUnitMilliliters,
      SupplyInputUnit.liter => l10n.supplyUnitLiters,
      SupplyInputUnit.piece => l10n.portionUnitPieces,
      SupplyInputUnit.dose => l10n.supplyUnitDoses,
    };

/// "2 kg", "400 g", "1.5 l", "12 pcs", "3 doses": an amount in [unit],
/// in kilograms and litres from a thousand up.
String supplyAmount(AppLocalizations l10n, SupplyUnit unit, double amount) {
  String number(double value) => formatDecimal(l10n, _round(value));
  return switch (unit) {
    SupplyUnit.gram when amount >= 1000 => l10n.supplyKg(number(amount / 1000)),
    SupplyUnit.gram => l10n.portionGrams(number(amount)),
    SupplyUnit.milliliter when amount >= 1000 => l10n.supplyLiters(
      number(amount / 1000),
    ),
    SupplyUnit.milliliter => l10n.portionMilliliters(number(amount)),
    SupplyUnit.piece => l10n.portionPieces(number(amount)),
    // Rounded first: 1.004 doses read "1 dose", not "1 doses".
    SupplyUnit.dose when _round(amount) == _round(amount).roundToDouble() =>
      l10n.supplyDoses(_round(amount).round()),
    SupplyUnit.dose => l10n.supplyDosesFraction(number(amount)),
  };
}

/// "≈ 1.5 pkg": an amount counted in packages.
String supplyPackages(AppLocalizations l10n, double packages) =>
    l10n.supplyPackages(formatDecimal(l10n, (packages * 10).round() / 10));

/// Two decimals at most, fewer for big amounts (1234.5678 g is 1234.6 g),
/// two significant digits for small ones (a collar's 0.004167 a day is
/// 0.0042, not 0).
double _round(double value) => value >= 100
    ? (value * 10).round() / 10
    : value >= 1 || value == 0
    ? (value * 100).round() / 100
    : double.parse(value.toStringAsPrecision(2));

/// Whether [digits] are a GTIN (EAN-8, UPC-A, EAN-13, GTIN-14) with a right
/// check digit: from the right, without it, the digits weigh 3, 1, 3, 1…
bool isValidGtin(String digits) {
  if (!RegExp(r'^(\d{8}|\d{12,14})$').hasMatch(digits)) return false;
  var sum = 0;
  var weight = 3;
  for (var i = digits.length - 2; i >= 0; i--) {
    sum += (digits.codeUnitAt(i) - 48) * weight;
    weight = 4 - weight;
  }
  return (10 - sum % 10) % 10 == digits.codeUnitAt(digits.length - 1) - 48;
}

/// How long it lasts: "about 20 days", "less than a day".
String supplyDaysLabel(AppLocalizations l10n, double days) =>
    days < 1 ? l10n.supplyLastsLessThanDay : l10n.supplyLastsDays(days.floor());

/// What the list says about an item's stock, e.g. "Buy by Oct 9 · enough for
/// about 10 days". "Time to buy" and "Ran out" are status tags on screen
/// (`SupplyStatusLine`).
String supplyStatusLine(AppLocalizations l10n, Supply supply) {
  final forecast = supply.forecast;
  if (!supply.active) return l10n.supplyInactive;
  final remaining = forecast.remaining;
  final days = forecast.daysLeft;
  return switch (forecast.status) {
    SupplyStatus.outOfStock => l10n.supplyOutOfStock,
    SupplyStatus.buyNow => l10n.supplyTimeToBuy,
    SupplyStatus.soon when days != null && forecast.buyBy != null =>
      l10n.supplySoonLeft(
        _shortDate(l10n, forecast.buyBy!),
        supplyDaysLabel(l10n, days),
      ),
    SupplyStatus.enough when days != null => l10n.supplyEnoughFor(
      supplyDaysLabel(l10n, days),
    ),
    SupplyStatus.noUsage when remaining != null => l10n.supplyLeftNoUsage(
      supplyAmount(l10n, supply.unit, remaining),
    ),
    SupplyStatus.noStock => l10n.supplyNoStock,
    _ => l10n.supplyNoStock,
  };
}

/// "Oct 9" («9 окт.»).
String _shortDate(AppLocalizations l10n, DateTime date) =>
    DateFormat.MMMd(l10n.localeName).format(date);

/// "October 22" («22 октября»).
String supplyLongDate(AppLocalizations l10n, DateTime date) =>
    DateFormat.MMMMd(l10n.localeName).format(date);
