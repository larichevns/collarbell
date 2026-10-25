// Screen: the passport form (07_passport_form): model, number, country, issue date,
// the issuing vet, the owners and notes.
// Run as: bridge.py run jobs/_screens.js jobs/_pet_kit.js jobs/s07_passport_form.js
await cbSetup();
const AREA = '07 Паспорт';

// Name, address, phone and e-mail of a vet or an owner.
async function contacts(name, [person, address, phone, email]) {
  return box({ name, dir: 'V', w: 'fill', gap: 16 }, [
    await field('Имя', person),
    await field('Адрес', address),
    await field('Телефон', phone),
    await field('Эл. почта', email, { hint: 'name@example.com' }),
  ]);
}

const top = box({ name: 'Паспорт', dir: 'V', w: 'fill', gap: 16 }, [
  await selectField('Образец паспорта', 'Другой паспорт'),
  await field('Номер паспорта', 'RU0123456', { mono: true }),
  await field('Страна выдачи', 'RU'),
  await dateField('Дата выдачи', '1 июл. 2021 г.'),
]);
const issuer = section('Ветеринар, выдавший паспорт', await head('Ветеринар, выдавший паспорт'),
  await contacts('Контакты ветеринара', ['Иванова Анна Сергеевна', 'Москва, ул. Лесная, 12', '+7 495 123-45-67', '']));

// One owner in a bordered block, with «удалить» beside the title.
const owner = formBlock('Владелец 1', 8, [
  box({ name: 'title row', dir: 'H', w: 'fill', align: 'center' }, [
    await text('Владелец 1', 'subtitle', 'ink', { name: 'title', w: 'fill' }),
    iconButton('delete'),
  ]),
  await contacts('Контакты владельца',
    ['Анна Смирнова', 'Москва, ул. Садовая, 5, кв. 17', '+7 916 555-12-34', 'anna.smirnova@example.com']),
]);
const owners = section('Владельцы', await head('Владельцы'),
  box({ name: 'Список владельцев', dir: 'V', w: 'fill', gap: 12 },
    [owner, await outlineButton('add', 'Добавить владельца', true)]));

const passportForm = await formPage('Паспорт — форма', 'Данные паспорта',
  box({ name: 'content', dir: 'V', w: 'fill', pad: [16, 16, 48, 16], gap: 32 },
    [top, issuer, owners, await field('Заметки', '')]));
await place(AREA, 0, passportForm, '07_passport_form_full.png');
return { passportForm: passportForm.id };
