// Home, the first tab: the greeting, the pets, what is important right now
// (made of Today's data, with "Fed" working as on Today) and the quick
// actions, which helpers don't get.
import 'dart:async';

import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/record_form_screen.dart';
import 'package:collarbell/features/feeding/feeding.dart';
import 'package:collarbell/features/home/home_screen.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/onboarding/welcome_screen.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pet_detail_screen.dart';
import 'package:collarbell/features/pets/pet_form_screen.dart';
import 'package:collarbell/features/supplies/supplies_screen.dart';
import 'package:collarbell/features/today/today.dart';
import 'package:collarbell/features/today/today_screen.dart';
import 'package:collarbell/features/visits/visit.dart';
import 'package:collarbell/features/visits/visit_detail_screen.dart';
import 'package:collarbell/l10n/app_localizations.dart';
import 'package:collarbell/shared/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);
const rex = Pet(id: 'p2', name: 'Rex', species: PetSpecies.dog);
const archived = Pet(
  id: 'p3',
  name: 'Old Tom',
  species: PetSpecies.cat,
  status: PetStatus.archived,
);

/// Home's list (the pets' row scrolls too, sideways).
final homeList = find
    .descendant(of: find.byType(HomeScreen), matching: find.byType(Scrollable))
    .first;

const t0800 = TimeOfDay(hour: 8, minute: 0);
const t1900 = TimeOfDay(hour: 19, minute: 0);

TodayFeeding feeding(Pet pet, TimeOfDay time, {FeedingMark? mark}) =>
    TodayFeeding(
      routineId: 'feed-${pet.id}',
      petId: pet.id,
      petName: pet.name,
      time: time,
      mark: mark,
    );

FeedingMark marked(Pet pet, TimeOfDay time) => FeedingMark(
  id: 'mark-${pet.id}-${time.hour}',
  routineId: 'feed-${pet.id}',
  date: testToday(),
  time: time,
  skipped: false,
  doneAt: DateTime(2026, 10, 2, time.hour, 2),
  byMe: true,
  byName: 'Anna',
);

TodayCareItem care(String planId, CareStatus status, int daysLeft) =>
    TodayCareItem(
      planId: planId,
      petId: murka.id,
      petName: murka.name,
      kind: CareKind.deworming,
      title: planId,
      nextDueOn: testToday().add(Duration(days: daysLeft)),
      status: status,
      daysLeft: daysLeft,
    );

TodayVisit visit(String id, {required int daysAway}) => TodayVisit(
  id: id,
  type: VisitType.vet,
  title: 'Visit $id',
  date: testToday().add(Duration(days: daysAway)),
  time: const TimeOfDay(hour: 10, minute: 30),
  daysAway: daysAway,
  pets: const [TodayVisitPet(id: 'p1', name: 'Murka')],
);

/// Today that answers only when [gate] completes: Home is still loading.
class _SlowToday extends FakeTodayRepository {
  final gate = Completer<void>();

  @override
  Future<TodayOverview> getToday() async {
    await gate.future;
    return super.getToday();
  }
}

/// Today whose answers wait for [gate] while it is set: a slow reload.
class _GatedToday extends FakeTodayRepository {
  _GatedToday({super.feedingMarks, super.feedings});

  Completer<void>? gate;

  @override
  Future<TodayOverview> getToday() async {
    final gate = this.gate;
    if (gate != null) await gate.future;
    return super.getToday();
  }
}

