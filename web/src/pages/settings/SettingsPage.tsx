// Settings (the phone app's More screen, its plan and AI screens): the profile (the name others see; this browser's
// language, as the sidebar's; the phone's time zone, which only the phone app sets); the theme of this browser; the
// group on screen and the person's groups (household/HouseholdSettings); the group's plan and this month's AI photos;
// whether AI reads photos; where reminders come (the phone app); help ("Getting to know the app" again); downloading
// one's data; and deleting the account (a page of its own: DeleteAccountPage). The web never sends the profile's
// language or time zone: they are the phone's.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Link } from 'react-router';
import { data } from '../../api/client';
import { downloadExport, saveFile } from '../../api/export';
import { errorMessage, exportErrorMessage, fieldErrorsOf } from '../../api/errors';
import { keys } from '../../api/keys';
import { useAiStatus, useMe, usePlan } from '../../api/queries';
import { ActionCard } from '../../components/ActionCard';
import { ChoiceGroup, TextField } from '../../components/fields';
import { fileSizeLabel } from '../../components/Files';
import { Icon } from '../../components/Icon';
import { useLeaveGuard } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loaded, Notice, PageHead, Section, Spinner } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { LANGS } from '../../i18n/lang';
import { localDateOf } from '../../lib/dates';
import { householdName } from '../../lib/labels';
import { useSession } from '../../session';
import { THEMES, useTheme } from '../../theme';
import { HouseholdSettings } from './HouseholdSettings';

export function SettingsPage() {
  const { t } = useI18n();
  return (
    <>
      <PageHead title={t.settingsTitle} />
      <div className="settings">
        <div className="settings-column">
          <Profile />
          <Theme />
          <HouseholdSettings />
        </div>
        <div className="settings-column">
          <PlanSection />
          <AiSection />
          <Section title={t.notificationsTitle}>
            <p className="with-icon align-start">
              <Icon name="smartphone" />
              {t.notificationsOnPhone}
            </p>
          </Section>
          <Section title={t.settingsHelp}>
            <ActionCard icon="waving_hand" title={t.welcomeTitle} hint={t.welcomeHint} to="/welcome" />
          </Section>
          <YourData />
        </div>
      </div>
    </>
  );
}

const MAX_NAME = 100;

/** The name others see next to the person's marks; the language of this browser; the phone's time zone. */
function Profile() {
  const { t, lang, choose } = useI18n();
  const { user } = useSession();
  const api = useApi();
  const me = useMe();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [saved, setSaved] = useState(me.data.displayName ?? '');
  const [name, setName] = useState(saved);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [refused, setRefused] = useState(false);
  const changed = name.trim() !== saved;
  useLeaveGuard(changed, busy);
  const nameError = name.trim().length > MAX_NAME ? t.formTooLong(MAX_NAME) : refused ? t.formServerFieldError : null;

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || name.trim().length > MAX_NAME) return;
    setBusy(true);
    setFailure(null);
    setRefused(false);
    try {
      // Only the name: the language and the time zone are the phone's (null keeps them).
      const answer = await data(
        api.PUT('/api/v1/me', { body: { displayName: name.trim(), locale: null, timeZone: null } }),
      );
      queryClient.setQueryData(keys.me(user.uid), answer);
      // The groups' lists of people show the name.
      void queryClient.invalidateQueries({ predicate: (query) => query.queryKey[1] === 'household' });
      setSaved(answer.displayName ?? '');
      setName(answer.displayName ?? '');
      toast(t.profileNameSaved);
    } catch (error) {
      const placed = !!fieldErrorsOf(error).displayName;
      setRefused(placed);
      setFailure(placed ? t.formCheckFields : errorMessage(t, error));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Section title={t.settingsProfile}>
      <div className="card settings-card">
        <p className="account-email">
          <span className="muted small">{t.signedInAs}</span>
          <span>{me.data.email ?? user.email}</span>
        </p>
        <form className="form-stack" noValidate onSubmit={(event) => void save(event)} aria-busy={busy || undefined}>
          <TextField
            label={t.profileNameLabel}
            hint={t.profileNameHint}
            value={name}
            autoComplete="name"
            onChange={setName}
            error={nameError}
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
        <ChoiceGroup
          label={t.languageLabel}
          value={lang}
          options={LANGS.map((option) => ({ value: option, label: t.languageNames[option] }))}
          onChange={choose}
          hint={t.profileLanguageHint}
        />
        <dl className="facts">
          <div className="fact">
            <dt>{t.profileTimeZoneLabel}</dt>
            <dd>
              {me.data.timeZone}
              <span className="field-hint">{t.profileTimeZoneHint}</span>
            </dd>
          </div>
        </dl>
      </div>
    </Section>
  );
}

