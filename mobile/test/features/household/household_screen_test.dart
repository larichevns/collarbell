// The group screen: the people and their roles; owners invite (role, then
// a code to share or copy), revoke invites, change roles, remove people and
// rename the group; everyone else only looks; anyone can leave, and an owner
// alone in an empty group can delete it. Every change names the group it
// was made on, and a dialog left open when the app moves to another group
// closes without doing anything.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const lastOwner = ApiException(
  ApiErrorKind.conflict,
  statusCode: 409,
  problem: ProblemDetails(type: ProblemTypes.lastOwner, status: 409),
);

/// Anna (the user, with [role]), Boris a member and Vera a helper.
FakeHouseholdRepository threePeople(
  HouseholdRole role, {
  FakeMeRepository? me,
  List<HouseholdInvite>? invites,
}) => FakeHouseholdRepository(
  role: role,
  me: me,
  members: [
    testMember(
      'anna',
      name: 'Anna',
      email: 'anna@example.com',
      role: role,
      isMe: true,
    ),
    testMember('boris', name: 'Boris', email: 'boris@example.com'),
    testMember('vera', name: 'Vera', role: HouseholdRole.helper),
  ],
  invites: invites,
);

void main() {
  /// Opens More, then the group screen, so going back lands on More.
  Future<void> openGroup(
    WidgetTester tester,
    FakeHouseholdRepository households, {
    FakeShare? share,
    String language = 'en',
  }) async {
    final me =
        households.me ??
        FakeMeRepository(
          households: [
            testHousehold(
              FakeMeRepository.homeId,
              role: households.role,
              memberCount: households.members.length,
            ),
          ],
        );
    await pumpApp(
      tester,
      location: AppRoutes.more,
      language: language,
      me: me,
      overrides: fakeRepositories(household: households, share: share),
    );
    await tapVisible(tester, find.byKey(const ValueKey('householdPeople')));
  }

  testWidgets('an owner sees everyone, the invites, and what to change', (
    tester,
  ) async {
    await openGroup(
      tester,
      threePeople(HouseholdRole.owner, invites: [testInvite('i1')]),
    );

    expect(find.text('My home'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('anna@example.com · you'), findsOneWidget);
    expect(find.text('boris@example.com'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('member-vera')),
        matching: find.text('Helper'),
      ),
      findsOneWidget,
    );
    expect(find.text('Invite'), findsOneWidget);
    expect(find.byTooltip('Rename'), findsOneWidget);
    expect(find.text('Open invites'), findsOneWidget);
    expect(find.text('ABCD-2345'), findsOneWidget);
    expect(find.text('Revoke'), findsOneWidget);
    expect(find.text('Leave group'), findsOneWidget);
    // Others are in it: it can't be deleted.
    expect(find.text('Delete group'), findsNothing);
  });

  for (final role in [HouseholdRole.member, HouseholdRole.helper]) {
    testWidgets("a ${role.name} sees the people but doesn't manage them", (
      tester,
    ) async {
      final households = threePeople(role);
      await openGroup(tester, households);

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Boris'), findsOneWidget);
      expect(find.text('Invite'), findsNothing);
      expect(find.byTooltip('Rename'), findsNothing);
      expect(find.text('Open invites'), findsNothing);

      // A person's row opens nothing.
      await tester.tap(find.text('Boris'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from group'), findsNothing);
      expect(households.roleChanges, isEmpty);
      // Leaving is for everyone.
      expect(find.text('Leave group'), findsOneWidget);
    });
  }

  testWidgets('people without an e-mail (as helpers get them) or a name', (
    tester,
  ) async {
    await openGroup(
      tester,
      FakeHouseholdRepository(
        role: HouseholdRole.helper,
        members: [
          testMember(
            'anna',
            name: 'Anna',
            role: HouseholdRole.helper,
            isMe: true,
          ),
          testMember('boris', name: 'Boris'),
          testMember('gleb', email: 'gleb@example.com'),
          testMember('nobody'),
        ],
      ),
    );

    // Just the name, nothing for the missing e-mail.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('member-boris')),
        matching: find.byType(Text),
      ),
      findsNWidgets(2),
    );
    expect(find.text('gleb@example.com'), findsOneWidget);
    expect(find.text('No name'), findsOneWidget);
    expect(find.text('you'), findsOneWidget);
  });

  testWidgets("an owner changes someone's role, and removes someone after "
      'asking', (tester) async {
    final households = threePeople(HouseholdRole.owner);
    await openGroup(tester, households);

    await tester.tap(find.text('Boris'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Sees everything and marks feedings, “Done”, visits and purchases.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('role-helper')));
    await tester.pumpAndSettle();

    expect(households.roleChanges, [('boris', HouseholdRole.helper)]);
    // Sent to the group the screen shows, not just whichever is on screen.
    expect(households.changedIn, [households.id]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('member-boris')),
        matching: find.text('Helper'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Boris'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from group'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Boris will no longer see the pets of this group. '
        'Their marks stay.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(households.removed, ['boris']);
    expect(find.text('Boris'), findsNothing);
  });

  testWidgets('an owner giving themselves another role is asked first', (
    tester,
  ) async {
    final households = threePeople(HouseholdRole.owner);
    await openGroup(tester, households);

    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    // Not for oneself: that is "Leave group".
    expect(find.text('Remove from group'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('role-member')));
    await tester.pumpAndSettle();
    expect(find.text('Stop being an owner?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(households.roleChanges, isEmpty);

    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change my role'));
    await tester.pumpAndSettle();

    expect(households.roleChanges, [('anna', HouseholdRole.member)]);
    // A member now: no more managing people.
    expect(find.text('Invite'), findsNothing);
  });

  testWidgets("the last owner can't step down: it says what to do first", (
    tester,
  ) async {
    final households = threePeople(HouseholdRole.owner)
      ..changeError = lastOwner;
    await openGroup(tester, households);

    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change my role'));
    await tester.pumpAndSettle();

    expect(find.text('Make someone else an owner first.'), findsOneWidget);
  });

  testWidgets('invite: the role, then the code to share or copy; an invite '
      'can be revoked', (tester) async {
    final share = FakeShare();
    final households = threePeople(HouseholdRole.owner);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await openGroup(tester, households, share: share);

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    expect(find.text('Who are you inviting?'), findsOneWidget);
    expect(
      find.text('Everything with the pets and records, but not the people.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('invite-helper')));
    await tester.pumpAndSettle();

    expect(households.newInvites, [HouseholdRole.helper]);
    expect(find.text('Invite code'), findsOneWidget);
    expect(find.text('WXYZ-6781'), findsWidgets);
    expect(find.text('The code works once, for 7 days.'), findsOneWidget);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    // As the person invited sees it: "Home", not "My home".
    expect(share.texts, [
      'Join “Home” in Collarbell: code WXYZ-6781, valid for 7 days.',
    ]);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 'WXYZ-6781');
    expect(find.text('The code was copied.'), findsOneWidget);

    // The sheet closes; the invite waits in the list until it is used.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Open invites'), findsOneWidget);
    await tapVisible(tester, find.text('Revoke'));

    expect(households.revoked, ['invite-1']);
    expect(find.text('The invite was revoked.'), findsOneWidget);
    expect(find.text('Open invites'), findsNothing);
  });

  testWidgets('in Russian: roles, "you" and the message to share', (
    tester,
  ) async {
    final share = FakeShare();
    await openGroup(
      tester,
      threePeople(HouseholdRole.owner),
      share: share,
      language: 'ru',
    );

    expect(find.text('Мой дом'), findsOneWidget);
    expect(find.text('anna@example.com · это вы'), findsOneWidget);
    expect(find.text('Владелец'), findsOneWidget);
    expect(find.text('Помощник'), findsOneWidget);

    await tester.tap(find.text('Пригласить'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-member')));
    await tester.pumpAndSettle();
    expect(
      find.text('Код сработает один раз и действует 7 дней.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Поделиться'));
    await tester.pumpAndSettle();

    expect(share.texts, [
      'Присоединяйтесь к группе «Дом» в Collarbell: код WXYZ-6781, '
          'действует 7 дней.',
    ]);
  });

  testWidgets('fits a small phone in Russian: the people, a person, the '
      'code', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.household,
      language: 'ru',
      size: const Size(360, 640),
      me: FakeMeRepository(
        households: [testHousehold(FakeMeRepository.homeId, memberCount: 3)],
      ),
      overrides: fakeRepositories(
        household: threePeople(
          HouseholdRole.owner,
          invites: [testInvite('i1')],
        ),
      ),
    );
    expect(find.text('Участники'), findsOneWidget);

    await tester.tap(find.text('Boris'));
    await tester.pumpAndSettle();
    expect(find.text('Убрать из группы'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('ABCD-2345'));
    expect(find.text('Код приглашения'), findsOneWidget);
    expect(find.text('Скопировать'), findsOneWidget);
  });

  testWidgets('owners rename the group', (tester) async {
    final households = threePeople(HouseholdRole.owner);
    await openGroup(tester, households);

    await tester.tap(find.byTooltip('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Dacha');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(households.renamed, ['Dacha']);
    expect(find.text('Dacha'), findsOneWidget);
  });

  testWidgets('a dialog left open when a push moves the app to another '
      'group closes, and nothing happens in either group', (tester) async {
    final push = FakePushPlatform();
    final me = FakeMeRepository(
      households: [
        testHousehold(FakeMeRepository.homeId),
        testHousehold('office', name: 'Office', memberCount: 3),
      ],
    );
    final households = threePeople(HouseholdRole.owner, me: me)
      ..id = 'office'
      ..name = 'Office';
    await pumpApp(
      tester,
      location: AppRoutes.household,
      me: me,
      household: const CurrentHousehold(id: 'office', name: 'Office'),
      overrides: fakeRepositories(household: households, push: push),
    );
    await tapVisible(tester, find.text('Leave group'));
    expect(find.text('Leave “Office”?'), findsOneWidget);

    push.tap({'kind': 'feeding', 'householdId': FakeMeRepository.homeId});
    await tester.pumpAndSettle();

    expect(find.text('Leave “Office”?'), findsNothing);
    expect(find.text('Leave'), findsNothing);
    expect(households.changedIn, isEmpty);
    expect(
      appContainer(tester).read(currentHouseholdProvider)?.id,
      FakeMeRepository.homeId,
    );
    expect(appRouter(tester).state.matchedLocation, AppRoutes.today);
  });

  testWidgets('leaving asks first; the last owner is told what to do', (
    tester,
  ) async {
    final households = threePeople(HouseholdRole.owner)
      ..changeError = lastOwner;
    await openGroup(tester, households);

    await tapVisible(tester, find.text('Leave group'));
    expect(find.text('Leave “My home”?'), findsOneWidget);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Make someone else an owner first.'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
  });

  testWidgets('after leaving, the app moves to another group and back to '
      'More', (tester) async {
    final me = FakeMeRepository(
      households: [
        testHousehold(FakeMeRepository.homeId),
        testHousehold('office', name: 'Office', role: HouseholdRole.member),
      ],
    );
    final households = threePeople(HouseholdRole.member, me: me)
      ..id = 'office'
      ..name = 'Office';
    await pumpApp(
      tester,
      location: AppRoutes.more,
      me: me,
      household: const CurrentHousehold(id: 'office', name: 'Office'),
      overrides: fakeRepositories(household: households),
    );
    await tapVisible(tester, find.byKey(const ValueKey('householdPeople')));

    await tapVisible(tester, find.text('Leave group'));
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(households.removed, ['anna']);
    expect(households.changedIn, ['office']);
    expect(find.text('You left “Office”.'), findsOneWidget);
    expect(appRouter(tester).state.matchedLocation, AppRoutes.more);
    expect(
      appContainer(tester).read(currentHouseholdProvider)?.id,
      me.households.single.id,
    );
    expect(find.text('My home'), findsOneWidget);
  });

  testWidgets('an owner alone in an empty group can delete it', (tester) async {
    final me = FakeMeRepository(
      households: [
        testHousehold(FakeMeRepository.homeId),
        testHousehold('office', name: 'Office'),
      ],
    );
    final households = FakeHouseholdRepository(
      id: 'office',
      name: 'Office',
      me: me,
    );
    await pumpApp(
      tester,
      location: AppRoutes.more,
      me: me,
      household: const CurrentHousehold(id: 'office', name: 'Office'),
      overrides: fakeRepositories(household: households),
    );
    await tapVisible(tester, find.byKey(const ValueKey('householdPeople')));

    // Nobody to leave it to.
    expect(find.text('Leave group'), findsNothing);
    await tapVisible(tester, find.text('Delete group'));
    expect(find.text('Delete “Office”?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(households.deleted, 1);
    expect(find.text('The group “Office” was deleted.'), findsOneWidget);
    expect(appRouter(tester).state.matchedLocation, AppRoutes.more);
  });

  testWidgets('a group with pets or supplies is not deleted, and says why', (
    tester,
  ) async {
    final households = FakeHouseholdRepository()
      ..changeError = const ApiException(
        ApiErrorKind.conflict,
        statusCode: 409,
        problem: ProblemDetails(
          type: ProblemTypes.householdNotEmpty,
          status: 409,
        ),
      );
    await openGroup(tester, households);

    await tapVisible(tester, find.text('Delete group'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Only an empty group can be deleted, and this one has pets or '
        'supplies.',
      ),
      findsOneWidget,
    );
  });
}
