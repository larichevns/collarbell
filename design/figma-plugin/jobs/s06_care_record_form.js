// Screens: the care record form, new and edit (Мурка's rabies vaccination)
// (06_care_record_form_new_full, 06_care_record_form_edit_full).
// Run: python3 bridge.py run jobs/_screens.js jobs/s06_care_kit.js jobs/s06_care_record_form.js
await cbSetup();

const fields = box({ name: 'fields', dir: 'V', gap: 16, w: 'fill' }, [
  await kindSelect(),
  await field('Название', 'Бешенство'),
  await dateField('Дата', '2 окт. 2026 г.'),
  await targetChips('Бешенство'),
  await field('Препарат', ''),
  await field('Производитель', ''),
  await field('Номер серии', '', { mono: true }),
  await dateField('Действует с', 'Не указана', { muted: true }),
  await dateField('Действует до', 'Не указана', { muted: true }),
  await field('Клиника', ''),
  await field('Ветеринар', ''),
  await field('Заметки', ''),
]);
// The record form leaves 32 before «Фото».
const content = careContent(32, [fields, await photosField(null)]);
const fresh = await careScreen('Запись ухода — новая', 'Новая запись', 'None', content, true);
// The edit form is a copy of this one (made before placing, so place() can't take it for an old one).
await cbDone();
const edit = fresh.clone();
await place(CARE_AREA, 4, fresh, '06_care_record_form_new_full.png');

// Edit: the saved record. It also has the time, the weight with «Может путешествовать»,
// filled-in details and the sticker photo.
edit.name = 'Запись ухода — изменение';
setProp(edit.children[0], 'Title', 'Изменить запись');
const form = edit.findOne((n) => n.name === 'fields');
// Puts a new node right after the field with this name.
function insertAfter(name, node) {
  let anchor = byName(form, name);
  while (anchor.parent !== form) anchor = anchor.parent;
  form.insertChild(form.children.indexOf(anchor) + 1, node);
  applySize(node);
}
setValue(byName(form, 'Дата'), '29 сент. 2025 г.');
insertAfter('Дата', await dateField('Время', '11:15',
  { clear: true, hint: 'Правила въезда отсчитывают часы от обработки.' }));
setValue(byName(form, 'Препарат'), 'Nobivac Rabies');
setValue(byName(form, 'Производитель'), 'MSD Animal Health');
setValue(byName(form, 'Номер серии'), 'A123B01');
for (const [name, date] of [['Действует с', '29 сент. 2025 г.'], ['Действует до', '29 сент. 2026 г.']]) {
  setValue(byName(form, name), date);
  setTrailing(byName(form, name), true);
}
const travel = await inst('Switch row', { Value: 'Off' }, { Title: 'Может путешествовать', 'Show subtitle': false });
travel.name = 'Может путешествовать';
insertAfter('Действует до', box({ name: 'Вес', dir: 'V', w: 'fill' },
  [await field('Вес, кг', '4,1'), sized(travel, 'fill')]));
setValue(byName(form, 'Клиника'), 'Ветклиника «Айболит»');
setValue(byName(form, 'Ветеринар'), 'Иванова А. С.');
setValue(byName(form, 'Заметки'), 'Перенесла хорошо, вечером была вялой.');
wrapValue(byName(form, 'Заметки'));
const photos = edit.findOne((n) => n.type === 'FRAME' && n.name === 'Фото');
photos.findOne((n) => n.name === 'empty').remove();
add(photos, box({ name: 'photos', dir: 'H', gap: 8, w: 'fill' }, [await photoTile(true)]));
await place(CARE_AREA, 5, edit, '06_care_record_form_edit_full.png');
return { fresh: fresh.id, freshH: fresh.height, edit: edit.id, editH: edit.height };
