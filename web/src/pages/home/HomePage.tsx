// Home (the phone app's home_screen.dart), the page the app opens on: a greeting, the pets, what is important right now
// (the next feeding with its "Fed" buttons, how much care is overdue or due soon, the next visit, what to buy) and
// quick actions. "Right now" is made of Today's data, the same query (read again every 30 seconds while live updates
// are off, when the window comes back to the front, and when someone else changes it), so it never lags behind Today;
// Today keeps the full list. On a wide screen "Right now" and the quick actions stand side by side.
//
// Once the pets have loaded, Home opens the onboarding by itself for a new account: in one household, with no pets
// (takeOnboardingTurn). Once per account on this browser, in place of Home, so Back doesn't bring it back.
import { useEffect, useId, useRef, useState, type ReactNode } from 'react';
import { Link, useNavigate } from 'react-router';
import { ApiError } from '../../api/client';
import { useAiStatus, usePets, useToday } from '../../api/queries';
import type { Pet, TodayVisit } from '../../api/types';
import { ActionCard, ActionList } from '../../components/ActionCard';
import { Icon } from '../../components/Icon';
import type { IconName } from '../../components/icons';
import { PetAvatar } from '../../components/PetAvatar';
import { EmptyState, ErrorNotice, Loading, PageHead, Section, StatusTag, useDocumentTitle } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useHousehold } from '../../household/household';
import { takeOnboardingTurn } from '../../household/remembered';
import { useI18n } from '../../i18n/i18n';
import type { Messages } from '../../i18n/en';
import { nextFeedingTime } from '../../lib/feeding';
import { useSession } from '../../session';
import { FeedingSection } from '../today/FeedingSection';
import { FirstStepCards } from '../today/FirstSteps';
import { isEmptyDay, useDayCaption } from '../today/TodayPage';
import { VisitRow } from '../today/VisitsSection';
import { VisitDoneDialog } from '../visits/VisitDoneDialog';
import { WeightDialog } from '../weight/WeightDialog';
import { usePetChoice } from './PetPicker';

/** The greeting by the browser's clock: morning from 05:00, afternoon from 12:00, evening from 17:00, night from 23. */
export function greeting(t: Messages, hour: number): string {
  if (hour >= 5 && hour < 12) return t.homeGreetingMorning;
  if (hour >= 12 && hour < 17) return t.homeGreetingAfternoon;
  if (hour >= 17 && hour < 23) return t.homeGreetingEvening;
  return t.homeGreetingNight;
}

/** The visit to show first: a past one waiting for "The visit took place", else the next one; null without visits. */
export function nextVisit(visits: readonly TodayVisit[]): TodayVisit | null {
  return visits.find((visit) => visit.daysAway < 0) ?? visits[0] ?? null;
}

export function HomePage() {
  const { t } = useI18n();
  const { user } = useSession();
  const { permissions, households } = useHousehold();
  const navigate = useNavigate();
  const date = useHouseholdDate();
  const pets = usePets();
  const today = useToday(date);
  const caption = useDayCaption(today.data?.date ?? date);
  useDocumentTitle(t.navHome);

  // The onboarding's turn, asked once: when the pets have loaded (the household on screen's), not while they reload.
  // Any pet counts, archived ones too; and only someone in a single household is new (the households come with /me).
  const asked = useRef(false);
  useEffect(() => {
    if (asked.current || !pets.data || pets.isFetching) return;
    asked.current = true;
    const turn = { canEdit: permissions.canEdit, hasPets: pets.data.length > 0, households: households.length };
    if (takeOnboardingTurn(user.uid, turn)) void navigate('/welcome', { replace: true });
  }, [pets.data, pets.isFetching, user.uid, permissions.canEdit, households.length, navigate]);

  const active = (pets.data ?? []).filter((pet) => pet.status === 'Active');
  let content: ReactNode;
  if (pets.error && !pets.data) {
    content = (
      <ErrorNotice
        error={pets.error}
        onRetry={() => {
          void pets.refetch();
          void today.refetch();
        }}
      />
    );
  } else if (!pets.data) {
    content = <Loading />;
  } else if (active.length === 0) {
    content = <NoPets />;
  } else {
    content = (
      <>
        <PetsRow pets={active} />
        <div className="home">
          <Section title={t.homeNowTitle}>
            <RightNow today={today} pets={active} />
          </Section>
          {/* Helpers mark and look; adding is for the others. */}
          {permissions.canEdit && (
            <Section title={t.homeQuickTitle}>
              <QuickActions pets={active} />
            </Section>
          )}
        </div>
      </>
    );
  }

  return (
    <>
      {/* Not a string: the browser tab says "Home", not the greeting. */}
      <PageHead title={<>{greeting(t, new Date().getHours())}</>} caption={caption} />
      {content}
    </>
  );
}

