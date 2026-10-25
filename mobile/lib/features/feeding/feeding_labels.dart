import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../care/care_labels.dart' show formatDecimal;
import 'feeding.dart';

/// "40 g", «40 г», "2 pcs".
String portionLabel(AppLocalizations l10n, double amount, PortionUnit unit) {
  final value = formatDecimal(l10n, amount);
  return switch (unit) {
    PortionUnit.gram => l10n.portionGrams(value),
    PortionUnit.milliliter => l10n.portionMilliliters(value),
    PortionUnit.piece => l10n.portionPieces(value),
  };
}

/// The short name of a unit, for the unit picker: "g", "ml", "pcs".
String portionUnitLabel(AppLocalizations l10n, PortionUnit unit) =>
    switch (unit) {
      PortionUnit.gram => l10n.portionUnitGrams,
      PortionUnit.milliliter => l10n.portionUnitMilliliters,
      PortionUnit.piece => l10n.portionUnitPieces,
    };

/// What is given: "Royal Canin, 40 g", or just one of them; null when the
/// schedule says neither.
String? feedingWhat(
  AppLocalizations l10n, {
  String? food,
  double? amount,
  PortionUnit? unit,
}) {
  final portion = amount == null || unit == null
      ? null
      : portionLabel(l10n, amount, unit);
  final parts = [?food, ?portion];
  return parts.isEmpty ? null : parts.join(', ');
}

/// "Every day", or the days in short: "Mon, Wed, Fri" («пн, ср, пт»).
String feedingDaysLabel(AppLocalizations l10n, List<int> days) {
  if (days.length == 7) return l10n.feedingEveryDay;
  return [for (final day in days) weekdayShort(l10n, day)].join(', ');
}

/// "Mon" («пн») for [DateTime.monday] and so on, in the app's language.
String weekdayShort(AppLocalizations l10n, int day) =>
    // 2024-01-01 was a Monday.
    DateFormat.E(l10n.localeName).format(DateTime(2024, 1, day));

/// A time of day the way the phone shows times: "08:00" or "8:00 AM".
String timeLabel(BuildContext context, TimeOfDay time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

int minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

/// Calendar days from [from] to [to] (negative when [to] is earlier). Counted
/// on the dates, not in hours: a day with a clock change has 23 or 25 hours.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
