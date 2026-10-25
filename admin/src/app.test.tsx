// The admin as a whole: the session gate, the routes and the pages, on the test data (the same as npm run dev:mock),
// in a memory router. What a test clicks is what the owner clicks.
import { act, fireEvent, render, screen as page, waitFor, within as inside } from '@testing-library/react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { dateInputValue, endOfDayIso, formatDateNumeric } from './lib/format';
import { createMockBackend, OWNER_EMAIL } from './mock/backend';
import { createFixtures } from './mock/fixtures';
import { createMockAuth } from './mock/services';
import { routes } from './routes';
import { SessionGate } from './session';

// The Russian texts have no-break spaces after short words and between a number and its word (tools/typograph.py
// puts them in this file too), and Testing Library reads the page's text with them as plain spaces. So the text
// queries (…ByText, …ByLabelText, …ByPlaceholderText, …ByTitle) get their text with plain spaces as well. Accessible
// names (…ByRole with name) are compared as they are.
const plainSpaces = (matcher: unknown) =>
  typeof matcher === 'string'
    ? matcher.replace(/\u00a0/g, ' ')
    : matcher instanceof RegExp
      ? new RegExp(matcher.source.replace(/\u00a0/g, ' '), matcher.flags)
      : matcher;

function plainQueries<T extends object>(queries: T): T {
  return new Proxy(queries, {
    get(target, key, receiver) {
      const query: unknown = Reflect.get(target, key, receiver);
      if (typeof query !== 'function' || typeof key !== 'string' || !/By(Text|LabelText|PlaceholderText|Title)$/.test(key)) {
        return query;
      }
      return (matcher: unknown, ...rest: unknown[]) => query(plainSpaces(matcher), ...rest);
    },
  });
}

const screen = plainQueries(page);
const within = (element: HTMLElement) => plainQueries(inside(element));

// The ids don't depend on the time; the moments are relative to now, as in mock mode.
const FIXTURES = createFixtures(new Date());
const ANNA = FIXTURES.people[0]!;

interface Options {
  user?: string | null;
  calm?: boolean;
  fetch?: typeof fetch;
  /** The pretend server's pause, to catch a page while it waits. */
  latencyMs?: number;
}

function renderAdmin(path: string, { user = OWNER_EMAIL, calm = false, fetch, latencyMs = 0 }: Options = {}) {
  const backend = createMockBackend({ now: FIXTURES.now, latencyMs, calm });
  const router = createMemoryRouter(routes, { initialEntries: [path] });
  const services = { auth: createMockAuth(user, 0), fetch: fetch ?? backend.fetch, mock: true };
  render(
    <SessionGate services={services}>
      <RouterProvider router={router} />
    </SessionGate>,
  );
  return { router, backend };
}

const search = (router: ReturnType<typeof createMemoryRouter>) => new URLSearchParams(router.state.location.search);
const lines = (selector = '.line') => document.querySelectorAll(selector).length;

afterEach(() => {
  vi.useRealTimers();
});

