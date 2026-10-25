// One item (the phone app's supply_detail_screen.dart): how long it lasts and when to buy it (the forecast card),
// "Bought" in packages and "Correct the stock" for everyone, the feedings that give it, its details, and its purchases
// and counts, newest first, each of which can be taken back (helpers only their own). For everyone but helpers:
// "Edit", "Stop buying" (no reminders; a purchase brings it back) and "Delete item", each after asking.
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { ApiError, data, type ApiClient } from '../../api/client';
import { errorMessage, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { refreshSupplies, useStockEvents, useSupply } from '../../api/queries';
import type { StockEvent, StockEventKind, Supply } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import { Icon } from '../../components/Icon';
import { SUPPLY_ICONS, SUPPLY_STATUS_ICONS } from '../../components/kindIcons';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loaded, Loading, Notice, PageHead, Section, StatusTag } from '../../components/ui';
import { useKeepFocus } from '../../components/useKeepFocus';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n, type I18n } from '../../i18n/i18n';
import { todayIn } from '../../lib/dates';
import {
  stockEntryLabel,
  supplyAmountLabel,
  supplyDaysLabel,
  supplyPackagesLabel,
  supplyStatusTone,
} from '../../lib/labels';
import { supplyRequestOf } from '../../lib/supplies';
import { petTabPath } from '../pets/PetPage';
import { StockDialog } from './StockDialog';

export function SupplyPage() {
  const { id = '' } = useParams();
  const { t } = useI18n();
  const { current, permissions } = useHousehold();
  // The household the page opened in: what it changes goes there.
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const supply = useSupply(id);
  const [stock, setStock] = useState<StockEventKind | null>(null);
  const [asking, setAsking] = useState<'stop' | 'delete' | null>(null);
  const [busy, setBusy] = useState(false);

  const back = { to: '/supplies', label: t.suppliesTitle };
  // Deleted (here or on another phone): the old copy is not shown as if it were there.
  if (!supply.data || isNotFound(supply.error)) {
    return (
      <>
        <PageHead back={back} title={t.suppliesTitle} />
        {supply.error ? <ErrorNotice error={supply.error} onRetry={() => void supply.refetch()} /> : <Loading />}
      </>
    );
  }
  const value = supply.data;
  // A reload that failed keeps the item on screen under the reason; no answer at all: the offline strip says so.
  const stale = supply.error && !(supply.error instanceof ApiError && supply.error.status === 0);

  /** No longer bought: the item as the server has it now, with "active" off. */
  async function stopBuying() {
    setBusy(true);
    try {
      const fresh = await data(api.GET('/api/v1/supplies/{id}', { params: { path: { id } } }));
      await api.PUT('/api/v1/supplies/{id}', {
        params: { path: { id } },
        body: { ...supplyRequestOf(fresh), active: false },
      });
      toast(t.supplyStoppedBuying);
    } catch (error) {
      toast(isNotFound(error) ? t.supplyGone : errorMessage(t, error));
    } finally {
      setBusy(false);
      setAsking(null);
      refreshSupplies(queryClient, household);
    }
  }

  async function remove() {
    setBusy(true);
    try {
      await api.DELETE('/api/v1/supplies/{id}', { params: { path: { id } } });
    } catch (error) {
      // Deleted on another device already: that is what was wanted.
      if (!isNotFound(error)) {
        toast(errorMessage(t, error));
        setBusy(false);
        setAsking(null);
        return;
      }
    }
    queryClient.removeQueries({ queryKey: keys.supply(household, id) });
    refreshSupplies(queryClient, household);
    // The feedings that gave it keep the food's name, without the link.
    void queryClient.invalidateQueries({ queryKey: [household, 'routines'] });
    void queryClient.invalidateQueries({ queryKey: [household, 'routine'] });
    void navigate('/supplies');
  }

  return (
    <>
      <PageHead
        back={back}
        title={value.name}
        caption={value.brand}
        actions={
          permissions.canEdit && (
            <>
              <Link to={`/supplies/${id}/edit`} className="button button--secondary">
                <Icon name="edit" />
                {t.commonEdit}
              </Link>
              {value.active && (
                <button
                  type="button"
                  className="button button--secondary"
                  onClick={() => setAsking('stop')}
                  disabled={busy}
                >
                  <Icon name="remove_shopping_cart" />
                  {t.supplyStopBuying}
                </button>
              )}
              <button
                type="button"
                className="button button--ghost button--danger-text"
                onClick={() => setAsking('delete')}
                disabled={busy}
              >
                <Icon name="delete" />
                {t.supplyDelete}
              </button>
            </>
          )
        }
      />
      {stale && <ErrorNotice error={supply.error} onRetry={() => void supply.refetch()} />}
      {!value.active && <Notice>{t.supplyInactiveNote}</Notice>}
      <div className="tab-sections">
        <div className="supply-summary">
          <ForecastCard supply={value} canEdit={permissions.canEdit} />
          <div className="supply-actions">
            <button type="button" className="button button--primary" onClick={() => setStock('Purchase')}>
              <Icon name="add_shopping_cart" />
              {t.supplyBought}
            </button>
            <button type="button" className="button button--secondary" onClick={() => setStock('Adjustment')}>
              <Icon name="tune" />
              {t.supplyCount}
            </button>
          </div>
        </div>
        {value.usageMode === 'Feeding' && <Feedings supply={value} canEdit={permissions.canEdit} />}
        <Details supply={value} />
        <History supply={value} api={api} household={household} />
      </div>
      {stock && (
        <StockDialog
          target={{ ...value, remaining: value.forecast.remaining }}
          kind={stock}
          onClose={() => setStock(null)}
        />
      )}
      {asking === 'stop' && (
        <ConfirmDialog
          title={t.supplyStopBuyingTitle(value.name)}
          body={t.supplyStopBuyingBody}
          confirmLabel={t.supplyStopBuying}
          busy={busy}
          onConfirm={() => void stopBuying()}
          onCancel={() => setAsking(null)}
        />
      )}
      {asking === 'delete' && (
        <ConfirmDialog
          title={t.supplyDeleteTitle(value.name)}
          body={t.supplyDeleteBody}
          confirmLabel={t.commonDelete}
          danger
          busy={busy}
          onConfirm={() => void remove()}
          onCancel={() => setAsking(null)}
        />
      )}
    </>
  );
}

