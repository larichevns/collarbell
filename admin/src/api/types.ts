// What the server's admin API answers (backend: Modules/Admin/AdminEndpoints.cs). JSON in camelCase; times are
// ISO-8601 strings in UTC. Enums come as the server names them: roles "Owner", "Member", "Helper"; platforms
// "Android", "Ios". The screens show unknown values as they are, so a new kind on the server breaks nothing here.

/** A moment as the server wrote it, e.g. "2026-10-05T14:22:05.123+00:00". Passed back unchanged when paging. */
export type IsoTime = string;

/** GET /api/admin/me: who is signed in. 403 means "not an admin". */
export interface AdminMe {
  email: string | null;
  displayName: string | null;
}

/** GET /api/admin/overview: the numbers of the whole service. "24h", "30d": the last 24 hours, 30 days. */
export interface Overview {
  generatedAt: IsoTime;
  people: {
    users: number;
    households: number;
    /** Groups with more than one person. */
    sharedHouseholds: number;
    /** Groups whose Premium works now. */
    premiumHouseholds: number;
    pets: number;
    activeToday: number;
    activeWeek: number;
    newWeek: number;
  };
  reminders: {
    sent24h: number;
    failed24h: number;
    skipped24h: number;
    /** Too late to send (the server was down longer than a reminder may wait). */
    expired24h: number;
    pending: number;
    /** How long the oldest reminder that is due has been waiting; 0 or null: none waits. */
    oldestOverdueMinutes: number | null;
  };
  devices: {
    android: number;
    ios: number;
    appVersions: { version: string; devices: number }[];
  };
  ai: {
    calls24h: number;
    failed24h: number;
    calls30d: number;
    failed30d: number;
    inputTokens30d: number;
    outputTokens30d: number;
    models30d: { model: string; calls: number; failed: number }[];
  };
  api: {
    requests24h: number;
    /** Answers 500 and above. */
    serverErrors24h: number;
    /** Errors people saw in the app. */
    appErrors24h: number;
    crashes24h: number;
  };
  server: {
    diskTotalBytes: number;
    diskFreeBytes: number;
    lastBackupAt: IsoTime | null;
    lastBackupBytes: number | null;
  };
  alerts: {
    telegramConfigured: boolean;
    /** The last alert of each kind, newest first. */
    recent: { kind: string; text: string; sentAt: IsoTime }[];
  };
}

/** A row of GET /api/admin/users. */
export interface UserRow {
  id: string;
  email: string | null;
  displayName: string | null;
  createdAt: IsoTime;
  lastSeenAt: IsoTime | null;
  households: number;
  devices: number;
  aiCalls30d: number;
}

/** GET /api/admin/users/{id}. */
export interface UserDetail {
  id: string;
  email: string | null;
  displayName: string | null;
  locale: string | null;
  timeZone: string | null;
  createdAt: IsoTime;
  lastSeenAt: IsoTime | null;
  households: { id: string; name: string; role: string; memberCount: number; pets: number; plan: PlanKind }[];
  devices: { platform: string; appVersion: string | null; lastSeenAt: IsoTime }[];
  ai: { calls30d: number; failed30d: number; inputTokens30d: number; outputTokens30d: number };
}

export type TimelineKind = 'request' | 'screen' | 'action' | 'error' | 'crash';

/**
 * One line of the визор (GET /api/admin/users/{id}/timeline), newest first. A request: text "PUT /api/v1/pets/…",
 * with status and durationMs. A screen: its route, "/pets/:id/health". An action, an error or a crash: a short text.
 */
export interface TimelineEvent {
  at: IsoTime;
  kind: TimelineKind;
  text: string;
  status: number | null;
  durationMs: number | null;
  /** One launch of the app; null when the request came without one. */
  session: string | null;
  householdId: string | null;
  appVersion: string | null;
}

export type PlanKind = 'Free' | 'Premium';

/** Who made the last change of a plan: an admin by hand, or a purchase (later). */
export type PlanSource = 'Manual' | 'Paddle' | 'AppStore';

/** A household's plan (backend: AdminPlan): what works now, the last change, and this month's AI photos. */
export interface AdminPlan {
  /** What works now: a Premium past its end is Free. */
  plan: PlanKind;
  /** null: nobody ever changed it (always Free). */
  source: PlanSource | null;
  /** The given Premium's end, also when it has passed; null: no end. */
  expiresAt: IsoTime | null;
  note: string | null;
  changedAt: IsoTime | null;
  /** The admin's e-mail. */
  changedBy: string | null;
  /** This calendar month (UTC), passport scans still being read included. */
  aiPhotosUsed: number;
  /** The limit of the plan that works now. */
  aiPhotosPerMonth: number;
}

/** PUT /api/admin/households/{id}/plan: Premium until a moment (or with no end), or Free (expiresAt is ignored). */
export interface PlanRequest {
  plan: PlanKind;
  expiresAt: IsoTime | null;
  /** Up to 200 characters, e.g. "тестер". */
  note: string | null;
}

/** GET /api/admin/households/{id}. */
export interface HouseholdDetail {
  id: string;
  name: string;
  timeZone: string;
  createdAt: IsoTime;
  members: { userId: string; email: string | null; displayName: string | null; role: string; joinedAt: IsoTime }[];
  pets: number;
  routines: number;
  carePlans: number;
  supplies: number;
  openInvites: number;
  plan: AdminPlan;
}

export type ProblemKind = 'server' | 'app-error' | 'crash';

/** A row of GET /api/admin/problems, newest first. */
export interface Problem {
  at: IsoTime;
  kind: ProblemKind;
  userId: string | null;
  email: string | null;
  text: string;
  path: string | null;
  status: number | null;
}
