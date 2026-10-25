// Screens: the pet form, new (05_pet_form_new) and edit (05_pet_form_edit, a copy of the new one).
// Run as: bridge.py run jobs/_screens.js jobs/_pet_kit.js jobs/s05_pet_form.js
await cbSetup();
const AREA = '05 Форма питомца';

// Segmented buttons (species, sex): equal segments in a pill; the chosen one mint.
async function segmented(name, options, selected) {
  const segments = [];
  for (let i = 0; i < options.length; i++) {
    const on = i === selected;
    segments.push(box({ name: options[i], dir: 'H', w: 'fill', h: 40, align: 'center', justify: 'center',
      fill: on ? 'primary-soft' : 'surface', stroke: i ? 'line-strong' : null, strokeSides: { left: 1 } },
    [await text(options[i], 'label', on ? 'primary' : 'ink', { name: 'label' })]));
  }
  // 40 high in a 48 tap area, like the app's SegmentedButton.
  return box({ name: 'Сегменты · ' + name, dir: 'H', w: 'fill', pad: [4, 0, 4, 0] }, [
    box({ name: 'segments', dir: 'H', w: 'fill', radius: FULL(), stroke: 'line-strong', clip: true }, segments)]);
}
function selectSegment(group, label) {
  for (const segment of group.findOne((n) => n.name === 'segments').children) {
    const on = segment.name === label;
    recolor(segment, on ? 'primary-soft' : 'surface');
    recolor(segment.findOne((n) => n.type === 'TEXT'), on ? 'primary' : 'ink');
  }
}

// The pet's colour in the app: chips with a coat dot; the chosen one mint with a tick.
const COATS = [['Рыжий', 'ginger'], ['Палевый', 'fawn'], ['Шоколадный', 'cocoa'], ['Серый', 'smoke'],
  ['Лиловый', 'lilac'], ['Чёрный', 'ink']];
async function coatChip(label, coat, on) {
  const mark = on ? icon('check_circle', 20, 'coat-' + coat, true)
    : box({ name: 'dot', w: 16, h: 16, radius: FULL(), fill: 'coat-' + coat });
  return box({ name: 'Чип · ' + label, dir: 'H', h: 36, pad: [0, 16, 0, on ? 14 : 16], gap: on ? 14 : 16,
    align: 'center', radius: FULL(), fill: on ? 'primary-soft' : 'surface', stroke: on ? null : 'line-strong' },
  [mark, await text(label, 'label', on ? 'primary' : 'ink', { name: 'label' })]);
}
async function coatPicker(helper) {
  const chips = [];
  for (const [label, coat] of COATS) chips.push(await coatChip(label, coat, false));
  // Rows 56 apart, like the app's chips with their 48 tap area: 36 + 20.
  const chipRows = box({ name: 'Цвета', dir: 'H', w: 358, gap: 8, pad: [6, 0, 6, 0] }, chips);
  chipRows.layoutWrap = 'WRAP';
  bindNum(chipRows, 'counterAxisSpacing', 20, 'space-');
  return labeled('Цвет питомца в приложении', sized(chipRows, 'fill'), helper);
}

// New pet: empty fields with hints, «Кошка» and «Не указан» chosen, no colour.
const fields = box({ name: 'Поля', dir: 'V', w: 'fill', gap: 16 }, [
  await field('Кличка', ''),
  await labeled('Вид', await segmented('Вид', ['Кошка', 'Собака', 'Другое'], 0)),
  await labeled('Пол', await segmented('Пол', ['Самка', 'Самец', 'Не указан'], 2)),
  await field('Порода', '', { hint: 'Например, мейн-кун' }),
  box({ name: 'Группа · Дата рождения', dir: 'V', w: 'fill' }, [await dateField('Дата рождения', '')]),
  box({ name: 'Группа · Стерилизация', dir: 'V', w: 'fill', gap: 8 }, [await switchRow('Стерилизация', false)]),
  await field('Окрас', '', { hint: 'Как в паспорте, например чёрно-белый' }),
  await field('Особые приметы', '', { hint: 'Например, белое пятно на груди' }),
  await coatPicker('Если не выбрать, приложение подберёт цвет, которого нет у других ваших питомцев.'),
]);
const identifiers = section('Чипы и татуировки', await head('Чипы и татуировки'),
  box({ name: 'Идентификаторы', dir: 'V', w: 'fill', gap: 12 }, [
    await text('Чипов и татуировок пока нет.', 'body', 'ink-muted', { name: 'Пусто', w: 'fill' }),
    await outlineButton('add', 'Добавить чип или татуировку', true),
  ]));
