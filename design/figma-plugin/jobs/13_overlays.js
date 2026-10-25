// Components: Save bar, Offline strip, Skeleton, Dialog, Bottom sheet.
await cbSetup();
await dsClean(['Save bar', 'Offline strip', 'Skeleton', 'Dialog', 'Bottom sheet', '.Slot', 'FAB']);
const FULL = CB.numValue['radius-full'];
const SM = CB.numValue['radius-sm'];
const MD = CB.numValue['radius-md'];
const LG = CB.numValue['radius-lg'];
// Recolours the label of a Button instance.
function labelColor(button, color) {
  button.findOne((n) => n.type === 'TEXT').fills = [paint(color)];
  return button;
}

const notice = await inst('Notice', { Kind: 'Error' });
setText(notice, 'message', 'Проверьте отмеченные поля');
notice.name = 'error';
const save = await inst('Button', { Style: 'Primary', State: 'Default' }, { Label: 'Сохранить' });
const saveBar = component('Save bar', { dir: 'V', w: 390, pad: 16, gap: 12, fill: 'surface', stroke: 'line',
  strokeSides: { top: 1 } }, [sized(notice, 'fill'), sized(save, 'fill')]);
save.resize(save.width, CB.numValue['control-lg']);
saveBar.description = 'Низ формы: кнопка «Сохранить» на всю ширину; над ней ошибка, если форма не прошла проверку.';
linkProperty(saveBar, 'Show error', 'BOOLEAN', false, 'error');

const retry = labelColor(await inst('Button', { Style: 'Text', State: 'Default' }, { Label: 'Повторить' }), 'on-inverse');
const strip = component('Offline strip', { dir: 'H', w: 390, h: 48, pad: [0, 8, 0, 16], gap: 12, align: 'center',
  fill: 'inverse-surface' }, [
  icon('cloud_off', 20, 'on-inverse'),
  await text('Нет связи с сервером · данные на 14:05', 'body-sm', 'on-inverse', { name: 'message', w: 'fill', lines: 2 }),
  retry,
]);
strip.description = 'Полоска над нижним меню, когда сервер не отвечает: время самой старой копии на экране.';
linkProperty(strip, 'Message', 'TEXT', 'Нет связи с сервером · данные на 14:05', 'message');

const block = (w, h, r) => box({ name: 'block', w, h, radius: r == null ? SM : r, fill: 'line' });
const listRows = [];
for (let row = 0; row < 4; row++) {
  listRows.push(box({ name: 'row', dir: 'H', pad: [12, 0, 12, 0], gap: 12, align: 'center', w: 'fill' }, [
    block(40, 40, FULL),
    box({ name: 'lines', dir: 'V', gap: 8 }, [block(row % 2 ? 168 : 214, 14), block(row % 2 ? 153 : 122, 12)]),
  ]));
}
const formFields = [];
for (let field = 0; field < 5; field++) {
  formFields.push(box({ name: 'field', dir: 'V', gap: 8, w: 'fill' }, [block(field % 2 ? 143 : 107, 12),
    sized(block(358, 48, MD), 'fill')]));
}
const skeletons = [
  component('Shape=List', { dir: 'V', w: 390, pad: 16, fill: 'paper' }, listRows),
  component('Shape=Form', { dir: 'V', w: 390, pad: 16, gap: 20, fill: 'paper' }, formFields),
];
const skeletonSet = variantSet('Skeleton', skeletons,
  'Пока данные грузятся: серые блоки line на месте будущего содержимого, по ним бежит мягкий блик (sunken).');