describe('signing in', () => {
  it('shows the form, says when the password is wrong, and opens the overview', async () => {
    renderAdmin('/', { user: null });
    expect(await screen.findByRole('heading', { name: 'Вход' })).toBeTruthy();
    fireEvent.change(screen.getByLabelText('E-mail'), { target: { value: 'owner@example.com' } });
    fireEvent.change(screen.getByLabelText('Пароль'), { target: { value: 'wrong' } });
    fireEvent.click(screen.getByRole('button', { name: 'Войти' }));
    expect(await screen.findByText('Неверный e-mail или пароль.')).toBeTruthy();

    fireEvent.change(screen.getByLabelText('Пароль'), { target: { value: 'secret' } });
    fireEvent.click(screen.getByRole('button', { name: 'Войти' }));
    expect(await screen.findByText('Требует внимания')).toBeTruthy();
    expect(screen.getByText('owner@example.com')).toBeTruthy();
  });

  it('tells a non-admin there is no access, and lets them sign out', async () => {
    renderAdmin('/', { user: 'stranger@example.com' });
    expect(await screen.findByText('Нет доступа: этот аккаунт не админ')).toBeTruthy();
    expect(screen.getByText('stranger@example.com')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Выйти' }));
    expect(await screen.findByRole('heading', { name: 'Вход' })).toBeTruthy();
  });

  it('signs out with a reason when the server stops taking the token', async () => {
    const backend = createMockBackend({ now: FIXTURES.now, latencyMs: 0 });
    const fetch: typeof window.fetch = async (input, init) =>
      String(input).includes('/overview') ? new Response('{}', { status: 401 }) : backend.fetch(input, init);
    renderAdmin('/', { fetch });
    expect(await screen.findByText('Вход больше не действует. Войдите снова.')).toBeTruthy();
    expect(await screen.findByRole('heading', { name: 'Вход' })).toBeTruthy();
  });

  it('signs out from the header', async () => {
    renderAdmin('/users');
    await screen.findByText('Новые сверху.');
    fireEvent.click(screen.getByRole('button', { name: 'Выйти' }));
    expect(await screen.findByRole('heading', { name: 'Вход' })).toBeTruthy();
  });
});

describe('Обзор', () => {
  it('lists what needs attention and colours its tiles', async () => {
    renderAdmin('/');
    const issues = await screen.findByRole('region', { name: 'Требует внимания' });
    expect(within(issues).getByText(/Мало места на диске/)).toBeTruthy();
    expect(within(issues).getByText(/Напоминания задерживаются/)).toBeTruthy();
    expect(screen.getByText('Не отправлены').closest('.stat')?.className).toContain('stat--danger');
    expect(screen.getByText('Свободно на диске').closest('.stat')?.className).toContain('stat--danger');
    expect(screen.getByText('Опоздали').closest('.stat')?.className).toContain('stat--warning');
    expect(screen.getByText('Отправлены').closest('.stat')?.className).toBe('stat');
    expect(screen.getByRole('meter', { name: /Занято/ })).toBeTruthy();
  });

  it('says all is calm when it is', async () => {
    renderAdmin('/', { calm: true });
    expect(await screen.findByText('Всё спокойно.')).toBeTruthy();
    expect(screen.queryByText('Требует внимания')).toBeNull();
  });

  it('refreshes every minute and on "Обновить"', async () => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
    const backend = createMockBackend({ now: FIXTURES.now, latencyMs: 0 });
    const asked: string[] = [];
    const fetch: typeof window.fetch = (input, init) => {
      asked.push(String(input));
      return backend.fetch(input, init);
    };
    renderAdmin('/', { fetch });
    await screen.findByText('Требует внимания');
    const overviews = () => asked.filter((url) => url === '/api/admin/overview').length;
    expect(overviews()).toBe(1);

    await act(async () => {
      vi.advanceTimersByTime(60_000);
    });
    await waitFor(() => expect(overviews()).toBe(2));

    fireEvent.click(screen.getByRole('button', { name: 'Обновить' }));
    await waitFor(() => expect(overviews()).toBe(3));
  });
});

describe('Люди', () => {
  it('shows the newest people, searches, and opens a person', async () => {
    const { router } = renderAdmin('/users');
    expect(await screen.findByText('Новые сверху.')).toBeTruthy();
    expect(screen.getAllByRole('row')).toHaveLength(22);

    fireEvent.change(screen.getByPlaceholderText('E-mail или имя'), { target: { value: 'смирн' } });
    expect(await screen.findByText('Найдено: 2 человека.')).toBeTruthy();
    expect(screen.getAllByRole('row')).toHaveLength(3);
    expect(search(router).get('q')).toBe('смирн');

    fireEvent.click(screen.getByRole('link', { name: 'Анна Смирнова' }));
    expect(await screen.findByRole('heading', { name: 'Анна Смирнова', level: 1 })).toBeTruthy();
    expect(router.state.location.pathname).toBe(`/users/${ANNA.id}`);
  });

  it('says when nobody is found', async () => {
    renderAdmin('/users?q=nobody-here');
    expect(await screen.findByText('Никого не нашли по «nobody-here».')).toBeTruthy();
  });
});

