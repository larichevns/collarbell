// «Тариф» on the household page: Free or Premium (until a day, or with no end), this month's AI photos against the
// plan's limit, the last change, and the admin's actions: «Выдать Premium», «Изменить срок», «Забрать Premium». The
// forms open inside the card (no browser dialogs); the card then shows the plan as the server answered it
// (PUT /api/admin/households/{id}/plan). Words of the states: lib/plan.ts.
import { useEffect, useId, useRef, useState, type FormEvent } from 'react';
import { ApiError, errorText } from '../api/client';
import type { AdminPlan, PlanRequest } from '../api/types';
import { Card, Icon, Meter, Notice, Spinner } from '../components/ui';
import {
  dateInputValue,
  daysUntil,
  endOfDayIso,
  formatDateNumeric,
  formatDateTime,
  formatFull,
  formatNumber,
  plural,
} from '../lib/format';
import { useNow } from '../lib/hooks';
import {
  aiPhotosUsage,
  isPurchased,
  planFormErrors,
  planSourceText,
  planState,
  PLAN_NOTE_MAX,
  type PlanFormField,
} from '../lib/plan';
import { useSession } from '../session';

type Mode = 'view' | 'grant' | 'change' | 'revoke';
type FormErrors = Partial<Record<PlanFormField, string>>;

export function PlanCard({
  householdId,
  householdName,
  plan,
  onChange,
}: {
  householdId: string;
  householdName: string;
  plan: AdminPlan;
  /** The plan as the server answered a change. */
  onChange: (plan: AdminPlan) => void;
}) {
  const now = useNow();
  const [mode, setMode] = useState<Mode>('view');
  const [saved, setSaved] = useState<string | null>(null);
  const state = planState(plan);

  const open = (next: Mode) => {
    setSaved(null);
    setMode(next);
  };
  const done = (updated: AdminPlan, message: string) => {
    onChange(updated);
    setMode('view');
    setSaved(message);
  };

  return (
    <Card title="Тариф" icon="workspace_premium" className="plan-card">
      <div className="plan-body">
        <div className="plan-summary">
          <p className={`plan-name plan-name--${plan.plan === 'Premium' ? 'premium' : 'free'}`}>{plan.plan}</p>
          {state.kind === 'premium' && (
            <p className="plan-term">
              {state.until ? (
                <>
                  до{'\u00a0'}
                  <time dateTime={state.until} title={formatFull(state.until)}>
                    {formatDateNumeric(state.until)}
                  </time>{' '}
                  · {daysLeft(state.until, now)}
                </>
              ) : (
                'бессрочно'
              )}
            </p>
          )}
          {state.kind === 'ended' && (
            <p className="plan-term plan-term--ended">
              <Icon name="schedule" size={18} />
              <span>
                Premium закончился{' '}
                <time dateTime={state.endedAt} title={formatFull(state.endedAt)}>
                  {formatDateNumeric(state.endedAt)}
                </time>
              </span>
            </p>
          )}
        </div>

        <AiPhotos plan={plan} />
        <LastChange plan={plan} now={now} />

        {mode === 'view' && saved && (
          <p className="plan-saved" role="status">
            <Icon name="check_circle" size={18} />
            {saved}
          </p>
        )}
        {mode === 'view' && (
          <div className="plan-actions">
            {state.kind === 'premium' ? (
              <>
                <button type="button" className="button button--secondary" onClick={() => open('change')}>
                  Изменить срок
                </button>
                <button type="button" className="button button--ghost button--danger-text" onClick={() => open('revoke')}>
                  Забрать Premium
                </button>
              </>
            ) : (
              <button type="button" className="button button--primary" onClick={() => open('grant')}>
                <Icon name="workspace_premium" size={18} />
                Выдать Premium
              </button>
            )}
          </div>
        )}
        {(mode === 'grant' || mode === 'change') && (
          <PremiumForm
            householdId={householdId}
            plan={plan}
            changing={mode === 'change'}
            onDone={done}
            onCancel={() => setMode('view')}
          />
        )}
        {mode === 'revoke' && (
          <RevokeForm householdId={householdId} householdName={householdName} onDone={done} onCancel={() => setMode('view')} />
        )}
      </div>
    </Card>
  );
}

/** «ещё 87 дней», «последний день». */
function daysLeft(until: string, now: Date): string {
  const days = daysUntil(until, now);
  return days <= 0 ? 'последний день' : `ещё ${days}\u00a0${plural(days, 'день', 'дня', 'дней')}`;
}

