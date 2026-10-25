// The keys of React Query's cache. Everything of a household starts with its id, so the data of one household never
// shows in another, and a change reloads what it touched by prefix: ['h1', 'pets'] covers the list and every pet.
import type { Species } from './types';

export const keys = {
  /** The person's households: per account, so another person signed in on this browser never sees them. */
  households: (uid: string) => ['households', uid] as const,
  /** The person's profile (GET /me): per account, like the households. */
  me: (uid: string) => ['me', uid] as const,
  /** The household's people, its invites (for owners), its name and time zone. */
  householdDetails: (household: string) => [household, 'household'] as const,
  /** The household's plan and this month's AI photos. */
  plan: (household: string) => [household, 'plan'] as const,
  /** Whether AI reads photos, and this month's use by the household. */
  aiStatus: (household: string) => [household, 'ai-status'] as const,
  today: (household: string, date: string) => [household, 'today', date] as const,
  todayAll: (household: string) => [household, 'today'] as const,
  pets: (household: string) => [household, 'pets'] as const,
  pet: (household: string, id: string) => [household, 'pets', id] as const,
  carePlan: (household: string, id: string) => [household, 'care-plan', id] as const,
  carePlans: (household: string, petId: string) => [household, 'care-plans', petId] as const,
  carePlansAll: (household: string) => [household, 'care-plans'] as const,
  /** The ready-made plans are the same for everyone: no household. */
  carePresets: (species: Species) => ['care-plan-presets', species] as const,
  careRecord: (household: string, id: string) => [household, 'care-record', id] as const,
  careRecords: (household: string, petId: string) => [household, 'care-records', petId] as const,
  careRecordsAll: (household: string) => [household, 'care-records'] as const,
  passport: (household: string, petId: string) => [household, 'passport', petId] as const,
  passportRecords: (household: string, petId: string) => [household, 'passport-records', petId] as const,
  passportRecordsAll: (household: string) => [household, 'passport-records'] as const,
  documents: (household: string, petId: string) => [household, 'documents', petId] as const,
  documentsAll: (household: string) => [household, 'documents'] as const,
  document: (household: string, id: string) => [household, 'document', id] as const,
  routines: (household: string, petId: string) => [household, 'routines', petId] as const,
  routine: (household: string, id: string) => [household, 'routine', id] as const,
  supplies: (household: string) => [household, 'supplies'] as const,
  supply: (household: string, id: string) => [household, 'supplies', id] as const,
  stockEvents: (household: string, id: string) => [household, 'supplies', id, 'stock-events'] as const,
  weights: (household: string, petId: string) => [household, 'weights', petId] as const,
  visits: (household: string) => [household, 'visits'] as const,
  visit: (household: string, id: string) => [household, 'visits', id] as const,
  /** A pet's scans and notes still waiting for someone: the photo scans (Passport tab) or the notes (Health tab). */
  aiImports: (household: string, petId: string, kind: 'scans' | 'notes') =>
    [household, 'ai-imports', petId, kind] as const,
  aiImportsAll: (household: string) => [household, 'ai-imports'] as const,
  /** One scan or note: its status, photos or text, and its draft once read. */
  aiImport: (household: string, id: string) => [household, 'ai-import', id] as const,
  /** What deleting the account does to each of the person's households: per account, like the households. */
  deletion: (uid: string) => ['deletion', uid] as const,
};
