// The demo's world (npm run dev:mock): a household with a cat and a dog, as lived in for a few years, in English or
// in Russian. Plans due, overdue and paused; a history of vaccinations, treatments, an antibody test and check-ups
// (one record with a sticker's photo); a passport with its pages; documents with image pages and a PDF; feeding
// schedules (one paused) fed from supplies; supplies in every state (to buy, ran out, running out soon, in stock,
// without a count or a daily use, no longer bought) with their purchases and counts; weighings and a vet's weights;
// visits; the household's people (a member, a sitter who helps) and an open invite; and a second household, on
// Premium, where the person only helps, with a third one's code to join (DEMO_IDS.CODE). The cat has a scan of three
// passport pages ready to check, with every kind of entry (records, weighings, microchips, the passport's details) and
// every doubt AI has (a date it couldn't read, day and month that could be swapped, a date in the future, protection
// that ends before it starts, a number that doesn't look right, already saved, the same on two photos, different from
// what is saved), and a note AI couldn't read (its "Try again" reads it). New scans and notes are read in a few
// seconds; a chip's photo gives two numbers to choose from. Dates count from today; everything is made up.
import type { Coat, Pet, Species } from '../api/types';
import type { Lang } from '../i18n/lang';
import { addDays, addInterval, daysBetween, todayIn } from '../lib/dates';
import { draft, draftIdentifier, draftPassport, draftRecord, draftWeight, chipReading } from '../test/ai';
import { PRESETS } from '../test/presets';
import {
  aiStatus,
  aiWorld,
  document,
  emptyHousehold,
  freePlan,
  invite,
  markKey,
  newId,
  person,
  pet,
  plan,
  record,
  routine,
  stockEntry,
  storedFile,
  supply,
  visit,
  weighing,
  type World,
} from '../test/server';
import { catPhoto, dogPhoto, formPage, labPage, passportCover, pdfFile, stickerPhoto } from './images';

const HOME = '0d9a3c1e-0000-4000-8000-00000000a001';
const OFFICE = '0d9a3c1e-0000-4000-8000-00000000a002';
const CAT = '0d9a3c1e-0000-4000-8000-00000000c001';
const DOG = '0d9a3c1e-0000-4000-8000-00000000c002';
const OFFICE_CAT = '0d9a3c1e-0000-4000-8000-00000000c003';
const NEIGHBOURS = '0d9a3c1e-0000-4000-8000-00000000a003';
/** The code of an invite to the neighbours' household, to try "Join with a code". */
const CODE = 'NBRS-2345';

/** The demo's households, pets and a code to join, for a look at a page by its address. */
export const DEMO_IDS = { HOME, OFFICE, CAT, DOG, OFFICE_CAT, NEIGHBOURS, CODE } as const;

