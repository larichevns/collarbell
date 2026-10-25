// "To buy" on Today: supplies that ran out or run out within their delivery time, with "Bought"; each opens its page
// in Supplies. On Today "Bought" is one package at once (the stock-event POST with the package's size); the item's page
// and the Supplies list take any number. A retry after a lost answer, within a minute, sends the same request id, so
// one purchase is never counted twice; a later "Bought" is another purchase, never merged into an old lost one.
import { useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { Link } from 'react-router';
import { useKeepFocus } from '../../components/useKeepFocus';
import { errorMessage, isNotFound } from '../../api/errors';
import { refreshSupplies } from '../../api/queries';
import type { Today, TodaySupply } from '../../api/types';
import { Icon } from '../../components/Icon';
import { SUPPLY_ICONS, SUPPLY_STATUS_ICONS } from '../../components/kindIcons';
import { useToast } from '../../components/Toasts';
import { Section, Spinner, StatusTag } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { supplyDaysLabel } from '../../lib/labels';

/** How long a "Bought" whose answer was lost is retried as the same purchase. */
const RETRY_WITHIN_MS = 60_000;

export function ShoppingSection({ today }: { today: Today }) {
  const { t } = useI18n();
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [busy, setBusy] = useState<string | null>(null);
  // The request id of a purchase that may have gone through without an answer, by item, and when it was sent: sent
  // again on a retry within a minute.
  const pending = useRef(new Map<string, { requestId: string; at: number }>());
  // Bought: the row leaves the list, and the focus goes to the next one.
  const list = useRef<HTMLUListElement>(null);
  useKeepFocus(list);

  async function bought(item: TodaySupply) {
    const kept = pending.current.get(item.id);
    const requestId = kept && Date.now() - kept.at < RETRY_WITHIN_MS ? kept.requestId : crypto.randomUUID();
    pending.current.set(item.id, { requestId, at: kept?.requestId === requestId ? kept.at : Date.now() });
    setBusy(item.id);
    try {
      await api.POST('/api/v1/supplies/{id}/stock-events', {
        params: { path: { id: item.id } },
        body: { kind: 'Purchase', quantity: item.packageSize, requestId },
      });
      pending.current.delete(item.id);
      toast(t.supplyPurchaseSaved);
    } catch (error) {
      if (isNotFound(error)) {
        pending.current.delete(item.id);
        toast(t.supplyGone);
      } else {
        toast(errorMessage(t, error));
      }
    } finally {
      setBusy(null);
      // Today's "To buy", and Supplies with the item's estimate and history.
      refreshSupplies(queryClient, current.id);
    }
  }

  return (
    <Section title={t.todayShoppingTitle}>
      <ul className="card card--list rows" ref={list}>
        {today.shopping.map((item) => (
          <SupplyRow key={item.id} item={item} busy={busy === item.id} onBought={() => void bought(item)} />
        ))}
      </ul>
    </Section>
  );
}

function SupplyRow({ item, busy, onBought }: { item: TodaySupply; busy: boolean; onBought: () => void }) {
  const { t } = useI18n();
  const nameId = useId();
  const ranOut = item.status === 'OutOfStock' || item.daysLeft === null;
  return (
    <li className="row">
      <span className="type-icon">
        <Icon name={SUPPLY_ICONS[item.category]} />
      </span>
      <div className="row-main">
        <Link to={`/supplies/${item.id}`} className="row-title row-link" id={nameId}>
          {item.name}
        </Link>
        <StatusTag tone={ranOut ? 'danger' : 'warning'} icon={SUPPLY_STATUS_ICONS[ranOut ? 'danger' : 'warning']}>
          {item.status === 'OutOfStock' || item.daysLeft === null
            ? t.supplyOutOfStock
            : t.supplyBuyNowLeft(supplyDaysLabel(t, item.daysLeft))}
        </StatusTag>
      </div>
      <div className="row-actions">
        {busy ? (
          <Spinner />
        ) : (
          <button
            type="button"
            className="button button--tonal"
            aria-describedby={nameId}
            onClick={onBought}
          >
            {t.supplyBought}
          </button>
        )}
      </div>
    </li>
  );
}
