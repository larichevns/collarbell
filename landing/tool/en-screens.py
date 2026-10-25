"""Writes the English variant of the screen renderer for the landing page's screenshots.

    python3 landing/tool/en-screens.py mobile/test/landing_screens_test.dart <PNG output dir>
    cd mobile && flutter test --no-pub test/landing_screens_test.dart; rm test/landing_screens_test.dart
    sh landing/tool/make-assets.sh <Russian PNGs, e.g. the bridge's refs> <PNG output dir>

It reads design/figma-plugin/render_screens_test.dart.txt and changes the app's language to English, the
sample household to English names and notes, the output folder to <PNG output dir>, and keeps only the
screens the landing page uses. The test file is temporary: delete it after the run, it is not part of the
suite. Every replacement must match exactly once, so a changed renderer stops this script instead of
producing half-Russian screenshots.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "design" / "figma-plugin" / "render_screens_test.dart.txt"
DST = Path(sys.argv[1])
OUT_DIR = str(Path(sys.argv[2]).resolve())

# The renderer's Russian samples keep short words with the next one (tools/typograph.py); the replacements below
# are written with plain spaces, and the English copy needs no Russian typography.
text = SRC.read_text().replace("\u00a0", " ")


def sub(old, new, count=1):
    global text
    found = text.count(old)
    if found != count:
        raise SystemExit(f"expected {count} x {old!r}, found {found}")
    text = text.replace(old, new)


# Header and output folder.
sub("// TEMPORARY, not part of the suite: renders every screen to PNG files for a\n// designer's Figma mockups. Delete after use.",
    "// TEMPORARY, not part of the suite: renders the screens the landing page\n// shows, in English. Delete after use.")
sub("final outDir = '${Directory.current.path}/../design/figma-plugin/.refs';",
    f"const outDir = '{OUT_DIR}';")

# Household data in English.
sub("const clinic = 'Ветклиника «Айболит»';", "const clinic = 'Riverside Vet Clinic';")
sub("const vet = 'Иванова А. С.';", "const vet = 'Dr. Emma Clarke';")
sub("name: 'Мурка',", "name: 'Luna',")
sub("breed: 'Сибирская',", "breed: 'Siberian',")
sub("color: 'Рыжая с белым',", "color: 'Ginger and white',")
sub("markings: 'Белое пятно на груди',", "markings: 'White patch on the chest',")
sub("allergies: 'Курица',", "allergies: 'Chicken',")
sub("notes: 'Боится пылесоса. Любит спать на подоконнике.',",
    "notes: 'Afraid of the vacuum cleaner. Loves the windowsill.',")
sub("location: 'Холка, слева',", "location: 'Withers, left side',")
sub("name: 'Барсик',", "name: 'Milo',")
sub("breed: 'Мейн-кун',", "breed: 'Maine Coon',")
sub("color: 'Серый табби',", "color: 'Grey tabby',")
sub("name: 'Рекс',", "name: 'Rex',")
sub("breed: 'Немецкая овчарка',", "breed: 'German Shepherd',")
sub("color: 'Чепрачный',", "color: 'Black and tan',")

sub("title: 'Бешенство',", "title: 'Rabies',", 2)
sub("title: 'Осмотр у ветеринара',", "title: 'Vet check-up',", 2)
sub("title: 'Обработка от глистов',", "title: 'Deworming',", 4)
sub("title: 'Комплексная прививка',", "title: 'FVRCP vaccine',", 4)
sub("title: 'Блохи и клещи',", "title: 'Fleas and ticks',", 2)
sub("'Мильпразон'", "'Milprazon'", 2)
sub("'Мильбемакс'", "'Milbemax'", 3)
sub("notes: 'Перенесла хорошо, вечером была вялой.',",
    "notes: 'Took it well, a little sleepy in the evening.',")
sub("notes: 'Здорова. Через год проверить зубы.',",
    "notes: 'Healthy. Check her teeth in a year.',")

sub("notes: 'Вечером можно добавить ложку влажного корма.',",
    "notes: 'In the evening, a spoonful of wet food is fine.',")
sub("food: 'Felix, паштет с кроликом',", "food: 'Felix pâté with rabbit',")
sub("byName: 'Анна',", "byName: 'Anna',")
sub("title: 'Осмотр и прививка от бешенства',", "title: 'Check-up and rabies shot',", 2)
sub("location: '$clinic, ул. Лесная, 12',", "location: '$clinic, 12 Forest Road',", 2)
sub("notes: 'Взять ветпаспорт. Не кормить за 2 часа до приёма.',",
    "notes: 'Bring the pet passport. No food 2 hours before.',")
sub("title: 'Груминг',", "title: 'Grooming',")
sub("location: 'Салон «Пушистик», пр. Мира, 8',", "location: 'Fluffy Paws, 8 Park Lane',")
sub("notes: 'Брать большую упаковку, 4 кг, если есть скидка.',",
    "notes: 'Take the big 4 kg bag when it is on sale.',")
sub("petName: 'Барсик',", "petName: 'Milo',")
sub("petName: 'Мурка',", "petName: 'Luna',")
sub("name: 'Древесный наполнитель',", "name: 'Wood pellet litter',")
sub("byName: 'Сергей',", "byName: 'Sam',")
sub("title: 'Общий анализ крови',", "title: 'Complete blood count',")
sub("notes: 'Все показатели в норме. Лаборатория «Вет Юнион».',",
    "notes: 'All values normal. Vet Union lab.',")

sub("number: 'RU0123456',", "number: 'GB0123456',")
sub("issuingCountry: 'RU',", "issuingCountry: 'GB',")
sub("name: 'Иванова Анна Сергеевна',", "name: 'Dr. Emma Clarke',")
sub("address: 'Москва, ул. Лесная, 12',", "address: '12 Forest Road, London',")
sub("phone: '+7 495 123-45-67',", "phone: '+44 20 7946 0123',")
sub("name: 'Анна Смирнова',", "name: 'Anna Smith',")
sub("address: 'Москва, ул. Садовая, 5, кв. 17',", "address: 'Flat 17, 5 Garden Street, London',")
sub("phone: '+7 916 555-12-34',", "phone: '+44 7700 900123',")
sub("'anna.smirnova@example.com'", "'anna.smith@example.com'", 2)

sub("'Барсик, Мурка, Рекс'", "'Milo, Luna, Rex'", 2)
sub("'Осмотр и прививка от бешенства',\n      at(1, 8, 30),", "'Check-up and rabies shot',\n      at(1, 8, 30),")
sub("'Барсик: Комплексная прививка'", "'Milo: FVRCP vaccine'")
sub("'Мурка: Бешенство'", "'Luna: Rabies'")
sub("      'Мурка',\n      at(-1, 19, 0),", "      'Luna',\n      at(-1, 19, 0),")

# The app in English.
sub("/// The whole app in Russian on a 390×844 phone", "/// The whole app in English on a 390×844 phone")
sub("'settings.language': 'ru',", "'settings.language': 'en',")
sub("deviceTimeZoneProvider.overrideWithValue(() async => 'Europe/Moscow'),",
    "deviceTimeZoneProvider.overrideWithValue(() async => 'Europe/London'),")

# Only the screens the landing page uses: cut every test, then add our own.
start = text.index("  // 1. Sign in and sign up.")
end = text.rindex("}")
tests = """  screenTest('02 today', (tester) async {
    await openApp(tester, World(), location: AppRoutes.today);
    await shot(tester, '02_today_with_data');
  });

  screenTest('03 pets', (tester) async {
    await openApp(tester, World(), location: AppRoutes.pets);
    await shot(tester, '03_pets_list');
  });

  for (final tab in PetTab.values) {
    if (tab == PetTab.documents) continue;
    screenTest('04 pet ${tab.name}', (tester) async {
      await openApp(
        tester,
        World(),
        location: AppRoutes.pet('murka', tab: tab),
      );
      await shot(tester, '04_pet_${tab.index + 1}_${tab.name}');
    });
  }

  screenTest('09 visits list', (tester) async {
    await openApp(tester, World(), location: AppRoutes.visits);
    await shot(tester, '09_visits_list');
  });

  screenTest('10 feeding form, new', (tester) async {
    await openApp(tester, World(), location: AppRoutes.newFeeding('barsik'));
    await shot(tester, '10_feeding_form_new');
  });

  screenTest('11 supplies list', (tester) async {
    await openApp(tester, World(), location: AppRoutes.supplies);
    await shot(tester, '11_supplies_list');
  });

  screenTest('11 supply detail', (tester) async {
    await openApp(tester, World(), location: AppRoutes.supply('s-rc'));
    await shot(tester, '11_supplies_detail');
  });

  screenTest('11 product scan: photos of the package', (tester) async {
    final world = World();
    world.picker.camera.add(
      const PickedMedia(path: '/tmp/package-front.jpg', name: 'front.jpg'),
    );
    await openApp(tester, world, location: AppRoutes.supplies);
    appRouter(tester).push(AppRoutes.supplyScan(photos: true));
    await tester.pumpAndSettle();
    await shot(tester, '11_supplies_scan_photos');
  });

  screenTest('12 ai', (tester) async {
    await openApp(tester, World(), location: AppRoutes.ai);
    await shot(tester, '12_more_ai');
  });
"""
text = text[:start] + tests + text[end:]

leftover = re.findall(r"[А-Яа-яЁё][^'\n]*", text[: text.index("Future<void> drawPictures()")])
DST.write_text(text)
print("written", DST)
print("Cyrillic left before drawPictures:", leftover)
