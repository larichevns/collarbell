// The sheet that adds, changes and deletes a weighing: today by default, the
// weight with a point or a comma (to the gram), a body condition score only
// when asked for, a note; mistakes caught before sending, a lost answer that
// adds nothing twice, the server's field errors on their fields, deleting
// after asking, and closing with something typed asking first.
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/weight/weight.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

final murka = Pet(
  id: 'p1',
  name: 'Murka',
  species: PetSpecies.cat,
  birthDate: DateTime(2024, 3, 1),
);

final today = testToday();

DateTime daysAgo(int days) =>
    DateTime(today.year, today.month, today.day - days);

Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

String textOf(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(field(label)).controller!.text;

ChoiceChip score(WidgetTester tester, int value) =>
    tester.widget<ChoiceChip>(find.byKey(ValueKey('score-$value')));

void main() {
  late FakeWeightRepository weight;

  setUp(() => weight = FakeWeightRepository());

  Future<void> openWeight(WidgetTester tester) => pumpApp(
    tester,
    location: '/pets/p1?tab=weight',
    overrides: fakeRepositories(
      pets: FakePetsRepository([murka]),
      weight: weight,
    ),
  );

  /// Opens the sheet of a new weighing from the empty tab.
  Future<void> openNew(WidgetTester tester) async {
    await openWeight(tester);
    await tester.tap(find.text('Add weight'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) =>
      tapVisible(tester, find.byKey(const ValueKey('saveWeighing')));

  testWidgets('adds a weighing: today, the weight with a comma, a score '
      'asked for, a note', (tester) async {
    await openNew(tester);
    expect(find.text('New weighing'), findsOneWidget);
    // The score is folded away until asked for.
    expect(find.text('Body condition score'), findsNothing);

    await tester.enterText(field('Weight, kg'), '4,235');
    await tapVisible(tester, find.text('Add body condition score'));
    expect(
      find.text(
        'Ideal is 4–5 of 9: the ribs are easy to feel, and the waist shows '
        'from above.',
      ),
      findsOneWidget,
    );
    await tapVisible(tester, find.byKey(const ValueKey('score-6')));
    await tester.enterText(field('Note'), '  Before breakfast  ');
    await save(tester);

    final (petId, input) = weight.created.single;
    expect(petId, 'p1');
    expect(input.measuredOn, today);
    expect(input.weightKg, 4.235);
    expect(input.bodyCondition, const BodyCondition(6, 9));
    expect(input.note, 'Before breakfast');
    expect(weight.createRequestIds.single, isNotEmpty);
    // The sheet closed, and the tab shows the weight.
    expect(find.text('New weighing'), findsNothing);
    expect(find.text('4.235 kg'), findsWidgets);
  });

  testWidgets('the other scale clears the score; a removed score is not '
      'sent', (tester) async {
    await openNew(tester);
    await tester.enterText(field('Weight, kg'), '4.2');
    await tapVisible(tester, find.text('Add body condition score'));
    await tapVisible(tester, find.byKey(const ValueKey('score-7')));

    await tapVisible(tester, find.text('Scale 1–5'));
    expect(find.byKey(const ValueKey('score-7')), findsNothing);
    expect([
      for (var value = 1; value <= 5; value++) score(tester, value).selected,
    ], everyElement(isFalse));
    expect(
      find.text(
        'Ideal is 3 of 5: the ribs are easy to feel, and the waist shows '
        'from above.',
      ),
      findsOneWidget,
    );
    await tapVisible(tester, find.byKey(const ValueKey('score-3')));
    await tapVisible(tester, find.text('Remove the score'));
    expect(find.text('Body condition score'), findsNothing);
    await save(tester);

    expect(weight.created.single.$2.bodyCondition, isNull);
  });

  testWidgets('mistakes are caught before sending', (tester) async {
    await openNew(tester);

    await save(tester);
    expect(find.text('Enter the weight'), findsOneWidget);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);

    await tester.enterText(field('Weight, kg'), '250');
    await save(tester);
    expect(find.text('Use a weight above 0 and up to 200 kg'), findsOneWidget);

    // Grams typed as kilograms' decimals: one too many.
    await tester.enterText(field('Weight, kg'), '4.2355');
    await save(tester);
    expect(find.text('Use 3 decimals at most'), findsOneWidget);

    // Only digits and a separator can be typed.
    await tester.enterText(field('Weight, kg'), '-4.2kg');
    expect(textOf(tester, 'Weight, kg'), '4.2');
    expect(weight.createRequestIds, isEmpty);
  });

  testWidgets('a lost answer: saving again sends the same request id and '
      'adds the weighing once', (tester) async {
    await openNew(tester);
    weight.loseNextCreateResponse = true;
    await tester.enterText(field('Weight, kg'), '4.2');

    await save(tester);
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('New weighing'), findsOneWidget, reason: 'still open');

    await save(tester);
    expect(weight.createRequestIds, hasLength(2));
    expect(weight.createRequestIds.toSet(), hasLength(1), reason: 'same id');
    expect(weight.weighings, hasLength(1), reason: 'added once');
    expect(find.text('New weighing'), findsNothing);
  });

  testWidgets('a lost answer, then a correction: the corrected weighing is '
      'what stays, and it is added once', (tester) async {
    await openNew(tester);
    // The first try reaches the server, but its answer is lost.
    weight.loseNextCreateResponse = true;
    await tester.enterText(field('Weight, kg'), '4.2');
    await save(tester);
    expect(find.text('New weighing'), findsOneWidget, reason: 'still open');

    // The user notices the typo and fixes it before saving again.
    await tester.enterText(field('Weight, kg'), '4.3');
    await save(tester);

    expect(find.text('New weighing'), findsNothing);
    expect(weight.createRequestIds.toSet(), hasLength(1), reason: 'same id');
    expect(weight.weighings.single.weightKg, 4.3);
    expect(weight.updated.single.$2.weightKg, 4.3);
  });

  testWidgets('a value the server refuses shows under its field', (
    tester,
  ) async {
    await openNew(tester);
    weight.saveError = validationProblem({
      'measuredOn': ["A weighing can't be before the pet was born."],
    });
    await tester.enterText(field('Weight, kg'), '4.2');

    await save(tester);

    expect(find.text("This value wasn't accepted. Check it."), findsOneWidget);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
    expect(find.text('New weighing'), findsOneWidget);
  });

  testWidgets('changes a weighing: the sheet opens with its values', (
    tester,
  ) async {
    weight.weighings.add(
      testWeight(
        'w1',
        on: daysAgo(3),
        kg: 4.2,
        bodyCondition: const BodyCondition(5, 9),
        note: 'Before breakfast',
      ),
    );
    await openWeight(tester);
    await tapVisible(tester, find.byKey(const ValueKey('weighing-w1')));

    expect(find.text('Edit weighing'), findsOneWidget);
    expect(textOf(tester, 'Weight, kg'), '4.2');
    expect(textOf(tester, 'Note'), 'Before breakfast');
    expect(score(tester, 5).selected, isTrue);

    await tester.enterText(field('Weight, kg'), '4.3');
    await save(tester);

    final (id, input) = weight.updated.single;
    expect(id, 'w1');
    expect(input.measuredOn, daysAgo(3));
    expect(input.weightKg, 4.3);
    expect(input.bodyCondition, const BodyCondition(5, 9));
    expect(input.note, 'Before breakfast');
    expect(weight.created, isEmpty);
    expect(find.text('4.3 kg'), findsWidgets);
  });

  testWidgets('a weighing from before a birth date set later keeps its date '
      'and can still be changed', (tester) async {
    // Weighed on 20 February; later the owner learned Murka was born on
    // 1 March. Like the server, the sheet checks only a new date.
    weight.weighings.add(testWeight('w1', on: DateTime(2024, 2, 20), kg: 0.1));
    await openWeight(tester);
    await tapVisible(tester, find.byKey(const ValueKey('weighing-w1')));

    await tester.enterText(field('Note'), 'First day home');
    await save(tester);

    final (id, input) = weight.updated.single;
    expect(id, 'w1');
    expect(input.measuredOn, DateTime(2024, 2, 20));
    expect(input.note, 'First day home');
  });

  testWidgets('a weighing made by a newer app is shown, not changed', (
    tester,
  ) async {
    weight.weighings.add(
      testWeight(
        'w1',
        on: daysAgo(3),
        kg: 4.2,
        bodyCondition: const BodyCondition(4, 7),
        hasUnknownValues: true,
      ),
    );
    await openWeight(tester);
    await tapVisible(tester, find.byKey(const ValueKey('weighing-w1')));

    expect(
      find.text(
        'This weighing was made in a newer version of the app. Update the '
        'app to change it.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('saveWeighing')), findsNothing);
  });

  testWidgets('deletes a weighing after asking', (tester) async {
    weight.weighings.add(testWeight('w1', on: daysAgo(3), kg: 4.2));
    await openWeight(tester);
    await tapVisible(tester, find.byKey(const ValueKey('weighing-w1')));

    await tester.tap(find.byTooltip('Delete weighing'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this weighing?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(weight.deleted, isEmpty);
    expect(find.text('Edit weighing'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete weighing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(weight.deleted, ['w1']);
    expect(find.text('Edit weighing'), findsNothing);
    expect(find.text('No weighings yet'), findsOneWidget);
  });

  testWidgets('a weighing deleted elsewhere: saving says so and closes', (
    tester,
  ) async {
    weight.weighings.add(testWeight('w1', on: daysAgo(3), kg: 4.2));
    await openWeight(tester);
    await tapVisible(tester, find.byKey(const ValueKey('weighing-w1')));
    weight.weighings.clear();

    await tester.enterText(field('Weight, kg'), '4.3');
    await save(tester);

    expect(
      find.text('This weighing has been deleted, probably on another device.'),
      findsOneWidget,
    );
    expect(find.text('Edit weighing'), findsNothing);
    expect(find.text('No weighings yet'), findsOneWidget);
  });

  testWidgets('closing with something typed asks first', (tester) async {
    await openNew(tester);
    await tester.enterText(field('Weight, kg'), '4.2');

    // A tap outside the sheet.
    await tester.tapAt(const Offset(20, 120));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Weight, kg'), '4.2');

    await tester.tapAt(const Offset(20, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('New weighing'), findsNothing);
    expect(weight.createRequestIds, isEmpty);
  });
}
