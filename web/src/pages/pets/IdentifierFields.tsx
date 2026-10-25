// The pet form's microchips and tattoos: a card each (type, number, date, place), up to five. The number is checked as
// it is typed against the server's rules (lib/identifiers.ts), so a 14-digit ISO number is caught before saving.
// With AI set up on the server, a chip's number can also be read from a photo of its sticker or the passport page
// (ChipReader.tsx): it fills the card, and the card asks to check it against the passport.
import { useLayoutEffect, useRef, useState } from 'react';
import type { ApiClient } from '../../api/client';
import type { IdentifierReading, IdentifierType } from '../../api/types';
import { DateField, SelectField, TextField } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useKeepFocus } from '../../components/useKeepFocus';
import { useI18n } from '../../i18n/i18n';
import { MAX_IDENTIFIERS, normalizeCode } from '../../lib/identifiers';
import { ChipPhotoReader, ReadingPicker, type ChipNote } from './ChipReader';

/** One microchip or tattoo while the form is open. */
export interface IdentifierDraft {
  /** Keeps a card's fields when a card above it is removed. */
  key: string;
  type: IdentifierType;
  /** As typed: the server keeps it so, and normalizes it for checks. */
  code: string;
  appliedOn: string;
  location: string;
  /** When a vet last read the chip: not edited here, but sent back so saving doesn't lose it. */
  readOn: string | null;
}

function newIdentifier(): IdentifierDraft {
  return { key: crypto.randomUUID(), type: 'IsoChip', code: '', appliedOn: '', location: '', readOn: null };
}

const TYPES: readonly IdentifierType[] = ['IsoChip', 'LegacyChip', 'Tattoo'];

/** What the number of each type looks like; a tattoo is any letters and digits. */
const HINTS: Record<IdentifierType, 'identifierIsoHint' | 'identifierLegacyHint' | null> = {
  IsoChip: 'identifierIsoHint',
  LegacyChip: 'identifierLegacyHint',
  Tattoo: null,
};

