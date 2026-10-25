// Components: Pet avatar, Status line, Switch.
await cbSetup();
await dsClean(['Pet avatar', 'Status line', 'Switch']);

const coats = ['Ginger', 'Fawn', 'Cocoa', 'Smoke', 'Lilac', 'Ink'];
const avatars = [];
for (const size of [28, 40, 64]) {
  for (const coat of coats) {
    const initial = await text('М', 'numeral', 'on-coat', { name: 'initial' });
    initial.fontSize = Math.round(size * 0.45);
    initial.lineHeight = { unit: 'PERCENT', value: 100 };
    const c = component(`Size=${size}, Coat=${coat}`, {
      dir: 'H', w: size, h: size, radius: CB.numValue['radius-full'],
      fill: 'coat-' + coat.toLowerCase(), align: 'center', justify: 'center',
    }, [initial]);
    bindSize(c, size, 'avatar-');
    avatars.push(c);
  }
}
const avatarSet = variantSet('Pet avatar', avatars,
  'Аватар питомца без фото: круг цвета шерсти и первая буква клички (numeral, 45% размера).');
linkProperty(avatarSet, 'Initial', 'TEXT', 'М', 'initial');

const statuses = [
  ['Overdue', 'error', 'danger', 'Просрочено на 3 дня · 29 сент. 2026 г.'],
  ['Soon', 'schedule', 'warning', 'Завтра · 3 окт. 2026 г.'],
  ['Planned', 'event', 'ink-muted', 'Через 25 дней · 27 окт. 2026 г.'],
];
const lines = [];
for (const [name, glyph, color, words] of statuses) {
  lines.push(component(`Status=${name}`, { dir: 'H', gap: 4, align: 'center' }, [
    icon(glyph, 16, color),
    await text(words, 'body-sm', color, { name: 'text' }),
  ]));
}
const statusSet = variantSet('Status line', lines,
  'Срок плана ухода: иконка и слова, цвет никогда не один. Просрочено — danger, скоро — warning, по плану — ink-muted.');

const switches = [
  component('Value=On', { dir: 'H', w: 52, h: 32, pad: [0, 4, 0, 4], radius: CB.numValue['radius-full'],
    fill: 'primary', align: 'center', justify: 'end' },
    [box({ name: 'thumb', w: 24, h: 24, radius: CB.numValue['radius-full'], fill: 'on-primary' })]),
  component('Value=Off', { dir: 'H', w: 52, h: 32, pad: [0, 4, 0, 8], radius: CB.numValue['radius-full'],
    fill: 'sunken', stroke: 'line-strong', strokeW: 2, align: 'center', justify: 'start' },
    [box({ name: 'thumb', w: 16, h: 16, radius: CB.numValue['radius-full'], fill: 'line-strong' })]),
];
const switchSet = variantSet('Switch', switches, 'Переключатель Material 3 в цветах Collarbell.');

await dsSection('Аватар питомца', 'Pet avatar · Size 28 / 40 / 64 (avatar-sm/md/lg) × Coat — шесть цветов шерсти. Свойство Initial — буква.', [avatarSet]);
await dsSection('Срок ухода', 'Status line · Overdue / Soon / Planned. Текст меняется прямо в слое text.', [statusSet]);
await dsSection('Переключатель', 'Switch · On / Off.', [switchSet]);
await cbDone();
const frame = await dsFrame();
await bridge.shot(frame, '10_components_a');
return { avatarSet: avatarSet.id, statusSet: statusSet.id, switchSet: switchSet.id };