/**
 * The active pets, a face and a name each; one opens the pet's page. For those who can add pets, "Add" ends the row.
 */
function PetsRow({ pets }: { pets: readonly Pet[] }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  return (
    <section className="home-pets" aria-label={t.homePetsLabel}>
      <ul className="home-pets-list">
        {pets.map((pet) => (
          <li key={pet.id}>
            <Link to={`/pets/${pet.id}`} className="home-pet">
              <PetAvatar name={pet.name} photo={pet.photo} size="lg" />
              <span className="home-pet-name">{pet.name}</span>
            </Link>
          </li>
        ))}
        {permissions.canEdit && (
          <li>
            <Link to="/pets/new" className="home-pet" aria-label={t.petsAdd}>
              <span className="home-pet-add" aria-hidden="true">
                <Icon name="add" />
              </span>
              <span className="home-pet-name" aria-hidden="true">
                {t.commonAdd}
              </span>
            </Link>
          </li>
        )}
      </ul>
    </section>
  );
}

/**
 * No pets in the group yet: adding one comes first, and the onboarding shows what the app does. Helpers don't add
 * pets: for them it says what will show here.
 */
function NoPets() {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  if (!permissions.canEdit) {
    return (
      <EmptyState icon="pets" title={t.petsEmptyTitle}>
        {t.todayStartBodyHelper}
      </EmptyState>
    );
  }
  return (
    <div className="home-start">
      <ActionList>
        <ActionCard primary icon="pets" title={t.homeAddPetTitle} hint={t.homeAddPetHint} to="/pets/new" />
        <ActionCard icon="waving_hand" title={t.homeTourTitle} hint={t.homeTourHint} to="/welcome" />
      </ActionList>
    </div>
  );
}

/**
 * What needs doing now, from Today's data: the next feeding (its "Fed" buttons work as on Today), the care that is
 * overdue or due soon, the next visit and what to buy. Nothing of that: all done. Nothing set up at all: the first
 * steps. A reload that fails keeps it on screen under the reason, as on Today.
 */
function RightNow({ today, pets }: { today: ReturnType<typeof useToday>; pets: readonly Pet[] }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const [marking, setMarking] = useState<TodayVisit | null>(null);
  const { data, error } = today;
  const retry = () => void today.refetch();

  if (!data) return error ? <ErrorNotice error={error} onRetry={retry} /> : <Loading />;
  const stale = error && !(error instanceof ApiError && error.status === 0);
  const notice = stale ? <ErrorNotice error={error} onRetry={retry} /> : null;
  if (isEmptyDay(data)) {
    return (
      <>
        {notice}
        {permissions.canEdit ? (
          <FirstStepCards pets={pets} />
        ) : (
          <Calm title={t.todayEmptyTitle} body={t.todayEmptyBody} />
        )}
      </>
    );
  }

  const next = nextFeedingTime(data.feedings);
  const overdue = data.care.filter((item) => item.status === 'Overdue').length;
  const soon = data.care.filter((item) => item.status === 'DueSoon').length;
  const visit = nextVisit(data.appointments);
  const toBuy = data.shopping.length;
  if (!next && !overdue && !soon && !visit && !toBuy) {
    return (
      <>
        {notice}
        <Calm done title={t.homeAllDoneTitle} body={t.homeAllDoneBody} />
      </>
    );
  }

  return (
    <div className="now">
      {notice}
      {next && <FeedingSection today={data} only={next} />}
      {(overdue > 0 || soon > 0 || visit || toBuy > 0) && (
        <ul className="card card--list rows">
          {(overdue > 0 || soon > 0) && (
            <NowRow icon="vaccines" to="/today" hint={t.homeCareHint}>
              <span className="now-tags">
                {overdue > 0 && (
                  <StatusTag tone="danger" icon="error">
                    {t.homeOverdue(overdue)}
                  </StatusTag>
                )}
                {/* Heard as two phrases; the gap on screen is the tags' own. */}
                {overdue > 0 && soon > 0 && ' '}
                {soon > 0 && (
                  <StatusTag tone="warning" icon="schedule">
                    {t.homeDueSoon(soon)}
                  </StatusTag>
                )}
              </span>
            </NowRow>
          )}
          {visit && <VisitRow visit={visit} today={data.date} onTookPlace={() => setMarking(visit)} />}
          {toBuy > 0 && (
            <NowRow icon="shopping_cart" to="/supplies" hint={t.homeToBuyHint}>
              {t.homeToBuy(toBuy)}
            </NowRow>
          )}
        </ul>
      )}
      {marking && (
        <VisitDoneDialog
          visit={{ id: marking.id, type: marking.type, petIds: marking.pets.map((pet) => pet.id) }}
          onClose={() => setMarking(null)}
        />
      )}
    </div>
  );
}

