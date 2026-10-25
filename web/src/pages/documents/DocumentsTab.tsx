// The Documents tab (the phone app's documents_tab.dart): every document of the pet by type (lab results,
// prescriptions, certificates, the passport's pages…), newest first in each, with its first page, title, date and
// number of pages. Those who change things drop scans, photos or PDF files onto the tab (or pick them): a new document
// opens with them as its pages, in that order, to get its type, title and date.
import { useState } from 'react';
import { Link } from 'react-router';
import { isPdf } from '../../api/files';
import { useDocuments } from '../../api/queries';
import type { Pet, PetDocument } from '../../api/types';
import { FileDrop, FileImage } from '../../components/Files';
import { Icon } from '../../components/Icon';
import { DOCUMENT_TYPE_ICONS } from '../../components/kindIcons';
import { EmptyState, Loaded, Section } from '../../components/ui';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { todayIn } from '../../lib/dates';
import { documentsByType, documentTitle } from '../../lib/documents';
import { NewDocumentDialog } from './DocumentDialogs';

export function DocumentsTab({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const documents = useDocuments(pet.id);
  const [adding, setAdding] = useState<File[] | null>(null);

  const list = (
    <Loaded query={documents}>
      {(value) =>
        value.length === 0 ? (
          <EmptyState icon="description" title={t.documentsEmptyTitle}>
            {t.documentsEmptyBody}
          </EmptyState>
        ) : (
          <div className="tab-sections">
            {documentsByType(value).map(([type, items]) => (
              <Section key={type} title={t.documentType[type]}>
                <ul className="card card--list rows">
                  {items.map((document) => (
                    <DocumentRow key={document.id} pet={pet} document={document} />
                  ))}
                </ul>
              </Section>
            ))}
          </div>
        )
      }
    </Loaded>
  );

  return (
    <div className="tab-sections">
      {permissions.canEdit ? (
        <FileDrop primary buttonLabel={t.documentsAdd} hint={t.documentsDrop} onFiles={setAdding}>
          {list}
        </FileDrop>
      ) : (
        list
      )}
      {adding && <NewDocumentDialog pet={pet} files={adding} onClose={() => setAdding(null)} />}
    </div>
  );
}

/** A document: its first page small (or a PDF's mark), its title or type, its date and number of pages. */
function DocumentRow({ pet, document }: { pet: Pet; document: PetDocument }) {
  const i18n = useI18n();
  const { t } = i18n;
  const { current } = useHousehold();
  const first = document.pages[0];
  const hasTitle = !!document.title?.trim();
  const date = document.documentDate ?? todayIn(current.timeZone, new Date(document.createdAt));
  const details = [
    // Without a title, the type is the row's title already.
    hasTitle ? t.documentType[document.type] : null,
    i18n.date(date),
    t.documentPageCount(document.pages.length),
  ];
  return (
    <li className="row">
      <span className="document-thumb" aria-hidden="true">
        {first && !isPdf(first) ? (
          <FileImage file={first} thumbnail alt="" />
        ) : (
          <Icon name={first ? 'picture_as_pdf' : DOCUMENT_TYPE_ICONS[document.type]} />
        )}
      </span>
      <div className="row-main">
        <Link to={`/pets/${pet.id}/documents/${document.id}`} className="row-title row-link">
          {documentTitle(t, document)}
        </Link>
        <span className="row-sub">{details.filter(Boolean).join(' · ')}</span>
      </div>
      <Icon name="chevron_right" className="row-arrow" />
    </li>
  );
}
