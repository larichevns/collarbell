// Pets: the household's cats and dogs as cards (photo, name, species and breed, age), the active ones first; archived
// and deceased pets stay, quieter and with their status. "Add pet" for everyone but helpers.
import { Link } from 'react-router';
import { usePets } from '../../api/queries';
import type { Pet } from '../../api/types';
import { Icon } from '../../components/Icon';
import { PetAvatar } from '../../components/PetAvatar';
import { Badge, EmptyState, ErrorNotice, Loading, PageHead } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { ageLabel } from '../../lib/labels';

export function PetsPage() {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const today = useHouseholdDate();
  const pets = usePets();

  let content;
  if (pets.error && !pets.data) {
    content = <ErrorNotice error={pets.error} onRetry={() => void pets.refetch()} />;
  } else if (!pets.data) {
    content = <Loading />;
  } else if (pets.data.length === 0) {
    content = (
      <EmptyState icon="pets" title={t.petsEmptyTitle}>
        {permissions.canEdit ? t.petsEmptyBody : t.petsEmptyBodyHelper}
      </EmptyState>
    );
  } else {
    // The server sends active pets first; kept so whatever happens.
    const ordered = [
      ...pets.data.filter((pet) => pet.status === 'Active'),
      ...pets.data.filter((pet) => pet.status !== 'Active'),
    ];
    content = (
      <ul className="pet-grid">
        {ordered.map((pet) => (
          <PetCard key={pet.id} pet={pet} today={today} />
        ))}
      </ul>
    );
  }

  return (
    <>
      <PageHead
        title={t.petsTitle}
        actions={
          permissions.canEdit && (
            <Link to="/pets/new" className="button button--primary">
              <Icon name="add" />
              {t.petsAdd}
            </Link>
          )
        }
      />
      {content}
    </>
  );
}

function PetCard({ pet, today }: { pet: Pet; today: string }) {
  const { t } = useI18n();
  const active = pet.status === 'Active';
  const breed = pet.breed?.trim();
  const age = pet.birthDate ? ageLabel(t, pet.birthDate, pet.birthDateApproximate, today) : null;
  return (
    <li className={`pet-card${active ? '' : ' pet-card--inactive'}`}>
      <PetAvatar name={pet.name} photo={pet.photo} size="lg" />
      <div className="pet-card-text">
        <Link to={`/pets/${pet.id}`} className="pet-card-name">
          {pet.name}
        </Link>
        <span className="muted">{[t.species[pet.species], breed].filter(Boolean).join(' · ')}</span>
        {age && <span className="muted small">{age}</span>}
        {!active && <Badge>{t.petStatus[pet.status]}</Badge>}
      </div>
      <Icon name="chevron_right" className="pet-card-arrow" />
    </li>
  );
}