/** The words of the demo in each language. */
const WORDS = {
  en: {
    me: { name: 'Alex Morgan', email: 'alex.morgan@example.com' },
    someoneElse: 'Sam',
    office: 'Office',
    cat: { name: 'Murka', breed: 'British Shorthair', color: 'Blue', markings: 'White patch under the chin' },
    dog: { name: 'Rex', breed: 'Labrador Retriever', color: 'Yellow', markings: null },
    officeCat: 'Barsik',
    allergies: 'Chicken',
    vet: 'Dr. Anna Weber',
    clinic: 'Park Vet Clinic',
    labName: 'VetLab Berlin',
    groomer: 'Happy Paws',
    titles: {
      rabies: 'Rabies',
      fvrcp: 'FVRCP (panleukopenia, herpes, calici)',
      deworm: 'Deworming',
      fleas: 'Fleas and ticks',
      exam: 'Check-up',
      dhpp: 'DHPP (distemper, hepatitis, parvo, parainfluenza)',
      nexgard: 'NexGard',
      tapeworm: 'Tapeworm treatment before travel',
      titer: 'Rabies antibody test',
      dental: 'Dental cleaning',
    },
    notes: {
      exam: 'Healthy, teeth fine. Keep the weight where it is.',
      titer: 'Result fine for travel to the EU.',
      tapeworm: 'Before the trip to Norway.',
      treats: 'Only at the weekend',
      fleas: 'Back on in spring.',
    },
    visits: { vet: 'Yearly check-up', groomer: 'Grooming', past: 'Rabies vaccination' },
    passportNumber: 'DE0123456789',
    country: 'DE',
    issuer: {
      name: 'Dr. Anna Weber',
      address: 'Park Vet Clinic, Parkstraße 12, 10115 Berlin',
      phone: '+49 30 1234567',
    },
    owners: [{ name: 'Alex Morgan', address: 'Lindenallee 5, 10115 Berlin', phone: '+49 151 2345678' }],
    pages: {
      identity: 'II. Description of the animal',
      rabies: 'V. Vaccination against rabies',
      rows: {
        name: 'Name',
        species: 'Species',
        breed: 'Breed',
        sex: 'Sex',
        born: 'Date of birth',
        color: 'Colour',
        chip: 'Transponder code',
        product: 'Manufacturer and name of vaccine',
        batch: 'Batch number',
        valid: 'Valid from – until',
      },
      species: 'Felis catus',
      sex: 'F',
    },
    lab: { title: 'Blood test', header: ['Test', 'Result', 'Range'], page2: 'Biochemistry' },
    certificate: 'Vaccination certificate',
    documents: {
      blood: 'Blood test',
      certificate: 'Rabies certificate',
      invoice: 'Clinic invoice',
      insurance: 'Pet insurance policy',
      prescription: 'Ear drops',
    },
    supplies: {
      cat: 'Royal Canin Sterilised 37',
      dog: 'Acana Adult Dog',
      treats: 'Dreamies treats',
      litter: 'Clumping litter',
      bags: 'Poop bags',
      shampoo: 'Oatmeal shampoo',
      kittenFood: "Hill's Science Plan Kitten",
      drops: 'Otomax ear drops',
      litterNote: 'The big bag from the pet shop on the corner',
      dropsNote: 'Two drops in each ear, morning and evening',
    },
    weightNotes: ['Before breakfast', 'After the holidays'],
    scan: {
      treatments: 'VIII. Anti-parasite treatment',
      exam: 'X. Clinical examination',
      date: 'Date',
      weight: 'Weight',
      vet: 'Vet',
      note: 'Yesterday the rabies shot at the clinic, Nobivac; she weighs 4.4 kg.',
    },
    sitter: 'Kate (pet sitter)',
    colleague: 'Daniel',
    neighbours: 'Neighbours',
    neighbour: 'Olivia',
    neighboursCat: 'Felix',
  },
  ru: {
    me: { name: 'Анна Иванова', email: 'anna.ivanova@example.com' },
    someoneElse: 'Миша',
    office: 'Офис',
    cat: {
      name: 'Мурка',
      breed: 'Британская короткошёрстная',
      color: 'Голубой',
      markings: 'Белое пятно под подбородком',
    },
    dog: { name: 'Рекс', breed: 'Лабрадор-ретривер', color: 'Палевый', markings: null },
    officeCat: 'Барсик',
    allergies: 'Курица',
    vet: 'Петрова Е. А.',
    clinic: 'Ветклиника «Айболит»',
    labName: 'Лаборатория «ВетЛаб»',
    groomer: 'Салон «Лапки»',
    titles: {
      rabies: 'Бешенство',
      fvrcp: 'Комплексная прививка (панлейкопения, герпес, калицивироз)',
      deworm: 'Обработка от глистов',
      fleas: 'Блохи и клещи',
      exam: 'Осмотр',
      dhpp: 'Комплексная прививка (чума, гепатит, парвовироз, парагрипп)',
      nexgard: 'NexGard',
      tapeworm: 'Обработка от ленточных глистов перед поездкой',
      titer: 'Тест на антитела к бешенству',
      dental: 'Чистка зубов',
    },
    notes: {
      exam: 'Здорова, зубы в порядке. Вес держать на этом уровне.',
      titer: 'Результат подходит для поездок в ЕС.',
      tapeworm: 'Перед поездкой в Норвегию.',
      treats: 'Только по выходным',
      fleas: 'Включить весной.',
    },
    visits: { vet: 'Ежегодный осмотр', groomer: 'Груминг', past: 'Прививка от бешенства' },
    passportNumber: 'RU0123456',
    country: 'RU',
    issuer: {
      name: 'Петрова Елена Андреевна',
      address: 'Ветклиника «Айболит», ул. Ленина, 1, Москва',
      phone: '+7 495 123-45-67',
    },
    owners: [{ name: 'Анна Иванова', address: 'Москва, ул. Садовая, 10, кв. 5', phone: '+7 916 123-45-67' }],
    pages: {
      identity: 'II. Описание животного',
      rabies: 'V. Вакцинация против бешенства',
      rows: {
        name: 'Кличка',
        species: 'Вид',
        breed: 'Порода',
        sex: 'Пол',
        born: 'Дата рождения',
        color: 'Окрас',
        chip: 'Номер транспондера',
        product: 'Производитель и название вакцины',
        batch: 'Номер серии',
        valid: 'Действует с – по',
      },
      species: 'Felis catus',
      sex: 'Ж',
    },
    lab: { title: 'Анализ крови', header: ['Показатель', 'Результат', 'Норма'], page2: 'Биохимия' },
    certificate: 'Сертификат о вакцинации',
    documents: {
      blood: 'Анализ крови',
      certificate: 'Сертификат о прививке от бешенства',
      invoice: 'Счёт клиники',
      insurance: 'Полис страхования',
      prescription: 'Капли в уши',
    },
    supplies: {
      cat: 'Royal Canin Sterilised 37',
      dog: 'Acana Adult Dog',
      treats: 'Лакомство Dreamies',
      litter: 'Комкующийся наполнитель',
      bags: 'Пакеты для прогулок',
      shampoo: 'Овсяный шампунь',
      kittenFood: "Hill's Science Plan Kitten",
      drops: 'Капли в уши Otomax',
      litterNote: 'Большой мешок из зоомагазина на углу',
      dropsNote: 'По две капли в каждое ухо утром и вечером',
    },
    weightNotes: ['До завтрака', 'После праздников'],
    scan: {
      treatments: 'VIII. Обработка от паразитов',
      exam: 'X. Клинический осмотр',
      date: 'Дата',
      weight: 'Вес',
      vet: 'Ветеринар',
      note: 'Вчера в клинике прививка от бешенства, Нобивак; весит 4,4 кг.',
    },
    sitter: 'Катя (ситтер)',
    colleague: 'Дмитрий',
    neighbours: 'Соседи',
    neighbour: 'Ольга',
    neighboursCat: 'Феликс',
  },
} as const;

/** The browser's time zone: the demo's dates are its days. */
function zone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'Europe/Berlin';
  } catch {
    return 'Europe/Berlin';
  }
}

