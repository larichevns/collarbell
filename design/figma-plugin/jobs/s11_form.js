// Screens: new item form (11_supplies_form_new_full) and, cloned from it, the edit
// form (11_supplies_form_edit_full). Run: bridge.py run jobs/_screens.js jobs/s11_kit.js jobs/s11_form.js
await cbSetup();
const W = PHONE_W - 32;

// A label above any control (CbLabeled).
async function labeled(title, child) {
  return box({ name: title, dir: 'V', gap: 8, w: 'fill' }, [await text(title, 'label', 'ink', { name: 'label' }), child]);
}

const categories = [['Сухой корм', 'rice_bowl'], ['Влажный корм', 'soup_kitchen'], ['Лакомства', 'cookie'],
  ['Наполнитель', 'layers'], ['Препарат', 'medication'], ['Другое', 'inventory_2']];
const chips = [];
for (const [label, glyph] of categories) chips.push(await chip(label, glyph, { selected: label === 'Сухой корм' }));

const size = await field('Упаковка', '2', { placeholder: true, noLabel: true, name: 'Размер упаковки', w: null });
size.resize(112, size.height);
const unit = await inst('Select field', {}, { Label: 'Упаковка', Value: 'кг', 'Show icon': false });
unit.name = 'Единица';
layer(unit, 'label').visible = false;
await layer(unit, 'value').setTextStyleIdAsync(CB.text.subtitle.id);

const stock = box({ name: 'Сколько есть сейчас', dir: 'V', w: 'fill' }, [
  sized(await inst('Switch row', { Value: 'On' }, { Title: 'Указать, сколько есть сейчас',
    Subtitle: 'Обычно это одна закрытая упаковка, которую только что купили' }), 'fill'),
  await counter('Закрытых упаковок по 1 кг', 1, true),
  box({ name: 'open package', dir: 'V', pad: [8, 0, 0, 0], w: 'fill' }, [
    await text('В открытой упаковке: ~0%', 'body', 'ink', { w: 'fill' }),
    slider(0, W),
  ]),
]);

const form = screen('Товар — новый', [
  await appBar('Новый товар'),
  box({ name: 'content', dir: 'V', gap: 20, pad: [16, 16, 48, 16], w: 'fill' }, [
    await field('Название', 'Например, Royal Canin Sterilised 37', { placeholder: true }),
    await field('Бренд', ''),
    await labeled('Что это', chipWrap(chips, W)),
    await labeled('Упаковка', box({ name: 'row', dir: 'H', gap: 8, w: 'fill' }, [size, sized(unit, 'fill')])),
    await field('Калорийность, ккал/кг', '3900', { placeholder: true,
      hint: 'С упаковки: ккал на кг (ккал на 100 г × 10)' }),
    await labeled('Расход', box({ name: 'usage', dir: 'V', gap: 8, w: 'fill' }, [
      await segmented('По кормлениям', 'Вручную'),
      await text('Расход считается из порций кормлений, где выбран этот корм.', 'body-sm', 'ink-muted', { w: 'fill' }),
    ])),
    await field('Дней на доставку', '5', { hint: 'За столько дней до конца придёт напоминание купить' }),
    stock,
    await field('Где купить', 'https://', { placeholder: true, hint: 'Ссылка на товар в магазине — чтобы быстро заказать' }),
    await field('Штрихкод', ''),
    await field('Заметки', ''),
  ]),
  sized(await inst('Save bar'), 'fill'),
  await nav(),
]);
await place(AREA, 5, form, '11_supplies_form_new_full.png');

// Edit: the same form with the item's values, no "how much now", and "Покупаем".
const edit = form.clone();
edit.name = 'Товар — изменение';
setProp(layer(edit, 'App bar'), 'Title', 'Изменить товар');
const values = [['Название', 'Royal Canin Sterilised 37'], ['Бренд', 'Royal Canin'], ['Размер упаковки', '2'],
  ['Калорийность, ккал/кг', '3890'], ['Где купить', 'https://zoomag.example/royal-canin-sterilised-37'],
  ['Штрихкод', '3182550702416'], ['Заметки', 'Брать большую упаковку, 4 кг, если есть скидка.']];
const lines = { 'Где купить': 1, 'Заметки': 3 };
for (const [name, value] of values) setValue(layer(edit, name), value, false, lines[name]);
layer(edit, 'Сколько есть сейчас').remove();
add(layer(edit, 'content'), sized(await inst('Switch row', { Value: 'On' }, { Title: 'Покупаем',
  Subtitle: 'Выключите, если больше не покупаете: напоминаний не будет, история останется' }), 'fill'));
await place(AREA, 6, edit, '11_supplies_form_edit_full.png');
return { form: form.id, edit: edit.id };