function AiPhotos({ plan }: { plan: AdminPlan }) {
  const usage = aiPhotosUsage(plan);
  const used = formatNumber(plan.aiPhotosUsed);
  const limit = formatNumber(plan.aiPhotosPerMonth);
  return (
    <div className={`plan-usage plan-usage--${usage.tone}`}>
      <div className="plan-usage-row">
        <span
          className="plan-usage-label"
          title="Календарный месяц по UTC; паспорта, которые ещё читаются, тоже считаются"
        >
          AI-фото в этом месяце
        </span>
        <span className="plan-usage-value">
          {used} из {limit}
        </span>
      </div>
      {usage.share !== null && (
        <Meter value={usage.share} tone={usage.tone} label={`AI-фото в этом месяце: ${used} из ${limit}`} />
      )}
      <p className="plan-usage-hint">
        {usage.tone === 'warning' && <Icon name="warning" size={16} />}
        {usage.hint}
      </p>
    </div>
  );
}

function LastChange({ plan, now }: { plan: AdminPlan; now: Date }) {
  if (!plan.changedAt) return <p className="plan-change muted">Тариф не меняли: группа всегда была на Free.</p>;
  const who =
    plan.source === 'Manual'
      ? plan.changedBy
        ? `Изменил ${plan.changedBy}`
        : 'Изменён вручную'
      : `Изменён: ${planSourceText(plan.source) ?? 'неизвестно как'}`;
  return (
    <p className="plan-change muted">
      {who}{' '}
      <time dateTime={plan.changedAt} title={formatFull(plan.changedAt)}>
        {formatDateTime(plan.changedAt, now)}
      </time>
      {plan.note && (
        <>
          {' · '}
          <span className="plan-note">{plan.note}</span>
        </>
      )}
    </p>
  );
}

/** What went wrong with a change, by the place in the form. */
function changeErrors(error: unknown): FormErrors {
  if (error instanceof ApiError && error.status === 400 && Object.keys(error.fields).length) {
    return planFormErrors(error.fields);
  }
  if (error instanceof ApiError && error.status === 404) return { form: 'Группа не найдена: возможно, её удалили.' };
  return { form: errorText(error) };
}

/** Sends a change; the form stays (with the errors) when the server says no. */
function useSavePlan(householdId: string) {
  const { api } = useSession();
  const [saving, setSaving] = useState(false);
  const [errors, setErrors] = useState<FormErrors>({});

  async function save(request: PlanRequest): Promise<AdminPlan | null> {
    setSaving(true);
    setErrors({});
    try {
      return await api.setPlan(householdId, request);
    } catch (error) {
      setErrors(changeErrors(error));
      setSaving(false);
      return null;
    }
  }

  return { saving, errors, setErrors, save };
}

/** Puts the keyboard in a form that has just opened. */
function useFocusOnOpen<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  useEffect(() => ref.current?.focus(), []);
  return ref;
}

function FieldError({ id, text }: { id: string; text: string | undefined }) {
  if (!text) return null;
  return (
    <p id={id} className="field-error">
      <Icon name="error" size={16} />
      {text}
    </p>
  );
}

