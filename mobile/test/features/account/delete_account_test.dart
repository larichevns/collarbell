// More → Delete account: what happens to each group (deleted, kept, handed
// over), what goes and what stays; with Firebase the password again, then a
// last question, and after the deletion the app signs out here and says
// so. A wrong password, a sign-in too long ago and no connection delete
// nothing. Groups that changed are shown before anything is deleted, a
// deletion whose answer was lost is checked first, and the screen keeps
// the deletion's outcome while it runs.
import 'dart:async';

import 'package:collarbell/app/app_config.dart';
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/account/account.dart';
import 'package:collarbell/features/account/account_repository.dart';
import 'package:collarbell/features/account/delete_account_screen.dart';
import 'package:collarbell/features/account/deleted_account.dart';
import 'package:collarbell/features/auth/auth_providers.dart';
import 'package:collarbell/features/auth/auth_repository.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/account/account_labels.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/l10n/app_localizations_en.dart';
import 'package:collarbell/l10n/app_localizations_ru.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// Stands in for Firebase: [rightPassword] is right, anything else wrong,
/// unless it fails with [failure]. Once the server deleted the sign-in
/// ([signInGone]) every password is wrong to it. The next [failSignOuts]
/// sign-outs fail (a locked keychain). Remembers what was typed.
class _PasswordAuth extends DevAuthRepository {
  _PasswordAuth(super.prefs);

  static const rightPassword = 'kitten-2026';

  final typed = <String>[];
  AuthFailure? failure;
  var signInGone = false;
  var failSignOuts = 0;

  @override
  Future<void> reauthenticate(String password) async {
    typed.add(password);
    if (failure case final failure?) throw AuthException(failure);
    if (signInGone || password != rightPassword) {
      throw const AuthException(AuthFailure.invalidCredentials);
    }
  }

  @override
  Future<void> signOut() async {
    if (failSignOuts > 0) {
      failSignOuts--;
      throw PlatformException(code: 'keychain-error');
    }
    await super.signOut();
  }
}

/// The server deletes the account (its sign-in too), but the answer is lost
/// with the connection: until [online] again nothing reaches the server.
class _LostAnswerAccount extends FakeAccountRepository {
  _PasswordAuth? auth;
  var online = true;
  var gone = false;

  @override
  Future<DeletionPreview> getDeletionPreview() async {
    if (!online || gone) {
      previewCalls++;
      throw online ? accountDeletedError : networkError;
    }
    return super.getDeletionPreview();
  }

  @override
  Future<void> deleteAccount(String plan) async {
    deletions++;
    deletedPlans.add(plan);
    if (!online) throw networkError;
    if (gone) throw accountDeletedError;
    gone = true;
    auth?.signInGone = true;
    online = false;
    throw networkError;
  }
}

/// A deletion that waits for the test to answer it.
class _GatedAccount extends FakeAccountRepository {
  Completer<void>? gate;

  @override
  Future<void> deleteAccount(String plan) async {
    deletions++;
    deletedPlans.add(plan);
    await (gate = Completer<void>()).future;
  }
}

/// What the server answers a deleted account's requests.
const accountDeletedError = ApiException(
  ApiErrorKind.unauthorized,
  statusCode: 401,
  problem: ProblemDetails(type: ProblemTypes.accountDeleted, status: 401),
);

const recentSignInRequired = ApiException(
  ApiErrorKind.forbidden,
  statusCode: 403,
  problem: ProblemDetails(type: ProblemTypes.recentSignInRequired, status: 403),
);

