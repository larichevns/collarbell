// The care screens in Russian, for a look on a small phone (iPhone SE): the
// test fills a cat's plans and records through the app's repositories,
// opens each screen and takes a screenshot. Run it on a small simulator:
//
//   cd mobile && flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/care_ru_test.dart -d <small simulator> \
//     --dart-define=CB_API_BASE_URL=http://localhost:5080
//
// Screenshots are written to build/screenshots/ (6x-ru-*.png, 7x-ru-*.png).
import 'package:collarbell/app/app.dart';
import 'package:collarbell/app/app_settings.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/care_refresh.dart';
import 'package:collarbell/features/care/care_repository.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/main.dart' as app;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'helpers.dart';

/// Its own developer account, so cleaning up never touches other pets.
const testEmail = 'e2e-care-ru@collarbell.local';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the care screens in Russian', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final previousEmail = prefs.getString(DevAuthRepository.lastEmailKey);
    final previousLanguage = prefs.getString(AppSettingsNotifier.languageKey);
    await DevAuthRepository(prefs).signOut();
    await skipOnboarding(prefs, testEmail);
    await prefs.setString(AppSettingsNotifier.languageKey, 'ru');

    await app.runCollarbell(
      overrides: [
        pushPlatformProvider.overrideWithValue(const DisabledPushPlatform()),
      ],
    );

    try {
      final continueAsDeveloper = find.text('Продолжить как разработчик');
      await pumpUntil(tester, continueAsDeveloper);
      await tester.enterText(field('Почта разработчика'), testEmail);
      await hideKeyboard(tester);
      await tester.tap(continueAsDeveloper);
      await pumpUntil(tester, find.text('Сегодня'));
      await deleteAllPets(tester);

      // A cat with plans in every state and some history.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CollarbellApp)),
      );
      final care = container.read(careRepositoryProvider);
      final pet = await container
          .read(petsRepositoryProvider)
          .createPet(
            const PetInput(
              name: 'Мурка',
              species: PetSpecies.cat,
              sex: PetSex.female,
            ),
          );
      final now = DateTime.now();
      DateTime day(int offset) =>
          DateTime(now.year, now.month, now.day + offset);
      await care.createPlan(
        pet.id,
        CarePlanInput(
          kind: CareKind.vaccination,
          title: 'Бешенство',
          interval: const CareInterval(1, IntervalUnit.year),
          nextDueOn: day(-3),
          targets: const [VaccineTarget.rabies],
          presetCode: 'cat-rabies',
        ),
        requestId: const Uuid().v4(),
      );
      final deworming = await care.createPlan(
        pet.id,
        CarePlanInput(
          kind: CareKind.deworming,
          title: 'Обработка от глистов',
          interval: const CareInterval(3, IntervalUnit.month),
          nextDueOn: day(5),
          defaultProduct: 'Мильбемакс',
          presetCode: 'cat-deworm',
        ),
        requestId: const Uuid().v4(),
      );
      await care.createPlan(
        pet.id,
        CarePlanInput(
          kind: CareKind.fleaTick,
          title: 'Блохи и клещи, раз в месяц',
          interval: const CareInterval(1, IntervalUnit.month),
          nextDueOn: day(20),
        ),
        requestId: const Uuid().v4(),
      );
      final exam = await care.createPlan(
        pet.id,
        CarePlanInput(
          kind: CareKind.vetExam,
          title: 'Осмотр перед поездкой',
          nextDueOn: day(-10),
        ),
        requestId: const Uuid().v4(),
      );
      await care.completePlan(
        exam.id,
        CompletionInput(performedOn: day(-9)),
        requestId: const Uuid().v4(),
      );
      await care.createRecord(
        pet.id,
        CareRecordInput(
          kind: CareKind.vaccination,
          title: 'Бешенство',
          performedOn: day(-360),
          product: 'Нобивак Рабиес',
          manufacturer: 'MSD',
          batchNumber: 'A123456',
          validFrom: day(-339),
          validUntil: day(-3),
          targets: const [VaccineTarget.rabies],
        ),
        requestId: const Uuid().v4(),
      );
      await care.createRecord(
        pet.id,
        CareRecordInput(
          kind: CareKind.rabiesTiter,
          title: 'Тест на антитела к бешенству',
          performedOn: day(-300),
          details: const CareRecordDetails(
            laboratory: 'BioLab',
            titerIuPerMl: 2.5,
          ),
        ),
        requestId: const Uuid().v4(),
      );
      refreshCare(container, pet.id);
      final router = container.read(routerProvider);

      router.go('/today');
      await pumpUntil(tester, find.text('Мурка'));
      await settle(tester);
      await binding.takeScreenshot('60-ru-today');

      router.go('/pets/${pet.id}?tab=health');
      await pumpUntil(tester, find.text('План ухода'));
      await pumpUntil(tester, find.text('Скоро'));
      await settle(tester);
      await binding.takeScreenshot('61-ru-health');

      final inactive = find.text('Завершённые и на паузе (1)');
      await scrollTo(tester, inactive, scrollable: scrollableIn(HealthTab));
      await tester.tap(inactive);
      await settle(tester);
      await binding.takeScreenshot('62-ru-health-finished');
      await scrollTo(
        tester,
        find.text('Все'),
        scrollable: scrollableIn(HealthTab),
      );
      await binding.takeScreenshot('63-ru-health-history');

      router.go('/pets/${pet.id}/plans/presets');
      await pumpUntil(tester, find.text('Свой план'));
      await settle(tester);
      await binding.takeScreenshot('64-ru-presets');

      router.go('/pets/${pet.id}/plans/new?preset=cat-deworm');
      await pumpUntil(tester, find.text('Новый план'));
      await settle(tester);
      await binding.takeScreenshot('65-ru-plan-form');

      router.go('/pets/${pet.id}/plans/${deworming.id}/done');
      await pumpUntil(tester, find.text('Отметить выполнение'));
      await settle(tester);
      await binding.takeScreenshot('66-ru-done');
      await tester.ensureVisible(find.text('Следующий раз'));
      await settle(tester);
      await binding.takeScreenshot('67-ru-done-next');

      router.go('/pets/${pet.id}/records/new?kind=vaccination&target=rabies');
      await pumpUntil(tester, find.text('Новая запись'));
      await settle(tester);
      await binding.takeScreenshot('68-ru-record-form');

      router.go('/pets/${pet.id}?tab=passport');
      await pumpUntil(tester, find.byType(PassportTab));
      // Let the record form finish closing before scrolling.
      await settle(tester);
      await scrollTo(
        tester,
        find.text('V. Вакцинация против бешенства'),
        scrollable: scrollableIn(PassportTab),
      );
      await pumpUntil(tester, find.textContaining('Нобивак Рабиес'));
      await settle(tester);
      await binding.takeScreenshot('69-ru-passport');
      await scrollTo(
        tester,
        find.text('X. Клинический осмотр'),
        scrollable: scrollableIn(PassportTab),
      );
      await binding.takeScreenshot('70-ru-passport-more');
    } finally {
      // Leave the device as it was: no test pets, signed out, the previous
      // language and developer email.
      if (find.byType(CollarbellApp).evaluate().isNotEmpty) {
        await deleteAllPets(tester);
      }
      await DevAuthRepository(prefs).signOut();
      if (previousLanguage == null) {
        await prefs.remove(AppSettingsNotifier.languageKey);
      } else {
        await prefs.setString(
          AppSettingsNotifier.languageKey,
          previousLanguage,
        );
      }
      if (previousEmail == null) {
        await prefs.remove(DevAuthRepository.lastEmailKey);
      } else {
        await prefs.setString(DevAuthRepository.lastEmailKey, previousEmail);
      }
    }
  });
}
