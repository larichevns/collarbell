// The onboarding, "Getting to know the app" (the phone app's welcome_screen.dart): three pages about what the app
// does, then, for those who can edit, the first steps: a pet, its feeding times and, for owners, the family. Helpers
// end after the pages: they don't set things up. There is no notifications step: reminders come to the phone app,
// and the first page says so.
//
// Home opens it by itself once for a new account (takeOnboardingTurn), Settings → Help whenever asked; opened either
// way, it counts as seen, and Home won't open it again. The page or step is in the address (/welcome?page=2,
// /welcome?step=feeding), so the browser's Back goes to the one before, as the arrow does; nothing saved is undone
// going back. Every step can be skipped; "Done" (or "Close") puts Home in its place. What it saves goes to the
// household it was opened in: another household on screen starts it again from the first page, and a save that ends
// after that moves nothing.
//
// Kept steady: a button waits while its save is on its way (a second press does nothing), the second click of a
// double click on any of its buttons never lands on the next step's, and a failed save keeps the step on screen with
// the reason.
// Adding a pet has no request id in the API: when its answer is lost, the pets are read again before anything else,
// so a pet the lost try added shows as "Already here" instead of being added twice. A name typed and not saved asks
// before leaving.
import { useQueryClient } from '@tanstack/react-query';
import {
  useEffect,
  useId,
  useRef,
  useState,
  type FormEvent,
  type MouseEvent,
  type ReactNode,
  type RefObject,
} from 'react';
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router';
import { ApiError, data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { usePets, useRoutines } from '../../api/queries';
import type { Pet, PetRequest, RoutineRequest, Species } from '../../api/types';
import { ActionCard } from '../../components/ActionCard';
import { ChoiceGroup, TextField, useFocusFirstError } from '../../components/fields';
import { Icon } from '../../components/Icon';
import type { IconName } from '../../components/icons';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { PetAvatar } from '../../components/PetAvatar';
import { ErrorNotice, Loading, Notice, Spinner, useDocumentTitle } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { markOnboardingSeen } from '../../household/remembered';
import { useI18n } from '../../i18n/i18n';
import { apiTime } from '../../lib/dates';
import { FEEDING_MAX, orderedTimes, WEEK } from '../../lib/feeding';
import { useSession } from '../../session';
import { routineHolds } from '../feeding/FeedingFormPage';
import { InviteDialog } from '../settings/InviteDialog';

type Step = 'pet' | 'feeding' | 'family';
type Place = { page: number } | { step: Step };

const PAGES = 3;
const MAX_NAME = 60;
const SPECIES: readonly Species[] = ['Cat', 'Dog'];
/** Twice a day by default, as most cats and dogs eat. */
const DEFAULT_TIMES = ['08:00', '19:00'];

/** The history entries the onboarding adds itself say so: Back from them is the browser's Back. */
interface WelcomeState {
  welcomeBack?: boolean;
}

/**
 * A press of the onboarding's buttons: the second click of a double click does nothing. By then the page or step has
 * moved on, and it would press the same place on the next one: "Skip" twice, or the next step's main button.
 */
function once(action: () => void) {
  return (event: MouseEvent<HTMLButtonElement>) => {
    if (event.detail > 1) {
      event.preventDefault();
      return;
    }
    action();
  };
}

const searchOf = (place: Place) =>
  'step' in place ? `?step=${place.step}` : place.page > 1 ? `?page=${place.page}` : '';

export function WelcomePage() {
  const { current } = useHousehold();
  // Another household on screen: a fresh start there, nothing typed here carried over.
  return <Welcome key={current.id} />;
}

function Welcome() {
  const i18n = useI18n();
  const { t } = i18n;
  const { current, permissions } = useHousehold();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const location = useLocation();
  const [search] = useSearchParams();
  useDocumentTitle(t.welcomeTitle);
  const { user } = useSession();
  // Seen, however it was opened (Settings → Help, say): Home won't open it by itself afterwards.
  useEffect(() => markOnboardingSeen(user.uid), [user.uid]);
  // A save that ends after another household came on screen (the onboarding starts again there) moves nothing.
  const stillHere = useStillHere(household);

  const steps: Step[] = !permissions.canEdit
    ? []
    : permissions.canManagePeople
      ? ['pet', 'feeding', 'family']
      : ['pet', 'feeding'];
  const stepIndex = steps.indexOf(search.get('step') as Step);
  const step = stepIndex >= 0 ? steps[stepIndex]! : null;
  const page = step ? PAGES : Math.min(PAGES, Math.max(1, Number(search.get('page')) || 1));
  const placeKey = step ?? `page-${page}`;

  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  // The pet step: the name and species typed, the pet added here (its feeding comes next).
  const [name, setName] = useState('');
  const [species, setSpecies] = useState<Species>('Cat');
  const [nameChecked, setNameChecked] = useState(false);
  const [nameRefused, setNameRefused] = useState(false);
  /** "Save and continue" pressed with a mistake: the focus goes to the field. */
  const [attempt, setAttempt] = useState(0);
  const petForm = useRef<HTMLFormElement>(null);
  useFocusFirstError(petForm, attempt);
  const [addedPet, setAddedPet] = useState<Pet | null>(null);
  /** A try of adding the pet got no clear answer: the pets are read again before the next one. */
  const unsure = useRef(false);

  // The feeding step: the times, a time typed and not added yet, and per pet the request id kept across tries.
  const [times, setTimes] = useState<string[]>(DEFAULT_TIMES);
  const [newTime, setNewTime] = useState('12:00');
  const [timeTyped, setTimeTyped] = useState(false);
  const requests = useRef(new Map<string, { id: string; tries: number }>());

  // The family step.
  const [inviting, setInviting] = useState(false);
  const [invited, setInvited] = useState(false);

  const pets = usePets();
  const active = (pets.data ?? []).filter((pet) => pet.status === 'Active');
  const feedingPet = addedPet ?? active[0] ?? null;
  const routines = useRoutines(feedingPet?.id ?? '', step === 'feeding' && feedingPet !== null);

  // A name typed on the pet step and not saved: leaving the onboarding asks first.
  const askingName = step === 'pet' && !!pets.data && active.length === 0;
  useLeaveGuard(askingName && name.trim() !== '', busy);

  // A new page or step: the reason of the last one goes, and the focus goes to its title (not on the first one).
  const heading = useRef<HTMLHeadingElement>(null);
  const shownPlace = useRef(placeKey);
  useEffect(() => {
    if (shownPlace.current === placeKey) return;
    shownPlace.current = placeKey;
    setFailure(null);
    heading.current?.focus();
  }, [placeKey]);

  // --- Moving between pages and steps ------------------------------------------------------------------------------

  const go = (place: Place) => void navigate({ search: searchOf(place) }, { state: { welcomeBack: true } });
  // Home in its place: Back from Home doesn't bring a finished onboarding back.
  const finish = () => void navigate('/', { replace: true });
  const afterPages = () => (steps.length > 0 ? go({ step: steps[0]! }) : finish());
  const nextStep = (from: number) => (from + 1 < steps.length ? go({ step: steps[from + 1]! }) : finish());
  let previous: Place | null = null;
  if (stepIndex > 0) previous = { step: steps[stepIndex - 1]! };
  else if (stepIndex === 0) previous = { page: PAGES };
  else if (page > 1) previous = { page: page - 1 };

  function back() {
    if (!previous) return;
    // The entry before is the onboarding's own: the browser's Back, so Forward works too. Opened at a step: replaced.
    if ((location.state as WelcomeState | null)?.welcomeBack) void navigate(-1);
    else void navigate({ search: searchOf(previous) }, { replace: true });
  }

  function skip() {
    if (stepIndex >= 0) nextStep(stepIndex);
    else afterPages();
  }

  // --- The pet ------------------------------------------------------------------------------------------------------

  const typed = name.trim();
  const nameError = !nameChecked
    ? typed.length > MAX_NAME
      ? t.formTooLong(MAX_NAME)
      : null
    : !typed
      ? t.petNameRequired
      : typed.length > MAX_NAME
        ? t.formTooLong(MAX_NAME)
        : nameRefused
          ? t.formServerFieldError
          : null;

  /** The pet with its name and species, as the pet form adds it; the rest of its details can be filled in later. */
  function petRequest(): PetRequest {
    return {
      name: typed,
      species,
      sex: 'Unknown',
      breed: null,
      birthDate: null,
      birthDateApproximate: false,
      neutered: null,
      neuteredOn: null,
      color: null,
      markings: null,
      coat: null,
      allergies: null,
      notes: null,
      status: null,
      identifiers: [],
    };
  }

  async function savePet() {
    if (busy) return;
    setNameChecked(true);
    setNameRefused(false);
    setFailure(null);
    if (!typed || typed.length > MAX_NAME) {
      setFailure(t.formCheckFields);
      setAttempt((value) => value + 1);
      return;
    }
    setBusy(true);
    try {
      if (unsure.current) {
        // The last try may have added the pet without its answer reaching here: the list first.
        const fresh = await pets.refetch({ throwOnError: true });
        unsure.current = false;
        // It did (or someone else added one meanwhile): the step shows it, nothing is added twice.
        if (fresh.data?.some((pet) => pet.status === 'Active')) return;
      }
      const saved = await data(api.POST('/api/v1/pets', { body: petRequest() }));
      // The list, Home and Today (their pets) are read again.
      void queryClient.invalidateQueries({ queryKey: keys.pets(household) });
      void queryClient.invalidateQueries({ queryKey: keys.todayAll(household) });
      setAddedPet(saved);
      setName('');
      setNameChecked(false);
      if (stillHere()) go({ step: 'feeding' });
    } catch (error) {
      if (fieldErrorsOf(error).name) {
        setNameRefused(true);
        setFailure(t.formCheckFields);
        setAttempt((value) => value + 1);
        return;
      }
      setFailure(errorMessage(t, error));
      // No answer, or the server failed on the way: the pet may be there all the same. The list is read again now, so
      // the step shows it if so, and again before the next try.
      if (!(error instanceof ApiError) || error.status === 0 || error.status >= 500) {
        unsure.current = true;
        void pets.refetch();
      }
    } finally {
      setBusy(false);
    }
  }

  // --- The feeding --------------------------------------------------------------------------------------------------

  /** The times with the one typed in the new-time field, when it is a new one and there is room. */
  function withTyped(list: string[]): string[] {
    const time = newTime.slice(0, 5);
    if (!time || list.includes(time) || list.length >= FEEDING_MAX.times) return list;
    return orderedTimes([...list, time]);
  }

  function addTime() {
    setTimeTyped(false);
    setFailure(null);
    setTimes((old) => withTyped(old));
  }

  function refreshFeeding(petId: string) {
    void queryClient.invalidateQueries({ queryKey: keys.routines(household, petId) });
    void queryClient.invalidateQueries({ queryKey: keys.todayAll(household) });
  }

  /** A schedule every day at the times for `pet`: food and portion can be added later in its Feeding tab. */
  async function saveFeeding(pet: Pet) {
    if (busy) return;
    const all = timeTyped ? withTyped(times) : times;
    if (all !== times) {
      setTimes(all);
      setTimeTyped(false);
    }
    if (all.length === 0) {
      setFailure(t.feedingTimesRequired);
      return;
    }
    // One id per pet's new schedule, sent with every try: a retry after a lost answer gets the schedule that was added.
    const request = requests.current.get(pet.id) ?? { id: crypto.randomUUID(), tries: 0 };
    const retry = request.tries > 0;
    requests.current.set(pet.id, { ...request, tries: request.tries + 1 });
    const sent: RoutineRequest = {
      kind: 'Feeding',
      times: all.map(apiTime),
      days: [...WEEK],
      food: null,
      amount: null,
      unit: null,
      notes: null,
      active: null,
      requestId: request.id,
      supplyItemId: null,
    };
    setBusy(true);
    setFailure(null);
    try {
      const added = await data(
        api.POST('/api/v1/pets/{petId}/routines', { params: { path: { petId: pet.id } }, body: sent }),
      );
      // A retry gets the schedule as the first try made it: times changed since then follow it.
      if (retry && !routineHolds(added, sent)) {
        await api.PUT('/api/v1/routines/{id}', {
          params: { path: { id: added.id } },
          body: { ...sent, requestId: null },
        });
      }
      refreshFeeding(pet.id);
      if (stillHere()) nextStep(steps.indexOf('feeding'));
    } catch (error) {
      // The save may have gone through and only the answer got lost: the step shows the schedule if so.
      refreshFeeding(pet.id);
      setFailure(isNotFound(error) ? t.careGonePet : errorMessage(t, error));
    } finally {
      setBusy(false);
    }
  }

  // --- What each page and step shows ------------------------------------------------------------------------------

  const formId = useId();
  let body: ReactNode;
  let main: { label: string; onPress?: () => void; form?: string; disabled?: boolean };

  if (step === null) {
    const intro: [IconName, string, string][] = [
      ['notifications', t.welcomeIntro1Title, t.welcomeIntro1Body],
      ['document_scanner', t.welcomeIntro2Title, t.welcomeIntro2Body],
      ['group', t.welcomeIntro3Title, t.welcomeIntro3Body],
    ];
    const [icon, title, text] = intro[page - 1]!;
    body = (
      <div className="welcome-intro">
        <span className="welcome-art" aria-hidden="true">
          <span className="welcome-art-inner">
            <Icon name={icon} size={52} />
          </span>
        </span>
        <h1 className="welcome-title" ref={heading} tabIndex={-1}>
          {title}
        </h1>
        <p className="welcome-text">{text}</p>
        <Dots page={page} />
      </div>
    );
    main = {
      label: page < PAGES ? t.welcomeNext : t.welcomeStart,
      onPress: () => (page < PAGES ? go({ page: page + 1 }) : afterPages()),
    };
  } else if (step === 'pet') {
    const invitedCard = (
      <ActionCard icon="vpn_key" title={t.welcomeInvitedTitle} hint={t.welcomeInvitedHint} to="/join" />
    );
    let content: ReactNode;
    main = { label: stepIndex + 1 < steps.length ? t.welcomeNext : t.welcomeDone, onPress: () => nextStep(stepIndex) };
    if (pets.error && !pets.data) {
      content = <ErrorNotice error={pets.error} onRetry={() => void pets.refetch()} />;
    } else if (!pets.data) {
      content = <Loading />;
      main = { ...main, disabled: true };
    } else if (active.length > 0) {
      content = (
        <>
          <Done>{t.welcomePetHere(active.map((pet) => pet.name).join(', '))}</Done>
          <Link to="/pets/new" className="button button--secondary align-start">
            <Icon name="add" size={18} />
            {t.welcomePetAddMore}
          </Link>
          <div className="welcome-gap">{invitedCard}</div>
        </>
      );
    } else {
      content = (
        <form
          ref={petForm}
          id={formId}
          className="form-stack"
          noValidate
          aria-busy={busy || undefined}
          onSubmit={(event: FormEvent) => {
            event.preventDefault();
            void savePet();
          }}
        >
          <fieldset className="form-stack" disabled={busy}>
            <TextField label={t.petNameLabel} value={name} onChange={setName} autoComplete="off" error={nameError} />
            <ChoiceGroup
              label={t.petSpeciesLabel}
              value={species}
              options={SPECIES.map((value) => ({ value, label: t.speciesShort[value] }))}
              onChange={setSpecies}
            />
          </fieldset>
          <div className="welcome-gap">{invitedCard}</div>
        </form>
      );
      main = { label: t.welcomeSaveNext, form: formId };
    }
    body = (
      <StepPage heading={heading} icon="pets" title={t.welcomePetTitle} text={t.welcomePetBody}>
        {content}
      </StepPage>
    );
  } else if (step === 'feeding') {
    const last = stepIndex + 1 >= steps.length;
    main = { label: last ? t.welcomeDone : t.welcomeNext, onPress: () => nextStep(stepIndex) };
    let content: ReactNode;
    if (!feedingPet) {
      content = pets.data || pets.error ? <Notice>{t.welcomeFeedingNoPet}</Notice> : <Loading />;
    } else {
      let schedule: ReactNode;
      if (routines.error && !routines.data) {
        schedule = <ErrorNotice error={routines.error} onRetry={() => void routines.refetch()} />;
      } else if (!routines.data) {
        schedule = <Loading />;
        main = { ...main, disabled: true };
      } else if (routines.data.length > 0) {
        schedule = <Done>{t.welcomeFeedingSet}</Done>;
      } else {
        schedule = (
          <fieldset className="choice-group" disabled={busy}>
            <legend className="field-label">{t.feedingTimesLabel}</legend>
            {times.length > 0 && (
              <ul className="choices plain-list">
                {times.map((time) => (
                  <li key={time}>
                    <button
                      type="button"
                      className="choice-pill time-chip"
                      aria-label={t.feedingTimeRemove(i18n.time(time))}
                      onClick={() => setTimes((old) => old.filter((each) => each !== time))}
                    >
                      {i18n.time(time)}
                      <Icon name="close" size={16} />
                    </button>
                  </li>
                ))}
              </ul>
            )}
            {times.length < FEEDING_MAX.times && (
              <div className="time-add">
                <label className="visually-hidden" htmlFor={`${formId}-time`}>
                  {t.feedingTimeNew}
                </label>
                <input
                  id={`${formId}-time`}
                  className="input input--time"
                  type="time"
                  value={newTime}
                  onChange={(event) => {
                    setNewTime(event.target.value);
                    setTimeTyped(true);
                  }}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter') {
                      event.preventDefault();
                      addTime();
                    }
                  }}
                />
                <button type="button" className="button button--secondary" onClick={addTime}>
                  <Icon name="add" size={18} />
                  {t.feedingTimeAdd}
                </button>
              </div>
            )}
          </fieldset>
        );
        main = { label: t.welcomeSaveNext, onPress: () => void saveFeeding(feedingPet) };
      }
      content = (
        <>
          <p className="welcome-pet">
            <PetAvatar name={feedingPet.name} photo={feedingPet.photo} size="sm" />
            <span className="welcome-pet-name">{feedingPet.name}</span>
          </p>
          {schedule}
        </>
      );
    }
    body = (
      <StepPage heading={heading} icon="restaurant" title={t.welcomeFeedingTitle} text={t.welcomeFeedingBody}>
        {content}
      </StepPage>
    );
  } else {
    body = (
      <StepPage heading={heading} icon="group_add" title={t.welcomeFamilyTitle} text={t.welcomeFamilyBody}>
        {invited && (
          <>
            <Done>{t.welcomeFamilyInvited}</Done>
            <button type="button" className="button button--secondary align-start" onClick={() => setInviting(true)}>
              <Icon name="person_add" size={18} />
              {t.welcomeFamilyInviteMore}
            </button>
          </>
        )}
      </StepPage>
    );
    main = invited
      ? { label: t.welcomeDone, onPress: finish }
      : { label: t.householdInvite, onPress: () => setInviting(true) };
  }

  const press = once(() => main.onPress?.());

  return (
    <div className="welcome">
      <div className="welcome-top">
        {previous ? (
          <button
            type="button"
            className="icon-button"
            aria-label={t.welcomeBack}
            title={t.welcomeBack}
            onClick={once(back)}
            disabled={busy}
          >
            <Icon name="arrow_back" />
          </button>
        ) : (
          <button
            type="button"
            className="icon-button"
            aria-label={t.welcomeClose}
            title={t.welcomeClose}
            onClick={once(finish)}
            disabled={busy}
          >
            <Icon name="close" />
          </button>
        )}
        <span className="welcome-step">{step && t.welcomeStep(stepIndex + 1, steps.length)}</span>
        {/* An escape, not a call to action: it stays text. */}
        <button type="button" className="button button--ghost" onClick={once(skip)} disabled={busy}>
          {t.welcomeSkip}
        </button>
      </div>
      <div className="welcome-body">{body}</div>
      <div className="welcome-foot">
        {failure && (
          <p className="form-error" role="alert">
            <Icon name="error" size={18} />
            {failure}
          </p>
        )}
        <button
          type={main.form ? 'submit' : 'button'}
          form={main.form}
          className="button button--primary button--wide"
          disabled={busy || main.disabled}
          onClick={press}
        >
          {busy && <Spinner />}
          {busy ? t.commonSaving : main.label}
        </button>
      </div>
      {inviting && (
        <InviteDialog
          api={api}
          household={household}
          invite={null}
          onClose={() => setInviting(false)}
          onCreated={() => setInvited(true)}
        />
      )}
    </div>
  );
}

