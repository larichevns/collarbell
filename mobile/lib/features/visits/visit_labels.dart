import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/l10n.dart';
import '../feeding/feeding_labels.dart' show calendarDaysBetween, timeLabel;
import 'visit.dart';

String visitTypeLabel(AppLocalizations l10n, VisitType type) => switch (type) {
  VisitType.vet => l10n.visitTypeVet,
  VisitType.grooming => l10n.visitTypeGrooming,
  VisitType.training => l10n.visitTypeTraining,
  VisitType.other => l10n.visitTypeOther,
};

IconData visitTypeIcon(VisitType type) => switch (type) {
  VisitType.vet => Symbols.local_hospital_rounded,
  VisitType.grooming => Symbols.content_cut_rounded,
  VisitType.training => Symbols.sports_rounded,
  VisitType.other => Symbols.event_rounded,
};

/// The reminders the visit form offers, in minutes before the visit.
const visitReminderChoices = [10080, 1440, 120, 60];

/// The reminders a new visit starts with: a day and two hours before.
const defaultVisitReminders = [1440, 120];

/// "A week before", "A day before", "2 hours before", "1 hour before", or
/// "N minutes before" for other values set elsewhere.
String visitReminderLabel(AppLocalizations l10n, int minutes) {
  return switch (minutes) {
    0 => l10n.visitRemindAtStart,
    10080 => l10n.visitRemindWeek,
    1440 => l10n.visitRemindDay,
    60 => l10n.visitRemindHour,
    _ when minutes % 10080 == 0 => l10n.visitRemindWeeks(minutes ~/ 10080),
    _ when minutes % 1440 == 0 => l10n.visitRemindDays(minutes ~/ 1440),
    _ when minutes % 60 == 0 => l10n.visitRemindHours(minutes ~/ 60),
    _ => l10n.visitRemindMinutes(minutes),
  };
}

/// When a visit is, counted from [today]: "Today at 10:30", "Tomorrow at
/// 10:30", "Fri, Oct 10 at 10:30".
String visitWhenLabel(
  BuildContext context,
  DateTime date,
  TimeOfDay time,
  DateTime today,
) {
  final l10n = context.l10n;
  final at = timeLabel(context, time);
  return switch (calendarDaysBetween(today, date)) {
    0 => l10n.visitToday(at),
    1 => l10n.visitTomorrow(at),
    -1 => l10n.visitYesterday(at),
    _ => l10n.visitOnDate(date, at),
  };
}

String visitStatusLabel(AppLocalizations l10n, VisitStatus status) =>
    switch (status) {
      VisitStatus.planned => l10n.visitStatusPlanned,
      VisitStatus.done => l10n.visitStatusDone,
      VisitStatus.cancelled => l10n.visitStatusCancelled,
    };