/** «Выдать Premium» and «Изменить срок»: with no end, or through a day; and a note. */
function PremiumForm({
  householdId,
  plan,
  changing,
  onDone,
  onCancel,
}: {
  householdId: string;
  plan: AdminPlan;
  changing: boolean;
  onDone: (plan: AdminPlan, message: string) => void;
  onCancel: () => void;
}) {
  const ids = useId();
  const title = useFocusOnOpen<HTMLHeadingElement>();
  const [end, setEnd] = useState<'forever' | 'until'>(changing && plan.expiresAt ? 'until' : 'forever');
  const [day, setDay] = useState(changing && plan.expiresAt ? dateInputValue(plan.expiresAt) : '');
  const [note, setNote] = useState(changing ? (plan.note ?? '') : '');
  const { saving, errors, setErrors, save } = useSavePlan(householdId);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    let expiresAt: string | null = null;
    if (end === 'until') {
      expiresAt = endOfDayIso(day);
      if (!expiresAt) {
        setErrors({ expiresAt: 'Выберите дату окончания.' });
        return;
      }
    }
    const updated = await save({ plan: 'Premium', expiresAt, note: note.trim() || null });
    if (updated) onDone(updated, changing ? 'Срок изменён.' : 'Premium выдан.');
  }

  return (
    <form className="plan-form" onSubmit={submit} noValidate aria-labelledby={`${ids}-title`}>
      <fieldset disabled={saving}>
        <h3 id={`${ids}-title`} ref={title} tabIndex={-1} className="plan-form-title">
          {changing ? 'Изменить срок Premium' : 'Выдать Premium'}
        </h3>
        {isPurchased(plan.source) && (
          <Notice tone="warning">
            <p>Тариф куплен ({planSourceText(plan.source)}). Изменение вручную заменит покупку.</p>
          </Notice>
        )}
        <div className="plan-form-group" role="radiogroup" aria-labelledby={`${ids}-end`}>
          <span id={`${ids}-end`} className="field-label">
            Срок
          </span>
          <div className="plan-ends">
            <label className="radio">
              <input type="radio" name={`${ids}-end`} checked={end === 'forever'} onChange={() => setEnd('forever')} />
              Бессрочно
            </label>
            <label className="radio">
              <input type="radio" name={`${ids}-end`} checked={end === 'until'} onChange={() => setEnd('until')} />
              До даты
            </label>
            <input
              type="date"
              className={`input plan-date${end === 'forever' ? ' is-idle' : ''}`}
              aria-label="Дата окончания"
              min={dateInputValue(new Date())}
              value={day}
              onChange={(event) => {
                setDay(event.target.value);
                setEnd('until');
              }}
              aria-invalid={errors.expiresAt ? true : undefined}
              aria-describedby={errors.expiresAt ? `${ids}-expires-error` : `${ids}-expires-hint`}
            />
          </div>
          {errors.expiresAt ? (
            <FieldError id={`${ids}-expires-error`} text={errors.expiresAt} />
          ) : (
            <p id={`${ids}-expires-hint`} className="field-hint">
              {end === 'until'
                ? 'Premium работает до конца этого дня по вашему времени, потом группа сама вернётся на Free.'
                : 'Premium работает, пока его не заберут.'}
            </p>
          )}
        </div>
        <NoteField ids={ids} note={note} setNote={setNote} error={errors.note} placeholder="например, тестер" />
        {errors.form && (
          <Notice tone="danger">
            <p>{errors.form}</p>
          </Notice>
        )}
        <div className="form-actions">
          <button type="submit" className="button button--primary">
            {saving && <Spinner />}
            {saving ? 'Сохраняем…' : 'Сохранить'}
          </button>
          <button type="button" className="button button--ghost" onClick={onCancel}>
            Отмена
          </button>
        </div>
      </fieldset>
    </form>
  );
}

/** «Забрать Premium»: one more step, with an optional note why. */
function RevokeForm({
  householdId,
  householdName,
  onDone,
  onCancel,
}: {
  householdId: string;
  householdName: string;
  onDone: (plan: AdminPlan, message: string) => void;
  onCancel: () => void;
}) {
  const ids = useId();
  const title = useFocusOnOpen<HTMLHeadingElement>();
  const [note, setNote] = useState('');
  const { saving, errors, save } = useSavePlan(householdId);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const updated = await save({ plan: 'Free', expiresAt: null, note: note.trim() || null });
    if (updated) onDone(updated, 'Premium забран: группа на Free.');
  }

  return (
    <form className="plan-form plan-form--danger" onSubmit={submit} noValidate aria-labelledby={`${ids}-title`}>
      <fieldset disabled={saving}>
        <h3 id={`${ids}-title`} ref={title} tabIndex={-1} className="plan-form-title">
          Забрать Premium у группы «{householdName}»?
        </h3>
        <p className="muted">Группа сразу перейдёт на Free, с его лимитом AI-фото.</p>
        <NoteField ids={ids} note={note} setNote={setNote} error={errors.note} placeholder="например, тест окончен" />
        {errors.form && (
          <Notice tone="danger">
            <p>{errors.form}</p>
          </Notice>
        )}
        <div className="form-actions">
          <button type="submit" className="button button--danger">
            {saving && <Spinner />}
            {saving ? 'Забираем…' : 'Забрать Premium'}
          </button>
          <button type="button" className="button button--ghost" onClick={onCancel}>
            Отмена
          </button>
        </div>
      </fieldset>
    </form>
  );
}

function NoteField({
  ids,
  note,
  setNote,
  error,
  placeholder,
}: {
  ids: string;
  note: string;
  setNote: (note: string) => void;
  error: string | undefined;
  placeholder: string;
}) {
  return (
    <div className="field">
      <label className="field-label" htmlFor={`${ids}-note`}>
        Заметка <span className="muted">— необязательно</span>
      </label>
      <input
        id={`${ids}-note`}
        className="input"
        maxLength={PLAN_NOTE_MAX}
        placeholder={placeholder}
        value={note}
        onChange={(event) => setNote(event.target.value)}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${ids}-note-error` : `${ids}-note-count`}
      />
      {error ? (
        <FieldError id={`${ids}-note-error`} text={error} />
      ) : (
        <p id={`${ids}-note-count`} className="field-hint">
          {note.length} / {PLAN_NOTE_MAX}
        </p>
      )}
    </div>
  );
}