describe('Человек and the визор', () => {
  it('shows groups, phones and AI', async () => {
    renderAdmin(`/users/${ANNA.id}`);
    expect(await screen.findByRole('heading', { name: 'Анна Смирнова', level: 1 })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Дом Смирновых' }).getAttribute('href')).toBe(
      `/households/${FIXTURES.householdIds.smirnovy}`,
    );
    expect(screen.getByText('Владелец')).toBeTruthy();
    expect(screen.getByText('Android')).toBeTruthy();
    expect(screen.getByText('AI за 30 дней')).toBeTruthy();
  });

  it('groups lines by session, filters kinds, and brings more', async () => {
    const { router } = renderAdmin(`/users/${ANNA.id}`);
    await waitFor(() => expect(lines()).toBe(200));
    expect(screen.getAllByText('Сессия').length).toBeGreaterThan(1);
    expect(lines('.line--request')).toBeGreaterThan(0);

    fireEvent.click(screen.getByRole('button', { name: /^Запросы/ }));
    expect(lines('.line--request')).toBe(0);
    expect(lines()).toBeGreaterThan(0);
    expect(search(router).get('show')).toBe('screens,actions,errors');

    fireEvent.click(screen.getByRole('button', { name: /^Запросы/ }));
    expect(search(router).get('show')).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: 'Показать ещё' }));
    await waitFor(() => expect(lines()).toBeGreaterThan(200));
  });

  it('adds up quick filter clicks', async () => {
    const { router } = renderAdmin(`/users/${ANNA.id}`);
    await waitFor(() => expect(lines()).toBe(200));
    const chip = (name: RegExp) => screen.getByRole('button', { name });
    // Three clicks before React draws again: each must build on the one before.
    act(() => {
      chip(/^Запросы/).click();
      chip(/^Экраны/).click();
      chip(/^Действия/).click();
    });
    await waitFor(() => expect(search(router).get('show')).toBe('errors'));
    expect(lines()).toBe(lines('.line--error') + lines('.line--crash'));
  });

  it('colours request statuses: 2xx, 4xx, 5xx', async () => {
    renderAdmin(`/users/${ANNA.id}`);
    await waitFor(() => expect(lines()).toBe(200));
    const badges = [...document.querySelectorAll('.line-meta .badge')];
    const toneOf = (status: string) => badges.find((badge) => badge.textContent === status)?.className;
    expect(toneOf('200')).toContain('badge--ok');
    expect(toneOf('500')).toContain('badge--danger');
  });

  it('opens around a problem and marks its line', async () => {
    const problem = FIXTURES.problems(168).find((item) => item.kind === 'server' && item.userId === ANNA.id)!;
    renderAdmin(`/users/${ANNA.id}?at=${encodeURIComponent(problem.at)}`);
    const marked = await screen.findByText('этот момент');
    const line = marked.closest('li')!;
    expect(line.className).toContain('line--marked');
    expect(within(line).getByText('500')).toBeTruthy();
    expect(screen.getByText(/Открыто вокруг/)).toBeTruthy();
  });

  it('says when the person is gone', async () => {
    renderAdmin('/users/nobody');
    expect(await screen.findByText('Человек не найден')).toBeTruthy();
  });
});

describe('Группа', () => {
  it('shows members with roles and the counts', async () => {
    renderAdmin(`/households/${FIXTURES.householdIds.smirnovy}`);
    expect(await screen.findByRole('heading', { name: 'Дом Смирновых', level: 1 })).toBeTruthy();
    const table = screen.getByRole('table');
    expect(within(table).getAllByRole('row')).toHaveLength(3);
    expect(within(table).getByText('Владелец')).toBeTruthy();
    expect(within(table).getByText('Участник')).toBeTruthy();
    expect(screen.getByText('Открытые приглашения')).toBeTruthy();
  });
});

