// Components: List row, Section header, Empty state, Select field, Switch row.
// Needs Pet avatar and Switch (job 10) and the Button set.
await cbSetup();
await dsClean(['List row', 'Section header', 'Empty state', 'Select field', 'Switch row']);
const FULL = CB.numValue['radius-full'];

async function leading(kind) {
  if (kind === 'Avatar') return inst('Pet avatar', { Size: '40', Coat: 'Ginger' });
  if (kind === 'Icon') {
    return box({ name: 'icon disc', dir: 'H', w: 40, h: 40, radius: FULL, fill: 'sunken', align: 'center', justify: 'center' },
      [icon('vaccines', 22, 'ink-muted')]);
  }
  return null;
}
async function trailing(kind) {
  if (kind === 'Chevron') return icon('chevron_right', 24, 'ink-muted', true);
  if (kind === 'Done') {
    return box({ name: 'done', dir: 'H', w: 44, h: 44, radius: FULL, stroke: 'line-strong', strokeW: 2,
      align: 'center', justify: 'center' }, [icon('check', 24, 'primary', true)]);
  }
  if (kind === 'Button') return inst('Button', { Style: 'Primary', State: 'Default' }, { Label: 'Покормили' });
  return null;
}
const rows = [];
for (const lead of ['Avatar', 'Icon', 'None']) {
  for (const trail of ['None', 'Chevron', 'Done', 'Button']) {
    const tight = trail === 'Done' || trail === 'Button';
    rows.push(component(`Leading=${lead}, Trailing=${trail}`, {
      dir: 'H', w: 358, pad: [12, tight ? 8 : 16, 12, 16], gap: 12, align: 'center' }, [
      await leading(lead),
      box({ name: 'texts', dir: 'V', w: 'fill' }, [
        await text('Мурка', 'subtitle', 'ink', { name: 'title', w: 'fill', lines: 1 }),
        await text('Royal Canin Sterilised 37, 40 г', 'body-sm', 'ink-muted', { name: 'subtitle', w: 'fill', lines: 2 }),
      ]),
      await trailing(trail),
    ]));
  }
}
const rowSet = variantSet('List row', rows,
  'Строка списка внутри карточки: слева аватар или иконка, справа стрелка, кнопка «Готово» или кнопка действия.');
linkProperty(rowSet, 'Title', 'TEXT', 'Мурка', 'title');
linkProperty(rowSet, 'Subtitle', 'TEXT', 'Royal Canin Sterilised 37, 40 г', 'subtitle');
linkProperty(rowSet, 'Show subtitle', 'BOOLEAN', true, 'subtitle');

const headers = [];
for (const [style, words] of [['Title', 'Визиты'], ['Subtitle', 'Просрочено']]) {
  headers.push(component('Style=' + style, { dir: 'H', w: 358, gap: 8, align: 'center' }, [
    await text(words, style === 'Title' ? 'title' : 'subtitle', style === 'Title' ? 'ink' : 'ink-muted',
      { name: 'title', w: 'fill' }),
    await inst('Button', { Style: 'Text', State: 'Default' }, { Label: 'Все визиты' }),
  ]));
  headers[headers.length - 1].findOne((n) => n.type === 'INSTANCE').name = 'action';
}
const headerSet = variantSet('Section header', headers, 'Заголовок раздела с необязательной текстовой кнопкой справа.');
linkProperty(headerSet, 'Title', 'TEXT', 'Визиты', 'title');
linkProperty(headerSet, 'Show action', 'BOOLEAN', true, 'action');

const empty = component('Empty state', { dir: 'V', w: 390, pad: [48, 24, 48, 24], gap: 16, align: 'center' }, [
  box({ name: 'disc', dir: 'H', w: 64, h: 64, radius: FULL, fill: 'sunken', align: 'center', justify: 'center' },
    [icon('pets', 28, 'ink-muted')]),
  box({ name: 'texts', dir: 'V', gap: 8, align: 'center', w: 'fill' }, [
    await text('Пока нет питомцев', 'title', 'ink', { name: 'title', w: 'fill', align: 'CENTER' }),
    await text('Добавьте первого — с него начнутся напоминания.', 'body', 'ink-muted',
      { name: 'message', w: 'fill', align: 'CENTER' }),
  ]),
  await inst('Button', { Style: 'Primary', State: 'Default' }, { Label: 'Добавить питомца' }),
]);
empty.children[2].name = 'button';
empty.description = 'Пустой экран: иконка на сером круге, заголовок, строка пояснения, необязательная кнопка.';
linkProperty(empty, 'Title', 'TEXT', 'Пока нет питомцев', 'title');
linkProperty(empty, 'Message', 'TEXT', 'Добавьте первого — с него начнутся напоминания.', 'message');
linkProperty(empty, 'Show button', 'BOOLEAN', false, 'button');

const select = component('Select field', { dir: 'V', w: 358, gap: 8 }, [
  await text('Тип', 'label', 'ink', { name: 'label' }),
  box({ name: 'field', dir: 'H', w: 'fill', pad: [12, 16, 12, 16], gap: 12, align: 'center', fill: 'surface',
    stroke: 'line-strong', radius: CB.numValue['radius-md'] }, [
    icon('vaccines', 24, 'ink-muted'),
    await text('Прививка', 'body', 'ink', { name: 'value', w: 'fill' }),
    icon('arrow_drop_down', 24, 'ink-muted', true),
  ]),
]);
select.findOne((n) => n.name === 'icon/vaccines').name = 'icon';
select.description = 'Поле выбора из списка (тип записи, питомец, единица).';
linkProperty(select, 'Label', 'TEXT', 'Тип', 'label');
linkProperty(select, 'Value', 'TEXT', 'Прививка', 'value');
linkProperty(select, 'Show icon', 'BOOLEAN', true, 'icon');

const switchRows = [];
for (const value of ['On', 'Off']) {
  switchRows.push(component('Value=' + value, { dir: 'H', w: 358, pad: [12, 0, 12, 0], gap: 16, align: 'center' }, [
    box({ name: 'texts', dir: 'V', w: 'fill' }, [
      await text('Действует', 'body', 'ink', { name: 'title', w: 'fill' }),
      await text('Напоминать о кормлении в это время', 'body-sm', 'ink-muted', { name: 'subtitle', w: 'fill' }),
    ]),
    await inst('Switch', { Value: value }),
  ]));
}
const switchRowSet = variantSet('Switch row', switchRows, 'Строка с переключателем в формах и настройках.');
linkProperty(switchRowSet, 'Title', 'TEXT', 'Действует', 'title');
linkProperty(switchRowSet, 'Subtitle', 'TEXT', 'Напоминать о кормлении в это время', 'subtitle');
linkProperty(switchRowSet, 'Show subtitle', 'BOOLEAN', true, 'subtitle');

await dsSection('Строка списка', 'List row · Leading Avatar / Icon / None × Trailing None / Chevron / Done / Button.', [rowSet]);
await dsSection('Заголовок раздела', 'Section header · Title / Subtitle; Show action.', [headerSet]);
await dsSection('Пустой экран', 'Empty state · Title, Message, Show button.', [empty]);
await dsSection('Поле выбора', 'Select field · Label, Value, Show icon.', [select]);
await dsSection('Строка с переключателем', 'Switch row · On / Off.', [switchRowSet]);
await cbDone();
await bridge.shot(await dsFrame(), '12_components_c', 0.5);
return { rowSet: rowSet.id, headerSet: headerSet.id, empty: empty.id, select: select.id, switchRowSet: switchRowSet.id };
