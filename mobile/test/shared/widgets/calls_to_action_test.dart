// Calls to action are buttons you want to press: the main one of a screen
// or an empty tab is a filled button, the others outlined, and where
// several things can be started, action cards. Never bare text or a bare
// icon (escapes such as "Skip" and dialog answers stay text).
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/feeding/feeding.dart';
import 'package:collarbell/features/notifications/push_registration.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pet_detail_screen.dart';
import 'package:collarbell/features/visits/visit.dart';
import 'package:collarbell/shared/widgets/cb_action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);
const rex = Pet(id: 'p2', name: 'Rex', species: PetSpecies.dog);

TodayFeeding feeding(Pet pet) => TodayFeeding(
  routineId: 'feed-${pet.id}',
  petId: pet.id,
  petName: pet.name,
  time: const TimeOfDay(hour: 8, minute: 0),
);

/// A filled button with [text], whichever constructor made it
/// (`FilledButton.icon` is a subclass).
Finder filled(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

void main() {
  testWidgets("Today's headers: outlined buttons with words, a round "
      '"+" where there is no room', (tester) async {
    final supplies = FakeSuppliesRepository(
      supplies: [testSupply('low', 'Low food', remaining: 200)],
    );
    await pumpApp(
      tester,
      location: AppRoutes.today,
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka, rex]),
        supplies: supplies,
        today: FakeTodayRepository(
          supplies: supplies,
          feedings: [feeding(murka), feeding(rex)],
          visits: [
            TodayVisit(
              id: 'v1',
              type: VisitType.vet,
              title: 'Check-up',
              date: testToday(),
              time: const TimeOfDay(hour: 10, minute: 0),
              daysAway: 0,
              pets: const [],
            ),
          ],
        ),
      ),
    );

    expect(find.widgetWithText(OutlinedButton, 'All fed'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'All visits'), findsOneWidget);
    final add = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Symbols.add_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(add.tooltip, 'Add a visit');
    // An outlined icon button: it has a side.
    expect(add.style?.side, isNotNull);
    await tester.scrollUntilVisible(find.text('All supplies'), 300);
    expect(find.widgetWithText(OutlinedButton, 'All supplies'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'All supplies'), findsNothing);
  });

  testWidgets('an empty Today with pets: action cards, each a button', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.today,
      overrides: fakeRepositories(pets: FakePetsRepository([murka])),
    );

    expect(find.byType(CbActionCard), findsNWidgets(3));
    expect(find.widgetWithText(CbActionCard, 'Add feeding'), findsOneWidget);
    expect(
      find.widgetWithText(CbActionCard, "We'll remind you when to feed"),
      findsOneWidget,
    );
    expect(find.byType(TextButton), findsNothing);

    // The words are part of the button.
    await tester.tap(find.text('Vet, grooming'));
    await tester.pumpAndSettle();
    expect(find.text('New visit'), findsOneWidget);
  });

  testWidgets("a pet's empty tabs say what to do with a real button", (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.pet('p1', tab: PetTab.health),
      size: const Size(390, 1400),
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        ai: FakeAiRepository(status: testAiStatus),
      ),
    );

    // Health: the plan's filled button, and cards for the history.
    expect(filled('Add plan'), findsOneWidget);
    expect(find.byKey(const ValueKey('historyScan')), findsOneWidget);
    expect(find.byKey(const ValueKey('historyNote')), findsOneWidget);
    expect(find.byKey(const ValueKey('historyAdd')), findsOneWidget);

    for (final (tab, label) in [
      ('Feeding', 'Add feeding'),
      ('Documents', 'Add document'),
    ]) {
      await tapVisible(tester, find.widgetWithText(Tab, tab));
      expect(filled(label), findsOneWidget, reason: tab);
    }
  });

  testWidgets('with something in them, the tabs keep an outlined button '
      'in the header', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.pet('p1', tab: PetTab.feeding),
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        feeding: FakeFeedingRepository(
          schedules: [
            const FeedingSchedule(
              id: 'f1',
              petId: 'p1',
              times: [TimeOfDay(hour: 8, minute: 0)],
              days: everyDay,
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const ValueKey('addFeeding')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('no visits: the button is in the empty list, not over it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.visits,
      overrides: fakeRepositories(),
    );

    expect(filled('Add a visit'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('notifications refused: "Open settings" is an outlined '
      'button', (tester) async {
    final push = FakePushPlatform(allowed: false);
    await pumpApp(
      tester,
      location: AppRoutes.today,
      overrides: fakeRepositories(push: push),
    );
    // Asked before, on this phone, and refused.
    await appContainer(
      tester,
    ).read(sharedPreferencesProvider).setBool('push.permissionAsked', true);
    appContainer(tester).invalidate(pushRegistrationProvider);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, 'Open settings'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open settings'));
    expect(push.settingsOpened, 1);
  });
}
