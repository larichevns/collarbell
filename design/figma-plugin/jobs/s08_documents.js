// Screens: Document form (new, edit) and Document detail (08_documents_*).
await cbSetup();
const AREA = '08 Документы';
const FULL = CB.numValue['radius-full'];
const SM = CB.numValue['radius-sm'];
const PAGE = await bridge.ref('crop_s08_doc_page.png');
const byName = (root, name) => root.findOne((n) => n.name === name);

// Sets a component property (text, boolean or variant) by its short name.
function prop(node, short, value) {
  const key = Object.keys(node.componentProperties).find((k) => k.split('#')[0] === short);
  node.setProperties({ [key]: value });
  return node;
}

// The App bar, its title ending 16 before the actions as in the app (long titles cut).
async function appBar(title, actions) {
  const bar = await inst('App bar', { Actions: actions || 'None' }, { Title: title });
  bar.name = 'App bar';
  bar.resize(PHONE_W, 56);
  bindNum(bar.findOne((n) => n.name === 'title wrap'), 'paddingRight', 16, 'space-'); // the app's 16 before actions
  const titleText = bar.findOne((n) => n.name === 'title');
  titleText.maxLines = 1; // one line, cut with …
  titleText.textTruncation = 'ENDING';
  return bar;
}

// Puts a value (ink) or a hint (ink-muted) into a Text field; long values wrap.
function setValue(f, value, hint) {
  const words = value || hint || '';
  if (f.type === 'INSTANCE') prop(f, 'Value', words);
  else byName(f, 'value').characters = words;
  const v = byName(f, 'value');
  v.fills = [paint(value ? 'ink' : 'ink-muted')];
  v.textAutoResize = 'HEIGHT';
  try {
    v.layoutSizingHorizontal = 'FILL';
  } catch (e) { // if an instance refuses it: a fixed width that wraps
    const row = v.parent;
    v.resize(row.width - row.paddingLeft - row.paddingRight, v.height);
    bridge.log('fixed width for ' + f.name + ': ' + e.message);
  }
  return f;
}

// A Text field. `trail`: an icon at the end (date fields). The component has
// no icon slot, so such a field is a detached Text field.
async function field(label, value, hint, trail) {
  let f = await inst('Text field', { State: 'Default' }, { Label: label, 'Show hint': false });
  if (trail) f = f.detachInstance();
  f.name = label;
  setValue(f, value, hint);
  if (trail) {
    const row = byName(f, 'field');
    add(row, icon(trail, 24, 'ink-muted', trail === 'close'));
    row.setBoundVariable('paddingRight', CB.num['space-3']);
  }
  return sized(f, 'fill');
}

// Turns a trailing icon into another one (calendar → close once a date is set).
function swapIcon(node, glyph) {
  node.fontName = ICON_FILLED;
  node.characters = glyph;
  node.name = 'icon/' + glyph;
}

// A section title: Section header (44 high, 48 next to a button), with an
// optional action beside it.
async function sectionTitle(title, action) {
  const h = await inst('Section header', { Style: 'Title' }, { Title: title, 'Show action': false });
  h.name = 'Section header';
  if (action) h.resize(h.width, 48); // as high as the button beside it
  if (!action) return sized(h, 'fill');
  return box({ name: 'Заголовок · ' + title, dir: 'H', w: 'fill', align: 'center' }, [sized(h, 'fill'), action]);
}

// «Добавить страницы»: a text button with an icon (Button has no icon).
async function addPages() {
  return box({ name: 'Добавить страницы', dir: 'H', h: 44, pad: [0, 12], gap: 8, align: 'center', radius: FULL }, [
    icon('add_a_photo', 18, 'primary'), await text('Добавить страницы', 'label', 'primary', { name: 'label' })]);
}

// A page tile (three in a row, 3:4): the photo, or a grey PDF tile. The app's
// tile border lies under the picture, so none shows. `remove` adds the × button.
async function tile(pdf, remove) {
  const t = box({ name: pdf ? 'Страница · PDF' : 'Страница · фото', dir: 'V', w: 114, h: 152, radius: SM,
    clip: true, fill: pdf ? 'sunken' : null, align: 'center', justify: 'center', gap: 4 }, pdf
    ? [icon('picture_as_pdf', 24, 'ink-muted'), await text('PDF', 'caption', 'ink-muted', { name: 'label' })]
    : [picture(PAGE, 114, 152)]);
  if (remove) {
    float(t, box({ name: 'Убрать страницу', dir: 'H', w: 44, h: 44, radius: FULL, fill: 'surface', align: 'center',
      justify: 'center' }, [icon('close', 24, 'ink', true)]), { right: 2, top: 2 });
  }
  return t;
}
async function pageGrid(remove) {
  return box({ name: 'Сетка страниц', dir: 'H', gap: 8 }, [await tile(false, remove), await tile(true, remove)]);
}

