// Deleting the account (spec, "Удаление аккаунта"; the phone app's delete_account_screen.dart): what happens to each
// of the person's groups (GET /me/deletion: deleted with its pets, kept by the others, or handed over to a member;
// helpers left alone lose it), what is deleted and what stays, the data to download first; then the person ticks that
// they understood, types their password again (Firebase's reauthentication, so the sign-in token says it was typed a
// moment ago, as the server wants) and deletes: DELETE /me?plan=<the fingerprint of the fates shown>.
//
// The server deletes only while the fates are the ones shown, and the page sends only the fates the person ticked
// "I understand" for: when someone joined, left or became an owner meanwhile (409 deletion-plan-changed, or a new
// picture read before deleting, by a live update or a reload), the page says that something changed, shows the groups
// anew, and the tick goes: she ticks again for what she sees now. A password typed too long ago (403
// recent-sign-in-required) is asked for again. A deletion whose answer got lost is checked before the next try: the
// server answers "account deleted" when it went through, and the app signs out. Afterwards the app signs out (and
// forgets the account's household), and the sign-in page says the account was deleted.
import { useEffect, useRef, useState, type FormEvent } from 'react';
import { ApiError, ProblemTypes } from '../../api/client';
import { errorMessage } from '../../api/errors';
import { useDeletionPreview } from '../../api/queries';
import type { DeletionPreview, HouseholdOutcome } from '../../api/types';
import { reauthErrorKey } from '../../auth/auth';
import { CheckboxField, TextField, useFocusFirstError } from '../../components/fields';
import { Icon } from '../../components/Icon';
import type { IconName } from '../../components/icons';
import { useLeaveGuard } from '../../components/LeaveGuard';
import { ErrorNotice, Loading, Notice, PageHead, Section, Spinner } from '../../components/ui';
import type { Messages } from '../../i18n/en';
import { useI18n } from '../../i18n/i18n';
import { householdName } from '../../lib/labels';
import { useSession } from '../../session';
import { ExportData } from './SettingsPage';

/** What deleting the account does to a household, in a sentence or two. */
export function householdFateLines(t: Messages, household: HouseholdOutcome): string[] {
  switch (household.fate) {
    case 'Kept':
      return [t.deleteAccountFateKept];
    case 'HandedOver':
      return [household.newOwner ? t.deleteAccountFateHandedOver(household.newOwner) : t.deleteAccountFateHandedOverUnnamed];
    default:
      // A fate this app doesn't know (a newer server) is told as the gravest: better to warn of a deletion that won't
      // happen than to miss one.
      return [
        t.deleteAccountFateDeleted(household.pets),
        // The others there are helpers: only members and owners keep a group.
        ...(household.others > 0 ? [t.deleteAccountFateDeletedHelpers] : []),
      ];
  }
}

/** The groups that go with the account, by name ("My home" for the server's "Home"), and that it can't be undone. */
export function deletionConfirmText(t: Messages, households: readonly HouseholdOutcome[]): string {
  const names = households
    .filter((household) => household.fate !== 'Kept' && household.fate !== 'HandedOver')
    .map((household) => t.quotedName(householdName(t, household.name, household.role)));
  const joined = names.length < 2 ? names.join('') : t.namesAnd(names.slice(0, -1).join(', '), names.at(-1)!);
  return t.deleteAccountConfirmBody(names.length, joined);
}

