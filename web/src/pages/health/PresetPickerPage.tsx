// "Add plan" (the phone app's preset_picker_screen.dart): the ready-made plans for the pet's species, grouped by kind
// (GET /care-plan-presets?species), and "Own plan". Choosing one opens the plan form with it. A product that is
// toxic to cats says so in red.
import { Link, useParams } from 'react-router';
import { useCarePresets, usePet } from '../../api/queries';
import type { CarePreset } from '../../api/types';
import { Icon } from '../../components/Icon';
import { CARE_KIND_ICONS } from '../../components/kindIcons';
import { ErrorNotice, Loading, PageHead, Section } from '../../components/ui';
import { useI18n } from '../../i18n/i18n';
import { PRESET_GROUPS, presetGroupOf } from '../../lib/care';
import { intervalLabel, presetNote, presetTitle } from '../../lib/labels';
import { petTabPath } from '../pets/PetPage';

export function PresetPickerPage() {
  const { id = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(id);
  const presets = useCarePresets(pet.data?.species);
  const back = { to: petTabPath(id, 'health'), label: pet.data?.name ?? t.petTabHealth };

  let content;
  const error = pet.error ?? presets.error;
  if (error) {
    content = (
      <ErrorNotice
        error={error}
        onRetry={() => {
          void pet.refetch();
          void presets.refetch();
        }}
      />
    );
  } else if (!presets.data) {
    content = <Loading />;
  } else {
    const list = presets.data;
    content = (
      <div className="tab-sections">
        <ul className="card card--list rows">
          <li className="row row--top">
            <span className="kind-icon">
              <Icon name="edit_note" />
            </span>
            <div className="row-main">
              <Link to={`/pets/${id}/plans/new/own`} className="row-title row-link">
                {t.presetOwnTitle}
              </Link>
              <span className="row-sub">{t.presetOwnBody}</span>
            </div>
            <Icon name="chevron_right" className="row-arrow" />
          </li>
        </ul>
        {list.length === 0 && <p className="muted">{t.presetNoneForSpecies}</p>}
        <div className="preset-groups">
          {PRESET_GROUPS.map((group) => {
            const items = list.filter((preset) => presetGroupOf(preset.kind) === group);
            if (!items.length) return null;
            return (
              <Section key={group} title={t.presetGroup[group]}>
                <ul className="card card--list rows">
                  {items.map((preset) => (
                    <PresetRow key={preset.code} petId={id} preset={preset} />
                  ))}
                </ul>
              </Section>
            );
          })}
        </div>
      </div>
    );
  }

  return (
    <>
      <PageHead back={back} title={t.presetPickerTitle} />
      {content}
    </>
  );
}

function PresetRow({ petId, preset }: { petId: string; preset: CarePreset }) {
  const { t } = useI18n();
  const note = presetNote(t, preset);
  return (
    <li className="row row--top">
      <span className="kind-icon">
        <Icon name={CARE_KIND_ICONS[preset.kind]} />
      </span>
      <div className="row-main">
        <Link to={`/pets/${petId}/plans/new/${encodeURIComponent(preset.code)}`} className="row-title row-link">
          {presetTitle(t, preset)}
        </Link>
        <span className="row-sub">{intervalLabel(t, preset.intervalValue, preset.intervalUnit)}</span>
        {note && <span className="row-sub">{note}</span>}
        {preset.dogOnly && (
          <span className="row-sub danger-text with-icon">
            <Icon name="warning" size={16} />
            {t.presetDogOnly}
          </span>
        )}
      </div>
      <Icon name="chevron_right" className="row-arrow" />
    </li>
  );
}
