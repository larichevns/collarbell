// The group on screen: More and Today show it; switching (from the list, by
// creating one, or by tapping a push of another group) starts every screen
// afresh with the other group's data, never showing the first one's; when
// the user isn't in the group any more, the app goes back to their first
// one, says so and drops the group's offline copies; the role is checked
// again when the app comes back to the screen.
import 'dart:async';
import 'dart:convert';

import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/offline_cache.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// Pets whose loading can be held, like a slow server.
class _SlowPets extends FakePetsRepository {
  _SlowPets(super.pets);

  Completer<void>? gate;

  @override
  Future<List<Pet>> getPets() async {
    final gate = this.gate;
    if (gate != null) await gate.future;
    return super.getPets();
  }
}

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);
const rex = Pet(id: 'p2', name: 'Rex', species: PetSpecies.dog);

void main() {
  late FakeMeRepository me;
  late FakePetsRepository pets;

  setUp(() {
    me = FakeMeRepository(
      households: [
        testHousehold(FakeMeRepository.homeId),
        testHousehold(
          'office',
          name: 'Office',
          role: HouseholdRole.helper,
          memberCount: 3,
        ),
      ],
    );
    pets = FakePetsRepository();
  });

  CurrentHousehold? current(WidgetTester tester) =>
      appContainer(tester).read(currentHouseholdProvider);

  testWidgets('More shows the group, the role and how many people', (
    tester,
  ) async {
    await pumpApp(tester, location: AppRoutes.more, me: me);

    expect(find.text('Group'), findsOneWidget);
    expect(find.text('My home'), findsOneWidget);
    expect(find.text('Owner · 1 person'), findsOneWidget);
    expect(find.text('Switch group'), findsOneWidget);
    expect(find.text('Members and invites'), findsOneWidget);
    // The server's choice is remembered for the next start.
    expect(current(tester)?.id, FakeMeRepository.homeId);
  });

  testWidgets('switching reloads every screen with the other group, and is '
      'remembered', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.more,
      me: me,
      overrides: fakeRepositories(pets: pets),
    );
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    final petCalls = pets.calls;
    final syncs = me.updates.length;

    await tapVisible(tester, find.byKey(const ValueKey('switchHousehold')));
    expect(find.text('Your groups'), findsOneWidget);
    expect(find.text('Helper · 3 people'), findsOneWidget);
    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();

    expect(find.text('You\'re in “Office” now.'), findsOneWidget);
    expect(current(tester)?.id, 'office');
    expect(current(tester)?.role, HouseholdRole.helper);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Helper · 3 people'), findsOneWidget);
    final saved = appContainer(tester)
        .read(sharedPreferencesProvider)
        .getString(CurrentHouseholdNotifier.keyFor(testUid));
    expect(jsonDecode(saved!)['id'], 'office');
    // The profile sync ran again, and every screen's data after it (a tab
    // out of sight when it comes back).
    expect(me.updates.length, syncs + 1);
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    expect(pets.calls, greaterThan(petCalls));
  });

  testWidgets('a new group: named, created, and the app moves there', (
    tester,
  ) async {
    final households = FakeHouseholdRepository(me: me);
    await pumpApp(
      tester,
      location: AppRoutes.more,
      me: me,
      overrides: fakeRepositories(household: households),
    );

    await tapVisible(tester, find.byKey(const ValueKey('switchHousehold')));
    await tester.tap(find.byKey(const ValueKey('createHousehold')));
    await tester.pumpAndSettle();
    expect(find.text('New group'), findsOneWidget);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Give the group a name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Cottage');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(households.created, ['Cottage']);
    expect(current(tester)?.id, 'new-1');
    expect(find.text('You\'re in “Cottage” now.'), findsOneWidget);
    expect(find.text('Cottage'), findsOneWidget);
  });

  testWidgets('removed from the group on screen: back to the first one, '
      'with a message', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.today,
      me: me,
      household: const CurrentHousehold(
        id: 'office',
        name: 'Office',
        role: HouseholdRole.helper,
      ),
      overrides: fakeRepositories(pets: pets),
    );
    expect(current(tester)?.id, 'office');
    final petCalls = pets.calls;

    // What the API client does when a request for it is refused (403,
    // not-a-household-member; see household_header_test.dart).
    me.households.removeWhere((household) => household.id == 'office');
    appContainer(tester).read(currentHouseholdProvider.notifier).lost('office');
    await tester.pumpAndSettle();

    expect(find.text('You\'re no longer in “Office”.'), findsOneWidget);
    expect(current(tester)?.id, FakeMeRepository.homeId);
    expect(current(tester)?.role, HouseholdRole.owner);
    expect(pets.calls, greaterThan(petCalls));
  });

  testWidgets("the other group's pets only, also while they load, and not "
      'the first one\'s when they don\'t', (tester) async {
    final slow = _SlowPets([murka]);
    await pumpApp(
      tester,
      location: AppRoutes.pets,
      me: me,
      overrides: fakeRepositories(pets: slow),
    );
    expect(find.text('Murka'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    // Office's pets come slowly.
    slow
      ..pets = [rex]
      ..gate = Completer<void>();
    await tapVisible(tester, find.byKey(const ValueKey('switchHousehold')));
    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pets'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Murka'), findsNothing);

    slow.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Rex'), findsOneWidget);

    // Back home, but the server doesn't answer and there is no copy: an
    // error, not Office's pets.
    slow.error = networkError;
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('switchHousehold')));
    await tester.tap(find.text('My home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsNothing);
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('removed from a group: its offline copies go, the others '
      'stay', (tester) async {
    final copies = MemoryOfflineCacheStore();
    final at = DateTime(2026, 10, 5);
    copies.entries['$testUid office /api/v1/pets?'] = CachedAnswer(1, at);
    copies.entries['$testUid home /api/v1/pets?'] = CachedAnswer(2, at);
    await pumpApp(
      tester,
      location: AppRoutes.today,
      me: me,
      household: const CurrentHousehold(id: 'office', name: 'Office'),
      offlineCopies: copies,
    );

    me.households.removeWhere((household) => household.id == 'office');
    appContainer(tester).read(currentHouseholdProvider.notifier).lost('office');
    await tester.pumpAndSettle();

    expect(copies.entries.keys, ['$testUid home /api/v1/pets?']);
  });

  testWidgets("a saved group the user isn't in any more: /me answers for the "
      'first one, and the app moves there', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.today,
      me: me,
      household: const CurrentHousehold(id: 'gone', name: 'Cottage'),
    );

    expect(find.text('You\'re no longer in “Cottage”.'), findsOneWidget);
    expect(current(tester)?.id, FakeMeRepository.homeId);
  });

  testWidgets('a push of another group switches to it, then opens its '
      'screen', (tester) async {
    final push = FakePushPlatform();
    final today = FakeTodayRepository();
    await pumpApp(
      tester,
      location: AppRoutes.more,
      me: me,
      overrides: fakeRepositories(push: push, today: today),
    );
    final syncs = me.updates.length;

    push.tap({'kind': 'feeding', 'householdId': FakeMeRepository.homeId});
    await tester.pumpAndSettle();
    // The group on screen already: nothing reloads but Today.
    expect(me.updates.length, syncs);

    push.tap({'kind': 'feeding', 'householdId': 'office'});
    await tester.pumpAndSettle();

    expect(current(tester)?.id, 'office');
    expect(current(tester)?.name, 'Office');
    expect(current(tester)?.role, HouseholdRole.helper);
    expect(me.updates.length, syncs + 1);
    expect(appRouter(tester).state.matchedLocation, AppRoutes.today);
    // Where the app is now, said briefly; Today shows it too.
    expect(find.text('You\'re in “Office” now.'), findsOneWidget);
    expect(find.textContaining('· Office'), findsOneWidget);
  });

  testWidgets('Today names the group for someone in more than one', (
    tester,
  ) async {
    await pumpApp(tester, location: AppRoutes.today, me: me);

    expect(find.textContaining('· My home'), findsOneWidget);
  });

  testWidgets('Today names no group for someone in just one', (tester) async {
    me.households.removeLast();
    await pumpApp(tester, location: AppRoutes.today, me: me);

    expect(find.textContaining('· My home'), findsNothing);
    expect(find.text('Today'), findsWidgets);
  });

  testWidgets("the name the server gives a first group: \"My home\" for its "
      'owner, "Home" for the others', (tester) async {
    me.households.add(testHousehold('anna-home', role: HouseholdRole.helper));
    await pumpApp(tester, location: AppRoutes.more, me: me);

    await tapVisible(tester, find.byKey(const ValueKey('switchHousehold')));

    expect(find.text('My home'), findsWidgets);
    // In the sheet: the tab bar has a "Home" too.
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Home'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('back in the app, the role is asked again: an owner may have '
      'changed it', (tester) async {
    me.households.first = testHousehold(
      FakeMeRepository.homeId,
      role: HouseholdRole.member,
    );
    await pumpApp(tester, location: AppRoutes.pets, me: me);
    expect(find.text('Add pet'), findsOneWidget);

    me.households.first = testHousehold(
      FakeMeRepository.homeId,
      role: HouseholdRole.helper,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Add pet'), findsNothing);
  });

  testWidgets('a push of another group: the tab left behind opens at its '
      'first screen too', (tester) async {
    final push = FakePushPlatform();
    await pumpApp(
      tester,
      location: AppRoutes.newPet,
      me: me,
      overrides: fakeRepositories(pets: pets, push: push),
    );

    push.tap({'kind': 'feeding', 'householdId': 'office'});
    await tester.pumpAndSettle();
    expect(appRouter(tester).state.matchedLocation, AppRoutes.today);
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();

    expect(appRouter(tester).state.matchedLocation, AppRoutes.pets);
  });

  testWidgets('after a switch, a tab still showing the other group opens at '
      'its first screen', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.newPet,
      me: me,
      overrides: fakeRepositories(pets: pets),
    );
    expect(appRouter(tester).state.matchedLocation, AppRoutes.newPet);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('switchHousehold')));
    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();

    expect(appRouter(tester).state.matchedLocation, AppRoutes.pets);
  });
}
