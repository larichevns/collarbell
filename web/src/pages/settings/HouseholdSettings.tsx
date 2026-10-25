// The group on screen (the phone app's household_screen.dart, household_sheets.dart and the switch sheet): its name
// and time zone (owners change them); its people and their roles (owners change a role, asking an owner who steps down
// first, and remove someone after asking); its open invites (owners: a code for a member or a helper, with a link to
// copy; revoked with a click); the person's groups (switch, join with a code, create one); and leaving the group, or,
// alone in it, deleting it. Everything is done in the household the section opened in; another household on screen
// opens it anew. The server checks the same rules.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useEffectEvent, useId, useRef, useState, type FormEvent } from 'react';
import { Link } from 'react-router';
import { data, type ApiClient } from '../../api/client';
import { fieldErrorsOf, householdErrorMessage, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { useHouseholdDetails } from '../../api/queries';
import type {
  HouseholdDetails,
  HouseholdInvite,
  HouseholdMember,
  HouseholdRole,
  HouseholdSummary,
} from '../../api/types';
import { ConfirmDialog, Dialog, DialogBody, DialogCancel, DialogFoot, DialogForm } from '../../components/Dialog';
import { SelectField, TextField } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useSwitchHousehold } from '../../components/Layout';
import { useLeaveGuard } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { Badge, Loaded, Section, Spinner } from '../../components/ui';
import { useKeepFocus } from '../../components/useKeepFocus';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { localDateOf } from '../../lib/dates';
import { householdName, memberName } from '../../lib/labels';
import { useSession } from '../../session';
import { InviteDialog } from './InviteDialog';

/** The server's name of a person's first household: "My home" to its owner; its owner types a name of their own. */
const DEFAULT_NAME = 'Home';
const MAX_NAME = 100;
const ROLES: readonly HouseholdRole[] = ['Owner', 'Member', 'Helper'];

export function HouseholdSettings() {
  const { current } = useHousehold();
  return (
    <>
      <CurrentHousehold key={current.id} />
      <Households />
    </>
  );
}

/** The household on screen: its settings, people and invites, and leaving it. */
function CurrentHousehold() {
  const { current } = useHousehold();
  const { user } = useSession();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const details = useHouseholdDetails();

  // The role in the newest answer: an owner may have just changed it. The sidebar and the rest of the app follow.
  const answeredRole = details.data?.role;
  useEffect(() => {
    if (answeredRole && answeredRole !== current.role) {
      void queryClient.invalidateQueries({ queryKey: keys.households(user.uid) });
    }
  }, [answeredRole, current.role, queryClient, user.uid]);

  return (
    <Loaded query={details}>
      {(value) => (
        <>
          <GroupSection details={value} api={api} household={household} />
          <Members details={value} api={api} household={household} />
          {value.role === 'Owner' && value.invites.length > 0 && (
            <Invites invites={value.invites} api={api} household={household} />
          )}
          <Leave details={value} api={api} household={household} />
        </>
      )}
    </Loaded>
  );
}

interface Pinned {
  api: ApiClient;
  household: string;
}

/** The time zones this browser knows, and the household's own in any case. */
function timeZones(own: string): string[] {
  let known: string[] = [];
  try {
    known = Intl.supportedValuesOf('timeZone');
  } catch {
    // An older browser: the household's own is the only choice.
  }
  return [...new Set([...known, 'UTC', own])].sort();
}

/** The group's name, the person's role and its size; owners change the name and the time zone. */
function GroupSection({ details, api, household }: { details: HouseholdDetails } & Pinned) {
  const { t } = useI18n();
  const owner = details.role === 'Owner';
  const name = householdName(t, details.name, details.role);
  return (
    <Section title={t.householdLabel}>
      <div className="card group-card">
        <p className="group-card-name">{name}</p>
        <p className="muted small">
          {[t.householdRole[details.role], t.householdMemberCount(details.members.length)].join(' · ')}
        </p>
        {owner ? (
          <GroupForm details={details} api={api} household={household} />
        ) : (
          <dl className="facts">
            <div className="fact">
              <dt>{t.householdTimeZoneLabel}</dt>
              <dd>{details.timeZone}</dd>
            </div>
          </dl>
        )}
      </div>
    </Section>
  );
}

