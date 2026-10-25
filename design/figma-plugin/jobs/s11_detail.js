// Screens: one item's page (11_supplies_detail_full) and the "how much is left" sheet
// over it (11_supplies_count_sheet). Run: bridge.py run jobs/_screens.js jobs/s11_kit.js jobs/s11_detail.js
await cbSetup();

// A feeding that uses this food: List row without leading, 72 high like a ListTile.
async function feedingRow(pet, portion) {
  const row = await inst('List row', { Leading: 'None', Trailing: 'Chevron' }, { Title: pet, Subtitle: portion });
  row.name = pet;
  setNum(row, 'paddingTop', 14);
  setNum(row, 'paddingBottom', 14);
  return sized(row, 'fill');
}

async function detailBody() {
  const forecast = card([box({ name: 'row', dir: 'H', gap: 12, w: 'fill' }, [
    icon('rice_bowl', 24, 'primary'),
    box({ name: 'texts', dir: 'V', gap: 4, w: 'fill' }, [
      await text('Хватит примерно на 2 дня', 'subtitle', 'accent-text', { w: 'fill', name: 'headline' }),
      await text('Осталось ≈ 400 г (≈ 0,2 уп.)', 'body-sm', 'ink', { w: 'fill' }),
      await text('Закончится около 4 октября', 'body-sm', 'ink', { w: 'fill' }),
      await text('Купить до 29 сентября · доставка 5 дней', 'body-sm', 'ink', { w: 'fill' }),
      await text('Расход 170 г в день — по кормлениям', 'body-sm', 'ink', { w: 'fill' }),
    ]),
  ])], { name: 'Прогноз', pad: 16 });
  const actions = box({ name: 'actions', dir: 'H', gap: 12, w: 'fill' }, [
    await pill('primary', 'add_shopping_cart', 'Купили', { w: 'fill', filled: true }),
    await pill('outline', 'tune', 'Уточнить остаток', { w: 'fill', wrap: true, filled: true }),
  ]);
  const undo = () => iconTap('undo', 'ink-muted', true);
  return box({ name: 'content', dir: 'V', gap: 24, pad: 16, w: 'fill' }, [
    box({ name: 'top', dir: 'V', gap: 16, w: 'fill' }, [forecast, actions]),
    await section('Кормления с этим кормом', card([
      await feedingRow('Барсик', '45 г × 2 в день'),
      await feedingRow('Мурка', '40 г × 2 в день'),
    ])),
    await section('О товаре', card([
      await fact('Что это', 'Сухой корм'),
      await fact('Бренд', 'Royal Canin'),
      await fact('Упаковка', '2 кг'),
      await fact('Калорийность, ккал/кг', '3890 ккал/кг'),
      await fact('Дней на доставку', '5 дней'),
      await fact('Штрихкод', '3182550702416'),
      await fact('Заметки', 'Брать большую упаковку, 4 кг, если есть скидка.'),
      box({ name: 'store', dir: 'V', pad: [10, 0, 2, 0] }, [await pill('text', 'open_in_new', 'Открыть магазин', { filled: true })]),
    ], { pad: 16 })),
    await section('Покупки и остатки', card([
      await tile('tune', 'Осталось 600 г', '1 окт. · вы', undo(), true),
      await tile('add_shopping_cart', 'Куплено +2 кг', '20 сент. · Сергей', undo(), true),
    ])),
  ]);
}

const detail = screen('Товар — карточка', [
  await appBar('Royal Canin Sterilised 37', 'Edit + Menu'),
  await detailBody(),
  await nav(),
]);
await place(AREA, 3, detail, '11_supplies_detail_full.png');

// The sheet over the top of the page: the page is cut at the phone's height.
const body = await detailBody();
body.name = 'page';
const countFrame = screen('Товар — лист «Сколько осталось»', [
  await appBar('Royal Canin Sterilised 37', 'Edit + Menu'),
  box({ name: 'content', dir: 'V', w: 'fill', h: PHONE_H - 56 - NAV_H, clip: true }, [body]),
  await nav(),
]);
await sheetOver(countFrame, 'Сколько осталось: Royal Canin Sterilised 37', box({ name: 'content', dir: 'V', gap: 16, w: 'fill' }, [
  await counter('Закрытых упаковок по 2 кг', 0, false),
  box({ name: 'open package', dir: 'V', w: 'fill' }, [
    await text('В открытой упаковке: ~20%', 'body', 'ink', { w: 'fill' }),
    slider(0.2, 358),
    await text('Всего ≈ 400 г', 'body-sm', 'ink-muted', { w: 'fill' }),
  ]),
  box({ name: 'buttons', dir: 'V', gap: 8, w: 'fill' }, [
    await wideButton('Primary', 'Сохранить', true),
    box({ name: 'nothing left', dir: 'V', pad: [2, 0], w: 'fill' }, [await wideButton('Text', 'Закончился')]),
  ]),
]));
await place(AREA, 4, countFrame, '11_supplies_count_sheet.png');
return { detail: detail.id, count: countFrame.id };
