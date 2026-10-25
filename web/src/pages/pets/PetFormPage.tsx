// Adding a pet, or editing one: the phone app's pet form. The photo (dropped or picked; uploaded on "Save"), name,
// species, sex, breed, date of birth, neutering, colour and markings as in the passport, microchips and tattoos (a chip's number also read from a photo by AI), allergies and notes. Mistakes the app can see
// show under their fields before anything is sent; the server's checks (a 400 by field) show the same way. Saving
// replaces all the pet's details and identifiers.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useNavigate, useParams } from 'react-router';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { uploadFile } from '../../api/files';
import { keys } from '../../api/keys';
import { useAiStatus, usePet } from '../../api/queries';
import type { FileLink, Pet, PetRequest, Sex, Species } from '../../api/types';
import { ChoiceGroup, CheckboxField, DateField, TextField, useFocusFirstError } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { PhotoDrop } from '../../components/PhotoDrop';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loading, PageHead, Section, Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { identifierProblem, MAX_LOCATION_LENGTH, normalizeCode } from '../../lib/identifiers';
import { identifierProblemLabel } from '../../lib/labels';
import { IdentifierFields, type IdentifierDraft } from './IdentifierFields';

// The server's limits; checked here so mistakes show before saving.
const MAX = { name: 60, breed: 100, color: 60, markings: 300, allergies: 500, notes: 2000 };

const SPECIES: readonly Species[] = ['Cat', 'Dog', 'Other'];
const SEXES: readonly Sex[] = ['Female', 'Male', 'Unknown'];

/** The server's field names this form shows under a field; a failure about anything else is said over "Save". */
const FIELDS =
  /^(name|breed|birthDate|neuteredOn|color|markings|allergies|notes|identifiers|identifiers\[\d+\]\.(code|appliedOn|location))$/;

export function NewPetPage() {
  return <PetForm pet={null} />;
}

