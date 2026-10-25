import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/passport/passport.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

void main() {
  late FakePassportRepository passport;

  setUp(() => passport = FakePassportRepository());

  Future<void> openForm(WidgetTester tester) => pumpApp(
    tester,
    location: '/pets/p1/passport/edit',
    size: const Size(390, 2600),
    overrides: fakeRepositories(
      pets: FakePetsRepository([
        const Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat),
      ]),
      passport: passport,
    ),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('saves the header with a normalised number and country', (
    tester,
  ) async {
    await openForm(tester);

    await tester.tap(find.text('Not specified'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EU passport (2014 model)').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Passport number'), 'de 0123 4567');
    await tester.enterText(field('Issuing country'), 'de');
    // The issuing vet's fields come first; owners are added below.
    await tester.enterText(field('Name').first, 'Dr. Weber');
    await tester.enterText(field('Phone').first, '+49 30 1234');
    await tester.tap(find.text('Add owner'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name').last, 'Anna');
    await save(tester);

    final (petId, saved) = passport.saved.single;
    expect(petId, 'p1');
    expect(saved.model, PassportModel.eu2014);
    expect(saved.number, 'DE01234567');
    expect(saved.issuingCountry, 'DE');
    expect(
      saved.issuer,
      const PassportContact(name: 'Dr. Weber', phone: '+49 30 1234'),
    );
    expect(saved.owners, [const PassportContact(name: 'Anna')]);
    expect(find.text('Passport details'), findsNothing, reason: 'form closed');
  });

  testWidgets('checks the country code and emails before saving', (
    tester,
  ) async {
    await openForm(tester);

    await tester.enterText(field('Issuing country'), 'Deutschland');
    await tester.enterText(field('Email').first, 'vet-at-example.com');
    await save(tester);

    expect(
      find.text('Use the two-letter country code, such as DE or FR'),
      findsOneWidget,
    );
    expect(find.text('Enter an email like name@example.com'), findsOneWidget);
    expect(passport.saved, isEmpty);
  });

  testWidgets('shows server errors on the owner fields they name', (
    tester,
  ) async {
    passport.saveError = const ApiException(
      ApiErrorKind.validation,
      statusCode: 400,
      problem: ProblemDetails(
        status: 400,
        errors: {
          'owners[0].phone': ['Use 40 characters or fewer.'],
        },
      ),
    );
    await openForm(tester);
    await tester.tap(find.text('Add owner'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name').last, 'Anna');
    await tester.enterText(field('Phone').last, '+49 30 1234');

    await save(tester);

    expect(find.text("This value wasn't accepted. Check it."), findsOneWidget);
    expect(
      find.text("Some details weren't accepted. Check them and try again."),
      findsNothing,
    );
  });

  testWidgets('an owner removed after a failed save is forgotten', (
    tester,
  ) async {
    await openForm(tester);
    await tester.tap(find.text('Add owner'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Email').last, 'not-an-email');
    await save(tester);
    expect(find.text('Enter an email like name@example.com'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove owner'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await save(tester);

    expect(passport.saved.single.$2.owners, isEmpty);
  });

  testWidgets('a server error for owner 2 shows on the second card', (
    tester,
  ) async {
    passport.saveError = const ApiException(
      ApiErrorKind.validation,
      statusCode: 400,
      problem: ProblemDetails(
        status: 400,
        errors: {
          'owners[1].phone': ['Use 40 characters or fewer.'],
        },
      ),
    );
    await openForm(tester);
    // Owner 1 stays empty; owner 2 is filled in.
    await tester.tap(find.text('Add owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add owner'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name').last, 'Anna');
    await tester.enterText(field('Phone').last, '+49 30 1234');

    await save(tester);

    // Both cards are sent as they are, so the indexes match.
    expect(passport.attempts.single.$2.owners, hasLength(2));
    final ownerTwo = find
        .ancestor(of: find.text('Owner 2'), matching: find.byType(Container))
        .first;
    expect(
      find.descendant(
        of: ownerTwo,
        matching: find.text("This value wasn't accepted. Check it."),
      ),
      findsOneWidget,
    );
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
  });
}
