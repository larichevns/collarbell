// The scan screens in Russian on a narrow phone, with long values: a row
// that doesn't fit fails the test.
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/passport/passport.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// Narrow like a small Android phone; tall, so every entry is laid out
/// without scrolling.
const narrowPhone = Size(360, 3200);

void main() {
  const pet = Pet(
    id: 'p1',
    name: 'Принцесса Мурка фон Гогенштауфен',
    species: PetSpecies.dog,
  );
  late FakeAiRepository ai;
  late FakeCareRepository care;

  setUp(() {
    ai = FakeAiRepository(
      status: testAiStatus,
      scans: [
        testScan(
          'scan-1',
          status: ScanStatus.ready,
          pages: [testFile('page-1'), testFile('page-2')],
          draft: ScanDraft(
            records: [
              DraftRecord(
                key: 0,
                kind: CareKind.vaccination,
                title: 'Вакцинация против бешенства и лептоспироза',
                performedOn: DateTime(2025, 3, 12),
                product: 'Нобивак Рабиес и Нобивак Лепто',
                manufacturer: 'MSD Animal Health',
                batchNumber: 'A123B45C67',
                validUntil: DateTime(2028, 3, 11),
                targets: const [VaccineTarget.rabies, VaccineTarget.lepto],
                veterinarian: 'Анна Сергеевна Петрова-Водкина',
                clinic: 'Ветеринарная клиника «Белый клык» на Васильевском',
                evidence: 'Нобивак Рабиес, серия A123B45C67, 12.03.2025',
                warnings: const [
                  DraftWarning('performedOn', DraftIssue.ambiguous),
                ],
                planId: 'plan-rabies',
              ),
              const DraftRecord(
                key: 1,
                kind: CareKind.echinococcus,
                title: 'Обработка от ленточных глистов перед поездкой',
                product: 'Мильпразон',
                page: 2,
                warnings: [DraftWarning('performedOn', DraftIssue.unreadable)],
                selected: false,
              ),
              DraftRecord(
                key: 2,
                kind: CareKind.deworming,
                title: 'Обработка от глистов',
                performedOn: DateTime(2025, 1, 5),
                page: 2,
                warnings: const [
                  DraftWarning('performedOn', DraftIssue.alreadySaved),
                ],
                selected: false,
              ),
            ],
            identifiers: [
              DraftIdentifier(
                key: 0,
                type: IdentifierType.legacyChip,
                code: '0A1B2C3D4E',
                appliedOn: DateTime(2019, 5, 20),
                location: 'Между лопатками, ближе к левому плечу',
                warnings: const [DraftWarning('code', DraftIssue.alreadySaved)],
                selected: false,
              ),
            ],
            passport: DraftPassport(
              number: 'RU-0123456789/2020',
              issuingCountry: 'RU',
              issuedOn: DateTime(2020, 3, 1),
              warnings: const [
                DraftWarning('passportNumber', DraftIssue.differsFromSaved),
              ],
              selected: false,
            ),
          ),
        ),
      ],
    );
    care = FakeCareRepository(
      plans: [
        testPlan(
          'plan-rabies',
          kind: CareKind.vaccination,
          title: 'Вакцинация против бешенства, ежегодная ревакцинация',
          interval: const CareInterval(1, IntervalUnit.year),
          targets: const [VaccineTarget.rabies],
          daysLeft: 20,
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
      passport: FakePassportRepository(
        Passport(number: 'RU0999', updatedAt: DateTime.utc(2026, 9, 1)),
      ),
      ai: ai,
    ),
  );

  testWidgets('the review fits in Russian and reads naturally', (tester) async {
    await open(tester, '/pets/p1/scans/scan-1');

    expect(find.text('Проверка скана'), findsOneWidget);
    expect(find.text('Записи'), findsOneWidget);
    expect(
      find.text('День и месяц могли перепутаться. Сверьте с оригиналом.'),
      findsOneWidget,
    );
    expect(find.text('Заменить на 3 дек. 2025 г.'), findsOneWidget);
    expect(
      find.text(
        'Отметить выполнение в плане «Вакцинация против бешенства, '
        'ежегодная ревакцинация»',
      ),
      findsOneWidget,
    );
    expect(find.text('Не прочитано'), findsOneWidget);
    expect(
      find.text('Укажите дату, чтобы сохранить эту запись.'),
      findsOneWidget,
    );
    expect(find.text('Уже сохранено'), findsNWidgets(2));
    expect(find.text('Такая запись уже есть в истории.'), findsOneWidget);
    expect(find.text('У питомца уже есть этот номер.'), findsOneWidget);
    // The passport number differs from the saved one: replaced only when
    // switched on. The country and the date fill in empty fields.
    expect(find.text('Сохранено: RU0999'), findsOneWidget);
    expect(find.text('Заменить сохранённое'), findsOneWidget);
    expect(find.text('Сохранить фото как страницы паспорта'), findsOneWidget);
    expect(find.text('Сохранить выбранное (2)'), findsOneWidget);
    expect(find.text('Удалить скан'), findsOneWidget);
  });

  testWidgets('the scan, the wait and the editors fit in Russian', (
    tester,
  ) async {
    await open(tester, '/pets/p1/scan');
    expect(find.text('Скан страниц паспорта'), findsOneWidget);
    expect(find.text('Сканировать камерой'), findsOneWidget);
    expect(find.text('Выбрать из фото'), findsOneWidget);
    await tester.tap(find.text('Другой документ'));
    await tester.pumpAndSettle();
    expect(find.text('Скан документа ветеринара'), findsOneWidget);

    await open(tester, '/pets/p1/scans/scan-1');
    await tapVisible(tester, find.byTooltip('Изменить').first);
    expect(find.text('Изменить запись'), findsOneWidget);
    expect(find.text('Прочитано на странице 1'), findsOneWidget);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byTooltip('Изменить').last);
    expect(find.text('Изменить данные паспорта'), findsOneWidget);
    expect(
      find.text(
        'Пустое поле не меняет то, что уже сохранено, а изменённое здесь '
        'значение заменит сохранённое.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a note, its wait and its review fit in Russian and read '
      'naturally', (tester) async {
    const text =
        'Вчера сделали прививку от бешенства, Нобивак Рабиес; весит 4,2 кг. '
        'Позавчера обработали от блох каплями Стронгхолд.';
    ai.scans['note-1'] = testNote(
      'note-1',
      text: text,
      status: ScanStatus.ready,
      draft: ScanDraft(
        records: [
          DraftRecord(
            key: 0,
            kind: CareKind.vaccination,
            title: 'Вакцинация против бешенства',
            performedOn: DateTime(2025, 10, 6),
            product: 'Нобивак Рабиес',
            targets: const [VaccineTarget.rabies],
            evidence: 'Вчера сделали прививку от бешенства, Нобивак Рабиес',
            planId: 'plan-rabies',
          ),
        ],
        weights: [
          DraftWeight(
            key: 0,
            measuredOn: DateTime(2025, 10, 6),
            weightKg: 4.2,
            evidence: 'весит 4,2 кг',
          ),
          DraftWeight(
            key: 1,
            measuredOn: DateTime(2025, 10, 6),
            weightKg: 4.2,
            warnings: const [
              DraftWarning('measuredOn', DraftIssue.alreadySaved),
            ],
            selected: false,
          ),
          DraftWeight(
            key: 2,
            measuredOn: DateTime(2025, 10, 5),
            evidence: 'взвесили',
            warnings: const [DraftWarning('weightKg', DraftIssue.unreadable)],
            selected: false,
          ),
        ],
      ),
    );
    ai.scans['note-2'] = testNote('note-2', text: text);

    await open(tester, '/pets/p1/note');
    expect(find.text('Записать словами'), findsOneWidget);
    expect(find.text('Заметка'), findsOneWidget);
    expect(find.text('0/1000'), findsOneWidget);
    expect(find.text('Прочитать'), findsOneWidget);

    await open(tester, '/pets/p1/scans/note-1');
    expect(find.text('Проверка заметки'), findsOneWidget);
    expect(
      find.text(
        'AI прочитал эти записи из вашей заметки. Сверьте их с тем, что вы '
        'написали, исправьте ошибки и снимите отметку с того, что сохранять '
        'не нужно.',
      ),
      findsOneWidget,
    );
    expect(find.text('Взвешивания'), findsOneWidget);
    expect(find.text('Взвешивание'), findsNWidgets(3));
    expect(find.text('4,2 кг'), findsNWidgets(2));
    expect(find.text('Этот вес уже есть на вкладке «Вес».'), findsOneWidget);
    expect(find.text('В заметке этого нет. Укажите сами.'), findsOneWidget);
    expect(
      find.text('Укажите вес, чтобы сохранить эту запись.'),
      findsOneWidget,
    );
    expect(find.text('Из заметки'), findsNWidgets(3));
    expect(find.text('Ваша заметка'), findsOneWidget);
    expect(find.text('«$text»'), findsOneWidget);
    expect(find.text('Сохранить выбранное (2)'), findsOneWidget);
    expect(find.text('Удалить заметку'), findsOneWidget);

    // Last: the wait's spinner never settles.
    appRouter(tester).go('/pets/p1/scans/note-2');
    await pumpFrames(tester);
    expect(find.text('Читаем заметку…'), findsOneWidget);
    expect(find.text('Обычно это занимает 5–30 секунд.'), findsOneWidget);
    expect(find.text('«$text»'), findsOneWidget);
  });
}
