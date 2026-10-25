// The Overview tab: the photo, which takes a new one dragged onto it or picked (POST /files, then PUT /pets/{id}/photo)
// and can be removed, the pet's details, and its microchips and tattoos. Helpers see it all and change nothing.
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { errorMessage } from '../../api/errors';
import { uploadFile } from '../../api/files';
import { keys } from '../../api/keys';
import type { Pet } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import { PhotoDrop } from '../../components/PhotoDrop';
import { Section } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { ageLabel } from '../../lib/labels';
import { IdentifierList } from './IdentifierList';

export function PetOverview({ pet }: { pet: Pet }) {
  const i18n = useI18n();
  const { t } = i18n;
  const api = useApi();
  const { current, permissions } = useHousehold();
  const queryClient = useQueryClient();
  const today = useHouseholdDate();
  const [busy, setBusy] = useState(false);
  const [photoError, setPhotoError] = useState<string | null>(null);
  const [removing, setRemoving] = useState(false);

  /** The pet, the list and Today show the photo: all read again. */
  const refresh = () =>
    Promise.all([
      queryClient.invalidateQueries({ queryKey: keys.pets(current.id) }),
      queryClient.invalidateQueries({ queryKey: keys.todayAll(current.id) }),
    ]);

  async function change(run: () => Promise<unknown>) {
    setBusy(true);
    setPhotoError(null);
    try {
      await run();
      await refresh();
    } catch (error) {
      setPhotoError(errorMessage(t, error));
    } finally {
      setBusy(false);
    }
  }

  const upload = (file: File) =>
    change(async () => {
      const uploaded = await uploadFile(api, file);
      await api.PUT('/api/v1/pets/{id}/photo', { params: { path: { id: pet.id } }, body: { fileId: uploaded.id } });
    });

  const remove = () => {
    setRemoving(false);
    void change(() => api.DELETE('/api/v1/pets/{id}/photo', { params: { path: { id: pet.id } } }));
  };

  return (
    <div className="pet-overview">
      <PhotoDrop
        name={pet.name}
        photo={pet.photo}
        editable={permissions.canEdit}
        busy={busy}
        error={photoError}
        onPick={(file) => void upload(file)}
        onRemove={() => setRemoving(true)}
      />
      <div className="pet-overview-text">
        <Section title={t.petDetailsTitle}>
          <PetDetails pet={pet} today={today} />
        </Section>
        <Section title={t.identifiersTitle}>
          <IdentifierList identifiers={pet.identifiers} />
        </Section>
      </div>
      {removing && (
        <ConfirmDialog
          title={t.petPhotoRemoveTitle}
          body={t.petPhotoRemoveBody}
          confirmLabel={t.commonRemove}
          danger
          onConfirm={remove}
          onCancel={() => setRemoving(false)}
        />
      )}
    </div>
  );
}

/** The filled-in details, one fact per row; what isn't filled in is left out. */
function PetDetails({ pet, today }: { pet: Pet; today: string }) {
  const i18n = useI18n();
  const { t } = i18n;
  const text = (value: string | null) => value?.trim() || null;
  const born = pet.birthDate;
  const rows: [string, string | null][] = [
    [t.petSpeciesLabel, t.species[pet.species]],
    [t.petSexLabel, t.sex[pet.sex]],
    [t.petBreedLabel, text(pet.breed)],
    [
      t.petBirthDateLabel,
      born && (pet.birthDateApproximate ? t.petBirthDateAbout(i18n.date(born)) : i18n.date(born)),
    ],
    [t.petAgeLabel, born && ageLabel(t, born, pet.birthDateApproximate, today)],
    [
      t.petNeuteredLabel,
      pet.neutered === null
        ? null
        : pet.neutered
          ? pet.neuteredOn
            ? t.petNeuteredOnValue(i18n.date(pet.neuteredOn))
            : t.commonYes
          : t.commonNo,
    ],
    [t.petColorLabel, text(pet.color)],
    [t.petMarkingsLabel, text(pet.markings)],
    [t.petAllergiesLabel, text(pet.allergies)],
    [t.petNotesLabel, text(pet.notes)],
  ];
  return (
    <dl className="card facts">
      {rows
        .filter((row): row is [string, string] => !!row[1])
        .map(([label, value]) => (
          <div key={label} className="fact">
            <dt>{label}</dt>
            <dd>{value}</dd>
          </div>
        ))}
    </dl>
  );
}
