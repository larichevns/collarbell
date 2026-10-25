// The Weight tab: why to weigh while there is nothing, the latest weight
// with its change and score, the history newest first with the change from
// the weight before, a vet's weight opening its check-up, what a helper
// sees, the chart (from two weights) and its periods (only when the log is
// longer), a log that can't load, a check-up saved elsewhere joining the
// log, and the tab in Russian on a narrow phone.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/record_detail_screen.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/weight/weight.dart';
import 'package:collarbell/features/weight/weight_repository.dart';
import 'package:collarbell/features/weight/weight_tab.dart';
import 'package:collarbell/features/weight/widgets/weight_chart.dart';
import 'package:collarbell/shared/widgets/cb_card.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

final today = testToday();

DateTime daysAgo(int days) =>
    DateTime(today.year, today.month, today.day - days);

/// "Oct 5, 2026", as the rows show a date.
String date(DateTime date) => DateFormat.yMMMd('en').format(date);

/// "Sep 12" for a date of this year, as "since" shows it.
String since(DateTime day) =>
    day.year == today.year ? DateFormat.MMMd('en').format(day) : date(day);

/// A row's second line: the parts joined by dots; none breaks inside.
String line(List<String> parts) =>
    [for (final part in parts) part.replaceAll(' ', '\u00A0')].join(' · ');

Finder row(String key) => find.byKey(ValueKey(key));

