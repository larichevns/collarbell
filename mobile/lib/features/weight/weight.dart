/// A pet's weight log: its weighings and the weights a vet noted at
/// check-ups, and the rules the Weight tab needs before the server answers
/// (the server's limits, the chart's periods, the change between weights).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../pets/pet.dart';

/// Where a weight of the log comes from.
enum WeightSource {
  /// A weighing of the log itself: added, changed and deleted on the Weight
  /// tab.
  weighing,

  /// The weight a vet noted in a check-up record: it is changed in that
  /// record, whose id the entry has.
  careRecord,

  /// A source this app doesn't know yet (from a newer server): shown, but
  /// not opened.
  other,
}

/// A body condition score: how lean or heavy the pet looks and feels, on
/// the 9-point scale vets use (WSAVA) or the older 5-point one. Weight alone
/// doesn't say whether it is right for the pet; the score does.
@immutable
class BodyCondition {
  const BodyCondition(this.score, this.scale);

  /// The scales the server takes, the usual one first.
  static const scales = [9, 5];

  /// From 1 (very thin) to [scale] (obese).
  final int score;

  /// 9 or 5.
  final int scale;

  /// The ideal scores on [scale]: 4–5 of 9, 3 of 5.
  static (int, int) idealOn(int scale) => scale == 5 ? (3, 3) : (4, 5);

  /// A scale and a score this app can show and edit.
  bool get isKnown => scales.contains(scale) && score >= 1 && score <= scale;

  @override
  bool operator ==(Object other) =>
      other is BodyCondition && other.score == score && other.scale == scale;

  @override
  int get hashCode => Object.hash(score, scale);

  @override
  String toString() => 'BodyCondition($score/$scale)';
}

/// One weight of a pet's log: a weighing, or the weight a vet noted at a
/// check-up.
@immutable
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.petId,
    required this.source,
    required this.measuredOn,
    required this.weightKg,
    required this.createdAt,
    this.bodyCondition,
    this.note,
    this.hasUnknownValues = false,
  });

  /// For a vet's weight, the id of its care record.
  final String id;
  final String petId;
  final WeightSource source;

  /// A calendar date.
  final DateTime measuredOn;

  /// To the gram; a vet's, to 10 g.
  final double weightKg;

  /// Only a weighing has one.
  final BodyCondition? bodyCondition;

  /// The user's note; for a vet's weight, the title of its record.
  final String? note;

  /// When it was added: weighings of the same day are ordered by it.
  final DateTime createdAt;

  /// A source or a body condition score this app doesn't know (from a newer
  /// server): the weighing isn't edited, because saving would replace them.
  final bool hasUnknownValues;

  /// [weightKg] in whole grams. Changes are worked out on grams: as
  /// doubles, 4.3 − 4.1 is 0.19999… kg.
  int get grams => (weightKg * 1000).round();

  bool get isWeighing => source == WeightSource.weighing;

  bool get isVet => source == WeightSource.careRecord;

  @override
  String toString() => 'WeightEntry($id, $weightKg kg, $measuredOn)';
}

/// What the weighing sheet saves.
@immutable
class WeighingInput {
  const WeighingInput({
    required this.measuredOn,
    required this.weightKg,
    this.bodyCondition,
    this.note,
  });

  final DateTime measuredOn;
  final double weightKg;
  final BodyCondition? bodyCondition;
  final String? note;
}

/// The server's limits; checked in the app so mistakes show before saving.
abstract final class WeightRules {
  /// The heaviest weight the server takes: a giant breed is about 100 kg,
  /// so more is a typo (grams typed as kilograms).
  static const maxKg = 200.0;

  /// A weighing is kept to the gram.
  static const weighingDecimals = 3;

  /// A check-up record keeps its weight to 10 g.
  static const recordDecimals = 2;

  static const maxNote = 500;

  /// No weighing is older than this, as for care records.
  static final earliestDate = DateTime(1990);

  /// The first date a weighing of [pet] can have: its birth date when that
  /// is exact, else 1990; never after [today].
  static DateTime firstDateFor(Pet pet, DateTime today) {
    // An approximate birth date says nothing for sure.
    final birth = pet.birthDateApproximate ? null : pet.birthDate;
    final first = birth != null && birth.isAfter(earliestDate)
        ? birth
        : earliestDate;
    return first.isAfter(today) ? today : first;
  }
}

/// Newest first, as the log is shown and the server sends it: by date, then
/// the one added later first.
int newestFirst(WeightEntry a, WeightEntry b) {
  final byDate = b.measuredOn.compareTo(a.measuredOn);
  return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
}

/// The change of the weight at [index] of [log] (newest first) from the one
/// before it in time, in grams; null for the oldest.
int? changeAt(List<WeightEntry> log, int index) =>
    index + 1 < log.length ? log[index].grams - log[index + 1].grams : null;

/// How far back the chart looks, up to today.
enum WeightPeriod {
  threeMonths(3),
  year(12),

  /// The whole log.
  all(null);

  const WeightPeriod(this.months);

  final int? months;

  /// The first day of the period that ends on [today]; null for [all].
  DateTime? startOn(DateTime today) {
    final months = this.months;
    return months == null ? null : monthsBefore(today, months);
  }
}

/// The periods to choose from for a log whose oldest weight is from
/// [oldest]. A period that would show the same as a longer one is left out,
/// so a log of the last three months has nothing to choose (empty).
List<WeightPeriod> weightPeriodsFor(DateTime oldest, DateTime today) {
  final shorter = [
    for (final period in WeightPeriod.values)
      if (period.startOn(today) case final start? when oldest.isBefore(start))
        period,
  ];
  return shorter.isEmpty ? const [] : [...shorter, WeightPeriod.all];
}

/// The period the chart starts with: the last year when the log is longer
/// and that year has two weights or more to draw, else all of it.
WeightPeriod defaultWeightPeriod(
  List<WeightPeriod> periods,
  List<WeightEntry> log,
  DateTime today,
) =>
    periods.contains(WeightPeriod.year) &&
        weightsIn(log, WeightPeriod.year, today).length >= 2
    ? WeightPeriod.year
    : WeightPeriod.all;

/// The weights of [log] in [period] up to [today], in the log's order.
List<WeightEntry> weightsIn(
  List<WeightEntry> log,
  WeightPeriod period,
  DateTime today,
) {
  final start = period.startOn(today);
  if (start == null) return log;
  return [
    for (final entry in log)
      if (!entry.measuredOn.isBefore(start)) entry,
  ];
}

/// The same day [months] months before [date], or the month's last day when
/// it is shorter: 31 May minus three months is 28 (or 29) February.
DateTime monthsBefore(DateTime date, int months) {
  // DateTime counts month 0 as December of the year before.
  final month = DateTime(date.year, date.month - months);
  // Day 0 of the following month is the last day of this one.
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, math.min(date.day, lastDay));
}
