// Components: App bar, Screen header, Bottom navigation, Tab bar.
await cbSetup();
await dsClean(['App bar', 'Screen header', 'Bottom navigation', 'Tab bar']);
const FULL = CB.numValue['radius-full'];
const tapBox = (glyph, filled) => box({ name: glyph, dir: 'H', w: 48, h: 48, align: 'center', justify: 'center' },
  [icon(glyph, 24, 'ink', filled)]);

const bars = [];
for (const [name, actions] of [['None', []], ['Menu', ['more_vert']], ['Edit + Menu', ['edit', 'more_vert']]]) {
  bars.push(component('Actions=' + name, { dir: 'H', w: 390, h: 64, pad: [0, 4, 0, 4], fill: 'paper', align: 'center' }, [
    tapBox('arrow_back', true),
    box({ name: 'title wrap', dir: 'H', pad: [0, 0, 0, 20], w: 'fill' },
      [await text('Мурка', 'title', 'ink', { name: 'title', w: 'fill', lines: 1 })]),
    ...actions.map((glyph) => tapBox(glyph, glyph === 'more_vert')),
  ]));
}
const appBar = variantSet('App bar', bars, 'Верхняя панель вложенных экранов: «назад», заголовок (title), действия.');
linkProperty(appBar, 'Title', 'TEXT', 'Мурка', 'title');

const header = component('Screen header', { dir: 'V', w: 390, pad: [32, 16, 16, 16], gap: 4 }, [
  await text('Пятница, 2 октября', 'caption', 'ink-muted', { name: 'caption' }),
  await text('Сегодня', 'display-lg', 'ink', { name: 'title' }),
]);
header.description = 'Заголовок вкладок нижнего меню: подпись (дата) и большой заголовок display-lg.';
linkProperty(header, 'Title', 'TEXT', 'Сегодня', 'title');
linkProperty(header, 'Caption', 'TEXT', 'Пятница, 2 октября', 'caption');
linkProperty(header, 'Show caption', 'BOOLEAN', true, 'caption');

const destinations = [['Today', 'today', 'Сегодня'], ['Pets', 'pets', 'Питомцы'],
  ['Supplies', 'inventory_2', 'Запасы'], ['More', 'more_horiz', 'Ещё']];
const navs = [];
for (const [selected] of destinations) {
  const items = [];
  for (const [key, glyph, label] of destinations) {
    const on = key === selected;
    items.push(box({ name: label, dir: 'V', pad: [12, 0, 16, 0], gap: 4, align: 'center', w: 'fill' }, [
      box({ name: 'indicator', dir: 'H', w: 64, h: 32, radius: FULL, fill: on ? 'primary-soft' : null,
        align: 'center', justify: 'center' }, [icon(glyph, 24, on ? 'primary' : 'ink-muted', on || glyph === 'more_horiz')]),
      await text(label, 'caption', on ? 'primary' : 'ink-muted', { name: 'label' }),
    ]));
  }
  navs.push(component('Tab=' + selected, { dir: 'H', w: 390, h: 80, fill: 'surface', stroke: 'line',
    strokeSides: { top: 1 } }, items));
}
const nav = variantSet('Bottom navigation', navs,
  'Нижнее меню: четыре вкладки. Выбранная — заливка primary-soft и закрашенная иконка primary.');

const tabs = [['Overview', 'Обзор'], ['Health', 'Здоровье'], ['Passport', 'Паспорт'],
  ['Documents', 'Документы'], ['Feeding', 'Кормление']];
const tabBars = [];
for (const [selected] of tabs) {
  const row = [];
  for (const [key, label] of tabs) {
    const on = key === selected;
    const word = await text(label, 'label', on ? 'primary' : 'ink-muted', { name: 'label' });
    row.push(box({ name: label, dir: 'V', pad: [0, 12, 0, 12], align: 'center' }, [
      box({ name: 'label box', dir: 'H', h: 45, align: 'center' }, [word]),
      box({ name: 'indicator', w: Math.ceil(word.width), h: 3, radius: [3, 3, 0, 0], fill: on ? 'primary' : null }),
    ]));
  }
  const late = selected === 'Documents' || selected === 'Feeding';
  tabBars.push(component('Tab=' + selected, { dir: 'H', w: 390, h: 48, clip: true, justify: late ? 'end' : 'start',
    fill: 'paper', stroke: 'line', strokeSides: { bottom: 1 } }, [box({ name: 'tabs', dir: 'H' }, row)]));
}
const tabBar = variantSet('Tab bar', tabBars,
  'Вкладки страницы питомца. Прокручиваются, если не помещаются; выбранная — primary с полоской снизу.');

await dsSection('Верхняя панель', 'App bar · Actions None / Menu / Edit + Menu. Свойство Title.', [appBar]);
await dsSection('Заголовок экрана', 'Screen header · вкладки нижнего меню. Свойства Title, Caption, Show caption.', [header]);
await dsSection('Нижнее меню', 'Bottom navigation · Tab Today / Pets / Supplies / More.', [nav]);
await dsSection('Вкладки питомца', 'Tab bar · Tab Overview / Health / Passport / Documents / Feeding.', [tabBar]);
await cbDone();
await bridge.shot(await dsFrame(), '11_components_b');
return { appBar: appBar.id, header: header.id, nav: nav.id, tabBar: tabBar.id };
