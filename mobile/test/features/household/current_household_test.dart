// The household on screen and what the role there allows: one place for
// the rules; what the server's answers change; saved per account.
import 'package:collarbell/app/app_config.dart';
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/features/auth/auth_providers.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Household household(String id, {HouseholdRole role = HouseholdRole.owner}) =>
    Household(id: id, name: id, timeZone: 'Europe/Berlin', role: role);

void main() {
  test('what each role may do', () {
    const owner = HouseholdPermissions(HouseholdRole.owner);
    const member = HouseholdPermissions(HouseholdRole.member);
    const helper = HouseholdPermissions(HouseholdRole.helper);
    // Not known yet: everything shows, the server refuses what it must.
    const unknown = HouseholdPermissions(null);

    expect([owner, member, helper, unknown].map((p) => p.canEdit), [
      true,
      true,
      false,
      true,
    ]);
    expect([owner, member, helper, unknown].map((p) => p.canManagePeople), [
      true,
      false,
      false,
      false,
    ]);
    expect(helper.canTakeBack(byMe: true), isTrue);
    expect(helper.canTakeBack(byMe: false), isFalse);
    expect(member.canTakeBack(byMe: false), isTrue);
  });

  group('the household on screen', () {
    late ProviderContainer container;

    /// Signs in as [email]; the app hears of it a moment later.
    Future<void> signIn(String email) async {
      final auth = container.read(authRepositoryProvider) as DevAuthRepository;
      await auth.signInAsDeveloper(email);
      await pumpEventQueue();
    }

    setUp(() async {
      // Signed in already, as after a start with a saved session.
      SharedPreferences.setMockInitialValues({
        DevAuthRepository.uidKey: DevAuthRepository.uidForEmail(
          'anna@example.com',
        ),
        DevAuthRepository.emailKey: 'anna@example.com',
      });
      final preferences = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://api.test',
              authMode: AuthMode.dev,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      container.listen(currentHouseholdProvider, (_, _) {});
    });

    CurrentHouseholdNotifier notifier() =>
        container.read(currentHouseholdProvider.notifier);
    CurrentHousehold? current() => container.read(currentHouseholdProvider);

    test("the server's choice is remembered, and the role kept up to date", () {
      notifier().remember(household('home'), asked: null);
      expect(current()?.id, 'home');

      notifier().remember(
        household('home', role: HouseholdRole.helper),
        asked: 'home',
      );
      expect(current()?.role, HouseholdRole.helper);
      expect(container.read(householdNoticeProvider), isNull);
    });

    test('an answer for a household left behind meanwhile changes nothing', () {
      notifier().switchTo(const CurrentHousehold(id: 'office'));

      notifier().remember(household('home'), asked: 'home');
      notifier().refresh(household('home'));

      expect(current()?.id, 'office');
    });

    test('/me answering for another household than asked: the asked one is '
        "the user's no more, and the app says so", () {
      notifier().switchTo(const CurrentHousehold(id: 'office', name: 'Office'));

      notifier().remember(household('home'), asked: 'office');

      expect(current()?.id, 'home');
      final notice = container.read(householdNoticeProvider);
      expect((notice as HouseholdLeft?)?.id, 'office');
      expect(notice?.name, 'Office');
    });

    test('leaving a household forgets it only while it is on screen', () {
      notifier().switchTo(const CurrentHousehold(id: 'office'));

      // Left on a screen still open while a push moved the app to "home".
      notifier().switchTo(const CurrentHousehold(id: 'home'));
      notifier().forget('office');
      expect(current()?.id, 'home');

      notifier().forget('home');
      expect(current(), isNull);
    });

    test('a refusal for another household than the one on screen is old '
        'news', () {
      notifier().switchTo(const CurrentHousehold(id: 'home'));

      notifier().lost('office');

      expect(current()?.id, 'home');
      expect(container.read(householdNoticeProvider), isNull);
    });

    test(
      'saved per account: another one starts with the server\'s choice',
      () async {
        notifier().switchTo(const CurrentHousehold(id: 'office'));

        await signIn('boris@example.com');
        expect(current(), isNull);

        await signIn('anna@example.com');
        expect(current()?.id, 'office');
      },
    );
  });
}