/** The system's theme, or light or dark, for this browser. */
function Theme() {
  const { t } = useI18n();
  const [theme, choose] = useTheme();
  return (
    <Section title={t.settingsTheme}>
      <ChoiceGroup
        label={t.settingsTheme}
        labelHidden
        value={theme}
        options={THEMES.map((option) => ({
          value: option,
          label: t.themeNames[option],
          icon: (
            <Icon
              name={option === 'dark' ? 'dark_mode' : option === 'light' ? 'light_mode' : 'brightness_auto'}
              size={18}
            />
          ),
        }))}
        onChange={choose}
        hint={t.themeHint}
      />
    </Section>
  );
}

/** The group's plan, until when, this month's AI photos and when they count from zero; what Premium gives. */
function PlanSection() {
  const i18n = useI18n();
  const { t } = i18n;
  const { current } = useHousehold();
  const plan = usePlan();
  return (
    <Section title={t.planTitle}>
      <Loaded query={plan}>
        {(value) => {
          const premium = value.plan === 'Premium';
          const usedUp = value.aiPhotosUsed >= value.aiPhotosPerMonth;
          const share = value.aiPhotosPerMonth > 0 ? Math.min(1, value.aiPhotosUsed / value.aiPhotosPerMonth) : 1;
          return (
            <div className="card settings-card">
              <p className="muted small">{t.planOf(householdName(t, current.name, current.role))}</p>
              <p className="plan-name with-icon">
                <Icon name="workspace_premium" className={premium ? 'plan-icon--premium' : 'plan-icon'} />
                {t.planKind[value.plan]}
              </p>
              {premium && (
                <p className="small">
                  {value.expiresAt ? t.planUntil(i18n.date(localDateOf(value.expiresAt))) : t.planNoEnd}
                </p>
              )}
              <div className="plan-photos">
                <p className="field-label">{t.planAiPhotos}</p>
                <p className="plan-photos-count">{t.planAiPhotosUsed(value.aiPhotosUsed, value.aiPhotosPerMonth)}</p>
                {/* The words above say it; the bar only shows it. */}
                <div className={`level${usedUp ? ' level--full' : ''}`} aria-hidden="true">
                  <span style={{ width: `${Math.round(share * 100)}%` }} />
                </div>
                {usedUp && <p>{t.planAiPhotosUsedUp}</p>}
                <p className="small">{t.planResetsOn(i18n.date(localDateOf(value.resetsAt)))}</p>
                <p className="muted small">{t.planAiPhotosHelp}</p>
              </div>
              {!premium && <p className="small">{t.planPremiumAiPhotos(value.premiumAiPhotosPerMonth)}</p>}
              <Notice>{t.planPaymentsNote}</Notice>
            </div>
          );
        }}
      </Loaded>
    </Section>
  );
}

/** Whether the server reads photos with AI; that happens in the phone app. Read only. */
function AiSection() {
  const { t } = useI18n();
  const status = useAiStatus();
  return (
    <Section title={t.aiTitle}>
      <Loaded query={status}>
        {(value) => (
          <div className="card settings-card">
            <p className="with-icon align-start ai-status">
              <Icon name={value.configured ? 'check_circle' : 'info'} className={value.configured ? 'ok-icon' : ''} />
              <span>
                <span className="ai-status-word">{value.configured ? t.aiConnected : t.aiNotConnected}</span>
                <span className="muted small">{value.configured ? t.aiConnectedBody : t.aiNotConnectedBody}</span>
              </span>
            </p>
            {value.freeTier && <Notice tone="warning">{t.aiFreeTierWarning}</Notice>}
          </div>
        )}
      </Loaded>
    </Section>
  );
}