export function IdentifierFields({
  drafts,
  onChange,
  errorOf,
  listError,
  today,
  reader = null,
}: {
  drafts: IdentifierDraft[];
  onChange: (drafts: IdentifierDraft[]) => void;
  /** The error of a card's field ("code", "appliedOn", "location"), or null. */
  errorOf: (index: number, field: 'code' | 'appliedOn' | 'location') => string | null;
  /** The server's word on the list as a whole. */
  listError: string | null;
  today: string;
  /** Reading a chip's number from a photo, when AI is set up on the server (the household's client); null: none. */
  reader?: { api: ApiClient; freeTier: boolean } | null;
}) {
  const { t } = useI18n();
  const update = (index: number, change: Partial<IdentifierDraft>) =>
    onChange(drafts.map((draft, at) => (at === index ? { ...draft, ...change } : draft)));
  // How a card's reading went, by its key; and several numbers to choose from for one card.
  const [notes, setNotes] = useState<Record<string, ChipNote>>({});
  const [choosing, setChoosing] = useState<{ key: string; readings: IdentifierReading[] } | null>(null);
  // The card whose photo is being prepared or read: one at a time, so every answer (and its choice) finds its card.
  const [readingFor, setReadingFor] = useState<string | null>(null);
  // The cards as they are now: a reading answers after the person went on typing (or removed the card).
  const latest = useRef(drafts);
  useLayoutEffect(() => {
    latest.current = drafts;
  });
  const note = (key: string, value: ChipNote | null) =>
    setNotes((old) => {
      const next = { ...old };
      if (value) next[key] = value;
      else delete next[key];
      return next;
    });

  /**
   * A number read from a photo into the card `key`, with its type. The place and date read go where the card has none
   * yet, or where they belonged to another number the reading replaces; typed for this number, they stay.
   */
  function fill(key: string, reading: IdentifierReading) {
    const cards = latest.current;
    const index = cards.findIndex((draft) => draft.key === key);
    const draft = cards[index];
    if (!draft) return;
    const before = normalizeCode(draft.code);
    const replaced = before !== '' && before !== normalizeCode(reading.rawCode);
    onChange(
      cards.map((each, at) =>
        at === index
          ? {
              ...each,
              type: reading.type,
              code: reading.rawCode,
              location: reading.location && (replaced || !each.location.trim()) ? reading.location : each.location,
              appliedOn: reading.appliedOn && (replaced || !each.appliedOn) ? reading.appliedOn : each.appliedOn,
            }
          : each,
      ),
    );
    note(key, { text: t.chipScanCheck, failed: false });
  }

  /** One number fills the card; of several, the person picks one; without any, the card says so. */
  function found(key: string, readings: IdentifierReading[]) {
    if (!latest.current.some((draft) => draft.key === key)) return;
    if (readings.length === 0) note(key, { text: t.chipScanNothingFound, failed: false });
    else if (readings.length === 1) fill(key, readings[0]!);
    else setChoosing({ key, readings });
  }
  // A card removed: the focus goes to the card now in its place, or to "Add" when none is left.
  const cards = useRef<HTMLDivElement>(null);
  useKeepFocus(cards, {
    item: 'fieldset.identifier',
    fallback: () => cards.current?.querySelector<HTMLElement>(':scope > button'),
  });

  return (
    <div className="identifiers" ref={cards}>
      {drafts.length === 0 && <p className="muted">{t.identifiersEmpty}</p>}
      {drafts.map((draft, index) => {
        const tattoo = draft.type === 'Tattoo';
        const hint = HINTS[draft.type];
        return (
          <fieldset key={draft.key} className="identifier">
            <legend className="visually-hidden">
              {t.identifiersTitle} {index + 1}
            </legend>
            <div className="identifier-head">
              <SelectField
                label={t.identifierTypeLabel}
                value={draft.type}
                options={TYPES.map((type) => ({ value: type, label: t.identifierType[type] }))}
                onChange={(type) => update(index, { type })}
              />
              <button
                type="button"
                className="icon-button"
                aria-label={t.identifierRemove}
                title={t.identifierRemove}
                onClick={() => onChange(drafts.filter((_, at) => at !== index))}
              >
                <Icon name="delete" />
              </button>
            </div>
            <TextField
              label={tattoo ? t.identifierTattooLabel : t.identifierChipLabel}
              hint={hint && t[hint]}
              value={draft.code}
              onChange={(code) => update(index, { code })}
              inputMode={draft.type === 'IsoChip' ? 'numeric' : 'text'}
              autoComplete="off"
              code
              error={errorOf(index, 'code')}
            />
            <div className="form-row">
              <DateField
                label={tattoo ? t.identifierTattooDateLabel : t.identifierChipDateLabel}
                value={draft.appliedOn}
                max={today}
                onChange={(appliedOn) => update(index, { appliedOn })}
                error={errorOf(index, 'appliedOn')}
              />
              <TextField
                label={t.identifierLocationLabel}
                placeholder={t.identifierLocationHint}
                value={draft.location}
                onChange={(location) => update(index, { location })}
                error={errorOf(index, 'location')}
              />
            </div>
            {reader && !tattoo && (
              <ChipPhotoReader
                api={reader.api}
                freeTier={reader.freeTier}
                disabled={readingFor !== null && readingFor !== draft.key}
                onBusy={(busy) => setReadingFor((old) => (busy ? draft.key : old === draft.key ? null : old))}
                onFound={(readings) => found(draft.key, readings)}
                onFailed={(message) => note(draft.key, { text: message, failed: true })}
              />
            )}
            {notes[draft.key] && (
              <p className={notes[draft.key]!.failed ? 'field-error' : 'field-hint chip-note'} role="status">
                {notes[draft.key]!.failed && <Icon name="error" size={16} />}
                {notes[draft.key]!.text}
              </p>
            )}
          </fieldset>
        );
      })}
      {listError && (
        <p className="field-error">
          <Icon name="error" size={16} />
          {listError}
        </p>
      )}
      {drafts.length < MAX_IDENTIFIERS && (
        <button
          type="button"
          className="button button--secondary"
          onClick={() => onChange([...drafts, newIdentifier()])}
        >
          <Icon name="add" size={18} />
          {t.identifiersAdd}
        </button>
      )}
      {choosing && (
        <ReadingPicker
          readings={choosing.readings}
          otherCodes={drafts.filter((draft) => draft.key !== choosing.key).map((draft) => normalizeCode(draft.code))}
          onPick={(reading) => {
            fill(choosing.key, reading);
            setChoosing(null);
          }}
          onClose={() => setChoosing(null)}
        />
      )}
    </div>
  );
}
