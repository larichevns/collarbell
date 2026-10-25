// Screen: «Отметить выполнение» for Мурка's overdue rabies plan (06_care_done_full).
// Run: python3 bridge.py run jobs/_screens.js jobs/s06_care_kit.js jobs/s06_care_done.js
await cbSetup();

// What is being marked done: the plan, the pet and interval, and how late it is.
const due = await inst('Status line', { Status: 'Overdue' });
setText(due, 'text', 'Просрочено на 3 дня · 29 сент. 2026 г.');
const header = box({ name: 'План', dir: 'H', gap: 12, w: 'fill' }, [
  kindDisc('vaccines'),
  box({ name: 'texts', dir: 'V', gap: 4, w: 'fill' }, [
    await text('Бешенство', 'title', 'ink', { name: 'title', w: 'fill' }),
    await text('Мурка · Раз в год', 'body-sm', 'ink-muted', { name: 'subtitle', w: 'fill' }),
    due,
  ]),
]);

const fields = box({ name: 'fields', dir: 'V', gap: 16, w: 'fill' }, [
  await dateField('Когда сделано', '2 окт. 2026 г.'),
  await field('Препарат', 'Nobivac Rabies'),
  await field('Производитель', ''),
  await field('Номер серии', '', { mono: true }),
  await dateField('Действует с', 'Не указана', { muted: true }),
  await dateField('Действует до', 'Не указана',
    { muted: true, hint: 'Как на наклейке вакцины. Следующий срок будет по этой дате.' }),
  await field('Клиника', ''),
  await field('Ветеринар', ''),
  await field('Заметки', ''),
]);

// The plan's next date after this «Done» and how it was worked out. The text button sits in
// the app's 48-high tap area.
const change = await inst('Button', { Style: 'Text', State: 'Default' }, { Label: 'Изменить' });
const next = card([
  await text('Следующий раз', 'label', 'ink', { name: 'title' }),
  box({ name: 'date', dir: 'V', w: 'fill' }, [
    await text('2 окт. 2027 г.', 'subtitle', 'ink', { name: 'date', w: 'fill' }),
    await text('Раз в год от этой даты', 'body-sm', 'ink-muted', { name: 'explanation', w: 'fill' }),
  ]),
  box({ name: 'actions', dir: 'H', pad: [2, 0, 2, 0] }, [change]),
], { name: 'Следующий раз', pad: 16, gap: 8 });

const content = careContent(24, [header, fields, next, await photosField(null)]);
const frame = await careScreen('Отметка выполнения — форма', 'Отметить выполнение', 'None', content, true);
await place(CARE_AREA, 3, frame, '06_care_done_full.png');
return { done: frame.id, height: frame.height };