/** A setup step: its icon in a mint circle, the title, why it matters, then what it asks for. */
function StepPage({
  heading,
  icon,
  title,
  text,
  children,
}: {
  heading: RefObject<HTMLHeadingElement | null>;
  icon: IconName;
  title: string;
  text: string;
  children: ReactNode;
}) {
  return (
    <div className="welcome-step-page">
      <span className="welcome-step-icon" aria-hidden="true">
        <Icon name={icon} size={32} />
      </span>
      <h1 className="welcome-title" ref={heading} tabIndex={-1}>
        {title}
      </h1>
      <p className="welcome-text">{text}</p>
      <div className="welcome-content">{children}</div>
    </div>
  );
}

/** Where the pages are: a dot each, the current one long and green. */
function Dots({ page }: { page: number }) {
  const { t } = useI18n();
  return (
    <p className="welcome-dots" role="img" aria-label={t.welcomePage(page, PAGES)}>
      {Array.from({ length: PAGES }, (_, index) => (
        <span key={index} className={`welcome-dot${index + 1 === page ? ' is-current' : ''}`} />
      ))}
    </p>
  );
}

/** Something already in place: the green check and what it is. */
function Done({ children }: { children: ReactNode }) {
  return (
    <p className="welcome-done">
      <Icon name="check_circle" className="mark-icon--done" />
      <span>{children}</span>
    </p>
  );
}
