// Screen: one care record, «Бешенство» (06_care_record_detail_full).
// Run: python3 bridge.py run jobs/_screens.js jobs/s06_care_kit.js jobs/s06_care_record_detail.js
await cbSetup();

// Every filled-in detail (CbDetailRow): a muted caption above its value; the batch in code style.
const details = [
  ['Тип', 'Прививка'],
  ['Дата', '29 сент. 2025 г., 11:15'],
  ['От чего защищает', 'Бешенство'],
  ['Препарат', 'Nobivac Rabies'],
  ['Производитель', 'MSD Animal Health'],
  ['Номер серии', 'A123B01', true],
  ['Действует с', '29 сент. 2025 г.'],
  ['Действует до', '29 сент. 2026 г.'],
  ['Вес, кг', '4,1 кг'],
  ['Клиника', 'Ветклиника «Айболит»'],
  ['Ветеринар', 'Иванова А. С.'],
  ['Заметки', 'Перенесла хорошо, вечером была вялой.'],
  ['Источник', 'Внесено вручную'],
];
const rows = [];
for (const [label, value, mono] of details) {
  rows.push(box({ name: label, dir: 'V', gap: 4, pad: [8, 0, 8, 0], w: 'fill' }, [
    await text(label, 'caption', 'ink-muted', { name: 'label', w: 'fill' }),
    await text(value, mono ? 'code' : 'body', 'ink', { name: 'value', w: 'fill' }),
  ]));
}

const content = careContent(24, [
  await section('Фото', box({ name: 'photos', dir: 'H', gap: 8, w: 'fill' }, [await photoTile(false)])),
  await section('Сведения', card(rows, { name: 'details', pad: 16 })),
]);
const frame = await careScreen('Запись ухода — просмотр', 'Бешенство', 'Edit + Menu', content, false);
await place(CARE_AREA, 6, frame, '06_care_record_detail_full.png');
return { detail: frame.id, height: frame.height };
