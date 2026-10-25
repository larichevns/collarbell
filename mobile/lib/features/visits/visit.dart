import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/foundation.dart';

import '../care/care.dart';
import '../files/stored_file.dart';

enum VisitType { vet, grooming, training, other }

enum VisitStatus { planned, done, cancelled }

/// A visit to the vet, the groomer and so on: a date and time in the
/// household's time zone, a place, the pets. Reminders come before it
/// ([remindMinutesBefore]); after it, "The visit took place" can turn it
/// into care records.
@immutable
class Visit {
  const Visit({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.time,
    required this.petIds,
    required this.remindMinutesBefore,
    required this.status,
    this.durationMinutes,
    this.location,
    this.notes,
    this.recordIds = const [],
    this.hasUnknownValues = false,
  });

  final String id;
  final VisitType type;
  final String title;

  /// The calendar date (midnight) and the time, in the household's zone.
  final DateTime date;
  final TimeOfDay time;
  final List<String> petIds;

  /// Reminders this many minutes before; a day and two hours by default.
  final List<int> remindMinutesBefore;
  final VisitStatus status;
  final int? durationMinutes;
  final String? location;
  final String? notes;

  /// The care records made when it took place.
  final List<String> recordIds;

  /// Values from a newer server this app doesn't know: it isn't edited.
  final bool hasUnknownValues;

  /// The date and time together, for sorting and "in 2 hours".
  DateTime get startsAt =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// What the visit form saves.
@immutable
class VisitInput {
  const VisitInput({
    required this.type,
    required this.title,
    required this.date,
    required this.time,
    required this.petIds,
    required this.remindMinutesBefore,
    this.durationMinutes,
    this.location,
    this.notes,
    this.status,
  });

  final VisitType type;
  final String title;
  final DateTime date;
  final TimeOfDay time;
  final List<String> petIds;
  final List<int> remindMinutesBefore;

  /// Not edited in the app yet; sent back as it was, so it isn't lost.
  final int? durationMinutes;
  final String? location;
  final String? notes;

  /// Only to cancel a visit or plan it again; null keeps it.
  final VisitStatus? status;
}

/// The kinds of care record a visit can become.
const visitRecordKinds = [
  CareKind.vetExam,
  CareKind.dental,
  CareKind.grooming,
  CareKind.procedure,
  CareKind.other,
];

/// The record a visit of this type usually becomes, or null for none.
CareKind? defaultRecordKind(VisitType type) => switch (type) {
  VisitType.vet => CareKind.vetExam,
  VisitType.grooming => CareKind.grooming,
  VisitType.training || VisitType.other => null,
};

/// A planned visit on the Today screen.
@immutable
class TodayVisit {
  const TodayVisit({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.time,
    required this.daysAway,
    required this.pets,
    this.location,
  });

  final String id;
  final VisitType type;
  final String title;
  final DateTime date;
  final TimeOfDay time;

  /// Negative for a past visit not marked yet.
  final int daysAway;
  final List<TodayVisitPet> pets;
  final String? location;
}

@immutable
class TodayVisitPet {
  const TodayVisitPet({required this.id, required this.name, this.photo});

  final String id;
  final String name;
  final StoredFile? photo;
}