/** How long it lasts, what is left, when it runs out and when to buy it, how much a day; what to do when unknown. */
function ForecastCard({ supply, canEdit }: { supply: Supply; canEdit: boolean }) {
  const i18n = useI18n();
  const { t } = i18n;
  const { status, remaining, usagePerDay, daysLeft, runsOutOn, buyBy } = supply.forecast;
  const ranOut = status === 'OutOfStock';
  const headline =
    status === 'NoStock'
      ? t.supplyNoStock
      : status === 'NoUsage'
        ? t.supplyNoUsage
        : ranOut
          ? t.supplyOutOfStock
          : daysLeft !== null
            ? t.supplyEnoughFor(supplyDaysLabel(t, daysLeft))
            : t.supplyNoUsage;
  const amount = (value: number) => supplyAmountLabel(i18n, supply.unit, value);
  const lines = [
    remaining !== null
      ? t.supplyRemaining(amount(remaining), supplyPackagesLabel(i18n, remaining / supply.packageSize))
      : null,
    runsOutOn ? (ranOut ? t.supplyRanOutOn : t.supplyRunsOutOn)(i18n.date(runsOutOn, 'dayMonthLong')) : null,
    buyBy && !ranOut
      ? t.supplyBuyBy(i18n.date(buyBy, 'dayMonthLong'), t.supplyLeadTimeDays(supply.leadTimeDays))
      : null,
    usagePerDay !== null
      ? (supply.usageMode === 'Feeding' ? t.supplyUsageFromFeeding : t.supplyUsageManual)(amount(usagePerDay))
      : null,
  ].filter((line): line is string => line !== null);
  // How to set the use up is in forms helpers don't open.
  const hint =
    status === 'NoStock'
      ? t.supplyNoStockHint
      : status === 'NoUsage' && canEdit
        ? supply.usageMode === 'Feeding'
          ? t.supplyNoUsageFeedingHint
          : t.supplyNoUsageManualHint
        : null;
  const tone = supplyStatusTone(supply);
  // The headline is a status tag only when it is time to act: ran out, or time to buy.
  return (
    <div className="card forecast">
      <span className={`type-icon${supply.active ? '' : ' type-icon--muted'}`}>
        <Icon name={SUPPLY_ICONS[supply.category]} />
      </span>
      <div className="forecast-text">
        <p className="forecast-headline">
          {tone === 'muted' ? (
            headline
          ) : (
            <StatusTag tone={tone} icon={SUPPLY_STATUS_ICONS[tone]}>
              {headline}
            </StatusTag>
          )}
        </p>
        {lines.map((line) => (
          <p key={line} className="small">
            {line}
          </p>
        ))}
        {hint && <p className="small muted">{hint}</p>}
      </div>
    </div>
  );
}

