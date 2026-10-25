// Screens: More, Notifications, Photo recognition (12_more_*), full height.
await cbSetup();
const AREA = '12 Ещё';
const FULL = CB.numValue['radius-full'];
const nav = () => inst('Bottom navigation', { Tab: 'More' });
const textOf = (node, name) => node.findOne((n) => n.type === 'TEXT' && n.name === name);
const style = (t, name) => t.setTextStyleIdAsync(CB.text[name].id);
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
// The app's AppBar is 56 high (the component is 64).
async function appBar(title) {
  const bar = await inst('App bar', { Actions: 'None' }, { Title: title });
  bar.resize(PHONE_W, 56);
  return bar;
}
// CbSection's title: a Section header, 44 high.
async function title(words) {
  const s = await inst('Section header', { Style: 'Title' }, { Title: words, 'Show action': false });
  s.resize(358, 44);
  return sized(s, 'fill');
}
// An outlined button with an icon (OutlinedButton.icon): the Button has no
// icon slot, so a Secondary one is detached and gets it. Full width, in its
// 48 px touch target.
async function iconButton(glyph, label, filled) {
  const b = (await inst('Button', { Style: 'Secondary', State: 'Default' }, { Label: label })).detachInstance();
  b.name = 'Button + icon · ' + label;
  b.insertChild(0, icon(glyph, 18, 'ink', filled));
  bindNum(b, 'itemSpacing', 8, 'space-');
  b.primaryAxisAlignItems = 'CENTER';
  return box({ name: 'button area', dir: 'V', h: 48, w: 'fill', justify: 'center' }, [sized(b, 'fill')]);
}
// A ListTile: plain icon (no disc), then a List row; 72 high like a two-line tile.
async function tile(glyph, words, sub, trailing, titleStyle) {
  const row = await inst('List row', { Leading: 'None', Trailing: trailing || 'None' }, { Title: words, Subtitle: sub });
  if (titleStyle) await style(textOf(row, 'title'), titleStyle);
  const w = box({ name: 'Tile · ' + words, dir: 'H', pad: [0, 0, 0, 16], align: 'center', w: 'fill' },
    [icon(glyph, 24, 'ink-muted'), sized(row, 'fill')]);
  w.minHeight = 72;
  return w;
}
const withDividers = (rows, indent) => rows.flatMap((r, i) => (i ? [divider(indent), r] : [r]));

// ----- More
// Flutter's Radio: an 18 px ring (radius 8, 2 px stroke), a 9 px dot when on.
function radio(on) {
  return box({ name: on ? 'radio on' : 'radio', dir: 'H', w: 40, h: 40, align: 'center', justify: 'center' }, [
    box({ name: 'ring', dir: 'H', w: 18, h: 18, radius: FULL, stroke: on ? 'primary' : 'line-strong', strokeW: 2,
      align: 'center', justify: 'center' }, on ? [box({ name: 'dot', w: 9, h: 9, radius: FULL, fill: 'primary' })] : []),
  ]);
}
const radioRow = async (words, on) => box({ name: 'Radio · ' + words, dir: 'H', h: 56, pad: [0, 16, 0, 16], gap: 16,
  align: 'center', w: 'fill' }, [radio(on), await text(words, 'body', 'ink', { w: 'fill' })]);
// More's sections: a plain title (no 44 px header), 12 above the card.
const moreSection = async (words, child) => box({ name: words, dir: 'V', gap: 12, pad: [24, 16, 0, 16], w: 'fill' },
  [await text(words, 'title', 'ink', { w: 'fill', name: 'title' }), child]);

const moreContent = box({ name: 'content', dir: 'V', pad: [0, 0, 48, 0], w: 'fill' }, [
  sized(await inst('Screen header', {}, { Title: 'Ещё', 'Show caption': false }), 'fill'),
  await moreSection('Аккаунт', flatCard([
    box({ name: 'texts', dir: 'V', gap: 4, w: 'fill' }, [
      await text('Вы вошли как', 'caption', 'ink-muted'),
      await text('anna.smirnova@example.com', 'subtitle', 'ink', { w: 'fill' }),
    ]),
  ], { pad: 16 })),
  await moreSection('Язык', flatCard([await radioRow('Как в системе'), await radioRow('English'), await radioRow('Русский', true)])),
  await moreSection('Тема', flatCard([await radioRow('Светлая (по умолчанию)', true), await radioRow('Тёмная'),
    await radioRow('Как в системе')])),
  await moreSection('Уведомления', flatCard([await tile('notifications', 'Уведомления', 'Напоминания, проверка, история', 'Chevron', 'body')])),
  await moreSection('AI', flatCard([await tile('document_scanner', 'Распознавание фото', 'Подключено', 'Chevron', 'body')])),
  box({ name: 'sign out', dir: 'V', pad: [32, 16, 0, 16], w: 'fill' }, [await iconButton('logout', 'Выйти', true)]),
]);
const more = fitTo(screen('Ещё — меню', [moreContent, await nav()]), 1156);
await place(AREA, 0, more, '12_more_more_full.png');

