import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/l10n.dart';
import 'care.dart';
import 'care_rules.dart';

// Localized names and icons of the care values, used by the Health tab, the
// forms, the passport sections and Today.

String careKindLabel(AppLocalizations l10n, CareKind kind) => switch (kind) {
  CareKind.vaccination => l10n.careKindVaccination,
  CareKind.rabiesTiter => l10n.careKindRabiesTiter,
  CareKind.deworming => l10n.careKindDeworming,
  CareKind.echinococcus => l10n.careKindEchinococcus,
  CareKind.fleaTick => l10n.careKindFleaTick,
  CareKind.heartworm => l10n.careKindHeartworm,
  CareKind.vetExam => l10n.careKindVetExam,
  CareKind.dental => l10n.careKindDental,
  CareKind.grooming => l10n.careKindGrooming,
  CareKind.procedure => l10n.careKindProcedure,
  CareKind.other => l10n.careKindOther,
};

IconData careKindIcon(CareKind kind) => switch (kind) {
  CareKind.vaccination => Symbols.vaccines_rounded,
  CareKind.rabiesTiter => Symbols.bloodtype_rounded,
  CareKind.deworming => Symbols.medication_rounded,
  CareKind.echinococcus => Symbols.flight_takeoff_rounded,
  CareKind.fleaTick => Symbols.pest_control_rounded,
  CareKind.heartworm => Symbols.monitor_heart_rounded,
  CareKind.vetExam => Symbols.medical_services_rounded,
  CareKind.dental => Symbols.sentiment_satisfied_rounded,
  CareKind.grooming => Symbols.content_cut_rounded,
  CareKind.procedure => Symbols.healing_rounded,
  CareKind.other => Symbols.event_note_rounded,
};

String vaccineTargetLabel(AppLocalizations l10n, VaccineTarget target) =>
    switch (target) {
      VaccineTarget.rabies => l10n.vaccineTargetRabies,
      VaccineTarget.fpv => l10n.vaccineTargetFpv,
      VaccineTarget.fhv1 => l10n.vaccineTargetFhv1,
      VaccineTarget.fcv => l10n.vaccineTargetFcv,
      VaccineTarget.felv => l10n.vaccineTargetFelv,
      VaccineTarget.chlamydia => l10n.vaccineTargetChlamydia,
      VaccineTarget.cdv => l10n.vaccineTargetCdv,
      VaccineTarget.cav2 => l10n.vaccineTargetCav2,
      VaccineTarget.cpv2 => l10n.vaccineTargetCpv2,
      VaccineTarget.cpiv => l10n.vaccineTargetCpiv,
      VaccineTarget.lepto => l10n.vaccineTargetLepto,
      VaccineTarget.bordetella => l10n.vaccineTargetBordetella,
      VaccineTarget.lyme => l10n.vaccineTargetLyme,
      VaccineTarget.canineInfluenza => l10n.vaccineTargetCanineInfluenza,
      VaccineTarget.leishmania => l10n.vaccineTargetLeishmania,
    };

/// "Every 3 months", "One-off", or "Repeats" when the unit is unknown.
String intervalLabel(
  AppLocalizations l10n,
  CareInterval? interval, {
  bool unknown = false,
}) {
  if (unknown) return l10n.intervalRepeats;
  if (interval == null) return l10n.intervalOneOff;
  final count = interval.value;
  // "Every month", «Раз в месяц»: 1 has its own words, while 21 takes the
  // plural form «Раз в 21 месяц».
  if (count == 1) {
    return switch (interval.unit) {
      IntervalUnit.day => l10n.intervalEveryDay,
      IntervalUnit.week => l10n.intervalEveryWeek,
      IntervalUnit.month => l10n.intervalEveryMonth,
      IntervalUnit.year => l10n.intervalEveryYear,
    };
  }
  return switch (interval.unit) {
    IntervalUnit.day => l10n.intervalEveryDays(count),
    IntervalUnit.week => l10n.intervalEveryWeeks(count),
    IntervalUnit.month => l10n.intervalEveryMonths(count),
    IntervalUnit.year => l10n.intervalEveryYears(count),
  };
}

String planIntervalLabel(AppLocalizations l10n, CarePlan plan) =>
    intervalLabel(l10n, plan.interval, unknown: plan.intervalUnknown);

