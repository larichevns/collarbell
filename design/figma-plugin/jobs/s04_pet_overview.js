// Screens: the pet's page, tabs Обзор, Документы and Кормление (04_pet_1, 04_pet_4, 04_pet_5).
// Run as: bridge.py run jobs/_screens.js jobs/_pet_kit.js jobs/s04_pet_overview.js
await cbSetup();
const AREA = '04 Страница питомца';

// Обзор: the photo slot and the details card.
const facts = [
  ['Вид', 'Кошка'], ['Пол', 'Самка'], ['Порода', 'Сибирская'], ['Дата рождения', '3 апр. 2021 г.'],
  ['Стерилизация', 'Да, 5 июн. 2022 г.'], ['Окрас', 'Рыжая с белым'], ['Особые приметы', 'Белое пятно на груди'],
  ['Цвет питомца в приложении', 'Рыжий'], ['Аллергии', 'Курица'],
  ['Заметки', 'Боится пылесоса. Любит спать на подоконнике.'],
];
const overview = await petPage('Питомец — обзор', 'Overview',
  box({ name: 'content', dir: 'V', w: 'fill', pad: [24, 16, 48, 16], gap: 24 }, [
    await photoSlot('Ginger', 'М'),
    section('Данные', await head('Данные'), await detailsCard('Данные', facts)),
  ]));
await place(AREA, 0, overview, '04_pet_1_overview_full.png');

// Документы: «Добавить документ» and the documents with their first page.
async function docRow(image, title, glyph, details) {
  return box({ name: 'Документ · ' + title, dir: 'H', w: 'fill', pad: [12, 16, 12, 16], gap: 12, align: 'center' }, [
    picture(await bridge.ref(image), 52, 52, CB.numValue['radius-sm']),
    box({ name: 'texts', dir: 'V', w: 'fill', gap: 4 }, [
      await text(title, 'subtitle', 'ink', { name: 'title', w: 'fill', lines: 1 }),
      box({ name: 'details', dir: 'H', w: 'fill', gap: 4, align: 'center' }, [
        icon(glyph, 14, 'ink-muted'),
        await text(details, 'body-sm', 'ink-muted', { name: 'details', w: 'fill', lines: 2 }),
      ]),
    ]),
    icon('chevron_right', 24, 'ink-muted', true),
  ]);
}
const documents = await petPage('Питомец — документы', 'Documents',
  box({ name: 'content', dir: 'V', w: 'fill', pad: [16, 16, 48, 16], gap: 16 }, [
    await outlineButton('add', 'Добавить документ', true),
    card([
      await docRow('crop_s04_doc_passport.png', 'Страницы паспорта', 'menu_book',
        nb('20 сент. 2026 г.') + ' · ' + nb('3 страницы')),
      divider(80),
      await docRow('crop_s04_doc_blood.png', 'Общий анализ крови', 'science',
        'Анализы · ' + nb('15 сент. 2026 г.') + ' · ' + nb('2 страницы')),
    ], { name: 'Документы' }),
  ]));
await place(AREA, 3, documents, '04_pet_4_documents.png');

// Кормление: the feeding schedules, each a card with its times large.
async function scheduleCard(times, days, what) {
  return card([box({ name: 'row', dir: 'H', w: 'fill', pad: 16, gap: 12, align: 'center' }, [
    icon('restaurant', 24, 'primary'),
    box({ name: 'texts', dir: 'V', w: 'fill' }, [
      await text(times, 'subtitle', 'ink', { name: 'times', w: 'fill' }),
      await text(days, 'body-sm', 'ink-muted', { name: 'days', w: 'fill' }),
      await text(what, 'body-sm', 'ink', { name: 'what', w: 'fill', lines: 2 }),
    ]),
    icon('chevron_right', 24, 'ink', true),
  ])], { name: 'Расписание · ' + times });
}
const feeding = await petPage('Питомец — кормление', 'Feeding',
  box({ name: 'content', dir: 'V', w: 'fill', pad: [16, 16, 48, 16] }, [
    section('Расписание кормления',
      await head('Расписание кормления', await linkButton('add', 'Добавить', true)),
      box({ name: 'schedules', dir: 'V', w: 'fill', gap: 12 }, [
        await scheduleCard('8:00 · 19:00', 'Каждый день', 'Royal Canin Sterilised 37, 40 г'),
        await scheduleCard('13:00', 'сб, вс', 'Felix, паштет с кроликом, 1 шт.'),
      ])),
  ]));
await place(AREA, 4, feeding, '04_pet_5_feeding.png');

return { overview: overview.id, documents: documents.id, feeding: feeding.id };