const moreFields = box({ name: 'Поля · ещё', dir: 'V', w: 'fill', gap: 16 }, [
  await field('Аллергии', '', { hint: 'Корм, лекарства' }),
  await field('Заметки', ''),
]);
const form = await formPage('Форма питомца — новый', 'Новый питомец',
  box({ name: 'content', dir: 'V', w: 'fill', pad: [16, 16, 48, 16], gap: 32 },
    [await photoSlot('Smoke', '?'), fields, identifiers, moreFields]));

// Edit: a copy of the new form with Мурка's data, the birth and neutering dates,
// her colour and her chip. Copied before placing: place() replaces frames by name.
await cbDone();
const edit = form.clone();
edit.name = 'Форма питомца — изменение';
const find = (name, root) => {
  const node = (root || edit).findOne((n) => n.name === name);
  if (!node) throw new Error('no layer ' + name);
  return node;
};
function replace(old, node) {
  old.parent.insertChild(old.parent.children.indexOf(old), node);
  applySize(node);
  old.remove();
  return node;
}
function setValue(name, value, wraps) {
  const f = find('Поле · ' + name);
  setProp(f, 'Value', value);
  const v = tint(f, 'value', 'ink');
  if (wraps) wrap(v);
}

setProp(edit.children[0], 'Title', 'Изменить данные');
replace(find('Аватар'), await bigAvatar('Ginger', 'М'));
setValue('Кличка', 'Мурка');
selectSegment(find('Сегменты · Пол'), 'Самка');
setValue('Порода', 'Сибирская');
replace(find('Дата · Дата рождения'), await dateField('Дата рождения', '3 апр. 2021 г.'));
add(find('Группа · Дата рождения'), await switchRow('Дата примерная', false));
setProp(find('Переключатель · Стерилизация'), 'Value', 'On');
add(find('Группа · Стерилизация'), await dateField('Дата стерилизации (необязательно)', '5 июн. 2022 г.'));
setValue('Окрас', 'Рыжая с белым');
setValue('Особые приметы', 'Белое пятно на груди');
replace(find('Чип · Рыжий'), await coatChip('Рыжий', 'ginger', true));
find('helper', find('Поле · Цвет питомца в приложении')).characters =
  'Отмечает питомца в приложении: аватар, а позже и календарь.';

// The chip: type, number with its format hint, date and place, in a bordered block.
replace(find('Пусто'), formBlock('Идентификатор · Чип ISO', 12, [
  box({ name: 'type row', dir: 'H', w: 'fill', gap: 8, align: 'end' },
    [await selectField('Тип', 'Чип ISO'), iconButton('delete')]),
  await field('Номер чипа', '643094100123456', { mono: true, help: '15 цифр, например 276 098 100 123 456' }),
  await dateField('Дата вживления', '1 июн. 2021 г.'),
  await field('Место', 'Холка, слева'),
]));
setValue('Аллергии', 'Курица');
setValue('Заметки', 'Боится пылесоса. Любит спать на подоконнике.', true);
await place(AREA, 0, form, '05_pet_form_new_full.png');
strokesOutside(edit);
await placeTall(AREA, 1, edit, '05_pet_form_edit_full.png');
return { form: form.id, edit: edit.id };