/** The feedings that give this food: the pet, the portion and how often; each opens the pet's feeding. */
function Feedings({ supply, canEdit }: { supply: Supply; canEdit: boolean }) {
  const i18n = useI18n();
  const { t } = i18n;
  return (
    <Section title={t.supplyFeedingsTitle}>
      {supply.feedings.length === 0 ? (
        <p className="muted">{canEdit ? t.supplyNoFeedings : t.supplyNoFeedingsHelper}</p>
      ) : (
        <ul className="card card--list rows">
          {supply.feedings.map((feeding) => {
            const portion =
              feeding.amount !== null && feeding.unit ? t.portion[feeding.unit](i18n.number(feeding.amount)) : '';
            return (
              <li key={feeding.routineId} className="row">
                <span className="type-icon">
                  <Icon name="restaurant" />
                </span>
                <div className="row-main">
                  <Link to={petTabPath(feeding.petId, 'feeding')} className="row-title row-link">
                    {feeding.petName}
                  </Link>
                  {feeding.counted ? (
                    <span className="row-sub">
                      {t.supplyFeedingPortion(portion, i18n.number(Math.round(feeding.timesPerDay * 10) / 10, 1))}
                    </span>
                  ) : (
                    <StatusTag tone="warning" icon="warning">
                      {t.supplyFeedingNotCounted}
                    </StatusTag>
                  )}
                </div>
                <Icon name="chevron_right" className="row-arrow" />
              </li>
            );
          })}
        </ul>
      )}
    </Section>
  );
}

/** The kind, brand, package, energy, delivery time, barcode, notes and the shop. */
function Details({ supply }: { supply: Supply }) {
  const i18n = useI18n();
  const { t } = i18n;
  const facts: [string, string, string?][] = [
    [t.supplyCategoryLabel, t.supplyCategory[supply.category]],
    ...(supply.brand ? [[t.supplyBrandLabel, supply.brand] as [string, string]] : []),
    [t.supplyPackageLabel, supplyAmountLabel(i18n, supply.unit, supply.packageSize)],
    ...(supply.kcalPerKg !== null ? [[t.supplyKcalLabel, t.supplyKcal(supply.kcalPerKg)] as [string, string]] : []),
    [t.supplyLeadTimeLabel, t.supplyLeadTimeDays(supply.leadTimeDays)],
    ...(supply.barcode ? [[t.supplyBarcodeLabel, supply.barcode, 'mono'] as [string, string, string]] : []),
    ...(supply.notes ? [[t.careNotesLabel, supply.notes, 'pre-line'] as [string, string, string]] : []),
  ];
  return (
    <Section title={t.supplyDetailsTitle}>
      <dl className="card facts">
        {facts.map(([label, value, style]) => (
          <div key={label} className="fact">
            <dt>{label}</dt>
            <dd className={style}>{value}</dd>
          </div>
        ))}
        {supply.storeUrl && (
          <div className="fact">
            <dt>{t.supplyStoreLabel}</dt>
            <dd>
              <a href={supply.storeUrl} target="_blank" rel="noopener noreferrer" className="with-icon">
                {t.supplyOpenStore}
                <Icon name="open_in_new" size={16} />
              </a>
            </dd>
          </div>
        )}
      </dl>
    </Section>
  );
}

