// Screens: the care plan form, new (from the FeLV preset) and edit («Бешенство»)
// (06_care_plan_form_new_full, 06_care_plan_form_edit_full).
// Run: python3 bridge.py run jobs/_screens.js jobs/s06_care_kit.js jobs/s06_care_plan_form.js
await cbSetup();

// A two-way segmented button (no component yet): pill, line-strong border, the chosen half mint.
// It is 40 high inside the app's 48-high tap area.
async function segmented(label, options, chosen) {
  const halves = [];
  for (let i = 0; i < options.length; i++) {
    const on = i === chosen;
    halves.push(box({ name: options[i], dir: 'H', h: 40, w: 'fill', align: 'center', justify: 'center',
      fill: on ? 'primary-soft' : 'surface', stroke: i < options.length - 1 ? 'line-strong' : null,
      strokeSides: { right: 1 } }, [await text(options[i], 'label', on ? 'primary' : 'ink', { name: 'label' })]));
  }
  const control = box({ name: 'segmented', dir: 'H', w: 'fill', radius: R().full, stroke: 'line-strong',
    clip: true }, halves);
  return labeled(label, box({ name: 'tap area', dir: 'V', pad: [4, 0, 4, 0], w: 'fill' }, [control]));
}

// «Раз в»: a 96-wide number field and the unit list.
async function intervalRow(count, unit) {
  const number = await field('Раз в', count, { noLabel: true, w: 96 });
  number.name = 'Число';
  const units = flatField(await inst('Select field', {}, { Label: 'Единица', Value: unit, 'Show icon': false }));
  units.name = 'Единица';
  units.findOne((n) => n.type === 'TEXT' && n.name === 'label').visible = false;
  return labeled('Раз в', box({ name: 'interval', dir: 'H', gap: 8, w: 'fill' }, [number, sized(units, 'fill')]));
}

// The preset's note on top: a grey info notice (Notice, Kind Info).
const note = await inst('Notice', { Kind: 'Info' });
setText(note, 'message', 'Сначала тест. Две дозы с интервалом 3–4 недели, затем раз в год, если кошка гуляет.');
note.name = 'Подсказка плана';

// New plan from the «Лейкоз кошек (FeLV)» preset: its note on top, the fields filled from it.
const content = careContent(16, [
  sized(note, 'fill'),
  await field('Что сделать', 'Лейкоз кошек (FeLV)'),
  await kindSelect(),
  await segmented('Как часто', ['Повторяется', 'Один раз'], 0),
  await intervalRow('1', 'год'),
  await dateField('Последний раз (необязательно)', 'Не указана',
    { muted: true, hint: 'От этой даты посчитаем следующую.' }),
  await dateField('Следующий срок', '2 окт. 2026 г.'),
  await field('Обычный препарат (необязательно)', 'Например, Мильбемакс',
    { muted: true, hint: 'Подставится, когда вы отметите выполнение.' }),
  await targetChips('Лейкоз (FeLV)'),
  await field('Заметки', ''),
]);
const fresh = await careScreen('План ухода — новый', 'Новый план', 'None', content, true);
// The edit form is a copy of this one (made before placing, so place() can't take it for an old one).
await cbDone();
const edit = fresh.clone();
await place(CARE_AREA, 1, fresh, '06_care_plan_form_new_full.png');

// Edit: the saved «Бешенство» plan. No preset note and no «Последний раз»; a menu and «Действует».
edit.name = 'План ухода — изменение';
const bar = edit.children[0];
setProp(bar, 'Actions', 'Menu');
setProp(bar, 'Title', 'Изменить план');
const form = edit.findOne((n) => n.name === 'content');
form.findOne((n) => n.name === 'Подсказка плана').remove();
form.findOne((n) => n.type === 'FRAME' && n.name === 'Последний раз (необязательно)').remove();
setValue(byName(form, 'Что сделать'), 'Бешенство');
setValue(byName(form, 'Следующий срок'), '29 сент. 2026 г.');
setValue(byName(form, 'Обычный препарат (необязательно)'), 'Nobivac Rabies');
setProp(byName(form, 'Чип · Бешенство'), 'Selected', 'On');
setProp(byName(form, 'Чип · Лейкоз (FeLV)'), 'Selected', 'Off');
const active = await inst('Switch row', { Value: 'On' }, { Title: 'Действует',
  Subtitle: 'Выключите, чтобы поставить план на паузу: он пропадёт с экрана «Сегодня».' });
active.name = 'Действует';
add(form, sized(active, 'fill'));
await place(CARE_AREA, 2, edit, '06_care_plan_form_edit_full.png');
return { fresh: fresh.id, freshH: fresh.height, edit: edit.id, editH: edit.height };