function GroupForm({ details, api, household }: { details: HouseholdDetails } & Pinned) {
  const { t } = useI18n();
  const { user } = useSession();
  const queryClient = useQueryClient();
  const toast = useToast();
  // What the server has: the form compares with it, and starts from it again after a save.
  const [saved, setSaved] = useState({
    name: details.name === DEFAULT_NAME ? '' : details.name,
    timeZone: details.timeZone,
    named: details.name !== DEFAULT_NAME,
  });
  const [name, setName] = useState(saved.name);
  const [timeZone, setTimeZone] = useState(saved.timeZone);
  const [checked, setChecked] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [refused, setRefused] = useState<Record<string, string[]>>({});
  const changed = name.trim() !== saved.name || timeZone !== saved.timeZone;
  useLeaveGuard(changed, busy);
  const zones = timeZones(details.timeZone);

  const nameError =
    name.trim().length > MAX_NAME
      ? t.formTooLong(MAX_NAME)
      : checked && !name.trim() && saved.named
        ? t.householdNameRequired
        : refused.name
          ? t.formServerFieldError
          : null;
  const zoneError = refused.timeZone ? t.formServerFieldError : null;

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setChecked(true);
    setFailure(null);
    setRefused({});
    const typed = name.trim();
    if (typed.length > MAX_NAME || (!typed && saved.named)) return;
    setBusy(true);
    try {
      const answer = await data(
        api.PUT('/api/v1/households/current', {
          body: {
            // Only what changed: null keeps it (the server's "Home" stays until a name is typed).
            name: typed && typed !== saved.name ? typed : null,
            timeZone: timeZone !== saved.timeZone ? timeZone : null,
          },
        }),
      );
      queryClient.setQueryData(keys.householdDetails(household), answer);
      void queryClient.invalidateQueries({ queryKey: keys.households(user.uid) });
      const next = {
        name: answer.name === DEFAULT_NAME ? '' : answer.name,
        timeZone: answer.timeZone,
        named: answer.name !== DEFAULT_NAME,
      };
      setSaved(next);
      setName(next.name);
      setTimeZone(next.timeZone);
      setChecked(false);
      toast(t.householdSaved);
    } catch (error) {
      const fields = fieldErrorsOf(error);
      setRefused(fields);
      setFailure(fields.name || fields.timeZone ? t.formCheckFields : householdErrorMessage(t, error));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="form-stack" noValidate onSubmit={(event) => void save(event)} aria-busy={busy || undefined}>
      <TextField
        label={t.householdNameLabel}
        placeholder={householdName(t, details.name, details.role)}
        value={name}
        onChange={setName}
        error={nameError}
      />
      <SelectField
        label={t.householdTimeZoneLabel}
        value={timeZone}
        options={zones.map((zone) => ({ value: zone, label: zone.replaceAll('_', ' ') }))}
        onChange={setTimeZone}
        hint={
          details.timeZoneSetByHand
            ? t.householdTimeZoneHint
            : `${t.householdTimeZoneHint} ${t.householdTimeZoneFollows}`
        }
        error={zoneError}
      />
      {failure && (
        <p className="form-error" role="alert">
          <Icon name="error" size={18} />
          {failure}
        </p>
      )}
      <button type="submit" className="button button--secondary align-start" disabled={busy || !changed}>
        {busy && <Spinner />}
        {busy ? t.commonSaving : t.commonSave}
      </button>
    </form>
  );
}

