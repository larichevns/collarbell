// Screens: Sign in and Sign up (01_auth_sign_in, 01_auth_sign_up).
await cbSetup();
const AREA = '01 Вход';

function prop(node, short, value) {
  const key = Object.keys(node.componentProperties).find((k) => k.split('#')[0] === short);
  node.setProperties({ [key]: value });
  return node;
}

// A Text field without a hint, full width. A placeholder is muted, as in the app.
async function field(label, value, placeholder) {
  const f = await inst('Text field', { State: 'Default' }, { Label: label, Value: value, 'Show hint': false });
  f.findOne((n) => n.type === 'TEXT' && n.name === 'value').fills = [paint(placeholder ? 'ink-muted' : 'ink')];
  return sized(f, 'fill');
}

// The password field: the Text field has no trailing icon, so this one is
// detached and gets the "show password" eye (an IconButton: 12 from the edge).
async function passwordField() {
  const f = (await inst('Text field', { State: 'Default' }, { Label: 'Пароль', Value: ' ', 'Show hint': false }))
    .detachInstance();
  f.name = 'Text field · пароль';
  const value = f.findOne((n) => n.type === 'TEXT' && n.name === 'value');
  value.characters = '';
  const row = value.parent;
  row.appendChild(icon('visibility', 24, 'ink-muted'));
  if (row.layoutMode && row.layoutMode !== 'NONE') {
    value.layoutSizingHorizontal = 'FILL';
    bindNum(row, 'paddingRight', 12, 'space-');
    row.counterAxisAlignItems = 'CENTER';
  }
  return sized(f, 'fill');
}

const link = (label) => inst('Button', { Style: 'Text', State: 'Default' }, { Label: label });

// The main button: Primary, full width, control-lg high (CbButtonStyles.large).
async function mainButton(label) {
  const b = await inst('Button', { Style: 'Primary', State: 'Default' }, { Label: label });
  b.resize(b.width, CB.numValue['control-lg']);
  return sized(b, 'fill');
}

// Text buttons take a 48 px row: their touch target.
const row48 = (name, justify, child) => box({ name, dir: 'H', h: 48, w: 'fill', justify, align: 'center' }, [child]);

const brand = box({ name: 'brand', dir: 'V', gap: 8, w: 'fill' }, [
  await text('Collarbell', 'display-lg', 'ink', { w: 'fill', name: 'app title' }),
  await text('Кормление, прививки и запасы ваших питомцев в одном месте.', 'body', 'ink-muted', { w: 'fill', name: 'tagline' }),
]);
const fields = box({ name: 'fields', dir: 'V', gap: 16, w: 'fill' }, [
  await text('Вход', 'title', 'ink', { w: 'fill', name: 'title' }),
  await field('Эл. почта', 'name@example.com', true),
  await passwordField(),
]);
const actions = box({ name: 'actions', dir: 'V', gap: 8, pad: [24, 0, 0, 0], w: 'fill' }, [
  await mainButton('Войти'),
  row48('switch mode', 'center', await link('Впервые в Collarbell? Создайте аккаунт')),
]);
const form = box({ name: 'form', dir: 'V', w: 'fill' }, [
  fields,
  row48('forgot password', 'end', await link('Забыли пароль?')),
  actions,
]);
const signIn = fitScreen(screen('Вход — форма входа', [
  box({ name: 'content', dir: 'V', gap: 32, pad: [48, 16, 24, 16], w: 'fill' }, [brand, form]),
]));
await place(AREA, 0, signIn, '01_auth_sign_in.png');

// Sign up: the same form with other words and no "Forgot password?".
const signUp = signIn.clone();
signUp.name = 'Вход — регистрация';
signUp.findOne((n) => n.type === 'TEXT' && n.name === 'title' && n.parent.name === 'fields').characters = 'Регистрация';
signUp.findOne((n) => n.name === 'forgot password').remove();
const upActions = signUp.findOne((n) => n.name === 'actions');
prop(upActions.children[0], 'Label', 'Создать аккаунт');
prop(upActions.findOne((n) => n.name === 'switch mode').children[0], 'Label', 'Уже есть аккаунт? Войдите');
await place(AREA, 1, signUp, '01_auth_sign_up.png');
return { signIn: signIn.id, signUp: signUp.id };
