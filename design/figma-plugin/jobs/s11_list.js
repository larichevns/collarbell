// Screens: Supplies list, the "add" sheet and the "bought" sheet (11_supplies_list,
// _add_sheet, _bought_sheet). Run: bridge.py run jobs/_screens.js jobs/s11_kit.js jobs/s11_list.js
await cbSetup();

// One item as List row: name in body (the app's SupplyRow), brand and status line
// under it, the status in its colour; "Купили" when it's time to buy, else a chevron.
async function supplyRow(name, brand, status, statusColor, glyph, bought) {
  const row = await inst('List row', { Leading: 'Icon', Trailing: bought ? 'Button' : 'Chevron' },
    { Title: name, Subtitle: brand + '\n' + status });
  row.name = name;
  const title = layer(row, 'title');
  await title.setTextStyleIdAsync(CB.text.body.id);
  title.maxLines = 1;
  title.textTruncation = 'ENDING';
  const sub = row.findOne((n) => n.type === 'TEXT' && n.name === 'subtitle');
  sub.maxLines = 3;
  if (statusColor !== 'ink-muted') sub.setRangeFills(brand.length + 1, sub.characters.length, [tone(statusColor)]);
  const lead = layer(row, 'icon/vaccines');
  lead.characters = glyph;
  lead.fills = [tone('primary')];
  if (bought) {
    nestedProp(row, 'Label', 'Купили');
  } else {
    setNum(row, 'paddingRight', 8);
    layer(row, 'icon/chevron_right').fills = [tone('ink')];
  }
  return sized(row, 'fill');
}

async function listScreen(name) {
  const frame = fitScreen(screen(name, [
    await inst('Screen header', {}, { Title: 'Запасы', 'Show caption': false }),
    box({ name: 'content', dir: 'V', gap: 24, pad: [0, 16, 16, 16], w: 'fill' }, [
      await section('Купить', card([await supplyRow('Royal Canin Sterilised 37', 'Royal Canin',
        'Пора купить · хватит примерно на 2 дня', 'accent-text', 'rice_bowl', true)])),
      await section('В запасе', card([await supplyRow('Древесный наполнитель', 'Cat Step',
        'Хватит примерно на 24 дня', 'ink-muted', 'layers', false)])),
    ]),
    await nav(),
  ]));
  float(frame, await inst('FAB', {}, { Label: 'Добавить' }), { right: 16, bottom: NAV_H + 16 });
  return frame;
}

const list = await listScreen('Запасы — список');
await place(AREA, 0, list, '11_supplies_list.png');

// Ways to add: ListTiles with plain icons, no title.
const addFrame = await listScreen('Запасы — лист «Добавить»');
await sheetOver(addFrame, null, box({ name: 'options', dir: 'V', w: 'fill' }, [
  await tile('qr_code_scanner', 'Сканировать штрихкод', 'Найдём товар в базах', null, true),
  await tile('photo_camera', 'Сфотографировать упаковку', 'AI прочитает название, вес и калорийность'),
  await tile('edit', 'Заполнить вручную'),
]), 8);
await place(AREA, 1, addFrame, '11_supplies_add_sheet.png');

// "Bought": packages of 2 kg, then the main button.
const boughtFrame = await listScreen('Запасы — лист «Купили»');
await sheetOver(boughtFrame, 'Купили: Royal Canin Sterilised 37', box({ name: 'content', dir: 'V', gap: 16, w: 'fill' }, [
  await counter('Упаковок по 2 кг', 1, false),
  await wideButton('Primary', 'Сохранить покупку', true),
]));
await place(AREA, 2, boughtFrame, '11_supplies_bought_sheet.png');
return { list: list.id, add: addFrame.id, bought: boughtFrame.id };
