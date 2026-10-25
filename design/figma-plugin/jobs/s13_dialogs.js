// Screens: "Leave without saving?" over the pet form, "Sign out?" over More
// (13_dialogs_*). The second clones «Ещё — меню»: run s12_more.js first.
await cbSetup();
const AREA = '13 Диалоги';
const FULL = CB.numValue['radius-full'];

function prop(node, short, value) {
  const key = Object.keys(node.componentProperties).find((k) => k.split('#')[0] === short);
  node.setProperties({ [key]: value });
  return node;
}
// The dialog over a dimmed screen (scrim: black 54 %, Flutter's dialog barrier).
async function withDialog(frame, title, message, confirm) {
  scrim(frame);
  const dialog = await inst('Dialog', {}, { Title: title, Message: message });
  prop(dialog.findOne((n) => n.type === 'INSTANCE' && n.name === 'confirm'), 'Label', confirm);
  float(frame, dialog, { left: Math.round((PHONE_W - dialog.width) / 2), top: Math.round((PHONE_H - dialog.height) / 2) });
  return frame;
}

// ----- The pet form under the dialog, drawn simply (as 05_pet_form_edit, top part).
async function segmented(name, options) {
  const segments = [];
  for (let i = 0; i < options.length; i++) {
    const on = i === 0;
    segments.push(box({ name: options[i], dir: 'H', h: 40, w: 'fill', align: 'center', justify: 'center',
      fill: on ? 'primary-soft' : 'surface', stroke: i ? 'line-strong' : null, strokeSides: { left: 1 } },
    [await text(options[i], 'label', on ? 'primary' : 'ink')]));
  }
  return box({ name, dir: 'V', gap: 8, w: 'fill' }, [
    await text(name, 'label', 'ink', { name: 'label' }),
    box({ name: 'segments area', dir: 'V', h: 48, w: 'fill', justify: 'center' }, [
      box({ name: 'Segmented · ' + name, dir: 'H', h: 40, w: 'fill', radius: FULL, stroke: 'line-strong', clip: true }, segments),
    ]),
  ]);
}
async function field(label, value) {
  const f = await inst('Text field', { State: 'Default' }, { Label: label, Value: value, 'Show hint': false });
  f.findOne((n) => n.type === 'TEXT' && n.name === 'value').fills = [paint('ink')];
  return sized(f, 'fill');
}

const appBar = await inst('App bar', { Actions: 'None' }, { Title: 'Изменить данные' });
appBar.resize(PHONE_W, 56);
const initial = await text('М', 'numeral', 'on-coat', { name: 'initial' });
initial.fontSize = 58;
initial.lineHeight = { unit: 'PERCENT', value: 100 };
const photoButton = (await inst('Button', { Style: 'Text', State: 'Default' }, { Label: 'Добавить фото' })).detachInstance();
photoButton.name = 'Button + icon · Добавить фото';
photoButton.insertChild(0, icon('photo_camera', 18, 'primary'));
bindNum(photoButton, 'itemSpacing', 8, 'space-');
if (photoButton.layoutMode !== 'NONE') photoButton.layoutSizingHorizontal = 'HUG';
const form = box({ name: 'content', dir: 'V', gap: 32, pad: [16, 16, 0, 16], w: 'fill' }, [
  box({ name: 'photo', dir: 'V', gap: 8, w: 'fill', align: 'center' }, [
    box({ name: 'avatar 128', dir: 'H', w: 128, h: 128, radius: FULL, fill: 'coat-ginger', align: 'center', justify: 'center' }, [initial]),
    box({ name: 'button area', dir: 'H', h: 48, align: 'center' }, [photoButton]),
  ]),
  box({ name: 'fields', dir: 'V', gap: 16, w: 'fill' }, [
    await field('Кличка', 'Мурочка'),
    await segmented('Вид', ['Кошка', 'Собака', 'Другое']),
    await segmented('Пол', ['Самка', 'Самец', 'Не указан']),
    await field('Порода', 'Сибирская'),
    await field('Дата рождения', '3 апр. 2021 г.'),
  ]),
]);
const leave = screen('Диалог — уйти без сохранения', [
  appBar, form,
  sized(await inst('Save bar', {}, { 'Show error': false }), 'fill'),
  await inst('Bottom navigation', { Tab: 'Pets' }),
]);
form.layoutGrow = 1;
form.clipsContent = true;
leave.resize(PHONE_W, PHONE_H);
await withDialog(leave, 'Уйти без сохранения?', 'Введённое на этом экране пропадёт.', 'Уйти');
await place(AREA, 0, leave, '13_dialogs_leave_without_saving.png');

// ----- More, scrolled to the end, under "Sign out?".
const page = await screensPage();
const more = page.findOne((n) => n.type === 'FRAME' && n.name === 'Ещё — меню');
if (!more) throw new Error('«Ещё — меню» is not on the page: run s12_more.js first');
const signOut = more.clone();
signOut.name = 'Диалог — выйти из аккаунта';
const content = signOut.children.find((n) => n.name === 'content');
// Bottom-aligned and cut at the top: the list as it is when scrolled to the end.
content.primaryAxisAlignItems = 'MAX';
content.clipsContent = true;
content.layoutGrow = 1;
signOut.resize(PHONE_W, PHONE_H);
await withDialog(signOut, 'Выйти из аккаунта?',
  'Напоминания перестанут приходить на этот телефон, пока вы снова не войдёте.', 'Выйти');
await place(AREA, 1, signOut, '13_dialogs_sign_out.png');
return { leave: leave.id, signOut: signOut.id };