/**
 * "Download my data" and deleting the account: its own page, which shows first what happens to each group. The
 * site's page about it stays for those who sign in on the phone without a password.
 */
function YourData() {
  const { t, lang } = useI18n();
  return (
    <Section title={t.yourDataTitle}>
      <div className="card settings-card">
        <ExportData />
        <div className="settings-part">
          <h3 className="settings-part-title">{t.deleteAccountTitle}</h3>
          <p>{t.deleteAccountSettingsBody}</p>
          <Link to="/settings/delete-account" className="button button--secondary button--danger-text align-start">
            <Icon name="delete" />
            {t.deleteAccountOpen}
          </Link>
          <p className="small muted">
            {t.deleteAccountNoPassword}{' '}
            <a href={lang === 'ru' ? '/ru/delete-account/' : '/delete-account/'}>{t.deleteAccountLink}</a>
          </p>
        </div>
      </div>
    </Section>
  );
}

type Download =
  | { step: 'idle' }
  | { step: 'downloading'; received: number }
  | { step: 'ready'; url: string; name: string; size: number }
  | { step: 'failed'; error: unknown };

/**
 * The ZIP of everything of the person's, saved as the file the server names. The bytes so far show while it comes
 * (the server doesn't know the total); "Cancel", or leaving the page, stops it. A few an hour: the server's limit is
 * said with how long to wait.
 */
export function ExportData() {
  const i18n = useI18n();
  const { t } = i18n;
  const api = useApi();
  const [state, setState] = useState<Download>({ step: 'idle' });
  const download = useRef<AbortController | null>(null);

  // Leaving the page stops the download.
  useEffect(() => () => download.current?.abort(), []);
  // The file made in this browser goes when it isn't offered any more.
  const url = state.step === 'ready' ? state.url : null;
  useEffect(() => {
    if (!url) return;
    return () => URL.revokeObjectURL(url);
  }, [url]);

  async function start() {
    download.current?.abort();
    const controller = new AbortController();
    download.current = controller;
    setState({ step: 'downloading', received: 0 });
    try {
      const file = await downloadExport(
        api,
        (received) => {
          if (!controller.signal.aborted) setState({ step: 'downloading', received });
        },
        controller.signal,
      );
      if (controller.signal.aborted) return;
      const made = URL.createObjectURL(file.blob);
      saveFile(made, file.name);
      setState({ step: 'ready', url: made, name: file.name, size: file.blob.size });
    } catch (error) {
      if (!controller.signal.aborted) setState({ step: 'failed', error });
    }
  }

  function cancel() {
    download.current?.abort();
    setState({ step: 'idle' });
  }

  return (
    <div className="settings-part">
      <h3 className="settings-part-title">{t.dataExportTitle}</h3>
      <p className="muted small">{t.dataExportHelper}</p>
      <div aria-live="polite" className="export-state">
        {state.step === 'downloading' && (
          <>
            <p className="loading-inline">
              <Spinner />
              {state.received === 0 ? t.dataExportPreparing : t.dataExportProgress(fileSizeLabel(i18n, state.received))}
            </p>
            <p className="muted small">{t.dataExportStay}</p>
          </>
        )}
        {state.step === 'ready' && (
          <Notice tone="ok">
            <p>{t.dataExportReady(fileSizeLabel(i18n, state.size), state.name)}</p>
            <p className="small">{t.dataExportKeepSafe}</p>
            <a href={state.url} download={state.name}>
              {t.dataExportSaveAgain}
            </a>
          </Notice>
        )}
        {state.step === 'failed' && <ExportFailure error={state.error} />}
      </div>
      {state.step === 'downloading' ? (
        <button type="button" className="button button--secondary align-start" onClick={cancel}>
          {t.commonCancel}
        </button>
      ) : (
        <button type="button" className="button button--secondary align-start" onClick={() => void start()}>
          <Icon name="download" />
          {t.dataExportTitle}
        </button>
      )}
    </div>
  );
}

function ExportFailure({ error }: { error: unknown }) {
  const { t } = useI18n();
  const message = exportErrorMessage(t, error);
  // Too many this hour: another try now would be refused too, so it is said plainly, without "Try again".
  if (message !== errorMessage(t, error)) return <Notice tone="warning">{message}</Notice>;
  return <ErrorNotice error={error} />;
}
