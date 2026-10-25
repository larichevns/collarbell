// The rules of the weight log the app applies before the server answers:
// changes in whole grams, the chart's periods (offered only when they show
// something different), a month back from the end of a month, the weight
// as it may be typed, the first date of a weighing, and how weights read.
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/weight/weight.dart';
import 'package:collarbell/features/weight/weight_labels.dart';
import 'package:collarbell/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations ru;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ru = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  test('a change is worked out in whole grams, from the weight before it', () {
    final log = [
      testWeight('c', on: DateTime(2026, 10, 5), kg: 4.3),
      testWeight('b', on: DateTime(2026, 9, 5), kg: 4.1),
      testWeight('a', on: DateTime(2026, 8, 5), kg: 4.1),
    ];
    // As doubles, 4.3 − 4.1 is 0.19999…
    expect(changeAt(log, 0), 200);
    expect(changeAt(log, 1), 0);
    expect(changeAt(log, 2), isNull, reason: 'the oldest');
    expect(weightChangeLabel(en, 200), '+0.2 kg');
    expect(weightChangeLabel(ru, -150), '\u22120,15 кг');
    expect(weightChangeLabel(en, 0), 'no change');
  });

  test('periods are offered only when they show something different', () {
    final today = DateTime(2026, 10, 7);
    expect(weightPeriodsFor(DateTime(2026, 8, 1), today), isEmpty);
    expect(weightPeriodsFor(DateTime(2026, 5, 1), today), [
      WeightPeriod.threeMonths,
      WeightPeriod.all,
    ]);
    expect(weightPeriodsFor(DateTime(2025, 1, 1), today), WeightPeriod.values);
    // The last year when it has a line to draw, else the whole log: weights
    // 700 and 500 days ago and one 10 days ago would leave the year with one.
    final busyYear = [
      testWeight('c', on: DateTime(2026, 9, 1), kg: 4.2),
      testWeight('b', on: DateTime(2026, 3, 1), kg: 4.1),
      testWeight('a', on: DateTime(2024, 1, 1), kg: 3.5),
    ];
    final quietYear = [
      testWeight('c', on: DateTime(2026, 9, 27), kg: 4.2),
      testWeight('b', on: DateTime(2024, 5, 25), kg: 3.9),
      testWeight('a', on: DateTime(2023, 11, 7), kg: 3.6),
    ];
    expect(
      defaultWeightPeriod(WeightPeriod.values, busyYear, today),
      WeightPeriod.year,
    );
    expect(
      defaultWeightPeriod(WeightPeriod.values, quietYear, today),
      WeightPeriod.all,
    );
    expect(defaultWeightPeriod(const [], busyYear, today), WeightPeriod.all);

    final log = [
      testWeight('b', on: DateTime(2026, 9, 1), kg: 4.2),
      testWeight('a', on: DateTime(2026, 2, 1), kg: 4),
    ];
    expect(
      [
        for (final entry in weightsIn(log, WeightPeriod.threeMonths, today))
          entry.id,
      ],
      ['b'],
    );
    expect(weightsIn(log, WeightPeriod.all, today), log);
  });

  test(
    'a month back from the end of a month is the end of the shorter one',
    () {
      expect(monthsBefore(DateTime(2026, 5, 31), 3), DateTime(2026, 2, 28));
      expect(monthsBefore(DateTime(2026, 1, 15), 3), DateTime(2025, 10, 15));
      expect(monthsBefore(DateTime(2024, 3, 31), 1), DateTime(2024, 2, 29));
    },
  );

  test('a weight is typed with a point or a comma, above 0 and up to 200 kg, '
      'with as many decimals as it is kept with', () {
    String? problem(String text, {int decimals = 3}) =>
        weightTextProblem(en, text, decimals: decimals, required: true);
    expect(problem('4.235'), isNull);
    expect(problem('4,235'), isNull);
    expect(problem('200'), isNull);
    expect(problem(''), 'Enter the weight');
    expect(problem('0'), 'Use a weight above 0 and up to 200 kg');
    expect(problem('200.5'), 'Use a weight above 0 and up to 200 kg');
    // Numbers double.tryParse would take.
    expect(problem('1e2'), 'Use a weight above 0 and up to 200 kg');
    expect(problem('NaN'), 'Use a weight above 0 and up to 200 kg');
    expect(problem('4.2355'), 'Use 3 decimals at most');
    // A point or comma may start or end it, as while typing; zeros at the
    // end are no extra precision.
    expect(problem('4,'), isNull);
    expect(problem('4.'), isNull);
    expect(problem(',5'), isNull);
    expect(problem('.5'), isNull);
    expect(problem('4.2350'), isNull);
    expect(problem('4,250', decimals: 2), isNull);
    expect(problem(','), 'Use a weight above 0 and up to 200 kg');
    expect(problem('4.235', decimals: 2), 'Use 2 decimals at most');
    expect(
      weightTextProblem(ru, '4,255', decimals: 2),
      'Не больше 2 знаков после запятой',
    );
    expect(weightTextProblem(en, '', decimals: 2), isNull, reason: 'optional');
  });

  test('a weighing starts no earlier than an exact birth date', () {
    final today = DateTime(2026, 10, 7);
    final born = Pet(
      id: 'p1',
      name: 'Murka',
      species: PetSpecies.cat,
      birthDate: DateTime(2024, 3, 1),
    );
    expect(WeightRules.firstDateFor(born, today), DateTime(2024, 3, 1));
    final about = Pet(
      id: 'p1',
      name: 'Murka',
      species: PetSpecies.cat,
      birthDate: DateTime(2024, 3, 1),
      birthDateApproximate: true,
    );
    expect(WeightRules.firstDateFor(about, today), DateTime(1990));
  });

  test('weights read to the gram, scores with their ideal', () {
    expect(weightValueLabel(en, 4.2350000001), '4.235 kg');
    expect(weightValueLabel(ru, 12), '12 кг');
    expect(bodyConditionLabel(en, const BodyCondition(5, 9)), 'BCS 5/9');
    expect(
      bodyConditionLabel(ru, const BodyCondition(3, 5)),
      'Упитанность 3/5',
    );
    expect(bodyConditionIdeal(9), '4–5');
    expect(bodyConditionIdeal(5), '3');
  });
}
