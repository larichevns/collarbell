// The visor in the app (data/api/app_events.dart): the screens by their
// route's pattern, tab switches too, never an id; a few actions by name;
// the error messages on the screen by their kind and codes; all sent when
// the app goes to the background. Nothing is sent for a signed-out person,
// and what waits goes with a sign-out.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/data/api/app_events.dart';
import 'package:collarbell/features/auth/auth_providers.dart';
import 'package:collarbell/features/feeding/feeding.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pet_detail_screen.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/pump.dart';

/// Takes what the app sends to the server's visor.
class _Visor {
  final batches = <List<AppEvent>>[];

  Future<void> send(List<AppEvent> events) async => batches.add(events);

  List<AppEvent> get sent => [for (final batch in batches) ...batch];

  List<String> named(AppEventKind kind) => [
    for (final event in sent)
      if (event.kind == kind) event.name,
  ];

  /// The visor on, as in a release build, sending here.
  List<Override> get on => [
    appEventsOnProvider.overrideWithValue(true),
    sendAppEventsProvider.overrideWithValue(send),
  ];
}

/// The app goes to the background, and comes back.
Future<void> _background(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pumpAndSettle();
}

TodayFeeding _feeding(String routineId, String petName) => TodayFeeding(
  routineId: routineId,
  petId: 'pet-$petName',
  petName: petName,
  time: const TimeOfDay(hour: 8, minute: 0),
);

void main() {
  const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

  testWidgets('screens go by their pattern, tab switches too, never an id; '
      'all goes when the app goes to the background', (tester) async {
    final visor = _Visor();
    await pumpApp(
      tester,
      location: AppRoutes.pet('p1', tab: PetTab.health),
      overrides: [
        ...fakeRepositories(pets: FakePetsRepository([murka])),
        ...visor.on,
      ],
    );

    appRouter(tester).push(AppRoutes.editPet('p1'));
    await tester.pumpAndSettle();
    appRouter(tester).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Supplies'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Pets'));
    await tester.pumpAndSettle();
    expect(visor.batches, isEmpty);
    await _background(tester);

    expect(visor.batches, hasLength(1));
    expect(visor.named(AppEventKind.screen), [
      '/home',
      '/pets/:petId',
      '/pets/:petId/edit',
      '/pets/:petId',
      '/supplies',
      '/pets/:petId',
    ]);
    expect('${visor.sent}', isNot(contains('p1')));
    expect('${visor.sent}', isNot(contains('health')));
  });

  testWidgets('"Fed" and "All fed" go by their names; an error message goes '
      'once, by its kind and codes, never its words', (tester) async {
    final visor = _Visor();
    final feeding = FakeFeedingRepository();
    final pets = FakePetsRepository([murka]);
    final supplies = FakeSuppliesRepository();
    await pumpApp(
      tester,
      location: AppRoutes.today,
      overrides: [
        ...fakeRepositories(
          pets: pets,
          feeding: feeding,
          supplies: supplies,
          today: FakeTodayRepository(
            feedingMarks: feeding,
            feedings: [
              _feeding('r1', 'Barsik'),
              _feeding('r2', 'Murka'),
              _feeding('r3', 'Rex'),
            ],
          ),
        ),
        ...visor.on,
      ],
    );

    await tester.tap(find.byKey(const ValueKey('fed-r1@480')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All fed'));
    await tester.pumpAndSettle();
    // The Supplies tab can't load: its error shows, and stays through
    // rebuilds.
    supplies.error = const ApiException(
      ApiErrorKind.server,
      statusCode: 500,
      problem: ProblemDetails(
        title: 'Murka could not be read',
        traceId: '00-4bf92f35-01',
      ),
    );
    await tester.tap(find.widgetWithText(NavigationDestination, 'Supplies'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Supplies'));
    await tester.pumpAndSettle();
    await _background(tester);

    expect(
      [
        for (final event in visor.sent)
          if (event.kind != AppEventKind.screen) (event.name, event.detail),
      ],
      [
        ('fed', null),
        ('fed-all', null),
        ('server', 'status=500 traceId=00-4bf92f35-01'),
      ],
    );
    expect('${visor.sent}', isNot(contains('Murka')));
    expect('${visor.sent}', isNot(contains('Barsik')));
  });

  testWidgets('a pet saved and another group picked go by their names, '
      'never what was typed or picked', (tester) async {
    final visor = _Visor();
    final me = FakeMeRepository(
      households: [
        testHousehold(FakeMeRepository.homeId),
        testHousehold('office', name: 'Office', role: HouseholdRole.helper),
      ],
    );
    await pumpApp(
      tester,
      location: AppRoutes.newPet,
      // Tall enough for the whole form.
      size: const Size(390, 2600),
      me: me,
      overrides: [...fakeRepositories(), ...visor.on],
    );

    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(CbTextField, 'Name'),
        matching: find.byType(TextFormField),
      ),
      'Murka',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('switchHousehold')));
    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();
    await _background(tester);

    expect(visor.named(AppEventKind.action), ['pet-saved', 'group-switched']);
    expect('${visor.sent}', isNot(contains('Murka')));
    expect('${visor.sent}', isNot(contains('Office')));
    expect('${visor.sent}', isNot(contains('office')));
  });

  testWidgets('nothing goes for a signed-out person: what waits goes with '
      'the sign-out, and the next sign-in starts afresh', (tester) async {
    final visor = _Visor();
    await pumpApp(
      tester,
      location: AppRoutes.pets,
      overrides: [...fakeRepositories(), ...visor.on],
    );

    await appContainer(tester).read(authRepositoryProvider).signOut();
    await tester.pumpAndSettle();
    expect(find.text('Continue as developer'), findsOneWidget);
    await _background(tester);
    expect(visor.batches, isEmpty);

    await tapVisible(tester, find.text('Continue as developer'));
    await _background(tester);

    expect(visor.batches, hasLength(1));
    // Another account, with no pets yet: Home opens its onboarding.
    expect(visor.named(AppEventKind.screen), ['/home', '/welcome']);
  });
}
