import 'package:collarbell/features/documents/document.dart';
import 'package:collarbell/features/passport/passport.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// Narrow like a small Android phone; tall, so every row is laid out
/// without scrolling. A row that doesn't fit fails the test.
const narrowPhone = Size(360, 2400);

void main() {
  final pet = Pet(
    id: 'p1',
    name: 'Принцесса Мурка фон Гогенштауфен',
    species: PetSpecies.other,
    breed: 'Британская короткошёрстная, голубой окрас',
    sex: PetSex.unknown,
    birthDate: DateTime(2021, 9, 30),
    birthDateApproximate: true,
    neutered: true,
    neuteredOn: DateTime(2022, 12, 31),
    color: 'Чёрно-белый с рыжими подпалинами',
    status: PetStatus.deceased,
    photo: testFile('photo'),
    identifiers: [
      PetIdentifier(
        type: IdentifierType.isoChip,
        code: '276098100123456',
        rawCode: '276 098 100 123 456',
        appliedOn: DateTime(2021, 12, 1),
        location: 'Левая сторона шеи, ближе к лопатке',
      ),
      const PetIdentifier(
        type: IdentifierType.legacyChip,
        code: '0A1B2C3D4E',
        rawCode: '0A1B2C3D4E',
      ),
    ],
  );
  final passport = Passport(
    model: PassportModel.eu2026,
    number: 'DE-0123456789/2026',
    issuingCountry: 'DE',
    issuedOn: DateTime(2022, 11, 30),
    issuer: const PassportContact(
      name: 'Ветеринарная клиника «Добрый доктор Айболит»',
      phone: '+49 30 1234 5678',
    ),
    owners: const [
      PassportContact(name: 'Анна Константинопольская'),
      PassportContact(name: 'Иван Петров'),
    ],
    updatedAt: DateTime.utc(2026, 10, 1),
  );
  final documents = [
    PetDocument(
      id: 'd1',
      petId: 'p1',
      type: DocumentType.vaccinationCertificate,
      title: 'Сертификат о вакцинации от бешенства и комплексной',
      documentDate: DateTime(2026, 9, 30),
      pages: [testFile('a'), testFile('b', pdf: true)],
      createdAt: DateTime.utc(2026, 10, 1),
    ),
    PetDocument(
      id: 'd2',
      petId: 'p1',
      type: DocumentType.passportPage,
      pages: [testFile('c')],
      createdAt: DateTime.utc(2026, 10, 1),
    ),
  ];

  Future<void> open(WidgetTester tester, String location) => pumpApp(
    tester,
    location: location,
    language: 'ru',
    size: narrowPhone,
    overrides: fakeRepositories(
      pets: FakePetsRepository([pet]),
      passport: FakePassportRepository(passport),
      documents: FakeDocumentsRepository(documents),
    ),
  );

  testWidgets('the pets list and the pet tabs fit in Russian', (tester) async {
    await open(tester, '/pets');
    expect(
      find.text(
        'Нет в живых · Другое животное · Британская короткошёрстная, голубой окрас',
      ),
      findsOneWidget,
    );
    expect(find.text('Добавить питомца'), findsOneWidget);

    await open(tester, '/pets/p1');
    expect(find.text('Примерно 30 сент. 2021 г.'), findsOneWidget);

    await tester.tap(find.text('Паспорт'));
    await tester.pumpAndSettle();
    expect(find.text('Данные паспорта'), findsOneWidget);
    expect(find.text('Не ISO: в поездку берите свой сканер.'), findsOneWidget);

    // The tab bar scrolls when the tabs don't fit (the test font is wide).
    await tapVisible(tester, find.text('Документы'));
    expect(find.text('Страницы паспорта'), findsOneWidget);
  });

  testWidgets('the forms fit in Russian', (tester) async {
    await open(tester, '/pets/p1/edit');
    expect(find.text('Изменить данные'), findsWidgets);
    expect(find.text('Чип не ISO'), findsOneWidget);

    await open(tester, '/pets/new');
    expect(find.text('Новый питомец'), findsOneWidget);

    await open(tester, '/pets/p1/passport/edit');
    expect(find.text('Паспорт ЕС (образец 2026 г.)'), findsOneWidget);

    await open(tester, '/pets/p1/documents/d1/edit');
    expect(find.text('Сертификат о вакцинации'), findsOneWidget);
  });
}
