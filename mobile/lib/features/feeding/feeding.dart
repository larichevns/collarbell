import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/foundation.dart';

import '../files/stored_file.dart';

/// What a portion is measured in.
enum PortionUnit { gram, milliliter, piece }

/// Every day of the week, Monday first ([DateTime.monday] … [DateTime.sunday]).
const everyDay = [1, 2, 3, 4, 5, 6, 7];

/// A pet's feeding schedule: at these times on these days, this food and
/// portion. Times are the household's local time; at each one the server
/// sends a reminder and the Today screen shows a "Fed" button.
@immutable
class FeedingSchedule {
  const FeedingSchedule({
    required this.id,
    required this.petId,
    required this.times,
    required this.days,
    this.food,
    this.amount,
    this.unit,
    this.notes,
    this.active = true,
    this.supplyItemId,
    this.hasUnknownValues = false,
  });

  final String id;
  final String petId;

  /// Earliest first.
  final List<TimeOfDay> times;

  /// Weekdays as [DateTime.weekday] numbers, Monday (1) first.
  final List<int> days;
  final String? food;
  final double? amount;
  final PortionUnit? unit;
  final String? notes;

  /// A paused schedule has no feedings and no reminders.
  final bool active;

  /// The food in supplies it gives: its portions make the food's daily use.
  final String? supplyItemId;

  /// Values from a newer server this app doesn't know: it isn't edited,
  /// because saving would replace them.
  final bool hasUnknownValues;

  bool get isEveryDay => days.length == 7;
}

/// What the feeding form saves.
@immutable
class FeedingInput {
  const FeedingInput({
    required this.times,
    required this.days,
    this.food,
    this.amount,
    this.unit,
    this.notes,
    this.active,
    this.supplyItemId,
  });

  final List<TimeOfDay> times;
  final List<int> days;
  final String? food;
  final double? amount;
  final PortionUnit? unit;
  final String? notes;

  /// Null keeps the schedule as it is (new schedules are active).
  final bool? active;

  /// The food in supplies; its name becomes the schedule's food.
  final String? supplyItemId;
}

/// A feeding marked done (or skipped on purpose), and by whom.
@immutable
class FeedingMark {
  const FeedingMark({
    required this.id,
    required this.routineId,
    required this.date,
    required this.time,
    required this.skipped,
    required this.doneAt,
    required this.byMe,
    this.byName,
  });

  final String id;
  final String routineId;
  final DateTime date;
  final TimeOfDay time;

  /// Skipped on purpose, e.g. no food before surgery.
  final bool skipped;

  /// When it was marked, local time.
  final DateTime doneAt;

  /// The name (or email) of whoever marked it.
  final String? byName;
  final bool byMe;
}

/// Someone else marked this feeding first: [mark] says who and when.
class FeedingAlreadyMarked implements Exception {
  const FeedingAlreadyMarked(this.mark);

  final FeedingMark mark;

  @override
  String toString() => 'FeedingAlreadyMarked(${mark.byName})';
}

/// One feeding of today on the Today screen: a pet at a time, with its mark.
@immutable
class TodayFeeding {
  const TodayFeeding({
    required this.routineId,
    required this.petId,
    required this.petName,
    required this.time,
    this.petPhoto,
    this.food,
    this.amount,
    this.unit,
    this.mark,
  });

  final String routineId;
  final String petId;
  final String petName;
  final StoredFile? petPhoto;
  final TimeOfDay time;
  final String? food;
  final double? amount;
  final PortionUnit? unit;
  final FeedingMark? mark;

  TodayFeeding withMark(FeedingMark? mark) => TodayFeeding(
    routineId: routineId,
    petId: petId,
    petName: petName,
    time: time,
    petPhoto: petPhoto,
    food: food,
    amount: amount,
    unit: unit,
    mark: mark,
  );
}

/// Today's feedings by time of day, earliest first; within a time, the
/// server's order (by pet name).
Map<TimeOfDay, List<TodayFeeding>> feedingsByTime(List<TodayFeeding> items) {
  final groups = <TimeOfDay, List<TodayFeeding>>{};
  for (final item in items) {
    groups.putIfAbsent(item.time, () => []).add(item);
  }
  final times = groups.keys.toList()
    ..sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
  return {for (final time in times) time: groups[time]!};
}

/// The next feeding: the earliest time of today with a pet not fed (and
/// not skipped) yet, with all of that time's pets; null when every
/// feeding of today is marked (Home's "Right now").
List<TodayFeeding>? nextFeeding(List<TodayFeeding> feedings) {
  for (final items in feedingsByTime(feedings).values) {
    if (items.any((item) => item.mark == null)) return items;
  }
  return null;
}
