import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/me/profile_sync.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/features/pets/pets_screen.dart';
import 'package:collarbell/features/pets/widgets/pet_avatar.dart';
import 'package:collarbell/theme/collarbell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// The avatar of the pet row that shows [name].
Finder avatarOf(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(PetRow)),
  matching: find.byType(PetAvatar),
);

void main() {
  Future<void> pumpPets(
    WidgetTester tester,
    FakePetsRepository repository, {
    Locale locale = const Locale('en'),
  }) {
    return pumpScreen(
      tester,
      const PetsScreen(),
      locale: locale,
      overrides: [
        petsRepositoryProvider.overrideWithValue(repository),
        // No API in widget tests: the profile sync completes at once.
        profileSyncProvider.overrideWith((ref) async {}),
      ],
    );
  }

  testWidgets('shows the empty state when the household has no pets', (
    tester,
  ) async {
    await pumpPets(tester, FakePetsRepository());

    expect(find.text('Pets'), findsOneWidget);
    expect(find.text('No pets yet'), findsOneWidget);
    expect(find.text("You'll add your cats and dogs here."), findsOneWidget);
  });

  testWidgets('shows the empty state in Russian', (tester) async {
    await pumpPets(tester, FakePetsRepository(), locale: const Locale('ru'));

    expect(find.text('Питомцы'), findsOneWidget);
    expect(find.text('Пока нет питомцев'), findsOneWidget);
    expect(find.text('Здесь появятся ваши кошки и собаки.'), findsOneWidget);
  });

  testWidgets('lists pets with name, species and a neutral avatar', (
    tester,
  ) async {
    final repository = FakePetsRepository([
      const Pet(
        id: '1',
        name: 'Murka',
        species: PetSpecies.cat,
        breed: 'British Shorthair',
      ),
      const Pet(id: '2', name: 'Rex', species: PetSpecies.dog),
    ]);

    await pumpPets(tester, repository);

    expect(find.text('Murka'), findsOneWidget);
    expect(find.text('Cat · British Shorthair'), findsOneWidget);
    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('No pets yet'), findsNothing);

    // Every pet gets the same colours: the initial in `on-avatar` on the
    // `avatar` circle.
    for (final (index, initial) in [(0, 'M'), (1, 'R')]) {
      final disc = tester.widget<Container>(
        find.descendant(
          of: find.byType(PetAvatar).at(index),
          matching: find.byType(Container),
        ),
      );
      expect(
        (disc.decoration! as BoxDecoration).color,
        CbTokenColors.light.avatar,
      );
      final letter = tester.widget<Text>(find.text(initial));
      expect(letter.style!.color, CbTokenColors.light.onAvatar);
    }
  });

  testWidgets('shows an error with "Try again" and reloads', (tester) async {
    final repository = FakePetsRepository()
      ..error = const ApiException(
        ApiErrorKind.server,
        statusCode: 500,
        problem: ProblemDetails(status: 500, title: 'Boom', traceId: '00-abc'),
      );

    await pumpPets(tester, repository);

    expect(
      find.text('Something went wrong on our side. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text('Error ID: 00-abc'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository
      ..error = null
      ..pets = [const Pet(id: '1', name: 'Murka', species: PetSpecies.cat)];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Murka'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(repository.calls, 2);
  });

  testWidgets('shows the photo thumbnail, or the initial without a photo', (
    tester,
  ) async {
    final repository = FakePetsRepository([
      Pet(
        id: '1',
        name: 'Murka',
        species: PetSpecies.cat,
        photo: testFile('photo-1'),
      ),
      const Pet(id: '2', name: 'Rex', species: PetSpecies.dog),
    ]);

    await pumpPets(tester, repository);

    final photo = find.descendant(
      of: avatarOf('Murka'),
      matching: find.byType(Image),
    );
    expect(photo, findsOneWidget);
    expect(
      find.descendant(of: avatarOf('Rex'), matching: find.byType(Image)),
      findsNothing,
    );
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('lists archived and deceased pets after active ones, quieter', (
    tester,
  ) async {
    final repository = FakePetsRepository([
      const Pet(
        id: '1',
        name: 'Barsik',
        species: PetSpecies.cat,
        status: PetStatus.deceased,
      ),
      const Pet(id: '2', name: 'Rex', species: PetSpecies.dog),
      const Pet(
        id: '3',
        name: 'Tuzik',
        species: PetSpecies.dog,
        status: PetStatus.archived,
      ),
    ]);

    await pumpPets(tester, repository);

    final names = [
      for (final row in tester.widgetList<PetRow>(find.byType(PetRow)))
        row.pet.name,
    ];
    expect(names, ['Rex', 'Barsik', 'Tuzik']);
    expect(find.text('Deceased · Cat'), findsOneWidget);
    expect(find.text('Archived · Dog'), findsOneWidget);
    final barsik = tester.widget<Text>(find.text('Barsik'));
    expect(barsik.style?.color, CbTokenColors.light.inkMuted);
    final rex = tester.widget<Text>(find.text('Rex'));
    expect(rex.style?.color, CbTokenColors.light.ink);
  });

  testWidgets('"Add pet" opens the form; a pet opens its page', (tester) async {
    final repository = FakePetsRepository([
      const Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat),
    ]);
    await pumpApp(
      tester,
      location: '/pets',
      overrides: [petsRepositoryProvider.overrideWithValue(repository)],
    );

    await tester.tap(find.text('Add pet'));
    await tester.pumpAndSettle();
    expect(find.text('New pet'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Murka'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
  });
}