// One fact in a details card: a muted caption above its value.
async function detailRow(label, value) {
  return box({ name: label, dir: 'V', gap: 4, pad: [8, 0], w: 'fill' }, [
    await text(label, 'caption', 'ink-muted', { w: 'fill', name: 'label' }),
    await text(value, 'body', 'ink', { w: 'fill', name: 'value' })]);
}

// A long screen: hugs its content, and grows to the app's screenshot height.
function fitTo(frame, h) {
  const content = frame.findChild((n) => n.name === 'content');
  content.layoutGrow = 0;
  frame.primaryAxisSizingMode = 'AUTO';
  if (frame.height < h) {
    content.layoutGrow = 1;
    frame.resize(PHONE_W, h);
  }
  return frame;
}

// --- Document form: new ---
const type = await inst('Select field', {}, { Label: 'Тип', Value: 'Другой документ' });
type.name = 'Тип';
byName(type, 'icon').characters = 'description';
const form = fitScreen(screen('Документ — новый', [
  await appBar('Новый документ'),
  box({ name: 'content', dir: 'V', pad: [16, 16, 48, 16], gap: 16, w: 'fill' }, [
    sized(type, 'fill'),
    await field('Название (необязательно)', '', 'Например, анализ крови'),
    await field('Дата документа', '', 'Не указана', 'calendar_today'),
    await field('Заметки', ''),
    box({ name: 'Страницы', dir: 'V', gap: 8, pad: [16, 0, 0, 0], w: 'fill' }, [
      await sectionTitle('Страницы', await addPages()),
      await text('Сфотографируйте страницы или выберите PDF.', 'body', 'ink-muted', { w: 'fill', name: 'Пусто' }),
    ]),
  ]),
  sized(await inst('Save bar'), 'fill'),
  await inst('Bottom navigation', { Tab: 'Pets' }),
]));
await place(AREA, 0, form, '08_documents_form_new.png');

// --- Document form: edit (a copy of the new form with the document filled in) ---
const edit = form.clone();
edit.name = 'Документ — изменение';
prop(byName(edit, 'App bar'), 'Title', 'Изменить документ');
const editType = byName(edit, 'Тип');
prop(editType, 'Value', 'Анализы');
byName(editType, 'icon').characters = 'science';
setValue(byName(edit, 'Название (необязательно)'), 'Общий анализ крови');
const date = setValue(byName(edit, 'Дата документа'), '15 сент. 2026 г.');
swapIcon(byName(date, 'icon/calendar_today'), 'close');
setValue(byName(edit, 'Заметки'), 'Все показатели в норме. Лаборатория «Вет Юнион».');
byName(edit, 'Пусто').remove();
add(byName(edit, 'Страницы'), await pageGrid(true));
fitTo(edit, 892);
await place(AREA, 1, edit, '08_documents_form_edit_full.png');

// --- Document detail ---
const detail = fitScreen(screen('Документ — карточка', [
  await appBar('Общий анализ крови', 'Edit + Menu'),
  box({ name: 'content', dir: 'V', pad: [16, 16, 48, 16], gap: 24, w: 'fill' }, [
    box({ name: 'Страницы', dir: 'V', gap: 8, w: 'fill' }, [await sectionTitle('Страницы'), await pageGrid(false)]),
    box({ name: 'Сведения', dir: 'V', gap: 8, w: 'fill' }, [await sectionTitle('Сведения'), card([
      await detailRow('Тип', 'Анализы'),
      await detailRow('Дата документа', '15 сент. 2026 г.'),
      await detailRow('Страницы', '2 страницы'),
      await detailRow('Добавлен', '15 сент. 2026 г.'),
      await detailRow('Заметки', 'Все показатели в норме. Лаборатория «Вет Юнион».'),
    ], { pad: 16 })]),
  ]),
  await inst('Bottom navigation', { Tab: 'Pets' }),
]));
await place(AREA, 2, detail, '08_documents_detail.png');
return { form: form.id, edit: edit.id, detail: detail.id };