/// Scrolls the Weight tab until [finder] is built and on screen.
Future<void> scrollWeightTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(
          of: find.byType(WeightTab),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// What the chart tells screen readers.
String chartSummary(WidgetTester tester) => tester
    .widget<Semantics>(
      find
          .descendant(
            of: find.byType(WeightChart),
            matching: find.byType(Semantics),
          )
          .first,
    )
    .properties
    .label!;

void main() {
  late FakeWeightRepository weight;
  late FakeCareRepository care;

  setUp(() {
    care = FakeCareRepository();
    weight = FakeWeightRepository(care: care);
  });

  Future<void> openWeight(
    WidgetTester tester, {
    HouseholdRole role = HouseholdRole.owner,
    String language = 'en',
    Size size = const Size(390, 844),
  }) => pumpApp(
    tester,
    location: '/pets/p1?tab=weight',
    language: language,
    size: size,
    me: FakeMeRepository(
      households: [testHousehold(FakeMeRepository.homeId, role: role)],
    ),
    overrides: fakeRepositories(
      pets: FakePetsRepository([murka]),
      care: care,
      weight: weight,
    ),
  );

  testWidgets('an empty log says why and how often to weigh, with a button '
      'to add the first weight', (tester) async {
    await openWeight(tester);

    expect(find.text('No weighings yet'), findsOneWidget);
    expect(
      find.text(
        'Weigh your pet once a month, kittens and puppies every 1–2 weeks: '
        'the log shows early when a pet starts losing or gaining weight.',
      ),
      findsOneWidget,
    );
    // The empty state's button, not a second one in a header.
    expect(find.text('Add'), findsNothing);

    await tester.tap(find.text('Add weight'));
    await tester.pumpAndSettle();
    expect(find.text('New weighing'), findsOneWidget);
  });

  testWidgets('the latest weight with its change and score; the history '
      'newest first, each with the change from the weight before it', (
    tester,
  ) async {
    weight.weighings.addAll([
      testWeight('w1', on: daysAgo(40), kg: 4.1),
      testWeight(
        'w3',
        on: daysAgo(2),
        kg: 4.2,
        bodyCondition: const BodyCondition(5, 9),
        note: 'Before breakfast',
      ),
      testWeight(
        'r1',
        on: daysAgo(20),
        kg: 4,
        source: WeightSource.careRecord,
        note: 'Annual check-up',
      ),
    ]);
    await openWeight(tester);

    expect(find.text('Latest weighing'), findsOneWidget);
    // Large in the card (and in the first row of the history).
    expect(
      find.descendant(
        of: find.byType(CbCard).first,
        matching: find.text('4.2 kg'),
      ),
      findsOneWidget,
    );
    expect(find.text(date(daysAgo(2))), findsOneWidget);
    expect(find.text('+0.2 kg since ${since(daysAgo(20))}'), findsOneWidget);
    expect(find.text('BCS 5/9 · ideal 4–5'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await scrollWeightTo(tester, row('weighing-w1'));
    expect(
      find.text(line([date(daysAgo(2)), '+0.2 kg', 'BCS 5/9'])),
      findsOneWidget,
    );
    expect(find.text('Before breakfast'), findsOneWidget);
    expect(
      find.text(line([date(daysAgo(20)), '\u22120.1 kg'])),
      findsOneWidget,
    );
    expect(find.text('Annual check-up'), findsOneWidget);
    // The oldest has nothing to compare with.
    expect(find.text(line([date(daysAgo(40))])), findsOneWidget);
    final tops = [
      for (final key in ['weighing-w3', 'careRecord-r1', 'weighing-w1'])
        tester.getTopLeft(row(key)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()), reason: 'newest first');
    // The icon tells a weighing from a vet's weight, to screen readers too.
    String? iconLabel(String key) => tester
        .widget<Icon>(
          find.descendant(of: row(key), matching: find.byType(Icon)).first,
        )
        .semanticLabel;
    expect(iconLabel('weighing-w3'), 'Weighing');
    expect(iconLabel('careRecord-r1'), 'Vet check-up');
  });

  testWidgets("a vet's weight is the check-up's: a tap opens its record", (
    tester,
  ) async {
    care.records = [
      testRecord(
        'r1',
        kind: CareKind.vetExam,
        title: 'Annual check-up',
        performedOn: daysAgo(20),
        weightKg: 4,
      ),
    ];
    await openWeight(tester);
    expect(find.text('${date(daysAgo(20))} · Vet check-up'), findsOneWidget);

    await scrollWeightTo(tester, row('careRecord-r1'));
    await tester.tap(row('careRecord-r1'));
    await tester.pumpAndSettle();

    expect(find.byType(RecordDetailScreen), findsOneWidget);
    expect(find.text('Annual check-up'), findsWidgets);
  });

  testWidgets('a helper sees the weights but adds and changes none; a '
      "vet's record still opens", (tester) async {
    weight.weighings.add(testWeight('w1', on: daysAgo(2), kg: 4.2));
    care.records = [
      testRecord(
        'r1',
        kind: CareKind.vetExam,
        title: 'Annual check-up',
        performedOn: daysAgo(20),
        weightKg: 4,
      ),
    ];
    await openWeight(tester, role: HouseholdRole.helper);

    expect(find.text('Add'), findsNothing);
    await scrollWeightTo(tester, row('careRecord-r1'));
    Finder chevron(String key) => find.descendant(
      of: row(key),
      matching: find.byIcon(Symbols.chevron_right_rounded),
    );
    expect(chevron('weighing-w1'), findsNothing);
    expect(chevron('careRecord-r1'), findsOneWidget);
    await tester.tap(row('weighing-w1'));
    await tester.pumpAndSettle();
    expect(find.text('Edit weighing'), findsNothing);
  });

  testWidgets("a helper's empty log says what will show, without a button", (
    tester,
  ) async {
    await openWeight(tester, role: HouseholdRole.helper);

    expect(find.text("The pet's weighings will show here."), findsOneWidget);
    expect(find.text('Add weight'), findsNothing);
  });

  testWidgets('the chart needs two weights; periods show only when the log '
      'is longer than they are', (tester) async {
    weight.weighings.add(testWeight('w1', on: daysAgo(10), kg: 4.2));
    await openWeight(tester);
    expect(
      find.text('The chart shows after the second weighing.'),
      findsOneWidget,
    );
    expect(find.byType(WeightChart), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);

    // Two weights within three months: the chart, nothing to choose.
    weight.weighings.add(testWeight('w0', on: daysAgo(50), kg: 4));
    appContainer(tester).invalidate(weightLogProvider('p1'));
    await tester.pumpAndSettle();
    await scrollWeightTo(tester, find.byType(WeightChart));
    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      chartSummary(tester),
      'Weight chart from ${date(daysAgo(50))} to ${date(daysAgo(10))}: '
      '4 kg at the start, 4.2 kg at the end, lowest 4 kg, highest 4.2 kg.',
    );
  });

  testWidgets('a log over a year long: the last year first, three months '
      'with one weight show none, all of it from the first', (tester) async {
    weight.weighings.addAll([
      testWeight('w-400', on: daysAgo(400), kg: 3.6),
      testWeight('w-200', on: daysAgo(200), kg: 3.9),
      testWeight(
        'r-10',
        on: daysAgo(10),
        kg: 4.2,
        source: WeightSource.careRecord,
      ),
    ]);
    await openWeight(tester);
    await scrollWeightTo(tester, find.byType(WeightChart));

    ChoiceChip chip(String label) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
    expect(chip('1 year').selected, isTrue);
    expect(chip('3 months').selected, isFalse);
    expect(chip('All time').selected, isFalse);
    expect(
      chartSummary(tester),
      startsWith(
        'Weight chart from '
        '${date(daysAgo(200))} to ${date(daysAgo(10))}',
      ),
    );
    // A vet's weight is among them: the legend says which marker is which.
    expect(find.text('Weighing'), findsOneWidget);
    expect(find.text('Vet check-up'), findsWidgets);

    await tapVisible(tester, find.text('3 months'));
    expect(find.byType(WeightChart), findsNothing);
    expect(
      find.text('Fewer than two weighings in this period.'),
      findsOneWidget,
    );

    await tapVisible(tester, find.text('All time'));
    expect(
      chartSummary(tester),
      'Weight chart from ${date(daysAgo(400))} to ${date(daysAgo(10))}: '
      '3.6 kg at the start, 4.2 kg at the end, lowest 3.6 kg, highest 4.2 kg.',
    );
  });

  testWidgets("a log that can't load says why; Try again loads it", (
    tester,
  ) async {
    weight.weighings.add(testWeight('w1', on: daysAgo(2), kg: 4.2));
    weight.listError = const ApiException(ApiErrorKind.network);
    await openWeight(tester);

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    weight.listError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('4.2 kg'), findsWidgets);
  });

  testWidgets("a check-up saved with a weight joins the log: the tab doesn't "
      'wait for a pull', (tester) async {
    await openWeight(tester);
    expect(find.text('No weighings yet'), findsOneWidget);

    appRouter(
      tester,
    ).push(AppRoutes.newCareRecord('p1', kind: CareKind.vetExam));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(CbTextField, 'Weight, kg'),
        matching: find.byType(TextFormField),
      ),
      '4.4',
    );
    await tapVisible(tester, find.text('Save'));

    expect(find.byType(WeightTab), findsOneWidget);
    expect(find.text('4.4 kg'), findsWidgets);
    expect(weight.listCalls, greaterThan(1));
  });

  testWidgets('fits a narrow phone in Russian', (tester) async {
    weight.weighings.addAll([
      testWeight('w1', on: daysAgo(40), kg: 4.1),
      testWeight(
        'w2',
        on: daysAgo(2),
        kg: 4.3,
        bodyCondition: const BodyCondition(5, 9),
        note: 'Перед завтраком, после долгой прогулки по парку',
      ),
    ]);
    await openWeight(tester, language: 'ru', size: const Size(360, 2400));

    expect(find.text('Последний вес'), findsOneWidget);
    expect(find.text('Упитанность 5/9 · норма 4–5'), findsOneWidget);
    expect(find.textContaining('+0,2 кг с '), findsOneWidget);
    expect(find.text('Динамика'), findsOneWidget);

    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Добавить оценку упитанности'));
    expect(find.text('Шкала 1–9'), findsOneWidget);
    // An overflow would have failed the test by now.
  });

  for (final language in ['ru', 'en']) {
    testWidgets('the chart and its legend fit a 320 dp phone with text twice '
        'as large ($language)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      weight.weighings.addAll([
        testWeight('w1', on: daysAgo(40), kg: 4.1),
        testWeight('w2', on: daysAgo(2), kg: 4.3),
      ]);
      care.records = [
        testRecord(
          'r1',
          kind: CareKind.vetExam,
          title: 'Check-up',
          performedOn: daysAgo(20),
          weightKg: 4.25,
        ),
      ];
      await openWeight(tester, language: language, size: const Size(320, 640));

      // The legend names both markers: a vet's weight is in view.
      await scrollWeightTo(tester, find.byType(WeightChart));
      // An overflow would have failed the test by now.
    });
  }
}