export function createDemoWorld(lang: Lang): World {
  const words = WORDS[lang];
  const timeZone = zone();
  const today = todayIn(timeZone);
  const day = (days: number) => addDays(today, days);
  const years = (count: number, days = 0) => addDays(addInterval(today, -count, 'Year'), days);
  const world: World = {
    today,
    households: new Map(),
    memberships: [HOME, OFFICE],
    locale: lang,
    me: { name: words.me.name, email: words.me.email, timeZone },
    presets: PRESETS,
    files: new Map(),
    requestIds: new Map(),
    // What "Find" knows beyond the household's items: Open Pet Food Facts' details, and a name from UPCitemdb.
    products: new Map([
      [
        '5901234123457',
        {
          source: 'OpenPetFoodFacts',
          product: {
            name: 'Purina One Sterilcat',
            brand: 'Purina',
            category: 'DryFood',
            unit: 'Gram',
            packageSize: 1500,
            kcalPerKg: 3800,
          },
        },
      ],
      [
        '4006381333931',
        {
          source: 'UpcItemDb',
          product: {
            name: 'Whiskas',
            brand: 'Whiskas',
            category: null,
            unit: null,
            packageSize: null,
            kcalPerKg: null,
          },
        },
      ],
    ]),
    ai: aiStatus(),
    exports: [],
    ...aiWorld(),
  };
  const file = (url: string, contentType = 'image/jpeg') => storedFile(world, newId(), url, contentType, url);
  const pdf = (lines: readonly string[]) => {
    const made = pdfFile(lines);
    const id = storedFile(world, newId(), made.url, 'application/pdf', null);
    world.files.get(id)!.sizeBytes = made.size;
    return id;
  };

  const home = emptyHousehold({ id: HOME, name: 'Home', role: 'Owner', timeZone, memberCount: 3 });
  home.joinedAt = `${years(4)}T10:00:00Z`;
  home.others = [
    { ...person('demo-sam', words.someoneElse, 'sam@example.com', 'Member'), joinedAt: `${years(3)}T18:00:00Z` },
    { ...person('demo-kate', words.sitter, 'kate@example.com', 'Helper'), joinedAt: `${day(-20)}T12:00:00Z` },
  ];
  home.invites = [invite(newId(), 'HKQM-7RTW', 'Helper')];
  home.plan = freePlan({ aiPhotosUsed: 7 });
  const catBorn = years(4, -95);
  const dogBorn = years(3, -40);
  const photoOf = (url: string) => {
    const id = file(url);
    return world.files.get(id)!;
  };
  const avatar = (url: string): Pet['photo'] => {
    const stored = photoOf(url);
    return {
      id: stored.id,
      contentType: 'image/jpeg',
      sizeBytes: stored.sizeBytes,
      width: 400,
      height: 400,
      url: stored.url,
      thumbnailUrl: stored.url,
      expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
    };
  };
  const animal = (
    id: string,
    who: (typeof words)['cat'] | (typeof words)['dog'],
    species: Species,
    coat: Coat,
    born: string,
    change: Partial<Pet>,
  ) =>
    pet(id, who.name, {
      species,
      breed: who.breed,
      color: who.color,
      markings: who.markings,
      coat,
      birthDate: born,
      ...change,
    });
  home.pets = [
    animal(CAT, words.cat, 'Cat', 'Smoke', catBorn, {
      sex: 'Female',
      neutered: true,
      neuteredOn: addDays(catBorn, 200),
      allergies: words.allergies,
      photo: avatar(catPhoto()),
      identifiers: [
        {
          id: newId(),
          type: 'IsoChip',
          code: '276098100345678',
          rawCode: '276 098 100 345 678',
          appliedOn: addDays(catBorn, 90),
          readOn: null,
          location: lang === 'ru' ? 'Левая сторона шеи' : 'Left side of the neck',
        },
      ],
    }),
    animal(DOG, words.dog, 'Dog', 'Fawn', dogBorn, {
      sex: 'Male',
      neutered: false,
      photo: avatar(dogPhoto()),
      identifiers: [
        {
          id: newId(),
          type: 'IsoChip',
          code: '643094100777123',
          rawCode: '643 094 100 777 123',
          appliedOn: addDays(dogBorn, 70),
          readOn: null,
          location: null,
        },
      ],
    }),
  ];

  // --- Plans ---
  const titles = words.titles;
  home.plans = [
    plan(newId(), CAT, today, {
      kind: 'Vaccination',
      title: titles.rabies,
      daysLeft: 9,
      defaultProduct: 'Nobivac Rabies',
      targets: ['Rabies'],
      presetCode: 'cat-rabies',
      lastDoneOn: years(1, 9),
    }),
    plan(newId(), CAT, today, {
      kind: 'Vaccination',
      title: titles.fvrcp,
      daysLeft: 150,
      defaultProduct: 'Purevax RCP',
      targets: ['Fpv', 'Fhv1', 'Fcv'],
      presetCode: 'cat-fvrcp',
      lastDoneOn: day(-215),
    }),
    plan(newId(), CAT, today, {
      kind: 'Deworming',
      title: titles.deworm,
      daysLeft: -4,
      intervalValue: 6,
      intervalUnit: 'Month',
      defaultProduct: 'Milbemax',
      presetCode: 'cat-deworm-indoor',
      lastDoneOn: day(-188),
    }),
    plan(newId(), CAT, today, {
      kind: 'FleaTick',
      title: titles.fleas,
      daysLeft: 20,
      intervalUnit: 'Month',
      defaultProduct: 'Frontline Combo',
      presetCode: 'cat-fleatick-monthly',
      notes: words.notes.fleas,
      active: false,
    }),
    plan(newId(), CAT, today, { kind: 'VetExam', title: titles.exam, daysLeft: 63, presetCode: 'cat-exam' }),
    plan(newId(), DOG, today, {
      kind: 'Vaccination',
      title: titles.dhpp,
      daysLeft: 420,
      intervalValue: 3,
      defaultProduct: 'Nobivac DHPPi',
      targets: ['Cdv', 'Cav2', 'Cpv2', 'Cpiv'],
      presetCode: 'dog-dhpp',
    }),
    plan(newId(), DOG, today, {
      kind: 'Vaccination',
      title: titles.rabies,
      daysLeft: 95,
      defaultProduct: 'Rabisin',
      targets: ['Rabies'],
      presetCode: 'dog-rabies',
    }),
    plan(newId(), DOG, today, {
      kind: 'Deworming',
      title: titles.deworm,
      daysLeft: 12,
      intervalUnit: 'Month',
      defaultProduct: 'Drontal Plus',
      presetCode: 'dog-deworm-high',
    }),
    plan(newId(), DOG, today, {
      kind: 'FleaTick',
      title: titles.nexgard,
      daysLeft: 0,
      intervalUnit: 'Month',
      defaultProduct: 'NexGard',
      presetCode: 'dog-fleatick-monthly',
    }),
    plan(newId(), DOG, today, {
      kind: 'Echinococcus',
      title: titles.tapeworm,
      daysLeft: 25,
      intervalValue: null,
      intervalUnit: null,
      presetCode: 'dog-echinococcus',
      notes: words.notes.tapeworm,
    }),
  ];

  // --- History ---
  const vet = { clinic: words.clinic, veterinarian: words.vet };
  const sticker = file(stickerPhoto('Nobivac Rabies', 'A2391C', '11/2027'));
  for (const [index, ago] of [3, 2, 1].entries()) {
    const on = years(ago, 9);
    home.records.push(
      record(newId(), CAT, {
        kind: 'Vaccination',
        title: titles.rabies,
        performedOn: on,
        product: 'Nobivac Rabies',
        manufacturer: 'MSD Animal Health',
        batchNumber: ['A1187B', 'A1764D', 'A2391C'][index]!,
        validFrom: addDays(on, 21),
        validUntil: addInterval(on, 1, 'Year'),
        targets: ['Rabies'],
        files: ago === 1 ? [sticker] : [],
        ...vet,
      }),
    );
  }
  home.records.push(
    record(newId(), CAT, {
      kind: 'Vaccination',
      title: titles.fvrcp,
      performedOn: day(-215),
      product: 'Purevax RCP',
      batchNumber: 'L45521',
      validUntil: day(150),
      targets: ['Fpv', 'Fhv1', 'Fcv'],
      ...vet,
    }),
    record(newId(), CAT, {
      kind: 'RabiesTiter',
      title: titles.titer,
      performedOn: years(2, -30),
      clinic: words.clinic,
      details: { laboratory: words.labName, reportNumber: 'FAVN-2291', titerIuPerMl: 2.3, fitForTravel: null },
      notes: words.notes.titer,
    }),
    ...[188, 370, 550].map((ago) =>
      record(newId(), CAT, { kind: 'Deworming', title: titles.deworm, performedOn: day(-ago), product: 'Milbemax' }),
    ),
    record(newId(), CAT, {
      kind: 'VetExam',
      title: titles.exam,
      performedOn: day(-302),
      weightKg: 4.6,
      details: { laboratory: null, reportNumber: null, titerIuPerMl: null, fitForTravel: true },
      notes: words.notes.exam,
      ...vet,
    }),
    record(newId(), CAT, {
      kind: 'VetExam',
      title: titles.exam,
      performedOn: day(-665),
      weightKg: 4.35,
      ...vet,
    }),
    record(newId(), CAT, { kind: 'Dental', title: titles.dental, performedOn: day(-420), ...vet }),
    record(newId(), DOG, {
      kind: 'Vaccination',
      title: titles.dhpp,
      performedOn: day(-675),
      product: 'Nobivac DHPPi',
      batchNumber: 'D20117',
      validUntil: day(420),
      targets: ['Cdv', 'Cav2', 'Cpv2', 'Cpiv'],
      ...vet,
    }),
    record(newId(), DOG, {
      kind: 'Vaccination',
      title: titles.rabies,
      performedOn: day(-270),
      product: 'Rabisin',
      manufacturer: 'Boehringer Ingelheim',
      batchNumber: 'R88341',
      validFrom: day(-249),
      validUntil: day(95),
      targets: ['Rabies'],
      ...vet,
    }),
    record(newId(), DOG, {
      kind: 'Echinococcus',
      title: titles.tapeworm,
      performedOn: day(-80),
      performedTime: '09:30:00',
      product: 'Drontal Plus',
      batchNumber: 'KP0042',
      ...vet,
    }),
    ...[18, 48, 79].map((ago) =>
      record(newId(), DOG, {
        kind: 'Deworming',
        title: titles.deworm,
        performedOn: day(-ago),
        product: 'Drontal Plus',
      }),
    ),
    record(newId(), DOG, {
      kind: 'VetExam',
      title: titles.exam,
      performedOn: day(-270),
      weightKg: 31.2,
      details: { laboratory: null, reportNumber: null, titerIuPerMl: null, fitForTravel: true },
      ...vet,
    }),
  );

  // --- The passport and documents ---
  home.passports.set(CAT, {
    petId: CAT,
    model: 'Eu2014',
    passportNumber: words.passportNumber,
    issuingCountry: words.country,
    issuedOn: addDays(catBorn, 95),
    issuer: { ...words.issuer, email: null },
    owners: words.owners.map((owner) => ({ ...owner, email: words.me.email })),
    notes: null,
    updatedAt: new Date().toISOString(),
  });
  const rows = words.pages.rows;
  const lastRabies = home.records.filter((item) => item.petId === CAT && item.targets.includes('Rabies')).at(-1)!;
  home.documents.push(
    document(newId(), CAT, {
      type: 'PassportPage',
      createdAt: `${addDays(catBorn, 100)}T10:00:00Z`,
      pages: [
        file(passportCover(lang)),
        file(
          formPage(words.pages.identity, [
            [rows.name, words.cat.name],
            [rows.species, words.pages.species],
            [rows.breed, words.cat.breed],
            [rows.sex, words.pages.sex],
            [rows.born, catBorn.split('-').reverse().join('.')],
            [rows.color, words.cat.color],
            [rows.chip, '276098100345678'],
          ]),
        ),
        file(
          formPage(
            words.pages.rabies,
            [
              [rows.product, 'MSD · Nobivac Rabies'],
              [rows.batch, lastRabies.batchNumber ?? ''],
              [
                rows.valid,
                `${(lastRabies.validFrom ?? '').split('-').reverse().join('.')} – ${(lastRabies.validUntil ?? '').split('-').reverse().join('.')}`,
              ],
            ],
            words.clinic.replace(/[«»]/g, ''),
          ),
        ),
      ],
    }),
    document(newId(), CAT, {
      type: 'LabResult',
      title: words.documents.blood,
      documentDate: day(-302),
      createdAt: `${day(-301)}T15:20:00Z`,
      pages: [
        file(
          labPage(words.lab.title, words.lab.header, [
            ['WBC', '8.4', '5.5–19.5'],
            ['RBC', '8.9', '5.0–10.0'],
            ['HGB', '13.1', '9.3–15.9'],
            ['PLT', '310', '175–600'],
          ]),
        ),
        file(
          labPage(words.lab.page2, words.lab.header, [
            ['ALT', '48', '12–130'],
            ['CREA', '1.4', '0.8–2.4'],
            ['GLU', '102', '74–159'],
          ]),
        ),
      ],
    }),
    document(newId(), CAT, {
      type: 'VaccinationCertificate',
      title: words.documents.certificate,
      documentDate: lastRabies.performedOn,
      createdAt: `${lastRabies.performedOn}T12:00:00Z`,
      pages: [
        file(
          formPage(
            words.certificate,
            [
              [rows.name, words.cat.name],
              [rows.product, 'Nobivac Rabies'],
              [rows.batch, lastRabies.batchNumber ?? ''],
            ],
            words.clinic.replace(/[«»]/g, ''),
          ),
        ),
      ],
    }),
    document(newId(), CAT, {
      type: 'Invoice',
      title: words.documents.invoice,
      documentDate: day(-302),
      createdAt: `${day(-302)}T16:00:00Z`,
      pages: [
        pdf([
          'INVOICE 2291',
          'Park Vet Clinic',
          `Date: ${day(-302)}`,
          'Clinical examination ........ 45.00',
          'Blood test (CBC, biochemistry) ........ 68.00',
          'Total ........ 113.00 EUR',
        ]),
      ],
    }),
    document(newId(), DOG, {
      type: 'Insurance',
      title: words.documents.insurance,
      documentDate: day(-200),
      createdAt: `${day(-200)}T09:00:00Z`,
      pages: [
        pdf(['PET INSURANCE POLICY', `Policy PX-55120`, `Valid from ${day(-200)}`, 'Accident and illness cover']),
      ],
    }),
    document(newId(), DOG, {
      type: 'Prescription',
      title: words.documents.prescription,
      documentDate: day(-33),
      createdAt: `${day(-33)}T11:00:00Z`,
      pages: [
        file(
          formPage(
            words.documents.prescription,
            [
              [rows.product, 'Otomax · 2×5'],
              [rows.valid, '7'],
            ],
            words.vet,
          ),
        ),
      ],
    }),
  );

  // --- Supplies and feeding ---
  // Every state of the list: the cat's food to buy (60 g a day, 160 g left), poop bags ran out, the dog's food runs
  // out within ten days (360 g a day), litter and ear drops in stock, treats without a daily use (their feeding is
  // paused), a shampoo nobody counted yet, and the kitten food no longer bought.
  const catFood = newId();
  const dogFood = newId();
  const treats = newId();
  const litter = newId();
  const bags = newId();
  const shampoo = newId();
  const kittenFood = newId();
  const drops = newId();
  const sam = { name: words.someoneElse, me: false };
  home.supplies = [
    supply(catFood, {
      name: words.supplies.cat,
      brand: 'Royal Canin',
      packageSize: 2000,
      kcalPerKg: 3930,
      barcode: '4600699503415',
      storeUrl: 'https://shop.example.com/royal-canin-sterilised-37',
    }),
    supply(dogFood, { name: words.supplies.dog, brand: 'Acana', packageSize: 6000, leadTimeDays: 7 }),
    supply(treats, { name: words.supplies.treats, category: 'Treats', unit: 'Piece', packageSize: 60 }),
    supply(litter, {
      name: words.supplies.litter,
      category: 'Litter',
      packageSize: 10_000,
      usageMode: 'Manual',
      manualDailyUsage: 333.333333,
      notes: words.supplies.litterNote,
    }),
    supply(bags, {
      name: words.supplies.bags,
      category: 'Other',
      unit: 'Piece',
      packageSize: 120,
      usageMode: 'Manual',
      manualDailyUsage: 4,
      leadTimeDays: 2,
    }),
    supply(shampoo, {
      name: words.supplies.shampoo,
      category: 'Other',
      unit: 'Milliliter',
      packageSize: 250,
      usageMode: 'Manual',
      manualDailyUsage: 250 / 60,
    }),
    supply(drops, {
      name: words.supplies.drops,
      brand: 'MSD',
      category: 'Medication',
      unit: 'Dose',
      packageSize: 40,
      usageMode: 'Manual',
      manualDailyUsage: 1,
      leadTimeDays: 3,
      notes: words.supplies.dropsNote,
    }),
    supply(kittenFood, {
      name: words.supplies.kittenFood,
      brand: "Hill's",
      packageSize: 1500,
      usageMode: 'Manual',
      manualDailyUsage: 50,
      active: false,
    }),
  ];
  home.stock = [
    stockEntry(catFood, 'Purchase', 2000, 31),
    stockEntry(catFood, 'Adjustment', 160, 0.1, sam),
    stockEntry(dogFood, 'Purchase', 6000, 20, sam),
    stockEntry(dogFood, 'Adjustment', 3420, 0.2),
    stockEntry(treats, 'Purchase', 60, 25),
    stockEntry(treats, 'Adjustment', 35, 3),
    stockEntry(litter, 'Purchase', 20_000, 6),
    stockEntry(bags, 'Purchase', 120, 40, sam),
    stockEntry(drops, 'Purchase', 40, 4),
    stockEntry(kittenFood, 'Purchase', 1500, 400),
  ];
  const catMorning = routine(newId(), CAT, {
    times: ['08:00:00', '19:00:00'],
    food: words.supplies.cat,
    amount: 30,
    unit: 'Gram',
    supplyItemId: catFood,
  });
  home.routines = [
    catMorning,
    routine(newId(), CAT, {
      times: ['12:00:00'],
      days: ['Saturday', 'Sunday'],
      food: words.supplies.treats,
      amount: 5,
      unit: 'Piece',
      supplyItemId: treats,
      notes: words.notes.treats,
      active: false,
    }),
    routine(newId(), DOG, {
      times: ['07:30:00', '18:30:00'],
      food: words.supplies.dog,
      amount: 180,
      unit: 'Gram',
      supplyItemId: dogFood,
    }),
  ];
  // Someone else fed the cat this morning.
  home.marks.set(`${catMorning.id}@${today}@08:00:00`, {
    id: newId(),
    routineId: catMorning.id,
    date: today,
    time: '08:00:00',
    status: 'Done',
    doneAt: new Date(Date.now() - 2 * 3_600_000).toISOString(),
    byName: words.someoneElse,
    byMe: false,
  });

  // --- Weights ---
  const catWeights = [4.12, 4.18, 4.25, 4.3, 4.41, 4.5, 4.62, 4.58, 4.55, 4.49, 4.52, 4.47, 4.44, 4.5, 4.46, 4.43, 4.4];
  catWeights.forEach((kg, index) => {
    home.weights.push(
      weighing(newId(), CAT, {
        measuredOn: day(-30 * (catWeights.length - index) + 12),
        weightKg: kg,
        bcs: index % 4 === 0 ? (kg > 4.5 ? 6 : 5) : null,
        bcsScale: index % 4 === 0 ? 9 : null,
        note: index === 7 ? words.weightNotes[1] : index === catWeights.length - 1 ? words.weightNotes[0] : null,
      }),
    );
  });
  const dogWeights = [27.8, 28.9, 29.6, 30.4, 30.9, 31.4, 31.0, 31.3];
  dogWeights.forEach((kg, index) => {
    home.weights.push(
      weighing(newId(), DOG, { measuredOn: day(-60 * (dogWeights.length - index) + 20), weightKg: kg }),
    );
  });

  // --- Visits ---
  home.visits = [
    visit(newId(), {
      type: 'Vet',
      title: words.visits.vet,
      date: day(-1),
      time: '17:30:00',
      petIds: [CAT],
      location: words.clinic,
    }),
    visit(newId(), {
      type: 'Grooming',
      title: words.visits.groomer,
      date: day(5),
      time: '11:00:00',
      petIds: [DOG],
      location: words.groomer,
    }),
    visit(newId(), {
      type: 'Vet',
      title: words.visits.past,
      date: lastRabies.performedOn,
      time: '10:00:00',
      petIds: [CAT],
      status: 'Done',
      location: words.clinic,
    }),
  ];

  // --- AI: a scan to check, a note that failed ---
  // AI reads new scans and notes in a few seconds, whenever they are asked about; a chip's photo has two numbers.
  world.readPolls = 0;
  world.readMs = 3500;
  world.chipReadings = [
    chipReading({ code: '276098100345678', rawCode: '276 098 100 345 678', location: words.cat.markings }),
    chipReading({ code: '276098100345687', rawCode: '276 098 100 345 687' }),
  ];
  const dotted = (iso: string) => iso.split('-').reverse().join('.');
  // A recent date whose day and month could be read either way round (03.04 or 04.03).
  let ambiguous = day(-3);
  while (Number(ambiguous.slice(8)) > 12 || ambiguous.slice(8) === ambiguous.slice(5, 7)) {
    ambiguous = addDays(ambiguous, -1);
  }
  const rabiesPlan = home.plans.find((item) => item.petId === CAT && item.targets.includes('Rabies'))!;
  const oldDeworming = home.records.find((item) => item.petId === CAT && item.kind === 'Deworming')!;
  const scanPages = [
    file(
      formPage(
        words.pages.rabies,
        [
          [rows.product, 'MSD · Nobivac Rabies'],
          [rows.batch, 'A2977K'],
          [rows.valid, `${dotted(addDays(ambiguous, 21))} – ${dotted(addInterval(ambiguous, 1, 'Year'))}`],
        ],
        words.clinic.replace(/[«»]/g, ''),
      ),
    ),
    file(
      formPage(words.scan.treatments, [
        [words.scan.date, dotted(oldDeworming.performedOn)],
        [rows.product, 'Milbemax'],
        [words.scan.date, '??.??.????'],
        [rows.product, 'Frontline Combo'],
        [words.scan.date, dotted(day(-95))],
        [rows.product, 'Milbemax'],
      ]),
    ),
    file(
      formPage(
        words.scan.exam,
        [
          [words.scan.date, dotted(day(-40))],
          [words.scan.weight, '4,45 kg'],
          [words.scan.vet, words.vet],
          [rows.chip, '276098100345678'],
        ],
        words.clinic.replace(/[«»]/g, ''),
      ),
    ),
  ];
  // Uploaded for the scan, not kept anywhere yet: saving the scan keeps them as passport pages.
  for (const id of scanPages) world.files.get(id)!.attached = false;
  const saved = home.passports.get(CAT)!;
  const scanned = draft({
    records: [
      draftRecord({
        kind: 'Vaccination',
        performedOn: ambiguous,
        product: 'Nobivac Rabies',
        manufacturer: 'MSD Animal Health',
        batchNumber: 'A2977K',
        validFrom: addDays(ambiguous, 21),
        validUntil: addInterval(ambiguous, 1, 'Year'),
        targets: ['Rabies'],
        veterinarian: words.vet,
        clinic: words.clinic,
        evidence: `Nobivac Rabies · A2977K · ${dotted(ambiguous)}`,
        page: 1,
        warnings: [{ field: 'performedOn', issue: 'Ambiguous' }],
        planId: rabiesPlan.id,
      }),
      draftRecord({
        kind: 'Deworming',
        title: titles.deworm,
        performedOn: oldDeworming.performedOn,
        product: 'Milbemax',
        evidence: `${dotted(oldDeworming.performedOn)} Milbemax`,
        page: 2,
        warnings: [{ field: 'record', issue: 'AlreadySaved' }],
        duplicateOf: oldDeworming.id,
        selected: false,
      }),
      draftRecord({
        kind: 'FleaTick',
        performedOn: null,
        product: 'Frontline Combo',
        evidence: '??.??.???? Frontline Combo',
        page: 2,
        warnings: [{ field: 'performedOn', issue: 'Unreadable' }],
        selected: false,
      }),
      draftRecord({
        kind: 'Deworming',
        title: titles.deworm,
        performedOn: day(-95),
        product: 'Milbemax',
        evidence: `${dotted(day(-95))} Milbemax`,
        page: 2,
      }),
      draftRecord({
        kind: 'Deworming',
        title: titles.deworm,
        performedOn: day(-95),
        product: 'Milbemax',
        evidence: `${dotted(day(-95))} Milbemax`,
        page: 3,
        warnings: [{ field: 'record', issue: 'Repeated' }],
        selected: false,
      }),
      draftRecord({
        kind: 'VetExam',
        title: titles.exam,
        performedOn: day(-40),
        weightKg: 4.45,
        veterinarian: words.vet,
        clinic: words.clinic,
        evidence: `${dotted(day(-40))} · 4,45 kg`,
        page: 3,
      }),
      draftRecord({
        kind: 'Vaccination',
        title: 'Purevax RCP',
        performedOn: day(-580),
        product: 'Purevax RCP',
        validUntil: day(-600),
        targets: ['Fpv', 'Fhv1', 'Fcv'],
        evidence: `Purevax RCP ${dotted(day(-580))} – ${dotted(day(-600))}`,
        page: 1,
        warnings: [{ field: 'validUntil', issue: 'EndsBeforeStart' }],
        selected: false,
      }),
    ],
    weights: [
      draftWeight({
        measuredOn: day(-40),
        weightKg: 4.45,
        evidence: '4,45 kg',
        page: 3,
        warnings: [{ field: 'weightKg', issue: 'Repeated' }],
        selected: false,
      }),
      draftWeight({
        measuredOn: addInterval(day(-100), 1, 'Year'),
        weightKg: 4.3,
        evidence: `${dotted(addInterval(day(-100), 1, 'Year'))} 4,3 kg`,
        page: 3,
        warnings: [{ field: 'measuredOn', issue: 'InFuture' }],
        selected: false,
      }),
    ],
    identifiers: [
      draftIdentifier({
        code: '276098100345678',
        evidence: '276098100345678',
        page: 3,
        warnings: [{ field: 'code', issue: 'AlreadySaved' }],
        selected: false,
      }),
      draftIdentifier({
        code: '27609810034568',
        evidence: '27609810034568',
        page: 3,
        warnings: [{ field: 'code', issue: 'InvalidFormat' }],
        selected: false,
      }),
    ],
    passport: draftPassport({
      // One digit off: the saved number stays unless the person says to replace it.
      passportNumber: `${saved.passportNumber!.slice(0, -1)}${saved.passportNumber!.endsWith('9') ? '8' : '9'}`,
      issuingCountry: saved.issuingCountry,
      issuedOn: saved.issuedOn,
      evidence: saved.passportNumber,
      page: 1,
      warnings: [{ field: 'passportNumber', issue: 'DiffersFromSaved' }],
      selected: false,
    }),
  });
  const scannedAt = new Date(Date.now() - 2 * 3_600_000).toISOString();
  home.imports.push(
    {
      id: newId(),
      petId: CAT,
      source: 'PassportPages',
      status: 'Ready',
      fileIds: scanPages,
      text: null,
      error: null,
      model: 'gemini-3.8-flash',
      createdAt: scannedAt,
      completedAt: scannedAt,
      appliedAt: null,
      result: null,
      requestId: null,
      outcome: { draft: scanned },
      polls: 0,
    },
    {
      id: newId(),
      petId: CAT,
      source: 'Text',
      status: 'Failed',
      fileIds: [],
      text: words.scan.note,
      error: 'Busy',
      model: null,
      createdAt: new Date(Date.now() - 26 * 3_600_000).toISOString(),
      completedAt: new Date(Date.now() - 26 * 3_600_000).toISOString(),
      appliedAt: null,
      result: null,
      requestId: null,
      outcome: { error: 'Busy' },
      polls: 0,
    },
  );

  // A household where the person only helps: a colleague's cat at the office, on Premium given by hand.
  const office = emptyHousehold({ id: OFFICE, name: words.office, role: 'Helper', timeZone, memberCount: 3 });
  office.joinedAt = `${day(-90)}T09:00:00Z`;
  office.others = [
    person('demo-colleague', words.colleague, 'colleague@example.com', 'Owner'),
    person('demo-pavel', null, 'pavel@example.com', 'Member'),
  ];
  office.plan = freePlan({
    plan: 'Premium',
    source: 'Manual',
    expiresAt: `${addInterval(today, 1, 'Year')}T00:00:00Z`,
    aiPhotosPerMonth: 300,
    aiPhotosUsed: 42,
  });
  office.pets = [pet(OFFICE_CAT, words.officeCat, { coat: 'Ginger', sex: 'Male', birthDate: years(6) })];
  office.routines = [routine(newId(), OFFICE_CAT, { times: ['09:00:00', '17:00:00'], amount: 40, unit: 'Gram' })];
  office.plans = [
    plan(newId(), OFFICE_CAT, today, {
      kind: 'Deworming',
      title: titles.deworm,
      daysLeft: 3,
      intervalValue: 3,
      intervalUnit: 'Month',
    }),
  ];

  // Neighbours whose cat the person may look after: "Join with a code" takes the demo's CODE.
  const neighbours = emptyHousehold({
    id: NEIGHBOURS,
    name: words.neighbours,
    role: 'Helper',
    timeZone,
    memberCount: 1,
  });
  neighbours.others = [person('demo-neighbour', words.neighbour, 'neighbour@example.com', 'Owner')];
  neighbours.invites = [invite(newId(), CODE, 'Helper', 'demo-neighbour')];
  neighbours.pets = [pet(newId(), words.neighboursCat, { coat: 'Ink', sex: 'Male' })];

  world.households.set(HOME, home);
  world.households.set(OFFICE, office);
  world.households.set(NEIGHBOURS, neighbours);
  return world;
}

