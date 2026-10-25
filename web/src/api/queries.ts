// What the pages read, through React Query: cached per household, read again when the window comes back to the
// front, and when the live updates say someone else changed it (live/topics.ts). Without a live connection (it is
// opening, or the server can't be reached), Today reads itself every 30 seconds as well.
import { useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query';
import { useApi, useHousehold } from '../household/household';
import { useLiveStatus } from '../live/LiveProvider';
import { useSession } from '../session';
import { data } from './client';
import { keys } from './keys';
import type { AiImport, CareRecord, Me, Pet, PetDocument, Routine, Species, Supply } from './types';

/** How often Today is read again while it is open and the tab has no live connection. */
export const TODAY_REFRESH_MS = 30_000;

/** How often a scan or note being read is asked about. */
export const SCAN_POLL_MS = 2_000;

export function useToday(date: string) {
  const api = useApi();
  const { current } = useHousehold();
  // Connected, the live updates say when Today changes.
  const live = useLiveStatus() === 'live';
  return useQuery({
    queryKey: keys.today(current.id, date),
    queryFn: ({ signal }) => data(api.GET('/api/v1/today', { params: { query: { date } }, signal })),
    refetchInterval: live ? false : TODAY_REFRESH_MS,
  });
}

export function usePets() {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.pets(current.id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/pets', { signal })),
  });
}

/** One pet. Until its own answer comes, the list's copy of it, so the page opens at once. */
export function usePet(id: string) {
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  return useQuery<Pet>({
    queryKey: keys.pet(current.id, id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/pets/{id}', { params: { path: { id } }, signal })),
    placeholderData: () => queryClient.getQueryData<Pet[]>(keys.pets(current.id))?.find((pet) => pet.id === id),
  });
}

export function useVisits() {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.visits(current.id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/appointments', { signal })),
  });
}

export function useVisit(id: string) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.visit(current.id, id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/appointments/{id}', { params: { path: { id } }, signal })),
  });
}

export function useCarePlan(id: string) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.carePlan(current.id, id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/care-plans/{id}', { params: { path: { id } }, signal })),
  });
}

/** The pet's plans: active ones first, soonest due first. */
export function useCarePlans(petId: string) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.carePlans(current.id, petId),
    queryFn: ({ signal }) => data(api.GET('/api/v1/pets/{petId}/care-plans', { params: { path: { petId } }, signal })),
  });
}

/** The ready-made plans for a species: the server's catalog, the same for everyone. */
export function useCarePresets(species: Species | undefined) {
  const api = useApi();
  return useQuery({
    queryKey: keys.carePresets(species ?? 'Other'),
    queryFn: ({ signal }) => data(api.GET('/api/v1/care-plan-presets', { params: { query: { species } }, signal })),
    enabled: species !== undefined,
    staleTime: 60 * 60_000,
  });
}

/** The pet's history, newest first. */
export function useCareRecords(petId: string) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.careRecords(current.id, petId),
    queryFn: ({ signal }) =>
      data(api.GET('/api/v1/pets/{petId}/care-records', { params: { path: { petId } }, signal })),
  });
}

/** One record. Until its own answer comes, a history's copy of it. */
export function useCareRecord(id: string) {
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  return useQuery<CareRecord>({
    queryKey: keys.careRecord(current.id, id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/care-records/{id}', { params: { path: { id } }, signal })),
    placeholderData: () => cachedIn<CareRecord>(queryClient, keys.careRecordsAll(current.id), id),
  });
}

export function usePassport(petId: string) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.passport(current.id, petId),
    queryFn: ({ signal }) => data(api.GET('/api/v1/pets/{id}/passport', { params: { path: { id: petId } }, signal })),
  });
}

/** The passport's health sections V–X, oldest first in each, built by the server from the records. */
export function usePassportRecords(petId: string) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.passportRecords(current.id, petId),
    queryFn: ({ signal }) =>
      data(api.GET('/api/v1/pets/{petId}/passport/records', { params: { path: { petId } }, signal })),
  });
}

/** Every document of the pet, passport pages included, newest first. */
export function useDocuments(petId: string) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.documents(current.id, petId),
    queryFn: ({ signal }) => data(api.GET('/api/v1/pets/{petId}/documents', { params: { path: { petId } }, signal })),
  });
}