const cancel = await inst('Button', { Style: 'Text', State: 'Default' }, { Label: 'Отмена' });
const confirm = labelColor(await inst('Button', { Style: 'Text', State: 'Default' }, { Label: 'Удалить' }), 'danger');
confirm.name = 'confirm';
const dialog = component('Dialog', { dir: 'V', w: 310, pad: 24, gap: 24, fill: 'surface', radius: LG,
  effect: 'Light/shadow-lg' }, [
  box({ name: 'texts', dir: 'V', gap: 16, w: 'fill' }, [
    await text('Удалить питомца по кличке Мурка?', 'title', 'ink', { name: 'title', w: 'fill' }),
    await text('Вместе с ним удалятся данные паспорта, документы и фото. Отменить это нельзя.', 'body', 'ink',
      { name: 'message', w: 'fill' }),
  ]),
  box({ name: 'actions', dir: 'H', gap: 8, justify: 'end', w: 'fill' }, [cancel, confirm]),
]);
dialog.description = 'Диалог подтверждения. Опасное действие — текстовая кнопка цвета danger.';
linkProperty(dialog, 'Title', 'TEXT', 'Удалить питомца по кличке Мурка?', 'title');
linkProperty(dialog, 'Message', 'TEXT', 'Вместе с ним удалятся данные паспорта, документы и фото. Отменить это нельзя.', 'message');

const slot = component('.Slot', { dir: 'H', w: 358, h: 120, radius: MD, fill: 'sunken', align: 'center', justify: 'center' },
  [await text('Содержимое', 'caption', 'ink-muted')]);
slot.description = 'Заглушка содержимого нижнего листа: замените через свойство Content.';
const slotInstance = slot.createInstance();
slotInstance.name = 'content';
const sheet = component('Bottom sheet', { dir: 'V', w: 390, fill: 'surface', radius: [LG, LG, 0, 0] }, [
  box({ name: 'handle area', dir: 'H', h: 48, w: 'fill', align: 'center', justify: 'center' },
    [box({ name: 'handle', w: 32, h: 4, radius: FULL, fill: 'line-strong' })]),
  box({ name: 'body', dir: 'V', pad: [0, 16, 16, 16], gap: 16, w: 'fill' }, [
    await text('Купили: Royal Canin Sterilised 37', 'title', 'ink', { name: 'title', w: 'fill' }),
    sized(slotInstance, 'fill'),
  ]),
]);
sheet.description = 'Нижний лист: ручка, заголовок и содержимое (свойство Content).';
linkProperty(sheet, 'Title', 'TEXT', 'Купили: Royal Canin Sterilised 37', 'title');
const contentKey = sheet.addComponentProperty('Content', 'INSTANCE_SWAP', slot.id);
sheet.findOne((n) => n.name === 'content').componentPropertyReferences = { mainComponent: contentKey };

const fab = component('FAB', { dir: 'H', h: 56, pad: [0, 20, 0, 16], gap: 12, align: 'center', fill: 'primary',
  radius: FULL, effect: 'Light/shadow-sm' }, [
  icon('add', 24, 'on-primary', true),
  await text('Добавить питомца', 'label', 'on-primary', { name: 'label' }),
]);
fab.findOne((n) => n.name === 'icon/add').name = 'icon';
fab.description = 'Плавающая кнопка списка: «Добавить питомца», «Добавить товар», «Новый визит».';
linkProperty(fab, 'Label', 'TEXT', 'Добавить питомца', 'label');

await dsSection('Плавающая кнопка', 'FAB · Label. Справа внизу над нижним меню, отступ 16.', [fab]);
await dsSection('Кнопка «Сохранить»', 'Save bar · Show error.', [saveBar]);
await dsSection('Нет связи', 'Offline strip · Message.', [strip]);
await dsSection('Скелетон загрузки', 'Skeleton · List / Form.', [skeletonSet]);
await dsSection('Диалог', 'Dialog · Title, Message.', [dialog]);
await dsSection('Нижний лист', 'Bottom sheet · Title, Content (.Slot — заглушка).', [box({ name: 'sheet row', dir: 'H', gap: 24 }, [sheet, slot])]);
await cbDone();
await bridge.shot(await dsFrame(), '13_components_d', 0.5);
return { fab: fab.id, saveBar: saveBar.id, strip: strip.id, skeletonSet: skeletonSet.id, dialog: dialog.id, sheet: sheet.id };
