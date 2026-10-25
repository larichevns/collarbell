// Supplies: the tab (what to buy first), "Bought" and "Correct", the item's
// page, the form, Today's "To buy", and a feeding that gives a food from
// supplies.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/feeding/feeding.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/supplies/supply.dart';
import 'package:collarbell/shared/widgets/cb_status_tag.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

Pet testPet(String id, String name) =>
    Pet(id: id, name: name, species: PetSpecies.cat, sex: PetSex.unknown);

void main() {
  group('the Supplies tab', () {
    testWidgets('what to buy comes first, with "Bought"; items no longer '
        'bought come last', (tester) async {
      final supplies = FakeSuppliesRepository(
        supplies: [
          testSupply('plenty', 'Plenty food'),
          testSupply('low', 'Low food', remaining: 200),
          testSupply('soon', 'Soon food', remaining: 800),
          testSupply('old', 'Old food', active: false),
          testSupply('litter', 'Litter', remaining: null, perDay: null),
        ],
      );
      // Tall enough for the whole list.
      await pumpApp(
        tester,
        location: AppRoutes.supplies,
        overrides: fakeRepositories(supplies: supplies),
        size: const Size(390, 1600),
      );

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      for (final title in [
        'To buy',
        'Running out soon',
        'In stock',
        'No longer bought',
      ]) {
        expect(find.text(title), findsWidgets);
      }
      expect(top('Low food'), lessThan(top('Soon food')));
      expect(top('Soon food'), lessThan(top('Plenty food')));
      expect(top('Plenty food'), lessThan(top('Old food')));
      // "Time to buy" is a yellow status tag; how long it lasts follows.
      expect(
        tester
            .widget<CbStatusTag>(
              find.ancestor(
                of: find.text('Time to buy'),
                matching: find.byType(CbStatusTag),
              ),
            )
            .tone,
        CbStatusTone.soon,
      );
      expect(find.text('Enough for about 2 days'), findsOneWidget);
      expect(find.text('Stock not entered'), findsOneWidget);
      expect(find.byKey(const ValueKey('bought-low')), findsOneWidget);
      expect(find.byKey(const ValueKey('bought-plenty')), findsNothing);
    });

    testWidgets('"Bought" adds packages and the item moves on', (tester) async {
      final supplies = FakeSuppliesRepository(
        supplies: [testSupply('low', 'Low food', remaining: 200)],
      );
      await pumpApp(
        tester,
        location: AppRoutes.supplies,
        overrides: fakeRepositories(supplies: supplies),
      );

      await tester.tap(find.byKey(const ValueKey('bought-low')));
      await tester.pumpAndSettle();
      expect(find.text('Bought: Low food'), findsOneWidget);
      expect(find.text('Packages of 2 kg'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byTooltip('More'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('saveStock')));
      await tester.pumpAndSettle();

      expect(supplies.added.single.$2, StockEventKind.purchase);
      expect(supplies.added.single.$3, 4000);
      expect(find.text('Purchase saved'), findsOneWidget);
      expect(find.text('To buy'), findsNothing);
    });

    testWidgets('an empty list says what supplies are for', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.supplies,
        overrides: fakeRepositories(),
      );

      expect(find.text('No supplies yet'), findsOneWidget);
      // The ways to add the first item are right there, as cards; the
      // button over the list comes with it.
      expect(find.byKey(const ValueKey('addSupply')), findsNothing);
      expect(find.byKey(const ValueKey('firstByBarcode')), findsOneWidget);
      expect(find.text('Scan the barcode'), findsOneWidget);
      // Without AI there are no photos to read.
      expect(find.text('Take photos of the package'), findsNothing);
      await tapVisible(tester, find.text('Fill in by hand'));
      expect(find.text('New item'), findsOneWidget);
    });
  });

  group('an item', () {
    testWidgets('its page: how long it lasts, the feedings, the history', (
      tester,
    ) async {
      final supplies = FakeSuppliesRepository(
        supplies: [
          testSupply(
            's1',
            'Royal Canin',
            brand: 'Royal Canin',
            feedings: const [
              SupplyFeeding(
                routineId: 'r1',
                petId: 'p1',
                petName: 'Murka',
                amount: 40,
                unit: PortionUnit.gram,
                timesPerDay: 2,
                counted: true,
              ),
            ],
          ),
        ],
      );
      supplies.stock['s1'] = [
        StockEntry(
          id: 'e1',
          kind: StockEventKind.purchase,
          quantity: 2000,
          at: testToday(),
          byMe: false,
          byName: 'Anna',
        ),
      ];
      await pumpApp(
        tester,
        location: AppRoutes.supply('s1'),
        overrides: fakeRepositories(supplies: supplies),
      );

      expect(find.text('Enough for about 25 days'), findsOneWidget);
      expect(find.text('Left: ≈ 2 kg (≈ 1 pkg)'), findsOneWidget);
      expect(find.text('Uses 80 g a day, from the feedings'), findsOneWidget);
      expect(find.textContaining('delivery 5 days'), findsOneWidget);
      final page = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Murka'),
        100,
        scrollable: page,
      );
      expect(find.text('40 g × 2 a day'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Bought +2 kg'),
        100,
        scrollable: page,
      );
      expect(find.textContaining('Anna'), findsOneWidget);

      await tester.tap(find.byTooltip('Take back'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Take back'));
      await tester.pumpAndSettle();
      expect(supplies.stock['s1'], isEmpty);
      expect(find.text('No purchases or counts yet'), findsOneWidget);
    });

    testWidgets('"Correct" starts from the estimate; "None left" is a count '
        'of nothing', (tester) async {
      final supplies = FakeSuppliesRepository(
        supplies: [testSupply('s1', 'Food', remaining: 2500)],
      );
      await pumpApp(
        tester,
        location: AppRoutes.supply('s1'),
        overrides: fakeRepositories(supplies: supplies),
      );

      await tester.tap(find.byKey(const ValueKey('count')));
      await tester.pumpAndSettle();
      expect(find.text("What's left: Food"), findsOneWidget);
      expect(find.text('Open package: about 30%'), findsOneWidget);
      expect(find.text('In all ≈ 2.6 kg'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nothingLeft')));
      await tester.pumpAndSettle();

      expect(supplies.added.single.$2, StockEventKind.adjustment);
      expect(supplies.added.single.$3, 0);
      expect(find.text('Ran out'), findsWidgets);
    });

    testWidgets('a bag just bought counts as one unopened, not an open one '
        'at 100 %', (tester) async {
      final supplies = FakeSuppliesRepository(
        supplies: [testSupply('s1', 'Food', remaining: 1999.9)],
      );
      await pumpApp(
        tester,
        location: AppRoutes.supply('s1'),
        overrides: fakeRepositories(supplies: supplies),
      );

      await tester.tap(find.byKey(const ValueKey('count')));
      await tester.pumpAndSettle();

      expect(find.text('Open package: about 0%'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(BottomSheet), matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('a new food: in kilograms, counted from the feedings, one '
        'bag there now', (tester) async {
      final supplies = FakeSuppliesRepository();
      await pumpApp(
        tester,
        location: AppRoutes.newSupply,
        overrides: fakeRepositories(supplies: supplies),
      );

      await tester.enterText(
        find.byKey(const ValueKey('name')).first,
        'Royal Canin',
      );
      // Not filled in: the form says what is missing.
      await tapVisible(tester, find.text('Save'));
      expect(find.text('A number above 0'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('packageSize')), '2');
      await tapVisible(tester, find.text('Save'));

      final (input, _) = supplies.created.single;
      expect(
        (input.name, input.category, input.unit, input.packageSize),
        ('Royal Canin', SupplyCategory.dryFood, SupplyUnit.gram, 2000.0),
      );
      expect(input.usageMode, SupplyUsageMode.feeding);
      expect(input.initialStock, 2000);
      expect(input.leadTimeDays, 5);
      // The new item's page.
      expect(find.text('Royal Canin'), findsWidgets);
      expect(find.text('Daily use not set'), findsOneWidget);
    });

    testWidgets('litter is counted by hand: "a 10 kg bag lasts 30 days"', (
      tester,
    ) async {
      final supplies = FakeSuppliesRepository();
      await pumpApp(
        tester,
        location: AppRoutes.newSupply,
        overrides: fakeRepositories(supplies: supplies),
      );

      await tester.enterText(
        find.byKey(const ValueKey('name')).first,
        'Litter',
      );
      await tapVisible(tester, find.text('Litter').last);
      await tester.enterText(find.byKey(const ValueKey('packageSize')), '10');
      await tester.ensureVisible(find.byKey(const ValueKey('manual')));
      await tester.enterText(find.byKey(const ValueKey('manual')), '30');
      await tapVisible(tester, find.text('Save'));

      final (input, _) = supplies.created.single;
      expect(input.usageMode, SupplyUsageMode.manual);
      expect(input.manualDailyUsage, closeTo(10000 / 30, 0.001));
      expect(find.text('Enough for about 30 days'), findsOneWidget);
    });

    testWidgets('the unit follows the kind until it is picked', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.newSupply,
        overrides: fakeRepositories(),
      );

      expect(find.text('kg'), findsOneWidget);
      await tapVisible(tester, find.text('Medicine'));
      expect(find.text('doses'), findsOneWidget);
      await tapVisible(tester, find.text('Wet food'));
      expect(find.text('pcs'), findsOneWidget);
    });

    testWidgets('a wrong barcode is told apart from one in use', (
      tester,
    ) async {
      final supplies = FakeSuppliesRepository();
      await pumpApp(
        tester,
        location: AppRoutes.newSupply,
        overrides: fakeRepositories(supplies: supplies),
      );

      await tester.enterText(find.byKey(const ValueKey('name')).first, 'Food');
      await tester.enterText(find.byKey(const ValueKey('packageSize')), '2');
      await tester.ensureVisible(find.byKey(const ValueKey('barcode')));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('barcode')),
          matching: find.byType(TextFormField),
        ),
        '4006381333932',
      );
      await tapVisible(tester, find.text('Save'));

      expect(find.text("Check the barcode's digits"), findsOneWidget);
      expect(supplies.created, isEmpty);
    });

    testWidgets('Russian: 1,5 kg is 1500 g', (tester) async {
      final supplies = FakeSuppliesRepository();
      await pumpApp(
        tester,
        location: AppRoutes.newSupply,
        overrides: fakeRepositories(supplies: supplies),
        language: 'ru',
      );

      await tester.enterText(find.byKey(const ValueKey('name')).first, 'Корм');
      await tester.enterText(find.byKey(const ValueKey('packageSize')), '1,5');
      await tapVisible(tester, find.text('Сохранить'));

      final (input, _) = supplies.created.single;
      expect(input.packageSize, 1500);
      expect(input.initialStock, 1500);
    });

    testWidgets('a package that lasts long keeps its days when edited', (
      tester,
    ) async {
      // A pack of one dose lasting 504 days: the server keeps 0.001984.
      final supplies = FakeSuppliesRepository(
        supplies: [
          Supply(
            id: 's1',
            name: 'Collar',
            category: SupplyCategory.medication,
            unit: SupplyUnit.dose,
            packageSize: 1,
            usageMode: SupplyUsageMode.manual,
            manualDailyUsage: 0.001984,
            leadTimeDays: 5,
            forecast: FakeSuppliesRepository.forecastOf(1, 0.001984, 5),
          ),
        ],
      );
      await pumpApp(
        tester,
        location: AppRoutes.editSupply('s1'),
        overrides: fakeRepositories(supplies: supplies),
      );

      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('manual')))
            .controller!
            .text,
        '504',
      );
      await tapVisible(tester, find.text('Save'));

      final (_, input) = supplies.updated.single;
      expect(input.manualDailyUsage, closeTo(1 / 504, 1e-6));
    });

    testWidgets('a link must be a web address', (tester) async {
      final supplies = FakeSuppliesRepository();
      await pumpApp(
        tester,
        location: AppRoutes.newSupply,
        overrides: fakeRepositories(supplies: supplies),
      );

      await tester.enterText(find.byKey(const ValueKey('name')).first, 'Food');
      await tester.enterText(find.byKey(const ValueKey('packageSize')), '2');
      await tester.ensureVisible(find.byKey(const ValueKey('storeUrl')));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('storeUrl')),
          matching: find.byType(TextFormField),
        ),
        'javascript:alert(1)',
      );
      await tapVisible(tester, find.text('Save'));

      expect(
        find.text('Use a link starting with https:// or http://'),
        findsOneWidget,
      );
      expect(supplies.created, isEmpty);
    });

    testWidgets('editing shows 2000 g as 2 kg and keeps the stock', (
      tester,
    ) async {
      final supplies = FakeSuppliesRepository(
        supplies: [testSupply('s1', 'Food', remaining: 1500)],
      );
      await pumpApp(
        tester,
        location: AppRoutes.editSupply('s1'),
        overrides: fakeRepositories(supplies: supplies),
      );

      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('packageSize')))
            .controller!
            .text,
        '2',
      );
      expect(find.text('kg'), findsOneWidget);
      // The stock is changed by purchases and counts, not here.
      expect(find.text('Say how much there is now'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('name')).first,
        'Food 2',
      );
      await tapVisible(tester, find.text('Save'));

      final (id, input) = supplies.updated.single;
      expect(
        (id, input.name, input.packageSize, input.initialStock),
        ('s1', 'Food 2', 2000.0, null),
      );
    });
  });

  testWidgets('Today lists what to buy, with "Bought" right there', (
    tester,
  ) async {
    final supplies = FakeSuppliesRepository(
      supplies: [testSupply('s1', 'Royal Canin', remaining: 0)],
    );
    await pumpApp(
      tester,
      location: AppRoutes.today,
      overrides: fakeRepositories(
        supplies: supplies,
        today: FakeTodayRepository(supplies: supplies),
      ),
    );

    expect(find.text('To buy'), findsOneWidget);
    expect(find.text('Ran out'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('todayBought-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveStock')));
    await tester.pumpAndSettle();

    expect(supplies.added.single.$3, 2000);
    // Bought: nothing to buy any more.
    expect(find.text('To buy'), findsNothing);
  });

  testWidgets('saving a feeding reloads the estimates of supplies', (
    tester,
  ) async {
    final supplies = FakeSuppliesRepository(
      supplies: [testSupply('s1', 'Royal Canin')],
    );
    final feeding = FakeFeedingRepository();
    await pumpApp(
      tester,
      location: AppRoutes.supplies,
      overrides: fakeRepositories(
        supplies: supplies,
        feeding: feeding,
        pets: FakePetsRepository([testPet('p1', 'Murka')]),
      ),
    );
    final before = supplies.listCalls;

    final router = tester.element(find.byType(Scaffold).first);
    GoRouter.of(router).push(AppRoutes.newFeeding('p1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add time'));
    await tester.pumpAndSettle();
    await enterPickerTime(tester, const TimeOfDay(hour: 8, minute: 0));
    await tapVisible(tester, find.text('Save'));

    expect(feeding.lastInput, isNotNull);
    expect(supplies.listCalls, greaterThan(before));
  });

  testWidgets('a feeding gives a food from supplies: its name, its unit', (
    tester,
  ) async {
    final feeding = FakeFeedingRepository();
    await pumpApp(
      tester,
      location: AppRoutes.newFeeding('p1'),
      overrides: fakeRepositories(
        feeding: feeding,
        pets: FakePetsRepository([testPet('p1', 'Murka')]),
        supplies: FakeSuppliesRepository(
          supplies: [
            testSupply('s1', 'Royal Canin'),
            testSupply(
              'pouches',
              'Pouches',
              category: SupplyCategory.wetFood,
              unit: SupplyUnit.piece,
              packageSize: 12,
            ),
            testSupply('old', 'Old food', active: false),
            testSupply('litter', 'Litter', category: SupplyCategory.litter),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Add time'));
    await tester.pumpAndSettle();
    await enterPickerTime(tester, const TimeOfDay(hour: 8, minute: 0));
    await tester.ensureVisible(find.byKey(const ValueKey('supply')));
    await tester.tap(find.byKey(const ValueKey('supply')));
    await tester.pumpAndSettle();
    // Food the household buys: not litter, not what it no longer buys.
    expect(find.text('Old food'), findsNothing);
    expect(find.text('Litter'), findsNothing);
    await tester.tap(find.text('Pouches').last);
    await tester.pumpAndSettle();
    // The food is the item's; the portion is counted in its pieces.
    expect(find.byKey(const ValueKey('food')), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, '40'), '1');
    await tapVisible(tester, find.text('Save'));

    final input = feeding.lastInput!;
    expect(
      (input.supplyItemId, input.food, input.unit),
      ('pouches', 'Pouches', PortionUnit.piece),
    );
  });
}
