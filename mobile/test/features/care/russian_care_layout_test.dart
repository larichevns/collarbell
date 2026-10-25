// The care screens in Russian on a narrow phone, with long names: a row
// that doesn't fit fails the test.
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// Narrow like a small Android phone; tall, so every row is laid out
/// without scrolling.
const narrowPhone = Size(360, 2400);

void main() {
  final pet = Pet(
    id: 'p1',
    name: 'Принцесса Мурка фон Гогенштауфен',
    species: PetSpecies.dog,
    photo: testFile('photo'),
  );
  late FakeCareRepository care;

  setUp(() {
    care = FakeCareRepository(
      plans: [
        testPlan(
          'rabies',
          kind: CareKind.vaccination,
          title: 'Вакцинация против бешенства и лептоспироза, ревакцинация',
          interval: const CareInterval(1, IntervalUnit.year),
          daysLeft: -11,
          lastDoneOn: DateTime(2025, 9, 20),
        ),
        testPlan(
          'deworm',
          title: 'Обработка от глистов',
          daysLeft: 12,
          defaultProduct: 'Мильбемакс',
        ),
        testPlan(
          'fleas',
          kind: CareKind.fleaTick,
          title: 'Блохи и клещи',
          interval: const CareInterval(12, IntervalUnit.week),
          daysLeft: 28,
        ),
        testPlan(
          'travel',
          kind: CareKind.echinococcus,
          title: 'Обработка от ленточных глистов перед поездкой',
          interval: null,
          daysLeft: -40,
          active: false,
          lastDoneOn: DateTime(2026, 8, 20),
        ),
      ],
      records: [
        testRecord(
          'r1',
          title: 'Бешенство',
          targets: const [VaccineTarget.rabies, VaccineTarget.lepto],
          product: 'Нобивак Рабиес и Нобивак Лепто',
          batchNumber: 'A123456789',
          validFrom: DateTime(2025, 9, 30),
          validUntil: DateTime(2026, 9, 30),
          files: [testFile('sticker')],
        ),
        testRecord(
          'r2',
          kind: CareKind.vetExam,
          title: 'Осмотр перед поездкой',
          weightKg: 32.5,
          details: const CareRecordDetails(fitForTravel: true),
        ),
      ],
    );
  });

  Future<void> open(WidgetTester tester, String location) => pumpApp(
    tester,
    location: location,
    language: 'ru',
    size: narrowPhone,
    overrides: fakeRepositories(
      pets: FakePetsRepository([pet]),
      care: care,
      today: FakeTodayRepository(care: care, pets: FakePetsRepository([pet])),
    ),
  );

  testWidgets('Today and the Health tab fit in Russian', (tester) async {
    await open(tester, '/today');
    expect(find.text('Просрочено'), findsOneWidget);
    expect(find.text('Позже'), findsOneWidget);
    expect(find.byTooltip('Сделано'), findsNWidgets(3));

    await open(tester, '/pets/p1?tab=health');
    expect(find.text('План ухода'), findsOneWidget);
    expect(find.text('Завершённые и на паузе (1)'), findsOneWidget);
    await tester.tap(find.text('Завершённые и на паузе (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Завершён'), findsOneWidget);
    expect(find.text('Добавить запись'), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);
  });

  testWidgets('the forms and the Done screen fit in Russian', (tester) async {
    await open(tester, '/pets/p1/plans/presets');
    expect(find.text('Только для собак'), findsOneWidget);

    await open(tester, '/pets/p1/plans/new?preset=dog-advantix');
    expect(find.text('Новый план'), findsOneWidget);
    expect(find.text('Раз в'), findsOneWidget);

    await open(tester, '/pets/p1/plans/rabies/edit');
    expect(find.text('Изменить план'), findsOneWidget);

    await open(tester, '/pets/p1/plans/rabies/done');
    expect(find.text('Отметить выполнение'), findsOneWidget);
    expect(find.text('Следующий раз'), findsOneWidget);

    await open(tester, '/pets/p1/records/new?kind=rabiesTiter');
    expect(find.text('Результат, МЕ/мл'), findsOneWidget);

    await open(tester, '/pets/p1/records/r1/edit');
    expect(find.text('Питомниковый кашель (бордетеллёз)'), findsOneWidget);
  });

  testWidgets('a record and the passport sections fit in Russian', (
    tester,
  ) async {
    await open(tester, '/pets/p1/records/r1');
    expect(find.text('Бешенство, Лептоспироз'), findsOneWidget);
    expect(find.text('Внесено вручную'), findsOneWidget);

    await open(tester, '/pets/p1?tab=passport');
    expect(find.text('V. Вакцинация против бешенства'), findsOneWidget);
    expect(
      find.text('Действует 30 сент. 2025 г. – 30 сент. 2026 г.'),
      findsOneWidget,
    );
    expect(find.text('X. Клинический осмотр'), findsOneWidget);
    expect(find.text('Может путешествовать'), findsOneWidget);
  });

  // The History header holds the scan button and "Add past record": on the
  // narrowest phones with large text they go under the title.
  for (final language in ['ru', 'en']) {
    testWidgets('the Health tab headers fit at 320 dp with large text '
        '($language)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        tester,
        location: '/pets/p1?tab=health',
        language: language,
        size: const Size(320, 640),
        overrides: fakeRepositories(
          pets: FakePetsRepository([pet]),
          care: care,
          ai: FakeAiRepository(status: testAiStatus),
        ),
      );
      await tester.scrollUntilVisible(
        find.byIcon(Symbols.document_scanner_rounded),
        200,
        scrollable: find
            .descendant(
              of: find.byType(HealthTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byIcon(Symbols.document_scanner_rounded), findsOneWidget);
      // An overflow would have failed the test by now.
    });
  }
}
