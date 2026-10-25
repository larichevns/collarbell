// A pretend Collarbell server for the tests and the demo (npm run dev:mock): a fetch() that answers /api/v1/… the way
// the real one does, from a world kept in memory. In the tests' world Anna owns the household "Home" (Murka the cat,
// Rex the dog, Tom who is archived) and helps in "Office"; the demo has a world of its own (src/mock/world.ts). Every
// request is written down (method, path, the household it named, the token, the body), and a test can send any
// request its own answer (respond), say for a 409 or a field the server refuses, or leave it the ordinary one.
//
// Download links are signed anew in every answer and live 15 minutes, as the real server's do. Request ids make a
// retry of an addition answer with what the first try added. Helpers only mark: their other changes get 403; the
// people, invites and settings of a household are for its owners. Supplies have their estimate worked out on every
// answer from their purchases and counts and the feedings that give them, the server's way (spec 5.3), and Today's
// "To buy" comes from it. AI reads scans and notes as world.reader says (src/test/ai.ts): a scan is "read" after
// world.readPolls questions about it and world.readMs; the month's AI photos and the day's notes are counted, the
// draft is saved as the server saves it, and the photos kept. Deleting the account wants a password typed again
// (the test auth's ";recent" token) and the fates the person was shown; after it, every request is refused as the
// server refuses a deleted account's.
import type {
  AiImport,
  AiImportError,
  AiImportSource,
  AiImportStatus,
  AiStatus,
  ApplyImportRequest,
  ApplyImportResponse,
  CareKind,
  CarePlan,
  CarePreset,
  CareRecord,
  CareRecordRequest,
  CarePlanRequest,
  CreateAiImportRequest,
  DayOfWeek,
  DocumentRequest,
  FeedingMark,
  FileLink,
  HouseholdDetails,
  HouseholdMember,
  HouseholdOutcome,
  HouseholdRole,
  HouseholdSummary,
  IdentifierReading,
  Me,
  Passport,
  PassportContact,
  PassportRequest,
  Pet,
  PetDocument,
  PetRequest,
  Plan,
  ProductDetails,
  ProductDraft,
  ProductSource,
  Routine,
  RoutineRequest,
  StockEvent,
  StockEventKind,
  Supply,
  SupplyFeeding,
  SupplyForecast,
  SupplyRequest,
  SupplyStatus,
  Today,
  TodaySupply,
  UpdateMeRequest,
  Visit,
  VisitRequest,
  Weight,
  WeightRequest,
} from '../api/types';
import { addDays, addInterval, daysBetween, todayIn } from '../lib/dates';
import { identifierProblem, MAX_IDENTIFIERS, normalizeCode } from '../lib/identifiers';
import { isValidGtin } from '../lib/supplies';
import { chipReading, defaultReader, productDraft, type Reader, type ReaderOutcome } from './ai';
import { PRESETS } from './presets';

export const ANNA = 'anna@example.com';
export const HOME = '11111111-1111-4111-8111-111111111111';
export const OFFICE = '22222222-2222-4222-8222-222222222222';
export const MURKA = 'aaaaaaaa-0000-4000-8000-000000000001';
export const REX = 'aaaaaaaa-0000-4000-8000-000000000002';
const TOM = 'aaaaaaaa-0000-4000-8000-000000000003';
const BARSIK = 'aaaaaaaa-0000-4000-8000-000000000004';
export const ZONE = 'Europe/Moscow';
/** The person signed in, as /me and the households' people name them. */
export const ME_ID = 'user-anna';
export const BORIS = 'user-boris';
/** A household Anna isn't in, which the code FRND-2345 lets her join as a helper. */
export const FRIENDS = '33333333-3333-4333-8333-333333333333';
export const FRIENDS_CODE = 'FRND-2345';

export interface Logged {
  method: string;
  path: string;
  query: URLSearchParams;
  household: string | null;
  authorization: string | null;
  body: unknown;
}

/** A test's own answer to a request; none (undefined): the ordinary answer. */
type Answer = (request: Logged) => Response | undefined | Promise<Response | undefined>;

/** An uploaded file: where it is, and whether it belongs somewhere yet (a file belongs to one place only). */
export interface StoredFile {
  id: string;
  contentType: string;
  sizeBytes: number;
  width: number | null;
  height: number | null;
  /** The address without its signature. */
  url: string;
  thumbnailUrl: string | null;
  attached: boolean;
}

/** Someone else in a household (the person signed in is the household's summary.role and joinedAt). */
export interface Person {
  userId: string;
  displayName: string | null;
  email: string | null;
  role: HouseholdRole;
  joinedAt: string;
}

/** An open invite: its code without the hyphen, as the server keeps it. */
export interface StoredInvite {
  id: string;
  code: string;
  role: HouseholdRole;
  createdAt: string;
  expiresAt: string;
  /** Who made it: ME_ID or another person's id. */
  createdBy: string;
}

/** A purchase (quantity added) or a count (quantity left), and who entered it. */
export interface StoredStockEvent {
  id: string;
  supplyId: string;
  kind: StockEventKind;
  quantity: number;
  at: string;
  byName: string | null;
  byMe: boolean;
}

/** A scan or note as kept: its photos by id, what AI made of it (decided when it started), how often it was asked. */
export interface StoredImport {
  id: string;
  petId: string;
  source: AiImportSource;
  status: AiImportStatus;
  fileIds: string[];
  text: string | null;
  error: AiImportError | null;
  model: string | null;
  createdAt: string;
  completedAt: string | null;
  appliedAt: string | null;
  result: ApplyImportResponse | null;
  requestId: string | null;
  /** What reading it gives: the draft once ready, or the failure. */
  outcome: ReaderOutcome;
  /** How many times it was asked about while being read. */
  polls: number;
}

/** A record as kept: its files by id (their links are signed in each answer). */
export type StoredRecord = Omit<CareRecord, 'files'> & { files: string[] };
/** A document as kept: its pages by file id. */
export type StoredDocument = Omit<PetDocument, 'pages'> & { pages: string[] };

export interface Household {
  /** The household and the person's role there; its memberCount is worked out from `others` in every answer. */
  summary: HouseholdSummary;
  /** When the person joined it: the people are listed in the order they joined. */
  joinedAt: string;
  /** Everyone else in it. */
  others: Person[];
  invites: StoredInvite[];
  /** An owner set the time zone (else a household of one follows its owner's phone). */
  timeZoneSetByHand: boolean;
  plan: Plan;
  pets: Pet[];
  plans: CarePlan[];
  routines: Routine[];
  marks: Map<string, FeedingMark>;
  visits: Visit[];
  records: StoredRecord[];
  passports: Map<string, Passport>;
  documents: StoredDocument[];
  /** The items as saved; their forecast and feedings are worked out in each answer. */
  supplies: Supply[];
  stock: StoredStockEvent[];
  /** The weighings; a vet's weights live in the check-up records. */
  weights: Weight[];
  /** The AI scans and notes, the oldest first. */
  imports: StoredImport[];
}

export interface World {
  /** Today in the households' time zone: the fixtures' dates count from it. */
  today: string;
  households: Map<string, Household>;
  /** The households the person is in, the first-joined first. */
  memberships: string[];
  locale: string;
  /** The person /me answers for; the time zone of their phone (default: ZONE). */
  me: { name: string; email: string; timeZone?: string };
  presets: readonly CarePreset[];
  files: Map<string, StoredFile>;
  /** What each request id added: a retry gets it again. */
  requestIds: Map<string, string>;
  /** What a barcode lookup finds beyond the household's own items, by the code. */
  products: Map<string, { product: ProductDetails; source: ProductSource }>;
  ai: AiStatus;
  /** When "Download my data" was asked for (ms): five an hour. */
  exports: number[];
  /** What AI makes of a scan or a note (the tests set their own). */
  reader: Reader;
  /** A scan is read after this many questions about it (the tests: one "processing" answer, then the draft)… */
  readPolls: number;
  /** …and this long after it started (the demo: a few seconds). */
  readMs: number;
  /** The notes AI read for the person today, and how many it reads a day (the server's Ai:TextEntriesPerDay). */
  notesRead: number;
  notesPerDay: number;
  /** What AI reads on a chip sticker, and on a package. */
  chipReadings: IdentifierReading[];
  productDraft: ProductDraft;
  /** The live updates' tickets given out. */
  tickets: string[];
  /** The account was deleted: every request is refused (401 account-deleted). */
  deleted: boolean;
}

export interface TestServer {
  fetch: typeof fetch;
  world: World;
  requests: Logged[];
  /** The requests of `method` to `path` (a path, or a pattern of paths). */
  calls(method: string, path: string | RegExp): Logged[];
  /** From now on `method path` gets `answer` (once: only the next one). */
  respond(method: string, path: string | RegExp, answer: Answer, options?: { once?: boolean }): void;
}

