// The passport's details (the phone app's passport_form_screen.dart): its model, number and issuing country, the date
// of issue, the vet who issued it, up to two owners as in section I, and notes. The number and the country are checked
// as the server checks them; an empty contact is dropped by the server. Saving replaces the details (PUT).
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type FormEvent } from 'react';
import { useNavigate, useParams } from 'react-router';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { usePassport, usePet } from '../../api/queries';
import type { Passport, PassportContact, PassportModel, PassportRequest, Pet } from '../../api/types';
import { DateField, SelectField, TextField, useFocusFirstError } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { useKeepFocus } from '../../components/useKeepFocus';
import { ErrorNotice, Loading, PageHead, Section, Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import {
  countryOk,
  MAX_OWNERS,
  normalizePassportNumber,
  PASSPORT_MAX,
  PASSPORT_MODELS,
  passportNumberOk,
} from '../../lib/passport';
import { petTabPath } from '../pets/PetPage';

/** The server's field names this form shows under a field; anything else is said over "Save". */
const FIELDS =
  /^(model|passportNumber|issuingCountry|issuedOn|notes|(issuer|owners\[\d+\])\.(name|address|phone|email))$/;

export function PassportFormPage() {
  const { id = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(id);
  const passport = usePassport(id);
  if (pet.data && passport.data && !isNotFound(pet.error) && !isNotFound(passport.error)) {
    return <PassportForm pet={pet.data} passport={passport.data} />;
  }
  return (
    <>
      <PageHead back={{ to: petTabPath(id, 'passport'), label: t.petTabPassport }} title={t.passportFormTitle} />
      {pet.error || passport.error ? (
        <ErrorNotice
          error={pet.error ?? passport.error}
          onRetry={() => {
            void pet.refetch();
            void passport.refetch();
          }}
        />
      ) : (
        <Loading />
      )}
    </>
  );
}

interface ContactDraft {
  key: string;
  name: string;
  address: string;
  phone: string;
  email: string;
}

const draftOf = (contact: PassportContact | null): ContactDraft => ({
  key: crypto.randomUUID(),
  name: contact?.name ?? '',
  address: contact?.address ?? '',
  phone: contact?.phone ?? '',
  email: contact?.email ?? '',
});

interface Values {
  model: PassportModel | '';
  number: string;
  country: string;
  issuedOn: string;
  issuer: ContactDraft;
  owners: ContactDraft[];
  notes: string;
}

/** What a form holds, to tell whether leaving loses anything: the cards without their keys. */
const snapshot = (values: Values) =>
  JSON.stringify(values, (key, value: unknown) => (key === 'key' ? undefined : value));

function PassportForm({ pet, passport }: { pet: Pet; passport: Passport }) {
  const { t } = useI18n();
  const { current } = useHousehold();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const today = useHouseholdDate();
  const form = useRef<HTMLFormElement>(null);
  const [values, setValues] = useState<Values>(() => ({
    model: passport.model ?? '',
    number: passport.passportNumber ?? '',
    country: passport.issuingCountry ?? '',
    issuedOn: passport.issuedOn ?? '',
    issuer: draftOf(passport.issuer),
    owners: passport.owners.map(draftOf),
    notes: passport.notes ?? '',
  }));
  const [opened] = useState(() => snapshot(values));
  const [submitted, setSubmitted] = useState(0);
  const [busy, setBusy] = useState(false);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  const { allowLeave } = useLeaveGuard(snapshot(values) !== opened, busy);
  const stillHere = useStillHere(household);
  useFocusFirstError(form, submitted);
  // An owner removed: the focus goes to the owner now in their place, or to "Add owner" when none is left.
  const ownerCards = useRef<HTMLDivElement>(null);
  useKeepFocus(ownerCards, {
    item: 'fieldset.identifier',
    fallback: () => ownerCards.current?.querySelector<HTMLElement>(':scope > button'),
  });
  const passportPath = petTabPath(pet.id, 'passport');

  const set = <K extends keyof Values>(field: K, value: Values[K]) => setValues((old) => ({ ...old, [field]: value }));

  function problems(refused: Record<string, string[]>): Record<string, string | null> {
    const server = (field: string) => (refused[field] ? t.formServerFieldError : null);
    const tooLong = (value: string, max: number, field: string) =>
      value.trim().length > max ? t.formTooLong(max) : server(field);
    const contact = (draft: ContactDraft, prefix: string) => ({
      [`${prefix}.name`]: tooLong(draft.name, PASSPORT_MAX.name, `${prefix}.name`),
      [`${prefix}.address`]: tooLong(draft.address, PASSPORT_MAX.address, `${prefix}.address`),
      [`${prefix}.phone`]: tooLong(draft.phone, PASSPORT_MAX.phone, `${prefix}.phone`),
      [`${prefix}.email`]:
        // Like the server and the phone app: an address with an "@" (vets' addresses aren't always ordinary).
        draft.email.trim() && !draft.email.includes('@')
          ? t.emailInvalid
          : tooLong(draft.email, PASSPORT_MAX.email, `${prefix}.email`),
    });
    return {
      model: server('model'),
      passportNumber: passportNumberOk(values.number) ? server('passportNumber') : t.passportNumberInvalid,
      issuingCountry: countryOk(values.country) ? server('issuingCountry') : t.passportCountryInvalid,
      issuedOn: values.issuedOn > today ? t.dateInFuture : server('issuedOn'),
      notes: tooLong(values.notes, PASSPORT_MAX.notes, 'notes'),
      ...contact(values.issuer, 'issuer'),
      ...Object.assign({}, ...values.owners.map((owner, index) => contact(owner, `owners[${index}]`))),
    };
  }
  const errors = problems(serverFields);

  function request(): PassportRequest {
    const clean = (value: string) => value.trim() || null;
    const contact = (draft: ContactDraft): PassportContact => ({
      name: clean(draft.name),
      address: clean(draft.address),
      phone: clean(draft.phone),
      email: clean(draft.email),
    });
    const issuer = contact(values.issuer);
    return {
      model: values.model || null,
      passportNumber: clean(normalizePassportNumber(values.number)),
      issuingCountry: clean(values.country)?.toUpperCase() ?? null,
      issuedOn: values.issuedOn || null,
      issuer: Object.values(issuer).some(Boolean) ? issuer : null,
      // Every card as it is, empty ones too (the server drops those), so an error for owners[1] is the second card's.
      owners: values.owners.map(contact),
      notes: clean(values.notes),
    };
  }

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setSubmitted((value) => value + 1);
    setServerFields({});
    setFailure(null);
    if (Object.values(problems({})).some(Boolean)) {
      setFailure(t.formCheckFields);
      return;
    }
    setBusy(true);
    try {
      await api.PUT('/api/v1/pets/{id}/passport', { params: { path: { id: pet.id } }, body: request() });
      void queryClient.invalidateQueries({ queryKey: keys.passport(household, pet.id) });
      allowLeave();
      if (stillHere()) void navigate(passportPath);
    } catch (error) {
      void queryClient.invalidateQueries({ queryKey: keys.passport(household, pet.id) });
      if (isNotFound(error)) {
        toast(t.careGonePet);
        allowLeave();
        if (stillHere()) void navigate('/pets');
        return;
      }
      const fields = fieldErrorsOf(error);
      const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => FIELDS.test(field));
      setServerFields(placed ? fields : {});
      setFailure(placed ? t.formCheckFields : errorMessage(t, error));
      if (placed) setSubmitted((value) => value + 1);
      setBusy(false);
    }
  }

  /** Name, address, phone and e-mail of a contact; `prefix` is its name in the server's errors. */
  const contactFields = (draft: ContactDraft, prefix: string, change: (draft: ContactDraft) => void) => (
    <div className="form-stack">
      <TextField
        label={t.contactNameLabel}
        value={draft.name}
        onChange={(name) => change({ ...draft, name })}
        error={errors[`${prefix}.name`]}
      />
      <TextField
        label={t.contactAddressLabel}
        value={draft.address}
        rows={3}
        onChange={(address) => change({ ...draft, address })}
        error={errors[`${prefix}.address`]}
      />
      <div className="form-row">
        <TextField
          label={t.contactPhoneLabel}
          value={draft.phone}
          autoComplete="off"
          onChange={(phone) => change({ ...draft, phone })}
          error={errors[`${prefix}.phone`]}
        />
        <TextField
          label={t.contactEmailLabel}
          type="email"
          placeholder={t.emailHint}
          value={draft.email}
          autoComplete="off"
          onChange={(email) => change({ ...draft, email })}
          error={errors[`${prefix}.email`]}
        />
      </div>
    </div>
  );

  return (
    <>
      <PageHead back={{ to: passportPath, label: pet.name }} title={t.passportFormTitle} />
      <form ref={form} className="form" noValidate onSubmit={(event) => void save(event)} aria-busy={busy || undefined}>
        <fieldset className="form-stack" disabled={busy}>
          <SelectField
            label={t.passportModelLabel}
            value={values.model}
            options={[
              { value: '' as const, label: t.passportModelNotSet },
              ...PASSPORT_MODELS.map((model) => ({ value: model, label: t.passportModel[model] })),
            ]}
            onChange={(model) => set('model', model)}
            error={errors.model}
          />
          <div className="form-row">
            <TextField
              label={t.passportNumberLabel}
              placeholder={t.passportNumberHint}
              value={values.number}
              code
              autoComplete="off"
              onChange={(number) => set('number', number)}
              error={errors.passportNumber}
            />
            <TextField
              label={t.passportCountryLabel}
              placeholder={t.passportCountryHint}
              value={values.country}
              autoComplete="off"
              onChange={(country) => set('country', country)}
              error={errors.issuingCountry}
            />
          </div>
          <DateField
            label={t.passportIssuedOnLabel}
            value={values.issuedOn}
            max={today}
            onChange={(issuedOn) => set('issuedOn', issuedOn)}
            error={errors.issuedOn}
          />
          <Section title={t.passportIssuerTitle}>
            {contactFields(values.issuer, 'issuer', (issuer) => set('issuer', issuer))}
          </Section>
          <Section title={t.passportOwnersTitle}>
            <div className="identifiers" ref={ownerCards}>
              {values.owners.map((owner, index) => (
                <fieldset key={owner.key} className="identifier">
                  <legend className="visually-hidden">{t.passportOwnerNumbered(index + 1)}</legend>
                  <div className="identifier-head">
                    <p className="identifier-title">{t.passportOwnerNumbered(index + 1)}</p>
                    <button
                      type="button"
                      className="icon-button"
                      aria-label={t.passportOwnerRemove(index + 1)}
                      title={t.passportOwnerRemove(index + 1)}
                      onClick={() => {
                        set(
                          'owners',
                          values.owners.filter((each) => each.key !== owner.key),
                        );
                        // The server names owners by position, which a removal makes wrong.
                        setServerFields((old) =>
                          Object.fromEntries(Object.entries(old).filter(([field]) => !field.startsWith('owners'))),
                        );
                      }}
                    >
                      <Icon name="delete" />
                    </button>
                  </div>
                  {contactFields(owner, `owners[${index}]`, (changed) =>
                    set(
                      'owners',
                      values.owners.map((each) => (each.key === owner.key ? changed : each)),
                    ),
                  )}
                </fieldset>
              ))}
              {values.owners.length < MAX_OWNERS && (
                <button
                  type="button"
                  className="button button--secondary"
                  onClick={() => set('owners', [...values.owners, draftOf(null)])}
                >
                  <Icon name="add" size={18} />
                  {t.passportOwnerAdd}
                </button>
              )}
            </div>
          </Section>
          <TextField
            label={t.passportNotesLabel}
            value={values.notes}
            rows={5}
            onChange={(notes) => set('notes', notes)}
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
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {busy ? t.commonSaving : t.commonSave}
          </button>
          <button
            type="button"
            className="button button--ghost"
            onClick={() => void navigate(passportPath)}
            disabled={busy}
          >
            {t.commonCancel}
          </button>
        </div>
      </form>
    </>
  );
}
