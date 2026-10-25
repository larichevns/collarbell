// The rules of care the app needs before the server answers (the phone app's care_rules.dart): which fields belong to
// which kind of care, the vaccine targets of each species, the plan's next date after "Done" worked out the way the
// server does it, and the server's limits, so mistakes show before saving.
import type { CareKind, CarePlan, CareStatus, IntervalUnit, Species, VaccineTarget } from '../api/types';
import type { Messages } from '../i18n/en';
import { addInterval } from './dates';

/** The earliest date the server takes for a record. */
export const EARLIEST_CARE_DATE = '1990-01-01';

/** Every kind of care, in the order the app lists them. */
export const CARE_KINDS: readonly CareKind[] = [
  'Vaccination',
  'RabiesTiter',
  'Deworming',
  'Echinococcus',
  'FleaTick',
  'Heartworm',
  'VetExam',
  'Dental',
  'Grooming',
  'Procedure',
  'Other',
];

/** Every vaccine target, rabies first, then the cats' and the dogs' (the server's order). */
export const VACCINE_TARGETS: readonly VaccineTarget[] = [
  'Rabies',
  'Fpv',
  'Fhv1',
  'Fcv',
  'Felv',
  'Chlamydia',
  'Cdv',
  'Cav2',
  'Cpv2',
  'Cpiv',
  'Lepto',
  'Bordetella',
  'Lyme',
  'CanineInfluenza',
  'Leishmania',
];

/** The server's limits of a plan and a record. */
export const CARE_MAX = {
  title: 100,
  product: 100,
  manufacturer: 100,
  batchNumber: 50,
  clinic: 200,
  veterinarian: 100,
  notes: 2000,
  laboratory: 200,
  reportNumber: 50,
  titer: 1000,
} as const;

/** The longest interval of a plan: ten years in each unit. */
export const MAX_INTERVAL: Record<IntervalUnit, number> = { Day: 3650, Week: 520, Month: 120, Year: 10 };

/** The latest next date the server takes: ten years from today. */
export function latestDueDate(today: string): string {
  return addInterval(today, 10, 'Year');
}

/** Kinds where something is given: they have a product, its manufacturer and a batch number. */
export function usesProduct(kind: CareKind): boolean {
  return !['RabiesTiter', 'VetExam', 'Dental', 'Grooming'].includes(kind);
}

/** Only vaccinations protect for a while: "valid from" and "valid until". */
export function usesValidity(kind: CareKind): boolean {
  return kind === 'Vaccination';
}

/** Only vaccinations protect against diseases. */
export function usesTargets(kind: CareKind): boolean {
  return kind === 'Vaccination';
}

/** The hour matters only for the tapeworm treatment before travel. */
export function usesTime(kind: CareKind): boolean {
  return kind === 'Echinococcus';
}

/** The laboratory, report number and result of a rabies antibody test. */
export function usesTiter(kind: CareKind): boolean {
  return kind === 'RabiesTiter';
}

/** Weight and "fit to travel" are noted at a check-up. */
export function usesExam(kind: CareKind): boolean {
  return kind === 'VetExam';
}

const CAT_TARGETS: readonly VaccineTarget[] = ['Rabies', 'Fpv', 'Fhv1', 'Fcv', 'Felv', 'Chlamydia'];
const DOG_TARGETS: readonly VaccineTarget[] = [
  'Rabies',
  'Cdv',
  'Cav2',
  'Cpv2',
  'Cpiv',
  'Lepto',
  'Bordetella',
  'Lyme',
  'CanineInfluenza',
  'Leishmania',
];

/**
 * The vaccine targets offered for a species (a cat's vaccines for cats, a dog's for dogs, all for other animals), and
 * the ones already chosen, so saving never drops them unseen; in the usual order.
 */
export function offeredTargets(species: Species, chosen: readonly VaccineTarget[] = []): VaccineTarget[] {
  const forSpecies = species === 'Cat' ? CAT_TARGETS : species === 'Dog' ? DOG_TARGETS : VACCINE_TARGETS;
  return VACCINE_TARGETS.filter((target) => forSpecies.includes(target) || chosen.includes(target));
}

/** Targets in the usual order, whatever order they were picked in. */
export function orderedTargets(targets: readonly VaccineTarget[]): VaccineTarget[] {
  return VACCINE_TARGETS.filter((target) => targets.includes(target));
}

/** The title a new record starts with: "Rabies" for a vaccination against one disease, else the kind's name. */
export function defaultRecordTitle(t: Messages, kind: CareKind, targets: readonly VaccineTarget[]): string {
  const only = targets.length === 1 ? targets[0] : undefined;
  return kind === 'Vaccination' && only ? t.vaccineTarget[only] : t.careKind[kind];
}

/** The groups of the ready-made plans. */
export type PresetGroup = 'vaccinations' | 'deworming' | 'parasites' | 'checkUps' | 'travel';
export const PRESET_GROUPS: readonly PresetGroup[] = ['vaccinations', 'deworming', 'parasites', 'checkUps', 'travel'];

export function presetGroupOf(kind: CareKind): PresetGroup {
  switch (kind) {
    case 'Vaccination':
      return 'vaccinations';
    case 'Deworming':
      return 'deworming';
    case 'FleaTick':
    case 'Heartworm':
      return 'parasites';
    case 'Echinococcus':
    case 'RabiesTiter':
      return 'travel';
    default:
      return 'checkUps';
  }
}

const STATUS_ORDER: readonly CareStatus[] = ['Overdue', 'DueSoon', 'Upcoming', 'Inactive'];

/** The plans by status, in the Health tab's order; each keeps the server's order (soonest first); no empty groups. */
export function groupPlans(plans: readonly CarePlan[]): [CareStatus, CarePlan[]][] {
  return STATUS_ORDER.map((status): [CareStatus, CarePlan[]] => [
    status,
    plans.filter((plan) => plan.status === status),
  ]).filter(([, group]) => group.length > 0);
}

/**
 * The plan's next date after "Done" on `performedOn`: the date the person chose, else the day the protection ends
 * (a vaccine's "valid until"), else one interval later. Null when the plan finishes instead: a one-off plan ends with
 * "Done" unless a next date was chosen.
 */
export function nextDueAfterDone({
  interval,
  performedOn,
  validUntil,
  chosen,
}: {
  interval: { value: number; unit: IntervalUnit } | null;
  performedOn: string;
  validUntil: string | null;
  chosen: string | null;
}): string | null {
  if (chosen) return chosen;
  if (!interval) return null;
  return validUntil ?? addInterval(performedOn, interval.value, interval.unit);
}
