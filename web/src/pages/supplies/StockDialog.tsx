// "Bought" and "Correct the stock" (the phone app's stock_sheets.dart). A purchase is some packages, one to start
// with, added to what is left. A count is what is there now: the unopened packages and how full the open one is, by
// tenths, starting from the estimate; "None left" says it ran out. Helpers may do both. One request id per dialog,
// sent with every try: a retry after a lost answer counts nothing twice. When the person changed the amount between
// the lost answer and the retry, the entry the first try made is taken back and the amount on screen entered.
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { data } from '../../api/client';
import { errorMessage, isNotFound } from '../../api/errors';
import { refreshSupplies } from '../../api/queries';
import type { StockEventKind, SupplyUnit } from '../../api/types';
import { Dialog, DialogBody, DialogCancel, DialogFoot, DialogForm } from '../../components/Dialog';
import { RangeField, Stepper } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useToast } from '../../components/Toasts';
import { Spinner } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { supplyAmountLabel } from '../../lib/labels';
import { countStart, stockQuantity, SUPPLY_MAX } from '../../lib/supplies';

/** What the dialogs need of an item: from its page, the list, or Today. */
export interface StockTarget {
  id: string;
  name: string;
  unit: SupplyUnit;
  packageSize: number;
  /** What is left now, by the estimate; null before the first purchase or count. */
  remaining: number | null;
}

export function StockDialog({
  target,
  kind,
  onClose,
}: {
  target: StockTarget;
  kind: StockEventKind;
  onClose: () => void;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const { current } = useHousehold();
  // The household the dialog opened in: the purchase goes there, whichever household is on screen meanwhile.
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const toast = useToast();
  const purchase = kind === 'Purchase';
  const [requestId, setRequestId] = useState(() => crypto.randomUUID());
  const [start] = useState(() =>
    purchase ? { packages: 1, openTenths: 0 } : countStart(target.remaining, target.packageSize),
  );
  const [packages, setPackages] = useState(start.packages);
  const [openTenths, setOpenTenths] = useState(start.openTenths);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  const size = supplyAmountLabel(i18n, target.unit, target.packageSize);
  const quantity = stockQuantity(target.packageSize, packages, purchase ? 0 : openTenths);

  async function save(amount: number) {
    setBusy(true);
    setFailure(null);
    try {
      const { event } = await data(
        api.POST('/api/v1/supplies/{id}/stock-events', {
          params: { path: { id: target.id } },
          body: { kind, quantity: amount, requestId },
        }),
      );
      if (Math.abs(event.quantity - amount) > 0.0005) {
        // A retry got the entry the first try made, with the amount of then: that one goes, this one is entered.
        try {
          await api.DELETE('/api/v1/supplies/{id}/stock-events/{eventId}', {
            params: { path: { id: target.id, eventId: event.id } },
          });
        } catch (error) {
          // Taken back on another device meanwhile: gone all the same (the item's own absence shows next).
          if (!isNotFound(error)) throw error;
        }
        const again = crypto.randomUUID();
        setRequestId(again);
        await api.POST('/api/v1/supplies/{id}/stock-events', {
          params: { path: { id: target.id } },
          body: { kind, quantity: amount, requestId: again },
        });
      }
      refreshSupplies(queryClient, household);
      toast(purchase ? t.supplyPurchaseSaved : t.supplyCountSaved);
      onClose();
    } catch (error) {
      refreshSupplies(queryClient, household);
      if (isNotFound(error)) {
        // Deleted on another device: there is nothing to count.
        toast(t.supplyGone);
        onClose();
        return;
      }
      setFailure(errorMessage(t, error));
      setBusy(false);
    }
  }

  return (
    <Dialog
      title={purchase ? t.supplyPurchaseTitle(target.name) : t.supplyCountTitle(target.name)}
      onClose={onClose}
      busy={busy}
      changed={packages !== start.packages || openTenths !== start.openTenths}
    >
      <DialogForm onSubmit={() => void save(quantity)} busy={busy}>
        <DialogBody>
          <div className="form-stack">
            <Stepper
              label={purchase ? t.supplyPackagesBought(size) : t.supplyPackagesClosed(size)}
              value={packages}
              min={purchase ? 1 : 0}
              max={SUPPLY_MAX.packages}
              onChange={setPackages}
            />
            {!purchase && (
              <>
                <RangeField
                  label={t.supplyOpenPackage(openTenths * 10)}
                  value={openTenths}
                  min={0}
                  max={10}
                  valueText={`${openTenths * 10}%`}
                  onChange={setOpenTenths}
                />
                <p className="muted small">{t.supplyCountTotal(supplyAmountLabel(i18n, target.unit, quantity))}</p>
              </>
            )}
          </div>
        </DialogBody>
        <DialogFoot>
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          {!purchase && (
            <button
              type="button"
              className="button button--ghost dialog-foot-start"
              onClick={() => void save(0)}
              disabled={busy}
            >
              {t.supplyNothingLeft}
            </button>
          )}
          <DialogCancel disabled={busy} />
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {purchase ? t.supplyPurchaseSave : t.commonSave}
          </button>
        </DialogFoot>
      </DialogForm>
    </Dialog>
  );
}