/// The unit after a number in the plan form: "3 months", «3 месяца».
String intervalUnitLabel(AppLocalizations l10n, IntervalUnit unit, int count) =>
    switch (unit) {
      IntervalUnit.day => l10n.intervalUnitDays(count),
      IntervalUnit.week => l10n.intervalUnitWeeks(count),
      IntervalUnit.month => l10n.intervalUnitMonths(count),
      IntervalUnit.year => l10n.intervalUnitYears(count),
    };

/// How far a due date is: "Today", "Tomorrow", "In 5 days", "In 3 months",
/// "3 days overdue".
String dueLabel(AppLocalizations l10n, int daysLeft) {
  if (daysLeft < 0) return l10n.dueOverdueDays(-daysLeft);
  if (daysLeft == 0) return l10n.dueToday;
  if (daysLeft == 1) return l10n.dueTomorrow;
  // Far dates read better in months: "In 11 months", not "In 334 days".
  if (daysLeft < 60) return l10n.dueInDays(daysLeft);
  return l10n.dueInMonths(daysLeft ~/ 30);
}

/// "Overdue", "Due soon", "Upcoming", "Finished" or "Paused".
String planStatusLabel(AppLocalizations l10n, CarePlan plan) =>
    switch (plan.status) {
      CareStatus.overdue => l10n.careStatusOverdue,
      CareStatus.dueSoon => l10n.careStatusDueSoon,
      CareStatus.upcoming => l10n.careStatusUpcoming,
      // A one-off plan ends with "Done"; any other inactive plan is paused.
      CareStatus.inactive =>
        plan.isOneOff && plan.lastDoneOn != null
            ? l10n.careStatusFinished
            : l10n.careStatusPaused,
    };

/// The title of a status group on the Health tab.
String planGroupLabel(AppLocalizations l10n, CareStatus status) =>
    switch (status) {
      CareStatus.overdue => l10n.careStatusOverdue,
      CareStatus.dueSoon => l10n.careStatusDueSoon,
      CareStatus.upcoming => l10n.careStatusUpcoming,
      CareStatus.inactive => l10n.healthGroupInactive,
    };

String presetGroupLabel(AppLocalizations l10n, PresetGroup group) =>
    switch (group) {
      PresetGroup.vaccinations => l10n.presetGroupVaccinations,
      PresetGroup.deworming => l10n.presetGroupDeworming,
      PresetGroup.parasites => l10n.presetGroupParasites,
      PresetGroup.checkUps => l10n.presetGroupCheckUps,
      PresetGroup.travel => l10n.presetGroupTravel,
    };

/// A record's date, with the time when it has one: "Jun 1, 2026, 14:30".
String recordDateLabel(BuildContext context, CareRecord record) {
  final l10n = context.l10n;
  final time = record.performedTime;
  return time == null
      ? l10n.dateMedium(record.performedOn)
      : l10n.dateWithTime(record.performedOn, time.format(context));
}

/// The title a new record starts with: the kind's name, or "Rabies" for a
/// rabies vaccination. The user can change it.
String defaultRecordTitle(
  AppLocalizations l10n,
  CareKind kind,
  List<VaccineTarget> targets,
) {
  if (kind == CareKind.vaccination && targets.length == 1) {
    return vaccineTargetLabel(l10n, targets.single);
  }
  return careKindLabel(l10n, kind);
}

