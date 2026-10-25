// A pet's page: the name, "Edit details" and "Delete pet" (not for helpers), and the pet's sections as tabs: Overview,
// Health, Passport, Documents, Feeding and Weight. Each tab has its own address (/pets/42/health), so a link, a reload
// and Back keep it; switching tabs replaces the address rather than adding to the history. The tabs follow the ARIA
// pattern: the arrow keys, Home and End move between them, Enter opens one.
import { useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState, type KeyboardEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { errorMessage, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { usePet } from '../../api/queries';
import type { Pet } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import { Icon } from '../../components/Icon';
import { ErrorNotice, Loading, Notice, PageHead } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import type { Messages } from '../../i18n/en';
import { DocumentsTab } from '../documents/DocumentsTab';
import { FeedingTab } from '../feeding/FeedingTab';
import { HealthTab } from '../health/HealthTab';
import { PassportTab } from '../passport/PassportTab';
import { WeightTab } from '../weight/WeightTab';
import { PetOverview } from './PetOverview';

export type PetTab = 'overview' | 'health' | 'passport' | 'documents' | 'feeding' | 'weight';

export const PET_TABS: readonly PetTab[] = ['overview', 'health', 'passport', 'documents', 'feeding', 'weight'];

const TAB_LABELS: Record<PetTab, keyof Messages> = {
  overview: 'petTabOverview',
  health: 'petTabHealth',
  passport: 'petTabPassport',
  documents: 'petTabDocuments',
  feeding: 'petTabFeeding',
  weight: 'petTabWeight',
};

/** The address of a pet's tab: "/pets/42" for Overview, "/pets/42/health" for the others. */
export function petTabPath(petId: string, tab: PetTab): string {
  return tab === 'overview' ? `/pets/${petId}` : `/pets/${petId}/${tab}`;
}

export function PetPage({ tab = 'overview' }: { tab?: PetTab }) {
  const { id = '' } = useParams();
  const { t } = useI18n();
  const api = useApi();
  const { current, permissions } = useHousehold();
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const pet = usePet(id);
  const tabsId = useId();
  const tabRefs = useRef(new Map<PetTab, HTMLAnchorElement>());
  const [deleting, setDeleting] = useState(false);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [deleteError, setDeleteError] = useState<unknown>(null);

  const back = { to: '/pets', label: t.petsTitle };
  // Deleted (here or on another phone): the old copy is not shown as if the pet were there.
  if (!pet.data || isNotFound(pet.error)) {
    return (
      <>
        <PageHead back={back} title={t.petsTitle} />
        {pet.error ? <ErrorNotice error={pet.error} onRetry={() => void pet.refetch()} /> : <Loading />}
      </>
    );
  }
  const { name } = pet.data;

  async function remove() {
    setDeleteBusy(true);
    setDeleteError(null);
    try {
      await api.DELETE('/api/v1/pets/{id}', { params: { path: { id } } });
      // Gone from the list at once, and its own copy forgotten; the list and Today (its plans and feedings leave too)
      // are read again.
      queryClient.setQueryData<Pet[]>(keys.pets(current.id), (old) => old?.filter((other) => other.id !== id));
      queryClient.removeQueries({ queryKey: keys.pet(current.id, id), exact: true });
      void navigate('/pets');
      void queryClient.invalidateQueries({ queryKey: keys.pets(current.id), exact: true });
      void queryClient.invalidateQueries({ queryKey: keys.todayAll(current.id) });
    } catch (error) {
      setDeleteError(error);
      setDeleteBusy(false);
    }
  }

  /** The arrow keys, Home and End move the focus between the tabs; Enter (a link's own key) opens one. */
  function moveFocus(event: KeyboardEvent<HTMLDivElement>) {
    const at = PET_TABS.indexOf(
      PET_TABS.find((candidate) => tabRefs.current.get(candidate) === document.activeElement) ?? tab,
    );
    const next =
      event.key === 'ArrowRight'
        ? (at + 1) % PET_TABS.length
        : event.key === 'ArrowLeft'
          ? (at - 1 + PET_TABS.length) % PET_TABS.length
          : event.key === 'Home'
            ? 0
            : event.key === 'End'
              ? PET_TABS.length - 1
              : null;
    if (next === null) return;
    event.preventDefault();
    tabRefs.current.get(PET_TABS[next]!)?.focus();
  }

  const tabId = (each: PetTab) => `${tabsId}-${each}`;
  return (
    <>
      <PageHead
        back={back}
        title={name}
        actions={
          permissions.canEdit && (
            <>
              <Link to={`/pets/${id}/edit`} className="button button--secondary">
                <Icon name="edit" />
                {t.petEdit}
              </Link>
              <button
                type="button"
                className="button button--ghost button--danger-text"
                onClick={() => setDeleting(true)}
              >
                <Icon name="delete" />
                {t.petDelete}
              </button>
            </>
          )
        }
      />
      <div className="tabs">
        <div role="tablist" aria-label={t.petTabs} className="tablist" onKeyDown={moveFocus}>
          {PET_TABS.map((each) => (
            <Link
              key={each}
              ref={(element) => {
                if (element) tabRefs.current.set(each, element);
                else tabRefs.current.delete(each);
              }}
              to={petTabPath(id, each)}
              replace
              role="tab"
              id={tabId(each)}
              aria-selected={each === tab}
              aria-controls={`${tabsId}-panel`}
              tabIndex={each === tab ? 0 : -1}
              className="tab"
              onKeyDown={(event) => {
                // Space opens a tab too, as it presses a button.
                if (event.key === ' ') {
                  event.preventDefault();
                  event.currentTarget.click();
                }
              }}
            >
              {t[TAB_LABELS[each]] as string}
            </Link>
          ))}
        </div>
      </div>
      <div role="tabpanel" id={`${tabsId}-panel`} aria-labelledby={tabId(tab)} className="tabpanel">
        {tab === 'overview' && <PetOverview pet={pet.data} />}
        {tab === 'health' && <HealthTab pet={pet.data} />}
        {tab === 'passport' && <PassportTab pet={pet.data} />}
        {tab === 'documents' && <DocumentsTab pet={pet.data} />}
        {tab === 'feeding' && <FeedingTab pet={pet.data} />}
        {tab === 'weight' && <WeightTab pet={pet.data} />}
      </div>
      {deleting && (
        <ConfirmDialog
          title={t.petDeleteTitle(name)}
          body={t.petDeleteBody}
          confirmLabel={t.commonDelete}
          danger
          busy={deleteBusy}
          error={deleteError ? <Notice tone="danger">{errorMessage(t, deleteError)}</Notice> : null}
          onConfirm={() => void remove()}
          onCancel={() => {
            setDeleting(false);
            setDeleteError(null);
          }}
        />
      )}
    </>
  );
}
