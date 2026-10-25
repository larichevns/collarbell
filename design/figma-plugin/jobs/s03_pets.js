// Screens: Pets list and Pets empty (03_pets_*).
await cbSetup();
const AREA = '03 Питомцы';

async function petsScreen(name, body) {
  const fab = await inst('FAB', {}, { Label: 'Добавить питомца' });
  const frame = fitScreen(screen(name, [
    await inst('Screen header', {}, { Title: 'Питомцы', 'Show caption': false }),
    box({ name: 'content', dir: 'V', pad: [0, 16, 16, 16], w: 'fill' }, body),
    await inst('Bottom navigation', { Tab: 'Pets' }),
  ]));
  float(frame, fab, { right: 16, bottom: 96 });
  return frame;
}

const pets = [['Барсик', 'Кошка · Мейн-кун', 'Smoke'], ['Мурка', 'Кошка · Сибирская', 'Ginger'],
  ['Рекс', 'Собака · Немецкая овчарка', 'Cocoa']];
const rows = [];
for (const [petName, about, coat] of pets) {
  if (rows.length) rows.push(divider(68));
  const row = await inst('List row', { Leading: 'Avatar', Trailing: 'Chevron' }, { Title: petName, Subtitle: about });
  rows.push(sized(setAvatar(row, coat, petName[0]), 'fill'));
}
const list = await petsScreen('Питомцы — список', [card(rows)]);
await place(AREA, 0, list, '03_pets_list.png');

const empty = await petsScreen('Питомцы — пусто', [sized(await inst('Empty state', {},
  { Title: 'Пока нет питомцев', Message: 'Здесь появятся ваши кошки и собаки.' }), 'fill')]);
await place(AREA, 1, empty, '03_pets_empty.png');
return { list: list.id, empty: empty.id };