export function DeleteAccountPage() {
  const { t } = useI18n();
  const session = useSession();
  const preview = useDeletionPreview();
  // The fates shown: the first picture, then each one shown with "something changed". Another picture read (a live
  // update, a reload) is a change she is told about.
  const [seen, setSeen] = useState<string | null>(null);
  // The fates she ticked "I understand" for: the deletion sends them. Another picture unticks.
  const [confirmed, setConfirmed] = useState<string | null>(null);
  const [changed, setChanged] = useState(false);
  // Grows with every "something changed": the page goes up to it.
  const [changes, setChanges] = useState(0);
  const [password, setPassword] = useState('');
  const [submitted, setSubmitted] = useState(false);
  // Grows with every try that misses the tick or the password: the first of them takes the focus.
  const [attempts, setAttempts] = useState(0);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  // The last deletion got no answer: it may have gone through. The next try asks the server first.
  const outcomeUnknown = useRef(false);
  const form = useRef<HTMLFormElement>(null);
  // Not while the deletion runs: its end signs out, or says here what went wrong.
  useLeaveGuard(false, busy);
  useFocusFirstError(form, attempts);

  const shown = preview.data;
  /** "Something changed in your groups", with the groups now in view: the tick goes, and she ticks again. */
  function showChanged(now: DeletionPreview | undefined) {
    setChanged(true);
    setConfirmed(null);
    setSubmitted(false);
    setChanges((count) => count + 1);
    if (now) setSeen(now.plan);
  }
  if (shown && !preview.isFetching) {
    if (seen === null) setSeen(shown.plan);
    else if (shown.plan !== seen) showChanged(shown);
  }
  const understood = confirmed !== null && confirmed === shown?.plan;

  useEffect(() => {
    if (changes > 0) window.scrollTo({ top: 0, behavior: 'smooth' });
  }, [changes]);

  async function remove(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    // Not while a try runs or the groups load anew.
    if (busy || preview.isFetching) return;
    setSubmitted(true);
    setFailure(null);
    // A word of a change said before goes: what follows says what holds now.
    setChanged(false);
    if (!understood || !password) {
      setAttempts((count) => count + 1);
      return;
    }
    setBusy(true);
    try {
      let now: DeletionPreview | undefined = shown;
      if (outcomeUnknown.current) {
        // A deletion that went through makes the server answer "account deleted": the app signs out by itself.
        const fresh = await preview.refetch();
        if (fresh.error) {
          setFailure(errorMessage(t, fresh.error));
          return;
        }
        outcomeUnknown.current = false;
        now = fresh.data;
      }
      if (!now) return;
      // Only the fates she ticked for: any other picture is shown first.
      if (now.plan !== confirmed) {
        showChanged(now);
        return;
      }
      try {
        await session.reauthenticate(password);
      } catch (error) {
        const key = reauthErrorKey(error);
        if (key === 'deleteAccountWrongPassword') setPassword('');
        setFailure(t[key]);
        return;
      }
      try {
        await session.api.forHousehold(null).DELETE('/api/v1/me', { params: { query: { plan: confirmed } } });
      } catch (error) {
        if (!(error instanceof ApiError)) throw error;
        // Deleted already (a try whose answer was lost): the app signs out by itself, and says why.
        if (error.status === 401) return;
        if (error.type === ProblemTypes.deletionPlanChanged) {
          // Nothing was deleted: the groups show anew, and the person ticks again.
          showChanged(undefined);
          void preview.refetch();
          return;
        }
        if (error.type === ProblemTypes.recentSignInRequired) {
          // The password again: an empty field, and no "Enter your password" under it until the next try.
          setPassword('');
          setSubmitted(false);
          setFailure(t.deleteAccountPasswordAgain);
          return;
        }
        outcomeUnknown.current = error.status === 0 || error.status >= 500;
        setFailure(errorMessage(t, error));
        // What the server says about the groups now.
        void preview.refetch();
        return;
      }
      // Gone on the server: the app signs out (and this browser forgets the account's household).
      session.signOut('account-deleted');
    } catch (error) {
      setFailure(errorMessage(t, error));
    } finally {
      setBusy(false);
    }
  }

  const head = <PageHead back={{ to: '/settings', label: t.settingsTitle }} title={t.deleteAccountTitle} />;
  if (!shown) {
    return (
      <>
        {head}
        {preview.error ? <ErrorNotice error={preview.error} onRetry={() => void preview.refetch()} /> : <Loading />}
      </>
    );
  }
  return (
    <>
      {head}
      <div className="delete-account">
        <Notice tone="warning">
          <p>{t.deleteAccountWarning}</p>
        </Notice>
        {changed && (
          <Notice tone="warning">
            <p>{t.deleteAccountPlanChanged}</p>
          </Notice>
        )}
        {shown.households.length > 0 && (
          <Section title={t.deleteAccountGroups}>
            <ul className="card card--list rows">
              {shown.households.map((household) => (
                <Outcome key={household.id} household={household} />
              ))}
            </ul>
          </Section>
        )}
        <Section title={t.deleteAccountGoes}>
          <ul className="card plain-list facts-list">
            <Fact icon="person">{t.deleteAccountGoesAccount}</Fact>
            <Fact icon="home">{t.deleteAccountGoesGroups}</Fact>
            <Fact icon="vpn_key">{t.deleteAccountGoesSignIn}</Fact>
          </ul>
        </Section>
        <Section title={t.deleteAccountStays}>
          <ul className="card plain-list facts-list">
            <Fact icon="group">{t.deleteAccountStaysRecords}</Fact>
            <Fact icon="schedule">{t.deleteAccountStaysBackups}</Fact>
            <Fact icon="document_scanner">{t.deleteAccountStaysAiPhotos}</Fact>
          </ul>
        </Section>
        <Section title={t.deleteAccountExportFirst}>
          <div className="card settings-card">
            <ExportData />
          </div>
        </Section>
        <form
          ref={form}
          className="form-stack delete-account-form"
          noValidate
          onSubmit={(event) => void remove(event)}
          aria-busy={busy || undefined}
        >
          <p>{deletionConfirmText(t, shown.households)}</p>
          <fieldset className="form-stack" disabled={busy}>
            <CheckboxField
              label={t.deleteAccountUnderstood}
              checked={understood}
              // Ticked for the fates on screen, and only for those.
              onChange={(ticked) => setConfirmed(ticked ? shown.plan : null)}
              error={submitted && !understood ? t.deleteAccountUnderstoodRequired : null}
            />
            <TextField
              label={t.passwordLabel}
              hint={t.deleteAccountPasswordHelper}
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={setPassword}
              error={submitted && !password ? t.passwordRequired : null}
            />
          </fieldset>
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <button type="submit" className="button button--danger align-start" disabled={busy || preview.isFetching}>
            {busy && <Spinner />}
            {busy ? t.deleteAccountDeleting : t.deleteAccountTitle}
          </button>
        </form>
      </div>
    </>
  );
}

/** One of the person's groups and what deleting the account does to it. */
function Outcome({ household }: { household: HouseholdOutcome }) {
  const { t } = useI18n();
  const deleted = household.fate !== 'Kept' && household.fate !== 'HandedOver';
  return (
    <li className="row row--top">
      <span className={`kind-icon${deleted ? ' kind-icon--danger' : ''}`} aria-hidden="true">
        <Icon name={deleted ? 'delete' : 'home'} />
      </span>
      <div className="row-main">
        <span className="row-title">{householdName(t, household.name, household.role)}</span>
        <span className="row-sub">{t.householdRole[household.role]}</span>
        <span className={deleted ? 'danger-text small' : 'row-sub'}>{householdFateLines(t, household).join(' ')}</span>
      </div>
    </li>
  );
}

function Fact({ icon, children }: { icon: IconName; children: string }) {
  return (
    <li className="fact-line">
      <Icon name={icon} className="muted" />
      <span>{children}</span>
    </li>
  );
}
