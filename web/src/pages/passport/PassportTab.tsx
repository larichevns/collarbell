// The Passport tab (the phone app's passport_tab.dart): that the digital copy is for information only; the passport's
// details (its model, number, country, date of issue, the vet who issued it and the owners); the pet's microchips; the
// photographed pages of the paper passport; and its health sections V–X, which the server builds from the records.
// Copying a paper passport is easier as a table: a card leads to the bulk entry. With AI set up on the server, the
// pages can be scanned instead: the scans waiting for someone show at the top (scans/ScanCards.tsx).
import { Link } from 'react-router';
import { usePassport, usePassportRecords } from '../../api/queries';
import type {
  CareKind,
  CareRecord,
  Passport,
  PassportContact,
  PassportRecords,
  Pet,
  VaccineTarget,
} from '../../api/types';
import { Icon } from '../../components/Icon';
import { Loaded, Notice, Section } from '../../components/ui';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { recordDateLabel } from '../../lib/labels';
import { IdentifierList } from '../pets/IdentifierList';
import { ScanEntry } from '../scans/ScanCards';
import { PassportPages } from './PassportPages';

export function PassportTab({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  return (
    <div className="tab-sections">
      <Notice>
        <p>{t.passportDisclaimer}</p>
      </Notice>
      {/* Helpers don't scan, as on the phone. */}
      {permissions.canEdit && <ScanEntry pet={pet} />}
      <PassportDetailsSection pet={pet} />
      <Section
        title={t.identifiersTitle}
        action={
          permissions.canEdit && (
            <Link to={`/pets/${pet.id}/edit`} className="button button--secondary">
              <Icon name={pet.identifiers.length ? 'edit' : 'add'} size={18} />
              {pet.identifiers.length ? t.commonEdit : t.commonAdd}
            </Link>
          )
        }
      >
        <IdentifierList identifiers={pet.identifiers} />
      </Section>
      <PassportPages pet={pet} />
      {permissions.canEdit && (
        <div className="card bulk-card">
          <Icon name="playlist_add" />
          <p>{t.bulkCard}</p>
          <Link to={`/pets/${pet.id}/records/import`} className="button button--secondary">
            {t.bulkLink}
          </Link>
        </div>
      )}
      <HealthSections pet={pet} />
    </div>
  );
}

function PassportDetailsSection({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const passport = usePassport(pet.id);
  const saved = !!passport.data?.updatedAt;
  return (
    <Section
      title={t.passportTitle}
      action={
        permissions.canEdit &&
        passport.data && (
          <Link to={`/pets/${pet.id}/passport/edit`} className="button button--secondary">
            <Icon name={saved ? 'edit' : 'add'} size={18} />
            {saved ? t.commonEdit : t.passportAdd}
          </Link>
        )
      }
    >
      <Loaded query={passport}>
        {(value) =>
          value.updatedAt ? (
            <PassportFacts passport={value} />
          ) : (
            <p className="muted">{permissions.canEdit ? t.passportEmpty : t.passportEmptyHelper}</p>
          )
        }
      </Loaded>
    </Section>
  );
}

/** A contact as lines: name, address, phone, e-mail. */
export function contactLines(contact: PassportContact): string {
  return [contact.name, contact.address, contact.phone, contact.email].filter(Boolean).join('\n');
}

function PassportFacts({ passport }: { passport: Passport }) {
  const i18n = useI18n();
  const { t } = i18n;
  const issuer = passport.issuer ? contactLines(passport.issuer) : '';
  const rows: [string, string | null, boolean][] = [
    [t.passportModelLabel, passport.model ? t.passportModel[passport.model] : null, false],
    [t.passportNumberLabel, passport.passportNumber, true],
    [t.passportCountryLabel, passport.issuingCountry, false],
    [t.passportIssuedOnLabel, passport.issuedOn ? i18n.date(passport.issuedOn) : null, false],
    [t.passportIssuerTitle, issuer || null, false],
    ...passport.owners.map((owner, index): [string, string | null, boolean] => [
      passport.owners.length === 1 ? t.passportOwnerTitle : t.passportOwnerNumbered(index + 1),
      contactLines(owner) || null,
      false,
    ]),
    [t.passportNotesLabel, passport.notes, false],
  ];
  return (
    <dl className="card facts">
      {rows
        .filter((row): row is [string, string, boolean] => !!row[1])
        .map(([label, value, code]) => (
          <div key={label} className="fact">
            <dt>{label}</dt>
            <dd className={code ? 'code' : 'pre-line'}>{value}</dd>
          </div>
        ))}
    </dl>
  );
}

type SectionKey = keyof PassportRecords;

const SECTIONS: readonly SectionKey[] = [
  'rabies',
  'rabiesTiters',
  'echinococcus',
  'treatments',
  'otherVaccinations',
  'examinations',
];

/** "Add" in a section opens the record form with its kind: a rabies vaccination, a deworming… */
const SECTION_KINDS: Record<SectionKey, { kind: CareKind; target?: VaccineTarget }> = {
  rabies: { kind: 'Vaccination', target: 'Rabies' },
  rabiesTiters: { kind: 'RabiesTiter' },
  echinococcus: { kind: 'Echinococcus' },
  treatments: { kind: 'Deworming' },
  otherVaccinations: { kind: 'Vaccination' },
  examinations: { kind: 'VetExam' },
};

/** The health sections V–X, oldest first in each, as in the paper passport. */
function HealthSections({ pet }: { pet: Pet }) {
  const records = usePassportRecords(pet.id);
  return (
    <Loaded query={records}>
      {(value) => (
        <div className="tab-sections">
          {SECTIONS.map((section) => (
            <HealthSection key={section} pet={pet} section={section} records={value[section]} />
          ))}
        </div>
      )}
    </Loaded>
  );
}

function HealthSection({ pet, section, records }: { pet: Pet; section: SectionKey; records: CareRecord[] }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const { kind, target } = SECTION_KINDS[section];
  const add = `/pets/${pet.id}/records/new?kind=${kind}${target ? `&target=${target}` : ''}&from=passport`;
  return (
    <Section
      title={t.passportSection[section]}
      action={
        permissions.canEdit && (
          <Link to={add} className="button button--secondary">
            <Icon name="add" size={18} />
            {t.commonAdd}
          </Link>
        )
      }
    >
      {records.length === 0 ? (
        <p className="muted">{t.passportSectionEmpty}</p>
      ) : (
        <ul className="card card--list rows">
          {records.map((record) => (
            <PassportRow key={record.id} pet={pet} section={section} record={record} />
          ))}
        </ul>
      )}
    </Section>
  );
}

/** A line of the paper passport: the date (with the hour of a treatment before travel), what was given, what matters. */
function PassportRow({ pet, section, record }: { pet: Pet; section: SectionKey; record: CareRecord }) {
  const i18n = useI18n();
  const { t } = i18n;
  // What was given: the product, else the title. Treatments say their kind too: the section mixes worms, fleas and
  // heartworm, unless the name says it already.
  const name = record.product ?? record.title;
  const kind = t.careKind[record.kind];
  const what = [
    section === 'treatments' && kind !== name ? kind : null,
    name,
    record.batchNumber ? t.careBatchValue(record.batchNumber) : null,
  ];
  const { validFrom, validUntil } = record;
  const details = record.details;
  const more = [
    validFrom && validUntil
      ? t.careValidRange(i18n.date(validFrom), i18n.date(validUntil))
      : validUntil
        ? t.careValidUntilValue(i18n.date(validUntil))
        : validFrom
          ? t.careValidFromValue(i18n.date(validFrom))
          : null,
    details?.titerIuPerMl != null ? t.recordTiterValue(i18n.number(details.titerIuPerMl)) : null,
    details?.laboratory ?? null,
    details?.fitForTravel === true
      ? t.recordFitForTravel
      : details?.fitForTravel === false
        ? t.recordNotFitForTravel
        : null,
    section === 'examinations' ? record.clinic : null,
  ];
  return (
    <li className="row">
      <div className="row-main">
        <span className="row-sub passport-date">{recordDateLabel(i18n, record)}</span>
        <Link to={`/pets/${pet.id}/records/${record.id}?from=passport`} className="row-title row-link">
          {what.filter(Boolean).join(' · ')}
        </Link>
        {more.some(Boolean) && <span className="row-sub">{more.filter(Boolean).join(' · ')}</span>}
      </div>
      <Icon name="chevron_right" className="row-arrow" />
    </li>
  );
}