export function EditPetPage() {
  const { id = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(id);
  // A pet deleted meanwhile (here, or on another phone) is not edited from an old copy.
  if (pet.data && !isNotFound(pet.error)) return <PetForm pet={pet.data} />;
  return (
    <>
      <PageHead back={{ to: `/pets/${id}`, label: t.petsTitle }} title={t.petFormEditTitle} />
      {pet.error ? <ErrorNotice error={pet.error} onRetry={() => void pet.refetch()} /> : <Loading />}
    </>
  );
}

interface Values {
  name: string;
  species: Species;
  sex: Sex;
  breed: string;
  birthDate: string;
  approximate: boolean;
  neutered: boolean;
  neuteredOn: string;
  color: string;
  markings: string;
  allergies: string;
  notes: string;
  identifiers: IdentifierDraft[];
}

function valuesOf(pet: Pet | null): Values {
  return {
    name: pet?.name ?? '',
    species: pet?.species ?? 'Cat',
    sex: pet?.sex ?? 'Unknown',
    breed: pet?.breed ?? '',
    birthDate: pet?.birthDate ?? '',
    approximate: pet?.birthDateApproximate ?? false,
    neutered: pet?.neutered ?? false,
    neuteredOn: pet?.neuteredOn ?? '',
    color: pet?.color ?? '',
    markings: pet?.markings ?? '',
    allergies: pet?.allergies ?? '',
    notes: pet?.notes ?? '',
    identifiers: (pet?.identifiers ?? []).map((identifier) => ({
      key: identifier.id,
      type: identifier.type,
      code: identifier.rawCode,
      appliedOn: identifier.appliedOn ?? '',
      location: identifier.location ?? '',
      readOn: identifier.readOn,
    })),
  };
}

/** What a form holds, to tell whether leaving loses anything: the values without the cards' keys. */
function snapshot(values: Values, photo: unknown): string {
  return JSON.stringify({ ...values, identifiers: values.identifiers.map(({ key: _key, ...rest }) => rest), photo });
}

function PetForm({ pet }: { pet: Pet | null }) {
  const i18n = useI18n();
  const { t } = i18n;
  // The household the form opened in: its save goes there, whichever household is on screen meanwhile.
  const { current } = useHousehold();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const today = useHouseholdDate();
  const form = useRef<HTMLFormElement>(null);
  // A chip's number can be read from a photo when the server has AI.
  const ai = useAiStatus();

  const [values, setValues] = useState(() => valuesOf(pet));
  /** A new photo, saved with the pet; "removed" takes the saved one away on "Save". */
  const [photo, setPhoto] = useState<{ file: File; preview: string } | 'removed' | null>(null);
  /** The new photo once uploaded: a retry after a failed save doesn't upload it again. */
  const uploaded = useRef<{ file: File; link: FileLink } | null>(null);
  const [submitted, setSubmitted] = useState(0);
  const [busy, setBusy] = useState<'photo' | 'saving' | null>(null);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  useFocusFirstError(form, submitted);

  const [opened] = useState(() => snapshot(values, null));
  const changed = snapshot(values, photo === null ? null : photo === 'removed' ? 'removed' : photo.preview) !== opened;
  // Leaving waits while the pet saves: its page opens next, in the household it was saved to.
  const { allowLeave } = useLeaveGuard(changed, busy !== null);
  const stillHere = useStillHere(household);

  // A picked photo is shown from memory until it is saved; its address is let go when replaced or left.
  const preview = photo && photo !== 'removed' ? photo.preview : null;
  useEffect(() => () => {
    if (preview) URL.revokeObjectURL(preview);
  }, [preview]);

  const set = <K extends keyof Values>(field: K, value: Values[K]) => setValues((old) => ({ ...old, [field]: value }));

  /**
   * The form's own checks (`required`: after a first "Save"), and the server's word on fields it refused, by the
   * server's names of the fields ("name", "identifiers[0].code").
   */
  function problems(required: boolean, refused: Record<string, string[]>): Record<string, string | null> {
    const server = (field: string) => (refused[field] ? t.formServerFieldError : null);
    const tooLong = (field: keyof typeof MAX) =>
      values[field].trim().length > MAX[field] ? t.formTooLong(MAX[field]) : server(field);
    const found: Record<string, string | null> = {
      name: required && !values.name.trim() ? t.petNameRequired : tooLong('name'),
      breed: tooLong('breed'),
      birthDate: server('birthDate'),
      neuteredOn:
        values.neuteredOn && values.birthDate && values.neuteredOn < values.birthDate
          ? t.petNeuteredBeforeBirth
          : server('neuteredOn'),
      color: tooLong('color'),
      markings: tooLong('markings'),
      allergies: tooLong('allergies'),
      notes: tooLong('notes'),
      identifiers: server('identifiers'),
    };
    const codes = values.identifiers.map((draft) => normalizeCode(draft.code));
    values.identifiers.forEach((draft, index) => {
      const at = `identifiers[${index}]`;
      // A number not typed yet is said only after "Save". Only the cards above count: the second of two equal numbers
      // gets the error.
      const problem = identifierProblem(draft.type, draft.code, codes.slice(0, index));
      found[`${at}.code`] =
        problem && (problem !== 'empty' || required) ? identifierProblemLabel(t, problem) : server(`${at}.code`);
      found[`${at}.appliedOn`] = server(`${at}.appliedOn`);
      found[`${at}.location`] =
        draft.location.trim().length > MAX_LOCATION_LENGTH ? t.formTooLong(MAX_LOCATION_LENGTH) : server(`${at}.location`);
    });
    return found;
  }
  const errors = problems(submitted > 0, serverFields);

  function request(): PetRequest {
    const clean = (value: string) => value.trim() || null;
    return {
      name: values.name.trim(),
      species: values.species,
      sex: values.sex,
      breed: clean(values.breed),
      birthDate: values.birthDate || null,
      birthDateApproximate: !!values.birthDate && values.approximate,
      // A checkbox can't say "unknown": unticked, a pet whose neutering was never given stays unknown.
      neutered: values.neutered ? true : pet?.neutered == null ? null : false,
      neuteredOn: values.neutered ? values.neuteredOn || null : null,
      color: clean(values.color),
      markings: clean(values.markings),
      // Pets have no colour in the app any more: null lets the server pick one for a new pet (the API still has it)
      // and keeps the saved one on an edit.
      coat: null,
      allergies: clean(values.allergies),
      notes: clean(values.notes),
      // The form has no status: null keeps it (and makes a new pet active).
      status: null,
      identifiers: values.identifiers.map((draft) => ({
        type: draft.type,
        code: draft.code.trim(),
        appliedOn: draft.appliedOn || null,
        readOn: draft.readOn,
        location: clean(draft.location),
      })),
    };
  }

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setSubmitted((value) => value + 1);
    setServerFields({});
    setFailure(null);
    if (Object.values(problems(true, {})).some(Boolean)) {
      setFailure(t.formCheckFields);
      return;
    }

    let saved: Pet | null = null;
    let photoStep: 'upload' | 'remove' = 'upload';
    try {
      // The photo first: if it is refused (too large, not a photo), nothing is saved yet and another can be picked.
      let link: FileLink | null = null;
      if (photo && photo !== 'removed') {
        setBusy('photo');
        link = uploaded.current?.file === photo.file ? uploaded.current.link : await uploadFile(api, photo.file);
        uploaded.current = { file: photo.file, link };
      }
      setBusy('saving');
      saved = await data(
        pet
          ? api.PUT('/api/v1/pets/{id}', { params: { path: { id: pet.id } }, body: request() })
          : api.POST('/api/v1/pets', { body: request() }),
      );
      if (link) {
        await api.PUT('/api/v1/pets/{id}/photo', { params: { path: { id: saved.id } }, body: { fileId: link.id } });
      } else if (photo === 'removed' && pet?.photo) {
        photoStep = 'remove';
        await api.DELETE('/api/v1/pets/{id}/photo', { params: { path: { id: saved.id } } });
      }
    } catch (error) {
      if (!saved) {
        const fields = fieldErrorsOf(error);
        const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => FIELDS.test(field));
        setServerFields(placed ? fields : {});
        setFailure(placed ? t.formCheckFields : errorMessage(t, error));
        if (placed) setSubmitted((value) => value + 1);
        setBusy(null);
        return;
      }
      // The pet is saved; only its photo isn't. Saving again would add the pet twice: on to its page instead.
      toast(photoStep === 'remove' ? t.petPhotoRemoveFailed : t.petPhotoSaveFailed);
    }
    // The list, the pet and Today (its name and photo) are read again.
    void queryClient.invalidateQueries({ queryKey: keys.pets(household) });
    void queryClient.invalidateQueries({ queryKey: keys.todayAll(household) });
    allowLeave();
    // Gone meanwhile (the household on screen went away): the pet is saved where it belongs; nothing opens elsewhere.
    if (!stillHere()) return;
    void navigate(`/pets/${saved.id}`, { replace: !pet });
  }

  const back = pet ? { to: `/pets/${pet.id}`, label: pet.name } : { to: '/pets', label: t.petsTitle };
  const shownPhoto = photo === 'removed' ? null : (pet?.photo ?? null);

  return (
    <>
      <PageHead back={back} title={pet ? t.petFormEditTitle : t.petFormAddTitle} />
      <form
        ref={form}
        className="form"
        noValidate
        onSubmit={(event) => void save(event)}
        aria-busy={busy !== null || undefined}
      >
        <PhotoDrop
          name={values.name}
          photo={shownPhoto}
          preview={preview}
          editable
          busy={busy === 'photo'}
          onPick={(file) => setPhoto({ file, preview: URL.createObjectURL(file) })}
          onRemove={() => setPhoto(pet?.photo ? 'removed' : null)}
        />
        <fieldset className="form-stack" disabled={busy !== null}>
          <TextField
            label={t.petNameLabel}
            value={values.name}
            onChange={(value) => set('name', value)}
            error={errors.name}
          />
          <ChoiceGroup
            label={t.petSpeciesLabel}
            value={values.species}
            options={SPECIES.map((value) => ({ value, label: t.speciesShort[value] }))}
            onChange={(value) => set('species', value)}
          />
          <ChoiceGroup
            label={t.petSexLabel}
            value={values.sex}
            options={SEXES.map((value) => ({ value, label: t.sex[value] }))}
            onChange={(value) => set('sex', value)}
          />
          <TextField
            label={t.petBreedLabel}
            placeholder={t.petBreedHint}
            value={values.breed}
            onChange={(value) => set('breed', value)}
            error={errors.breed}
          />
          <div className="form-row">
            <DateField
              label={t.petBirthDateLabel}
              value={values.birthDate}
              max={today}
              onChange={(value) => set('birthDate', value)}
              error={errors.birthDate}
            />
            {values.birthDate && (
              <CheckboxField
                label={t.petBirthDateApproximate}
                checked={values.approximate}
                onChange={(value) => set('approximate', value)}
              />
            )}
          </div>
          <div className="form-row">
            <CheckboxField
              label={t.petNeuteredLabel}
              checked={values.neutered}
              onChange={(value) =>
                setValues((old) => ({ ...old, neutered: value, neuteredOn: value ? old.neuteredOn : '' }))
              }
            />
            {values.neutered && (
              <DateField
                label={t.petNeuteredOnLabel}
                value={values.neuteredOn}
                min={values.birthDate || undefined}
                max={today}
                onChange={(value) => set('neuteredOn', value)}
                error={errors.neuteredOn}
              />
            )}
          </div>
          <TextField
            label={t.petColorLabel}
            placeholder={t.petColorHint}
            value={values.color}
            onChange={(value) => set('color', value)}
            error={errors.color}
          />
          <TextField
            label={t.petMarkingsLabel}
            placeholder={t.petMarkingsHint}
            value={values.markings}
            onChange={(value) => set('markings', value)}
            rows={2}
            error={errors.markings}
          />
          <Section title={t.identifiersTitle}>
            <IdentifierFields
              drafts={values.identifiers}
              onChange={(identifiers) => {
                set('identifiers', identifiers);
                // The server names cards by position, which a card added or removed makes wrong.
                setServerFields((old) =>
                  Object.fromEntries(Object.entries(old).filter(([field]) => !field.startsWith('identifiers'))),
                );
              }}
              errorOf={(index, field) => errors[`identifiers[${index}].${field}`] ?? null}
              listError={errors.identifiers ?? null}
              today={today}
              reader={ai.data?.configured ? { api, freeTier: ai.data.freeTier } : null}
            />
          </Section>
          <TextField
            label={t.petAllergiesLabel}
            placeholder={t.petAllergiesHint}
            value={values.allergies}
            onChange={(value) => set('allergies', value)}
            rows={3}
            error={errors.allergies}
          />
          <TextField
            label={t.petNotesLabel}
            value={values.notes}
            onChange={(value) => set('notes', value)}
            rows={4}
            error={errors.notes}
          />
        </fieldset>
        <div className="form-foot">
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <button type="submit" className="button button--primary" disabled={busy !== null}>
            {busy && <Spinner />}
            {busy === 'photo' ? t.petPhotoUploading : busy ? t.commonSaving : t.commonSave}
          </button>
          <button
            type="button"
            className="button button--ghost"
            onClick={() => void navigate(back.to)}
            disabled={busy !== null}
          >
            {t.commonCancel}
          </button>
        </div>
      </form>
    </>
  );
}