export interface ServerOptions {
  /** Where an uploaded file can be seen: a made-up address in the tests, the file itself in the demo. */
  fileUrl?: (id: string, file: Blob) => string;
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

/**
 * The type ASP.NET's problem details fill in for a status when the endpoint names none (TypedResults.Problem, a
 * validation problem, a 404): a link to the RFC's section. The API's own refusals name a type of their own instead.
 */
const GENERIC_TYPES: Record<number, string> = {
  400: 'https://tools.ietf.org/html/rfc9110#section-15.5.1',
  401: 'https://tools.ietf.org/html/rfc9110#section-15.5.2',
  403: 'https://tools.ietf.org/html/rfc9110#section-15.5.4',
  404: 'https://tools.ietf.org/html/rfc9110#section-15.5.5',
  409: 'https://tools.ietf.org/html/rfc9110#section-15.5.10',
  500: 'https://tools.ietf.org/html/rfc9110#section-15.6.1',
  502: 'https://tools.ietf.org/html/rfc9110#section-15.6.3',
  503: 'https://tools.ietf.org/html/rfc9110#section-15.6.4',
};

export const problem = (status: number, body: Record<string, unknown> = {}) =>
  new Response(JSON.stringify({ type: GENERIC_TYPES[status], status, title: 'Problem', ...body }), {
    status,
    headers: { 'Content-Type': 'application/problem+json' },
  });

/** A 400 with the failed checks by field, as ASP.NET writes them. */
const invalid = (errors: Record<string, string>) =>
  problem(400, {
    title: 'One or more validation errors occurred.',
    errors: Object.fromEntries(Object.entries(errors).map(([field, text]) => [field, [text]])),
  });

const noContent = () => new Response(null, { status: 204 });
const notFound = () => problem(404, { title: 'Not Found' });

let sequence = 0;
export const newId = () => `00000000-0000-4000-8000-${String((sequence += 1)).padStart(12, '0')}`;
const NOW = () => new Date().toISOString();
const DAY_MS = 86_400_000;
const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_UPLOAD = 15 * 1024 * 1024;
const MAX_RECORD_FILES = 10;
const MAX_DOCUMENT_PAGES = 50;
const WEEK: readonly DayOfWeek[] = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

// --- Making things --------------------------------------------------------------------------------------------------

export function pet(id: string, name: string, change: Partial<Pet> = {}): Pet {
  return {
    id,
    name,
    species: 'Cat',
    breed: null,
    sex: 'Unknown',
    birthDate: null,
    birthDateApproximate: false,
    neutered: null,
    neuteredOn: null,
    color: null,
    markings: null,
    coat: 'Smoke',
    allergies: null,
    notes: null,
    status: 'Active',
    photo: null,
    identifiers: [],
    createdAt: NOW(),
    updatedAt: NOW(),
    ...change,
  };
}

/** A plan due `daysLeft` days from today; its status is worked out on every answer. */
export function plan(
  id: string,
  petId: string,
  today: string,
  change: Partial<CarePlan> & { daysLeft: number },
): CarePlan {
  return {
    id,
    petId,
    kind: 'Other',
    title: 'Plan',
    intervalValue: 1,
    intervalUnit: 'Year',
    lastDoneOn: null,
    remindOffsetsDays: [7, 1, 0],
    defaultProduct: null,
    targets: [],
    presetCode: null,
    notes: null,
    active: true,
    createdAt: NOW(),
    updatedAt: NOW(),
    status: 'Upcoming',
    ...change,
    nextDueOn: change.nextDueOn ?? addDays(today, change.daysLeft),
  };
}

export function visit(id: string, change: Partial<Visit>): Visit {
  return {
    id,
    type: 'Vet',
    title: 'Visit',
    date: '2026-01-01',
    time: '10:30:00',
    startsAt: NOW(),
    durationMinutes: null,
    location: null,
    notes: null,
    petIds: [],
    remindOffsetsMinutes: [1440, 120],
    status: 'Planned',
    recordIds: [],
    createdAt: NOW(),
    updatedAt: NOW(),
    ...change,
  };
}

export function record(id: string, petId: string, change: Partial<StoredRecord>): StoredRecord {
  return {
    id,
    petId,
    planId: null,
    kind: 'Other',
    title: 'Record',
    performedOn: '2026-01-01',
    performedTime: null,
    product: null,
    manufacturer: null,
    batchNumber: null,
    validFrom: null,
    validUntil: null,
    targets: [],
    clinic: null,
    veterinarian: null,
    weightKg: null,
    details: null,
    notes: null,
    source: 'Manual',
    files: [],
    createdAt: NOW(),
    updatedAt: NOW(),
    ...change,
  };
}

export function routine(id: string, petId: string, change: Partial<Routine>): Routine {
  return {
    id,
    petId,
    kind: 'Feeding',
    times: ['08:00:00'],
    days: [...WEEK],
    food: null,
    amount: null,
    unit: null,
    notes: null,
    active: true,
    supplyItemId: null,
    createdAt: NOW(),
    updatedAt: NOW(),
    ...change,
  };
}

export function document(id: string, petId: string, change: Partial<StoredDocument>): StoredDocument {
  return {
    id,
    petId,
    type: 'Other',
    title: null,
    documentDate: null,
    notes: null,
    pages: [],
    createdAt: NOW(),
    updatedAt: NOW(),
    ...change,
  };
}

export function weighing(id: string, petId: string, change: Partial<Weight>): Weight {
  return {
    id,
    petId,
    source: 'Weighing',
    measuredOn: '2026-01-01',
    weightKg: 4,
    bcs: null,
    bcsScale: null,
    note: null,
    createdAt: NOW(),
    updatedAt: NOW(),
    ...change,
  };
}

export function supply(id: string, change: Partial<Supply>): Supply {
  return {
    id,
    name: 'Food',
    brand: null,
    barcode: null,
    category: 'DryFood',
    unit: 'Gram',
    packageSize: 2000,
    kcalPerKg: null,
    usageMode: 'Feeding',
    manualDailyUsage: null,
    leadTimeDays: 5,
    storeUrl: null,
    notes: null,
    active: true,
    forecast: {
      remaining: null,
      usagePerDay: null,
      daysLeft: null,
      runsOutOn: null,
      buyBy: null,
      status: 'NoStock',
      countedFrom: null,
    },
    feedings: [],
    createdAt: NOW(),
    updatedAt: NOW(),
    ...change,
  };
}

/** A scan (or a note) of a pet, ready to check unless said otherwise. */
export function aiImport(id: string, petId: string, change: Partial<StoredImport> = {}): StoredImport {
  return {
    id,
    petId,
    source: 'PassportPages',
    status: 'Ready',
    fileIds: [],
    text: null,
    error: null,
    model: 'gemini-3.8-flash',
    createdAt: NOW(),
    completedAt: NOW(),
    appliedAt: null,
    result: null,
    requestId: null,
    outcome: { draft: { records: [], identifiers: [], passport: null, weights: [] } },
    polls: 0,
    ...change,
  };
}

/** An upload not used anywhere yet (a scan's photo, until the scan is saved). */
export function uploadedFile(world: Pick<World, 'files'>, id: string): string {
  storedFile(world, id, `https://files.example/${id}`);
  world.files.get(id)!.attached = false;
  return id;
}

/** A file the world has, as if uploaded: a photo (with its small version) or a PDF. */
export function storedFile(
  world: Pick<World, 'files'>,
  id: string,
  url: string,
  contentType = 'image/jpeg',
  thumbnailUrl: string | null = contentType === 'application/pdf' ? null : `${url}/small`,
): string {
  world.files.set(id, {
    id,
    contentType,
    sizeBytes: contentType === 'application/pdf' ? 180_000 : 240_000,
    width: contentType === 'application/pdf' ? null : 1240,
    height: contentType === 'application/pdf' ? null : 1754,
    url,
    thumbnailUrl,
    attached: true,
  });
  return id;
}

export function emptyHousehold(summary: HouseholdSummary): Household {
  return {
    summary,
    joinedAt: '2025-01-10T09:00:00Z',
    others: [],
    invites: [],
    timeZoneSetByHand: false,
    plan: freePlan(),
    pets: [],
    plans: [],
    routines: [],
    marks: new Map(),
    visits: [],
    records: [],
    passports: new Map(),
    documents: [],
    supplies: [],
    stock: [],
    weights: [],
    imports: [],
  };
}

/** The Free plan with some of this month's AI photos used; the count starts again on the 1st (UTC). */
export function freePlan(change: Partial<Plan> = {}): Plan {
  const now = new Date();
  return {
    plan: 'Free',
    source: null,
    expiresAt: null,
    aiPhotosPerMonth: 20,
    aiPhotosUsed: 7,
    resetsAt: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString(),
    premiumAiPhotosPerMonth: 300,
    ...change,
  };
}

/** Someone else in a household. */
export function person(userId: string, displayName: string | null, email: string | null, role: HouseholdRole): Person {
  return { userId, displayName, email, role, joinedAt: '2025-03-01T09:00:00Z' };
}

/** A purchase or a count of a supply, `daysAgo` days ago (a fraction is part of a day), by the person signed in. */
export function stockEntry(
  supplyId: string,
  kind: StockEventKind,
  quantity: number,
  daysAgo = 0,
  by: { name: string | null; me: boolean } = { name: 'Anna', me: true },
): StoredStockEvent {
  return {
    id: newId(),
    supplyId,
    kind,
    quantity,
    at: new Date(Date.now() - daysAgo * DAY_MS).toISOString(),
    byName: by.name,
    byMe: by.me,
  };
}

/** AI set up on the server, on Gemini's free tier. */
export function aiStatus(change: Partial<AiStatus> = {}): AiStatus {
  return {
    configured: true,
    models: [{ provider: 'Gemini', model: 'gemini-3.8-flash', ready: true }],
    freeTier: true,
    thisMonth: { requests: 12, inputTokens: 48_000, outputTokens: 6_100 },
    ...change,
  };
}

/** The world the tests start with. */
function createWorld(): World {
  const today = todayIn(ZONE);
  const files = new Map<string, StoredFile>();
  const world: World = {
    today,
    households: new Map(),
    memberships: [HOME, OFFICE],
    locale: 'en',
    me: { name: 'Anna', email: ANNA },
    presets: PRESETS,
    files,
    requestIds: new Map(),
    products: new Map([
      [
        '5901234123457',
        {
          source: 'OpenPetFoodFacts',
          product: {
            name: 'Purina One Sterilcat',
            brand: 'Purina',
            category: 'DryFood',
            unit: 'Gram',
            packageSize: 1500,
            kcalPerKg: 3800,
          },
        },
      ],
      [
        '4006381333931',
        {
          source: 'UpcItemDb',
          product: {
            name: 'Whiskas pouches',
            brand: 'Whiskas',
            category: null,
            unit: null,
            packageSize: null,
            kcalPerKg: null,
          },
        },
      ],
    ]),
    ai: aiStatus(),
    exports: [],
    ...aiWorld(),
  };
  const home = emptyHousehold({ id: HOME, name: 'Home', role: 'Owner', timeZone: ZONE, memberCount: 2 });
  home.others = [person(BORIS, 'Boris', 'boris@example.com', 'Member')];
  home.pets = [
    pet(MURKA, 'Murka', {
      species: 'Cat',
      sex: 'Female',
      breed: 'Siberian',
      coat: 'Ginger',
      birthDate: addInterval(today, -3, 'Year'),
      neutered: true,
      identifiers: [
        {
          id: newId(),
          type: 'IsoChip',
          code: '643094100000001',
          rawCode: '643 094 100 000 001',
          appliedOn: null,
          readOn: null,
          location: 'Left side of the neck',
        },
      ],
    }),
    pet(REX, 'Rex', { species: 'Dog', sex: 'Male', coat: 'Cocoa' }),
    pet(TOM, 'Tom', { status: 'Archived' }),
  ];
  home.plans = [
    plan('plan-rabies', MURKA, today, {
      kind: 'Vaccination',
      title: 'Rabies',
      daysLeft: -3,
      defaultProduct: 'Nobivac Rabies',
      targets: ['Rabies'],
    }),
    plan('plan-deworm', REX, today, {
      kind: 'Deworming',
      title: 'Deworming',
      daysLeft: 5,
      intervalValue: 3,
      intervalUnit: 'Month',
    }),
    plan('plan-exam', MURKA, today, { kind: 'VetExam', title: 'Yearly check-up', daysLeft: 20 }),
    plan('plan-fleas', MURKA, today, {
      kind: 'FleaTick',
      title: 'Fleas and ticks',
      daysLeft: 40,
      intervalUnit: 'Month',
      active: false,
    }),
  ];
  home.routines = [
    routine('routine-murka', MURKA, {
      times: ['08:00:00', '19:00:00'],
      food: 'Royal Canin',
      amount: 40,
      unit: 'Gram',
      supplyItemId: 'supply-food',
    }),
    routine('routine-rex', REX, { times: ['08:00:00'], amount: 200, unit: 'Gram' }),
  ];
  // Murka eats 80 g a day of it: 200 g left lasts two and a half days, within the five days of delivery.
  home.supplies = [
    supply('supply-food', { name: 'Royal Canin Sterilised', brand: 'Royal Canin', barcode: '4600699503415' }),
    supply('supply-litter', { name: 'Clumping litter', category: 'Litter', usageMode: 'Manual' }),
  ];
  home.stock = [
    stockEntry('supply-food', 'Purchase', 2000, 30),
    stockEntry('supply-food', 'Adjustment', 200, 0, { name: 'Boris', me: false }),
  ];
  home.visits = [
    visit('visit-vet', { type: 'Vet', title: 'Check-up', date: addDays(today, -1), petIds: [MURKA] }),
    visit('visit-groomer', {
      type: 'Grooming',
      title: 'Groomer',
      date: addDays(today, 7),
      time: '15:00:00',
      petIds: [REX],
      location: 'Happy Paws',
    }),
    visit('visit-old', {
      type: 'Vet',
      title: 'Vaccination',
      date: addDays(today, -40),
      status: 'Done',
      petIds: [MURKA],
    }),
  ];
  home.records = [
    record('record-rabies', MURKA, {
      kind: 'Vaccination',
      title: 'Rabies',
      performedOn: addDays(today, -368),
      product: 'Nobivac Rabies',
      batchNumber: 'A123',
      validFrom: addDays(today, -368),
      validUntil: addDays(today, -3),
      targets: ['Rabies'],
      veterinarian: 'Dr. Petrova',
      files: [storedFile(world, 'file-sticker', 'https://files.example/file-sticker')],
    }),
    record('record-deworm', MURKA, {
      kind: 'Deworming',
      title: 'Deworming',
      performedOn: addDays(today, -60),
      product: 'Milbemax',
    }),
    record('record-exam', MURKA, {
      kind: 'VetExam',
      title: 'Check-up',
      performedOn: addDays(today, -30),
      clinic: 'Vet+',
      weightKg: 4.1,
      details: { laboratory: null, reportNumber: null, titerIuPerMl: null, fitForTravel: true },
    }),
  ];
  home.passports.set(MURKA, {
    petId: MURKA,
    model: 'Eu2014',
    passportNumber: 'RU0123456',
    issuingCountry: 'RU',
    issuedOn: addInterval(today, -2, 'Year'),
    issuer: { name: 'Dr. Petrova', address: 'Vet+, Lenina 1', phone: null, email: null },
    owners: [{ name: 'Anna', address: null, phone: '+7 900 000-00-00', email: ANNA }],
    notes: null,
    updatedAt: NOW(),
  });
  home.documents = [
    document('doc-passport', MURKA, {
      type: 'PassportPage',
      createdAt: '2026-01-10T10:00:00Z',
      pages: [
        storedFile(world, 'file-page-1', 'https://files.example/file-page-1'),
        storedFile(world, 'file-page-2', 'https://files.example/file-page-2'),
      ],
    }),
    document('doc-lab', MURKA, {
      type: 'LabResult',
      title: 'Blood test',
      documentDate: addDays(today, -20),
      pages: [storedFile(world, 'file-lab', 'https://files.example/file-lab.pdf', 'application/pdf')],
    }),
  ];
  home.weights = [
    weighing('weight-1', MURKA, { measuredOn: addDays(today, -200), weightKg: 3.85 }),
    weighing('weight-2', MURKA, { measuredOn: addDays(today, -10), weightKg: 4.2, bcs: 5, bcsScale: 9 }),
  ];
  const office = emptyHousehold({ id: OFFICE, name: 'Office', role: 'Helper', timeZone: ZONE, memberCount: 3 });
  office.joinedAt = '2025-06-01T09:00:00Z';
  office.others = [
    person('user-olga', 'Olga', 'olga@example.com', 'Owner'),
    person('user-pavel', null, 'pavel@example.com', 'Member'),
  ];
  office.pets = [pet(BARSIK, 'Barsik', { coat: 'Lilac' })];
  office.routines = [routine('routine-barsik', BARSIK, { times: ['09:00:00'] })];
  // Friends of Anna's, whose owner gave her a code.
  const friends = emptyHousehold({ id: FRIENDS, name: 'Friends', role: 'Helper', timeZone: ZONE, memberCount: 1 });
  friends.others = [person('user-ivan', 'Ivan', 'ivan@example.com', 'Owner')];
  friends.invites = [invite('invite-friends', FRIENDS_CODE, 'Helper', 'user-ivan')];
  world.households.set(HOME, home);
  world.households.set(OFFICE, office);
  world.households.set(FRIENDS, friends);
  return world;
}

/** The AI of a world: the default reader, read at the second question, 30 notes a day, a chip and a package to read. */
export function aiWorld(): Pick<
  World,
  'reader' | 'readPolls' | 'readMs' | 'notesRead' | 'notesPerDay' | 'chipReadings' | 'productDraft' | 'tickets' | 'deleted'
> {
  return {
    reader: defaultReader,
    readPolls: 1,
    readMs: 0,
    notesRead: 0,
    notesPerDay: 30,
    chipReadings: [chipReading()],
    productDraft: productDraft(),
    tickets: [],
    deleted: false,
  };
}

/** An open invite made today, for seven days. */
export function invite(id: string, code: string, role: HouseholdRole, createdBy = ME_ID): StoredInvite {
  return {
    id,
    code: code.replace('-', ''),
    role,
    createdAt: NOW(),
    expiresAt: new Date(Date.now() + 7 * DAY_MS).toISOString(),
    createdBy,
  };
}

/** Where a feeding's mark is kept in a household's `marks`. */
export const markKey = (routineId: string, date: string, time: string) => `${routineId}@${date}@${time}`;

/** Someone else marks a feeding of today, on their phone. */
export function markedElsewhere(world: World, routineId: string, time: string, byName: string): FeedingMark {
  const mark: FeedingMark = {
    id: newId(),
    routineId,
    date: world.today,
    time,
    status: 'Done',
    doneAt: `${world.today}T05:02:00Z`,
    byName,
    byMe: false,
  };
  world.households.get(HOME)!.marks.set(markKey(routineId, world.today, time), mark);
  return mark;
}

// --- Answers --------------------------------------------------------------------------------------------------------

/** The endpoints of a person's own: a household they aren't in any more answers as their first one. */
const PERSONAL = new Set([
  '/api/v1/me',
  '/api/v1/me/export',
  '/api/v1/me/deletion',
  '/api/v1/households',
  '/api/v1/invites/preview',
  '/api/v1/invites/accept',
  '/api/v1/live/tickets',
]);

/** At most this many photos a scan, and a chip's or a package's (the server's). */
const MAX_SCAN_PHOTOS = 10;
const MAX_READER_PHOTOS = 3;
/** A note is a few sentences. */
const MAX_NOTE = 1000;

/** The most households one person can be in, and open invites of one household (the server's). */
const MAX_HOUSEHOLDS = 20;
const MAX_OPEN_INVITES = 20;
const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** "Download my data": five an hour per person. */
const EXPORTS_PER_HOUR = 5;

export function createTestServer(world: World = createWorld(), options: ServerOptions = {}): TestServer {
  const requests: Logged[] = [];
  const answers: { method: string; path: string | RegExp; answer: Answer; once: boolean }[] = [];
  const matches = (path: string, pattern: string | RegExp) =>
    typeof pattern === 'string' ? path === pattern : pattern.test(path);
  let signature = 0;
  const fileUrl = options.fileUrl ?? ((id: string) => `https://files.example/${id}`);

  /** A file's link as an answer gives it: signed anew, alive for 15 minutes. */
  function link(id: string): FileLink {
    const file = world.files.get(id);
    signature += 1;
    const signed = (url: string) =>
      url.startsWith('http') ? `${url}${url.includes('?') ? '&' : '?'}sig=${signature}` : `${url}#sig=${signature}`;
    return {
      id,
      contentType: file?.contentType ?? 'image/jpeg',
      sizeBytes: file?.sizeBytes ?? 1000,
      width: file?.width ?? null,
      height: file?.height ?? null,
      url: signed(file?.url ?? `https://files.example/${id}`),
      thumbnailUrl: file?.thumbnailUrl ? signed(file.thumbnailUrl) : null,
      expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
    };
  }

  /** A pet's photo signed anew, when the world knows its file. */
  const petOut = (item: Pet): Pet =>
    item.photo && world.files.has(item.photo.id) ? { ...item, photo: link(item.photo.id) } : item;
  const recordOut = (item: StoredRecord): CareRecord => ({ ...item, files: item.files.map(link) });
  const documentOut = (item: StoredDocument): PetDocument => ({ ...item, pages: item.pages.map(link) });

  /** A plan's status on the household's today. */
  function planOut(item: CarePlan): CarePlan {
    const daysLeft = daysBetween(world.today, item.nextDueOn);
    const status = !item.active ? 'Inactive' : daysLeft < 0 ? 'Overdue' : daysLeft <= 14 ? 'DueSoon' : 'Upcoming';
    return { ...item, daysLeft, status };
  }

  /** The files of a request: known, and not in another place yet (or in `own` already). */
  function filesProblem(fileIds: readonly string[], own: readonly string[] = []): string | null {
    if (new Set(fileIds).size !== fileIds.length) return 'Each file can be used once.';
    for (const id of fileIds) {
      const file = world.files.get(id);
      if (!file) return 'Unknown file: upload it first.';
      if (file.attached && !own.includes(id)) return 'This file is already used; upload it again.';
    }
    return null;
  }
  const attach = (fileIds: readonly string[]) => fileIds.forEach((id) => (world.files.get(id)!.attached = true));
  const release = (fileIds: readonly string[]) => fileIds.forEach((id) => world.files.delete(id));

  /** An entry of the person signed in. */
  const myEntry = () => ({ name: world.me.name.trim() || world.me.email, me: true });

  /** The open invite with a code as typed (any case, with or without the hyphen), and its household. */
  function openInvite(typed: string): { invite: StoredInvite; household: Household } | null {
    const code = typed.replace(/[\s-]/g, '').toUpperCase();
    for (const each of world.households.values()) {
      const found = each.invites.find((item) => item.code === code && Date.parse(item.expiresAt) > Date.now());
      if (found) return { invite: found, household: each };
    }
    return null;
  }

  let seed = 20_261_007;
  /** A code nobody has: eight characters without 0, O, 1 and I, the same in every run. */
  function newInviteCode(): string {
    let code = '';
    for (let index = 0; index < 8; index += 1) {
      seed = (seed * 1_103_515_245 + 12_345) % 2_147_483_648;
      code += INVITE_ALPHABET[seed % INVITE_ALPHABET.length];
    }
    return code;
  }

  /** What a request id added before, if anything: the retry gets it again. */
  const earlier = (requestId: unknown) =>
    typeof requestId === 'string' ? (world.requestIds.get(requestId) ?? null) : null;
  const remember = (requestId: unknown, id: string) => {
    if (typeof requestId === 'string') world.requestIds.set(requestId, id);
  };

  function todayOf(household: Household, date: string): Today {
    const petOf = (id: string) => household.pets.find((item) => item.id === id)!;
    const active = (id: string) => petOf(id)?.status === 'Active';
    const weekday = WEEK[new Date(`${date}T00:00:00Z`).getUTCDay()]!;
    const feedings = household.routines
      .filter((item) => item.active && active(item.petId) && item.days.includes(weekday))
      .flatMap((item) => item.times.map((time) => ({ item, time })));
    return {
      date,
      feedings: feedings.map(({ item, time }) => ({
        routineId: item.id,
        petId: item.petId,
        petName: petOf(item.petId).name,
        petCoat: petOf(item.petId).coat,
        petPhoto: petOut(petOf(item.petId)).photo,
        time,
        food: item.food,
        amount: item.amount,
        unit: item.unit,
        mark: household.marks.get(markKey(item.id, date, time)) ?? null,
      })),
      appointments: household.visits
        .filter((item) => item.status === 'Planned')
        .map((item) => ({
          id: item.id,
          type: item.type,
          title: item.title,
          date: item.date,
          time: item.time,
          startsAt: item.startsAt,
          daysAway: daysBetween(date, item.date),
          location: item.location,
          pets: item.petIds.map((id) => ({
            id,
            name: petOf(id).name,
            coat: petOf(id).coat,
            photo: petOut(petOf(id)).photo,
          })),
        })),
      care: household.plans
        .map(planOut)
        .filter((item) => item.active && active(item.petId) && daysBetween(date, item.nextDueOn) <= 30)
        .sort((a, b) => a.nextDueOn.localeCompare(b.nextDueOn))
        .map((item) => ({
          planId: item.id,
          petId: item.petId,
          petName: petOf(item.petId).name,
          petCoat: petOf(item.petId).coat,
          petPhoto: petOut(petOf(item.petId)).photo,
          kind: item.kind,
          title: item.title,
          nextDueOn: item.nextDueOn,
          status: item.status,
          daysLeft: daysBetween(date, item.nextDueOn),
        })),
      shopping: shoppingOf(household),
    };
  }

  /** The household as the lists show it: how many people are in it, the person too. */
  function summaryOf(household: Household): HouseholdSummary {
    return { ...household.summary, memberCount: household.others.length + 1 };
  }

  function myHouseholds(): HouseholdSummary[] {
    return world.memberships.map((each) => summaryOf(world.households.get(each)!));
  }

  /** The person's own entry in a household's people. */
  function meIn(household: Household): HouseholdMember {
    return {
      userId: ME_ID,
      displayName: world.me.name.trim() || null,
      email: world.me.email,
      role: household.summary.role,
      joinedAt: household.joinedAt,
      isMe: true,
    };
  }

  /** The household with its people in the order they joined; its open invites for owners; e-mails hidden from helpers. */
  function detailsOf(household: Household): HouseholdDetails {
    const { id, name, timeZone, role } = household.summary;
    const helperView = role === 'Helper';
    const members = [
      meIn(household),
      ...household.others.map((other) => ({ ...other, email: helperView ? null : other.email, isMe: false })),
    ].sort((a, b) => a.joinedAt.localeCompare(b.joinedAt));
    const now = Date.now();
    return {
      id,
      name,
      timeZone,
      timeZoneSetByHand: household.timeZoneSetByHand,
      role,
      members,
      invites:
        role === 'Owner'
          ? household.invites
              .filter((item) => Date.parse(item.expiresAt) > now)
              .map(({ id: inviteId, code, role: invited, createdAt, expiresAt }) => ({
                id: inviteId,
                code: `${code.slice(0, 4)}-${code.slice(4)}`,
                role: invited,
                createdAt,
                expiresAt,
              }))
          : [],
    };
  }

  /** Nobody is without a household: the person left with none gets a new one of their own. */
  function ensureHousehold(): void {
    if (world.memberships.length > 0) return;
    const id = newId();
    const zone = world.me.timeZone ?? ZONE;
    const created = emptyHousehold({ id, name: 'Home', role: 'Owner', timeZone: zone, memberCount: 1 });
    created.joinedAt = NOW();
    world.households.set(id, created);
    world.memberships.push(id);
  }

  /** The feedings of active pets' active schedules that give an item. */
  function feedingsOf(household: Household, item: Supply): { feedings: SupplyFeeding[]; usage: number | null } {
    let usage = 0;
    const feedings = household.routines
      .filter((each) => each.active && each.supplyItemId === item.id)
      .flatMap((each) => {
        const owner = household.pets.find((candidate) => candidate.id === each.petId);
        if (!owner || owner.status !== 'Active') return [];
        const timesPerDay = (each.times.length * (each.days.length || 7)) / 7;
        const counted = item.usageMode === 'Feeding' && (each.amount ?? 0) > 0 && each.unit === item.unit;
        if (counted) usage += each.amount! * timesPerDay;
        return [
          {
            routineId: each.id,
            petId: each.petId,
            petName: owner.name,
            amount: each.amount,
            unit: each.unit,
            timesPerDay: Math.round(timesPerDay * 1000) / 1000,
            counted,
          },
        ];
      })
      .sort((a, b) => a.petName.localeCompare(b.petName));
    if (item.usageMode === 'Manual') return { feedings, usage: item.manualDailyUsage };
    return { feedings, usage: usage > 0 ? usage : null };
  }

  /** An item as answers give it: with its estimate on the household's today, and the feedings that give it. */
  function supplyOut(household: Household, item: Supply): Supply {
    const { feedings, usage } = feedingsOf(household, item);
    const events = household.stock.filter((entry) => entry.supplyId === item.id);
    return {
      ...item,
      forecast: forecastOf(events, usage, item.leadTimeDays, new Date(), household.summary.timeZone),
      feedings,
    };
  }

  /** The list's order: active first, the most urgent first, then by when they run out and by name. */
  function suppliesOf(household: Household): Supply[] {
    const urgency: Record<SupplyStatus, number> = {
      OutOfStock: 0,
      BuyNow: 1,
      Soon: 2,
      NoStock: 3,
      NoUsage: 4,
      Enough: 5,
    };
    return household.supplies
      .map((item) => supplyOut(household, item))
      .sort(
        (a, b) =>
          Number(!a.active) - Number(!b.active) ||
          urgency[a.forecast.status] - urgency[b.forecast.status] ||
          (a.forecast.runsOutOn ?? '9999').localeCompare(b.forecast.runsOutOn ?? '9999') ||
          a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }),
      );
  }

  /** Today's "To buy": what is still bought and ran out, or runs out within its delivery time. */
  function shoppingOf(household: Household): TodaySupply[] {
    return household.supplies
      .map((item) => supplyOut(household, item))
      .filter((item) => item.active && (item.forecast.status === 'BuyNow' || item.forecast.status === 'OutOfStock'))
      .sort(
        (a, b) =>
          (a.forecast.runsOutOn ?? '').localeCompare(b.forecast.runsOutOn ?? '') || a.name.localeCompare(b.name),
      )
      .map((item) => ({
        id: item.id,
        name: item.name,
        brand: item.brand,
        category: item.category,
        unit: item.unit,
        packageSize: item.packageSize,
        status: item.forecast.status,
        remaining: item.forecast.remaining,
        daysLeft: item.forecast.daysLeft,
        runsOutOn: item.forecast.runsOutOn,
      }));
  }

  /** A scan as answers give it: its photos signed anew, its draft once ready. */
  function importOut(item: StoredImport): AiImport {
    return {
      id: item.id,
      petId: item.petId,
      source: item.source,
      status: item.status,
      pages: item.fileIds.filter((id) => world.files.has(id)).map(link),
      draft: item.status === 'Ready' && 'draft' in item.outcome ? item.outcome.draft : null,
      error: item.error,
      model: item.model,
      createdAt: item.createdAt,
      completedAt: item.completedAt,
      appliedAt: item.appliedAt,
      result: item.result,
      text: item.text,
    };
  }

  /** A scan being read is read once asked about often enough (`asked`: by its own address) and long enough after. */
  function advance(item: StoredImport, asked: boolean): void {
    if (item.status !== 'Queued' && item.status !== 'Processing') return;
    if (asked) item.polls += 1;
    if (item.polls <= world.readPolls || Date.now() - Date.parse(item.createdAt) < world.readMs) {
      if (item.polls > 0) item.status = 'Processing';
      return;
    }
    item.completedAt = NOW();
    if ('draft' in item.outcome) {
      item.status = 'Ready';
      item.model = 'gemini-3.8-flash';
    } else {
      item.status = 'Failed';
      item.error = item.outcome.error;
    }
  }

  /** What deleting the account does to each of the person's households, and the fingerprint of those fates. */
  function deletionPreview(): { households: HouseholdOutcome[]; plan: string } {
    const households = world.memberships.map((id): HouseholdOutcome => {
      const each = world.households.get(id)!;
      const theirs = [...each.others].sort((a, b) => a.joinedAt.localeCompare(b.joinedAt));
      const heir = theirs.find((other) => other.role === 'Member');
      const role = each.summary.role;
      const fate =
        theirs.length === 0
          ? 'Deleted'
          : role !== 'Owner' || theirs.some((other) => other.role === 'Owner')
            ? 'Kept'
            : heir
              ? 'HandedOver'
              : 'Deleted';
      return {
        id,
        name: each.summary.name,
        role,
        fate,
        pets: each.pets.length,
        others: theirs.length,
        newOwner: fate === 'HandedOver' ? (heir!.displayName ?? heir!.email) : null,
      };
    });
    const fates = households.map((each) => `${each.id}:${each.fate}:${each.newOwner ?? ''}`).join('|');
    return { households, plan: fingerprint(fates) };
  }

  function stockOut(entry: StoredStockEvent): StockEvent {
    const { id, kind, quantity, at, byName, byMe } = entry;
    return { id, kind, quantity, at, byName, byMe };
  }

  /** The weight log: the weighings and the check-ups' weights, newest first. */
  function weightsOf(household: Household, petId: string): Weight[] {
    const vet: Weight[] = household.records
      .filter((item) => item.petId === petId && item.kind === 'VetExam' && item.weightKg !== null)
      .map((item) => ({
        id: item.id,
        petId,
        source: 'CareRecord',
        measuredOn: item.performedOn,
        weightKg: item.weightKg!,
        bcs: null,
        bcsScale: null,
        note: item.title,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      }));
    return [...household.weights.filter((item) => item.petId === petId), ...vet].sort(
      (a, b) => b.measuredOn.localeCompare(a.measuredOn) || b.createdAt.localeCompare(a.createdAt),
    );
  }

  async function serve(logged: Logged, request: Request): Promise<Response> {
    const { method, path } = logged;
    if (path === '/health') return json(200, { status: 'Healthy' });
    if (!logged.authorization?.startsWith('Bearer token:')) return problem(401, { title: 'Unauthorized' });
    // A deleted account's token still works with Firebase for up to an hour: the server refuses it.
    if (world.deleted) {
      return problem(401, { title: 'This account has been deleted.', type: 'urn:collarbell:problem:account-deleted' });
    }

    const named = logged.household;
    const member = named ? world.memberships.includes(named) : true;
    if (!member && !PERSONAL.has(path)) {
      return problem(403, { type: 'urn:collarbell:problem:not-a-household-member' });
    }
    ensureHousehold();
    const householdId = named && member ? named : world.memberships[0]!;
    const household = world.households.get(householdId)!;
    const role = household.summary.role;
    const helper = role === 'Helper';
    const helperRefused = () => problem(403, { type: 'urn:collarbell:problem:role-forbidden' });
    const body = (logged.body ?? {}) as Record<string, unknown>;
    const petById = (id: string) => household.pets.find((item) => item.id === id);
    let match: RegExpExecArray | null;
    const route = (pattern: RegExp, verb: string) => method === verb && (match = pattern.exec(path)) !== null;
    const param = (index = 1) => match![index]!;

    // --- The person and the households ---
    const meOut = (): Me => {
      const { id, name, role: shown, timeZone } = household.summary;
      return {
        id: ME_ID,
        email: world.me.email,
        displayName: world.me.name.trim() || null,
        locale: world.locale,
        timeZone: world.me.timeZone ?? ZONE,
        household: { id, name, role: shown, timeZone },
        households: myHouseholds(),
      };
    };
    if (path === '/api/v1/me' && method === 'GET') {
      return json(200, meOut());
    }
    if (path === '/api/v1/me' && method === 'PUT') {
      const input = body as unknown as UpdateMeRequest;
      if ((input.displayName ?? '').length > 100) return invalid({ displayName: 'Use 100 characters or fewer.' });
      if (input.locale !== null && input.locale !== undefined && !['en', 'ru'].includes(input.locale)) {
        return invalid({ locale: 'Use one of: en, ru.' });
      }
      if (input.displayName !== null && input.displayName !== undefined) world.me.name = input.displayName.trim();
      if (input.locale) world.locale = input.locale;
      if (input.timeZone) world.me.timeZone = input.timeZone;
      return json(200, meOut());
    }
    if (path === '/api/v1/me/deletion' && method === 'GET') {
      return json(200, deletionPreview());
    }
    if (path === '/api/v1/me' && method === 'DELETE') {
      // The password typed in the last five minutes, as the token's auth_time says.
      if (!logged.authorization?.includes(';recent')) {
        return problem(403, {
          type: 'urn:collarbell:problem:recent-sign-in-required',
          title: 'Sign in again to delete the account.',
        });
      }
      // Only while the households' fates are the ones the person was shown.
      if (logged.query.get('plan') !== deletionPreview().plan) {
        return problem(409, {
          type: 'urn:collarbell:problem:deletion-plan-changed',
          title: "The households' fates changed: look again.",
        });
      }
      world.deleted = true;
      return noContent();
    }
    if (path === '/api/v1/live/tickets' && method === 'POST') {
      const ticket = `ticket-${world.tickets.length + 1}`;
      world.tickets.push(ticket);
      return json(200, { ticket, expiresAt: new Date(Date.now() + 60_000).toISOString() });
    }
    if (path === '/api/v1/me/export' && method === 'GET') {
      const now = Date.now();
      world.exports = world.exports.filter((at) => now - at < 3_600_000);
      if (world.exports.length >= EXPORTS_PER_HOUR) {
        // Until the oldest of them is an hour old.
        const wait = Math.ceil((Math.min(...world.exports) + 3_600_000 - now) / 1000);
        return new Response(null, { status: 429, headers: { 'Retry-After': String(wait) } });
      }
      world.exports.push(now);
      const name = `collarbell-export-${new Date(now).toISOString().slice(0, 10)}.zip`;
      const zip = zipOf('README.txt', `Collarbell: everything of ${world.me.email}.\n`);
      return new Response(zip, {
        status: 200,
        headers: {
          'Content-Type': 'application/zip',
          'Content-Disposition': `attachment; filename=${name}; filename*=UTF-8''${name}`,
        },
      });
    }
    if (path === '/api/v1/households' && method === 'GET') {
      return json(200, myHouseholds());
    }
    if (path === '/api/v1/households' && method === 'POST') {
      const name = typeof body.name === 'string' ? body.name.trim() : '';
      if (!name) return invalid({ name: 'Give the household a name.' });
      if (name.length > 100) return invalid({ name: 'Use 100 characters or fewer.' });
      if (world.memberships.length >= MAX_HOUSEHOLDS) {
        return problem(409, { type: 'urn:collarbell:problem:household-limit' });
      }
      const id = newId();
      const created = emptyHousehold({ id, name, role: 'Owner', timeZone: world.me.timeZone ?? ZONE, memberCount: 1 });
      created.joinedAt = NOW();
      world.households.set(id, created);
      world.memberships.push(id);
      return json(201, summaryOf(created));
    }
    if (path === '/api/v1/invites/preview' && method === 'POST') {
      const found = openInvite(String(body.code ?? ''));
      if (!found) return notFound();
      const inviter = found.household.others.find((each) => each.userId === found.invite.createdBy);
      return json(200, {
        householdName: found.household.summary.name,
        invitedBy: found.invite.createdBy === ME_ID ? world.me.name || null : (inviter?.displayName ?? null),
        role: found.invite.role,
        expiresAt: found.invite.expiresAt,
        alreadyMember: world.memberships.includes(found.household.summary.id),
      });
    }
    if (path === '/api/v1/invites/accept' && method === 'POST') {
      const found = openInvite(String(body.code ?? ''));
      if (!found) return notFound();
      const joined = found.household;
      if (world.memberships.includes(joined.summary.id)) {
        return problem(409, { type: 'urn:collarbell:problem:already-a-member' });
      }
      if (world.memberships.length >= MAX_HOUSEHOLDS) {
        return problem(409, { type: 'urn:collarbell:problem:household-limit' });
      }
      joined.summary.role = found.invite.role;
      joined.joinedAt = NOW();
      joined.invites = joined.invites.filter((item) => item !== found.invite);
      world.memberships.push(joined.summary.id);
      return json(200, summaryOf(joined));
    }

    // --- The household of the request: its people, invites and settings (owners), its plan ---
    const ownersOnly = () => (role === 'Owner' ? null : helperRefused());
    if (path === '/api/v1/households/current' && method === 'GET') {
      return json(200, detailsOf(household));
    }
    if (path === '/api/v1/households/current' && method === 'PUT') {
      const refused = ownersOnly();
      if (refused) return refused;
      const name = typeof body.name === 'string' ? body.name.trim() : null;
      const zone = typeof body.timeZone === 'string' ? body.timeZone : null;
      if (body.name !== null && body.name !== undefined && !name)
        return invalid({ name: 'Give the household a name.' });
      if (name && name.length > 100) return invalid({ name: 'Use 100 characters or fewer.' });
      if (zone !== null && !knownZone(zone))
        return invalid({ timeZone: 'Use an IANA time zone such as Europe/Berlin.' });
      if (name) household.summary.name = name;
      if (zone) {
        household.summary.timeZone = zone;
        household.timeZoneSetByHand = true;
      }
      return json(200, detailsOf(household));
    }
    if (path === '/api/v1/households/current' && method === 'DELETE') {
      const refused = ownersOnly();
      if (refused) return refused;
      if (household.others.length > 0 || household.pets.length > 0 || household.supplies.length > 0) {
        return problem(409, { type: 'urn:collarbell:problem:household-not-empty' });
      }
      world.households.delete(householdId);
      world.memberships = world.memberships.filter((each) => each !== householdId);
      return noContent();
    }
    if (route(/^\/api\/v1\/households\/current\/members\/([^/]+)$/, 'PUT')) {
      const refused = ownersOnly();
      if (refused) return refused;
      const next = body.role as HouseholdRole;
      if (!['Owner', 'Member', 'Helper'].includes(next)) return invalid({ role: 'Use Owner, Member or Helper.' });
      const userId = param();
      const other = household.others.find((each) => each.userId === userId);
      if (userId !== ME_ID && !other) return notFound();
      const wasOwner = userId === ME_ID ? household.summary.role === 'Owner' : other!.role === 'Owner';
      if (wasOwner && next !== 'Owner' && ownersBesides(household, userId) === 0) {
        return problem(409, { type: 'urn:collarbell:problem:last-owner' });
      }
      if (userId === ME_ID) household.summary.role = next;
      else other!.role = next;
      // An owner no more: the codes they handed out stop working.
      if (next !== 'Owner') household.invites = household.invites.filter((item) => item.createdBy !== userId);
      return json(200, detailsOf(household));
    }
    if (route(/^\/api\/v1\/households\/current\/members\/([^/]+)$/, 'DELETE')) {
      const userId = param();
      const leaving = userId === ME_ID;
      if (!leaving && role !== 'Owner') return helperRefused();
      const other = household.others.find((each) => each.userId === userId);
      if (!leaving && !other) return notFound();
      const owner = leaving ? household.summary.role === 'Owner' : other!.role === 'Owner';
      if (owner && ownersBesides(household, userId) === 0) {
        return problem(409, { type: 'urn:collarbell:problem:last-owner' });
      }
      household.invites = household.invites.filter((item) => item.createdBy !== userId);
      if (leaving) world.memberships = world.memberships.filter((each) => each !== householdId);
      else household.others = household.others.filter((each) => each !== other);
      return noContent();
    }
    if (path === '/api/v1/households/current/invites' && method === 'POST') {
      const refused = ownersOnly();
      if (refused) return refused;
      const invited = body.role as HouseholdRole;
      if (invited !== 'Member' && invited !== 'Helper') {
        return invalid({ role: 'Invite as a member or a helper; make someone an owner once they have joined.' });
      }
      const now = Date.now();
      if (household.invites.filter((item) => Date.parse(item.expiresAt) > now).length >= MAX_OPEN_INVITES) {
        return problem(409, { type: 'urn:collarbell:problem:invite-limit' });
      }
      const created = invite(newId(), newInviteCode(), invited);
      household.invites.push(created);
      return json(
        201,
        detailsOf(household).invites.find((item) => item.id === created.id),
      );
    }
    if (route(/^\/api\/v1\/households\/current\/invites\/([^/]+)$/, 'DELETE')) {
      const refused = ownersOnly();
      if (refused) return refused;
      const found = household.invites.find((item) => item.id === param() && Date.parse(item.expiresAt) > Date.now());
      if (!found) return notFound();
      household.invites = household.invites.filter((item) => item !== found);
      return noContent();
    }
    if (path === '/api/v1/plan' && method === 'GET') {
      return json(200, household.plan);
    }
    if (path === '/api/v1/ai/status' && method === 'GET') {
      return json(200, world.ai);
    }
    if (path === '/api/v1/today' && method === 'GET') {
      return json(200, todayOf(household, logged.query.get('date') ?? world.today));
    }

    // --- Feeding marks ---
    if (route(/^\/api\/v1\/routines\/([^/]+)\/completions$/, 'POST')) {
      const key = markKey(param(), String(body.date), String(body.time));
      const existing = household.marks.get(key);
      if (existing) return existing.byMe ? json(200, existing) : json(409, existing);
      const mark: FeedingMark = {
        id: newId(),
        routineId: param(),
        date: String(body.date),
        time: String(body.time),
        status: body.status === 'Skipped' ? 'Skipped' : 'Done',
        doneAt: new Date().toISOString(),
        byName: world.me.name,
        byMe: true,
      };
      household.marks.set(key, mark);
      return json(201, mark);
    }
    if (route(/^\/api\/v1\/routines\/([^/]+)\/completions\/([^/]+)$/, 'DELETE')) {
      for (const [key, mark] of household.marks) if (mark.id === param(2)) household.marks.delete(key);
      return noContent();
    }

    // --- Care plans ---
    if (path === '/api/v1/care-plan-presets' && method === 'GET') {
      const species = logged.query.get('species');
      return json(
        200,
        world.presets.filter((item) => !species || item.species === null || item.species === species),
      );
    }
    if (route(/^\/api\/v1\/pets\/([^/]+)\/care-plans$/, 'GET')) {
      if (!petById(param())) return notFound();
      return json(
        200,
        household.plans
          .filter((item) => item.petId === param())
          .map(planOut)
          .sort((a, b) => Number(!a.active) - Number(!b.active) || a.nextDueOn.localeCompare(b.nextDueOn)),
      );
    }
    if (route(/^\/api\/v1\/pets\/([^/]+)\/care-plans$/, 'POST')) {
      const owner = petById(param());
      if (!owner) return notFound();
      if (helper) return helperRefused();
      const input = body as unknown as CarePlanRequest;
      const again = earlier(input.requestId);
      const before = again && household.plans.find((item) => item.id === again);
      if (before) return json(201, planOut(before));
      const refused = planProblems(input, owner, null);
      if (refused) return invalid(refused);
      const created: CarePlan = {
        ...plan(newId(), owner.id, world.today, { daysLeft: 0 }),
        ...planFields(input),
        active: input.active ?? true,
      };
      household.plans.push(created);
      remember(input.requestId, created.id);
      return json(201, planOut(created));
    }
    if (route(/^\/api\/v1\/care-plans\/([^/]+)$/, 'GET') || route(/^\/api\/v1\/care-plans\/([^/]+)$/, 'PUT')) {
      const found = household.plans.find((item) => item.id === param());
      if (!found) return notFound();
      if (method === 'GET') return json(200, planOut(found));
      if (helper) return helperRefused();
      const input = body as unknown as CarePlanRequest;
      const refused = planProblems(input, petById(found.petId)!, found.presetCode);
      if (refused) return invalid(refused);
      Object.assign(found, planFields(input), { active: input.active ?? found.active, updatedAt: NOW() });
      return json(200, planOut(found));
    }
    if (route(/^\/api\/v1\/care-plans\/([^/]+)$/, 'DELETE')) {
      const found = household.plans.find((item) => item.id === param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      household.plans = household.plans.filter((item) => item !== found);
      return noContent();
    }
    if (route(/^\/api\/v1\/care-plans\/([^/]+)\/complete$/, 'POST')) {
      const found = household.plans.find((item) => item.id === param());
      if (!found) return notFound();
      const performedOn = String(body.performedOn);
      const done = record(newId(), found.petId, {
        planId: found.id,
        kind: found.kind,
        title: found.title,
        performedOn,
        performedTime: (body.performedTime as string | null) ?? null,
        product: (body.product as string | null) ?? null,
        manufacturer: (body.manufacturer as string | null) ?? null,
        batchNumber: (body.batchNumber as string | null) ?? null,
        validFrom: (body.validFrom as string | null) ?? null,
        validUntil: (body.validUntil as string | null) ?? null,
        targets: found.targets,
        clinic: (body.clinic as string | null) ?? null,
        veterinarian: (body.veterinarian as string | null) ?? null,
        notes: (body.notes as string | null) ?? null,
      });
      household.records.push(done);
      const repeats = found.intervalValue !== null && found.intervalUnit !== null;
      const chosen = body.nextDueOn as string | null;
      if (chosen || repeats) {
        found.nextDueOn =
          chosen ??
          (body.validUntil as string | null) ??
          addInterval(performedOn, found.intervalValue!, found.intervalUnit!);
      } else {
        // A one-off plan finishes with "Done".
        found.active = false;
      }
      found.lastDoneOn = performedOn;
      return json(200, { plan: planOut(found), record: recordOut(done) });
    }

    // --- Care records ---
    if (route(/^\/api\/v1\/pets\/([^/]+)\/care-records$/, 'GET')) {
      if (!petById(param())) return notFound();
      const kind = logged.query.get('kind');
      return json(
        200,
        household.records
          .filter((item) => item.petId === param() && (!kind || item.kind === kind))
          .sort(
            (a, b) =>
              b.performedOn.localeCompare(a.performedOn) ||
              (b.performedTime ?? '').localeCompare(a.performedTime ?? '') ||
              b.createdAt.localeCompare(a.createdAt),
          )
          .map(recordOut),
      );
    }
    if (route(/^\/api\/v1\/pets\/([^/]+)\/care-records$/, 'POST')) {
      if (!petById(param())) return notFound();
      if (helper) return helperRefused();
      const input = body as unknown as CareRecordRequest;
      const again = earlier(input.requestId);
      const before = again && household.records.find((item) => item.id === again);
      if (before) return json(201, recordOut(before));
      const refused = recordProblems(input, world.today);
      if (refused) return invalid(refused);
      const created = record(newId(), param(), recordFields(input));
      household.records.push(created);
      remember(input.requestId, created.id);
      return json(201, recordOut(created));
    }
    if (route(/^\/api\/v1\/care-records\/([^/]+)$/, 'GET') || route(/^\/api\/v1\/care-records\/([^/]+)$/, 'PUT')) {
      const found = household.records.find((item) => item.id === param());
      if (!found) return notFound();
      if (method === 'GET') return json(200, recordOut(found));
      if (helper) return helperRefused();
      const input = body as unknown as CareRecordRequest;
      const refused = recordProblems(input, world.today);
      if (refused) return invalid(refused);
      Object.assign(found, recordFields(input), { updatedAt: NOW() });
      return json(200, recordOut(found));
    }
    if (route(/^\/api\/v1\/care-records\/([^/]+)$/, 'DELETE')) {
      const found = household.records.find((item) => item.id === param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      household.records = household.records.filter((item) => item !== found);
      release(found.files);
      return noContent();
    }
    if (route(/^\/api\/v1\/care-records\/([^/]+)\/files$/, 'POST')) {
      const found = household.records.find((item) => item.id === param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      const fileIds = ((body.fileIds as string[] | null) ?? []).filter((id) => !found.files.includes(id));
      const wrong = filesProblem(fileIds);
      if (wrong) return invalid({ fileIds: wrong });
      if (found.files.length + fileIds.length > MAX_RECORD_FILES) {
        return invalid({ fileIds: `A record has ${MAX_RECORD_FILES} files or fewer.` });
      }
      attach(fileIds);
      found.files.push(...fileIds);
      return json(200, recordOut(found));
    }
    if (route(/^\/api\/v1\/care-records\/([^/]+)\/files\/([^/]+)$/, 'DELETE')) {
      const found = household.records.find((item) => item.id === param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      found.files = found.files.filter((id) => id !== param(2));
      release([param(2)]);
      return noContent();
    }
    if (route(/^\/api\/v1\/pets\/([^/]+)\/passport\/records$/, 'GET')) {
      if (!petById(param())) return notFound();
      const own = household.records
        .filter((item) => item.petId === param())
        .sort(
          (a, b) =>
            a.performedOn.localeCompare(b.performedOn) || (a.performedTime ?? '').localeCompare(b.performedTime ?? ''),
        );
      const rabies = (item: StoredRecord) => item.kind === 'Vaccination' && item.targets.includes('Rabies');
      const section = (belongs: (item: StoredRecord) => boolean) => own.filter(belongs).map(recordOut);
      return json(200, {
        rabies: section(rabies),
        rabiesTiters: section((item) => item.kind === 'RabiesTiter'),
        echinococcus: section((item) => item.kind === 'Echinococcus'),
        treatments: section((item) => ['Deworming', 'FleaTick', 'Heartworm'].includes(item.kind)),
        otherVaccinations: section((item) => item.kind === 'Vaccination' && !rabies(item)),
        examinations: section((item) => item.kind === 'VetExam'),
      });
    }

    // --- The passport's details ---
    if (route(/^\/api\/v1\/pets\/([^/]+)\/passport$/, 'GET') || route(/^\/api\/v1\/pets\/([^/]+)\/passport$/, 'PUT')) {
      if (!petById(param())) return notFound();
      if (method === 'GET') return json(200, household.passports.get(param()) ?? emptyPassport(param()));
      if (helper) return helperRefused();
      const input = body as unknown as PassportRequest;
      const number = input.passportNumber?.replace(/\s/g, '').toUpperCase() ?? null;
      if (number && !/^[A-Z0-9/-]{1,30}$/.test(number)) return invalid({ passportNumber: 'Not a passport number.' });
      if (input.issuingCountry && !/^[A-Za-z]{2}$/.test(input.issuingCountry)) {
        return invalid({ issuingCountry: 'Use a two-letter country code.' });
      }
      const filled = (contact: PassportContact | null | undefined) =>
        contact && Object.values(contact).some(Boolean) ? contact : null;
      const saved: Passport = {
        petId: param(),
        model: input.model ?? null,
        passportNumber: number || null,
        issuingCountry: input.issuingCountry?.toUpperCase() ?? null,
        issuedOn: input.issuedOn ?? null,
        issuer: filled(input.issuer),
        owners: (input.owners ?? []).filter((owner) => filled(owner)),
        notes: input.notes ?? null,
        updatedAt: NOW(),
      };
      household.passports.set(param(), saved);
      return json(200, saved);
    }

    // --- Documents ---
    if (route(/^\/api\/v1\/pets\/([^/]+)\/documents$/, 'GET')) {
      if (!petById(param())) return notFound();
      const type = logged.query.get('type');
      const day = (item: StoredDocument) => item.documentDate ?? item.createdAt.slice(0, 10);
      return json(
        200,
        household.documents
          .filter((item) => item.petId === param() && (!type || item.type === type))
          .sort((a, b) => day(b).localeCompare(day(a)) || b.createdAt.localeCompare(a.createdAt))
          .map(documentOut),
      );
    }
    if (route(/^\/api\/v1\/pets\/([^/]+)\/documents$/, 'POST')) {
      if (!petById(param())) return notFound();
      if (helper) return helperRefused();
      const input = body as unknown as DocumentRequest;
      const fileIds = input.fileIds ?? [];
      if (!fileIds.length) return invalid({ fileIds: 'Add at least one page.' });
      if (fileIds.length > MAX_DOCUMENT_PAGES) return invalid({ fileIds: 'A document has 50 pages or fewer.' });
      const wrong = filesProblem(fileIds);
      if (wrong) return invalid({ fileIds: wrong });
      const refused = documentProblems(input, world.today);
      if (refused) return invalid(refused);
      attach(fileIds);
      const created = document(newId(), param(), { ...documentFields(input), pages: [...fileIds] });
      household.documents.push(created);
      return json(201, documentOut(created));
    }
    if (route(/^\/api\/v1\/documents\/([^/]+)$/, 'GET') || route(/^\/api\/v1\/documents\/([^/]+)$/, 'PUT')) {
      const found = household.documents.find((item) => item.id === param());
      if (!found) return notFound();
      if (method === 'GET') return json(200, documentOut(found));
      if (helper) return helperRefused();
      const input = body as unknown as DocumentRequest;
      const refused = documentProblems(input, world.today);
      if (refused) return invalid(refused);
      Object.assign(found, documentFields(input), { updatedAt: NOW() });
      return json(200, documentOut(found));
    }
    if (route(/^\/api\/v1\/documents\/([^/]+)$/, 'DELETE')) {
      const found = household.documents.find((item) => item.id === param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      household.documents = household.documents.filter((item) => item !== found);
      release(found.pages);
      return noContent();
    }
    if (route(/^\/api\/v1\/documents\/([^/]+)\/pages$/, 'POST')) {
      const found = household.documents.find((item) => item.id === param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      // Pages already there (a retry after a lost answer) are no error.
      const fileIds = ((body.fileIds as string[] | null) ?? []).filter((id) => !found.pages.includes(id));
      if (found.pages.length + fileIds.length > MAX_DOCUMENT_PAGES) {
        return invalid({ fileIds: 'A document has 50 pages or fewer.' });
      }
      const wrong = filesProblem(fileIds);
      if (wrong) return invalid({ fileIds: wrong });
      attach(fileIds);
      found.pages.push(...fileIds);
      return json(200, documentOut(found));
    }
    if (route(/^\/api\/v1\/documents\/([^/]+)\/pages\/([^/]+)$/, 'DELETE')) {
      const found = household.documents.find((item) => item.id === param());
      if (!found || !found.pages.includes(param(2))) return notFound();
      if (helper) return helperRefused();
      found.pages = found.pages.filter((id) => id !== param(2));
      release([param(2)]);
      // A document without pages has nothing left to show.
      if (!found.pages.length) household.documents = household.documents.filter((item) => item !== found);
      return noContent();
    }

    // --- Files ---
    if (path === '/api/v1/files' && method === 'POST') {
      const form = await request.formData();
      // A File, though not always of this window's kind (the fetch's own, in the tests).
      const file = form.get('file') as unknown as Blob | string | null;
      if (!file || typeof file === 'string') return invalid({ file: 'Add a file.' });
      if (file.size > MAX_UPLOAD) return problem(413, { detail: 'Upload files up to 15 MB.' });
      const pdf = file.type === 'application/pdf';
      if (!pdf && !PHOTO_TYPES.includes(file.type)) return problem(415, { detail: 'Use a photo or a PDF.' });
      const id = newId();
      const url = fileUrl(id, file);
      world.files.set(id, {
        id,
        // Photos become JPEG on the server; PDFs stay as they are.
        contentType: pdf ? 'application/pdf' : 'image/jpeg',
        sizeBytes: file.size,
        width: pdf ? null : 640,
        height: pdf ? null : 480,
        url,
        thumbnailUrl: pdf ? null : url.startsWith('http') ? `${url}/small` : url,
        attached: false,
      });
      return json(201, link(id));
    }
    if (route(/^\/api\/v1\/files\/([^/]+)\/url$/, 'GET')) {
      return world.files.has(param()) ? json(200, link(param())) : notFound();
    }

    // --- Pets ---
    if (path === '/api/v1/pets' && method === 'GET') {
      return json(
        200,
        [
          ...household.pets.filter((item) => item.status === 'Active'),
          ...household.pets.filter((item) => item.status !== 'Active'),
        ].map(petOut),
      );
    }
    if (path === '/api/v1/pets' && method === 'POST') {
      if (helper) return helperRefused();
      const created = pet(newId(), '', fromPetRequest(body as unknown as PetRequest));
      household.pets.push(created);
      return json(201, created);
    }
    if ((match = /^\/api\/v1\/pets\/([^/]+)$/.exec(path))) {
      const found = petById(param());
      if (!found) return notFound();
      if (method === 'GET') return json(200, petOut(found));
      if (helper) return helperRefused();
      if (method === 'PUT') {
        Object.assign(found, fromPetRequest(body as unknown as PetRequest, found), { updatedAt: NOW() });
        return json(200, petOut(found));
      }
      if (method === 'DELETE') {
        household.pets = household.pets.filter((item) => item !== found);
        return noContent();
      }
    }
    if ((match = /^\/api\/v1\/pets\/([^/]+)\/photo$/.exec(path))) {
      const found = petById(param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      if (method === 'PUT') {
        const fileId = String(body.fileId);
        if (world.files.has(fileId)) world.files.get(fileId)!.attached = true;
        found.photo = world.files.has(fileId) ? link(fileId) : null;
        return json(200, petOut(found));
      }
      found.photo = null;
      return noContent();
    }

    // --- Feeding schedules and supplies ---
    if (route(/^\/api\/v1\/pets\/([^/]+)\/routines$/, 'GET')) {
      if (!petById(param())) return notFound();
      const first = (item: Routine) => [...item.times].sort()[0] ?? '';
      return json(
        200,
        household.routines
          .filter((item) => item.petId === param())
          .sort(
            (a, b) =>
              Number(!a.active) - Number(!b.active) ||
              first(a).localeCompare(first(b)) ||
              a.createdAt.localeCompare(b.createdAt),
          ),
      );
    }
    if (route(/^\/api\/v1\/pets\/([^/]+)\/routines$/, 'POST')) {
      if (!petById(param())) return notFound();
      if (helper) return helperRefused();
      const input = body as unknown as RoutineRequest;
      const again = earlier(input.requestId);
      const before = again && household.routines.find((item) => item.id === again);
      if (before) return json(201, before);
      const refused = routineProblems(input);
      if (refused) return invalid(refused);
      const created = routine(newId(), param(), routineFields(input, household));
      household.routines.push(created);
      remember(input.requestId, created.id);
      return json(201, created);
    }
    if (route(/^\/api\/v1\/routines\/([^/]+)$/, 'GET') || route(/^\/api\/v1\/routines\/([^/]+)$/, 'PUT')) {
      const found = household.routines.find((item) => item.id === param());
      if (!found) return notFound();
      if (method === 'GET') return json(200, found);
      if (helper) return helperRefused();
      const input = body as unknown as RoutineRequest;
      const refused = routineProblems(input);
      if (refused) return invalid(refused);
      Object.assign(found, routineFields(input, household), {
        active: input.active ?? found.active,
        updatedAt: NOW(),
      });
      return json(200, found);
    }
    if (route(/^\/api\/v1\/routines\/([^/]+)$/, 'DELETE')) {
      const found = household.routines.find((item) => item.id === param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      household.routines = household.routines.filter((item) => item !== found);
      return noContent();
    }
    if (path === '/api/v1/supplies' && method === 'GET') {
      return json(200, suppliesOf(household));
    }
    if (path === '/api/v1/supplies' && method === 'POST') {
      if (helper) return helperRefused();
      const input = body as unknown as SupplyRequest;
      const again = earlier(input.requestId);
      const before = again && household.supplies.find((item) => item.id === again);
      if (before) return json(201, supplyOut(household, before));
      const refused = supplyProblems(input, household, null);
      if (refused) return invalid(refused);
      const created = supply(newId(), supplyFields(input, null));
      household.supplies.push(created);
      if (input.initialStock !== null && input.initialStock !== undefined) {
        household.stock.push(stockEntry(created.id, 'Adjustment', input.initialStock, 0, myEntry()));
      }
      remember(input.requestId, created.id);
      return json(201, supplyOut(household, created));
    }
    if (route(/^\/api\/v1\/supplies\/([^/]+)$/, 'GET') || route(/^\/api\/v1\/supplies\/([^/]+)$/, 'PUT')) {
      const found = household.supplies.find((item) => item.id === param());
      if (!found) return notFound();
      if (method === 'GET') return json(200, supplyOut(household, found));
      if (helper) return helperRefused();
      const input = body as unknown as SupplyRequest;
      const refused = supplyProblems(input, household, found.id);
      if (refused) return invalid(refused);
      Object.assign(found, supplyFields(input, found), { updatedAt: NOW() });
      // A renamed food is renamed in the feedings that give it.
      for (const each of household.routines) if (each.supplyItemId === found.id) each.food = found.name;
      return json(200, supplyOut(household, found));
    }
    if (route(/^\/api\/v1\/supplies\/([^/]+)$/, 'DELETE')) {
      const found = household.supplies.find((item) => item.id === param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      household.supplies = household.supplies.filter((item) => item !== found);
      household.stock = household.stock.filter((entry) => entry.supplyId !== found.id);
      // Feedings keep the food's name.
      for (const each of household.routines) if (each.supplyItemId === found.id) each.supplyItemId = null;
      return noContent();
    }
    if (route(/^\/api\/v1\/supplies\/([^/]+)\/stock-events$/, 'GET')) {
      if (!household.supplies.some((item) => item.id === param())) return notFound();
      return json(
        200,
        household.stock
          .filter((entry) => entry.supplyId === param())
          .sort((a, b) => b.at.localeCompare(a.at) || b.id.localeCompare(a.id))
          .slice(0, 50)
          .map(stockOut),
      );
    }
    if (route(/^\/api\/v1\/supplies\/([^/]+)\/stock-events$/, 'POST')) {
      const found = household.supplies.find((item) => item.id === param());
      if (!found) return notFound();
      const again = earlier(body.requestId);
      const before = again && household.stock.find((entry) => entry.id === again);
      // A retry of an entry that went through: counted once.
      if (before) return json(200, { event: stockOut(before), supply: supplyOut(household, found) });
      const kind = body.kind as StockEventKind;
      const quantity = Number(body.quantity);
      if (kind !== 'Purchase' && kind !== 'Adjustment') {
        return invalid({ kind: 'Say whether it is a purchase or a count of what is left.' });
      }
      const most = Math.max(found.packageSize, 1000) * 1000;
      if (!(quantity >= 0) || (kind === 'Purchase' && quantity <= 0) || quantity > most) {
        return invalid({ quantity: 'Use an amount above 0, up to a thousand packages.' });
      }
      const entry = stockEntry(found.id, kind, Math.round(quantity * 1000) / 1000, 0, myEntry());
      household.stock.push(entry);
      // Bought again: it is bought, with its estimate and reminders back.
      if (kind === 'Purchase' && !found.active) found.active = true;
      remember(body.requestId, entry.id);
      return json(201, { event: stockOut(entry), supply: supplyOut(household, found) });
    }
    if (route(/^\/api\/v1\/supplies\/([^/]+)\/stock-events\/([^/]+)$/, 'DELETE')) {
      const found = household.stock.find((entry) => entry.id === param(2) && entry.supplyId === param());
      // A helper takes back only their own.
      if (found && helper && !found.byMe) return helperRefused();
      if (!found) return notFound();
      household.stock = household.stock.filter((entry) => entry !== found);
      return noContent();
    }
    if (path === '/api/v1/products/lookup' && method === 'GET') {
      const code = gtin(logged.query.get('code') ?? '');
      if (!code) return invalid({ code: 'Not a product barcode (EAN, UPC or a GS1 DataMatrix).' });
      const existing = household.supplies.find((item) => item.barcode === code);
      if (existing) {
        return json(200, {
          code,
          batch: null,
          expiresOn: null,
          existing: { id: existing.id, name: existing.name, active: existing.active },
          product: null,
          source: null,
        });
      }
      const known = world.products.get(code);
      return json(200, {
        code,
        batch: null,
        expiresOn: null,
        existing: null,
        product: known?.product ?? null,
        source: known?.source ?? null,
      });
    }

    // --- Weights ---
    if (route(/^\/api\/v1\/pets\/([^/]+)\/weights$/, 'GET')) {
      if (!petById(param())) return notFound();
      return json(200, weightsOf(household, param()));
    }
    if (route(/^\/api\/v1\/pets\/([^/]+)\/weights$/, 'POST')) {
      const owner = petById(param());
      if (!owner) return notFound();
      if (helper) return helperRefused();
      const input = body as unknown as WeightRequest;
      const again = earlier(input.requestId);
      const before = again && household.weights.find((item) => item.id === again);
      if (before) return json(201, before);
      const refused = weightProblems(input, owner, world.today, null);
      if (refused) return invalid(refused);
      const created = weighing(newId(), owner.id, weightFields(input));
      household.weights.push(created);
      remember(input.requestId, created.id);
      return json(201, created);
    }
    if (route(/^\/api\/v1\/weights\/([^/]+)$/, 'GET') || route(/^\/api\/v1\/weights\/([^/]+)$/, 'PUT')) {
      const found = household.weights.find((item) => item.id === param());
      if (!found) return notFound();
      if (method === 'GET') return json(200, found);
      if (helper) return helperRefused();
      const input = body as unknown as WeightRequest;
      const refused = weightProblems(input, petById(found.petId)!, world.today, found.measuredOn);
      if (refused) return invalid(refused);
      Object.assign(found, weightFields(input), { updatedAt: NOW() });
      return json(200, found);
    }
    if (route(/^\/api\/v1\/weights\/([^/]+)$/, 'DELETE')) {
      const found = household.weights.find((item) => item.id === param());
      if (!found) return notFound();
      if (helper) return helperRefused();
      household.weights = household.weights.filter((item) => item !== found);
      return noContent();
    }

    /** What saving a draft would refuse, by the field names of the request ("records[0].record.performedOn"). */
    const applyProblems = (input: ApplyImportRequest, item: StoredImport): Record<string, string[]> | null => {
      const errors: Record<string, string[]> = {};
      const owner = petById(item.petId)!;
      (input.records ?? []).forEach(({ record: sent, planId }, index) => {
        const refused = recordProblems(sent, world.today);
        for (const [field, text] of Object.entries(refused ?? {})) errors[`records[${index}].record.${field}`] = [text];
        if (planId) {
          const linked = household.plans.find((each) => each.id === planId && each.petId === item.petId);
          const fits =
            linked &&
            linked.active &&
            linked.kind === sent.kind &&
            (sent.kind !== 'Vaccination' ||
              !linked.targets.length ||
              !(sent.targets ?? []).length ||
              linked.targets.some((target) => (sent.targets ?? []).includes(target)));
          if (!fits) errors[`records[${index}].planId`] = ['This plan is not one this record can be done in.'];
        }
      });
      const saved = owner.identifiers.map((each) => each.code);
      const adding = new Set<string>();
      (input.identifiers ?? []).forEach((sent, index) => {
        const problemOf = identifierProblem(sent.type, sent.code);
        if (problemOf) errors[`identifiers[${index}].code`] = ['Not a valid number for its type.'];
        else if (!saved.includes(normalizeCode(sent.code))) adding.add(normalizeCode(sent.code));
      });
      if (saved.length + adding.size > MAX_IDENTIFIERS) {
        errors.identifiers = [`A pet has ${MAX_IDENTIFIERS} microchips and tattoos or fewer.`];
      }
      const passport = input.passport;
      if (passport) {
        const number = passport.passportNumber?.replace(/\s/g, '').toUpperCase();
        if (number && !/^[A-Z0-9/-]{1,30}$/.test(number)) errors['passport.passportNumber'] = ['Not a passport number.'];
        if (passport.issuingCountry && !/^[A-Za-z]{2}$/.test(passport.issuingCountry)) {
          errors['passport.issuingCountry'] = ['Use a two-letter country code.'];
        }
        if (passport.issuedOn && passport.issuedOn > addDays(world.today, 1)) {
          errors['passport.issuedOn'] = ['Use a date that has come.'];
        }
      }
      (input.weights ?? []).forEach((sent, index) => {
        const refused = weightProblems(
          { measuredOn: sent.measuredOn, weightKg: sent.weightKg, bcs: null, bcsScale: null, note: null, requestId: null },
          owner,
          world.today,
          null,
        );
        for (const [field, text] of Object.entries(refused ?? {})) errors[`weights[${index}].${field}`] = [text];
      });
      return Object.keys(errors).length ? errors : null;
    };

    /** Saves what the person kept of a draft, as the server does: records (a plan's "Done"), weighings, microchips,
     * the passport's empty fields, and the photos as passport pages or a document. */
    const applyImport = (input: ApplyImportRequest, item: StoredImport): ApplyImportResponse => {
      const owner = petById(item.petId)!;
      const recordIds: string[] = [];
      const moved = new Set<string>();
      for (const { record: sent, planId } of input.records ?? []) {
        const made = record(newId(), item.petId, { ...recordFields(sent), planId, source: 'AiScan' });
        household.records.push(made);
        recordIds.push(made.id);
        const linked = planId ? household.plans.find((each) => each.id === planId) : undefined;
        // A plan moves on when the record is its newest news.
        if (linked && (!linked.lastDoneOn || sent.performedOn > linked.lastDoneOn)) {
          linked.lastDoneOn = sent.performedOn;
          if (linked.intervalValue !== null && linked.intervalUnit !== null) {
            linked.nextDueOn = sent.validUntil ?? addInterval(sent.performedOn, linked.intervalValue, linked.intervalUnit);
          } else {
            linked.active = false;
          }
          moved.add(linked.id);
        }
      }
      for (const sent of input.weights ?? []) {
        household.weights.push(
          weighing(newId(), item.petId, { measuredOn: sent.measuredOn, weightKg: Math.round(sent.weightKg * 1000) / 1000 }),
        );
      }
      let identifiersAdded = 0;
      for (const sent of input.identifiers ?? []) {
        const code = normalizeCode(sent.code);
        if (owner.identifiers.some((each) => each.code === code)) continue;
        owner.identifiers.push({
          id: newId(),
          type: sent.type,
          code,
          rawCode: sent.code,
          appliedOn: sent.appliedOn,
          readOn: null,
          location: sent.location,
        });
        identifiersAdded += 1;
      }
      let passportUpdated = false;
      const fields = input.passport;
      if (fields && (fields.passportNumber || fields.issuingCountry || fields.issuedOn)) {
        const passport = household.passports.get(item.petId) ?? emptyPassport(item.petId);
        household.passports.set(item.petId, {
          ...passport,
          passportNumber: fields.passportNumber?.replace(/\s/g, '').toUpperCase() ?? passport.passportNumber,
          issuingCountry: fields.issuingCountry?.toUpperCase() ?? passport.issuingCountry,
          issuedOn: fields.issuedOn ?? passport.issuedOn,
          updatedAt: NOW(),
        });
        passportUpdated = true;
      }
      let documentId: string | null = null;
      const photos = item.fileIds.filter((id) => world.files.has(id));
      if (input.keepPhotos && photos.length) {
        attach(photos);
        const pages = household.documents
          .filter((each) => each.petId === item.petId && each.type === 'PassportPage')
          .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
        const last = pages[0];
        if (item.source === 'PassportPages' && last && last.pages.length + photos.length <= MAX_DOCUMENT_PAGES) {
          last.pages.push(...photos);
          documentId = last.id;
        } else {
          const made = document(newId(), item.petId, {
            type: item.source === 'PassportPages' ? 'PassportPage' : 'Other',
            pages: [...photos],
          });
          household.documents.push(made);
          documentId = made.id;
        }
      }
      return {
        recordIds,
        plansMoved: moved.size,
        identifiersAdded,
        passportUpdated,
        documentId,
        weightsAdded: (input.weights ?? []).length,
      };
    };

    // --- AI: scans and notes, the microchip and package readers ---
    const aiRefused = () =>
      problem(409, { title: "AI isn't set up.", detail: 'Add an AI model on the server (Ai settings) to read photos.' });
    /** The month's AI photos: `count` more fit (and are counted), or the refusal. */
    const holdPhotos = (count: number): Response | null => {
      const { plan: kind, aiPhotosPerMonth, aiPhotosUsed, resetsAt } = household.plan;
      if (aiPhotosUsed + count > aiPhotosPerMonth) {
        return problem(409, {
          type: 'urn:collarbell:problem:ai-limit',
          title: 'Not enough AI photos left this month.',
          plan: kind,
          limit: aiPhotosPerMonth,
          used: aiPhotosUsed,
          requested: count,
          resetsAt,
          scope: 'household',
        });
      }
      household.plan.aiPhotosUsed += count;
      return null;
    };
    /** Uploads AI can read: known, not used anywhere, photos (a PDF is no photo to AI). */
    const photosProblem = (fileIds: readonly string[]): string | null =>
      filesProblem(fileIds) ??
      (fileIds.some((id) => world.files.get(id)!.contentType === 'application/pdf')
        ? 'Use a photo: JPEG, PNG or WebP.'
        : null);
    if (path === '/api/v1/ai-imports' && method === 'POST') {
      const input = body as unknown as CreateAiImportRequest;
      const owner = petById(String(input.petId));
      if (!owner) return notFound();
      if (helper) return helperRefused();
      if (!world.ai.configured) return aiRefused();
      const again = earlier(input.requestId);
      const before = again && household.imports.find((item) => item.id === again);
      if (before) {
        return before.petId === owner.id && before.source === input.source
          ? json(202, importOut(before))
          : invalid({ requestId: 'This request id was used for something else.' });
      }
      const fileIds = input.fileIds ?? [];
      const note = input.source === 'Text';
      const text = (input.text ?? '').trim() || null;
      if (!['PassportPages', 'VetDocument', 'Text'].includes(input.source)) {
        return invalid({ source: 'Unknown kind of scan.' });
      }
      if (note) {
        if (!text || !/[\p{L}\p{Nd}]/u.test(text.replace(/[\uD800-\uDFFF]/g, ''))) {
          return invalid({ text: 'Write what was done.' });
        }
        if (text.length > MAX_NOTE) return invalid({ text: `Use ${MAX_NOTE} characters or fewer.` });
        if (fileIds.length) return invalid({ fileIds: 'A note has no photos.' });
        if (world.notesRead >= world.notesPerDay) {
          return problem(429, {
            type: 'urn:collarbell:problem:text-limit',
            title: 'AI has read enough of your notes for today.',
            limit: world.notesPerDay,
          });
        }
        world.notesRead += 1;
      } else {
        if (fileIds.length === 0 || fileIds.length > MAX_SCAN_PHOTOS) {
          return invalid({ fileIds: `Add 1 to ${MAX_SCAN_PHOTOS} photos.` });
        }
        const wrong = photosProblem(fileIds);
        if (wrong) return invalid({ fileIds: wrong });
        const refused = holdPhotos(fileIds.length);
        if (refused) return refused;
      }
      const failed = input.retryOf
        ? household.imports.find((item) => item.id === input.retryOf && item.status === 'Failed')
        : undefined;
      const created: StoredImport = {
        id: newId(),
        petId: owner.id,
        source: input.source,
        status: 'Queued',
        fileIds: [...fileIds],
        text,
        error: null,
        model: null,
        // Read again unchanged, a note is still the one written that day: its "yesterday" counts from then. Changed
        // before it is read again, it is written now.
        createdAt: note && failed?.source === 'Text' && failed.text === text ? failed.createdAt : NOW(),
        completedAt: null,
        appliedAt: null,
        result: null,
        requestId: input.requestId ?? null,
        outcome: world.reader({
          source: input.source,
          text,
          pages: fileIds.length,
          pet: owner,
          plans: household.plans.filter((item) => item.petId === owner.id).map(planOut),
          today: world.today,
        }),
        polls: 0,
      };
      // "Try again" after a failure is a new reading: the failed one gives way to it, whoever started it.
      for (const item of household.imports) {
        if (item.status !== 'Failed') continue;
        const same = note
          ? item.source === 'Text' && item.petId === owner.id && (item.id === input.retryOf || item.text === text)
          : item.id === input.retryOf || item.fileIds.some((id) => fileIds.includes(id));
        if (same) {
          item.status = 'Discarded';
          item.text = null;
        }
      }
      household.imports.push(created);
      remember(input.requestId, created.id);
      return json(202, importOut(created));
    }
    if (route(/^\/api\/v1\/ai-imports\/([^/]+)$/, 'GET')) {
      const found = household.imports.find((item) => item.id === param());
      if (!found) return notFound();
      advance(found, true);
      return json(200, importOut(found));
    }
    if (route(/^\/api\/v1\/ai-imports\/([^/]+)$/, 'DELETE')) {
      const found = household.imports.find((item) => item.id === param());
      if (!found) return notFound();
      if (found.status === 'Applied') return problem(409, { title: 'This scan is saved already.' });
      found.status = 'Discarded';
      found.text = null;
      return noContent();
    }
    if (route(/^\/api\/v1\/pets\/([^/]+)\/ai-imports$/, 'GET')) {
      if (!petById(param())) return notFound();
      const notes = logged.query.get('notes');
      const items = household.imports.filter(
        (item) => item.petId === param() && (notes === null || (item.source === 'Text') === (notes === 'true')),
      );
      items.forEach((item) => advance(item, false));
      return json(
        200,
        items
          .filter((item) => ['Queued', 'Processing', 'Ready', 'Failed'].includes(item.status))
          .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
          .slice(0, 20)
          .map(importOut),
      );
    }
    if (route(/^\/api\/v1\/ai-imports\/([^/]+)\/apply$/, 'POST')) {
      const found = household.imports.find((item) => item.id === param());
      if (!found) return notFound();
      // Saved before (a retry after a lost answer): the first answer again, nothing saved twice.
      if (found.status === 'Applied' && found.result) return json(200, found.result);
      if (found.status !== 'Ready') return problem(409, { title: "The draft isn't ready." });
      const refused = applyProblems(body as unknown as ApplyImportRequest, found);
      if (refused) return problem(400, { title: 'One or more validation errors occurred.', errors: refused });
      found.result = applyImport(body as unknown as ApplyImportRequest, found);
      found.status = 'Applied';
      found.appliedAt = NOW();
      return json(200, found.result);
    }
    if (path === '/api/v1/pets/identifiers/scan' && method === 'POST') {
      if (!world.ai.configured) return aiRefused();
      const fileIds = (body.fileIds as string[] | null) ?? [];
      if (fileIds.length === 0 || fileIds.length > MAX_READER_PHOTOS) {
        return invalid({ fileIds: `Add 1 to ${MAX_READER_PHOTOS} photos.` });
      }
      const wrong = photosProblem(fileIds);
      if (wrong) return invalid({ fileIds: wrong });
      const held = holdPhotos(fileIds.length);
      if (held) return held;
      return json(200, { identifiers: world.chipReadings, model: 'gemini-3.8-flash' });
    }
    if (path === '/api/v1/products/scan' && method === 'POST') {
      if (!world.ai.configured) return aiRefused();
      const fileIds = (body.fileIds as string[] | null) ?? [];
      if (fileIds.length === 0 || fileIds.length > MAX_READER_PHOTOS) {
        return invalid({ fileIds: `Add 1 to ${MAX_READER_PHOTOS} photos.` });
      }
      const wrong = photosProblem(fileIds);
      if (wrong) return invalid({ fileIds: wrong });
      if (typeof body.barcode === 'string' && body.barcode.trim() && !gtin(body.barcode)) {
        return invalid({ barcode: 'Not a product barcode.' });
      }
      const held = holdPhotos(fileIds.length);
      if (held) return held;
      return json(200, { product: world.productDraft, model: 'gemini-3.8-flash' });
    }

    // --- Visits ---
    if (path === '/api/v1/appointments' && method === 'GET') {
      return json(200, household.visits);
    }
    if (path === '/api/v1/appointments' && method === 'POST') {
      if (helper) return helperRefused();
      const input = body as unknown as VisitRequest;
      const again = earlier(input.requestId);
      const before = again && household.visits.find((item) => item.id === again);
      if (before) return json(201, before);
      const created = visit(newId(), fromVisitRequest(input));
      household.visits.push(created);
      remember(input.requestId, created.id);
      return json(201, created);
    }
    if ((match = /^\/api\/v1\/appointments\/([^/]+)$/.exec(path))) {
      const found = household.visits.find((item) => item.id === param());
      if (!found) return notFound();
      if (method === 'GET') return json(200, found);
      if (helper) return helperRefused();
      if (method === 'PUT') {
        const input = body as unknown as VisitRequest;
        Object.assign(found, fromVisitRequest(input), { status: input.status ?? found.status });
        return json(200, found);
      }
      if (method === 'DELETE') {
        household.visits = household.visits.filter((item) => item !== found);
        return noContent();
      }
    }
    if (route(/^\/api\/v1\/appointments\/([^/]+)\/complete$/, 'POST')) {
      const found = household.visits.find((item) => item.id === param());
      if (!found) return notFound();
      found.status = 'Done';
      const planIds = (body.planIds as string[] | null) ?? [];
      const kind = body.recordKind as CareKind | null;
      found.recordIds = [];
      if (kind) {
        for (const petId of found.petIds) {
          const made = record(newId(), petId, {
            kind,
            title: found.title,
            performedOn: found.date,
            notes: (body.notes as string | null) ?? null,
          });
          household.records.push(made);
          found.recordIds.push(made.id);
        }
      }
      for (const id of planIds) {
        const moved = household.plans.find((item) => item.id === id);
        if (moved?.intervalValue && moved.intervalUnit) {
          moved.lastDoneOn = found.date;
          moved.nextDueOn = addInterval(found.date, moved.intervalValue, moved.intervalUnit);
        }
      }
      return json(200, { appointment: found, movedPlanIds: planIds });
    }
    return notFound();
  }

  async function testFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
    const request = input instanceof Request ? input : new Request(input, init);
    const url = new URL(request.url);
    let body: unknown;
    if ((request.headers.get('Content-Type') ?? '').includes('json')) body = await request.clone().json();
    const logged: Logged = {
      method: request.method,
      path: url.pathname,
      query: url.searchParams,
      household: request.headers.get('X-Household'),
      authorization: request.headers.get('Authorization'),
      body,
    };
    requests.push(logged);
    const special = answers.find((item) => item.method === logged.method && matches(logged.path, item.path));
    if (special) {
      if (special.once) answers.splice(answers.indexOf(special), 1);
      const answer = await special.answer(logged);
      if (answer) return answer;
    }
    return serve(logged, request);
  }

  return {
    fetch: testFetch,
    world,
    requests,
    calls: (method, path) => requests.filter((item) => item.method === method && matches(item.path, path)),
    respond(method, path, answer, { once = false } = {}) {
      answers.unshift({ method, path, answer, once });
    },
  };
}

// --- The server's checks, the few the app's screens meet ------------------------------------------------------------

function emptyPassport(petId: string): Passport {
  return {
    petId,
    model: null,
    passportNumber: null,
    issuingCountry: null,
    issuedOn: null,
    issuer: null,
    owners: [],
    notes: null,
    updatedAt: null,
  };
}

function planFields(input: CarePlanRequest): Partial<CarePlan> {
  return {
    kind: input.kind,
    title: input.title.trim(),
    intervalValue: input.intervalValue,
    intervalUnit: input.intervalUnit,
    nextDueOn: input.nextDueOn,
    remindOffsetsDays: input.remindOffsetsDays ?? [7, 1, 0],
    defaultProduct: input.defaultProduct,
    targets: input.targets ?? [],
    presetCode: input.presetCode,
    notes: input.notes,
  };
}

function planProblems(input: CarePlanRequest, owner: Pet, currentPreset: string | null): Record<string, string> | null {
  if (!input.title?.trim()) return { title: 'Enter what needs to be done.' };
  if ((input.intervalValue === null) !== (input.intervalUnit === null)) {
    return { intervalValue: 'Give both the number and the unit.' };
  }
  if (input.presetCode && input.presetCode !== currentPreset) {
    const preset = PRESETS.find((item) => item.code === input.presetCode);
    if (!preset) return { presetCode: 'Unknown preset.' };
    if (preset.dogOnly && owner.species !== 'Dog') {
      return { presetCode: 'This product is for dogs only: it contains permethrin, which is toxic to cats.' };
    }
    if (preset.species && preset.species !== owner.species)
      return { presetCode: 'This preset is for another species.' };
  }
  return null;
}

function recordFields(input: CareRecordRequest): Partial<StoredRecord> {
  return {
    kind: input.kind,
    title: input.title.trim(),
    performedOn: input.performedOn,
    performedTime: input.performedTime,
    product: input.product,
    manufacturer: input.manufacturer,
    batchNumber: input.batchNumber,
    validFrom: input.validFrom,
    validUntil: input.validUntil,
    targets: input.targets ?? [],
    clinic: input.clinic,
    veterinarian: input.veterinarian,
    // A weight only at a check-up.
    weightKg: input.kind === 'VetExam' ? input.weightKg : null,
    details: input.details,
    notes: input.notes,
  };
}

function recordProblems(input: CareRecordRequest, today: string): Record<string, string> | null {
  if (!input.title?.trim()) return { title: 'Enter what was done.' };
  if (!input.performedOn || input.performedOn < '1990-01-01') return { performedOn: 'Use a date after 1990.' };
  if (input.performedOn > addDays(today, 1)) return { performedOn: 'Use a date that has come.' };
  if (input.targets?.length && input.kind !== 'Vaccination') return { targets: 'Only vaccinations have targets.' };
  if (input.validUntil && input.validUntil <= input.performedOn)
    return { validUntil: 'Protection ends after it starts.' };
  return null;
}

function documentFields(input: DocumentRequest): Partial<StoredDocument> {
  return {
    type: input.type,
    title: input.title?.trim() || null,
    documentDate: input.documentDate,
    notes: input.notes?.trim() || null,
  };
}

function documentProblems(input: DocumentRequest, today: string): Record<string, string> | null {
  if ((input.title ?? '').trim().length > 200) return { title: 'Use 200 characters or fewer.' };
  if (input.documentDate && input.documentDate > addDays(today, 1))
    return { documentDate: 'Use a date that has come.' };
  return null;
}

function routineFields(input: RoutineRequest, household: Household): Partial<Routine> {
  const linked = input.supplyItemId ? household.supplies.find((item) => item.id === input.supplyItemId) : undefined;
  return {
    times: [...new Set(input.times)].sort(),
    days: input.days?.length ? WEEK.filter((day) => input.days!.includes(day)) : [...WEEK],
    food: linked?.name ?? (input.food?.trim() || null),
    amount: input.amount,
    unit: input.amount === null ? null : input.unit,
    notes: input.notes?.trim() || null,
    supplyItemId: linked?.id ?? null,
  };
}

function routineProblems(input: RoutineRequest): Record<string, string> | null {
  const times = input.times ?? [];
  if (times.length === 0 || times.length > 8 || new Set(times).size !== times.length) {
    return { times: 'Use 1 to 8 different times of day.' };
  }
  if (input.amount !== null && (input.amount <= 0 || input.amount > 10_000)) {
    return { amount: 'Use an amount above 0 and up to 10 000, with at most 2 decimals.' };
  }
  return null;
}

function weightFields(input: WeightRequest): Partial<Weight> {
  return {
    measuredOn: input.measuredOn,
    weightKg: Math.round(input.weightKg * 1000) / 1000,
    bcs: input.bcs,
    bcsScale: input.bcs === null ? null : input.bcsScale,
    note: input.note?.trim() || null,
  };
}

function weightProblems(
  input: WeightRequest,
  owner: Pet,
  today: string,
  before: string | null,
): Record<string, string> | null {
  if (input.measuredOn < '1990-01-01') return { measuredOn: 'Use a date after 1990.' };
  const birth = owner.birthDateApproximate ? null : owner.birthDate;
  if (birth && input.measuredOn < birth && input.measuredOn !== before) {
    return { measuredOn: "A weighing can't be before the pet was born." };
  }
  if (input.measuredOn > addDays(today, 1)) return { measuredOn: 'Use a date that has come.' };
  if (!(input.weightKg > 0) || input.weightKg > 200) return { weightKg: 'Use a weight above 0 and up to 200 kg.' };
  if ((input.bcs === null) !== (input.bcsScale === null)) return { bcs: 'Give the score together with its scale.' };
  if (input.bcs !== null && input.bcsScale !== null && (input.bcs < 1 || input.bcs > input.bcsScale)) {
    return { bcs: `Use a score from 1 to ${input.bcsScale}.` };
  }
  if ((input.note ?? '').trim().length > 500) return { note: 'Use 500 characters or fewer.' };
  return null;
}

function fromPetRequest(request: PetRequest, old?: Pet): Partial<Pet> {
  return {
    name: request.name,
    species: request.species,
    sex: request.sex,
    breed: request.breed,
    birthDate: request.birthDate,
    birthDateApproximate: request.birthDateApproximate,
    neutered: request.neutered,
    neuteredOn: request.neuteredOn,
    color: request.color,
    markings: request.markings,
    coat: request.coat ?? old?.coat ?? 'Fawn',
    allergies: request.allergies,
    notes: request.notes,
    identifiers: (request.identifiers ?? []).map((identifier) => ({
      id: newId(),
      type: identifier.type,
      code: identifier.code.replace(/[\s\-.*]/g, '').toUpperCase(),
      rawCode: identifier.code,
      appliedOn: identifier.appliedOn,
      readOn: identifier.readOn,
      location: identifier.location,
    })),
  };
}

function fromVisitRequest(request: VisitRequest): Partial<Visit> {
  return {
    type: request.type,
    title: request.title,
    date: request.date,
    time: request.time,
    durationMinutes: request.durationMinutes,
    location: request.location,
    notes: request.notes,
    petIds: request.petIds,
    remindOffsetsMinutes: request.remindOffsetsMinutes ?? [1440, 120],
  };
}

// --- Supplies: the estimate and the checks (the server's SupplyForecasts and SuppliesEndpoints) ----------------------

/**
 * The estimate at `now` (spec 5.3): from the last count (or the first purchase when nothing was ever counted) the
 * daily use is taken away and later purchases are added, never below empty. The moment it runs out doesn't move as
 * time passes; to buy is the delivery time before that, "soon" when that day comes within a week.
 */
export function forecastOf(
  events: readonly StoredStockEvent[],
  usagePerDay: number | null,
  leadTimeDays: number,
  now: Date,
  timeZone: string,
): SupplyForecast {
  const round = (value: number, decimals: number) => Math.round(value * 10 ** decimals) / 10 ** decimals;
  const ordered = [...events].sort((a, b) => a.at.localeCompare(b.at) || a.id.localeCompare(b.id));
  const usage = usagePerDay !== null && usagePerDay > 0 ? usagePerDay : null;
  let start = ordered.findLastIndex((entry) => entry.kind === 'Adjustment');
  if (start < 0) start = ordered.findIndex((entry) => entry.kind === 'Purchase');
  if (start < 0) {
    return {
      remaining: null,
      usagePerDay: usage === null ? null : round(usage, 3),
      daysLeft: null,
      runsOutOn: null,
      buyBy: null,
      status: 'NoStock',
      countedFrom: null,
    };
  }
  const used = (from: string, to: number) =>
    usage === null ? 0 : Math.max(0, (usage * (to - Date.parse(from))) / DAY_MS);
  const anchor = ordered[start]!;
  let level = anchor.quantity;
  let since = anchor.at;
  for (const purchase of ordered.slice(start + 1)) {
    level = Math.max(0, level - used(since, Date.parse(purchase.at))) + purchase.quantity;
    since = purchase.at;
  }
  const remaining = Math.max(0, level - used(since, now.getTime()));
  const base = { remaining: round(remaining, 3), countedFrom: anchor.at };
  if (usage === null) {
    return { ...base, usagePerDay: null, daysLeft: null, runsOutOn: null, buyBy: null, status: 'NoUsage' };
  }
  const daysLeft = remaining / usage;
  if (level / usage > 3650) {
    return {
      ...base,
      usagePerDay: round(usage, 3),
      daysLeft: Math.min(round(daysLeft, 1), 3650),
      runsOutOn: null,
      buyBy: null,
      status: 'Enough',
    };
  }
  const runsOutOn = todayIn(timeZone, new Date(Date.parse(since) + (level / usage) * DAY_MS));
  const buyBy = addDays(runsOutOn, -leadTimeDays);
  const today = todayIn(timeZone, now);
  const status: SupplyStatus =
    remaining <= 0 ? 'OutOfStock' : buyBy <= today ? 'BuyNow' : buyBy <= addDays(today, 7) ? 'Soon' : 'Enough';
  return { ...base, usagePerDay: round(usage, 3), daysLeft: round(daysLeft, 1), runsOutOn, buyBy, status };
}

/** A product's barcode as the server keeps it: a UPC-A or a GTIN-14 with a 0 ahead becomes the EAN-13; null if wrong. */
function gtin(text: string): string | null {
  const digits = text.trim();
  if (!isValidGtin(digits)) return null;
  if (digits.length === 12) return `0${digits}`;
  if (digits.length === 14 && digits.startsWith('0')) return digits.slice(1);
  return digits;
}

function supplyProblems(input: SupplyRequest, household: Household, own: string | null): Record<string, string> | null {
  const name = input.name?.trim() ?? '';
  if (!name) return { name: 'Give the item a name.' };
  if (name.length > 100) return { name: 'Use 100 characters or fewer.' };
  if ((input.brand ?? '').trim().length > 100) return { brand: 'Use 100 characters or fewer.' };
  const barcode = input.barcode?.trim() ? gtin(input.barcode) : null;
  if (input.barcode?.trim() && !barcode) return { barcode: 'Use the digits of an EAN, UPC or GTIN barcode.' };
  if (barcode && household.supplies.some((item) => item.barcode === barcode && item.id !== own)) {
    return { barcode: 'Another item in supplies has this barcode.' };
  }
  if (!(input.packageSize > 0) || input.packageSize > 1_000_000) return { packageSize: 'Use a package size above 0.' };
  if (input.kcalPerKg !== null && (input.kcalPerKg <= 0 || input.kcalPerKg > 10_000)) {
    return { kcalPerKg: 'Use 1 to 10 000 kcal per kg.' };
  }
  if (input.manualDailyUsage !== null && !(input.manualDailyUsage > 0)) {
    return { manualDailyUsage: 'Use a daily amount above 0.' };
  }
  if (input.leadTimeDays !== null && (input.leadTimeDays < 0 || input.leadTimeDays > 60)) {
    return { leadTimeDays: 'Use 0 to 60 days.' };
  }
  const url = input.storeUrl?.trim();
  if (url && !/^https?:\/\/[^/\s]+/.test(url)) return { storeUrl: 'Use a web address starting with https://.' };
  if ((input.notes ?? '').trim().length > 500) return { notes: 'Use 500 characters or fewer.' };
  return null;
}

function supplyFields(input: SupplyRequest, old: Supply | null): Partial<Supply> {
  const clean = (value: string | null | undefined) => value?.trim() || null;
  return {
    name: input.name.trim(),
    brand: clean(input.brand),
    barcode: input.barcode?.trim() ? gtin(input.barcode) : null,
    category: input.category,
    unit: input.unit,
    packageSize: Math.round(input.packageSize * 1000) / 1000,
    kcalPerKg: input.kcalPerKg,
    usageMode: input.usageMode ?? (input.category === 'DryFood' || input.category === 'WetFood' ? 'Feeding' : 'Manual'),
    manualDailyUsage: input.manualDailyUsage === null ? null : Math.round(input.manualDailyUsage * 1e6) / 1e6,
    leadTimeDays: input.leadTimeDays ?? old?.leadTimeDays ?? 5,
    storeUrl: clean(input.storeUrl),
    notes: clean(input.notes),
    active: input.active ?? old?.active ?? true,
  };
}

// --- Households -----------------------------------------------------------------------------------------------------

/** How many owners a household has besides `userId`. */
function ownersBesides(household: Household, userId: string): number {
  const me = userId !== ME_ID && household.summary.role === 'Owner' ? 1 : 0;
  return me + household.others.filter((each) => each.userId !== userId && each.role === 'Owner').length;
}

/** An IANA time zone this runtime knows ("Europe/Berlin", or UTC). */
function knownZone(zone: string): boolean {
  if (zone !== 'UTC' && !zone.includes('/')) return false;
  try {
    new Intl.DateTimeFormat('en', { timeZone: zone });
    return true;
  } catch {
    return false;
  }
}

/** A short opaque fingerprint of a text (the deletion plan's): the same text, the same fingerprint. */
function fingerprint(text: string): string {
  let hash = 5381;
  for (let index = 0; index < text.length; index += 1) hash = ((hash * 33) ^ text.charCodeAt(index)) >>> 0;
  return `plan-${hash.toString(16)}-${text.length}`;
}

// --- "Download my data" ---------------------------------------------------------------------------------------------

/** A ZIP with one text file, stored as it is: what the pretend export holds. */
function zipOf(name: string, text: string): Uint8Array<ArrayBuffer> {
  const encoder = new TextEncoder();
  const content = encoder.encode(text);
  const fileName = encoder.encode(name);
  const crc = crc32(content);
  const local = new Uint8Array(30 + fileName.length + content.length);
  const head = new DataView(local.buffer);
  head.setUint32(0, 0x04034b50, true);
  head.setUint16(4, 20, true);
  // 1 January 1980, the earliest a ZIP knows.
  head.setUint16(12, 0x21, true);
  head.setUint32(14, crc, true);
  head.setUint32(18, content.length, true);
  head.setUint32(22, content.length, true);
  head.setUint16(26, fileName.length, true);
  local.set(fileName, 30);
  local.set(content, 30 + fileName.length);
  const central = new Uint8Array(46 + fileName.length);
  const entry = new DataView(central.buffer);
  entry.setUint32(0, 0x02014b50, true);
  entry.setUint16(4, 20, true);
  entry.setUint16(6, 20, true);
  entry.setUint16(14, 0x21, true);
  entry.setUint32(16, crc, true);
  entry.setUint32(20, content.length, true);
  entry.setUint32(24, content.length, true);
  entry.setUint16(28, fileName.length, true);
  central.set(fileName, 46);
  const end = new Uint8Array(22);
  const tail = new DataView(end.buffer);
  tail.setUint32(0, 0x06054b50, true);
  tail.setUint16(8, 1, true);
  tail.setUint16(10, 1, true);
  tail.setUint32(12, central.length, true);
  tail.setUint32(16, local.length, true);
  const zip = new Uint8Array(local.length + central.length + end.length);
  zip.set(local, 0);
  zip.set(central, local.length);
  zip.set(end, local.length + central.length);
  return zip;
}

function crc32(bytes: Uint8Array): number {
  let crc = ~0;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return ~crc >>> 0;
}
