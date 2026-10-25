// Joining with a code: the code as people type or paste it, what it invites
// to, joining (the app moves to that group), and why a code doesn't work.
import 'dart:async';

import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/household/household_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

InvitePreview dachaInvite({bool alreadyMember = false}) => InvitePreview(
  householdName: 'Dacha',
  invitedBy: 'Anna',
  role: HouseholdRole.helper,
  expiresAt: DateTime(2026, 10, 12),
  alreadyMember: alreadyMember,
);

void main() {
  group('the code field', () {
    String typed(String text) =>
        InviteCodeFormatter.format(InviteCodeFormatter.digitsOf(text));

    test('upper case, a hyphen after four, at most eight', () {
      expect(typed('abcd'), 'ABCD');
      expect(typed('abcd2'), 'ABCD-2');
      expect(typed('abcd2345'), 'ABCD-2345');
      expect(typed('ABCD-2345X'), 'ABCD-2345');
      expect(typed('abcd 2345'), 'ABCD-2345');
      // Deleting goes past the hyphen.
      expect(typed('ABCD-'), 'ABCD');
    });

    test('a pasted message gives its code', () {
      expect(
        typed('Join “Office” in Collarbell: code WXYZ-6781, valid for 7 days.'),
        'WXYZ-6781',
      );
      expect(
        typed(
          'Присоединяйтесь к группе «Дом» в Collarbell: код abcd-2345, '
          'действует 7 дней.',
        ),
        'ABCD-2345',
      );
    });
  });

  late FakeMeRepository me;
  late FakeHouseholdRepository households;

  setUp(() {
    me = FakeMeRepository();
    households = FakeHouseholdRepository(me: me)
      ..previews['ABCD2345'] = dachaInvite();
  });

  /// From More through "Switch group" to "Join with a code".
  Future<void> openJoin(WidgetTester tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.more,
      me: me,
      overrides: fakeRepositories(household: households),
    );
    await tapVisible(tester, find.byKey(const ValueKey('switchHousehold')));
    await tester.tap(find.byKey(const ValueKey('joinHousehold')));
    await tester.pumpAndSettle();
  }

  Future<void> typeCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextFormField), code);
    await tester.pumpAndSettle();
  }

  testWidgets('shows what the code invites to, joins, and moves the app '
      'there', (tester) async {
    await openJoin(tester);
    expect(find.text('Join a group'), findsOneWidget);

    await typeCode(tester, 'abcd2345');

    expect(find.text('ABCD-2345'), findsOneWidget);
    expect(households.previewed, ['ABCD2345']);
    expect(
      find.text('Anna invites you to “Dacha” as a helper.'),
      findsOneWidget,
    );
    expect(find.text('The code works until Oct 12.'), findsOneWidget);

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(households.accepted, ['ABCD2345']);
    expect(find.text('You joined “Dacha”.'), findsOneWidget);
    expect(appRouter(tester).state.matchedLocation, AppRoutes.more);
    final current = appContainer(tester).read(currentHouseholdProvider);
    expect((current?.id, current?.role), ('joined', HouseholdRole.helper));
    expect(find.text('Dacha'), findsOneWidget);
    expect(find.text('Helper · 2 people'), findsOneWidget);
  });

  testWidgets('in Russian: who invites, where and as whom', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.joinHousehold,
      language: 'ru',
      me: me,
      overrides: fakeRepositories(household: households),
    );

    await typeCode(tester, 'ABCD2345');

    expect(
      find.text('Anna приглашает вас в группу «Dacha» как помощника.'),
      findsOneWidget,
    );
    expect(find.text('Вступить'), findsOneWidget);
  });

  testWidgets("a wrong code says so, and nothing can be joined", (
    tester,
  ) async {
    await openJoin(tester);

    await typeCode(tester, 'ZZZZ9999');

    expect(
      find.text("This code doesn't work: check it or ask for a new one."),
      findsOneWidget,
    );
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(households.accepted, isEmpty);
  });

  testWidgets('a group the user is in already: said before joining', (
    tester,
  ) async {
    households.previews['ABCD2345'] = dachaInvite(alreadyMember: true);
    await openJoin(tester);

    await typeCode(tester, 'ABCD2345');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.text("You're already in this group."), findsOneWidget);
    expect(households.accepted, isEmpty);
  });

  testWidgets('joining refused: already in it, or the code was used '
      'meanwhile', (tester) async {
    households.acceptError = const ApiException(
      ApiErrorKind.conflict,
      statusCode: 409,
      problem: ProblemDetails(type: ProblemTypes.alreadyAMember, status: 409),
    );
    await openJoin(tester);
    await typeCode(tester, 'ABCD2345');

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(find.text("You're already in this group."), findsOneWidget);

    households.acceptError = notFound;
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(
      find.text("This code doesn't work: check it or ask for a new one."),
      findsOneWidget,
    );
    expect(appRouter(tester).state.matchedLocation, AppRoutes.joinHousehold);
  });

  testWidgets("a character codes never have: said at once, and the server "
      'is not asked', (tester) async {
    await openJoin(tester);

    await typeCode(tester, 'ABC0');
    expect(
      find.text(
        'Codes have no letters O and I and no digits 0 and 1: check the code.',
      ),
      findsOneWidget,
    );
    await typeCode(tester, 'ABCO2345');
    expect(households.previewed, isEmpty);
  });

  testWidgets('typing on while a code is checked: its answer is dropped', (
    tester,
  ) async {
    final gate = Completer<void>();
    final slow = _SlowPreview(gate, me: me)
      ..previews['ABCD2345'] = dachaInvite();
    await pumpApp(
      tester,
      location: AppRoutes.joinHousehold,
      me: me,
      overrides: fakeRepositories(household: slow),
    );

    await tester.enterText(find.byType(TextFormField), 'ABCD2345');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'ABCD234');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Anna invites you to “Dacha” as a helper.'), findsNothing);
  });

  testWidgets('too many tries: wait a few minutes', (tester) async {
    households.previewError = const ApiException(
      ApiErrorKind.unknown,
      statusCode: 429,
    );
    await openJoin(tester);

    await typeCode(tester, 'ABCD2345');

    expect(
      find.text('Too many tries. Try again in a few minutes.'),
      findsOneWidget,
    );
  });
}

/// Answers the preview only when [gate] opens, like a slow server.
class _SlowPreview extends FakeHouseholdRepository {
  _SlowPreview(this.gate, {super.me});

  final Completer<void> gate;

  @override
  Future<InvitePreview> previewInvite(String code) async {
    await gate.future;
    return super.previewInvite(code);
  }
}
