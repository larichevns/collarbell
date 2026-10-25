// An invite (the phone app's household_sheets.dart): who is invited, a member or a helper, each with what they may
// do; then the one-time code, large to read out, how long it works, and the web's link to join with it, each with
// "Copy". Owners only. An open invite of the list shows its code the same way. The onboarding's family step uses it
// too.
import { useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { useHref } from 'react-router';
import { data, type ApiClient } from '../../api/client';
import { householdErrorMessage } from '../../api/errors';
import { keys } from '../../api/keys';
import type { HouseholdInvite, HouseholdRole } from '../../api/types';
import { Dialog, DialogBody, DialogCancel, DialogFoot, DialogForm } from '../../components/Dialog';
import { Icon } from '../../components/Icon';
import { Badge, Spinner } from '../../components/ui';
import { useI18n } from '../../i18n/i18n';
import { inviteDaysLeft, inviteLink } from '../../lib/invites';

/** The roles an invite can give: an owner is made once the person has joined. */
const INVITED: readonly HouseholdRole[] = ['Member', 'Helper'];

export function InviteDialog({
  api,
  household,
  invite: shown,
  onClose,
  onCreated,
}: {
  /** The household the invite is for, and its client. */
  api: ApiClient;
  household: string;
  /** An open invite to show; none: a new one, after picking the role. */
  invite: HouseholdInvite | null;
  onClose: () => void;
  /** A new invite was made (the onboarding says so once the dialog is closed). */
  onCreated?: (invite: HouseholdInvite) => void;
}) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const [role, setRole] = useState<HouseholdRole>('Member');
  const [invite, setInvite] = useState(shown);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const roleName = useId();

  async function create() {
    setBusy(true);
    setFailure(null);
    try {
      const created = await data(api.POST('/api/v1/households/current/invites', { body: { role } }));
      setInvite(created);
      onCreated?.(created);
    } catch (error) {
      setFailure(householdErrorMessage(t, error));
    } finally {
      setBusy(false);
      void queryClient.invalidateQueries({ queryKey: keys.householdDetails(household) });
    }
  }

  if (invite) {
    return (
      <Dialog title={t.householdInviteCodeTitle} onClose={onClose}>
        <DialogBody>
          <InviteCode invite={invite} />
        </DialogBody>
        <DialogFoot>
          <button type="button" className="button button--primary" onClick={onClose}>
            {t.commonClose}
          </button>
        </DialogFoot>
      </Dialog>
    );
  }

  return (
    <Dialog title={t.householdInviteTitle} onClose={onClose} busy={busy}>
      <DialogForm onSubmit={() => void create()} busy={busy}>
        <DialogBody>
          <fieldset className="role-choices">
            <legend className="visually-hidden">{t.householdInviteTitle}</legend>
            {INVITED.map((each) => (
              <label key={each} className="role-choice">
                <input
                  type="radio"
                  name={roleName}
                  value={each}
                  checked={role === each}
                  aria-labelledby={`${roleName}-${each}-name`}
                  aria-describedby={`${roleName}-${each}`}
                  onChange={() => setRole(each)}
                />
                <span className="role-choice-text">
                  <span className="role-choice-name" id={`${roleName}-${each}-name`}>
                    {t.householdRole[each]}
                  </span>
                  <span className="muted small" id={`${roleName}-${each}`}>
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
            {t.householdInviteCreate}
          </button>
        </DialogFoot>
      </DialogForm>
    </Dialog>
  );
}

/** Copies text; false when the browser wouldn't (no permission, a page not served over https). */
async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

/** The code to read out or copy, its role and days, and the link to join on the web. */
function InviteCode({ invite }: { invite: HouseholdInvite }) {
  const { t } = useI18n();
  // The join page's path with the app's own (/app/join).
  const link = inviteLink(invite.code, useHref('/join'));
  const linkId = useId();
  const linkField = useRef<HTMLInputElement>(null);
  const [copied, setCopied] = useState<'code' | 'link' | 'failed' | null>(null);

  async function copy(what: 'code' | 'link') {
    const done = await copyText(what === 'code' ? invite.code : link);
    setCopied(done ? what : 'failed');
    // Not copied: the link is selected, for Ctrl+C.
    if (!done && what === 'link') linkField.current?.select();
  }

  return (
    <div className="invite-code">
      <p className="invite-code-value" lang="en">
        {invite.code}
      </p>
      <p className="invite-code-about">
        <Badge>{t.householdRole[invite.role]}</Badge>
        <span className="muted small">{t.householdInviteCodeBody(inviteDaysLeft(invite.expiresAt))}</span>
      </p>
      <button
        type="button"
        className="button button--secondary align-start"
        onClick={() => void copy('code')}
      >
        <Icon name="content_copy" size={18} />
        {t.householdCopyCode}
      </button>
      <div className="field">
        <label className="field-label" htmlFor={linkId}>
          {t.householdInviteLinkLabel}
        </label>
        <input
          ref={linkField}
          id={linkId}
          className="input input--code"
          readOnly
          value={link}
          aria-describedby={`${linkId}-hint`}
          onFocus={(event) => event.target.select()}
        />
        <p className="field-hint" id={`${linkId}-hint`}>
          {t.householdInviteLinkHint}
        </p>
      </div>
      <button
        type="button"
        className="button button--secondary align-start"
        onClick={() => void copy('link')}
      >
        <Icon name="link" size={18} />
        {t.householdCopyLink}
      </button>
      <p className="muted small" role="status">
        {copied === 'failed' ? t.householdCopyFailed : copied ? t.householdCopied : ''}
      </p>
    </div>
  );
}
