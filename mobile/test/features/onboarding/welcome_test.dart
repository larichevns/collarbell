// The onboarding: when it opens by itself (once per account, for a new
// group with nothing set up), opened again from More, its pages and setup
// steps through the fakes, skipping, Back, and who gets which steps.
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/feeding/feeding.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/home/home_screen.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/household/join_screen.dart';
import 'package:collarbell/features/notifications/push_registration.dart';
import 'package:collarbell/features/onboarding/onboarding.dart';
import 'package:collarbell/features/onboarding/welcome_screen.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pet_form_screen.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

/// The main button under the onboarding (its words change with the step).
final mainButton = find.descendant(
  of: find.byType(WelcomeScreen),
  matching: find.byType(FilledButton),
);

Future<void> tapMain(WidgetTester tester) async {
  await tester.tap(mainButton);
  await tester.pumpAndSettle();
}

/// Through the three pages to the first step.
Future<void> passPages(WidgetTester tester) async {
  for (var page = 0; page < 3; page++) {
    await tapMain(tester);
  }
}

String mainLabel(WidgetTester tester) =>
    (tester.widget<FilledButton>(mainButton).child! as Text).data!;

/// A server that adds the pet, but whose answer gets lost on the way.
class _LostAnswerPets extends FakePetsRepository {
  @override
  Future<Pet> createPet(PetInput input) async {
    await super.createPet(input);
    throw networkError;
  }
}

/// A feeding save that fails the first time (no connection), with every
/// request id it was sent.
class _FlakyFeeding extends FakeFeedingRepository {
  final requestIds = <String>[];

  @override
  Future<FeedingSchedule> createSchedule(
    String petId,
    FeedingInput input, {
    required String requestId,
  }) {
    requestIds.add(requestId);
    if (requestIds.length == 1) throw networkError;
    return super.createSchedule(petId, input, requestId: requestId);
  }
}