/** A row of "Right now" that leads to a page: an icon, what it is (tags, a count), a line under it, a chevron. */
function NowRow({ icon, to, hint, children }: { icon: IconName; to: string; hint: string; children: ReactNode }) {
  const hintId = useId();
  return (
    <li className="row">
      <span className="type-icon">
        <Icon name={icon} />
      </span>
      <div className="row-main">
        <Link to={to} className="row-title row-link" aria-describedby={hintId}>
          {children}
        </Link>
        <span className="row-sub" id={hintId}>
          {hint}
        </span>
      </div>
      <Icon name="chevron_right" className="row-arrow" />
    </li>
  );
}

/** A quiet card: all done for today (with the green check), or nothing planned yet. */
function Calm({ title, body, done = false }: { title: string; body: string; done?: boolean }) {
  return (
    <div className="card calm">
      <Icon
        name={done ? 'check_circle' : 'event_available'}
        size={32}
        className={`calm-icon${done ? ' calm-icon--done' : ''}`}
      />
      <div className="calm-text">
        <p className="calm-title">{title}</p>
        <p className="muted small">{body}</p>
      </div>
    </div>
  );
}

/**
 * What can be started from Home in one press, compact cards side by side. Those that need a pet go straight to the
 * only one, or ask which. The scan and the note need AI on the server, as on the pet's tabs.
 */
function QuickActions({ pets }: { pets: readonly Pet[] }) {
  const { t } = useI18n();
  const ai = useAiStatus().data?.configured ?? false;
  const choice = usePetChoice();
  const [weighing, setWeighing] = useState<Pet | null>(null);
  return (
    <>
      <ActionList grid>
        <ActionCard
          compact
          icon="vaccines"
          title={t.homeQuickCare}
          hint={t.homeQuickCareHint}
          {...choice.target(pets, (pet) => `/pets/${pet.id}/records/new`)}
        />
        <ActionCard compact icon="stethoscope" title={t.visitAddCard} hint={t.visitAddCardHint} to="/visits/new" />
        {ai && (
          <>
            <ActionCard
              compact
              icon="document_scanner"
              title={t.homeQuickScan}
              hint={t.homeQuickScanHint}
              {...choice.target(pets, (pet) => `/pets/${pet.id}/scan?from=passport`)}
            />
            <ActionCard
              compact
              icon="edit_note"
              title={t.homeQuickNote}
              hint={t.homeQuickNoteHint}
              {...choice.target(pets, (pet) => `/pets/${pet.id}/note?from=health`)}
            />
          </>
        )}
        <ActionCard
          compact
          icon="monitor_weight"
          title={t.homeQuickWeigh}
          hint={t.homeQuickWeighHint}
          onClick={() => choice.choose(pets, setWeighing)}
        />
        <ActionCard
          compact
          icon="inventory_2"
          title={t.homeQuickSupply}
          hint={t.homeQuickSupplyHint}
          to="/supplies/new"
        />
      </ActionList>
      {choice.dialog}
      {weighing && <WeightDialog pet={weighing} weighing={null} onClose={() => setWeighing(null)} />}
    </>
  );
}
