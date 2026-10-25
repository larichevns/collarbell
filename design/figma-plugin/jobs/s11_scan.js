// Screens: barcode scanner (11_supplies_scan_camera), typing the digits
// (_scan_type_code), unknown product (_scan_unknown_product) and package photos
// (_scan_photos). Run: bridge.py run jobs/_screens.js jobs/s11_kit.js jobs/s11_scan.js
await cbSetup();

// The scanner: a full-screen page over the tabs (no nav), the camera view dark, a
// frame where to hold the barcode, a hint and "Ввести цифры" at the bottom.
async function cameraScreen(name) {
  const bar = await appBar('Штрихкод', 'Menu', true);
  const torch = layer(bar, 'icon/more_vert');
  torch.fontName = ICON_OUTLINED;
  torch.characters = 'flashlight_on';
  const cam = box({ name: 'камера', dir: 'none', w: PHONE_W, h: PHONE_H - 56, fill: 'inverse-surface' });
  const finder = box({ name: 'рамка', w: 280, h: 160, radius: CB.numValue['radius-md'], stroke: 'on-inverse', strokeW: 2 });
  const hint = box({ name: 'подсказка', dir: 'V', gap: 12, align: 'center', w: PHONE_W - 32 }, [
    await text('Наведите камеру на штрихкод на упаковке', 'body', 'on-inverse', { w: 'fill', align: 'CENTER' }),
    box({ name: 'tap', dir: 'V', pad: [2, 0] }, [await inst('Button', { Style: 'Primary', State: 'Default' }, { Label: 'Ввести цифры' })]),
  ]);
  for (const [node, x, y] of [[finder, 55, 314], [hint, 16, 0]]) {
    cam.appendChild(node);
    node.x = x;
    node.y = y;
  }
  hint.y = cam.height - 24 - hint.height;
  hint.constraints = { horizontal: 'STRETCH', vertical: 'MAX' };
  finder.constraints = { horizontal: 'CENTER', vertical: 'CENTER' };
  return screen(name, [bar, cam]);
}

const camera = await cameraScreen('Штрихкод — камера');
await place(AREA, 7, camera, '11_supplies_scan_camera.png');

// The digits typed by hand: Dialog with a focused field instead of the message.
const typed = await cameraScreen('Штрихкод — ввод цифр');
const dialog = (await inst('Dialog', {}, { Title: 'Ввести цифры' })).detachInstance();
dialog.name = 'Диалог';
dialog.resize(280, dialog.height);
dialog.layoutSizingVertical = 'HUG';
const message = layer(dialog, 'message');
const code = await field('Цифры', '4607009123455', { state: 'Focused', noLabel: true });
message.parent.insertChild(message.parent.children.indexOf(message), code);
code.layoutSizingHorizontal = 'FILL';
layer(code, 'caret').visible = false; // the component's caret stands before the text
message.remove();
const find = layer(dialog, 'confirm');
setProp(find, 'Label', 'Найти');
find.findOne((n) => n.type === 'TEXT').fills = [tone('primary')];
scrim(typed);
float(typed, dialog, { left: 55, top: 317 });
await place(AREA, 8, typed, '11_supplies_scan_type_code.png');

// A new item's screens inside the Supplies tab: App bar «Новый товар», the nav.
async function newItemScreen(name, children, gap) {
  return fitScreen(screen(name, [
    await appBar('Новый товар'),
    box({ name: 'content', dir: 'V', gap, pad: 16, w: 'fill' }, children),
    await nav(),
  ]));
}

const unknown = await newItemScreen('Новый товар — не найден', [
  card([
    await text('Товар с этим штрихкодом не найден.', 'body', 'ink', { w: 'fill' }),
    await text('Штрихкод 4607009123455', 'body-sm', 'ink-muted', { w: 'fill' }),
  ], { pad: 16, gap: 4 }),
  box({ name: 'buttons', dir: 'V', gap: 8, w: 'fill' }, [
    await pill('primary', 'photo_camera', 'Сфотографировать упаковку', { w: 'fill', h: CB.numValue['control-lg'] }),
    await wideButton('Secondary', 'Заполнить вручную'),
  ]),
], 16);
await place(AREA, 9, unknown, '11_supplies_scan_unknown_product.png');

const notice = await inst('Notice', { Kind: 'Info' });
setText(notice, 'message', 'Фото уходят в бесплатный Gemini: на них не должно быть личных данных.');
const photos = await newItemScreen('Новый товар — фото упаковки', [
  box({ name: 'top', dir: 'V', gap: 12, w: 'fill' }, [
    await text('Сфотографируйте лицевую сторону и сторону с весом и составом — до 3 фото.', 'body', 'ink', { w: 'fill' }),
    sized(notice, 'fill'),
    chipWrap([
      await chip('Фото 1', 'image', { iconColor: 'ink-muted', close: true }),
      await chip('Добавить фото', 'add_a_photo'),
      await chip('Из галереи', 'photo_library'),
    ], PHONE_W - 32),
  ]),
  box({ name: 'buttons', dir: 'V', gap: 8, w: 'fill' }, [
    await wideButton('Primary', 'Прочитать', true),
    box({ name: 'by hand', dir: 'V', pad: [2, 0], w: 'fill' }, [await wideButton('Text', 'Заполнить вручную')]),
  ]),
], 20);
await place(AREA, 10, photos, '11_supplies_scan_photos.png');
return { camera: camera.id, typed: typed.id, unknown: unknown.id, photos: photos.id };
