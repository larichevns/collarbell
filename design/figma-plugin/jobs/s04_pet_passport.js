// Screen: the pet's page, tab Паспорт (04_pet_3_passport): disclaimer, AI scan, passport data,
// chips, photographed pages and the health sections V–X.
// Run as: bridge.py run jobs/_screens.js jobs/_pet_kit.js jobs/s04_pet_passport.js
await cbSetup();
const AREA = '04 Страница питомца';

const notice = sized(await inst('Notice', { Kind: 'Info' }), 'fill');
setText(notice, 'message', 'Цифровая копия — только для справки. Официальным документом остаётся бумажный паспорт.');
notice.name = 'Notice · справка';

// «Сканировать страницы паспорта»: what the AI scan does, and its button.
const scan = card([
  box({ name: 'about', dir: 'H', w: 'fill', gap: 12 }, [
    kindDisc('document_scanner'),
    box({ name: 'texts', dir: 'V', w: 'fill', gap: 4 }, [
      await text('Сканировать страницы паспорта', 'subtitle', 'ink', { name: 'title', w: 'fill' }),
      await text('AI прочитает с фото прививки, обработки, чипы и данные паспорта. Перед сохранением вы всё проверите.',
        'body-sm', 'ink-muted', { name: 'text', w: 'fill' }),
    ]),
  ]),
  await outlineButton('document_scanner', 'Сканировать', false, true),
], { name: 'Скан паспорта', pad: 16, gap: 12 });

const passportData = section('Данные паспорта', await head('Данные паспорта', 'Изменить'),
  await detailsCard('Данные паспорта', [
    ['Образец паспорта', 'Другой паспорт'], ['Номер паспорта', 'RU0123456', true], ['Страна выдачи', 'RU'],
    ['Дата выдачи', '1 июл. 2021 г.'],
    ['Ветеринар, выдавший паспорт', 'Иванова Анна Сергеевна\nМосква, ул. Лесная, 12\n+7 495 123-45-67'],
    ['Владелец', 'Анна Смирнова\nМосква, ул. Садовая, 5, кв. 17\n+7 916 555-12-34\nanna.smirnova@example.com'],
  ]));

const chip = card([box({ name: 'Чип ISO', dir: 'V', w: 'fill', pad: [8, 0, 8, 0] }, [
  await text('Чип ISO', 'caption', 'ink-muted', { name: 'type', w: 'fill' }),
  box({ name: 'code', dir: 'V', w: 'fill', pad: [4, 0, 0, 0] }, [
    await text('643 094 100 123 456', 'code', 'ink', { name: 'code', w: 'fill' }),
    await text('Вживлён ' + nb('1 июн. 2021 г.') + ' · Холка, слева', 'body-sm', 'ink-muted', { name: 'details', w: 'fill' }),
  ]),
])], { name: 'Чипы и татуировки', pad: 16 });
const chips = section('Чипы и татуировки', await head('Чипы и татуировки', 'Изменить'), chip);

// Pages of the paper passport: tiles, three in a row, portrait 3:4.
const tiles = [];
for (const name of ['crop_s04_page1.png', 'crop_s04_page2.png', 'crop_s04_page3.png']) {
  const tile = picture(await bridge.ref(name), 114, 152, CB.numValue['radius-sm']);
  tile.name = 'Страница ' + (tiles.length + 1);
  tiles.push(tile);
}
const pages = section('Страницы',
  await head('Страницы', await linkButton('add_a_photo', 'Добавить страницы')),
  box({ name: 'Сетка страниц', dir: 'H', w: 'fill', gap: 8 }, tiles));

// A line of a health section, like the paper passport: date, what was given, details.
async function passportRow(date, what, more) {
  const lines = [await text(what, 'body', 'ink', { name: 'what', w: 'fill' })];
  if (more) lines.push(await text(more, 'body-sm', 'ink-muted', { name: 'more', w: 'fill' }));
  return box({ name: 'Запись · ' + date, dir: 'H', w: 'fill', pad: [12, 16, 12, 16], align: 'center' }, [
    box({ name: 'texts', dir: 'V', w: 'fill', gap: 4 }, [
      await text(date, 'label', 'ink', { name: 'date', w: 'fill' }),
      box({ name: 'lines', dir: 'V', w: 'fill' }, lines),
    ]),
    icon('chevron_right', 24, 'ink-muted', true),
  ]);
}
async function rowsCard(name, rows) {
  const items = [];
  for (const row of rows) {
    if (items.length) items.push(divider(16));
    items.push(await passportRow(...row));
  }
  return card(items, { name });
}
const valid = (from, to) => 'Действует ' + nb(from) + ' – ' + nb(to);
// A health section; a long title has «Добавить» under it, as in the app.
async function healthSection(title, below, content) {
  return section(title, below ? await headBelow(title, 'Добавить') : await head(title, 'Добавить'), content);
}
const health = [
  await healthSection('V. Вакцинация против бешенства', true, await rowsCard('V', [
    ['29 сент. 2025 г., 11:15', 'Nobivac Rabies · Серия A123B01', valid('29 сент. 2025 г.', '29 сент. 2026 г.')]])),
  await healthSection('VI. Тест на антитела к бешенству', true, await mutedCard('Записей пока нет.')),
  await healthSection('VII. Обработка от эхинококка', true, await mutedCard('Записей пока нет.')),
  await healthSection('VIII. Другие обработки от паразитов', true, await rowsCard('VIII', [
    ['18 авг. 2026 г.', 'Обработка от глистов · Мильбемакс'],
    ['27 сент. 2026 г.', 'Блохи и клещи · Frontline Combo']])),
  await healthSection('IX. Другие прививки', false, await rowsCard('IX', [
    ['10 окт. 2024 г.', 'Nobivac Tricat Trio · Серия C789D03', valid('10 окт. 2024 г.', '10 окт. 2027 г.')]])),
  await healthSection('X. Клинический осмотр', false, await rowsCard('X', [
    ['3 окт. 2025 г.', 'Осмотр у ветеринара', 'Может путешествовать · Ветклиника «Айболит»']])),
];

const passport = await petPage('Питомец — паспорт', 'Passport',
  box({ name: 'content', dir: 'V', w: 'fill', pad: [16, 16, 72, 16], gap: 24 },
    [notice, scan, passportData, chips, pages, ...health]));
await placeTall(AREA, 2, passport, '04_pet_3_passport_full.png');
return { passport: passport.id };
