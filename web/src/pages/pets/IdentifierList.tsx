// A pet's microchips and tattoos as the passport prints them: the type, the code (an ISO number in groups of three),
// when it was implanted or applied and where. The Overview and the Passport tab show it; the pet form edits it.
import type { Pet } from '../../api/types';
import { StatusTag } from '../../components/ui';
import { useI18n } from '../../i18n/i18n';
import { displayCode } from '../../lib/identifiers';

export function IdentifierList({ identifiers }: { identifiers: Pet['identifiers'] }) {
  const i18n = useI18n();
  const { t } = i18n;
  if (identifiers.length === 0) return <p className="muted">{t.identifiersEmpty}</p>;
  return (
    <ul className="card card--list rows">
      {identifiers.map((identifier) => (
        <li key={identifier.id} className="row">
          <div className="row-main">
            <span className="row-sub">{t.identifierType[identifier.type]}</span>
            <span className="row-title code">{displayCode(identifier.type, identifier.code)}</span>
            {(identifier.appliedOn || identifier.location) && (
              <span className="row-sub">
                {[
                  identifier.appliedOn &&
                    (identifier.type === 'Tattoo' ? t.identifierTattooAppliedOn : t.identifierChipImplantedOn)(
                      i18n.date(identifier.appliedOn),
                    ),
                  identifier.location,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </span>
            )}
            {identifier.type === 'LegacyChip' && (
              <StatusTag tone="warning" icon="warning">
                {t.identifierLegacyHint}
              </StatusTag>
            )}
          </div>
        </li>
      ))}
    </ul>
  );
}
