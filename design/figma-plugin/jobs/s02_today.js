// Screens: Today with data (full height), first steps, offline (02_today_*).
await cbSetup();
const AREA = '02 Сегодня';
const header = () => inst('Screen header', {}, { Title: 'Сегодня', Caption: 'Пятница, 2 октября' });
const nav = () => inst('Bottom navigation', { Tab: 'Today' });
const textOf = (node, name) => node.findOne((n) => n.type === 'TEXT' && n.name === name);
const style = (t, name) => t.setTextStyleIdAsync(CB.text[name].id);
// One line, cut with … (truncation first: text() sets them the other way round and both are lost).
const oneLine = (t) => { t.textTruncation = 'ENDING'; t.maxLines = 1; return t; };
// card() with its border drawn inside, outside the layout (like the app's
// Card): new frames here count strokes in the layout, which adds 2 px.
function flatCard(children, props) {
  const c = card(children, props);
  c.strokesIncludedInLayout = false;
  return c;
}

// Exactly the ref's height: 'content' takes the spare height or is cut.
function fitTo(frame, h) {
  const content = frame.children.find((n) => n.name === 'content');
  content.layoutGrow = 1;
  content.clipsContent = true;
  frame.resize(PHONE_W, h);
  return frame;
}

// A section title; with an action it is 48 high (the button's touch target), else 44.
async function sectionHeader(title, action, styleName) {
  const s = await inst('Section header', { Style: styleName || 'Title' }, { Title: title, 'Show action': !!action });
  if (action) setText(s, 'label', action);
  s.resize(358, action ? 48 : 44);
  return sized(s, 'fill');
}
// The groups' titles are plain text in the app (no 44 px header).
const groupTitle = (title) => text(title, 'title', 'ink', { w: 'fill', name: 'title' });
const withDividers = (rows, indent) => rows.flatMap((r, i) => (i ? [divider(indent), r] : [r]));

// Feeding: a List row with the small avatar, the name in body and one line of food.
async function feedRow(pet, coat, what, markedAt) {
  const row = await inst('List row', { Leading: 'Avatar', Trailing: markedAt ? 'None' : 'Button' }, { Title: pet, Subtitle: what });
  row.findOne((n) => n.type === 'INSTANCE' && 'Coat' in n.componentProperties).setProperties({ Size: '28' });
  setAvatar(row, coat, pet[0]);
  await style(textOf(row, 'title'), 'body');
  oneLine(textOf(row, 'subtitle'));
  row.resize(358, 64);
  if (!markedAt) return sized(row, 'fill');
  // Marked: the time it was fed, with a tick (a text button in the app).
  const mark = box({ name: 'fed at', dir: 'H', gap: 8, pad: [0, 20, 0, 4], align: 'center' }, [
    icon('check_circle', 18, 'success', true),
    await text(markedAt, 'body-sm', 'ink-muted'),
  ]);
  return box({ name: 'Fed row · ' + pet, dir: 'H', h: 64, w: 'fill', align: 'center' }, [sized(row, 'fill'), mark]);
}
async function feedSlot(time, rows) {
  const head = await sectionHeader(time, 'Покормить всех', 'Subtitle');
  textOf(head, 'title').fills = [paint('ink')];
  return flatCard([box({ name: 'slot header', dir: 'H', pad: [8, 8, 0, 16], w: 'fill' }, [head]), ...withDividers(rows, 56)],
    { name: 'Кормление ' + time });
}

// Care: List row (Done) with the due line under the subtitle. The row has no
// slot for it, so it is detached; the avatar and the ring stay at the top.
// The due line wraps like the app's: the date never breaks inside.
async function careRow(title, sub, coat, initial, status, when, date) {
  const row = (await inst('List row', { Leading: 'Avatar', Trailing: 'Done' }, { Title: title, Subtitle: sub })).detachInstance();
  row.name = 'Care row · ' + title;
  setAvatar(row, coat, initial);
  row.counterAxisAlignItems = 'MIN';
  const line = await inst('Status line', { Status: status });
  const words = setText(line, 'text', when + ' · ' + date.replace(/ /g, '\u00a0'));
  add(row.findOne((n) => n.name === 'texts'), box({ name: 'due', dir: 'H', pad: [4, 0, 0, 0], w: 'fill' }, [sized(line, 'fill')]));
  words.layoutSizingHorizontal = 'FILL';
  words.textAutoResize = 'HEIGHT';
  if (words.height > 20) line.counterAxisAlignItems = 'MIN';
  return sized(row, 'fill');
}
async function group(title, rows) {
  return box({ name: title, dir: 'V', gap: 8, w: 'fill' }, [await groupTitle(title), flatCard(withDividers(rows, 68))]);
}

// Feeding.
const RC = 'Royal Canin Sterilised 37';
const feeding = box({ name: 'Кормление', dir: 'V', gap: 8, w: 'fill' }, [
  await sectionHeader('Кормление'),
  box({ name: 'slots', dir: 'V', gap: 12, w: 'fill' }, [
    await feedSlot('8:00', [await feedRow('Барсик', 'Smoke', RC + ', 45 г'), await feedRow('Мурка', 'Ginger', RC + ', 40 г', '8:04'),
      await feedRow('Рекс', 'Cocoa', 'Acana Adult Large Breed, 300 г')]),
    await feedSlot('19:00', [await feedRow('Барсик', 'Smoke', RC + ', 45 г'), await feedRow('Мурка', 'Ginger', RC + ', 40 г'),
      await feedRow('Рекс', 'Cocoa', 'Acana Adult Large Breed, 300 г')]),
  ]),
]);

