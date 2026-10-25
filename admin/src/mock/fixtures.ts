// Test data for npm run dev:mock and the tests: 21 made-up people (example.com addresses) in 18 groups, a week of
// визор for each (made by a seeded random generator: the same data every time, at times relative to `now`), the
// problems and numbers that follow from it, and the groups' plans (three were given Premium by hand). Nothing here is
// real.
import type {
  AdminPlan,
  HouseholdDetail,
  Overview,
  PlanKind,
  PlanRequest,
  PlanSource,
  Problem,
  TimelineEvent,
  UserDetail,
  UserRow,
} from '../api/types';

/** The pretend admin: who is signed in in mock mode, and who gave the plans below. */
export const OWNER_EMAIL = 'owner@example.com';

/** AI photos a calendar month (backend settings "Plans"). */
export const FREE_AI_PHOTOS = 20;
export const PREMIUM_AI_PHOTOS = 300;

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const GIB = 1024 ** 3;

/** mulberry32: a tiny random generator with a seed. */
function seeded(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function uuid(random: () => number): string {
  let hex = '';
  for (let i = 0; i < 32; i += 1) hex += Math.floor(random() * 16).toString(16);
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

function between(random: () => number, min: number, max: number): number {
  return min + Math.floor(random() * (max - min + 1));
}

type Role = 'Owner' | 'Member' | 'Helper';
type Platform = 'Android' | 'Ios';

interface PersonSeed {
  name: string | null;
  email: string;
  locale: string;
  timeZone: string;
  createdDaysAgo: number;
  /** Launches of the app a day, on average; 0: signed up and never came back. */
  activity: number;
  phones: { platform: Platform; version: string }[];
  households: [key: string, role: Role][];
  aiCalls30d: number;
}

interface HouseholdSeed {
  key: string;
  name: string;
  timeZone: string;
  createdDaysAgo: number;
  pets: number;
  routines: number;
  carePlans: number;
  supplies: number;
  openInvites: number;
}

const HOUSEHOLDS: HouseholdSeed[] = [
  { key: 'smirnovy', name: 'Дом Смирновых', timeZone: 'Europe/Moscow', createdDaysAgo: 58, pets: 3, routines: 5, carePlans: 7, supplies: 6, openInvites: 1 },
  { key: 'kuznetsovy', name: 'Кузнецовы', timeZone: 'Asia/Yekaterinburg', createdDaysAgo: 41, pets: 1, routines: 2, carePlans: 3, supplies: 2, openInvites: 0 },
  { key: 'garcia', name: 'Casa García', timeZone: 'Europe/Madrid', createdDaysAgo: 35, pets: 2, routines: 4, carePlans: 2, supplies: 3, openInvites: 0 },
  { key: 'wilson', name: 'Wilson home', timeZone: 'Europe/London', createdDaysAgo: 33, pets: 1, routines: 2, carePlans: 1, supplies: 1, openInvites: 0 },
  { key: 'ivanovy', name: 'Ивановы', timeZone: 'Europe/Moscow', createdDaysAgo: 30, pets: 2, routines: 4, carePlans: 5, supplies: 4, openInvites: 0 },
  { key: 'dacha', name: 'Дача', timeZone: 'Europe/Moscow', createdDaysAgo: 25, pets: 1, routines: 2, carePlans: 1, supplies: 2, openInvites: 1 },
  { key: 'petrov', name: 'Барсик и Ко', timeZone: 'Asia/Novosibirsk', createdDaysAgo: 28, pets: 1, routines: 1, carePlans: 2, supplies: 1, openInvites: 0 },
  { key: 'morozovy', name: 'Морозовы', timeZone: 'Europe/Moscow', createdDaysAgo: 26, pets: 2, routines: 3, carePlans: 4, supplies: 5, openInvites: 0 },
  { key: 'fischer', name: 'Fischers', timeZone: 'Europe/Berlin', createdDaysAgo: 22, pets: 2, routines: 3, carePlans: 2, supplies: 2, openInvites: 0 },
  { key: 'sokolov', name: 'Соколовы', timeZone: 'Europe/Moscow', createdDaysAgo: 20, pets: 0, routines: 0, carePlans: 0, supplies: 0, openInvites: 0 },
  { key: 'volkovy', name: 'Волковы', timeZone: 'Europe/Samara', createdDaysAgo: 18, pets: 3, routines: 6, carePlans: 6, supplies: 4, openInvites: 2 },
  { key: 'novikovy', name: 'Квартира на Ленина', timeZone: 'Europe/Moscow', createdDaysAgo: 12, pets: 2, routines: 4, carePlans: 3, supplies: 3, openInvites: 0 },
  { key: 'kozlov', name: 'Козловы', timeZone: 'Asia/Krasnoyarsk', createdDaysAgo: 9, pets: 1, routines: 2, carePlans: 1, supplies: 1, openInvites: 0 },
  { key: 'rossi', name: 'Casa Rossi', timeZone: 'Europe/Rome', createdDaysAgo: 6, pets: 1, routines: 2, carePlans: 2, supplies: 1, openInvites: 0 },
  { key: 'lebedevy', name: 'Лебедевы', timeZone: 'Europe/Moscow', createdDaysAgo: 5, pets: 2, routines: 3, carePlans: 2, supplies: 2, openInvites: 0 },
  { key: 'home1983', name: 'Мой дом', timeZone: 'Europe/Moscow', createdDaysAgo: 4, pets: 1, routines: 1, carePlans: 0, supplies: 0, openInvites: 0 },
  { key: 'orlov', name: 'Орловы', timeZone: 'Asia/Vladivostok', createdDaysAgo: 3, pets: 1, routines: 2, carePlans: 1, supplies: 1, openInvites: 0 },
  { key: 'clark', name: 'Clark family', timeZone: 'America/New_York', createdDaysAgo: 2, pets: 2, routines: 2, carePlans: 0, supplies: 1, openInvites: 0 },
];

/**
 * Plans given by hand before the data starts; the other groups were never changed (Free). Days count from now:
 * Дом Смирновых has Premium for 87 more days, Ивановы with no end, Casa García's trial month ended 4 days ago.
 */
const PLANS: Record<string, { endsInDays: number | null; note: string; changedDaysAgo: number }> = {
  smirnovy: { endsInDays: 87, note: 'тестер', changedDaysAgo: 12 },
  ivanovy: { endsInDays: null, note: 'друзья', changedDaysAgo: 20 },
  garcia: { endsInDays: -4, note: 'пробный месяц', changedDaysAgo: 34 },
};

/** AI photos this month: Морозовы are near the Free limit, Волковы at it, Casa García over it (used while Premium). */
const AI_PHOTOS_USED: Record<string, number> = {
  smirnovy: 7,
  ivanovy: 41,
  garcia: 26,
  morozovy: 17,
  volkovy: 20,
  novikovy: 3,
  kuznetsovy: 2,
  lebedevy: 5,
  dacha: 1,
};

/** A household's plan as last set (backend: billing.plans); no row: always Free. */
interface PlanRow {
  plan: PlanKind;
  source: PlanSource;
  expiresAt: number | null;
  note: string | null;
  changedAt: number;
  changedBy: string | null;
}

/** What works at a moment: a Premium past its end is Free. */
function effectivePlan(row: PlanRow | undefined, at: number): PlanKind {
  return row?.plan === 'Premium' && (row.expiresAt === null || row.expiresAt > at) ? 'Premium' : 'Free';
}

const PEOPLE: PersonSeed[] = [
  { name: 'Анна Смирнова', email: 'anna.smirnova@example.com', locale: 'ru-RU', timeZone: 'Europe/Moscow', createdDaysAgo: 58, activity: 3.6, phones: [{ platform: 'Android', version: '1.4.0' }], households: [['smirnovy', 'Owner']], aiCalls30d: 14 },
  { name: 'Дмитрий Смирнов', email: 'dmitry.smirnov@example.com', locale: 'ru-RU', timeZone: 'Europe/Moscow', createdDaysAgo: 57, activity: 1.5, phones: [{ platform: 'Ios', version: '1.4.0' }], households: [['smirnovy', 'Member']], aiCalls30d: 2 },
  { name: 'Ольга Кузнецова', email: 'olga.k@example.com', locale: 'ru-RU', timeZone: 'Asia/Yekaterinburg', createdDaysAgo: 41, activity: 2, phones: [{ platform: 'Android', version: '1.3.2' }], households: [['kuznetsovy', 'Owner']], aiCalls30d: 6 },
  { name: 'Maria Garcia', email: 'maria.garcia@example.org', locale: 'es-ES', timeZone: 'Europe/Madrid', createdDaysAgo: 35, activity: 1.2, phones: [{ platform: 'Ios', version: '1.4.0' }], households: [['garcia', 'Owner']], aiCalls30d: 3 },
  { name: 'James Wilson', email: 'jwilson@example.com', locale: 'en-GB', timeZone: 'Europe/London', createdDaysAgo: 33, activity: 0.8, phones: [{ platform: 'Ios', version: '1.3.2' }, { platform: 'Android', version: '1.4.0' }], households: [['wilson', 'Owner']], aiCalls30d: 0 },
  { name: 'Екатерина Иванова', email: 'katya.ivanova@example.com', locale: 'ru-RU', timeZone: 'Europe/Moscow', createdDaysAgo: 30, activity: 2.5, phones: [{ platform: 'Android', version: '1.4.0' }], households: [['ivanovy', 'Owner'], ['dacha', 'Helper']], aiCalls30d: 9 },
  { name: 'Сергей Петров', email: 's.petrov@example.com', locale: 'ru-RU', timeZone: 'Asia/Novosibirsk', createdDaysAgo: 28, activity: 0.3, phones: [{ platform: 'Android', version: '1.2.0' }], households: [['petrov', 'Owner']], aiCalls30d: 0 },
  { name: 'Алина Морозова', email: 'alina.morozova@example.com', locale: 'ru-RU', timeZone: 'Europe/Moscow', createdDaysAgo: 26, activity: 1.8, phones: [{ platform: 'Ios', version: '1.4.0' }], households: [['morozovy', 'Owner'], ['dacha', 'Owner']], aiCalls30d: 21 },
  { name: 'Lena Fischer', email: 'lena.fischer@example.de', locale: 'de-DE', timeZone: 'Europe/Berlin', createdDaysAgo: 22, activity: 1, phones: [{ platform: 'Android', version: '1.4.0' }], households: [['fischer', 'Owner']], aiCalls30d: 4 },
  { name: 'Павел Соколов', email: 'pavel.sokolov@example.com', locale: 'ru-RU', timeZone: 'Europe/Moscow', createdDaysAgo: 20, activity: 0, phones: [], households: [['sokolov', 'Owner']], aiCalls30d: 0 },
  { name: 'Ирина Волкова', email: 'irina.volkova@example.com', locale: 'ru-RU', timeZone: 'Europe/Samara', createdDaysAgo: 18, activity: 1.4, phones: [{ platform: 'Android', version: '1.3.2' }], households: [['volkovy', 'Owner']], aiCalls30d: 2 },
  { name: 'Никита Волков', email: 'nikita.volkov@example.com', locale: 'ru-RU', timeZone: 'Europe/Samara', createdDaysAgo: 17, activity: 0.6, phones: [{ platform: 'Android', version: '1.4.0' }], households: [['volkovy', 'Member']], aiCalls30d: 0 },
  { name: 'Tom Becker', email: 'tom.becker@example.de', locale: 'de-DE', timeZone: 'Europe/Berlin', createdDaysAgo: 15, activity: 0.5, phones: [{ platform: 'Ios', version: '1.4.0' }], households: [['fischer', 'Helper']], aiCalls30d: 0 },
  { name: 'Юлия Новикова', email: 'yulia.n@example.com', locale: 'ru-RU', timeZone: 'Europe/Moscow', createdDaysAgo: 12, activity: 2.2, phones: [{ platform: 'Ios', version: '1.4.0' }], households: [['novikovy', 'Owner']], aiCalls30d: 11 },
  { name: 'Артём Козлов', email: 'artem.kozlov@example.com', locale: 'ru-RU', timeZone: 'Asia/Krasnoyarsk', createdDaysAgo: 9, activity: 1, phones: [{ platform: 'Android', version: '1.4.0' }], households: [['kozlov', 'Owner']], aiCalls30d: 1 },
  { name: 'Sofia Rossi', email: 'sofia.rossi@example.it', locale: 'it-IT', timeZone: 'Europe/Rome', createdDaysAgo: 6, activity: 1.6, phones: [{ platform: 'Ios', version: '1.4.0' }], households: [['rossi', 'Owner']], aiCalls30d: 5 },
  { name: 'Мария Лебедева', email: 'maria.lebedeva@example.com', locale: 'ru-RU', timeZone: 'Europe/Moscow', createdDaysAgo: 5, activity: 2.8, phones: [{ platform: 'Android', version: '1.4.0' }], households: [['lebedevy', 'Owner']], aiCalls30d: 7 },
  { name: null, email: 'user1983@example.net', locale: 'ru-RU', timeZone: 'Europe/Moscow', createdDaysAgo: 4, activity: 0.4, phones: [{ platform: 'Android', version: '1.4.0' }], households: [['home1983', 'Owner']], aiCalls30d: 0 },
  { name: 'Георгий Орлов', email: 'g.orlov@example.com', locale: 'ru-RU', timeZone: 'Asia/Vladivostok', createdDaysAgo: 3, activity: 1.1, phones: [{ platform: 'Ios', version: '1.4.0' }], households: [['orlov', 'Owner']], aiCalls30d: 2 },
  { name: 'Emily Clark', email: 'emily.clark@example.com', locale: 'en-US', timeZone: 'America/New_York', createdDaysAgo: 2, activity: 0.9, phones: [{ platform: 'Ios', version: '1.4.0' }], households: [['clark', 'Owner']], aiCalls30d: 0 },
  { name: 'Василиса Фёдорова', email: 'vasilisa.f@example.com', locale: 'ru-RU', timeZone: 'Europe/Moscow', createdDaysAgo: 1, activity: 1.5, phones: [{ platform: 'Android', version: '1.4.0' }], households: [['ivanovy', 'Member']], aiCalls30d: 0 },
];

/** One step of a session: what the person did, as app events and requests, a few seconds apart. */
type Step = (ids: StepIds) => StepLine[];
type StepLine =
  | { kind: 'request'; text: string; status: number; durationMs: [number, number] }
  | { kind: 'screen' | 'action' | 'error' | 'crash'; text: string };
interface StepIds {
  pet: string;
  record: string;
  plan: string;
  routine: string;
  supply: string;
}

const request = (text: string, status: number, durationMs: [number, number] = [25, 240]): StepLine => ({
  kind: 'request',
  text,
  status,
  durationMs,
});

const STEPS: { weight: number; step: Step }[] = [
  { weight: 10, step: () => [{ kind: 'screen', text: '/pets' }, request('GET /api/v1/pets', 200)] },
  { weight: 10, step: (ids) => [{ kind: 'screen', text: '/pets/:petId' }, request(`GET /api/v1/pets/${ids.pet}`, 200)] },
  {
    weight: 14,
    step: (ids) => [{ kind: 'action', text: 'fed · breakfast' }, request(`POST /api/v1/routines/${ids.routine}/completions`, 201)],
  },
  {
    weight: 6,
    step: (ids) => [
      { kind: 'screen', text: '/pets/:petId/health' },
      request(`GET /api/v1/pets/${ids.pet}/care-records`, 200),
      request(`GET /api/v1/pets/${ids.pet}/care-plans`, 200),
    ],
  },
  {
    weight: 4,
    step: (ids) => [{ kind: 'action', text: 'marked done · deworming' }, request(`POST /api/v1/care-plans/${ids.plan}/complete`, 200)],
  },
  { weight: 7, step: () => [{ kind: 'screen', text: '/supplies' }, request('GET /api/v1/supplies', 200)] },
  {
    weight: 4,
    step: (ids) => [
      { kind: 'action', text: 'used stock · dry food' },
      request(`POST /api/v1/supplies/${ids.supply}/stock-events`, 201),
    ],
  },
  { weight: 3, step: (ids) => [{ kind: 'screen', text: '/pets/:petId/passport' }, request(`GET /api/v1/pets/${ids.pet}/passport`, 200)] },
  {
    weight: 2,
    step: (ids) => [
      { kind: 'screen', text: '/pets/:petId/documents/new' },
      { kind: 'action', text: 'scanned passport' },
      request(`POST /api/v1/pets/${ids.pet}/ai-imports`, 202, [2500, 9000]),
    ],
  },
  {
    weight: 3,
    step: (ids) => [{ kind: 'screen', text: '/pets/:petId/edit' }, request(`PUT /api/v1/pets/${ids.pet}`, 200, [60, 400])],
  },
  {
    weight: 1,
    step: (ids) => [
      { kind: 'screen', text: '/pets/:petId/edit' },
      request(`PUT /api/v1/pets/${ids.pet}`, 409, [40, 160]),
      { kind: 'error', text: 'save failed · 409 conflict' },
    ],
  },
  { weight: 2, step: () => [{ kind: 'screen', text: '/more/household' }, request('GET /api/v1/households/current', 200)] },
  { weight: 2, step: () => [{ kind: 'screen', text: '/pets/:petId/visits' }, request('GET /api/v1/appointments', 200)] },
  {
    weight: 1,
    step: (ids) => [
      request(`GET /api/v1/care-records/${ids.record}`, 404, [20, 80]),
      { kind: 'error', text: 'record not found · 404' },
    ],
  },
];

const SERVER_ERROR: Step = (ids) => [
  { kind: 'action', text: 'used stock · wet food' },
  request(`POST /api/v1/supplies/${ids.supply}/stock-events`, 500, [900, 2400]),
  { kind: 'error', text: 'save failed · 500' },
];

const CRASH: StepLine = { kind: 'crash', text: 'FlutterError · RenderFlex overflowed by 24 pixels on /pets/:petId/health' };

function pickStep(random: () => number): Step {
  const total = STEPS.reduce((sum, item) => sum + item.weight, 0);
  let roll = random() * total;
  for (const item of STEPS) {
    roll -= item.weight;
    if (roll < 0) return item.step;
  }
  return STEPS[0]!.step;
}

interface Person {
  seed: PersonSeed;
  id: string;
  createdAt: number;
  households: { key: string; role: Role }[];
  /** Newest first. */
  timeline: TimelineEvent[];
  phoneIds: string[];
}

interface Household {
  seed: HouseholdSeed;
  id: string;
  createdAt: number;
}

export interface Fixtures {
  now: Date;
  overview(calm: boolean): Overview;
  users(query: string, limit: number): UserRow[];
  user(id: string): UserDetail | null;
  timeline(id: string, before: string | null, limit: number): TimelineEvent[] | null;
  household(id: string): HouseholdDetail | null;
  /** PUT …/plan once the request has passed the checks (backend/mock/backend.ts makes them); null: no such group. */
  setPlan(householdId: string, request: PlanRequest, adminEmail: string): AdminPlan | null;
  problems(hours: number): Problem[];
  /** For the tests and the screenshots: the people in their order. */
  people: { id: string; email: string; name: string | null }[];
  householdIds: Record<string, string>;
}

/**
 * `now`: the moment the data is made around. `clock`: the time for plans (is a Premium still on, when was it changed),
 * the real one by default, as a plan given in the admin is.
 */
export function createFixtures(now: Date = new Date(), clock: () => number = () => Date.now()): Fixtures {
  const nowMs = now.getTime();
  const ids = seeded(1983);

  const households: Household[] = HOUSEHOLDS.map((seed) => ({
    seed,
    id: uuid(ids),
    createdAt: nowMs - seed.createdDaysAgo * DAY - between(ids, 1, 12) * HOUR,
  }));
  const householdByKey = new Map(households.map((household) => [household.seed.key, household]));

  const planRows = new Map<string, PlanRow>();
  for (const household of households) {
    const given = PLANS[household.seed.key];
    if (!given) continue;
    planRows.set(household.id, {
      plan: 'Premium',
      source: 'Manual',
      expiresAt: given.endsInDays === null ? null : nowMs + given.endsInDays * DAY,
      note: given.note,
      changedAt: nowMs - given.changedDaysAgo * DAY - 3 * HOUR,
      changedBy: OWNER_EMAIL,
    });
  }

  const planOf = (household: Household): PlanKind => effectivePlan(planRows.get(household.id), clock());

  function adminPlan(household: Household): AdminPlan {
    const row = planRows.get(household.id);
    const plan = planOf(household);
    return {
      plan,
      source: row?.source ?? null,
      expiresAt: row?.expiresAt == null ? null : iso(row.expiresAt),
      note: row?.note ?? null,
      changedAt: row ? iso(row.changedAt) : null,
      changedBy: row?.changedBy ?? null,
      aiPhotosUsed: AI_PHOTOS_USED[household.seed.key] ?? 0,
      aiPhotosPerMonth: plan === 'Premium' ? PREMIUM_AI_PHOTOS : FREE_AI_PHOTOS,
    };
  }

  const people: Person[] = PEOPLE.map((seed, index) => {
    const random = seeded(100 + index);
    const person: Person = {
      seed,
      id: uuid(ids),
      createdAt: nowMs - seed.createdDaysAgo * DAY - between(random, 0, 10) * HOUR,
      households: seed.households.map(([key, role]) => ({ key, role })),
      timeline: [],
      phoneIds: seed.phones.map(() => uuid(random)),
    };
    person.timeline = makeTimeline(person, index, random, nowMs, householdByKey);
    return person;
  });
  const personById = new Map(people.map((person) => [person.id, person]));

  const lastSeen = (person: Person): number | null => (person.timeline[0] ? Date.parse(person.timeline[0].at) : null);

  function membersOf(key: string) {
    return people.flatMap((person) =>
      person.households.filter((membership) => membership.key === key).map((membership) => ({ person, role: membership.role })),
    );
  }

  function joinedAt(person: Person, household: Household, role: Role): number {
    return role === 'Owner' ? household.createdAt : Math.max(household.createdAt, person.createdAt) + 3 * HOUR;
  }

  // Problems: 5xx answers, errors and crashes from everyone's визор, plus two server errors without a person.
  const allProblems: Problem[] = [];
  for (const person of people) {
    for (const event of person.timeline) {
      if (event.kind === 'request' && event.status !== null && event.status >= 500) {
        const path = event.text.slice(event.text.indexOf(' ') + 1);
        allProblems.push({ at: event.at, kind: 'server', userId: person.id, email: person.seed.email, text: `${event.text} → ${event.status}`, path, status: event.status });
      } else if (event.kind === 'error' || event.kind === 'crash') {
        allProblems.push({ at: event.at, kind: event.kind === 'crash' ? 'crash' : 'app-error', userId: person.id, email: person.seed.email, text: event.text, path: null, status: null });
      }
    }
  }
  allProblems.push(
    { at: iso(nowMs - 3 * HOUR - 17 * MINUTE), kind: 'server', userId: null, email: null, text: 'POST /api/v1/invites/preview → 502', path: '/api/v1/invites/preview', status: 502 },
    { at: iso(nowMs - 2 * DAY - 5 * HOUR), kind: 'server', userId: null, email: null, text: 'GET /health → 503', path: '/health', status: 503 },
  );
  allProblems.sort((a, b) => Date.parse(b.at) - Date.parse(a.at));

  const within = (at: string, ms: number) => nowMs - Date.parse(at) < ms;

  function overview(calm: boolean): Overview {
    const devices = people.flatMap((person) => person.seed.phones);
    const versions = new Map<string, number>();
    for (const phone of devices) versions.set(phone.version, (versions.get(phone.version) ?? 0) + 1);
    const day = people.flatMap((person) => person.timeline.filter((event) => within(event.at, DAY)));
    const problemsDay = allProblems.filter((problem) => within(problem.at, DAY));
    const models = [
      { model: 'gemini-2.5-flash', calls: 77, failed: calm ? 1 : 3 },
      { model: 'gemini-2.5-pro', calls: 10, failed: calm ? 0 : 1 },
    ];
    return {
      generatedAt: iso(nowMs),
      people: {
        users: people.length,
        households: households.length,
        sharedHouseholds: households.filter((household) => membersOf(household.seed.key).length > 1).length,
        premiumHouseholds: households.filter((household) => planOf(household) === 'Premium').length,
        pets: households.reduce((sum, household) => sum + household.seed.pets, 0),
        activeToday: people.filter((person) => person.timeline.some((event) => within(event.at, DAY))).length,
        activeWeek: people.filter((person) => person.timeline.some((event) => within(event.at, 7 * DAY))).length,
        newWeek: people.filter((person) => nowMs - person.createdAt < 7 * DAY).length,
      },
      reminders: calm
        ? { sent24h: 214, failed24h: 0, skipped24h: 17, expired24h: 0, pending: 46, oldestOverdueMinutes: 0 }
        : { sent24h: 214, failed24h: 2, skipped24h: 17, expired24h: 1, pending: 46, oldestOverdueMinutes: 14 },
      devices: {
        android: devices.filter((phone) => phone.platform === 'Android').length,
        ios: devices.filter((phone) => phone.platform === 'Ios').length,
        appVersions: [...versions].map(([version, count]) => ({ version, devices: count })).sort((a, b) => b.devices - a.devices),
      },
      ai: {
        calls24h: 31,
        failed24h: calm ? 0 : 1,
        calls30d: models.reduce((sum, model) => sum + model.calls, 0),
        failed30d: models.reduce((sum, model) => sum + model.failed, 0),
        inputTokens30d: 1_284_512,
        outputTokens30d: 211_806,
        models30d: models,
      },
      api: {
        requests24h: day.filter((event) => event.kind === 'request').length,
        serverErrors24h: calm ? 0 : problemsDay.filter((problem) => problem.kind === 'server').length,
        appErrors24h: problemsDay.filter((problem) => problem.kind === 'app-error').length,
        crashes24h: calm ? 0 : problemsDay.filter((problem) => problem.kind === 'crash').length,
      },
      server: calm
        ? { diskTotalBytes: 80 * GIB, diskFreeBytes: 51.2 * GIB, lastBackupAt: iso(nowMs - 7 * HOUR - 12 * MINUTE), lastBackupBytes: 1.3 * GIB }
        : { diskTotalBytes: 80 * GIB, diskFreeBytes: 6.9 * GIB, lastBackupAt: iso(nowMs - 31 * HOUR - 4 * MINUTE), lastBackupBytes: 1.3 * GIB },
      alerts: {
        telegramConfigured: true,
        recent: calm
          ? [{ kind: 'server-errors', text: 'Ошибок сервера за 15 минут: 6.', sentAt: iso(nowMs - 5 * DAY - 3 * HOUR) }]
          : [
              { kind: 'reminders-late', text: 'Напоминания задерживаются: самое старое ждёт 14 мин.', sentAt: iso(nowMs - 4 * MINUTE) },
              { kind: 'disk-low', text: 'Мало места на диске: свободно 6,9 ГБ из 80 ГБ.', sentAt: iso(nowMs - 2 * HOUR - 6 * MINUTE) },
              { kind: 'backup-old', text: 'Бэкап базы не обновлялся 29 ч.', sentAt: iso(nowMs - 2 * HOUR - 6 * MINUTE) },
              { kind: 'server-errors', text: 'Ошибок сервера за 15 минут: 6.', sentAt: iso(nowMs - DAY - 3 * HOUR) },
            ],
      },
    };
  }

  function userRow(person: Person): UserRow {
    const seen = lastSeen(person);
    return {
      id: person.id,
      email: person.seed.email,
      displayName: person.seed.name,
      createdAt: iso(person.createdAt),
      lastSeenAt: seen === null ? null : iso(seen),
      households: person.households.length,
      devices: person.seed.phones.length,
      aiCalls30d: person.seed.aiCalls30d,
    };
  }

  return {
    now,
    people: people.map((person) => ({ id: person.id, email: person.seed.email, name: person.seed.name })),
    householdIds: Object.fromEntries(households.map((household) => [household.seed.key, household.id])),
    overview,
    users(query, limit) {
      const needle = query.trim().toLowerCase();
      return people
        .filter(
          (person) =>
            !needle ||
            person.seed.email.toLowerCase().includes(needle) ||
            (person.seed.name ?? '').toLowerCase().includes(needle),
        )
        .sort((a, b) => b.createdAt - a.createdAt)
        .slice(0, limit)
        .map(userRow);
    },
    user(id) {
      const person = personById.get(id);
      if (!person) return null;
      const row = userRow(person);
      const ai = person.seed.aiCalls30d;
      return {
        id: person.id,
        email: person.seed.email,
        displayName: person.seed.name,
        locale: person.seed.locale,
        timeZone: person.seed.timeZone,
        createdAt: row.createdAt,
        lastSeenAt: row.lastSeenAt,
        households: person.households.map(({ key, role }) => {
          const household = householdByKey.get(key)!;
          return {
            id: household.id,
            name: household.seed.name,
            role,
            memberCount: membersOf(key).length,
            pets: household.seed.pets,
            plan: planOf(household),
          };
        }),
        devices: person.seed.phones.map((phone, index) => ({
          platform: phone.platform,
          appVersion: phone.version,
          lastSeenAt: iso((lastSeen(person) ?? person.createdAt + HOUR) - index * 6 * DAY),
        })),
        ai: { calls30d: ai, failed30d: Math.floor(ai / 7), inputTokens30d: ai * 14_250, outputTokens30d: ai * 2_310 },
      };
    },
    timeline(id, before, limit) {
      const person = personById.get(id);
      if (!person) return null;
      const until = before === null ? Number.POSITIVE_INFINITY : Date.parse(before);
      return person.timeline.filter((event) => Date.parse(event.at) < until).slice(0, limit);
    },
    household(id) {
      const household = households.find((item) => item.id === id);
      if (!household) return null;
      return {
        id: household.id,
        name: household.seed.name,
        timeZone: household.seed.timeZone,
        createdAt: iso(household.createdAt),
        members: membersOf(household.seed.key)
          .map(({ person, role }) => ({
            userId: person.id,
            email: person.seed.email,
            displayName: person.seed.name,
            role,
            joinedAt: iso(joinedAt(person, household, role)),
          }))
          .sort((a, b) => Date.parse(a.joinedAt) - Date.parse(b.joinedAt)),
        pets: household.seed.pets,
        routines: household.seed.routines,
        carePlans: household.seed.carePlans,
        supplies: household.seed.supplies,
        openInvites: household.seed.openInvites,
        plan: adminPlan(household),
      };
    },
    setPlan(householdId, request, adminEmail) {
      const household = households.find((item) => item.id === householdId);
      if (!household) return null;
      planRows.set(household.id, {
        plan: request.plan,
        source: 'Manual',
        // Free takes Premium back: its end goes too.
        expiresAt: request.plan === 'Premium' && request.expiresAt !== null ? Date.parse(request.expiresAt) : null,
        note: request.note,
        changedAt: clock(),
        changedBy: adminEmail,
      });
      return adminPlan(household);
    },
    problems(hours) {
      return allProblems.filter((problem) => within(problem.at, hours * HOUR)).slice(0, 300);
    },
  };
}

function iso(ms: number): string {
  return new Date(ms).toISOString();
}

/**
 * A week of one person's визор: launches of the app on each day since they signed up, each a run of screens, actions
 * and requests a few seconds apart; now and then a request without a session (the phone refreshing its push token).
 * The first person (Анна) always has a server error today and a crash yesterday, for the screens to show.
 */
function makeTimeline(
  person: Person,
  index: number,
  random: () => number,
  nowMs: number,
  householdByKey: Map<string, Household>,
): TimelineEvent[] {
  const events: TimelineEvent[] = [];
  const phone = person.seed.phones[0];
  if (!phone || person.seed.activity === 0) return events;
  const home = person.households[0] ? householdByKey.get(person.households[0].key)!.id : null;
  const stepIds: StepIds = { pet: uuid(random), record: uuid(random), plan: uuid(random), routine: uuid(random), supply: uuid(random) };

  // Day n: the 18 waking hours before "now minus n days", so the last 24 hours always have something.
  for (let daysAgo = 0; daysAgo < 7; daysAgo += 1) {
    const windowEnd = nowMs - daysAgo * DAY;
    if (windowEnd < person.createdAt) break;
    const launches = Math.floor(person.seed.activity + random());
    const starts = Array.from({ length: launches }, () => windowEnd - between(random, 10, 18 * 60) * MINUTE).sort((a, b) => a - b);

    // One launch at a time: a launch that would begin before the previous one ended waits for it.
    let previousEnd = 0;
    starts.forEach((planned, launch) => {
      const start = Math.max(planned, previousEnd + between(random, 2, 40) * MINUTE);
      if (start > nowMs - 2 * MINUTE || start < person.createdAt) return;
      const session = uuid(random);
      let t = start + between(random, 0, 59) * 1000;
      const push = (line: StepLine) => {
        if (t > nowMs) return;
        events.push({
          at: iso(t),
          kind: line.kind,
          text: line.text,
          status: line.kind === 'request' ? line.status : null,
          durationMs: line.kind === 'request' ? between(random, line.durationMs[0], line.durationMs[1]) : null,
          session,
          householdId: home,
          appVersion: phone.version,
        });
        t += line.kind === 'request' ? between(random, 300, 900) : between(random, 150, 600);
      };

      push(request(`PUT /api/v1/devices/${person.phoneIds[0]}`, 204, [30, 90]));
      push({ kind: 'screen', text: '/today' });
      push(request('GET /api/v1/today', 200, [40, 220]));
      const steps = between(random, 3, 16);
      const forcedError = index === 0 && daysAgo === 0 && launch === 0;
      for (let step = 0; step < steps; step += 1) {
        t += between(random, 3, 75) * 1000;
        const chosen = forcedError && step === 1 ? SERVER_ERROR : random() < 0.006 ? SERVER_ERROR : pickStep(random);
        for (const line of chosen(stepIds)) push(line);
      }
      if ((index === 0 && daysAgo === 1 && launch === 0) || random() < 0.015) push(CRASH);
      previousEnd = t;
    });

    if (random() < 0.5) {
      const at = windowEnd - between(random, 5, 23 * 60) * MINUTE;
      if (at < nowMs && at > person.createdAt) {
        events.push({
          at: iso(at),
          kind: 'request',
          text: `PUT /api/v1/devices/${person.phoneIds[0]}`,
          status: 204,
          durationMs: between(random, 30, 90),
          session: null,
          householdId: null,
          appVersion: phone.version,
        });
      }
    }
  }

  return events.sort((a, b) => Date.parse(b.at) - Date.parse(a.at));
}
