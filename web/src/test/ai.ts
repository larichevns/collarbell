// What the pretend server's AI reads (src/test/server.ts): a scan's or a note's draft, made up by a reader the tests
// (and the demo) can replace, and builders for the entries of a draft. The default reader reads a rabies vaccination
// off any photos (a "Done" of the pet's rabies plan, when it has one), and from a note what it plainly says: a weight
// in kilograms, a rabies shot, yesterday or today.
import type {
  AiImportError,
  AiImportSource,
  CarePlan,
  DraftIdentifier,
  DraftPassport,
  DraftRecord,
  DraftWeight,
  IdentifierReading,
  ImportDraft,
  Pet,
  ProductDraft,
} from '../api/types';
import { addDays } from '../lib/dates';

/** What a reader gets: the scan or note, the pet and its plans, the household's today. */
export interface ReaderInput {
  source: AiImportSource;
  text: string | null;
  /** How many photos. */
  pages: number;
  pet: Pet;
  plans: readonly CarePlan[];
  today: string;
}

/** What AI made of a scan or note: its draft, or why it failed. */
export type ReaderOutcome = { draft: ImportDraft } | { error: AiImportError };

export type Reader = (input: ReaderInput) => ReaderOutcome;

let keys = 0;
const nextKey = () => (keys += 1);

export function draftRecord(change: Partial<DraftRecord> = {}): DraftRecord {
  return {
    key: nextKey(),
    kind: 'Vaccination',
    title: null,
    performedOn: null,
    performedTime: null,
    product: null,
    manufacturer: null,
    batchNumber: null,
    validFrom: null,
    validUntil: null,
    targets: [],
    veterinarian: null,
    clinic: null,
    weightKg: null,
    evidence: null,
    page: 1,
    warnings: [],
    duplicateOf: null,
    planId: null,
    selected: true,
    ...change,
  };
}

export function draftIdentifier(change: Partial<DraftIdentifier> = {}): DraftIdentifier {
  return {
    key: nextKey(),
    type: 'IsoChip',
    code: null,
    appliedOn: null,
    location: null,
    evidence: null,
    page: 1,
    warnings: [],
    selected: true,
    ...change,
  };
}

export function draftPassport(change: Partial<DraftPassport> = {}): DraftPassport {
  return {
    passportNumber: null,
    issuingCountry: null,
    issuedOn: null,
    evidence: null,
    page: 1,
    warnings: [],
    selected: true,
    ...change,
  };
}

export function draftWeight(change: Partial<DraftWeight> = {}): DraftWeight {
  return {
    key: nextKey(),
    measuredOn: null,
    weightKg: null,
    evidence: null,
    page: 1,
    warnings: [],
    duplicateOf: null,
    selected: true,
    ...change,
  };
}

export function draft(change: Partial<ImportDraft> = {}): ImportDraft {
  return { records: [], identifiers: [], passport: null, weights: [], ...change };
}

/** The pet's active rabies plan, which a rabies vaccination read is the "Done" of. */
function rabiesPlan(plans: readonly CarePlan[]): CarePlan | undefined {
  return plans.find((plan) => plan.active && plan.kind === 'Vaccination' && plan.targets.includes('Rabies'));
}

/** Photos: a rabies vaccination. A note: a weight in kilograms and a rabies shot, on the day it says. */
export const defaultReader: Reader = ({ source, text, plans, today }) => {
  if (source !== 'Text') {
    const on = addDays(today, -10);
    return {
      draft: draft({
        records: [
          draftRecord({
            kind: 'Vaccination',
            performedOn: on,
            product: 'Nobivac Rabies',
            batchNumber: 'B777',
            validFrom: addDays(on, 21),
            validUntil: addDays(on, 365),
            targets: ['Rabies'],
            evidence: 'Nobivac Rabies · B777',
            planId: rabiesPlan(plans)?.id ?? null,
          }),
        ],
      }),
    };
  }
  const words = text ?? '';
  const on = /yesterday|вчера/i.test(words) ? addDays(today, -1) : today;
  const weight = /(\d+(?:[.,]\d+)?)\s*(?:kg|кг)/i.exec(words);
  const rabies = /rabies|бешенств/i.exec(words);
  return {
    draft: draft({
      records: rabies
        ? [
            draftRecord({
              kind: 'Vaccination',
              performedOn: on,
              targets: ['Rabies'],
              evidence: rabies[0],
              planId: rabiesPlan(plans)?.id ?? null,
            }),
          ]
        : [],
      weights: weight
        ? [draftWeight({ measuredOn: on, weightKg: Number(weight[1]!.replace(',', '.')), evidence: weight[0] })]
        : [],
    }),
  };
};

/** The numbers AI reads on a chip sticker by default: one ISO chip. */
export function chipReading(change: Partial<IdentifierReading> = {}): IdentifierReading {
  return {
    type: 'IsoChip',
    code: '276098100123456',
    rawCode: '276 098 100 123 456',
    appliedOn: null,
    location: null,
    problem: null,
    ...change,
  };
}

/** What AI reads on a package by default: a cat's dry food, 1.5 kg. */
export function productDraft(change: Partial<ProductDraft> = {}): ProductDraft {
  return {
    isPetProduct: true,
    name: 'Brit Care Cat Sterilised',
    brand: 'Brit',
    category: 'DryFood',
    unit: 'Gram',
    packageSize: 1500,
    kcalPerKg: 3650,
    barcode: null,
    species: 'Cat',
    treatment: null,
    protectionWeeks: null,
    dosesInPackage: null,
    evidence: 'Brit Care Cat Sterilised 1.5 kg',
    ...change,
  };
}
