// Form fields: the label above, the input, then a hint or the error under it. The error is tied to its input
// (aria-invalid, aria-describedby), so a screen reader says it with the field; the server's field errors show the same
// way. Every input is the browser's own (date, time, select, checkbox): keyboards, screen readers and pickers work.
import { useEffect, useId, useState, type ReactNode, type RefObject } from 'react';
import { useI18n } from '../i18n/i18n';
import { Icon } from './Icon';

interface InputProps {
  id: string;
  'aria-describedby'?: string;
  'aria-invalid'?: true;
}

function Field({
  label,
  hint,
  error,
  children,
}: {
  label: string;
  hint?: string | null;
  error?: string | null;
  children: (input: InputProps) => ReactNode;
}) {
  const id = useId();
  const noteId = `${id}-note`;
  const note = error ?? hint;
  return (
    <div className="field">
      <label className="field-label" htmlFor={id}>
        {label}
      </label>
      {children({
        id,
        'aria-describedby': note ? noteId : undefined,
        'aria-invalid': error ? true : undefined,
      })}
      {error ? (
        <p className="field-error" id={noteId}>
          <Icon name="error" size={16} />
          {error}
        </p>
      ) : (
        hint && (
          <p className="field-hint" id={noteId}>
            {hint}
          </p>
        )
      )}
    </div>
  );
}

interface TextProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  hint?: string | null;
  error?: string | null;
  placeholder?: string;
  /** Several lines: a textarea of this many rows. */
  rows?: number;
  type?: 'text' | 'email' | 'password' | 'url';
  autoComplete?: string;
  inputMode?: 'text' | 'numeric' | 'decimal';
  /** Codes (a chip number): monospace, no spell check. */
  code?: boolean;
  /** The field to start in (a page opened for it). */
  autoFocus?: boolean;
}

export function TextField({ label, value, onChange, hint, error, rows, code, ...input }: TextProps) {
  const inputClass = `input${code ? ' input--code' : ''}`;
  return (
    <Field label={label} hint={hint} error={error}>
      {(props) =>
        rows ? (
          <textarea
            {...props}
            className={inputClass}
            rows={rows}
            value={value}
            placeholder={input.placeholder}
            onChange={(event) => onChange(event.target.value)}
          />
        ) : (
          <input
            {...props}
            {...input}
            className={inputClass}
            type={input.type ?? 'text'}
            spellCheck={code ? false : undefined}
            value={value}
            onChange={(event) => onChange(event.target.value)}
          />
        )
      }
    </Field>
  );
}

/** A calendar date as the API writes it ("2026-10-07"; "" when none), with the browser's picker. */
export function DateField({
  label,
  value,
  onChange,
  min,
  max,
  hint,
  error,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  min?: string;
  max?: string;
  hint?: string | null;
  error?: string | null;
}) {
  return (
    <Field label={label} hint={hint} error={error}>
      {(props) => (
        <input
          {...props}
          className="input input--date"
          type="date"
          value={value}
          min={min}
          max={max}
          onChange={(event) => onChange(event.target.value)}
        />
      )}
    </Field>
  );
}

/** A time of day ("08:30"; "" when none), with the browser's picker. */
export function TimeField({
  label,
  value,
  onChange,
  hint,
  error,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  hint?: string | null;
  error?: string | null;
}) {
  return (
    <Field label={label} hint={hint} error={error}>
      {(props) => (
        <input
          {...props}
          className="input input--time"
          type="time"
          value={value}
          onChange={(event) => onChange(event.target.value)}
        />
      )}
    </Field>
  );
}

export function SelectField<T extends string>({
  label,
  value,
  options,
  onChange,
  hint,
  error,
}: {
  label: string;
  value: T;
  options: readonly { value: T; label: string }[];
  onChange: (value: T) => void;
  hint?: string | null;
  error?: string | null;
}) {
  return (
    <Field label={label} hint={hint} error={error}>
      {(props) => (
        <select
          {...props}
          className="input"
          value={value}
          onChange={(event) => onChange(event.target.value as T)}
        >
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      )}
    </Field>
  );
}

/** A yes-or-no choice: the box, its label to the right, a hint under it. */
export function CheckboxField({
  label,
  checked,
  onChange,
  hint,
  error,
}: {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  hint?: string | null;
  /** Why it must be ticked: said with the box, as a field's error is. */
  error?: string | null;
}) {
  const id = useId();
  const note = error ?? hint;
  return (
    <div className={`check-field${error ? ' is-invalid' : ''}`}>
      <input
        id={id}
        type="checkbox"
        checked={checked}
        aria-describedby={note ? `${id}-note` : undefined}
        aria-invalid={error ? true : undefined}
        onChange={(event) => onChange(event.target.checked)}
      />
      <label htmlFor={id}>{label}</label>
      {error ? (
        <p className="field-error" id={`${id}-note`}>
          <Icon name="error" size={16} />
          {error}
        </p>
      ) : (
        hint && (
          <p className="field-hint" id={`${id}-note`}>
            {hint}
          </p>
        )
      )}
    </div>
  );
}