/** "Oct 9", or "Oct 9, 2025" for another year: the day of an entry in the household's zone. */
function entryDate(i18n: I18n, at: string, timeZone: string, today: string): string {
  const date = todayIn(timeZone, new Date(at));
  return i18n.date(date, date.slice(0, 4) === today.slice(0, 4) ? 'dayMonth' : 'medium');
}

/** Purchases and counts, newest first; one entered by mistake is taken back after asking (helpers: their own). */
function History({ supply, api, household }: { supply: Supply; api: ApiClient; household: string }) {
  const i18n = useI18n();
  const { t } = i18n;
  const { current, permissions } = useHousehold();
  const queryClient = useQueryClient();
  const toast = useToast();
  const today = useHouseholdDate();
  const events = useStockEvents(supply.id);
  const [undoing, setUndoing] = useState<StockEvent | null>(null);
  const [busy, setBusy] = useState(false);
  // An entry taken back: the focus goes to the one now in its place.
  const list = useRef<HTMLUListElement>(null);
  useKeepFocus(list);

  async function undo(entry: StockEvent) {
    setBusy(true);
    try {
      await api.DELETE('/api/v1/supplies/{id}/stock-events/{eventId}', {
        params: { path: { id: supply.id, eventId: entry.id } },
      });
    } catch (error) {
      // Taken back elsewhere already: what was wanted.
      if (!isNotFound(error)) toast(errorMessage(t, error));
    } finally {
      setBusy(false);
      setUndoing(null);
      refreshSupplies(queryClient, household);
    }
  }

  return (
    <Section title={t.supplyHistoryTitle}>
      <Loaded query={events}>
        {(entries) =>
          entries.length === 0 ? (
            <p className="muted">{t.supplyHistoryEmpty}</p>
          ) : (
            <ul className="card card--list rows" ref={list}>
              {entries.map((entry) => {
                const label = stockEntryLabel(i18n, supply.unit, entry);
                const date = entryDate(i18n, entry.at, current.timeZone, today);
                const who = entry.byMe ? t.supplyEntryByMe : entry.byName;
                return (
                  <li key={entry.id} className="row">
                    <span className="type-icon type-icon--muted">
                      <Icon name={entry.kind === 'Purchase' ? 'add_shopping_cart' : 'tune'} />
                    </span>
                    <div className="row-main">
                      <span className="row-title">{label}</span>
                      <span className="row-sub">{[date, who].filter(Boolean).join(' · ')}</span>
                    </div>
                    {permissions.canTakeBack(entry.byMe) && (
                      <div className="row-actions">
                        <button
                          type="button"
                          className="button button--ghost"
                          aria-label={t.supplyEntryUndoFor(`${label}, ${date}`)}
                          onClick={() => setUndoing(entry)}
                          disabled={busy}
                        >
                          <Icon name="undo" size={18} />
                          {t.supplyEntryUndo}
                        </button>
                      </div>
                    )}
                  </li>
                );
              })}
            </ul>
          )
        }
      </Loaded>
      {undoing && (
        <ConfirmDialog
          title={t.supplyEntryUndoTitle}
          body={t.supplyEntryUndoBody}
          confirmLabel={t.supplyEntryUndo}
          danger
          busy={busy}
          onConfirm={() => void undo(undoing)}
          onCancel={() => setUndoing(null)}
        />
      )}
    </Section>
  );
}
