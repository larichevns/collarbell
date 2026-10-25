import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../files/stored_file.dart';
import '../pets/pet.dart';

/// What kind of care. It decides which fields a record has and which
/// section of the passport it goes to.
enum CareKind {
  vaccination,

  /// Rabies antibody test (passport section VI).
  rabiesTiter,
  deworming,

  /// Tapeworm treatment before travel (passport section VII): the hour
  /// matters, not just the date.
  echinococcus,
  fleaTick,
  heartworm,
  vetExam,
  dental,
  grooming,
  procedure,
  other,
}

enum IntervalUnit { day, week, month, year }

/// What a vaccine protects against; the paper passport lists these for
/// every shot.
enum VaccineTarget {
  rabies,

  // Cats.
  /// Feline panleukopenia.
  fpv,

  /// Feline herpesvirus (rhinotracheitis).
  fhv1,

  /// Feline calicivirus.
  fcv,

  /// Feline leukaemia.
  felv,
  chlamydia,

  // Dogs.
  /// Canine distemper.
  cdv,

  /// Canine adenovirus (hepatitis).
  cav2,

  /// Canine parvovirus.
  cpv2,

  /// Canine parainfluenza.
  cpiv,
  lepto,

  /// Kennel cough.
  bordetella,
  lyme,
  canineInfluenza,
  leishmania,
}

/// Where a plan stands today.
enum CareStatus {
  /// The due date has passed.
  overdue,

  /// Due within [CarePlan.dueSoonDays] days.
  dueSoon,
  upcoming,

  /// Finished (a one-off plan that is done) or paused.
  inactive,
}

/// Where a record came from: typed in, or read from a photo (later).
enum RecordSource { manual, aiScan }

/// "Every [value] [unit]s", e.g. every 3 months.
@immutable
class CareInterval {
  const CareInterval(this.value, this.unit);

  final int value;
  final IntervalUnit unit;

  /// The longest interval the server accepts: ten years.
  static int maxValue(IntervalUnit unit) => switch (unit) {
    IntervalUnit.day => 3650,
    IntervalUnit.week => 520,
    IntervalUnit.month => 120,
    IntervalUnit.year => 10,
  };

  @override
  bool operator ==(Object other) =>
      other is CareInterval && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => 'CareInterval($value ${unit.name})';
}

/// A ready-made plan from the server's catalog, e.g. "Deworming every
/// 3 months". Every value is a starting point the user can change.
@immutable
class CarePreset {
  const CarePreset({
    required this.code,
    required this.kind,
    required this.title,
    this.species,
    this.interval,
    this.targets = const [],
    this.dogOnly = false,
    this.note,
  });

  /// A stable id such as `cat-rabies`. The app shows the title and the note
  /// in the user's language by this code.
  final String code;

  /// Null when the preset suits any species.
  final PetSpecies? species;
  final CareKind kind;

  /// English, from the server: shown only for codes this app doesn't know.
  final String title;

  /// Null for a one-off plan.
  final CareInterval? interval;
  final List<VaccineTarget> targets;

  /// Never for cats: K9 Advantix, for example, contains permethrin, which
  /// is toxic to cats. The server refuses it for a cat.
  final bool dogOnly;

  /// English, from the server, like [title].
  final String? note;

  @override
  String toString() => 'CarePreset($code)';
}

/// "What to do and when": a repeating plan (rabies once a year) or a one-off
/// (a treatment before a trip).
@immutable
class CarePlan {
  const CarePlan({
    required this.id,
    required this.petId,
    required this.kind,
    required this.title,
    required this.nextDueOn,
    required this.status,
    required this.daysLeft,
    this.interval,
    this.intervalUnknown = false,
    this.lastDoneOn,
    this.remindOffsetsDays = const [7, 1, 0],
    this.defaultProduct,
    this.targets = const [],
    this.presetCode,
    this.notes,
    this.active = true,
    this.hasUnknownValues = false,
  });

  /// A plan due within this many days counts as "due soon" (as on the
  /// server).
  static const dueSoonDays = 14;

  final String id;
  final String petId;
  final CareKind kind;
  final String title;