/** One document. Until its own answer comes, a list's copy of it. */
export function useDocument(id: string) {
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  return useQuery<PetDocument>({
    queryKey: keys.document(current.id, id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/documents/{id}', { params: { path: { id } }, signal })),
    placeholderData: () => cachedIn<PetDocument>(queryClient, [current.id, 'documents'], id),
  });
}

/** The pet's feeding schedules: active ones first, by their first time. */
export function useRoutines(petId: string, enabled = true) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    enabled,
    queryKey: keys.routines(current.id, petId),
    queryFn: ({ signal }) => data(api.GET('/api/v1/pets/{petId}/routines', { params: { path: { petId } }, signal })),
  });
}

export function useRoutine(id: string) {
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  return useQuery<Routine>({
    queryKey: keys.routine(current.id, id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/routines/{id}', { params: { path: { id } }, signal })),
    placeholderData: () => cachedIn<Routine>(queryClient, [current.id, 'routines'], id),
  });
}

/**
 * The household's supplies with their estimates, as the server orders them: what runs out first comes first, items
 * no longer bought last. The feeding form offers its food.
 */
export function useSupplies() {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.supplies(current.id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/supplies', { signal })),
  });
}

/** One item with its estimate and the feedings that give it. Until its own answer comes, the list's copy of it. */
export function useSupply(id: string) {
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  return useQuery<Supply>({
    queryKey: keys.supply(current.id, id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/supplies/{id}', { params: { path: { id } }, signal })),
    placeholderData: () =>
      queryClient.getQueryData<Supply[]>(keys.supplies(current.id))?.find((item) => item.id === id),
  });
}

/** An item's purchases and counts, newest first (the last 50). */
export function useStockEvents(id: string) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.stockEvents(current.id, id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/supplies/{id}/stock-events', { params: { path: { id } }, signal })),
  });
}

/**
 * After a purchase, a count, or a change to an item: the list, the item and its entries (all under the list's key),
 * and Today's "To buy" are read again.
 */
export function refreshSupplies(queryClient: QueryClient, household: string): void {
  void queryClient.invalidateQueries({ queryKey: keys.supplies(household) });
  void queryClient.invalidateQueries({ queryKey: keys.todayAll(household) });
}

/** The person's profile (GET /me), starting from what the session opened with. */
export function useMe() {
  const { user, me, api } = useSession();
  const { current } = useHousehold();
  return useQuery<Me>({
    queryKey: keys.me(user.uid),
    queryFn: ({ signal }) => data(api.forHousehold(current.id).GET('/api/v1/me', { signal })),
    initialData: me,
    staleTime: 60_000,
  });
}

/** The household on screen with its people; for owners also its open invites. */
export function useHouseholdDetails() {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.householdDetails(current.id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/households/current', { signal })),
  });
}

/** The household's plan (Free or Premium) and this month's AI photos. */
export function usePlan() {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.plan(current.id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/plan', { signal })),
  });
}

/** Whether the server reads photos with AI (set up in its configuration), for the household on screen. */
export function useAiStatus() {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.aiStatus(current.id),
    queryFn: ({ signal }) => data(api.GET('/api/v1/ai/status', { signal })),
  });
}

/**
 * The pet's scans (photos) or notes still waiting for someone: being read, ready to check, or failed, newest first
 * (the server's newest 20 of each kind).
 */
export function usePetImports(petId: string, kind: 'scans' | 'notes', enabled = true) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    enabled,
    queryKey: keys.aiImports(current.id, petId, kind),
    queryFn: ({ signal }) =>
      data(
        api.GET('/api/v1/pets/{petId}/ai-imports', {
          params: { path: { petId }, query: { notes: kind === 'notes' } },
          signal,
        }),
      ),
  });
}

/** Whether a scan or note is still being read: the app asks again every two seconds. */
export function isReading(scan: Pick<AiImport, 'status'>): boolean {
  return scan.status === 'Queued' || scan.status === 'Processing';
}