/** The people in the order they joined, with their roles; owners change roles, invite and remove. */
function Members({ details, api, household }: { details: HouseholdDetails } & Pinned) {
  const { t } = useI18n();
  const owner = details.role === 'Owner';
  const [inviting, setInviting] = useState(false);
  const [changing, setChanging] = useState<HouseholdMember | null>(null);
  const [removing, setRemoving] = useState<HouseholdMember | null>(null);
  // Someone removed: the focus goes to the person now in their place.
  const list = useRef<HTMLUListElement>(null);
  useKeepFocus(list);

  return (
    <Section
      title={t.householdMembers}
      action={
        owner && (
          <button type="button" className="button button--secondary" onClick={() => setInviting(true)}>
            <Icon name="person_add" size={18} />
            {t.householdInvite}
          </button>
        )
      }
    >
      <ul className="card card--list rows" ref={list}>
        {details.members.map((member) => {
          const name = memberName(t, member);
          const about = [
            member.displayName?.trim() && member.email ? member.email : null,
            member.isMe ? t.householdYou : null,
          ];
          return (
            <li key={member.userId} className="row">
              <span className="type-icon type-icon--muted">
                <Icon name="person" />
              </span>
              <div className="row-main">
                <span className="row-title">{name}</span>
                {about.some(Boolean) && <span className="row-sub">{about.filter(Boolean).join(' · ')}</span>}
              </div>
              <div className="row-actions">
                <Badge>{t.householdRole[member.role]}</Badge>
                {owner && (
                  <button
                    type="button"
                    className="button button--secondary"
                    aria-label={t.householdChangeRoleFor(name)}
                    onClick={() => setChanging(member)}
                  >
                    {t.householdChangeRole}
                  </button>
                )}
                {owner && !member.isMe && (
                  <button
                    type="button"
                    className="button button--ghost button--danger-text"
                    aria-label={t.householdMemberRemoveFor(name)}
                    onClick={() => setRemoving(member)}
                  >
                    {t.householdMemberRemoveConfirm}
                  </button>
                )}
              </div>
            </li>
          );
        })}
      </ul>
      {inviting && <InviteDialog api={api} household={household} invite={null} onClose={() => setInviting(false)} />}
      {changing && <RoleDialog member={changing} api={api} household={household} onClose={() => setChanging(null)} />}
      {removing && <RemoveDialog member={removing} api={api} household={household} onClose={() => setRemoving(null)} />}
    </Section>
  );
}

/** Reads the household's people and the person's households again: a role or the people changed. */
function useRefreshPeople(household: string) {
  const queryClient = useQueryClient();
  const { user } = useSession();
  return () => {
    void queryClient.invalidateQueries({ queryKey: keys.householdDetails(household) });
    void queryClient.invalidateQueries({ queryKey: keys.households(user.uid) });
  };
}

