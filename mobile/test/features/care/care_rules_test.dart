// The care rules the app works out itself before the server answers: the
// next due date (the same as the API's), the status groups, the fields of
// each kind, and the words for intervals and due dates in both languages.
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/care_labels.dart';
import 'package:collarbell/features/care/care_rules.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

const monthly = CareInterval(1, IntervalUnit.month);
const quarterly = CareInterval(3, IntervalUnit.month);

/// Every preset code of the server's catalog (CarePresets.cs).
const allPresetCodes = [
  'cat-fvrcp', 'cat-fvrcp-kitten', 'cat-rabies', 'cat-felv', 'cat-chlamydia', //
  'cat-deworm', 'cat-deworm-indoor', 'cat-deworm-outdoor', 'cat-deworm-kitten',
  'cat-fleatick-monthly', 'cat-bravecto', 'cat-bravecto-plus', 'cat-seresto',
  'cat-exam', 'cat-dental', 'cat-nails', 'dog-dhpp', 'dog-dhpp-puppy',
  'dog-rabies', 'dog-lepto', 'dog-kennel-cough', 'dog-lyme', 'dog-leishmania',
  'dog-deworm', 'dog-deworm-indoor', 'dog-deworm-high', 'dog-deworm-puppy',
  'dog-fleatick-monthly', 'dog-bravecto', 'dog-seresto', 'dog-advantix',
  'dog-heartworm', 'dog-echinococcus', 'dog-exam', 'dog-dental', 'dog-nails',
];

/// Presets of the catalog without a note.
const codesWithoutNote = {
  'cat-seresto', 'dog-seresto', 'cat-dental', 'dog-dental', 'cat-nails', //
  'dog-nails', 'dog-heartworm',
};