// ----- Notifications
const switchRow = async (glyph, words, sub) => {
  const row = await inst('Switch row', { Value: 'On' }, { Title: words, Subtitle: sub });
  await style(textOf(row, 'title'), 'subtitle');
  const w = box({ name: 'Switch · ' + words, dir: 'H', pad: [0, 16, 0, 16], gap: 16, align: 'center', w: 'fill' },
    [icon(glyph, 24, 'ink-muted'), sized(row, 'fill')]);
  w.minHeight = 72;
  return w;
};
const block = async (words, child) => box({ name: words, dir: 'V', gap: 8, w: 'fill' }, [await title(words), child]);
const notice = await inst('Notice', { Kind: 'Info' });
setText(notice, 'message', 'Напоминания приходят на этот телефон.');
const notifContent = box({ name: 'content', dir: 'V', gap: 24, pad: [16, 16, 48, 16], w: 'fill' }, [
  box({ name: 'status', dir: 'V', gap: 12, w: 'fill' }, [sized(notice, 'fill'),
    await iconButton('notifications_active', 'Прислать проверочное уведомление')]),
  await block('Напоминания', flatCard([
    await switchRow('restaurant', 'Кормление', 'В каждое время кормления'),
    await switchRow('vaccines', 'Прививки и обработки', 'За 7 дней, за день и в день срока, в 10:00; повторно, если просрочено'),
    await switchRow('event', 'Визиты', 'Как указано у визита'),
    await switchRow('inventory_2', 'Запасы', 'Когда пора купить, в 10:00'),
  ])),
  await block('Ближайшие напоминания', flatCard([
    await tile('restaurant', 'Барсик, Мурка, Рекс', 'Завтра, 8:00'),
    await tile('event', 'Осмотр и прививка от бешенства', 'Завтра, 8:30'),
    await tile('vaccines', 'Барсик: Комплексная прививка', '4 окт. 2026 г., 9:00'),
  ])),
  await block('Недавние напоминания', flatCard([
    await tile('restaurant', 'Барсик, Мурка, Рекс', 'Сегодня в 8:00 · отправлено'),
    await tile('inventory_2', 'Royal Canin Sterilised 37', 'Вчера, 10:00 · отправлено'),
    await tile('vaccines', 'Мурка: Бешенство', 'Вчера, 9:00 · отправлено'),
    await tile('restaurant', 'Мурка', 'Вчера, 19:00 · не нужно: уже сделано'),
  ])),
]);
const notif = fitTo(screen('Уведомления — настройки', [await appBar('Уведомления'), notifContent, await nav()]), 1388);
await place(AREA, 1, notif, '12_more_notifications_full.png');

// ----- Photo recognition (AI)
async function modelRow(name) {
  const row = await inst('List row', { Leading: 'None', Trailing: 'None' }, { Title: name, Subtitle: 'Google Gemini' });
  await style(textOf(row, 'title'), 'code');
  return box({ name: 'Model · ' + name, dir: 'H', align: 'center', w: 'fill' }, [sized(row, 'fill'),
    box({ name: 'ready', dir: 'H', gap: 4, pad: [0, 16, 0, 0], align: 'center' },
      [icon('check_circle', 18, 'primary'), await text('Готова', 'body-sm', 'primary')])]);
}
const detail = async (label, value) => box({ name: label, dir: 'V', gap: 4, pad: [8, 0, 8, 0], w: 'fill' },
  [await text(label, 'caption', 'ink-muted'), await text(value, 'body', 'ink')]);
const warning = await inst('Notice', { Kind: 'Warning' });
setText(warning, 'message', 'Бесплатный тариф Gemini: Google может использовать отправленные данные для улучшения своих ' +
  'продуктов, а читать их могут сотрудники-рецензенты. Сканируйте только свои документы.');
const aiContent = box({ name: 'content', dir: 'V', gap: 24, pad: [16, 16, 48, 16], w: 'fill' }, [
  box({ name: 'status', dir: 'V', gap: 12, w: 'fill' }, [
    flatCard([box({ name: 'connected', dir: 'H', gap: 12, w: 'fill' }, [
      icon('check_circle', 24, 'primary'),
      box({ name: 'texts', dir: 'V', gap: 4, w: 'fill' }, [
        await text('Подключено', 'subtitle', 'ink'),
        await text('AI читает фото страниц паспорта и документов ветеринара и готовит черновик. Ничего не сохраняется, ' +
          'пока вы его не проверите.', 'body-sm', 'ink-muted', { w: 'fill' }),
      ]),
    ])], { pad: 16 }),
    sized(warning, 'fill'),
  ]),
  await block('Модели', box({ name: 'models', dir: 'V', gap: 8, w: 'fill' }, [
    flatCard(withDividers([await modelRow('gemini-3.8-flash'), await modelRow('gemini-3.7-flash')], 16)),
    await text('Они пробуются по порядку: если модель занята или исчерпала бесплатный лимит, фото читает следующая.',
      'body-sm', 'ink-muted', { w: 'fill' }),
  ])),
  await block('В этом месяце', flatCard([await detail('Запросы', '12'), await detail('Отправлено токенов', '20 400'),
    await detail('Получено токенов', '9 800')], { pad: 16 })),
  await block('Проверка подключения', box({ name: 'test', dir: 'V', gap: 12, w: 'fill' }, [
    await text('Модель спросят, какого цвета квадрат на маленькой картинке. Это может занять до минуты.', 'body', 'ink', { w: 'fill' }),
    await iconButton('wifi_tethering', 'Проверить подключение', true),
  ])),
]);
const ai = fitTo(screen('Распознавание фото — подключено', [await appBar('Распознавание фото'), aiContent, await nav()]), 1289);
await place(AREA, 2, ai, '12_more_ai_full.png');
return { more: more.id, notifications: notif.id, ai: ai.id };