// Visits: "All" and a "+" icon button; the visit row has a plain icon and the pets' faces.
const visitHead = box({ name: 'visits header', dir: 'H', w: 'fill', align: 'center' }, [
  await sectionHeader('Визиты', 'Все'),
  box({ name: 'add visit', dir: 'H', w: 48, h: 48, align: 'center', justify: 'center' }, [icon('add', 24, 'ink-muted', true)]),
]);
const visitRow = box({ name: 'visit', dir: 'H', pad: 16, gap: 12, w: 'fill' }, [
  icon('local_hospital', 24, 'primary'),
  box({ name: 'texts', dir: 'V', w: 'fill' }, [
    await text('Осмотр и прививка от бешенства', 'subtitle', 'ink', { w: 'fill', name: 'title' }),
    await text('Завтра в 10:30', 'body-sm', 'ink-muted', { w: 'fill', name: 'when' }),
    oneLine(await text('Ветклиника «Айболит», ул. Лесная, 12', 'body-sm', 'ink', { w: 'fill', name: 'place' })),
  ]),
  await inst('Pet avatar', { Size: '28', Coat: 'Ginger' }, { Initial: 'М' }),
]);
const visits = box({ name: 'Визиты', dir: 'V', gap: 8, w: 'fill' }, [visitHead, flatCard([visitRow])]);

// To buy: a List row with the category icon in primary and the status in accent-text.
const buyRow = await inst('List row', { Leading: 'Icon', Trailing: 'Button' },
  { Title: RC, Subtitle: 'Пора купить · хватит примерно на 2 дня' });
const glyph = buyRow.findOne((n) => n.type === 'TEXT' && n.name.startsWith('icon/'));
glyph.characters = 'rice_bowl';
glyph.fills = [paint('primary')];
await style(textOf(buyRow, 'title'), 'body');
oneLine(textOf(buyRow, 'title'));
textOf(buyRow, 'subtitle').fills = [paint('accent-text')];
setText(buyRow, 'label', 'Купили');
const shopping = box({ name: 'Купить', dir: 'V', gap: 8, w: 'fill' }, [
  await sectionHeader('Купить', 'Все запасы'), flatCard([sized(buyRow, 'fill')]),
]);

const content = box({ name: 'content', dir: 'V', gap: 24, pad: [0, 16, 72, 16], w: 'fill' }, [
  feeding, visits, shopping,
  await group('Просрочено', [await careRow('Бешенство', 'Мурка · Прививка', 'Ginger', 'М', 'Overdue',
    'Просрочено на 3 дня', '29 сент. 2026 г.')]),
  await group('Скоро', [
    await careRow('Осмотр у ветеринара', 'Мурка · Осмотр', 'Ginger', 'М', 'Soon', 'Завтра', '3 окт. 2026 г.'),
    await careRow('Обработка от глистов', 'Рекс', 'Cocoa', 'Р', 'Soon', 'Через 4 дня', '6 окт. 2026 г.'),
    await careRow('Комплексная прививка', 'Барсик · Прививка', 'Smoke', 'Б', 'Soon', 'Через 9 дней', '11 окт. 2026 г.'),
  ]),
  await group('Позже', [await careRow('Блохи и клещи', 'Мурка', 'Ginger', 'М', 'Planned', 'Через 25 дней', '27 окт. 2026 г.')]),
]);
const data = fitTo(screen('Сегодня — с данными', [await header(), content, await nav()]), 1842);
await place(AREA, 0, data, '02_today_with_data_full.png');

// First steps: the empty state, then "Add pet" (a filled button with an icon).
const addPet = (await inst('Button', { Style: 'Primary', State: 'Default' }, { Label: 'Добавить питомца' })).detachInstance();
addPet.name = 'Button + icon · Добавить питомца';
addPet.insertChild(0, icon('add', 18, 'on-primary', true));
bindNum(addPet, 'itemSpacing', 8, 'space-');
if (addPet.layoutMode !== 'NONE') addPet.layoutSizingHorizontal = 'HUG';
const first = fitScreen(screen('Сегодня — первые шаги', [
  await header(),
  box({ name: 'content', dir: 'V', w: 'fill', align: 'center' }, [
    sized(await inst('Empty state', {}, { Title: 'Начните с питомца', 'Show button': false,
      Message: 'Добавьте кошку или собаку: потом здесь появятся кормления, прививки, обработки и что пора купить.' }), 'fill'),
    box({ name: 'add pet', dir: 'H', h: 48, align: 'center' }, [addPet]),
  ]),
  await nav(),
]));
await place(AREA, 1, first, '02_today_first_steps.png');

// Offline: the same Today, with the strip over the bottom navigation.
const offline = data.clone();
offline.name = 'Сегодня — нет связи';
const strip = await inst('Offline strip', {}, { Message: 'Нет связи с сервером · данные на 14:05' });
offline.insertChild(offline.children.length - 1, strip);
fitTo(offline, PHONE_H);
await place(AREA, 2, offline, '02_today_offline.png');
return { data: data.id, first: first.id, offline: offline.id };