/** A person's role, each with what it may do. An owner stepping down is asked first. */
function RoleDialog({ member, api, household, onClose }: { member: HouseholdMember; onClose: () => void } & Pinned) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const refresh = useRefreshPeople(household);
  const [role, setRole] = useState(member.role);
  const [asking, setAsking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const group = useId();

  async function save() {
    if (role === member.role) {
      onClose();
      return;
    }
    // No more inviting or changing roles, and their open invites stop working: one click shouldn't do that.
    if (member.isMe && member.role === 'Owner' && !asking) {
      setAsking(true);
      return;
    }
    setAsking(false);
    setBusy(true);
    setFailure(null);
    try {
      const answer = await data(
        api.PUT('/api/v1/households/current/members/{userId}', {
          params: { path: { userId: member.userId } },
          body: { role },
        }),
      );
      queryClient.setQueryData(keys.householdDetails(household), answer);
      refresh();
      onClose();
    } catch (error) {
      refresh();
      setFailure(householdErrorMessage(t, error));
      setBusy(false);
    }
  }

  return (
    <Dialog title={memberName(t, member)} onClose={onClose} busy={busy} changed={role !== member.role}>
      <DialogForm onSubmit={() => void save()} busy={busy}>
        <DialogBody>
          <fieldset className="role-choices">
            <legend className="field-label">{t.householdRoleLabel}</legend>
            {ROLES.map((each) => (
              <label key={each} className="role-choice">
                <input
                  type="radio"
                  name={group}
                  value={each}
                  checked={role === each}
                  aria-labelledby={`${group}-${each}-name`}
                  aria-describedby={`${group}-${each}`}
                  onChange={() => setRole(each)}
                />
                <span className="role-choice-text">
                  <span className="role-choice-name" id={`${group}-${each}-name`}>
                    {t.householdRole[each]}
                  </span>
                  <span className="muted small" id={`${group}-${each}`}>
                    {t.householdRoleHelp[each]}
                  </span>
                </span>
              </label>
            ))}
          </fieldset>
        </DialogBody>
        <DialogFoot>
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <DialogCancel disabled={busy} />
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {busy ? t.commonSaving : t.commonSave}
          </button>
        </DialogFoot>
      </DialogForm>
      {asking && (
        <ConfirmDialog
          title={t.householdStepDownTitle}
          body={t.householdStepDownBody}
          confirmLabel={t.householdStepDownConfirm}
          danger
          onConfirm={() => void save()}
          onCancel={() => setAsking(false)}
        />
      )}
    </Dialog>
  );
}

/** "Remove from the group?": they stop seeing its pets; their marks stay. */
function RemoveDialog({ member, api, household, onClose }: { member: HouseholdMember; onClose: () => void } & Pinned) {
  const { t } = useI18n();
  const refresh = useRefreshPeople(household);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  async function remove() {
    setBusy(true);
    setFailure(null);
    try {
      await api.DELETE('/api/v1/households/current/members/{userId}', {
        params: { path: { userId: member.userId } },
      });
      refresh();
      onClose();
    } catch (error) {
      refresh();
      // Gone already (they left, or another owner removed them): what was wanted.
      if (isNotFound(error)) {
        onClose();
        return;
      }
      setFailure(householdErrorMessage(t, error));
      setBusy(false);
    }
  }

  return (
    <ConfirmDialog
      title={t.householdMemberRemoveTitle}
      body={t.householdMemberRemoveBody(memberName(t, member))}
      confirmLabel={t.householdMemberRemoveConfirm}
      danger
      busy={busy}
      error={
        failure && (
          <p className="form-error" role="alert">
            <Icon name="error" size={18} />
            {failure}
          </p>
        )
      }
      onConfirm={() => void remove()}
      onCancel={onClose}
    />
  );
}

/** The codes nobody has used yet: each shows again with its link; "Revoke" takes it back. Owners only. */
function Invites({ invites, api, household }: { invites: HouseholdInvite[] } & Pinned) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const refresh = useRefreshPeople(household);
  const [showing, setShowing] = useState<HouseholdInvite | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const list = useRef<HTMLUListElement>(null);
  useKeepFocus(list);

  async function revoke(invite: HouseholdInvite) {
    setBusy(invite.id);
    try {
      await api.DELETE('/api/v1/households/current/invites/{id}', { params: { path: { id: invite.id } } });
      toast(t.householdInviteRevoked);
    } catch (error) {
      // Used or taken back meanwhile: it doesn't work any more either way.
      if (!isNotFound(error)) toast(householdErrorMessage(t, error));
    } finally {
      setBusy(null);
      refresh();
    }
  }

  return (
    <Section title={t.householdInvites}>
      <ul className="card card--list rows" ref={list}>
        {invites.map((invite) => (
          <li key={invite.id} className="row">
            <span className="type-icon type-icon--muted">
              <Icon name="vpn_key" />
            </span>
            <div className="row-main">
              <button
                type="button"
                className="row-title row-link row-button invite-row-code"
                onClick={() => setShowing(invite)}
              >
                {invite.code}
              </button>
              <span className="row-sub">
                {[t.householdRole[invite.role], t.householdInviteUntil(i18n.date(localDateOf(invite.expiresAt)))].join(
                  ' · ',
                )}
              </span>
            </div>
            <div className="row-actions">
              {busy === invite.id ? (
                <Spinner />
              ) : (
                <button
                  type="button"
                  className="button button--ghost"
                  aria-label={t.householdInviteRevokeFor(invite.code)}
                  onClick={() => void revoke(invite)}
                >
                  {t.householdInviteRevoke}
                </button>
              )}
            </div>
          </li>
        ))}
      </ul>
      {showing && <InviteDialog api={api} household={household} invite={showing} onClose={() => setShowing(null)} />}
    </Section>
  );
}

