// "Join a group" (the phone app's join_screen.dart): the code someone gave the person, what it invites to, and "Join";
// the joined group then opens on Home, with its pets. The code is typed or pasted (a whole message gives its code), or
// comes in an invite's link after "#". The server allows a few codes per person in ten minutes, against guessing, so a
// code is checked once all eight characters are in, and one with a character codes never have is refused at once.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useEffectEvent, useId, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { ApiError, data } from '../../api/client';
import { householdErrorMessage, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import type { HouseholdSummary, InvitePreview } from '../../api/types';
import { Icon } from '../../components/Icon';
import { useToast } from '../../components/Toasts';
import { Badge, ErrorNotice, Notice, PageHead, Spinner } from '../../components/ui';
import { useApi } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { localDateOf } from '../../lib/dates';
import { formatInviteCode, impossibleInviteCode, INVITE_CODE_LENGTH, inviteCodeOf } from '../../lib/invites';
import { householdName } from '../../lib/labels';
import { useSession } from '../../session';

type Check =
  | { code: string; state: 'checking' }
  | { code: string; state: 'found'; preview: InvitePreview }
  | { code: string; state: 'failed'; error: unknown };

/** A code from the address (an invite's link: …/join#ABCD-2345). */
function codeFromAddress(hash: string): string {
  try {
    return inviteCodeOf(decodeURIComponent(hash.replace(/^#/, '')));
  } catch {
    return '';
  }
}

export function JoinPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const location = useLocation();
  const navigate = useNavigate();
  const api = useApi();
  const { user } = useSession();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [code, setCode] = useState(() => codeFromAddress(location.hash));
  const [check, setCheck] = useState<Check | null>(null);
  const [joining, setJoining] = useState(false);
  const [joinFailure, setJoinFailure] = useState<unknown>(null);
  const fieldId = useId();
  // The code a check's answer belongs to: an answer about a code typed over is dropped.
  const latest = useRef(code);
  latest.current = code;

  async function preview(digits: string) {
    setCheck({ code: digits, state: 'checking' });
    setJoinFailure(null);
    try {
      const found = await data(api.POST('/api/v1/invites/preview', { body: { code: digits } }));
      if (latest.current === digits) setCheck({ code: digits, state: 'found', preview: found });
    } catch (error) {
      if (latest.current === digits) setCheck({ code: digits, state: 'failed', error });
    }
  }

  // A code from an invite's link is checked at once, once.
  const linkChecked = useRef(false);
  const checkLink = useEffectEvent(() => {
    if (linkChecked.current) return;
    linkChecked.current = true;
    if (code.length === INVITE_CODE_LENGTH && !impossibleInviteCode(code)) void preview(code);
  });
  useEffect(() => checkLink(), []);

  function type(text: string) {
    const digits = inviteCodeOf(text);
    if (digits === code) return;
    setCode(digits);
    setCheck(null);
    setJoinFailure(null);
    latest.current = digits;
    if (digits.length === INVITE_CODE_LENGTH && !impossibleInviteCode(digits)) void preview(digits);
  }

  async function join() {
    if (check?.state !== 'found') return;
    setJoining(true);
    setJoinFailure(null);
    try {
      const joined = await data(api.POST('/api/v1/invites/accept', { body: { code: check.code } }));
      // In the list before it is on screen: a household not in the list would be left at once.
      queryClient.setQueryData(keys.households(user.uid), (old: HouseholdSummary[] | undefined) => [
        ...(old ?? []).filter((each) => each.id !== joined.id),
        joined,
      ]);
      void queryClient.invalidateQueries({ queryKey: keys.households(user.uid) });
      toast(t.joinJoined(householdName(t, joined.name, joined.role)));
      void navigate('/', { state: { household: joined.id } });
    } catch (error) {
      setJoinFailure(error);
      setJoining(false);
    }
  }

  const impossible = impossibleInviteCode(code);
  const shown = check && check.code === code ? check : null;
  const found = shown?.state === 'found' ? shown.preview : null;
  const failure = (error: unknown) =>
    // A code that is wrong, used, taken back or expired is a 404.
    isNotFound(error) ? t.joinNotFound : householdErrorMessage(t, error);
  const unreachable = (error: unknown) => error instanceof ApiError && error.status === 0;

  return (
    <>
      <PageHead back={{ to: '/settings', label: t.settingsTitle }} title={t.joinTitle} />
      <div className="form">
        <div className="field">
          <label className="field-label" htmlFor={fieldId}>
            {t.joinCodeLabel}
          </label>
          <input
            id={fieldId}
            className="input input--code join-code"
            value={formatInviteCode(code)}
            autoComplete="off"
            autoCapitalize="characters"
            spellCheck={false}
            aria-describedby={`${fieldId}-note`}
            aria-invalid={impossible || undefined}
            onChange={(event) => type(event.target.value)}
            disabled={joining}
          />
          {impossible ? (
            <p className="field-error" id={`${fieldId}-note`}>
              <Icon name="error" size={16} />
              {t.joinCodeBadCharacters}
            </p>
          ) : (
            <p className="field-hint" id={`${fieldId}-note`}>
              {t.joinCodeHelper}
            </p>
          )}
        </div>
        <div aria-live="polite">
          {shown?.state === 'checking' && (
            <p className="loading-inline">
              <Spinner />
              {t.joinChecking}
            </p>
          )}
          {shown?.state === 'failed' &&
            (unreachable(shown.error) ? (
              <ErrorNotice error={shown.error} onRetry={() => void preview(shown.code)} />
            ) : (
              <Notice tone="danger">{failure(shown.error)}</Notice>
            ))}
          {found && (
            <div className="card join-preview">
              <p className="join-preview-text">
                {found.invitedBy
                  ? t.joinPreview(found.invitedBy, householdName(t, found.householdName, 'Helper'), found.role)
                  : t.joinPreviewNoName(householdName(t, found.householdName, 'Helper'), found.role)}
              </p>
              <p className="invite-code-about">
                <Badge>{t.householdRole[found.role]}</Badge>
                <span className="muted small">{t.householdRoleHelp[found.role]}</span>
              </p>
              <p className="muted small">{t.joinValidUntil(i18n.date(localDateOf(found.expiresAt)))}</p>
              {found.alreadyMember && <Notice>{t.joinAlreadyMember}</Notice>}
            </div>
          )}
          {joinFailure !== null && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure(joinFailure)}
            </p>
          )}
        </div>
        <div className="form-foot">
          <button
            type="button"
            className="button button--primary"
            disabled={!found || found.alreadyMember || joining}
            onClick={() => void join()}
          >
            {joining && <Spinner />}
            {t.joinAction}
          </button>
        </div>
      </div>
    </>
  );
}
