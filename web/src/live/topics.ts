// What each topic of the live updates reads again: the React Query keys of the pages that show it, the phone app's
// liveTopicProviders. A key stands for everything under it: [household, 'care-plans'] is every pet's plans, since a
// change says what changed, not for which pet. Only what a page on screen shows loads again at once (React Query
// refetches active queries); the rest is marked stale and loads when shown.
import type { QueryClient, QueryKey } from '@tanstack/react-query';
import { keys } from '../api/keys';
import { ANYTHING } from './live';
import { LIVE_TOPICS, type LiveTopic } from './realtime';

/** Plans and records, the passport's sections, and the weight log (a vet's weight lives in a check-up record). */
const care = (household: string): QueryKey[] => [
  keys.carePlansAll(household),
  [household, 'care-plan'],
  keys.careRecordsAll(household),
  [household, 'care-record'],
  keys.passportRecordsAll(household),
  [household, 'weights'],
];

/** The feeding schedules, every pet's and each one's page. */
const feeding = (household: string): QueryKey[] => [
  [household, 'routines'],
  [household, 'routine'],
];

/** The queries that show a topic in `household`, for the person `uid`. */
export function topicKeys(topic: LiveTopic, household: string, uid: string): QueryKey[] {
  switch (topic) {
    // Their names and photos are on Today and the visits; a paused or deleted pet's feedings use no food. Deleting
    // the account says how many pets a group would lose.
    case 'pets':
      return [
        keys.pets(household),
        keys.todayAll(household),
        keys.visits(household),
        keys.supplies(household),
        keys.deletion(uid),
      ];
    case 'passport':
      return [[household, 'passport']];
    case 'care':
      return [...care(household), keys.todayAll(household)];
    // A weighing added, changed or deleted: the Weight tab.
    case 'weight':
      return [[household, 'weights']];
    // A mark or a schedule. The supplies' estimates follow the schedules, and a schedule changed sends "supplies" too.
    case 'feeding':
      return [...feeding(household), keys.todayAll(household)];
    // A visit that took place adds care records and moves plans.
    case 'visits':
      return [keys.visits(household), keys.todayAll(household), ...care(household)];
    // Today lists what to buy; the schedules show the food's name.
    case 'supplies':
      return [keys.supplies(household), keys.todayAll(household), ...feeding(household)];
    case 'documents':
      return [keys.documentsAll(household), [household, 'document']];
    // The scans waiting on the Passport tab, the notes on the Health tab, a scan being read; a scan uses AI photos of
    // the month: the plan and the AI status count them.
    case 'imports':
      return [keys.aiImportsAll(household), [household, 'ai-import'], keys.plan(household), keys.aiStatus(household)];
    // Its people, their roles, the invites, its name and time zone (what "today" is). The person's groups (names,
    // roles) are read again too: a role changed shows at once. Who is in it decides what deleting the account does.
    case 'household':
      return [
        keys.householdDetails(household),
        keys.me(uid),
        keys.households(uid),
        keys.todayAll(household),
        keys.deletion(uid),
      ];
    // Free or Premium, and the AI photos of the month that a chip or package scan used.
    case 'plan':
      return [keys.plan(household), keys.aiStatus(household)];
  }
}

function isKnown(topic: string): topic is LiveTopic {
  return (LIVE_TOPICS as readonly string[]).includes(topic);
}

/** Reads again what shows `topics`; a topic the app doesn't know (ANYTHING, or a newer server's) reads everything. */
export function readTopics(queryClient: QueryClient, household: string, uid: string, topics: Iterable<string>): void {
  const all = [...topics];
  if (all.some((topic) => topic === ANYTHING || !isKnown(topic))) {
    readEverything(queryClient, household, uid);
    return;
  }
  const seen = new Set<string>();
  for (const topic of all as LiveTopic[]) {
    for (const queryKey of topicKeys(topic, household, uid)) {
      const id = JSON.stringify(queryKey);
      if (seen.has(id)) continue;
      seen.add(id);
      void queryClient.invalidateQueries({ queryKey });
    }
  }
}

/** Everything of the household, and the person's own lists: after a gap (the server keeps no history). */
export function readEverything(queryClient: QueryClient, household: string, uid: string): void {
  void queryClient.invalidateQueries({ predicate: (query) => query.queryKey[0] === household });
  for (const queryKey of [keys.me(uid), keys.households(uid), keys.deletion(uid)]) {
    void queryClient.invalidateQueries({ queryKey });
  }
}
