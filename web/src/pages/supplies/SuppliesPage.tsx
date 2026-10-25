// Supplies (the phone app's supplies_screen.dart): food, litter and medicine with how long they last, grouped as on
// the phone: what to buy now, what runs out soon, what is in stock, then what is no longer bought, each in the
// server's order (what runs out first comes first). An item to buy has "Bought" right in the list (packages, in a
// dialog); every item opens its page. "Add item" for everyone but helpers, who mark purchases. With no items yet, the
// ways to add the first one are action cards under the empty text (as the phone's): by the barcode, from photos of the
// package (with AI on the server), or by hand; each opens the new item's form there.
import { useId, useRef, useState } from 'react';
import { Link } from 'react-router';
import { useAiStatus, useSupplies } from '../../api/queries';
import type { Supply } from '../../api/types';
import { ActionCard, ActionList } from '../../components/ActionCard';
import { Icon } from '../../components/Icon';
import { SUPPLY_ICONS, SUPPLY_STATUS_ICONS } from '../../components/kindIcons';
import { EmptyState, Loaded, PageHead, Section, StatusTag } from '../../components/ui';
import { useKeepFocus } from '../../components/useKeepFocus';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { supplyStatusLine, supplyStatusTone } from '../../lib/labels';
import { groupSupplies, needsBuying } from '../../lib/supplies';
import { StockDialog } from './StockDialog';

export function SuppliesPage() {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const supplies = useSupplies();
  const ai = useAiStatus().data?.configured ?? false;
  const [buying, setBuying] = useState<Supply | null>(null);
  // Bought: the item moves to another group, and the focus goes to the row now in its place.
  const groups = useRef<HTMLDivElement>(null);
  useKeepFocus(groups);

  return (
    <>
      <PageHead
        title={t.suppliesTitle}
        actions={
          // Empty (or still loading): the first item's cards are below instead.
          permissions.canEdit &&
          (supplies.data ? supplies.data.length > 0 : !!supplies.error) && (
            <Link to="/supplies/new" className="button button--primary">
              <Icon name="add" />
              {t.suppliesAdd}
            </Link>
          )
        }
      />
      <Loaded query={supplies}>
        {(items) =>
          items.length === 0 ? (
            <EmptyState
              icon="inventory_2"
              title={t.suppliesEmptyTitle}
              actions={
                permissions.canEdit && (
                  <ActionList>
                    <ActionCard
                      icon="barcode_scanner"
                      title={t.supplyAddByBarcode}
                      hint={t.supplyAddByBarcodeHelper}
                      to="/supplies/new?start=barcode"
                    />
                    {ai && (
                      <ActionCard
                        icon="photo_camera"
                        title={t.supplyAddByPhoto}
                        hint={t.supplyAddByPhotoHelper}
                        to="/supplies/new?start=photos"
                      />
                    )}
                    <ActionCard
                      icon="edit"
                      title={t.supplyAddByHand}
                      hint={t.supplyAddByHandHelper}
                      to="/supplies/new"
                    />
                  </ActionList>
                )
              }
            >
              {permissions.canEdit ? t.suppliesEmptyBody : t.suppliesEmptyBodyHelper}
            </EmptyState>
          ) : (
            <div className="tab-sections" ref={groups}>
              {groupSupplies(items).map(([group, list]) => (
                <Section key={group} title={t.supplyGroup[group]}>
                  <ul className="card card--list rows">
                    {list.map((item) => (
                      <SupplyRow key={item.id} supply={item} onBought={() => setBuying(item)} />
                    ))}
                  </ul>
                </Section>
              ))}
            </div>
          )
        }
      </Loaded>
      {buying && (
        <StockDialog
          target={{ ...buying, remaining: buying.forecast.remaining }}
          kind="Purchase"
          onClose={() => setBuying(null)}
        />
      )}
    </>
  );
}

/** An item: its kind, name and brand, how long it lasts, and "Bought" when it's time to buy it. */
function SupplyRow({ supply, onBought }: { supply: Supply; onBought: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const nameId = useId();
  const tone = supplyStatusTone(supply);
  return (
    <li className="row">
      <span className={`type-icon${supply.active ? '' : ' type-icon--muted'}`}>
        <Icon name={SUPPLY_ICONS[supply.category]} />
      </span>
      <div className="row-main">
        <Link to={`/supplies/${supply.id}`} className="row-title row-link" id={nameId}>
          {supply.name}
        </Link>
        {supply.brand && <span className="row-sub">{supply.brand}</span>}
        {tone === 'muted' ? (
          <span className="row-sub">{supplyStatusLine(i18n, supply)}</span>
        ) : (
          <StatusTag tone={tone} icon={SUPPLY_STATUS_ICONS[tone]}>
            {supplyStatusLine(i18n, supply)}
          </StatusTag>
        )}
      </div>
      <div className="row-actions">
        {needsBuying(supply) ? (
          <button
            type="button"
            className="button button--tonal"
            aria-describedby={nameId}
            onClick={onBought}
          >
            {t.supplyBought}
          </button>
        ) : (
          <Icon name="chevron_right" className="row-arrow" />
        )}
      </div>
    </li>
  );
}