/// The preset's title in the user's language. The server's English title is
/// the fallback for codes this app doesn't know yet.
String presetTitle(AppLocalizations l10n, CarePreset preset) =>
    switch (preset.code) {
      'cat-fvrcp' => l10n.presetCatFvrcp,
      'cat-fvrcp-kitten' => l10n.presetCatFvrcpKitten,
      'cat-rabies' || 'dog-rabies' => l10n.presetRabies,
      'cat-felv' => l10n.presetCatFelv,
      'cat-chlamydia' => l10n.presetCatChlamydia,
      'cat-deworm' || 'dog-deworm' => l10n.presetDeworm,
      'cat-deworm-indoor' => l10n.presetCatDewormIndoor,
      'cat-deworm-outdoor' => l10n.presetCatDewormOutdoor,
      'cat-deworm-kitten' => l10n.presetCatDewormKitten,
      'cat-fleatick-monthly' ||
      'dog-fleatick-monthly' => l10n.presetFleaTickMonthly,
      'cat-bravecto' || 'dog-bravecto' => l10n.presetBravecto,
      'cat-bravecto-plus' => l10n.presetCatBravectoPlus,
      'cat-seresto' || 'dog-seresto' => l10n.presetSeresto,
      'cat-exam' || 'dog-exam' => l10n.presetExam,
      'cat-dental' || 'dog-dental' => l10n.presetDental,
      'cat-nails' || 'dog-nails' => l10n.presetNails,
      'dog-dhpp' => l10n.presetDogDhpp,
      'dog-dhpp-puppy' => l10n.presetDogDhppPuppy,
      'dog-lepto' => l10n.presetDogLepto,
      'dog-kennel-cough' => l10n.presetDogKennelCough,
      'dog-lyme' => l10n.presetDogLyme,
      'dog-leishmania' => l10n.presetDogLeishmania,
      'dog-deworm-indoor' => l10n.presetDogDewormIndoor,
      'dog-deworm-high' => l10n.presetDogDewormHigh,
      'dog-deworm-puppy' => l10n.presetDogDewormPuppy,
      'dog-advantix' => l10n.presetDogAdvantix,
      'dog-heartworm' => l10n.presetDogHeartworm,
      'dog-echinococcus' => l10n.presetDogEchinococcus,
      _ => preset.title,
    };

/// The preset's note in the user's language, or null when it has none. The
/// server's English note is the fallback for unknown codes.
String? presetNote(AppLocalizations l10n, CarePreset preset) =>
    switch (preset.code) {
      'cat-fvrcp' => l10n.presetCatFvrcpNote,
      'cat-fvrcp-kitten' => l10n.presetCatFvrcpKittenNote,
      'cat-rabies' || 'dog-rabies' => l10n.presetRabiesNote,
      'cat-felv' => l10n.presetCatFelvNote,
      'cat-chlamydia' => l10n.presetCatChlamydiaNote,
      'cat-deworm' || 'dog-deworm' => l10n.presetDewormNote,
      'cat-deworm-indoor' => l10n.presetCatDewormIndoorNote,
      'cat-deworm-outdoor' => l10n.presetCatDewormOutdoorNote,
      'cat-deworm-kitten' => l10n.presetCatDewormKittenNote,
      'cat-fleatick-monthly' => l10n.presetCatFleaTickMonthlyNote,
      'cat-bravecto' || 'dog-bravecto' => l10n.presetBravectoNote,
      'cat-bravecto-plus' => l10n.presetCatBravectoPlusNote,
      'cat-exam' => l10n.presetCatExamNote,
      'dog-dhpp' => l10n.presetDogDhppNote,
      'dog-dhpp-puppy' => l10n.presetDogDhppPuppyNote,
      'dog-lepto' => l10n.presetDogLeptoNote,
      'dog-kennel-cough' => l10n.presetDogKennelCoughNote,
      'dog-lyme' => l10n.presetDogLymeNote,
      'dog-leishmania' => l10n.presetDogLeishmaniaNote,
      'dog-deworm-indoor' => l10n.presetDogDewormIndoorNote,
      'dog-deworm-high' => l10n.presetDogDewormHighNote,
      'dog-deworm-puppy' => l10n.presetDogDewormPuppyNote,
      'dog-fleatick-monthly' => l10n.presetDogFleaTickMonthlyNote,
      'dog-advantix' => l10n.presetDogAdvantixNote,
      'dog-echinococcus' => l10n.presetDogEchinococcusNote,
      'dog-exam' => l10n.presetDogExamNote,
      // Known presets without a note.
      'cat-seresto' ||
      'dog-seresto' ||
      'cat-dental' ||
      'dog-dental' ||
      'cat-nails' ||
      'dog-nails' ||
      'dog-heartworm' => null,
      _ => preset.note,
    };

/// A decimal as the user reads and types it: "2.5" in English, «2,5» in
/// Russian, without a trailing ".0".
String formatDecimal(AppLocalizations l10n, double value) {
  var text = value.toString();
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  return l10n.localeName.startsWith('ru') ? text.replaceAll('.', ',') : text;
}

/// Reads "2.5" or "2,5"; null when the text is not a number.
double? parseDecimal(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Glues the words of [text] together with non-breaking spaces, so a short
/// value such as "Oct 1, 2026" or «28 сент. 2026 г.» never breaks across
/// lines. Only for short values: a phrase must be able to wrap.
String keepTogether(String text) => text.replaceAll(' ', '\u00A0');