void main() {
  test('the greeting follows the time of day', () {
    final l10n = lookupAppLocalizations(const Locale('ru'));
    String at(int hour) => homeGreeting(l10n, DateTime(2026, 10, 14, hour));
    expect(at(5), 'Доброе утро');
    expect(at(11), 'Доброе утро');
    expect(at(12), 'Добрый день');
    expect(at(16), 'Добрый день');
    expect(at(17), 'Добрый вечер');
    expect(at(22), 'Добрый вечер');
    expect(at(23), 'Доброй ночи');
    expect(at(0), 'Доброй ночи');
    expect(at(4), 'Доброй ночи');
    final en = lookupAppLocalizations(const Locale('en'));
    expect(homeGreeting(en, DateTime(2026, 10, 14, 23)), 'Good evening');
  });

  test('the next feeding is the earliest time with a pet not fed yet', () {
    expect(nextFeeding(const []), isNull);
    final next = nextFeeding([
      feeding(murka, t0800, mark: marked(murka, t0800)),
      feeding(rex, t0800, mark: marked(rex, t0800)),
      feeding(murka, t1900),
      feeding(rex, t1900, mark: marked(rex, t1900)),
    ]);
    // The whole time, the pet already fed included.
    expect([for (final item in next!) item.petName], ['Murka', 'Rex']);
    expect(next.first.time, t1900);
    expect(
      nextFeeding([feeding(murka, t0800, mark: marked(murka, t0800))]),
      isNull,
    );
  });

  test('the visit first shown: one waiting for "How did it go?"', () {
    expect(nextVisit(const []), isNull);
    expect(
      nextVisit([visit('next', daysAway: 1), visit('past', daysAway: -2)])!.id,
      'past',
    );
    expect(nextVisit([visit('next', daysAway: 1)])!.id, 'next');
  });

  late FakePetsRepository pets;
  late FakeFeedingRepository feedings;
  late FakeSuppliesRepository supplies;
  late FakeTodayRepository today;

  setUp(() {
    pets = FakePetsRepository([murka, rex, archived]);
    feedings = FakeFeedingRepository();
    supplies = FakeSuppliesRepository();
    today = FakeTodayRepository(
      feedingMarks: feedings,
      supplies: supplies,
      feedings: [
        feeding(murka, t0800),
        feeding(rex, t0800),
        feeding(murka, t1900),
      ],
      items: [
        care('Rabies', CareStatus.overdue, -3),
        care('Deworming', CareStatus.dueSoon, 4),
        care('Fleas', CareStatus.dueSoon, 9),
        care('Check-up', CareStatus.upcoming, 25),
      ],
      visits: [visit('exam', daysAway: 1)],
    );
  });

  Future<void> openHome(
    WidgetTester tester, {
    HouseholdRole role = HouseholdRole.owner,
    String language = 'en',
    Size size = const Size(390, 844),
  }) => pumpApp(
    tester,
    location: AppRoutes.home,
    language: language,
    size: size,
    me: FakeMeRepository(
      households: [testHousehold(FakeMeRepository.homeId, role: role)],
    ),
    overrides: fakeRepositories(
      pets: pets,
      today: today,
      feeding: feedings,
      supplies: supplies,
      ai: FakeAiRepository(status: testAiStatus),
    ),
  );

  testWidgets('the app opens on Home: the pets, what is important now, the '
      'quick actions', (tester) async {
    supplies.supplies.add(testSupply('low', 'Low food', remaining: 200));
    await openHome(tester);

    expect(appRouter(tester).state.matchedLocation, AppRoutes.home);
    expect(find.byType(HomeScreen), findsOneWidget);
    // Active pets only.
    expect(find.byKey(const ValueKey('homePet-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('homePet-p2')), findsOneWidget);
    expect(find.text('Old Tom'), findsNothing);
    expect(find.byKey(const ValueKey('homeAddPet')), findsOneWidget);

    expect(find.text('Right now'), findsOneWidget);
    expect(find.text('Feeding at 8:00 AM'), findsOneWidget);
    expect(find.text('Overdue: 1'), findsOneWidget);
    expect(find.text('Due soon: 2'), findsOneWidget);
    expect(find.text('Visit exam'), findsOneWidget);
    expect(find.text('To buy: 1'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Quick actions'),
      300,
      scrollable: homeList,
    );
    for (final key in [
      'quickCare',
      'quickVisit',
      'quickScan',
      'quickNote',
      'quickWeigh',
      'quickPurchase',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('"Fed" on Home marks as on Today; once the time is done, the '
      'next one shows', (tester) async {
    await openHome(tester);

    await tester.tap(find.byKey(const ValueKey('fed-feed-p1@480')));
    await tester.pumpAndSettle();
    expect(feedings.marks.single.$1, 'feed-p1');
    // Rex is still to feed at 08:00.
    expect(find.text('Feeding at 8:00 AM'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fed-feed-p2@480')));
    await tester.pumpAndSettle();
    expect(find.text('Feeding at 8:00 AM'), findsNothing);
    expect(find.text('Feeding at 7:00 PM'), findsOneWidget);
  });

  testWidgets('a mark made on Home stays in view while Today reloads', (
    tester,
  ) async {
    // Review probe: the section forgot its marks whenever Home rebuilt.
    final slow = _GatedToday(
      feedingMarks: feedings,
      feedings: [feeding(murka, t0800), feeding(rex, t0800)],
    );
    await pumpApp(
      tester,
      location: AppRoutes.home,
      overrides: fakeRepositories(pets: pets, today: slow, feeding: feedings),
    );

    slow.gate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('fed-feed-p1@480')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Today is reading again: the mark made here shows, not "Fed".
    expect(find.byKey(const ValueKey('marked-feed-p1@480')), findsOneWidget);
    expect(find.byKey(const ValueKey('fed-feed-p1@480')), findsNothing);

    slow.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('marked-feed-p1@480')), findsOneWidget);
    expect(find.byKey(const ValueKey('fed-feed-p2@480')), findsOneWidget);
  });

  testWidgets('"All fed" marks every pet of the time', (tester) async {
    await openHome(tester);

    await tester.tap(find.byKey(const ValueKey('feedAll-480')));
    await tester.pumpAndSettle();

    expect(
      [for (final mark in feedings.marks) mark.$1],
      ['feed-p1', 'feed-p2'],
    );
    expect(find.text('Feeding at 7:00 PM'), findsOneWidget);
  });

  testWidgets('nothing left to do: all done for today', (tester) async {
    today = FakeTodayRepository(
      feedings: [feeding(murka, t0800, mark: marked(murka, t0800))],
      items: [care('Check-up', CareStatus.upcoming, 25)],
    );
    await openHome(tester);

    expect(find.byKey(const ValueKey('allDone')), findsOneWidget);
    expect(find.text('All done for today'), findsOneWidget);
    expect(find.textContaining('Feeding at'), findsNothing);
  });

  testWidgets('pets with nothing set up: the first steps, not "all done"', (
    tester,
  ) async {
    today = FakeTodayRepository();
    await openHome(tester);

    expect(find.byKey(const ValueKey('firstFeeding')), findsOneWidget);
    expect(find.byKey(const ValueKey('firstCare')), findsOneWidget);
    // The quick actions have the visit.
    expect(find.byKey(const ValueKey('firstVisit')), findsNothing);
    expect(find.text('All done for today'), findsNothing);
  });

  testWidgets('overdue and due soon open the Today tab', (tester) async {
    await openHome(tester);

    await tester.tap(find.byKey(const ValueKey('nowCare')));
    await tester.pumpAndSettle();

    expect(appRouter(tester).state.matchedLocation, AppRoutes.today);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('Rabies'), findsOneWidget);
  });

  testWidgets('a visit waiting for "How did it go?" comes first, and opens '
      'the visit', (tester) async {
    today.visits = [visit('next', daysAway: 2), visit('past', daysAway: -1)];
    await openHome(tester);

    expect(find.text('Visit past'), findsOneWidget);
    expect(find.text('Visit next'), findsNothing);
    await tester.tap(find.text('Visit past'));
    await tester.pumpAndSettle();
    expect(find.byType(VisitDetailScreen), findsOneWidget);
  });

  testWidgets('"To buy" opens the Supplies tab', (tester) async {
    supplies.supplies.add(testSupply('low', 'Low food', remaining: 200));
    await openHome(tester);

    await tapVisible(tester, find.byKey(const ValueKey('nowBuy')));

    expect(appRouter(tester).state.matchedLocation, AppRoutes.supplies);
    expect(find.byType(SuppliesScreen), findsOneWidget);
  });

  testWidgets('a pet opens on top of Home; Back returns to Home', (
    tester,
  ) async {
    await openHome(tester);

    await tester.tap(find.byKey(const ValueKey('homePet-p2')));
    await tester.pumpAndSettle();
    expect(find.byType(PetDetailScreen), findsOneWidget);
    // Still in the Home tab, with the tab bar.
    expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen).hitTestable(), findsOneWidget);
  });

  testWidgets('"Add" at the end of the pets opens the new-pet form', (
    tester,
  ) async {
    await openHome(tester);

    await tester.tap(find.byKey(const ValueKey('homeAddPet')));
    await tester.pumpAndSettle();
    expect(find.byType(PetFormScreen), findsOneWidget);
  });

  testWidgets('a quick action for a pet asks which, with several', (
    tester,
  ) async {
    await openHome(tester);

    await tapVisible(tester, find.byKey(const ValueKey('quickCare')));
    expect(find.text('Which pet?'), findsOneWidget);
    // Active pets only.
    expect(find.byKey(const ValueKey('pickPet-p3')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pickPet-p2')));
    await tester.pumpAndSettle();

    expect(find.byType(RecordFormScreen), findsOneWidget);
    expect(appRouter(tester).state.uri.path, AppRoutes.newCareRecord('p2'));
  });

  testWidgets('with one pet, a quick action goes straight to it', (
    tester,
  ) async {
    pets.pets = [murka];
    await openHome(tester);

    await tapVisible(tester, find.byKey(const ValueKey('quickWeigh')));

    expect(find.text('Which pet?'), findsNothing);
    // The weighing sheet over Home.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the scan and the note need AI on the server', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.home,
      overrides: fakeRepositories(pets: pets, today: today),
    );

    await tester.scrollUntilVisible(
      find.text('Quick actions'),
      300,
      scrollable: homeList,
    );
    expect(find.byKey(const ValueKey('quickScan')), findsNothing);
    expect(find.byKey(const ValueKey('quickNote')), findsNothing);
    expect(find.byKey(const ValueKey('quickCare')), findsOneWidget);
  });

  testWidgets('a helper marks feedings, but gets no quick actions and no '
      '"Add"', (tester) async {
    await openHome(tester, role: HouseholdRole.helper);

    expect(find.text('Feeding at 8:00 AM'), findsOneWidget);
    expect(find.byKey(const ValueKey('fed-feed-p1@480')), findsOneWidget);
    expect(find.byKey(const ValueKey('homeAddPet')), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Quick actions'), findsNothing);
  });

  testWidgets('no pets: adding one comes first, and the tour', (tester) async {
    pets.pets = [archived];
    today = FakeTodayRepository();
    await openHome(tester);

    expect(find.text('Add a pet'), findsOneWidget);
    expect(find.text('Right now'), findsNothing);
    expect(find.text('Quick actions'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('homeTour')));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('no pets, as a helper: what will show here', (tester) async {
    pets.pets = [];
    today = FakeTodayRepository();
    await openHome(tester, role: HouseholdRole.helper);

    expect(find.text('Add a pet'), findsNothing);
    expect(
      find.text(
        'When the group has pets, their feeding, care and shopping show '
        'up here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('loading: the skeleton until Today answers', (tester) async {
    // The skeleton's shimmer stands still: the frames can settle.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final slow = _SlowToday();
    await pumpApp(
      tester,
      location: AppRoutes.pets,
      overrides: fakeRepositories(pets: pets, today: slow),
    );
    appRouter(tester).go(AppRoutes.home);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CbLoadingState), findsOneWidget);
    slow.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CbLoadingState), findsNothing);
  });

  testWidgets('a failed load says so, with "Try again"', (tester) async {
    today.error = const ApiException(ApiErrorKind.network);
    await openHome(tester);

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    today.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Feeding at 8:00 AM'), findsOneWidget);
  });

  testWidgets('back in the app, Home reads Today again', (tester) async {
    await openHome(tester);
    final calls = today.calls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(today.calls, greaterThan(calls));
  });

  // The test font draws every letter a square, so Russian words are far
  // wider here than on a phone: Russian is checked at the usual size, and
  // with real fonts at 1.3 in the rendered screens.
  for (final (language, scale) in [('ru', 1.0), ('en', 1.3)]) {
    testWidgets('fits 320 dp ($language, text $scale), the five tabs too', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      supplies.supplies.add(testSupply('low', 'Low food', remaining: 200));
      await openHome(tester, language: language, size: const Size(320, 3000));

      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.byKey(const ValueKey('quickPurchase')), findsOneWidget);
      // An overflow would have failed the test by now.
    });
  }
}