  /// Null for a one-off plan, and when [intervalUnknown].
  final CareInterval? interval;

  /// The plan repeats, but in a unit this app doesn't know (from a newer
  /// server).
  final bool intervalUnknown;
  final DateTime nextDueOn;
  final CareStatus status;

  /// Days from today to [nextDueOn]; negative when overdue.
  final int daysLeft;

  /// The last time the plan was marked done, if ever.
  final DateTime? lastDoneOn;

  /// Remind this many days before the due date (reminders come later). The
  /// form doesn't show them, but sends them back unchanged.
  final List<int> remindOffsetsDays;

  /// Offered when the plan is marked done.
  final String? defaultProduct;

  /// For vaccinations: what the vaccine protects against.
  final List<VaccineTarget> targets;

  /// The preset the plan was made from, if any.
  final String? presetCode;
  final String? notes;
  final bool active;

  /// The server sent a kind, interval unit or vaccine target this app
  /// doesn't know (from a newer version). The plan is shown with stand-ins,
  /// and editing it is turned off: saving would replace the unknown values.
  final bool hasUnknownValues;

  bool get isOneOff => interval == null && !intervalUnknown;

  @override
  String toString() => 'CarePlan($id, $title)';
}

/// What the plan form saves (`POST /pets/{id}/care-plans` and
/// `PUT /care-plans/{id}`).
@immutable
class CarePlanInput {
  const CarePlanInput({
    required this.kind,
    required this.title,
    required this.nextDueOn,
    this.interval,
    this.remindOffsetsDays,
    this.defaultProduct,
    this.targets = const [],
    this.presetCode,
    this.notes,
    this.active,
  });

  final CareKind kind;
  final String title;

  /// Null for a one-off plan.
  final CareInterval? interval;
  final DateTime nextDueOn;

  /// Null on create: the server's default ([7, 1, 0]).
  final List<int>? remindOffsetsDays;
  final String? defaultProduct;
  final List<VaccineTarget> targets;
  final String? presetCode;
  final String? notes;

  /// Null keeps the current value (and makes a new plan active).
  final bool? active;

  @override
  String toString() => 'CarePlanInput(${kind.name}, $title, $interval)';
}

/// What "Done" saves (`POST /care-plans/{id}/complete`): it becomes a new
/// record, and the plan moves to its next date.
@immutable
class CompletionInput {
  const CompletionInput({
    required this.performedOn,
    this.performedTime,
    this.product,
    this.manufacturer,
    this.batchNumber,
    this.validFrom,
    this.validUntil,
    this.clinic,
    this.veterinarian,
    this.notes,
    this.nextDueOn,
  });

  final DateTime performedOn;
  final TimeOfDay? performedTime;

  /// Sent as it is: an empty product means none was given (the form fills
  /// in the plan's usual product, and the user may clear it).
  final String? product;
  final String? manufacturer;
  final String? batchNumber;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? clinic;
  final String? veterinarian;
  final String? notes;

  /// The next date the user chose; null lets the server work it out.
  final DateTime? nextDueOn;

  @override
  String toString() => 'CompletionInput($performedOn, next: $nextDueOn)';
}

/// Extra fields of some kinds of records.
@immutable
class CareRecordDetails {
  const CareRecordDetails({
    this.laboratory,
    this.reportNumber,
    this.titerIuPerMl,
    this.fitForTravel,
  });

  static const empty = CareRecordDetails();

  /// Rabies antibody test: the laboratory and its report number.
  final String? laboratory;
  final String? reportNumber;

  /// Rabies antibody test result in IU/ml (travel to the EU needs at least
  /// 0.5).
  final double? titerIuPerMl;

  /// Check-up: the vet confirmed the pet is fit to travel. Null when not
  /// stated.
  final bool? fitForTravel;

  bool get isEmpty =>
      laboratory == null &&
      reportNumber == null &&
      titerIuPerMl == null &&
      fitForTravel == null;

  @override
  bool operator ==(Object other) =>
      other is CareRecordDetails &&
      other.laboratory == laboratory &&
      other.reportNumber == reportNumber &&
      other.titerIuPerMl == titerIuPerMl &&
      other.fitForTravel == fitForTravel;

