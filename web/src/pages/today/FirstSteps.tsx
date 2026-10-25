// What to set up first, when nothing is planned yet (the phone app's TodayFirstSteps): on an empty Today, and on Home
// when the pets have nothing set up. Nothing can be planned without a pet, so that comes first, as the page's main
// button; with pets, action cards for their feeding and their care plan (vaccinations, treatments), and on Today a
// visit, which needs no plan (Home's quick actions have one). A card for one pet opens its form; for several it asks
// which pet first. Helpers don't set things up: for them it only says what will show here.
import { Link } from 'react-router';
import { usePets } from '../../api/queries';
import type { Pet } from '../../api/types';
import { ActionCard, ActionList } from '../../components/ActionCard';
import { Icon } from '../../components/Icon';
import { EmptyState, ErrorNotice, Loading } from '../../components/ui';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { usePetChoice } from '../home/PetPicker';

/** Today with nothing on it: the pet first, else what to plan for the pets. */
export function TodayFirstSteps() {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const query = usePets();
  const pets = query.data;
  if (!pets) {
    return query.error ? <ErrorNotice error={query.error} onRetry={() => void query.refetch()} /> : <Loading />;
  }
  const active = pets.filter((pet) => pet.status === 'Active');
  if (active.length === 0) {
    return (
      <EmptyState
        icon="pets"
        title={permissions.canEdit ? t.todayStartTitle : t.petsEmptyTitle}
        actions={
          permissions.canEdit && (
            <Link to="/pets/new" className="button button--primary">
              <Icon name="add" />
              {t.petsAdd}
            </Link>
          )
        }
      >
        {permissions.canEdit ? t.todayStartBody : t.todayStartBodyHelper}
      </EmptyState>
    );
  }
  return (
    <EmptyState
      icon="event_available"
      title={t.todayEmptyTitle}
      actions={permissions.canEdit && <FirstStepCards pets={active} visit />}
    >
      {t.todayEmptyBody}
    </EmptyState>
  );
}

/** The cards of the first steps for the household's active `pets`; `visit`: with "Add a visit". */
export function FirstStepCards({ pets, visit = false }: { pets: readonly Pet[]; visit?: boolean }) {
  const { t } = useI18n();
  const choice = usePetChoice();
  return (
    <>
      <ActionList>
        <ActionCard
          icon="restaurant"
          title={t.todayAddFeeding}
          hint={t.todayAddFeedingHint}
          {...choice.target(pets, (pet) => `/pets/${pet.id}/feeding/new`)}
        />
        <ActionCard
          icon="vaccines"
          title={t.todayAddCare}
          hint={t.todayAddCareHint}
          {...choice.target(pets, (pet) => `/pets/${pet.id}/plans/new`)}
        />
        {visit && <ActionCard icon="stethoscope" title={t.visitAddCard} hint={t.visitAddCardHint} to="/visits/new" />}
      </ActionList>
      {choice.dialog}
    </>
  );
}