describe('Тариф', () => {
  const ids = FIXTURES.householdIds;
  const group = (key: string) => `/households/${ids[key]}`;
  const planOf = (key: string) => FIXTURES.household(ids[key]!)!.plan;
  const DAY = 86_400_000;
  /** The card, once the group has loaded; queries inside it only. */
  const card = async () => within((await screen.findByRole('heading', { name: 'Тариф' })).closest('section')!);
  const checked = (element: HTMLElement) => (element as HTMLInputElement).checked;

  it('shows Premium until a day, the AI photos and the last change', async () => {
    renderAdmin(group('smirnovy'));
    const plan = await card();
    expect(plan.getByText('Premium')).toBeTruthy();
    expect(plan.getByText(formatDateNumeric(planOf('smirnovy').expiresAt!))).toBeTruthy();
    expect(plan.getByText(/ещё \d+ (день|дня|дней)/)).toBeTruthy();
    expect(plan.getByText('7 из 300')).toBeTruthy();
    expect(plan.getByRole('meter').className).toContain('meter--ok');
    expect(plan.getByText(/Изменил owner@example\.com/)).toBeTruthy();
    expect(plan.getByText('тестер')).toBeTruthy();
    expect(plan.getByRole('button', { name: 'Изменить срок' })).toBeTruthy();
    expect(plan.getByRole('button', { name: 'Забрать Premium' })).toBeTruthy();
  });

  it('shows Premium with no end', async () => {
    renderAdmin(group('ivanovy'));
    const plan = await card();
    expect(plan.getByText('бессрочно')).toBeTruthy();
    expect(plan.getByText('41 из 300')).toBeTruthy();
  });

  it('shows a Premium that ran out, and photos over the Free limit in yellow', async () => {
    renderAdmin(group('garcia'));
    const plan = await card();
    expect(plan.getByText('Free')).toBeTruthy();
    expect(plan.getByText(/Premium закончился/)).toBeTruthy();
    expect(plan.getByText(formatDateNumeric(planOf('garcia').expiresAt!))).toBeTruthy();
    expect(plan.getByText('26 из 20')).toBeTruthy();
    expect(plan.getByRole('meter').className).toContain('meter--warning');
    expect(plan.getByText('лимит превышен на 6 фото')).toBeTruthy();
    expect(plan.getByRole('button', { name: 'Выдать Premium' })).toBeTruthy();
  });

  it('shows a group whose plan was never changed, near its limit', async () => {
    renderAdmin(group('morozovy'));
    const plan = await card();
    expect(plan.getByText('Тариф не меняли: группа всегда была на Free.')).toBeTruthy();
    expect(plan.getByText('17 из 20')).toBeTruthy();
    expect(plan.getByText('почти исчерпан: осталось 3 фото')).toBeTruthy();
  });

  it('gives Premium with no end', async () => {
    renderAdmin(group('morozovy'));
    const plan = await card();
    fireEvent.click(plan.getByRole('button', { name: 'Выдать Premium' }));
    expect(checked(plan.getByRole('radio', { name: 'Бессрочно' }))).toBe(true);
    fireEvent.change(plan.getByLabelText(/Заметка/), { target: { value: 'тестер' } });
    fireEvent.click(plan.getByRole('button', { name: 'Сохранить' }));
    expect(await plan.findByText('Premium выдан.')).toBeTruthy();
    expect(plan.getByText('Premium')).toBeTruthy();
    expect(plan.getByText('бессрочно')).toBeTruthy();
    expect(plan.getByText('тестер')).toBeTruthy();
    expect(plan.getByText('17 из 300')).toBeTruthy();
  });

  it('gives Premium through a picked day', async () => {
    renderAdmin(group('kozlov'));
    const plan = await card();
    fireEvent.click(plan.getByRole('button', { name: 'Выдать Premium' }));
    const day = dateInputValue(new Date(Date.now() + 30 * DAY));
    fireEvent.change(plan.getByLabelText('Дата окончания'), { target: { value: day } });
    expect(checked(plan.getByRole('radio', { name: 'До даты' }))).toBe(true);
    fireEvent.click(plan.getByRole('button', { name: 'Сохранить' }));
    expect(await plan.findByText('Premium выдан.')).toBeTruthy();
    expect(plan.getByText(formatDateNumeric(endOfDayIso(day)!))).toBeTruthy();
    expect(plan.getByText(/ещё 30 дней/)).toBeTruthy();
  });

  it('changes the term, starting from the current one', async () => {
    renderAdmin(group('smirnovy'));
    const plan = await card();
    fireEvent.click(plan.getByRole('button', { name: 'Изменить срок' }));
    expect((plan.getByLabelText('Дата окончания') as HTMLInputElement).value).toBe(dateInputValue(planOf('smirnovy').expiresAt!));
    expect((plan.getByLabelText(/Заметка/) as HTMLInputElement).value).toBe('тестер');
    fireEvent.click(plan.getByRole('radio', { name: 'Бессрочно' }));
    fireEvent.click(plan.getByRole('button', { name: 'Сохранить' }));
    expect(await plan.findByText('Срок изменён.')).toBeTruthy();
    expect(plan.getByText('бессрочно')).toBeTruthy();
  });

  it('asks for the day when "До даты" has none, without asking the server', async () => {
    const backend = createMockBackend({ now: FIXTURES.now, latencyMs: 0 });
    const changes: string[] = [];
    const fetch: typeof window.fetch = (input, init) => {
      if (init?.method === 'PUT') changes.push(String(input));
      return backend.fetch(input, init);
    };
    renderAdmin(group('kozlov'), { fetch });
    const plan = await card();
    fireEvent.click(plan.getByRole('button', { name: 'Выдать Premium' }));
    fireEvent.click(plan.getByRole('radio', { name: 'До даты' }));
    fireEvent.click(plan.getByRole('button', { name: 'Сохранить' }));
    expect(await plan.findByText('Выберите дату окончания.')).toBeTruthy();
    expect(changes).toEqual([]);
  });

  it('shows the server check next to the day and keeps the form open', async () => {
    renderAdmin(group('morozovy'));
    const plan = await card();
    fireEvent.click(plan.getByRole('button', { name: 'Выдать Premium' }));
    fireEvent.change(plan.getByLabelText('Дата окончания'), { target: { value: '2020-01-01' } });
    fireEvent.click(plan.getByRole('button', { name: 'Сохранить' }));
    expect(await plan.findByText('Дата окончания должна быть в будущем.')).toBeTruthy();
    expect(plan.getByLabelText('Дата окончания').getAttribute('aria-invalid')).toBe('true');
    expect(plan.getByRole('button', { name: 'Сохранить' })).toBeTruthy();
    expect(plan.getByText('Free')).toBeTruthy();
  });

  it('shows a note check from the server under the note', async () => {
    const backend = createMockBackend({ now: FIXTURES.now, latencyMs: 0 });
    const fetch: typeof window.fetch = async (input, init) =>
      init?.method === 'PUT'
        ? new Response(JSON.stringify({ status: 400, errors: { note: ['At most 200 characters.'] } }), {
            status: 400,
            headers: { 'Content-Type': 'application/problem+json' },
          })
        : backend.fetch(input, init);
    renderAdmin(group('morozovy'), { fetch });
    const plan = await card();
    fireEvent.click(plan.getByRole('button', { name: 'Выдать Premium' }));
    fireEvent.click(plan.getByRole('button', { name: 'Сохранить' }));
    expect(await plan.findByText('Заметка — не длиннее 200 знаков.')).toBeTruthy();
    expect(plan.getByLabelText(/Заметка/).getAttribute('aria-invalid')).toBe('true');
  });

  it('holds the form while saving', async () => {
    renderAdmin(group('morozovy'), { latencyMs: 40 });
    const plan = await card();
    fireEvent.click(plan.getByRole('button', { name: 'Выдать Premium' }));
    fireEvent.click(plan.getByRole('button', { name: 'Сохранить' }));
    const saving = await plan.findByRole('button', { name: 'Сохраняем…' });
    expect(saving.closest('fieldset')!.disabled).toBe(true);
    expect(await plan.findByText('Premium выдан.')).toBeTruthy();
  });

  it('takes Premium back only after a confirmation', async () => {
    renderAdmin(group('ivanovy'));
    const plan = await card();
    fireEvent.click(plan.getByRole('button', { name: 'Забрать Premium' }));
    expect(plan.getByText('Забрать Premium у группы «Ивановы»?')).toBeTruthy();
    fireEvent.click(plan.getByRole('button', { name: 'Отмена' }));
    expect(plan.queryByText(/Забрать Premium у группы/)).toBeNull();
    expect(plan.getByText('Premium')).toBeTruthy();

    fireEvent.click(plan.getByRole('button', { name: 'Забрать Premium' }));
    fireEvent.change(plan.getByLabelText(/Заметка/), { target: { value: 'тест окончен' } });
    fireEvent.click(plan.getByRole('button', { name: 'Забрать Premium' }));
    expect(await plan.findByText('Premium забран: группа на Free.')).toBeTruthy();
    expect(plan.getByText('Free')).toBeTruthy();
    expect(plan.getByText('тест окончен')).toBeTruthy();
    expect(plan.getByRole('button', { name: 'Выдать Premium' })).toBeTruthy();
  });
});

