// "Which pet?" (the phone app's pet_picker.dart), for an action that needs a pet: Home's quick actions and the first
// steps. With one active pet the action goes straight to it; with several a dialog lists them, a face and a name each,
// to pick from; with none there is nothing to do it for, and the new pet's form opens instead.
import { useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router';
import type { Pet } from '../../api/types';
import { Dialog, DialogBody } from '../../components/Dialog';
import { PetAvatar } from '../../components/PetAvatar';
import { useI18n } from '../../i18n/i18n';

export interface PetChoice {
  /** Does `action` for a pet of `pets`: at once for the only one, after asking for several. */
  choose: (pets: readonly Pet[], action: (pet: Pet) => void) => void;
  /**
   * An action card's target for a page of a pet: the page itself (a link) for the only pet, else a press that asks
   * which pet first.
   */
  target: (pets: readonly Pet[], path: (pet: Pet) => string) => { to: string } | { onClick: () => void };
  /** The question, while it is asked: to render next to the cards. */
  dialog: ReactNode;
}

export function usePetChoice(): PetChoice {
  const navigate = useNavigate();
  const [asking, setAsking] = useState<{ pets: readonly Pet[]; action: (pet: Pet) => void } | null>(null);

  const choose: PetChoice['choose'] = (pets, action) => {
    if (pets.length === 0) void navigate('/pets/new');
    else if (pets.length === 1) action(pets[0]!);
    else setAsking({ pets, action });
  };

  return {
    choose,
    target: (pets, path) =>
      pets.length === 1
        ? { to: path(pets[0]!) }
        : { onClick: () => choose(pets, (pet) => void navigate(path(pet))) },
    dialog: asking && (
      <PetPickerDialog
        pets={asking.pets}
        onPick={(pet) => {
          setAsking(null);
          asking.action(pet);
        }}
        onClose={() => setAsking(null)}
      />
    ),
  };
}

function PetPickerDialog({
  pets,
  onPick,
  onClose,
}: {
  pets: readonly Pet[];
  onPick: (pet: Pet) => void;
  onClose: () => void;
}) {
  const { t } = useI18n();
  return (
    <Dialog title={t.homePickPet} onClose={onClose}>
      <DialogBody>
        <ul className="pick-pets plain-list">
          {pets.map((pet) => (
            <li key={pet.id}>
              <button type="button" className="pick-pet" onClick={() => onPick(pet)}>
                <PetAvatar name={pet.name} photo={pet.photo} />
                <span className="pick-pet-name">{pet.name}</span>
              </button>
            </li>
          ))}
        </ul>
      </DialogBody>
    </Dialog>
  );
}
