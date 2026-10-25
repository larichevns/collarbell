/// The rules of plans and records that the app needs before the server
/// answers: the next due date (the same as the API's `Intervals.Add` and
/// `CarePlan.MarkDone`), the status groups, and which fields belong to
/// which kind of care.
library;

import 'dart:math' as math;

import '../pets/pet.dart';
import 'care.dart';

/// The earliest date the server accepts for a record or a due date.
final earliestCareDate = DateTime(1990);

/// The latest due date the server accepts: ten years from [today].
DateTime latestDueDate(DateTime today) =>
    addInterval(today, const CareInterval(10, IntervalUnit.year));

// --- Dates ----------------------------------------------------------------

/// The date one interval after [date]. Months and years keep the day where
/// they can: 31 January + 1 month is 28 (or 29) February, as on the server.
DateTime addInterval(DateTime date, CareInterval interval) {
  final value = interval.value;
  return switch (interval.unit) {
    IntervalUnit.day => DateTime(date.year, date.month, date.day + value),
    IntervalUnit.week => DateTime(date.year, date.month, date.day + 7 * value),
    IntervalUnit.month => _addMonths(date, value),
    IntervalUnit.year => _addMonths(date, 12 * value),
  };
}

DateTime _addMonths(DateTime date, int months) {
  // DateTime counts month 13 as January of the next year.
  final month = DateTime(date.year, date.month + months);
  // Day 0 of the following month is the last day of this one.
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, math.min(date.day, lastDay));
}

/// The plan's next due date after "Done" on [performedOn], worked out like
/// the server does: the date the user [chosen], else the day the protection
/// ends ([validUntil], e.g. a vaccine's), else one [interval] later.
///
/// Returns null when the plan finishes instead: a one-off plan ends with
/// "Done" unless the user chose a next date.
DateTime? nextDueAfterDone({
  required CareInterval? interval,
  required DateTime performedOn,
  DateTime? validUntil,
  DateTime? chosen,
}) {
  if (chosen != null) return chosen;
  if (interval == null) return null;
  return validUntil ?? addInterval(performedOn, interval);
}

/// The status of a plan with [daysLeft] days to its due date, as the
/// server decides it. Used when the server sends a status this app doesn't
/// know.
CareStatus statusFor({required bool active, required int daysLeft}) {
  if (!active) return CareStatus.inactive;
  if (daysLeft < 0) return CareStatus.overdue;
  if (daysLeft <= CarePlan.dueSoonDays) return CareStatus.dueSoon;
  return CareStatus.upcoming;
}

// --- Groups ---------------------------------------------------------------

/// The plans by status, in the order the Health tab shows the groups:
/// overdue, due soon, upcoming, then finished or paused. Each group keeps
/// the server's order (soonest first); empty groups are left out.
Map<CareStatus, List<CarePlan>> groupPlans(List<CarePlan> plans) => {
  for (final status in CareStatus.values)
    if (plans.any((plan) => plan.status == status))
      status: [
        for (final plan in plans)
          if (plan.status == status) plan,
      ],
};

/// The groups of the preset picker.
enum PresetGroup { vaccinations, deworming, parasites, checkUps, travel }

PresetGroup presetGroupOf(CareKind kind) => switch (kind) {
  CareKind.vaccination => PresetGroup.vaccinations,
  CareKind.deworming => PresetGroup.deworming,
  CareKind.fleaTick || CareKind.heartworm => PresetGroup.parasites,
  CareKind.echinococcus || CareKind.rabiesTiter => PresetGroup.travel,
  CareKind.vetExam ||
  CareKind.dental ||
  CareKind.grooming ||
  CareKind.procedure ||
  CareKind.other => PresetGroup.checkUps,
};

// --- Fields per kind ------------------------------------------------------

/// Kinds where something is given: they have a product, its manufacturer
/// and a batch number.
bool usesProduct(CareKind kind) => switch (kind) {
  CareKind.vaccination ||
  CareKind.deworming ||
  CareKind.echinococcus ||
  CareKind.fleaTick ||
  CareKind.heartworm ||
  CareKind.procedure ||
  CareKind.other => true,
  CareKind.rabiesTiter ||
  CareKind.vetExam ||
  CareKind.dental ||
  CareKind.grooming => false,
};

/// Only vaccinations protect against diseases and have a validity period.
bool usesTargets(CareKind kind) => kind == CareKind.vaccination;

/// The hour matters only for the tapeworm treatment before travel.
bool usesTime(CareKind kind) => kind == CareKind.echinococcus;

/// The laboratory, report number and result of a rabies antibody test.
bool usesTiter(CareKind kind) => kind == CareKind.rabiesTiter;

/// Weight and "fit to travel" are noted at a check-up.
bool usesExam(CareKind kind) => kind == CareKind.vetExam;

/// The vaccine targets offered for a species: a cat's vaccines for cats, a
/// dog's for dogs, all of them for other animals.
List<VaccineTarget> targetsFor(PetSpecies species) => switch (species) {
  PetSpecies.cat => const [
    VaccineTarget.rabies,
    VaccineTarget.fpv,
    VaccineTarget.fhv1,
    VaccineTarget.fcv,
    VaccineTarget.felv,
    VaccineTarget.chlamydia,
  ],
  PetSpecies.dog => const [
    VaccineTarget.rabies,
    VaccineTarget.cdv,
    VaccineTarget.cav2,
    VaccineTarget.cpv2,
    VaccineTarget.cpiv,
    VaccineTarget.lepto,
    VaccineTarget.bordetella,
    VaccineTarget.lyme,
    VaccineTarget.canineInfluenza,
    VaccineTarget.leishmania,
  ],
  PetSpecies.other => VaccineTarget.values,
};