void main() {
  // Taps here come faster than a person's: the main button doesn't wait
  // after a step change (one test checks that it does).
  setUpAll(() => WelcomeScreen.settleAfterMove = Duration.zero);
  tearDownAll(
    () => WelcomeScreen.settleAfterMove = const Duration(milliseconds: 300),
  );

  group('its turn', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    bool turn(
      String uid, {
      int households = 1,
      bool canEdit = true,
      bool hasPets = false,
    }) => OnboardingTurn.takeTurn(
      prefs,
      uid,
      households: households,
      canEdit: canEdit,
      hasPets: hasPets,
    );

    test('opens once for a person starting from nothing: one group, no '
        'pets, able to add them', () {
      expect(turn('anna'), isTrue);
      expect(prefs.getBool(OnboardingTurn.keyFor('anna')), isTrue);
      expect(turn('anna'), isFalse);
      // Per account: someone else on this phone has a turn of their own.
      expect(turn('boris'), isTrue);
    });

    test('anyone else: not shown, and the turn is taken all the same', () {
      for (final (uid, households, canEdit, hasPets) in [
        // Pets of any status: a deceased or archived pet counts.
        ('with pets', 1, true, true),
        // A family member who joined keeps their own empty group.
        ('in two groups', 2, true, false),
        ('a helper', 1, false, false),
      ]) {
        expect(
          turn(uid, households: households, canEdit: canEdit, hasPets: hasPets),
          isFalse,
          reason: uid,
        );
        expect(prefs.getBool(OnboardingTurn.keyFor(uid)), isTrue, reason: uid);
      }
    });
  });

  group('opening by itself', () {
    testWidgets('a new account with no pets: once, on top of Home', (
      tester,
    ) async {
      final pets = FakePetsRepository();
      await pumpApp(
        tester,
        location: AppRoutes.home,
        onboardingSeen: false,
        overrides: fakeRepositories(pets: pets),
      );

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Reminders on time'), findsOneWidget);
      expect(
        appContainer(tester)
            .read(sharedPreferencesProvider)
            .getBool(OnboardingTurn.keyFor(testUid)),
        isTrue,
      );

      // Closed: Home under it. Reloads don't open it again.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      appContainer(tester).invalidate(petsProvider);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('an account whose group has pets: never, and its turn is '
        'taken', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.home,
        onboardingSeen: false,
        overrides: fakeRepositories(pets: FakePetsRepository([murka])),
      );

      expect(find.byType(WelcomeScreen), findsNothing);
      expect(
        appContainer(tester)
            .read(sharedPreferencesProvider)
            .getBool(OnboardingTurn.keyFor(testUid)),
        isTrue,
      );
    });

    testWidgets('only a deceased or archived pet: never, and Home still '
        'offers to add one', (tester) async {
      // Review probe: the turn was decided on active pets only.
      await pumpApp(
        tester,
        location: AppRoutes.home,
        onboardingSeen: false,
        overrides: fakeRepositories(
          pets: FakePetsRepository([
            const Pet(
              id: 'p9',
              name: 'Old Tom',
              species: PetSpecies.cat,
              status: PetStatus.deceased,
            ),
            const Pet(
              id: 'p8',
              name: 'Rex',
              species: PetSpecies.dog,
              status: PetStatus.archived,
            ),
          ]),
        ),
      );

      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.text('Add a pet'), findsOneWidget);
      expect(
        appContainer(tester)
            .read(sharedPreferencesProvider)
            .getBool(OnboardingTurn.keyFor(testUid)),
        isTrue,
      );
    });

    testWidgets('in two groups, the one on screen empty (a family member '
        'who joined, on a new phone): never, and its turn is taken', (
      tester,
    ) async {
      // Review probe: "Who lives with you?" in the person's own empty group
      // would add the family's cat a second time.
      await pumpApp(
        tester,
        location: AppRoutes.home,
        onboardingSeen: false,
        me: FakeMeRepository(
          households: [
            testHousehold(FakeMeRepository.homeId),
            testHousehold('family', name: 'Family', role: HouseholdRole.member),
          ],
        ),
        overrides: fakeRepositories(),
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(
        appContainer(tester)
            .read(sharedPreferencesProvider)
            .getBool(OnboardingTurn.keyFor(testUid)),
        isTrue,
      );
    });

    testWidgets('not before the groups and the pets are known', (tester) async {
      final pets = FakePetsRepository()..error = networkError;
      await pumpApp(
        tester,
        location: AppRoutes.home,
        onboardingSeen: false,
        overrides: fakeRepositories(pets: pets),
      );
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(
        appContainer(tester)
            .read(sharedPreferencesProvider)
            .getBool(OnboardingTurn.keyFor(testUid)),
        isNull,
      );

      // Loaded: one group, no pets.
      pets.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('opened from More first: it doesn\'t open again by itself', (
      tester,
    ) async {
      // Home can't decide yet (the pets don't load); More opens it.
      final pets = FakePetsRepository()..error = networkError;
      await pumpApp(
        tester,
        location: AppRoutes.more,
        onboardingSeen: false,
        overrides: fakeRepositories(pets: pets),
      );
      await tester.scrollUntilVisible(
        find.text('Getting to know the app'),
        300,
      );
      await tapVisible(tester, find.text('Getting to know the app'));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        appContainer(tester)
            .read(sharedPreferencesProvider)
            .getBool(OnboardingTurn.keyFor(testUid)),
        isTrue,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // The pets load on Home now: no second showing.
      pets.error = null;
      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('seen before on this phone: not again', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.home,
        overrides: fakeRepositories(),
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });
  });

  testWidgets('More opens it again, from its first page; closing returns to '
      'More', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.more,
      overrides: fakeRepositories(pets: FakePetsRepository([murka])),
    );

    // The list builds its rows as they scroll into view.
    await tester.scrollUntilVisible(find.text('Getting to know the app'), 300);
    await tapVisible(tester, find.text('Getting to know the app'));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Reminders on time'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Getting to know the app'), findsOneWidget);
    expect(appRouter(tester).state.matchedLocation, AppRoutes.more);
  });

  Future<void> openWelcome(
    WidgetTester tester, {
    FakePetsRepository? pets,
    FakeFeedingRepository? feeding,
    FakePushPlatform? push,
    FakeHouseholdRepository? household,
    HouseholdRole role = HouseholdRole.owner,
  }) async {
    await pumpApp(
      tester,
      location: AppRoutes.home,
      me: FakeMeRepository(
        households: [testHousehold(FakeMeRepository.homeId, role: role)],
      ),
      overrides: fakeRepositories(
        pets: pets,
        feeding: feeding,
        push: push,
        household: household,
      ),
    );
    appRouter(tester).push(AppRoutes.welcome);
    await tester.pumpAndSettle();
  }

  testWidgets('the steps add the pet and its feeding, turn notifications on '
      'and invite the family', (tester) async {
    final pets = FakePetsRepository();
    final feeding = FakeFeedingRepository();
    final push = FakePushPlatform(allowed: false);
    final household = FakeHouseholdRepository();
    await openWelcome(
      tester,
      pets: pets,
      feeding: feeding,
      push: push,
      household: household,
    );

    expect(mainLabel(tester), 'Next');
    await tapMain(tester);
    expect(find.text('The passport in a minute'), findsOneWidget);
    await tapMain(tester);
    expect(find.text('Together with the family'), findsOneWidget);
    expect(mainLabel(tester), 'Start');
    await tapMain(tester);

    // 1. The pet: a name and cat or dog.
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Who lives with you?'), findsOneWidget);
    await tapMain(tester);
    expect(find.text('Enter the pet\'s name'), findsOneWidget);
    expect(pets.created, isEmpty);
    await tester.enterText(find.byType(TextFormField), 'Rex');
    await tester.tap(find.text('Dog'));
    await tester.pumpAndSettle();
    expect(mainLabel(tester), 'Save and continue');
    await tapMain(tester);
    expect(
      pets.created.single,
      const PetInput(name: 'Rex', species: PetSpecies.dog),
    );

    // 2. Its feeding: 08:00 and 19:00 to start with, every day.
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('7:00 PM'), findsOneWidget);
    // 19:00 goes.
    await tester.tap(find.byTooltip('Remove this time').last);
    await tester.pumpAndSettle();
    expect(find.text('7:00 PM'), findsNothing);
    await tapMain(tester);
    expect(feeding.lastInput!.times, const [TimeOfDay(hour: 8, minute: 0)]);
    expect(feeding.lastInput!.days, everyDay);
    expect(feeding.schedules.single.petId, 'new-1');

    // 3. Notifications: the phone asks at once, the screen said why.
    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(mainLabel(tester), 'Turn on notifications');
    await tapMain(tester);
    expect(push.permissionRequests, 1);
    expect(find.byType(AlertDialog), findsNothing);
    // Refused on the phone: the way to the settings, and on.
    expect(find.byKey(const ValueKey('welcomePushSettings')), findsOneWidget);
    expect(mainLabel(tester), 'Next');
    await tapMain(tester);

    // 4. The family: an invite, its code, then done.
    expect(find.text('Step 4 of 4'), findsOneWidget);
    expect(mainLabel(tester), 'Invite');
    await tapMain(tester);
    await tester.tap(find.byKey(const ValueKey('invite-member')));
    await tester.pumpAndSettle();
    expect(household.newInvites, [HouseholdRole.member]);
    expect(find.byKey(const ValueKey('inviteCode')), findsOneWidget);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    expect(
      find.text('Invite created. The code works for 7 days.'),
      findsOneWidget,
    );
    expect(mainLabel(tester), 'Done');
    await tapMain(tester);

    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('what is set up already shows as done', (tester) async {
    final feeding = FakeFeedingRepository(
      schedules: [
        const FeedingSchedule(
          id: 'f1',
          petId: 'p1',
          times: [TimeOfDay(hour: 8, minute: 0)],
          days: everyDay,
        ),
      ],
    );
    await openWelcome(
      tester,
      pets: FakePetsRepository([
        murka,
        const Pet(id: 'p2', name: 'Barsik', species: PetSpecies.cat),
      ]),
      feeding: feeding,
      push: FakePushPlatform(),
    );
    await passPages(tester);

    expect(find.text('Already here: Murka, Barsik'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(mainLabel(tester), 'Next');
    await tapMain(tester);
    expect(find.text('Feeding is already set up'), findsOneWidget);
    await tapMain(tester);
    expect(find.text('Notifications are on'), findsOneWidget);
  });

  testWidgets('"Add another" opens the full pet form over the onboarding', (
    tester,
  ) async {
    final pets = FakePetsRepository([murka]);
    await openWelcome(tester, pets: pets);
    await passPages(tester);

    await tester.tap(find.byKey(const ValueKey('welcomeAddMore')));
    await tester.pumpAndSettle();
    expect(find.byType(PetFormScreen), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(CbTextField, 'Name'),
        matching: find.byType(TextFormField),
      ),
      'Barsik',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Already here: Murka, Barsik'), findsOneWidget);
  });

  testWidgets('"I was invited" opens joining with a code', (tester) async {
    await openWelcome(tester);
    await passPages(tester);

    await tapVisible(tester, find.byKey(const ValueKey('welcomeInvited')));
    expect(find.byType(JoinHouseholdScreen), findsOneWidget);
    // Back: the onboarding as it was.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4'), findsOneWidget);
  });

  testWidgets('a failed save keeps the step, with why', (tester) async {
    final pets = FakePetsRepository()
      ..saveError = const ApiException(ApiErrorKind.network);
    await openWelcome(tester, pets: pets);
    await passPages(tester);

    await tester.enterText(find.byType(TextFormField), 'Rex');
    await tapMain(tester);

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Rex'), findsOneWidget);
  });

  testWidgets('every step can be skipped; Back goes to the step or page '
      'before', (tester) async {
    final pets = FakePetsRepository();
    await openWelcome(tester, pets: pets);

    // "Skip" on the pages: straight to the first step.
    await tester.tap(find.byKey(const ValueKey('welcomeSkip')));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Rex');

    await tester.tap(find.byKey(const ValueKey('welcomeSkip')));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 4'), findsOneWidget);
    // No pet yet: feeding waits for one.
    expect(find.textContaining('Feeding is set up for a pet'), findsOneWidget);
    expect(pets.created, isEmpty);

    // The phone's Back: the step before, the name still typed.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Rex'), findsOneWidget);
    // Back again: the last page, then the ones before it.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Together with the family'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Reminders on time'), findsOneWidget);

    // From the first page, Back closes it: the typed name would be lost,
    // so it asks first.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the last step\'s "Skip" ends it', (tester) async {
    await openWelcome(tester);
    await passPages(tester);
    for (var step = 0; step < 4; step++) {
      await tester.tap(find.byKey(const ValueKey('welcomeSkip')));
      await tester.pumpAndSettle();
    }
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('a helper gets the pages only', (tester) async {
    await openWelcome(tester, role: HouseholdRole.helper);

    await tapMain(tester);
    await tapMain(tester);
    expect(mainLabel(tester), 'Start');
    await tapMain(tester);

    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the family step is for owners: a member has three steps', (
    tester,
  ) async {
    await openWelcome(
      tester,
      pets: FakePetsRepository([murka]),
      role: HouseholdRole.member,
    );
    await passPages(tester);

    expect(find.text('Step 1 of 3'), findsOneWidget);
    await tapMain(tester);
    await tapMain(tester);
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(mainLabel(tester), 'Done');
    await tapMain(tester);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('notifications refused: the way to the settings', (tester) async {
    final push = FakePushPlatform(allowed: false);
    await openWelcome(tester, pets: FakePetsRepository([murka]), push: push);
    // Asked before, on this phone, and refused.
    await appContainer(
      tester,
    ).read(sharedPreferencesProvider).setBool('push.permissionAsked', true);
    appContainer(tester).invalidate(pushRegistrationProvider);
    await passPages(tester);
    await tapMain(tester);
    await tapMain(tester);

    expect(
      find.text(
        "Notifications are off for Collarbell in the phone's settings.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('welcomePushSettings')));
    expect(push.settingsOpened, 1);
  });

  testWidgets('fits a small phone in Russian with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(
      tester,
      location: AppRoutes.home,
      language: 'ru',
      size: const Size(320, 640),
      overrides: fakeRepositories(pets: FakePetsRepository([murka])),
    );
    appRouter(tester).push(AppRoutes.welcome);
    await tester.pumpAndSettle();

    // The pages, the pet, its feeding, notifications: on to the family.
    for (var page = 0; page < 6; page++) {
      await tapMain(tester);
    }
    // An overflow would have failed the test by now.
    expect(find.text('Позовите семью'), findsOneWidget);
  });

  testWidgets('a pet saved whose answer got lost is not added twice: the '
      'step shows it as there', (tester) async {
    // Review probe: a retry after a lost answer added the pet again.
    final pets = _LostAnswerPets();
    await openWelcome(tester, pets: pets);
    await passPages(tester);

    await tester.enterText(find.byType(TextFormField), 'Rex');
    await tapMain(tester);

    expect(pets.created, hasLength(1));
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Already here: Rex'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(mainLabel(tester), 'Next');
    await tapMain(tester);
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(pets.created, hasLength(1));
  });

  testWidgets('a double tap on "Next" doesn\'t press the next step\'s '
      'button too', (tester) async {
    // Review probe: the second tap asked for notifications unasked.
    WelcomeScreen.settleAfterMove = const Duration(milliseconds: 300);
    addTearDown(() => WelcomeScreen.settleAfterMove = Duration.zero);
    final push = FakePushPlatform(allowed: false);
    await openWelcome(
      tester,
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
      push: push,
    );
    // Through the pages with "Skip", which isn't held.
    await tester.tap(find.byKey(const ValueKey('welcomeSkip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcomeSkip')));
    await tester.pumpAndSettle();
    expect(find.text('Feeding is already set up'), findsOneWidget);
    // A person reads the step first (real time: the button waits by the
    // clock).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );

    // Two quick taps: "Next", then the same place on the next step.
    await tester.tap(mainButton);
    await tester.pump();
    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(mainLabel(tester), 'Turn on notifications');
    await tester.tap(mainButton);
    await tester.pumpAndSettle();

    expect(push.permissionRequests, 0);
    expect(find.text('Step 3 of 4'), findsOneWidget);
  });

  testWidgets('notifications are asked for once, however often it is '
      'tapped', (tester) async {
    final push = FakePushPlatform(allowed: false);
    await openWelcome(tester, pets: FakePetsRepository([murka]), push: push);
    await passPages(tester);
    await tester.tap(find.byKey(const ValueKey('welcomeSkip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcomeSkip')));
    await tester.pumpAndSettle();
    expect(mainLabel(tester), 'Turn on notifications');

    await tester.tap(mainButton);
    await tester.tap(mainButton);
    await tester.pumpAndSettle();

    expect(push.permissionRequests, 1);
  });

  testWidgets('each pet\'s feeding has its own request id', (tester) async {
    // Review probe: the server answers a known id with its schedule, so a
    // save for another pet must not reuse the first one's.
    final pets = FakePetsRepository([murka]);
    final feeding = _FlakyFeeding();
    await openWelcome(tester, pets: pets, feeding: feeding);
    await passPages(tester);
    await tapMain(tester);

    // Murka's save fails; meanwhile Murka is gone and Rex is the pet.
    await tapMain(tester);
    expect(find.text('Step 2 of 4'), findsOneWidget);
    pets.pets = [const Pet(id: 'p2', name: 'Rex', species: PetSpecies.dog)];
    appContainer(tester).invalidate(petsProvider);
    await tester.pumpAndSettle();
    expect(find.text('Rex'), findsOneWidget);
    await tapMain(tester);

    expect(feeding.schedules.single.petId, 'p2');
    expect(feeding.requestIds, hasLength(2));
    expect(feeding.requestIds.first, isNot(feeding.requestIds.last));
  });

  testWidgets('at most 8 feeding times, as in the feeding form', (
    tester,
  ) async {
    await openWelcome(tester, pets: FakePetsRepository([murka]));
    await passPages(tester);
    await tapMain(tester);

    for (var hour = 9; hour < 15; hour++) {
      await tester.tap(find.byKey(const ValueKey('welcomeAddTime')));
      await tester.pumpAndSettle();
      await enterPickerTime(tester, TimeOfDay(hour: hour, minute: 0));
    }
    expect(find.byKey(const ValueKey('welcomeAddTime')), findsNothing);
  });

  testWidgets('joining a family closes the onboarding: the app is in that '
      'family, on Home', (tester) async {
    final me = FakeMeRepository();
    final households = FakeHouseholdRepository(me: me)
      ..previews['ABCD2345'] = InvitePreview(
        householdName: 'Dacha',
        invitedBy: 'Anna',
        role: HouseholdRole.member,
        expiresAt: DateTime(2026, 10, 12),
      );
    await pumpApp(
      tester,
      location: AppRoutes.home,
      me: me,
      overrides: fakeRepositories(household: households),
    );
    appRouter(tester).push(AppRoutes.welcome);
    await tester.pumpAndSettle();
    await passPages(tester);

    await tapVisible(tester, find.byKey(const ValueKey('welcomeInvited')));
    await tester.enterText(find.byType(TextFormField), 'abcd2345');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(households.accepted, ['ABCD2345']);
    expect(appContainer(tester).read(currentHouseholdProvider)?.id, 'joined');
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(HomeScreen).hitTestable(), findsOneWidget);
    expect(appRouter(tester).state.matchedLocation, AppRoutes.home);
  });
}