/** One of a few, side by side (species, sex, the kind of visit): radio buttons drawn as pills. */
export function ChoiceGroup<T extends string>({
  label,
  value,
  options,
  onChange,
  hint,
  error,
  labelHidden = false,
}: {
  label: string;
  value: T | null;
  options: readonly { value: T; label: string; icon?: ReactNode; disabled?: boolean }[];
  onChange: (value: T) => void;
  hint?: string | null;
  error?: string | null;
  /** The legend is for screen readers only: what the choices are is plain to see (a filter above a list). */
  labelHidden?: boolean;
}) {
  const id = useId();
  return (
    <fieldset
      className="choice-group"
      data-invalid={error ? true : undefined}
      aria-describedby={error || hint ? `${id}-note` : undefined}
    >
      <legend className={labelHidden ? 'visually-hidden' : 'field-label'}>{label}</legend>
      <div className="choices">
        {options.map((option) => (
          <label key={option.value} className="choice">
            <input
              type="radio"
              name={id}
              value={option.value}
              checked={value === option.value}
              disabled={option.disabled}
              onChange={() => onChange(option.value)}
            />
            <span className="choice-pill">
              {option.icon}
              {option.label}
            </span>
          </label>
        ))}
      </div>
      {error ? (
        <p className="field-error" id={`${id}-note`}>
          <Icon name="error" size={16} />
          {error}
        </p>
      ) : (
        hint && (
          <p className="field-hint" id={`${id}-note`}>
            {hint}
          </p>
        )
      )}
    </fieldset>
  );
}

/** Several of many (the pets of a visit, its reminders): checkboxes drawn as pills. */
export function MultiChoice<T extends string | number>({
  label,
  values,
  options,
  onChange,
  hint,
  error,
}: {
  label: string;
  values: readonly T[];
  options: readonly { value: T; label: string }[];
  onChange: (values: T[]) => void;
  hint?: string | null;
  error?: string | null;
}) {
  const id = useId();
  return (
    <fieldset
      className="choice-group"
      data-invalid={error ? true : undefined}
      aria-describedby={error || hint ? `${id}-note` : undefined}
    >
      <legend className="field-label">{label}</legend>
      <div className="choices">
        {options.map((option) => (
          <label key={String(option.value)} className="choice">
            <input
              type="checkbox"
              checked={values.includes(option.value)}
              onChange={(event) =>
                onChange(
                  event.target.checked
                    ? [...values, option.value]
                    : values.filter((value) => value !== option.value),
                )
              }
            />
            <span className="choice-pill">
              {values.includes(option.value) && <Icon name="check" size={16} />}
              {option.label}
            </span>
          </label>
        ))}
      </div>
      {error ? (
        <p className="field-error" id={`${id}-note`}>
          <Icon name="error" size={16} />
          {error}
        </p>
      ) : (
        hint && (
          <p className="field-hint" id={`${id}-note`}>
            {hint}
          </p>
        )
      )}
    </fieldset>
  );
}

/**
 * A whole number with − and + beside it (packages): typed, stepped with the buttons, or with the arrow keys in the
 * field. A button at its limit stays where it is (aria-disabled), so the keyboard's focus isn't lost. While the field
 * has the focus it shows what is typed, so it can be emptied and typed anew (Backspace, then 3, is 3); the number
 * itself is kept within its limits all the while (an empty field is the least), and shown so once the focus leaves.
 */
export function Stepper({
  label,
  value,
  min,
  max,
  onChange,
  hint,
  error,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  onChange: (value: number) => void;
  hint?: string | null;
  error?: string | null;
}) {
  const { t } = useI18n();
  const clamp = (next: number) => Math.min(max, Math.max(min, next));
  // What is typed, while the field has the focus; null: the number as it is.
  const [typing, setTyping] = useState<string | null>(null);
  return (
    <Field label={label} hint={hint} error={error}>
      {(props) => (
        <div className="stepper">
          <button
            type="button"
            className="icon-button stepper-button"
            aria-label={t.stepperFewer(label)}
            aria-disabled={value <= min || undefined}
            onClick={() => value > min && onChange(value - 1)}
          >
            <Icon name="remove" />
          </button>
          <input
            {...props}
            className="input stepper-input"
            type="number"
            inputMode="numeric"
            min={min}
            max={max}
            step={1}
            value={typing ?? value}
            onChange={(event) => {
              const text = event.target.value;
              setTyping(text);
              // Emptied: the least for now, until something is typed.
              if (text.trim() === '') onChange(min);
              else if (Number.isInteger(Number(text))) onChange(clamp(Number(text)));
            }}
            onBlur={() => setTyping(null)}
          />
          <button
            type="button"
            className="icon-button stepper-button"
            aria-label={t.stepperMore(label)}
            aria-disabled={value >= max || undefined}
            onClick={() => value < max && onChange(value + 1)}
          >
            <Icon name="add" />
          </button>
        </div>
      )}
    </Field>
  );
}

/** A value on a scale by steps (how full the open package is), read out as `valueText`. */
export function RangeField({
  label,
  value,
  min,
  max,
  valueText,
  onChange,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  valueText: string;
  onChange: (value: number) => void;
}) {
  return (
    <Field label={label}>
      {(props) => (
        <input
          {...props}
          className="range"
          type="range"
          min={min}
          max={max}
          step={1}
          value={value}
          aria-valuetext={valueText}
          onChange={(event) => onChange(Number(event.target.value))}
        />
      )}
    </Field>
  );
}

/** A field a person can see and use: not a drop zone's hidden file input. */
const VISIBLE_FIELD =
  'input:not([type="file"]):not([aria-hidden="true"]):not([disabled]), select:not([disabled]), textarea:not([disabled])';

/**
 * After a submit with mistakes (`attempt` grows), the first field with an error gets the focus, which also scrolls it
 * into view. A group of choices hands it to its first choice; a group without a field to type in (a document's pages)
 * to its first button ("Add pages").
 */
export function useFocusFirstError(form: RefObject<HTMLElement | null>, attempt: number) {
  useEffect(() => {
    if (attempt === 0) return;
    const invalid = form.current?.querySelector<HTMLElement>('[aria-invalid="true"], [data-invalid]');
    const target = invalid?.matches('fieldset')
      ? (invalid.querySelector<HTMLElement>(VISIBLE_FIELD) ??
        invalid.querySelector<HTMLElement>('button:not([disabled])'))
      : invalid;
    target?.focus();
  }, [form, attempt]);
}