void main() {
  group('addInterval', () {
    test('adds days and weeks across months and years', () {
      expect(
        addInterval(
          DateTime(2026, 12, 30),
          const CareInterval(3, IntervalUnit.day),
        ),
        DateTime(2027, 1, 2),
      );
      expect(
        addInterval(
          DateTime(2026, 10, 1),
          const CareInterval(12, IntervalUnit.week),
        ),
        DateTime(2026, 12, 24),
      );
    });

    test('keeps the day of the month where it can', () {
      expect(
        addInterval(DateTime(2026, 7, 6), quarterly),
        DateTime(2026, 10, 6),
      );
      expect(
        addInterval(DateTime(2026, 11, 15), quarterly),
        DateTime(2027, 2, 15),
      );
    });

    test('ends at the last day of a shorter month, like the server', () {
      expect(
        addInterval(DateTime(2026, 1, 31), monthly),
        DateTime(2026, 2, 28),
      );
      expect(
        addInterval(DateTime(2028, 1, 31), monthly),
        DateTime(2028, 2, 29),
      );
      expect(
        addInterval(DateTime(2026, 11, 30), quarterly),
        DateTime(2027, 2, 28),
      );
      expect(
        addInterval(DateTime(2026, 3, 31), monthly),
        DateTime(2026, 4, 30),
      );
    });

    test('a year after 29 February is 28 February', () {
      expect(
        addInterval(
          DateTime(2028, 2, 29),
          const CareInterval(1, IntervalUnit.year),
        ),
        DateTime(2029, 2, 28),
      );
      expect(
        addInterval(
          DateTime(2028, 2, 29),
          const CareInterval(4, IntervalUnit.year),
        ),
        DateTime(2032, 2, 29),
      );
    });
  });

  group('nextDueAfterDone', () {
    final doneOn = DateTime(2026, 10, 1);

    test('is one interval after the date it was done', () {
      expect(
        nextDueAfterDone(interval: quarterly, performedOn: doneOn),
        DateTime(2027, 1, 1),
      );
    });

    test('follows "valid until" over the interval', () {
      expect(
        nextDueAfterDone(
          interval: const CareInterval(1, IntervalUnit.year),
          performedOn: doneOn,
          validUntil: DateTime(2029, 9, 30),
        ),
        DateTime(2029, 9, 30),
      );
    });

    test('a chosen date wins over everything', () {
      expect(
        nextDueAfterDone(
          interval: quarterly,
          performedOn: doneOn,
          validUntil: DateTime(2027, 9, 30),
          chosen: DateTime(2026, 11, 15),
        ),
        DateTime(2026, 11, 15),
      );
    });

    test('a one-off plan finishes, unless a next date is chosen', () {
      expect(nextDueAfterDone(interval: null, performedOn: doneOn), isNull);
      // The server also finishes it when "valid until" is given.
      expect(
        nextDueAfterDone(
          interval: null,
          performedOn: doneOn,
          validUntil: DateTime(2027, 9, 30),
        ),
        isNull,
      );
      expect(
        nextDueAfterDone(
          interval: null,
          performedOn: doneOn,
          chosen: DateTime(2027, 4, 1),
        ),
        DateTime(2027, 4, 1),
      );
    });
  });

  test('statusFor uses the 14-day "due soon" window', () {
    expect(statusFor(active: false, daysLeft: -3), CareStatus.inactive);
    expect(statusFor(active: true, daysLeft: -1), CareStatus.overdue);
    expect(statusFor(active: true, daysLeft: 0), CareStatus.dueSoon);
    expect(statusFor(active: true, daysLeft: 14), CareStatus.dueSoon);
    expect(statusFor(active: true, daysLeft: 15), CareStatus.upcoming);
  });

  test('groupPlans: overdue, due soon, upcoming, inactive; order kept', () {
    final plans = [
      testPlan('a', daysLeft: -10),
      testPlan('b', daysLeft: -2),
      testPlan('c', daysLeft: 3),
      testPlan('d', daysLeft: 40),
      testPlan('e', daysLeft: 90),
      testPlan('f', daysLeft: -30, active: false),
    ];
    final groups = groupPlans(plans);

    expect(groups.keys, [
      CareStatus.overdue,
      CareStatus.dueSoon,
      CareStatus.upcoming,
      CareStatus.inactive,
    ]);
    List<String> ids(CareStatus status) => [
      for (final plan in groups[status]!) plan.id,
    ];
    expect(ids(CareStatus.overdue), ['a', 'b']);
    expect(ids(CareStatus.dueSoon), ['c']);
    expect(ids(CareStatus.upcoming), ['d', 'e']);
    expect(ids(CareStatus.inactive), ['f']);

    expect(groupPlans([testPlan('x', daysLeft: 3)]).keys, [CareStatus.dueSoon]);
    expect(groupPlans(const []), isEmpty);
  });

  test('vaccine targets follow the species', () {
    expect(targetsFor(PetSpecies.cat), contains(VaccineTarget.fpv));
    expect(targetsFor(PetSpecies.cat), isNot(contains(VaccineTarget.cdv)));
    expect(targetsFor(PetSpecies.dog), contains(VaccineTarget.cdv));
    expect(targetsFor(PetSpecies.dog), isNot(contains(VaccineTarget.felv)));
    for (final species in PetSpecies.values) {
      expect(targetsFor(species), contains(VaccineTarget.rabies));
    }
    expect(targetsFor(PetSpecies.other), VaccineTarget.values);
  });

  test('fields per kind', () {
    expect(usesTargets(CareKind.vaccination), isTrue);
    expect(usesTargets(CareKind.deworming), isFalse);
    expect(usesTime(CareKind.echinococcus), isTrue);
    expect(usesTime(CareKind.deworming), isFalse);
    expect(usesTiter(CareKind.rabiesTiter), isTrue);
    expect(usesExam(CareKind.vetExam), isTrue);
    expect(usesProduct(CareKind.deworming), isTrue);
    expect(usesProduct(CareKind.grooming), isFalse);
    expect(presetGroupOf(CareKind.heartworm), PresetGroup.parasites);
    expect(presetGroupOf(CareKind.echinococcus), PresetGroup.travel);
  });

  group('words', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ru = lookupAppLocalizations(const Locale('ru'));

    test('intervals in English', () {
      expect(intervalLabel(en, monthly), 'Every month');
      expect(intervalLabel(en, quarterly), 'Every 3 months');
      expect(
        intervalLabel(en, const CareInterval(1, IntervalUnit.day)),
        'Every day',
      );
      expect(
        intervalLabel(en, const CareInterval(12, IntervalUnit.week)),
        'Every 12 weeks',
      );
      expect(intervalLabel(en, null), 'One-off');
      expect(intervalLabel(en, null, unknown: true), 'Repeats');
    });

    test('intervals in Russian, with plural forms', () {
      expect(intervalLabel(ru, monthly), 'Раз в месяц');
      expect(intervalLabel(ru, quarterly), 'Раз в 3 месяца');
      expect(
        intervalLabel(ru, const CareInterval(6, IntervalUnit.month)),
        'Раз в 6 месяцев',
      );
      expect(
        intervalLabel(ru, const CareInterval(21, IntervalUnit.month)),
        'Раз в 21 месяц',
      );
      expect(
        intervalLabel(ru, const CareInterval(1, IntervalUnit.week)),
        'Раз в неделю',
      );
      expect(
        intervalLabel(ru, const CareInterval(2, IntervalUnit.week)),
        'Раз в 2 недели',
      );
      expect(
        intervalLabel(ru, const CareInterval(5, IntervalUnit.year)),
        'Раз в 5 лет',
      );
      expect(
        intervalLabel(ru, const CareInterval(1, IntervalUnit.day)),
        'Каждый день',
      );
      expect(intervalUnitLabel(ru, IntervalUnit.week, 1), 'неделю');
      expect(intervalUnitLabel(ru, IntervalUnit.month, 5), 'месяцев');
    });

    test('due dates', () {
      expect(dueLabel(en, 0), 'Today');
      expect(dueLabel(en, 1), 'Tomorrow');
      expect(dueLabel(en, 5), 'In 5 days');
      expect(dueLabel(en, 365), 'In 12 months');
      expect(dueLabel(en, -1), '1 day overdue');
      expect(dueLabel(en, -3), '3 days overdue');
      expect(dueLabel(ru, 5), 'Через 5 дней');
      expect(dueLabel(ru, 2), 'Через 2 дня');
      expect(dueLabel(ru, 21), 'Через 21 день');
      expect(dueLabel(ru, -3), 'Просрочено на 3 дня');
      expect(dueLabel(ru, -11), 'Просрочено на 11 дней');
    });

    test('every preset code of the catalog has its own words', () {
      for (final l10n in [en, ru]) {
        for (final code in allPresetCodes) {
          final preset = CarePreset(
            code: code,
            kind: CareKind.other,
            title: 'SERVER TITLE',
            note: 'SERVER NOTE',
          );
          expect(
            presetTitle(l10n, preset),
            isNot('SERVER TITLE'),
            reason: code,
          );
          if (codesWithoutNote.contains(code)) {
            expect(presetNote(l10n, preset), isNull, reason: code);
          } else {
            expect(
              presetNote(l10n, preset),
              isNot('SERVER NOTE'),
              reason: code,
            );
            expect(presetNote(l10n, preset), isNotEmpty, reason: code);
          }
        }
      }
      expect(
        presetTitle(
          ru,
          const CarePreset(
            code: 'dog-advantix',
            kind: CareKind.fleaTick,
            title: '',
          ),
        ),
        'K9 Advantix',
      );
    });

    test('an unknown preset code shows the server words', () {
      const preset = CarePreset(
        code: 'cat-new-vaccine',
        kind: CareKind.vaccination,
        title: 'New vaccine',
        note: 'From the newer server',
      );
      expect(presetTitle(ru, preset), 'New vaccine');
      expect(presetNote(ru, preset), 'From the newer server');
    });

    test('decimals use the language separator', () {
      expect(formatDecimal(en, 2.5), '2.5');
      expect(formatDecimal(ru, 2.5), '2,5');
      expect(formatDecimal(ru, 4.0), '4');
      expect(parseDecimal('2,5'), 2.5);
      expect(parseDecimal(' 0.5 '), 0.5);
      expect(parseDecimal('abc'), isNull);
    });
  });
}