/** One scan or note (none: null), asked about every two seconds while AI reads it (the tab in view). */
export function useAiImport(id: string | null) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.aiImport(current.id, id ?? ''),
    queryFn: ({ signal }) => data(api.GET('/api/v1/ai-imports/{id}', { params: { path: { id: id! } }, signal })),
    enabled: id !== null,
    refetchInterval: (query) => (query.state.data && isReading(query.state.data) ? SCAN_POLL_MS : false),
  });
}

/** What deleting the account would do to each of the person's households, and the fingerprint of it. */
export function useDeletionPreview() {
  const { user, api } = useSession();
  return useQuery({
    queryKey: keys.deletion(user.uid),
    // The person's own: it names no household.
    queryFn: ({ signal }) => data(api.forHousehold(null).GET('/api/v1/me/deletion', { signal })),
  });
}

/**
 * After a scan or note was saved (or part of it, before a failure): everything it can change for the pet is read
 * again: its care, the pet (microchips), the passport, the documents (the photos kept), its scans and notes.
 */
export function refreshAfterScan(queryClient: QueryClient, household: string, petId: string): void {
  refreshCare(queryClient, household, petId);
  void queryClient.invalidateQueries({ queryKey: keys.pets(household) });
  void queryClient.invalidateQueries({ queryKey: keys.passport(household, petId) });
  void queryClient.invalidateQueries({ queryKey: keys.documents(household, petId) });
  void queryClient.invalidateQueries({ queryKey: [household, 'document'] });
  refreshImports(queryClient, household);
}

/** The scans and notes waiting for someone, the month's AI photos and the plan's count. */
export function refreshImports(queryClient: QueryClient, household: string): void {
  void queryClient.invalidateQueries({ queryKey: keys.aiImportsAll(household) });
  void queryClient.invalidateQueries({ queryKey: keys.plan(household) });
}

/**
 * A scan saved or thrown away here, as it is now, in the cache of its page: opened again (Back), the page shows it so
 * at once, never as ready from a copy of before (the live updates skip the tab's own changes). Nothing kept for it,
 * nothing to change.
 */
export function cacheScan(queryClient: QueryClient, household: string, id: string, change: Partial<AiImport>): void {
  queryClient.setQueryData<AiImport>(keys.aiImport(household, id), (old) => old && { ...old, ...change });
}

/** Whether AI is set up, in every household: an AI call said it isn't (any more), so the buttons that use it go. */
export function refreshAiStatus(queryClient: QueryClient): void {
  void queryClient.invalidateQueries({ predicate: (query) => query.queryKey[1] === 'ai-status' });
}

/** The pet's weight log, newest first: its weighings and the weights a vet noted at check-ups. */
export function useWeights(petId: string) {
  const api = useApi();
  const { current } = useHousehold();
  return useQuery({
    queryKey: keys.weights(current.id, petId),
    queryFn: ({ signal }) => data(api.GET('/api/v1/pets/{petId}/weights', { params: { path: { petId } }, signal })),
  });
}

/** A thing by id in the lists cached under `prefix` (every pet's history, say), to show while its own answer comes. */
function cachedIn<T extends { id: string }>(
  queryClient: QueryClient,
  prefix: readonly unknown[],
  id: string,
): T | undefined {
  for (const [, list] of queryClient.getQueriesData<T[]>({ queryKey: prefix })) {
    const found = Array.isArray(list) ? list.find((item) => item.id === id) : undefined;
    if (found) return found;
  }
  return undefined;
}

/**
 * After a change to a pet's care (a plan, a record, "Done"), everything that shows it is read again: the plans, the
 * history, the passport's sections, the weight log (a vet's weight lives in a record) and Today.
 */
export function refreshCare(queryClient: QueryClient, household: string, petId?: string): void {
  const all = [
    petId ? keys.carePlans(household, petId) : keys.carePlansAll(household),
    [household, 'care-plan'],
    petId ? keys.careRecords(household, petId) : keys.careRecordsAll(household),
    [household, 'care-record'],
    petId ? keys.passportRecords(household, petId) : keys.passportRecordsAll(household),
    petId ? keys.weights(household, petId) : [household, 'weights'],
    keys.todayAll(household),
  ];
  for (const queryKey of all) void queryClient.invalidateQueries({ queryKey });
}