  @override
  int get hashCode =>
      Object.hash(laboratory, reportNumber, titerIuPerMl, fitForTravel);
}

/// "What was done": a vaccination, a treatment, a check-up. Records are also
/// the health sections of the digital passport.
@immutable
class CareRecord {
  const CareRecord({
    required this.id,
    required this.petId,
    required this.kind,
    required this.title,
    required this.performedOn,
    this.planId,
    this.performedTime,
    this.product,
    this.manufacturer,
    this.batchNumber,
    this.validFrom,
    this.validUntil,
    this.targets = const [],
    this.clinic,
    this.veterinarian,
    this.weightKg,
    this.details = CareRecordDetails.empty,
    this.notes,
    this.source = RecordSource.manual,
    this.files = const [],
    this.hasUnknownValues = false,
  });

  final String id;
  final String petId;

  /// The plan this record completed, if it was made with "Done".
  final String? planId;
  final CareKind kind;
  final String title;
  final DateTime performedOn;
  final TimeOfDay? performedTime;
  final String? product;
  final String? manufacturer;
  final String? batchNumber;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final List<VaccineTarget> targets;
  final String? clinic;
  final String? veterinarian;
  final double? weightKg;
  final CareRecordDetails details;
  final String? notes;

  /// Null when the server sent a source this app doesn't know.
  final RecordSource? source;

  /// Photos of the vaccine sticker, the vet's conclusion and the like.
  final List<StoredFile> files;

  /// The server sent a kind or vaccine target this app doesn't know: shown
  /// with stand-ins, not editable (see [CarePlan.hasUnknownValues]).
  final bool hasUnknownValues;

  /// At most this many photos per record (the server's limit).
  static const maxFiles = 10;

  @override
  String toString() => 'CareRecord($id, $title)';
}

/// What the record form saves (`POST /pets/{id}/care-records` and
/// `PUT /care-records/{id}`). Photos are added and removed one by one,
/// never sent as a list.
@immutable
class CareRecordInput {
  const CareRecordInput({
    required this.kind,
    required this.title,
    required this.performedOn,
    this.performedTime,
    this.product,
    this.manufacturer,
    this.batchNumber,
    this.validFrom,
    this.validUntil,
    this.targets = const [],
    this.clinic,
    this.veterinarian,
    this.weightKg,
    this.details = CareRecordDetails.empty,
    this.notes,
  });

  final CareKind kind;
  final String title;
  final DateTime performedOn;
  final TimeOfDay? performedTime;
  final String? product;
  final String? manufacturer;
  final String? batchNumber;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final List<VaccineTarget> targets;
  final String? clinic;
  final String? veterinarian;
  final double? weightKg;
  final CareRecordDetails details;
  final String? notes;

  @override
  String toString() => 'CareRecordInput(${kind.name}, $title, $performedOn)';
}

/// The health sections of the EU pet passport, built by the server from the
/// records. Each list is oldest first, as in the paper passport.
@immutable
class PassportRecords {
  const PassportRecords({
    this.rabies = const [],
    this.rabiesTiters = const [],
    this.echinococcus = const [],
    this.treatments = const [],
    this.otherVaccinations = const [],
    this.examinations = const [],
  });

  /// V. Vaccinations against rabies (also combined vaccines).
  final List<CareRecord> rabies;

  /// VI. Rabies antibody tests.
  final List<CareRecord> rabiesTiters;

  /// VII. Tapeworm treatments before travel.
  final List<CareRecord> echinococcus;

  /// VIII. Other treatments against parasites: worms, fleas and ticks,
  /// heartworm.
  final List<CareRecord> treatments;

  /// IX. Other vaccinations.
  final List<CareRecord> otherVaccinations;

  /// X. Check-ups.
  final List<CareRecord> examinations;
}

/// What a new plan's form starts with when it doesn't come from a preset:
/// e.g. a flea treatment scanned in supplies, "every 12 weeks".
@immutable
class CarePlanDraft {
  const CarePlanDraft({
    required this.kind,
    required this.title,
    required this.interval,
    this.product,
  });

  final CareKind kind;
  final String title;
  final CareInterval interval;
  final String? product;
}