void main() {
  late FakeAccountRepository account;
  late FakePushPlatform push;
  late FakeNotificationsRepository notifications;

  setUp(() => account = FakeAccountRepository());

  /// Opens the delete screen, signed in; with Firebase unless [authMode]
  /// says otherwise. The screen is tall enough to show all of it.
  Future<void> openDelete(
    WidgetTester tester, {
    AuthMode authMode = AuthMode.firebase,
    String language = 'en',
    Size size = const Size(390, 2600),
    FakeMeRepository? me,
  }) async {
    push = FakePushPlatform();
    notifications = FakeNotificationsRepository();
    await pumpApp(
      tester,
      location: AppRoutes.deleteAccount,
      authMode: authMode,
      language: language,
      size: size,
      me: me,
      overrides: [
        ...fakeRepositories(
          account: account,
          push: push,
          notifications: notifications,
        ),
        authRepositoryProvider.overrideWith(
          (ref) => _PasswordAuth(ref.watch(sharedPreferencesProvider)),
        ),
      ],
    );
  }

  _PasswordAuth auth(WidgetTester tester) =>
      appContainer(tester).read(authRepositoryProvider) as _PasswordAuth;

  Finder deleteButton() => find.byKey(const ValueKey('deleteAccountButton'));

  /// Types [password] (if any), taps "Delete account" and, when asked,
  /// confirms.
  Future<void> delete(WidgetTester tester, {String? password}) async {
    if (password != null) {
      await tester.enterText(find.byKey(const ValueKey('password')), password);
    }
    await tapVisible(tester, deleteButton());
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete account'),
    );
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('says what happens to each group, what goes and what stays', (
    tester,
  ) async {
    account.households = [
      // The person's first group, with a helper: nobody would look after it.
      testOutcome('h1', pets: 2, others: 1),
      testOutcome(
        'h2',
        name: 'Office',
        role: HouseholdRole.member,
        fate: HouseholdFate.kept,
        pets: 1,
        others: 3,
      ),
      testOutcome(
        'h3',
        name: 'Dacha',
        fate: HouseholdFate.handedOver,
        others: 2,
        newOwner: 'Boris',
      ),
      testOutcome(
        'h4',
        name: 'Shelter',
        fate: HouseholdFate.handedOver,
        others: 1,
      ),
    ];
    await openDelete(tester);

    expect(
      find.text("Your account will be deleted for good. This can't be undone."),
      findsOneWidget,
    );
    void says(String id, String name, String fate) {
      final row = find.byKey(ValueKey('outcome-$id'));
      expect(
        find.descendant(of: row, matching: find.text(name)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(fate)),
        findsOneWidget,
      );
    }

    // The server's "Home" is "My home" to its owner.
    says(
      'h1',
      'My home',
      'Will be deleted with its 2 pets and all their records, photos and '
          'documents. Only helpers would be left in it, and they lose access.',
    );
    says('h2', 'Office', 'Stays with the others as it is.');
    says('h3', 'Dacha', 'Stays with the others; Boris becomes its owner.');
    says(
      'h4',
      'Shelter',
      'Stays with the others; the member who joined first becomes its owner.',
    );
    expect(find.text('What gets deleted'), findsOneWidget);
    expect(find.text('Your sign-in: the e-mail and password.'), findsOneWidget);
    expect(find.text('What stays'), findsOneWidget);
    expect(
      find.text(
        'In shared groups your records and feeding marks stay without your '
        'name, and what is written in them (e.g. the owner\'s details in a pet '
        'passport) stays as it is.',
      ),
      findsOneWidget,
    );
    expect(find.text('Download my data first'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('in Russian on a small phone: plain words, nothing overflows', (
    tester,
  ) async {
    account.households = [
      testOutcome('h1', pets: 1),
      testOutcome('h2', name: 'Офис', pets: 3, others: 2),
      testOutcome(
        'h3',
        name: 'Дача',
        role: HouseholdRole.helper,
        fate: HouseholdFate.kept,
      ),
      testOutcome(
        'h4',
        name: 'Приют',
        fate: HouseholdFate.handedOver,
        newOwner: 'Борис',
      ),
    ];
    await openDelete(tester, language: 'ru', size: const Size(360, 640));

    expect(find.text('Удалить аккаунт'), findsWidgets);
    expect(
      find.text('Аккаунт удалится насовсем. Отменить это нельзя.'),
      findsOneWidget,
    );
    expect(find.text('Мой дом'), findsOneWidget);
    expect(
      find.text(
        'Удалится вместе с 1 питомцем и всеми записями, фото и документами.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Удалится вместе с 3 питомцами и всеми записями, фото и документами. '
        'Кроме вас, в ней только помощники — они потеряют к ней доступ.',
      ),
      findsOneWidget,
    );
    expect(find.text('Останется у остальных как есть.'), findsOneWidget);
    expect(
      find.text('Останется у остальных, владельцем станет Борис.'),
      findsOneWidget,
    );
    // The rest of the list, down to the button: nothing overflows.
    await tester.scrollUntilVisible(
      deleteButton(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Сначала скачать мои данные'), findsOneWidget);
    expect(
      find.text('Введите пароль, чтобы подтвердить, что это вы.'),
      findsOneWidget,
    );
  });

  testWidgets('with Firebase the password comes first: nothing without it', (
    tester,
  ) async {
    await openDelete(tester);

    await delete(tester);

    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('Delete your account?'), findsNothing);
    expect(auth(tester).typed, isEmpty);
    expect(account.deletions, 0);
  });

  testWidgets('the password, a last question, then deleted: the app signs '
      'out here, asks the server nothing more, and says so', (tester) async {
    await openDelete(tester);
    final prefs = appContainer(tester).read(sharedPreferencesProvider);
    expect(
      prefs.getString(CurrentHouseholdNotifier.keyFor(testUid)),
      isNotNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('password')),
      _PasswordAuth.rightPassword,
    );
    await tapVisible(tester, deleteButton());
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(
      find.text(
        "“My home” will be deleted with everything in it. This can't be "
        'undone.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete account'),
      ),
    );
    await tester.pumpAndSettle();

    expect(auth(tester).typed, [_PasswordAuth.rightPassword]);
    expect(account.deletions, 1);
    // With the plan of the groups as the screen showed them.
    expect(account.deletedPlans, ['plan-1']);
    // On the sign-in screen, with the reason.
    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(appContainer(tester).read(authUserProvider), isNull);
    // This phone gets no more pushes, but the server isn't asked to forget
    // it: it has forgotten the account's phones itself.
    expect(push.tokensForgotten, 1);
    expect(notifications.forgotten, isEmpty);
    // Nothing of the account stays for the next person on this phone.
    expect(prefs.getString(CurrentHouseholdNotifier.keyFor(testUid)), isNull);
  });

  testWidgets('a wrong password deletes nothing and says so', (tester) async {
    await openDelete(tester);

    await delete(tester, password: 'puppy');

    expect(find.text('Wrong password. Try again.'), findsOneWidget);
    expect(account.deletions, 0);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    // Empty, to type again, without "Enter your password" yet.
    expect(find.text('puppy'), findsNothing);
    expect(find.text('Enter your password'), findsNothing);
    expect(appContainer(tester).read(authUserProvider), isNotNull);
  });

  testWidgets('the server wants the password again: it asks for it, nothing '
      'is deleted', (tester) async {
    account.deleteError = recentSignInRequired;
    await openDelete(tester);

    await delete(tester, password: _PasswordAuth.rightPassword);

    expect(
      find.text('For your safety, type your password again.'),
      findsOneWidget,
    );
    expect(find.text(_PasswordAuth.rightPassword), findsNothing);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(appContainer(tester).read(authUserProvider), isNotNull);
    expect(appContainer(tester).read(deletedAccountProvider), isFalse);

    // Typed again, and the server takes it.
    account.deleteError = null;
    await delete(tester, password: _PasswordAuth.rightPassword);

    expect(account.deletions, 2);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });

  /// On the server, someone joined "Home" meanwhile: it isn't deleted any
  /// more but goes to Boris, and the fates have a new plan.
  void someoneJoined() {
    account
      ..households = [
        testOutcome(
          FakeMeRepository.homeId,
          fate: HouseholdFate.handedOver,
          others: 1,
          newOwner: 'Boris',
        ),
      ]
      ..plan = 'plan-2';
  }

  const handedToBoris = 'Stays with the others; Boris becomes its owner.';
  const somethingChanged =
      'Something changed in your groups. Check again what happens to them, '
      'then delete.';

  testWidgets('the groups changed on the server before the deletion: '
      'nothing is deleted, the screen shows them anew and says so; the '
      'password stays, and the next try deletes as now shown', (tester) async {
    await openDelete(tester);
    await tester.enterText(
      find.byKey(const ValueKey('password')),
      _PasswordAuth.rightPassword,
    );
    // While the password was typed, someone used an old invite.
    someoneJoined();

    await delete(tester);

    expect(account.deletedPlans, ['plan-1']);
    expect(find.text(somethingChanged), findsOneWidget);
    expect(find.text(handedToBoris), findsOneWidget);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(appContainer(tester).read(authUserProvider), isNotNull);
    expect(appContainer(tester).read(deletedAccountProvider), isFalse);
    // No need to type it again: it is still there, and checked again.
    expect(find.text(_PasswordAuth.rightPassword), findsOneWidget);

    await delete(tester);

    expect(auth(tester).typed, [
      _PasswordAuth.rightPassword,
      _PasswordAuth.rightPassword,
    ]);
    expect(account.deletedPlans, ['plan-1', 'plan-2']);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });

  testWidgets('groups that changed on their own before the tap (a live '
      'update, off screen on a small phone) are shown first: the tap sends '
      'nothing; the next one deletes them as shown', (tester) async {
    account.households = [
      testOutcome(
        FakeMeRepository.homeId,
        fate: HouseholdFate.handedOver,
        pets: 2,
        others: 1,
        newOwner: 'Boris',
      ),
    ];
    await openDelete(tester, size: const Size(360, 640));
    expect(find.text(handedToBoris), findsOneWidget);
    // Down to the password, as the person types it.
    await tester.scrollUntilVisible(
      deleteButton(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('password')),
      _PasswordAuth.rightPassword,
    );
    // Meanwhile Boris left: "Home" would now go with its 2 pets.
    account
      ..households = [testOutcome(FakeMeRepository.homeId, pets: 2)]
      ..plan = 'plan-2';
    appContainer(tester).invalidate(deletionPreviewProvider);
    await tester.pumpAndSettle();

    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    // Nothing asked, nothing sent: the groups are in view, with the word.
    expect(find.byType(AlertDialog), findsNothing);
    expect(account.deletions, 0);
    expect(auth(tester).typed, isEmpty);
    expect(find.text(somethingChanged), findsOneWidget);
    final row = find.byKey(ValueKey('outcome-${FakeMeRepository.homeId}'));
    expect(
      tester.getRect(row).overlaps(Offset.zero & const Size(360, 640)),
      isTrue,
    );
    expect(
      find.text(
        'Will be deleted with its 2 pets and all their records, photos and '
        'documents.',
      ),
      findsOneWidget,
    );

    // Seen now: the next tap asks, and deletes them as shown.
    await tester.scrollUntilVisible(
      deleteButton(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await delete(tester);
    expect(account.deletedPlans, ['plan-2']);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });

  testWidgets('the groups changed while the question was open: nothing is '
      'sent, and the screen says so', (tester) async {
    await openDelete(tester);
    await tester.enterText(
      find.byKey(const ValueKey('password')),
      _PasswordAuth.rightPassword,
    );
    await tapVisible(tester, deleteButton());
    expect(
      find.text(
        "“My home” will be deleted with everything in it. This can't be "
        'undone.',
      ),
      findsOneWidget,
    );

    // A live update shows the groups anew behind the question.
    someoneJoined();
    appContainer(tester).invalidate(deletionPreviewProvider);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete account'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(somethingChanged), findsOneWidget);
    expect(find.text(handedToBoris), findsOneWidget);
    // The answer was about the old groups: neither the password nor the
    // deletion went anywhere.
    expect(auth(tester).typed, isEmpty);
    expect(account.deletions, 0);

    // Asked again about the groups as they are now.
    await delete(tester);
    expect(account.deletedPlans, ['plan-2']);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });

  testWidgets('no connection: it says so, and the account stays', (
    tester,
  ) async {
    account.deleteError = networkError;
    await openDelete(tester);

    await delete(tester, password: _PasswordAuth.rightPassword);

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(appContainer(tester).read(authUserProvider), isNotNull);
    expect(push.tokensForgotten, 0);
  });

  testWidgets('no connection to check the password: the server is never '
      'asked', (tester) async {
    await openDelete(tester);
    auth(tester).failure = AuthFailure.network;

    await delete(tester, password: _PasswordAuth.rightPassword);

    expect(
      find.text('No connection. Check your internet and try again.'),
      findsOneWidget,
    );
    expect(account.deletions, 0);
  });

  testWidgets('developer sign-in: no password, the question, then deleted', (
    tester,
  ) async {
    await openDelete(tester, authMode: AuthMode.dev);

    expect(find.byKey(const ValueKey('password')), findsNothing);
    await delete(tester);

    expect(account.deletions, 1);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(find.text('Continue as developer'), findsOneWidget);
  });

  testWidgets("the groups couldn't be loaded: an error with Try again, and "
      'nothing to delete with', (tester) async {
    account.previewError = networkError;
    await openDelete(tester);

    expect(deleteButton(), findsNothing);
    account.previewError = null;
    await tapVisible(tester, find.text('Try again'));

    expect(deleteButton(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('outcome-${FakeMeRepository.homeId}')),
      findsOneWidget,
    );
  });

  testWidgets('More → Delete account opens it; Back returns to More', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.more,
      overrides: fakeRepositories(account: account),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('deleteAccount')),
      300,
    );
    expect(
      find.text("You'll see first what happens to each group"),
      findsOneWidget,
    );
    await tapVisible(tester, find.byKey(const ValueKey('deleteAccount')));

    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(account.previewCalls, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.text('Your data'), findsOneWidget);
  });

  testWidgets("the deletion went through but its answer was lost: the next "
      'tap asks the server first, hears the account is gone and signs out; '
      'never "Wrong password"', (tester) async {
    final lost = _LostAnswerAccount();
    account = lost;
    await openDelete(tester);
    lost.auth = auth(tester);

    await delete(tester, password: _PasswordAuth.rightPassword);
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(appContainer(tester).read(authUserProvider), isNotNull);

    // The connection is back; the person taps again.
    lost.online = true;
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    // The password isn't checked again: it went with the account.
    expect(auth(tester).typed, [_PasswordAuth.rightPassword]);
    expect(lost.deletions, 1);
    expect(find.text('Wrong password. Try again.'), findsNothing);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(appContainer(tester).read(authUserProvider), isNull);
  });

  testWidgets('no answer, and nothing was deleted: the next tap checks, '
      'then asks and deletes as usual', (tester) async {
    account.deleteError = networkError;
    await openDelete(tester, authMode: AuthMode.dev);
    await delete(tester);
    final asked = account.previewCalls;

    account.deleteError = null;
    await delete(tester);

    expect(account.previewCalls, greaterThan(asked));
    expect(account.deletions, 2);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });

  group('while it deletes', () {
    late _GatedAccount gated;

    Future<void> startDeleting(
      WidgetTester tester, {
      FakeMeRepository? me,
    }) async {
      gated = _GatedAccount();
      account = gated;
      await openDelete(tester, authMode: AuthMode.dev, me: me);
      await tapVisible(tester, deleteButton());
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete account'),
        ),
      );
      // The button spins: frames, not "settle".
      await tester.pump(const Duration(milliseconds: 300));
      expect(gated.deletions, 1);
    }

    bool spinning() => find
        .descendant(
          of: deleteButton(),
          matching: find.byType(CircularProgressIndicator),
        )
        .evaluate()
        .isNotEmpty;

    testWidgets('Back and the More tab leave the screen be, and the answer '
        'shows on it', (tester) async {
      await startDeleting(tester);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('More').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(spinning(), isTrue);

      gated.gate!.completeError(deletionPlanChanged);
      await tester.pumpAndSettle();
      expect(find.text(somethingChanged), findsOneWidget);
      expect(appContainer(tester).read(authUserProvider), isNotNull);
    });

    testWidgets('the app moves to another group (every tab is built anew): '
        'the new screen waits too, and shows the answer', (tester) async {
      await startDeleting(
        tester,
        me: FakeMeRepository(
          households: [
            testHousehold(FakeMeRepository.homeId),
            testHousehold('office', name: 'Office'),
          ],
        ),
      );
      final before = tester.state(find.byType(DeleteAccountScreen));

      // A tapped push of the other group moves the app there.
      appContainer(tester)
          .read(currentHouseholdProvider.notifier)
          .switchTo(const CurrentHousehold(id: 'office', name: 'Office'));
      // The tabs leave for a frame and come back; the groups load anew.
      await pumpFrames(tester);
      expect(tester.state(find.byType(DeleteAccountScreen)), isNot(before));
      expect(spinning(), isTrue);

      gated.gate!.completeError(networkError);
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Can't reach the server. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      expect(spinning(), isFalse);
    });
  });

  testWidgets('the sign-out after the deletion fails once: it is tried again '
      'and the app signs out', (tester) async {
    await openDelete(tester, authMode: AuthMode.dev);
    auth(tester).failSignOuts = 1;

    await delete(tester);

    expect(account.deletions, 1);
    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(appContainer(tester).read(authUserProvider), isNull);
  });

  testWidgets('it fails twice: the screen says the account is deleted and '
      'the app will sign out on the next start; nothing spins, Back works', (
    tester,
  ) async {
    await openDelete(tester, authMode: AuthMode.dev);
    auth(tester).failSignOuts = 2;

    await delete(tester);

    expect(
      find.text(
        "Your account is deleted, but this phone couldn't sign out of it. "
        'The app will sign out the next time it starts.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: deleteButton(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsNothing);
  });

  testWidgets('the last question names the groups that go', (tester) async {
    account.households = [
      testOutcome(FakeMeRepository.homeId, pets: 1),
      testOutcome('h2', name: 'Office', fate: HouseholdFate.kept),
      testOutcome('h3', name: 'Дача', role: HouseholdRole.member),
    ];
    await openDelete(tester, authMode: AuthMode.dev, language: 'ru');

    await tapVisible(tester, deleteButton());

    expect(
      find.text(
        'Удалятся группы «Мой дом» и «Дача» со всем, что в них есть. '
        'Отменить это нельзя.',
      ),
      findsOneWidget,
    );
  });

  test('the question in words: one group, two, three, none', () {
    final en = AppLocalizationsEn();
    final ru = AppLocalizationsRu();
    final home = testOutcome(FakeMeRepository.homeId);
    final dacha = testOutcome('h2', name: 'Dacha');
    final office = testOutcome('h3', name: 'Office');
    final kept = testOutcome('h4', name: 'Club', fate: HouseholdFate.kept);

    expect(
      deleteAccountConfirmMessage(en, [home, kept]),
      "“My home” will be deleted with everything in it. This can't be "
      'undone.',
    );
    expect(
      deleteAccountConfirmMessage(ru, [home]),
      'Удалится группа «Мой дом» со всем, что в ней есть. Отменить это '
      'нельзя.',
    );
    expect(
      deleteAccountConfirmMessage(en, [home, dacha, office]),
      '“My home”, “Dacha” and “Office” will be deleted with everything in '
      "them. This can't be undone.",
    );
    expect(
      deleteAccountConfirmMessage(ru, [home, dacha]),
      'Удалятся группы «Мой дом» и «Dacha» со всем, что в них есть. '
      'Отменить это нельзя.',
    );
    expect(deleteAccountConfirmMessage(ru, [kept]), 'Отменить это нельзя.');
  });
}