/** Leaving the group (the pets and records stay), or, alone in it as its owner, deleting it. */
function Leave({ details, api, household }: { details: HouseholdDetails } & Pinned) {
  const { t } = useI18n();
  const { households, switchTo, leftHere } = useHousehold();
  const { user } = useSession();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [asking, setAsking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const alone = details.members.length === 1;
  const owner = details.role === 'Owner';
  const me = details.members.find((member) => member.isMe);
  const name = householdName(t, details.name, details.role);
  if (alone && !owner) return null;
  const deleting = alone;

  async function go() {
    setBusy(true);
    setFailure(null);
    try {
      if (deleting) await api.DELETE('/api/v1/households/current');
      else if (me) {
        await api.DELETE('/api/v1/households/current/members/{userId}', { params: { path: { userId: me.userId } } });
      }
    } catch (error) {
      setFailure(householdErrorMessage(t, error));
      setBusy(false);
      return;
    }
    // The next household of the person's is on screen from now on. Without one, the server makes them a new one, and
    // the app moves there by itself. Either way the word is this one's, not "You're no longer in it".
    leftHere(household);
    const rest = households.filter((each) => each.id !== household);
    if (rest[0]) {
      switchTo(rest[0].id);
      queryClient.setQueryData(keys.households(user.uid), rest);
    }
    toast(deleting ? t.householdDeleted(name) : t.householdLeftSelf(name));
    void queryClient.invalidateQueries({ queryKey: keys.households(user.uid) });
  }

  return (
    <div className="leave-group">
      <button
        type="button"
        className="button button--ghost button--danger-text"
        onClick={() => setAsking(true)}
        disabled={busy}
      >
        <Icon name={deleting ? 'delete' : 'logout'} />
        {deleting ? t.householdDelete : t.householdLeave}
      </button>
      {asking && (
        <ConfirmDialog
          title={deleting ? t.householdDeleteTitle(name) : t.householdLeaveTitle(name)}
          body={deleting ? t.householdDeleteBody : t.householdLeaveBody}
          confirmLabel={deleting ? t.commonDelete : t.householdLeaveConfirm}
          danger
          busy={busy}
          error={
            failure && (
              <p className="form-error" role="alert">
                <Icon name="error" size={18} />
                {failure}
              </p>
            )
          }
          onConfirm={() => void go()}
          onCancel={() => {
            setAsking(false);
            setFailure(null);
          }}
        />
      )}
    </div>
  );
}

/** The person's groups with their role and size: another one opens with "Switch"; join one with a code, or create one. */
function Households() {
  const { t } = useI18n();
  const { current, households } = useHousehold();
  const switchHousehold = useSwitchHousehold();
  const toast = useToast();
  const [creating, setCreating] = useState(false);
  // A group just created, on its way to the screen: said once it is there (a page with typed input may stop the move).
  const [opening, setOpening] = useState<HouseholdSummary | null>(null);
  useEffect(() => {
    if (!opening || current.id !== opening.id) return;
    toast(t.householdSwitched(opening.name));
    setOpening(null);
  }, [opening, current.id, toast, t]);
  return (
    <Section
      title={t.householdGroups}
      action={
        <>
          <Link to="/join" className="button button--secondary">
            <Icon name="vpn_key" size={18} />
            {t.householdJoin}
          </Link>
          <button type="button" className="button button--secondary" onClick={() => setCreating(true)}>
            <Icon name="add" size={18} />
            {t.householdCreate}
          </button>
        </>
      }
    >
      <ul className="card card--list rows">
        {households.map((each) => {
          const name = householdName(t, each.name, each.role);
          return (
            <li key={each.id} className="row">
              <span className={`type-icon${each.id === current.id ? '' : ' type-icon--muted'}`}>
                <Icon name="home" />
              </span>
              <div className="row-main">
                <span className="row-title">{name}</span>
                <span className="row-sub">
                  {[t.householdRole[each.role], t.householdMemberCount(each.memberCount)].join(' · ')}
                </span>
              </div>
              <div className="row-actions">
                {each.id === current.id ? (
                  <Badge>
                    <Icon name="check" size={16} />
                    {t.householdCurrent}
                  </Badge>
                ) : (
                  <button
                    type="button"
                    className="button button--secondary"
                    aria-label={t.householdSwitchTo(name)}
                    onClick={() => switchHousehold(each.id)}
                  >
                    <Icon name="swap_horiz" size={18} />
                    {t.householdSwitch}
                  </button>
                )}
              </div>
            </li>
          );
        })}
      </ul>
      {creating && <CreateDialog onClose={() => setCreating(false)} onCreated={setOpening} />}
    </Section>
  );
}

/** "New group": its name; the person becomes its owner, and it opens. */
function CreateDialog({ onClose, onCreated }: { onClose: () => void; onCreated: (made: HouseholdSummary) => void }) {
  const { t } = useI18n();
  const { user } = useSession();
  const api = useApi();
  const queryClient = useQueryClient();
  const switchHousehold = useSwitchHousehold();
  const [name, setName] = useState('');
  const [checked, setChecked] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [created, setCreated] = useState<HouseholdSummary | null>(null);
  const typed = name.trim();
  const error = typed.length > MAX_NAME ? t.formTooLong(MAX_NAME) : checked && !typed ? t.householdNameRequired : null;

  // Created: once the dialog holds nothing to lose (the frame has heard so), the new group opens. The list says so
  // when it is on screen.
  const open = useEffectEvent((made: HouseholdSummary) => {
    onClose();
    onCreated(made);
    switchHousehold(made.id);
  });
  useEffect(() => {
    if (created) open(created);
  }, [created]);

  async function create() {
    setChecked(true);
    setFailure(null);
    if (!typed || typed.length > MAX_NAME) return;
    setBusy(true);
    try {
      const made = await data(api.POST('/api/v1/households', { body: { name: typed } }));
      // In the list before it is on screen: a household not in the list would be left at once.
      queryClient.setQueryData(keys.households(user.uid), (old: HouseholdSummary[] | undefined) => [
        ...(old ?? []).filter((each) => each.id !== made.id),
        made,
      ]);
      void queryClient.invalidateQueries({ queryKey: keys.households(user.uid) });
      setCreated(made);
    } catch (failed) {
      setFailure(householdErrorMessage(t, failed));
      setBusy(false);
    }
  }

  return (
    <Dialog
      title={t.householdCreateTitle}
      onClose={onClose}
      busy={busy && !created}
      changed={typed.length > 0 && !created}
    >
      <DialogForm onSubmit={() => void create()} busy={busy}>
        <DialogBody>
          <TextField
            label={t.householdNameLabel}
            placeholder={t.householdNameHint}
            value={name}
            onChange={setName}
            error={error}
          />
        </DialogBody>
        <DialogFoot>
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <DialogCancel disabled={busy} />
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {t.householdCreateAction}
          </button>
        </DialogFoot>
      </DialogForm>
    </Dialog>
  );
}
