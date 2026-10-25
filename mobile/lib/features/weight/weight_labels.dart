import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/l10n.dart';
import '../care/care_labels.dart' show formatDecimal, parseDecimal;
import 'weight.dart';

// Localized words of the weight log, used by the Weight tab, the weighing
// sheet, the Overview and the scan review.

/// A weight as the user reads it: "4.235 kg", «4,2 кг», to the gram.
String weightValueLabel(AppLocalizations l10n, double kg) =>
    l10n.recordWeightValue(weightNumberLabel(l10n, kg));

/// The number of a weight without its unit: "4.235", «4,2».
String weightNumberLabel(AppLocalizations l10n, double kg) =>
    // Through whole grams: a double may carry a tail such as 4.2350000001.
    formatDecimal(l10n, (kg * 1000).round() / 1000);

/// A change of [grams]: "+0.2 kg", "−0.15 kg", or "no change".
String weightChangeLabel(AppLocalizations l10n, int grams) {
  if (grams == 0) return l10n.weightNoChange;
  // A true minus sign, as wide as the plus.
  final sign = grams > 0 ? '+' : '\u2212';
  return l10n.recordWeightValue(
    '$sign${formatDecimal(l10n, grams.abs() / 1000)}',
  );
}

/// "BCS 5/9" («Упитанность 5/9»).
String bodyConditionLabel(AppLocalizations l10n, BodyCondition score) =>
    l10n.weightBodyCondition(score.score, score.scale);

/// The ideal scores on [scale]: "4–5" of 9, "3" of 5.
String bodyConditionIdeal(int scale) {
  final (low, high) = BodyCondition.idealOn(scale);
  return low == high ? '$low' : '$low–$high';
}

String weightPeriodLabel(AppLocalizations l10n, WeightPeriod period) =>
    switch (period) {
      WeightPeriod.threeMonths => l10n.weightPeriodThreeMonths,
      WeightPeriod.year => l10n.weightPeriodYear,
      WeightPeriod.all => l10n.weightPeriodAll,
    };

/// "Sep 12" («12 сент.») for a date of this year, "Sep 12, 2025" for an
/// older one.
String weightShortDate(AppLocalizations l10n, DateTime date, DateTime today) =>
    weightDayLabel(l10n, date, withYear: date.year != today.year);

/// "Sep 12, 2025", or "Sep 12" («12 сент.») without the year.
String weightDayLabel(
  AppLocalizations l10n,
  DateTime date, {
  required bool withYear,
}) => withYear
    ? l10n.dateMedium(date)
    : DateFormat.MMMd(l10n.localeName).format(date);

/// The icon of a weight's source: a scale for a weighing, the check-up's
/// icon for a vet's weight.
IconData weightSourceIcon(WeightSource source) => switch (source) {
  WeightSource.careRecord => Symbols.medical_services_rounded,
  WeightSource.weighing || WeightSource.other => Symbols.monitor_weight_rounded,
};

/// "Weighing" or "Vet check-up"; null for a source this app doesn't know.
String? weightSourceLabel(AppLocalizations l10n, WeightSource source) =>
    switch (source) {
      WeightSource.weighing => l10n.weightSourceWeighing,
      WeightSource.careRecord => l10n.weightSourceVet,
      WeightSource.other => null,
    };

/// A number typed with a point or a comma, which may start or end it
/// ("4," while typing, ",5"); a group holds its decimals. "1e2" or "NaN",
/// which `double.tryParse` would take, are not.
final _typedNumber = RegExp(r'^(?:\d+(?:[.,](\d*))?|[.,](\d+))$');

/// What is wrong with a weight typed as [text] in kilograms: null when it
/// is above 0 and up to 200 kg with at most [decimals] decimals, or empty
/// and not [required].
String? weightTextProblem(
  AppLocalizations l10n,
  String text, {
  required int decimals,
  bool required = false,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return required ? l10n.weightRequired : null;
  final match = _typedNumber.firstMatch(trimmed);
  final kg = parseDecimal(trimmed);
  if (match == null || kg == null || kg <= 0 || kg > WeightRules.maxKg) {
    return l10n.recordWeightInvalid;
  }
  // Checked on the text: as a double, 2.2 × 1000 isn't exactly 2200.
  // Zeros at the end say nothing more: "4,250" is 4.25.
  final typed = (match.group(1) ?? match.group(2) ?? '').replaceFirst(
    RegExp(r'0+$'),
    '',
  );
  if (typed.length > decimals) return l10n.weightTooPrecise(decimals);
  return null;
}