/** The demo's other days, by the address's switch ?mockWorld= (services.ts). */
export type DemoShape = 'new' | 'pets' | 'done';

export function isDemoShape(value: string | null): value is DemoShape {
  return value === 'new' || value === 'pets' || value === 'done';
}

/**
 * `new`: a new account (another e-mail, so this browser hasn't seen it) with one empty household: Home opens the
 * onboarding by itself the first time, and shows "Add a pet" after. `pets`: the pets with nothing set up (no feedings,
 * plans, visits or supplies): Today's and Home's first steps. `done`: the day done: every feeding marked, nothing due
 * within two weeks, no visit planned, nothing to buy: Home's "All done for today".
 */
export function shapeDemoWorld(world: World, shape: DemoShape): void {
  const home = world.households.get(HOME)!;
  if (shape === 'new') {
    world.me = { ...world.me, email: world.me.email.replace('@', '+new@') };
    world.memberships = [HOME];
    const fresh = emptyHousehold({ ...home.summary, memberCount: 1 });
    fresh.joinedAt = `${world.today}T09:00:00Z`;
    world.households.set(HOME, fresh);
    return;
  }
  home.visits = home.visits.filter((item) => item.status !== 'Planned');
  home.supplies = [];
  home.stock = [];
  if (shape === 'pets') {
    home.routines = [];
    home.plans = [];
    home.marks.clear();
    return;
  }
  home.plans = home.plans.filter((item) => !item.active || daysBetween(world.today, item.nextDueOn) > 14);
  const doneAt = new Date().toISOString();
  for (const item of home.routines.filter((each) => each.active)) {
    for (const time of item.times) {
      home.marks.set(markKey(item.id, world.today, time), {
        id: newId(),
        routineId: item.id,
        date: world.today,
        time,
        status: 'Done',
        doneAt,
        byName: world.me.name,
        byMe: true,
      });
    }
  }
}