describe('plans elsewhere', () => {
  it('counts the Premium groups on the overview', async () => {
    renderAdmin('/');
    const tile = (await screen.findByText('Группы с Premium')).closest('.stat') as HTMLElement;
    expect(within(tile).getByText('2')).toBeTruthy();
  });

  it('shows each group plan on the person page', async () => {
    renderAdmin(`/users/${ANNA.id}`);
    const groups = (await screen.findByRole('heading', { name: 'Группы' })).closest('section')!;
    expect(within(groups).getByText('Premium')).toBeTruthy();
  });
});

describe('Проблемы', () => {
  it('filters by kind and leads to the визор at that moment', async () => {
    const { router } = renderAdmin('/problems');
    await screen.findAllByRole('link', { name: /В визоре/ });
    const day = FIXTURES.problems(24);
    expect(document.querySelectorAll('.problem')).toHaveLength(day.length);

    fireEvent.click(screen.getByRole('radio', { name: /^Ошибки сервера/ }));
    expect(document.querySelectorAll('.problem')).toHaveLength(day.filter((problem) => problem.kind === 'server').length);
    expect(search(router).get('kind')).toBe('server');

    const open = screen.getAllByRole('link', { name: /В визоре/ })[0]!;
    expect(open.getAttribute('href')).toMatch(/^\/users\/[0-9a-f-]+\?at=/);
  });

  it('asks the server for another period', async () => {
    const { router } = renderAdmin('/problems');
    await screen.findAllByRole('link', { name: /В визоре/ });
    fireEvent.click(screen.getByRole('radio', { name: '7 дней' }));
    await waitFor(() => expect(document.querySelectorAll('.problem')).toHaveLength(FIXTURES.problems(168).length));
    expect(search(router).get('hours')).toBe('168');
  });
});

describe('addresses', () => {
  it('has a page for an unknown address', async () => {
    renderAdmin('/nowhere');
    expect(await screen.findByText('Такой страницы нет')).toBeTruthy();
  });

  it('keeps the header when a page breaks on an answer it does not expect', async () => {
    const quiet = vi.spyOn(console, 'error').mockImplementation(() => {});
    const backend = createMockBackend({ now: FIXTURES.now, latencyMs: 0 });
    const fetch: typeof window.fetch = async (input, init) =>
      String(input).endsWith('/overview') ? new Response('{}', { status: 200 }) : backend.fetch(input, init);
    renderAdmin('/', { fetch });
    expect(await screen.findByText('Что-то пошло не так')).toBeTruthy();
    expect(screen.getByRole('link', { name: /Люди/ })).toBeTruthy();
    quiet.mockRestore();
  });
});
