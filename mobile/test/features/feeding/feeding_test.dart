// Feeding: the schedule form, and today's feedings with "Fed", "All fed",
// someone else marking first, and taking a mark back.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/feeding/feeding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

TodayFeeding feeding(
  String routineId,
  String petName, {
  TimeOfDay time = const TimeOfDay(hour: 8, minute: 0),
  FeedingMark? mark,
  String? food,
  double? amount,
}) => TodayFeeding(
  routineId: routineId,
  petId: 'pet-$petName',
  petName: petName,
  time: time,
  food: food,
  amount: amount,
  unit: amount == null ? null : PortionUnit.gram,
  mark: mark,
);

FeedingMark markBy(String routineId, {String? name, bool byMe = false}) =>
    FeedingMark(
      id: 'mark-$routineId',
      routineId: routineId,
      date: testToday(),
      time: const TimeOfDay(hour: 8, minute: 0),
      skipped: false,
      doneAt: DateTime(2026, 10, 2, 8, 2),
      byMe: byMe,
      byName: name,
    );

void main() {
  group('the schedule form', () {
    testWidgets('adds the times in order, every day, with food and portion', (
      tester,
    ) async {
      final repository = FakeFeedingRepository();
      await pumpApp(
        tester,
        location: AppRoutes.newFeeding('p1'),
        overrides: fakeRepositories(feeding: repository),
      );

      await tester.tap(find.text('Add time'));
      await tester.pumpAndSettle();
      await enterPickerTime(tester, const TimeOfDay(hour: 20, minute: 0));
      await tester.tap(find.text('Add time'));
      await tester.pumpAndSettle();
      await enterPickerTime(tester, const TimeOfDay(hour: 8, minute: 0));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Royal Canin Sterilised'),
        'Royal Canin',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '40'), '40.5');
      await tapVisible(tester, find.text('Save'));

      final input = repository.lastInput!;
      expect(input.times, const [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ]);
      expect(input.days, everyDay);
      expect(
        (input.food, input.amount, input.unit),
        ('Royal Canin', 40.5, PortionUnit.gram),
      );
      expect(repository.lastRequestId, isNotNull);
    });

    testWidgets("takes decimals that floating point can't hold exactly", (
      tester,
    ) async {
      final repository = FakeFeedingRepository();
      await pumpApp(
        tester,
        location: AppRoutes.newFeeding('p1'),
        overrides: fakeRepositories(feeding: repository),
      );

      await tester.tap(find.text('Add time'));
      await tester.pumpAndSettle();
      await enterPickerTime(tester, const TimeOfDay(hour: 8, minute: 0));
      // As a double, 2.2 × 100 isn't exactly 220: the check reads the text.
      await tester.enterText(find.widgetWithText(TextFormField, '40'), '2.2');
      await tapVisible(tester, find.text('Save'));

      expect(repository.lastInput?.amount, 2.2);
    });

    testWidgets('needs a time', (tester) async {
      final repository = FakeFeedingRepository();
      await pumpApp(
        tester,
        location: AppRoutes.newFeeding('p1'),
        overrides: fakeRepositories(feeding: repository),
      );

      await tapVisible(tester, find.text('Save'));

      expect(find.text('Add at least one time'), findsOneWidget);
      expect(repository.lastInput, isNull);
    });
  });

  group('today', () {
    testWidgets('"Fed" marks one pet; "All fed" the rest of that time', (
      tester,
    ) async {
      final repository = FakeFeedingRepository();
      await pumpApp(
        tester,
        location: AppRoutes.today,
        overrides: fakeRepositories(
          feeding: repository,
          today: FakeTodayRepository(
            feedingMarks: repository,
            feedings: [
              feeding('r1', 'Barsik', food: 'Royal Canin', amount: 40),
              feeding('r2', 'Murka'),
              feeding('r3', 'Rex'),
            ],
          ),
        ),
      );

      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Royal Canin, 40 g'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fed-r1@480')));
      await tester.pumpAndSettle();
      expect(repository.marks.map((m) => m.$1), ['r1']);

      await tester.tap(find.text('All fed'));
      await tester.pumpAndSettle();
      expect(repository.marks.map((m) => m.$1), ['r1', 'r2', 'r3']);
      expect(repository.marks.first.$2, testToday());
      expect(repository.marks.first.$3, const TimeOfDay(hour: 8, minute: 0));
    });

    testWidgets(
      '"All fed" stops at the first pet the server didn\'t answer for',
      (tester) async {
        final repository = FakeFeedingRepository()
          ..markError = const ApiException(ApiErrorKind.network);
        await pumpApp(
          tester,
          location: AppRoutes.today,
          overrides: fakeRepositories(
            feeding: repository,
            today: FakeTodayRepository(
              feedingMarks: repository,
              feedings: [feeding('r1', 'Barsik'), feeding('r2', 'Murka')],
            ),
          ),
        );

        await tester.tap(find.text('All fed'));
        await tester.pumpAndSettle();

        // The second pet would only wait as long again.
        expect(repository.markAttempts, 1);
        expect(find.textContaining("Can't reach the server."), findsOneWidget);
      },
    );

    testWidgets('someone else marked it first: who and when', (tester) async {
      final repository = FakeFeedingRepository()
        ..takenBy['r1'] = markBy('r1', name: 'Anna');
      await pumpApp(
        tester,
        location: AppRoutes.today,
        overrides: fakeRepositories(
          feeding: repository,
          today: FakeTodayRepository(
            feedingMarks: repository,
            feedings: [feeding('r1', 'Murka')],
          ),
        ),
      );

      await tester.tap(find.text('Fed'));
      await tester.pumpAndSettle();

      expect(find.text('Already marked: Anna, 8:02 AM'), findsOneWidget);
      expect(repository.marks, isEmpty);
      // Today reloaded: the row shows Anna's mark, not a "Fed" button.
      expect(find.text('Marked by Anna'), findsOneWidget);
      expect(find.text('Fed'), findsNothing);
    });

    testWidgets('a long press skips a feeding after asking', (tester) async {
      final repository = FakeFeedingRepository();
      await pumpApp(
        tester,
        location: AppRoutes.today,
        overrides: fakeRepositories(
          feeding: repository,
          today: FakeTodayRepository(
            feedingMarks: repository,
            feedings: [feeding('r1', 'Murka')],
          ),
        ),
      );

      await tester.longPress(find.text('Murka'));
      await tester.pumpAndSettle();
      expect(find.text('Murka: skip this feeding?'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(repository.marks.single.$4, isTrue);
    });

    testWidgets('a mark can be taken back', (tester) async {
      final repository = FakeFeedingRepository();
      await pumpApp(
        tester,
        location: AppRoutes.today,
        overrides: fakeRepositories(
          feeding: repository,
          today: FakeTodayRepository(
            feedings: [feeding('r1', 'Murka', mark: markBy('r1', byMe: true))],
          ),
        ),
      );

      // Marked by me: just the time; no "All fed" for a single pet.
      expect(find.text('8:02 AM'), findsOneWidget);
      expect(find.text('All fed'), findsNothing);
      await tester.tap(find.text('8:02 AM'));
      await tester.pumpAndSettle();
      expect(find.text('Murka: take the mark back?'), findsOneWidget);
      await tester.tap(find.text('Take back'));
      await tester.pumpAndSettle();

      expect(repository.undone, ['mark-r1']);
    });
  });
}
