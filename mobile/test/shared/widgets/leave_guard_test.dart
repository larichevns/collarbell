// Forms ask before Back throws away what was typed, and only then.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_providers.dart';
import 'package:collarbell/data/api/offline_cache.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pet_form_screen.dart';
import 'package:collarbell/features/pets/pets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

void main() {
  testWidgets('typed something: Back asks, and Cancel keeps it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.newPet,
      overrides: fakeRepositories(),
    );
    await tester.enterText(find.byKey(const ValueKey('name')), 'Murka');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(PetFormScreen), findsOneWidget);
    expect(find.text('Murka'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(PetFormScreen), findsNothing);
    expect(find.byType(PetsScreen), findsOneWidget);
  });

  testWidgets('nothing changed: Back just leaves', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.newPet,
      overrides: fakeRepositories(),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Leave without saving?'), findsNothing);
    expect(find.byType(PetsScreen), findsOneWidget);
  });

  testWidgets('a change typed back to what it was asks nothing', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.editPet('p1'),
      overrides: fakeRepositories(
        pets: FakePetsRepository([
          const Pet(id: 'p1', name: 'Barsik', species: PetSpecies.cat),
        ]),
      ),
    );
    final name = find.byKey(const ValueKey('name'));
    await tester.enterText(name, 'Barsik!');
    await tester.enterText(name, 'Barsik');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Leave without saving?'), findsNothing);
    expect(find.byType(PetFormScreen), findsNothing);
  });

  testWidgets('tapping the tab again would drop the form: it asks too', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.newPet,
      overrides: fakeRepositories(),
    );
    await tester.enterText(find.byKey(const ValueKey('name')), 'Murka');

    await tester.tap(find.text('Pets').last);
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Murka'), findsOneWidget);

    await tester.tap(find.text('Pets').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(PetFormScreen), findsNothing);
    expect(find.byType(PetsScreen), findsOneWidget);
  });

  testWidgets('a form opened from an offline copy says so and saves nothing', (
    tester,
  ) async {
    final pets = FakePetsRepository([
      const Pet(id: 'p1', name: 'Barsik', species: PetSpecies.cat),
    ]);
    await pumpApp(
      tester,
      location: AppRoutes.pets,
      overrides: fakeRepositories(pets: pets),
    );
    ProviderScope.containerOf(tester.element(find.byType(PetsScreen)))
        .read(serverReachabilityProvider.notifier)
        .report(const ServerReachability.unreachable());
    appRouter(tester).push(AppRoutes.editPet('p1'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('name')), 'Barsik II');
    await tapVisible(tester, find.text('Save'));

    expect(find.textContaining('opened without a connection'), findsOneWidget);
    expect(pets.pets.single.name, 'Barsik');
  });
}
