// Adding an item to supplies, or changing one (the phone app's supply_form_screen.dart). A barcode typed in is
// checked by its check digit; when adding, "Find" looks it up as the phone's scan does (the household's own item, the
// catalog, Open Pet Food Facts, UPCitemdb: GET /products/lookup) and fills in what is known. Then the name and brand,
// the kind, the package (typed in kilograms or litres too, kept in grams and millilitres), a food's energy, the daily
// use (from the feedings that give a food, or by hand: "a package lasts N days" or so much a day), the days for
// delivery, what is there now (adding only: unopened packages and how full the open one is), where to buy it and
// notes; changing it, "Still buying". One id per new item makes a retry after a lost answer safe; a correction typed
// between the lost answer and the retry (the details, or what is there now) follows the item the first try made.
// With AI set up on the server, "Fill from photos" reads photos of the package (POST /products/scan, as the phone's
// product scan does) and fills in what it finds: what a barcode's lookup gave stays first (Open Pet Food Facts' data
// keeps its source), the photos fill in the rest. "Still buying" is sent only when changed here: a purchase on another
// phone meanwhile isn't undone.
//
// The API has no price: the spec's data model names Price and Currency, but neither the server nor the phone app has
// them yet, so the form has none either.
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type FormEvent, type KeyboardEvent } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { refreshSupplies, useAiStatus, useSupply } from '../../api/queries';
import type {
  ProductDetails,
  ProductDraft,
  ProductLookup,
  ProductSource,
  Supply,
  SupplyCategory,
  SupplyDataSource,
  SupplyRequest,
} from '../../api/types';
import {
  CheckboxField,
  ChoiceGroup,
  RangeField,
  SelectField,
  Stepper,
  TextField,
  useFocusFirstError,
} from '../../components/fields';
import { Icon } from '../../components/Icon';
import { SUPPLY_ICONS } from '../../components/kindIcons';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loading, Notice, PageHead, Spinner } from '../../components/ui';
import { PackageReader } from './PackageReader';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import type { Lang } from '../../i18n/lang';
import { isFood } from '../../lib/feeding';
import { supplyAmountLabel } from '../../lib/labels';
import { decimalText, parseDecimal } from '../../lib/numbers';
import {
  baseInputUnit,
  DEFAULT_LEAD_TIME_DAYS,
  defaultInputUnit,
  defaultUsage,
  INPUT_UNITS,
  inputFactor,
  inputUnitFor,
  isValidGtin,
  isWebAddress,
  manualDaily,
  manualUsageOf,
  stockQuantity,
  storedUnit,
  SUPPLY_CATEGORIES,
  supplyHolds,
  SUPPLY_MAX,
  type InputUnit,
  type ManualUsage,
} from '../../lib/supplies';

/**
 * A new item. `?start=` from the empty Supplies' cards: `barcode` starts in the barcode's field, `photos` with "Fill
 * from photos" open.
 */
export function NewSupplyPage() {
  const [search] = useSearchParams();
  const start = search.get('start');
  return <SupplyForm supply={null} start={start === 'barcode' || start === 'photos' ? start : null} />;
}

export function EditSupplyPage() {
  const { id = '' } = useParams();
  const { t } = useI18n();
  const supply = useSupply(id);
  // Deleted meanwhile (here, or on another phone): not edited from an old copy.
  if (supply.data && !supply.isPlaceholderData && !isNotFound(supply.error)) return <SupplyForm supply={supply.data} />;
  return (
    <>
      <PageHead back={{ to: `/supplies/${id}`, label: t.suppliesTitle }} title={t.supplyEditTitle} />
      {supply.error ? <ErrorNotice error={supply.error} onRetry={() => void supply.refetch()} /> : <Loading />}
    </>
  );
}

/** How the daily use is counted: from the feedings that give a food, or by hand in one of two ways. */
type Usage = 'Feeding' | ManualUsage;

/**
 * Where the details came from, for the server's shared catalog: a barcode's lookup (for that code: a code typed since
 * isn't that product's), the photos of the package, or both.
 */
interface FilledFrom {
  source: SupplyDataSource;
  /** The barcode the lookup was for; null when only photos filled it in. */
  code: string | null;
  photos: boolean;
}

interface Values {
  barcode: string;
  name: string;
  brand: string;
  category: SupplyCategory;
  /** The package's size as typed, in `unit`. */
  size: string;
  unit: InputUnit;
  kcal: string;
  /** From the feedings (food only), or by hand: counted from the feedings only while it is a food. */
  usage: 'Feeding' | 'Manual';
  /** By hand: "a package lasts N days" or so much a day. A kind changed keeps it. */
  manualMode: ManualUsage;
  /** The days a package lasts, or the amount a day (in the item's unit), as typed. */
  manual: string;
  leadTime: string;
  /** Adding only: what is there now. */
  setStock: boolean;
  closed: number;
  openTenths: number;
  storeUrl: string;
  notes: string;
  /** Changing only: still bought. */
  active: boolean;
}

/** The server's field names, and the field of the form each is shown under; anything else is said over "Save". */
const FIELDS: Record<string, keyof Problems> = {
  barcode: 'barcode',
  name: 'name',
  brand: 'brand',
  category: 'category',
  unit: 'size',
  packageSize: 'size',
  kcalPerKg: 'kcal',
  usageMode: 'manual',
  manualDailyUsage: 'manual',
  leadTimeDays: 'leadTime',
  storeUrl: 'storeUrl',
  notes: 'notes',
  initialStock: 'stock',
};

interface Problems {
  barcode: string | null;
  name: string | null;
  brand: string | null;
  category: string | null;
  size: string | null;
  kcal: string | null;
  manual: string | null;
  leadTime: string | null;
  storeUrl: string | null;
  notes: string | null;
  stock: string | null;
}

/** Three decimals at most, as the server keeps sizes. */
const round3 = (value: number) => Math.round(value * 1000) / 1000;

/** A kind's usual way of counting the use: a food from the feedings, anything else by hand. */
function usageFor(category: SupplyCategory): Values['usage'] {
  return defaultUsage(category);
}

function initialValues(supply: Supply | null, lang: Lang): Values {
  if (!supply) {
    return {
      barcode: '',
      name: '',
      brand: '',
      category: 'DryFood',
      size: '',
      unit: defaultInputUnit('DryFood'),
      kcal: '',
      usage: usageFor('DryFood'),
      manualMode: 'packageLasts',
      manual: '',
      leadTime: String(DEFAULT_LEAD_TIME_DAYS),
      // A new bag is usually just bought.
      setStock: true,
      closed: 1,
      openTenths: 0,
      storeUrl: '',
      notes: '',
      active: true,
    };
  }
  const unit = inputUnitFor(supply.unit, supply.packageSize);
  const manual = manualUsageOf(supply.packageSize, supply.manualDailyUsage);
  return {
    barcode: supply.barcode ?? '',
    name: supply.name,
    brand: supply.brand ?? '',
    category: supply.category,
    size: decimalText(lang, round3(supply.packageSize / inputFactor(unit))),
    unit,
    kcal: supply.kcalPerKg !== null ? String(supply.kcalPerKg) : '',
    usage: supply.usageMode === 'Feeding' && isFood(supply.category) ? 'Feeding' : 'Manual',
    manualMode: manual.mode,
    manual: manual.value !== null ? decimalText(lang, manual.value) : '',
    leadTime: String(supply.leadTimeDays),
    setStock: false,
    closed: 0,
    openTenths: 0,
    storeUrl: supply.storeUrl ?? '',
    notes: supply.notes ?? '',
    active: supply.active,
  };
}

/** What "Find" found for a code, or that it is looking. */
type Lookup =
  | { code: string; state: 'looking' }
  | { code: string; state: 'done'; result: ProductLookup }
  | { code: string; state: 'failed'; error: unknown };

function SupplyForm({ supply, start = null }: { supply: Supply | null; start?: 'barcode' | 'photos' | null }) {
  const i18n = useI18n();
  const { t, lang } = i18n;
  const { current } = useHousehold();
  // The household the form opened in: its save goes there, whichever household is on screen meanwhile.
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const form = useRef<HTMLFormElement>(null);
  const [requestId] = useState(() => crypto.randomUUID());
  // Tries of a new item sent so far: a retry may get the item an earlier try made, before a correction since.
  const tries = useRef(0);

  const [values, setValues] = useState<Values>(() => initialValues(supply, lang));
  const [opened] = useState(() => JSON.stringify(values));
  // "Still buying" as the form opened with it: only a change made here is sent, not one read since from another phone.
  const [openedActive] = useState(() => values.active);
  const ai = useAiStatus();
  // A kind picked later keeps the unit and the way of counting the person chose.
  const [touched, setTouched] = useState({ unit: supply !== null, usage: false });
  const [submitted, setSubmitted] = useState(0);
  const [findTried, setFindTried] = useState(false);
  const [busy, setBusy] = useState(false);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  const [lookup, setLookup] = useState<Lookup | null>(null);
  // Where the details came from, for the server's shared catalog: the lookup or the photos that filled them in.
  const [filledFrom, setFilledFrom] = useState<FilledFrom | null>(null);
  // What the photos of the package said beyond the details: whether it seems a pet product at all.
  const [photosRead, setPhotosRead] = useState<{ petProduct: boolean } | null>(null);
  const barcodeNow = useRef(values.barcode);
  barcodeNow.current = values.barcode.trim();
  const { allowLeave } = useLeaveGuard(JSON.stringify(values) !== opened, busy);
  const stillHere = useStillHere(household);
  useFocusFirstError(form, submitted);

  const set = <K extends keyof Values>(field: K, value: Values[K]) => setValues((old) => ({ ...old, [field]: value }));
  const food = isFood(values.category);
  // How the use is counted now: from the feedings only while it is a food.
  const usage: Usage = food && values.usage === 'Feeding' ? 'Feeding' : values.manualMode;
  const unit = storedUnit(values.unit);
  const parsedSize = parseDecimal(values.size);
  const packageSize = parsedSize === null ? null : round3(parsedSize * inputFactor(values.unit));
  // "Packages of 2 kg": the size typed, else one of the unit.
  const sizeLabel = supplyAmountLabel(
    i18n,
    unit,
    packageSize && packageSize > 0 ? packageSize : inputFactor(values.unit),
  );

  /** The form's own checks (formats once "Save" was pressed), and the server's word on fields it refused. */
  function problems(checked: boolean, refused: Record<string, string[]>): Problems {
    const server = (...fields: string[]) =>
      fields.some((field) => refused[field] && FIELDS[field]) ? t.formServerFieldError : null;
    const tooLong = (text: string, max: number) => (text.trim().length > max ? t.formTooLong(max) : null);
    const barcode = values.barcode.trim();
    const kcal = values.kcal.trim();
    const manual = parseDecimal(values.manual);
    const lead = values.leadTime.trim();
    const url = values.storeUrl.trim();
    const manualOk =
      manual !== null &&
      (usage === 'packageLasts'
        ? manual >= 1 && manual <= SUPPLY_MAX.packageLastsDays
        : manual > 0 && manual <= SUPPLY_MAX.amount);
    return {
      barcode: (checked || findTried) && barcode && !isValidGtin(barcode) ? t.supplyBarcodeInvalid : server('barcode'),
      name:
        checked && !values.name.trim()
          ? t.supplyNameRequired
          : (tooLong(values.name, SUPPLY_MAX.name) ?? server('name')),
      brand: tooLong(values.brand, SUPPLY_MAX.brand) ?? server('brand'),
      category: server('category'),
      size:
        checked && !(packageSize !== null && packageSize > 0 && packageSize <= SUPPLY_MAX.amount)
          ? t.supplySizeInvalid
          : server('packageSize', 'unit'),
      kcal:
        checked && food && kcal && !(/^\d+$/.test(kcal) && Number(kcal) >= 1 && Number(kcal) <= SUPPLY_MAX.kcal)
          ? t.supplyKcalInvalid
          : server('kcalPerKg'),
      manual:
        checked && usage !== 'Feeding' && values.manual.trim() && !manualOk
          ? t.supplyUsageInvalid
          : server('manualDailyUsage', 'usageMode'),
      leadTime:
        checked && !(/^\d+$/.test(lead) && Number(lead) <= SUPPLY_MAX.leadTimeDays)
          ? t.supplyLeadTimeInvalid(SUPPLY_MAX.leadTimeDays)
          : server('leadTimeDays'),
      storeUrl:
        checked && url && !isWebAddress(url)
          ? t.supplyUrlInvalid
          : (tooLong(url, SUPPLY_MAX.url) ?? server('storeUrl')),
      notes: tooLong(values.notes, SUPPLY_MAX.notes) ?? server('notes'),
      stock: server('initialStock'),
    };
  }
  const errors = problems(submitted > 0, serverFields);

  function request(): SupplyRequest {
    const clean = (value: string) => value.trim() || null;
    const size = packageSize!;
    const feeding = usage === 'Feeding';
    const manual = parseDecimal(values.manual);
    const barcode = clean(values.barcode);
    // A lookup's details are that barcode's: a code typed since makes them the person's (or the photos').
    const source = !filledFrom
      ? null
      : filledFrom.code === null || filledFrom.code === barcode
        ? filledFrom.source
        : filledFrom.photos
          ? 'Ai'
          : null;
    return {
      name: values.name.trim(),
      brand: clean(values.brand),
      barcode: clean(values.barcode),
      category: values.category,
      unit,
      packageSize: size,
      kcalPerKg: food && values.kcal.trim() ? Number(values.kcal.trim()) : null,
      usageMode: feeding ? 'Feeding' : 'Manual',
      manualDailyUsage: !feeding && manual !== null && manual > 0 ? manualDaily(values.manualMode, manual, size) : null,
      leadTimeDays: Number(values.leadTime.trim()),
      storeUrl: clean(values.storeUrl),
      notes: clean(values.notes),
      // Sent only when changed here: null keeps it as it is (a new item is bought), also when another phone bought it
      // again meanwhile.
      active: supply && values.active !== openedActive ? values.active : null,
      initialStock: !supply && values.setStock ? stockQuantity(size, values.closed, values.openTenths) : null,
      dataSource: supply ? null : source,
      requestId: supply ? null : requestId,
    };
  }

  function refresh() {
    refreshSupplies(queryClient, household);
    // A renamed food is renamed in the feedings that give it.
    void queryClient.invalidateQueries({ queryKey: [household, 'routines'] });
    void queryClient.invalidateQueries({ queryKey: [household, 'routine'] });
  }

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setSubmitted((value) => value + 1);
    setServerFields({});
    setFailure(null);
    if (Object.values(problems(true, {})).some(Boolean)) {
      setFailure(t.formCheckFields);
      return;
    }
    setBusy(true);
    const sent = request();
    try {
      let saved;
      if (supply) {
        saved = await data(api.PUT('/api/v1/supplies/{id}', { params: { path: { id: supply.id } }, body: sent }));
      } else {
        const retry = tries.current > 0;
        tries.current += 1;
        saved = await data(api.POST('/api/v1/supplies', { body: sent }));
        // A retry after a lost answer gets the item as the first try made it: a correction since then follows.
        if (retry && !supplyHolds(saved, sent)) {
          saved = await data(
            api.PUT('/api/v1/supplies/{id}', {
              params: { path: { id: saved.id } },
              body: { ...sent, initialStock: null, requestId: null },
            }),
          );
        }
        if (retry) await correctStock(saved.id, sent.initialStock);
      }
      refresh();
      allowLeave();
      if (stillHere()) void navigate(`/supplies/${saved.id}`, { replace: !supply });
    } catch (error) {
      refresh();
      if (supply && isNotFound(error)) {
        // Deleted on another device: there is nothing left to save.
        toast(t.supplyGone);
        allowLeave();
        if (stillHere()) void navigate('/supplies');
        return;
      }
      const fields = fieldErrorsOf(error);
      const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => field in FIELDS);
      setServerFields(placed ? fields : {});
      setFailure(!placed ? errorMessage(t, error) : fields.barcode ? t.supplyBarcodeTaken : t.formCheckFields);
      if (placed) setSubmitted((value) => value + 1);
      setBusy(false);
    }
  }

  /**
   * After a retry: the count the item was made with is what is there now on screen. The first try's count (the item's
   * only entry yet) is taken back when it says otherwise, and this one entered.
   */
  async function correctStock(id: string, stockNow: number | null) {
    const entries = await data(api.GET('/api/v1/supplies/{id}/stock-events', { params: { path: { id } } }));
    const counted = entries.find((entry) => entry.kind === 'Adjustment');
    if (counted && stockNow !== null && Math.abs(counted.quantity - stockNow) < 0.0005) return;
    if (counted) {
      await api.DELETE('/api/v1/supplies/{id}/stock-events/{eventId}', {
        params: { path: { id, eventId: counted.id } },
      });
    }
    if (stockNow !== null) {
      await api.POST('/api/v1/supplies/{id}/stock-events', {
        params: { path: { id } },
        body: { kind: 'Adjustment', quantity: stockNow, requestId: crypto.randomUUID() },
      });
    }
  }

  /** "Find": what the barcode is, and the product's details filled in. */
  async function find() {
    const code = values.barcode.trim();
    setFindTried(true);
    if (!isValidGtin(code)) return;
    setLookup({ code, state: 'looking' });
    try {
      const result = await data(api.GET('/api/v1/products/lookup', { params: { query: { code } } }));
      // Typed on meanwhile: the answer is about another code.
      if (barcodeNow.current !== code) return;
      if (!result.existing && result.product) fill(result.product, result.source);
      setLookup({ code, state: 'done', result });
    } catch (error) {
      if (barcodeNow.current === code) setLookup({ code, state: 'failed', error });
    }
  }

  /** What a product database knows, over what was there: only the name is sure. */
  function fill(product: ProductDetails, source: ProductSource | null) {
    setValues((old) => {
      const category = product.category ?? old.category;
      const sized = product.unit !== null && product.packageSize !== null && product.packageSize > 0;
      const shownUnit = sized
        ? inputUnitFor(product.unit!, product.packageSize!)
        : product.unit
          ? baseInputUnit(product.unit)
          : touched.unit
            ? old.unit
            : defaultInputUnit(category);
      return {
        ...old,
        name: product.name,
        brand: product.brand ?? old.brand,
        category,
        unit: shownUnit,
        size: sized ? decimalText(lang, round3(product.packageSize! / inputFactor(shownUnit))) : old.size,
        kcal: product.kcalPerKg !== null ? String(product.kcalPerKg) : old.kcal,
        usage: touched.usage ? old.usage : usageFor(category),
      };
    });
    setFilledFrom({ source: source ?? 'Manual', code: values.barcode.trim(), photos: false });
  }

  /**
   * What photos of the package said, as the phone's SupplyPrefill: the lookup's product (when "Find" found one for the
   * barcode there) stays first, since a database's name is spelled as on the shelf; the photos fill in the rest, and
   * often know the size. A medicine's package lasts as long as its doses protect.
   */
  function fillFromPhotos(read: ProductDraft) {
    const current = lookup && lookup.state === 'done' && lookup.code === values.barcode.trim() ? lookup.result : null;
    const product = current && !current.existing ? current.product : null;
    setValues((old) => {
      const category = product?.category ?? read.category ?? old.category;
      const unit = product?.packageSize != null ? product.unit : read.unit;
      const size = product?.packageSize ?? read.packageSize;
      const sized = unit !== null && size !== null && size > 0;
      const shownUnit = sized
        ? inputUnitFor(unit, size)
        : unit
          ? baseInputUnit(unit)
          : touched.unit
            ? old.unit
            : defaultInputUnit(category);
      const kcal = product?.kcalPerKg ?? read.kcalPerKg;
      const weeks = read.protectionWeeks;
      const protects = !touched.usage && unit === 'Dose' && sized && weeks !== null && weeks > 0 && !old.manual.trim();
      const barcode = read.barcode?.replace(/\D/g, '') ?? '';
      return {
        ...old,
        name: product?.name ?? read.name ?? old.name,
        brand: product?.brand ?? read.brand ?? old.brand,
        category,
        unit: shownUnit,
        size: sized ? decimalText(lang, round3(size / inputFactor(shownUnit))) : old.size,
        kcal: kcal !== null && kcal !== undefined ? String(kcal) : old.kcal,
        usage: touched.usage ? old.usage : usageFor(category),
        ...(protects ? { manualMode: 'packageLasts' as const, manual: String(Math.round(weeks * 7 * size)) } : {}),
        // The code the photos show, when none was typed.
        barcode: old.barcode || (isValidGtin(barcode) ? barcode : ''),
      };
    });
    // Open Pet Food Facts' details stay theirs when photos fill in the rest: shown with their licence, and never
    // copied to the shared catalog.
    const openFood = current?.source === 'OpenPetFoodFacts' && !!product;
    setFilledFrom({
      source: openFood ? 'OpenPetFoodFacts' : 'Ai',
      code: openFood ? values.barcode.trim() : null,
      photos: true,
    });
    setPhotosRead({ petProduct: read.isPetProduct });
  }

  function pickCategory(category: SupplyCategory) {
    setValues((old) => ({
      ...old,
      category,
      unit: touched.unit ? old.unit : defaultInputUnit(category),
      // From the feedings or by hand follows the kind until the person chose; the way by hand stays as it was.
      usage: touched.usage ? old.usage : usageFor(category),
    }));
  }

  const shownLookup = lookup && lookup.code === values.barcode.trim() ? lookup : null;
  const usageOptions: Usage[] = food ? ['Feeding', 'packageLasts', 'perDay'] : ['packageLasts', 'perDay'];
  const usageLabels: Record<Usage, string> = {
    Feeding: t.supplyUsageFeeding,
    packageLasts: t.supplyUsagePackageLasts,
    perDay: t.supplyUsagePerDay,
  };
  const back = supply ? `/supplies/${supply.id}` : '/supplies';

  return (
    <>
      <PageHead
        back={{ to: back, label: supply ? supply.name : t.suppliesTitle }}
        title={supply ? t.supplyEditTitle : t.supplyAddTitle}
      />
      <form ref={form} className="form" noValidate onSubmit={(event) => void save(event)} aria-busy={busy || undefined}>
        <fieldset className="form-stack" disabled={busy}>
          <div
            className="form-stack"
            onKeyDown={(event: KeyboardEvent<HTMLDivElement>) => {
              // Enter in the barcode looks it up, rather than saving the form.
              if (!supply && event.key === 'Enter' && event.target instanceof HTMLInputElement) {
                event.preventDefault();
                void find();
              }
            }}
          >
            <TextField
              label={t.supplyBarcodeLabel}
              placeholder={t.supplyBarcodeHint}
              hint={supply ? null : t.supplyBarcodeFindHelper}
              value={values.barcode}
              inputMode="numeric"
              autoComplete="off"
              autoFocus={start === 'barcode'}
              code
              onChange={(barcode) => set('barcode', barcode.replace(/\D/g, ''))}
              error={errors.barcode}
            />
            {!supply && (
              <button
                type="button"
                className="button button--secondary align-start"
                onClick={() => void find()}
                disabled={shownLookup?.state === 'looking'}
              >
                <Icon name="search" size={18} />
                {t.supplyFind}
              </button>
            )}
            <div aria-live="polite">
              {shownLookup && <LookupResult lookup={shownLookup} onRetry={() => void find()} />}
            </div>
          </div>
          {!supply && (
            <PackageReader
              available={!!ai.data?.configured}
              api={api}
              freeTier={!!ai.data?.freeTier}
              barcode={isValidGtin(values.barcode.trim()) ? values.barcode.trim() : null}
              startOpen={start === 'photos'}
              onRead={fillFromPhotos}
            />
          )}
          {photosRead && (
            <div aria-live="polite">
              {!photosRead.petProduct && <Notice tone="warning">{t.supplyNotPetProduct}</Notice>}
              {/* What "Find" found says its own source above. */}
              <Notice tone="ok">
                <p>{t.supplyFromPhotos}</p>
              </Notice>
            </div>
          )}
          <TextField
            label={t.supplyNameLabel}
            placeholder={t.supplyNameHint}
            value={values.name}
            onChange={(name) => set('name', name)}
            error={errors.name}
          />
          <TextField
            label={t.supplyBrandLabel}
            value={values.brand}
            onChange={(brand) => set('brand', brand)}
            error={errors.brand}
          />
          <ChoiceGroup
            label={t.supplyCategoryLabel}
            value={values.category}
            options={SUPPLY_CATEGORIES.map((category) => ({
              value: category,
              label: t.supplyCategory[category],
              icon: <Icon name={SUPPLY_ICONS[category]} size={18} />,
            }))}
            onChange={pickCategory}
            error={errors.category}
          />
          <div className="form-row">
            <TextField
              label={t.supplyPackageSizeLabel}
              placeholder={t.supplySizeHint}
              value={values.size}
              inputMode="decimal"
              autoComplete="off"
              onChange={(size) => set('size', size.replace(/[^\d.,]/g, ''))}
              error={errors.size}
            />
            <SelectField
              label={t.supplyUnitLabel}
              value={values.unit}
              options={INPUT_UNITS.map((each) => ({ value: each, label: t.supplyInputUnit[each] }))}
              onChange={(picked) => {
                set('unit', picked);
                setTouched((old) => ({ ...old, unit: true }));
              }}
            />
          </div>
          {food && (
            <TextField
              label={t.supplyKcalLabel}
              placeholder={t.supplyKcalHint}
              hint={t.supplyKcalHelper}
              value={values.kcal}
              inputMode="numeric"
              autoComplete="off"
              onChange={(kcal) => set('kcal', kcal.replace(/\D/g, ''))}
              error={errors.kcal}
            />
          )}
          <ChoiceGroup
            label={t.supplyUsageLabel}
            value={usage}
            options={usageOptions.map((each) => ({ value: each, label: usageLabels[each] }))}
            onChange={(picked) => {
              setValues((old) => ({
                ...old,
                usage: picked === 'Feeding' ? 'Feeding' : 'Manual',
                manualMode: picked === 'Feeding' ? old.manualMode : picked,
                // The other way of counting means another number.
                manual: picked === usage ? old.manual : '',
              }));
              setTouched((old) => ({ ...old, usage: true }));
            }}
            hint={usage === 'Feeding' ? t.supplyUsageFeedingHelper : null}
            error={usage === 'Feeding' ? errors.manual : null}
          />
          {usage !== 'Feeding' && (
            <TextField
              label={
                usage === 'packageLasts'
                  ? t.supplyPackageLastsLabel
                  : t.supplyPerDayLabel(t.supplyInputUnit[baseInputUnit(unit)])
              }
              hint={usage === 'packageLasts' ? t.supplyUsagePackageLastsHelper(sizeLabel) : t.supplyUsagePerDayHelper}
              value={values.manual}
              inputMode="decimal"
              autoComplete="off"
              onChange={(manual) => set('manual', manual.replace(/[^\d.,]/g, ''))}
              error={errors.manual}
            />
          )}
          <TextField
            label={t.supplyLeadTimeLabel}
            hint={t.supplyLeadTimeHelper}
            value={values.leadTime}
            inputMode="numeric"
            autoComplete="off"
            onChange={(leadTime) => set('leadTime', leadTime.replace(/\D/g, ''))}
            error={errors.leadTime}
          />
          {!supply && (
            <div className="form-stack">
              <CheckboxField
                label={t.supplyStockNowLabel}
                hint={t.supplyStockNowHelper}
                checked={values.setStock}
                onChange={(setStock) => set('setStock', setStock)}
              />
              {values.setStock && (
                <div className="stock-now">
                  <Stepper
                    label={t.supplyPackagesClosed(sizeLabel)}
                    value={values.closed}
                    min={0}
                    max={SUPPLY_MAX.packages}
                    onChange={(closed) => set('closed', closed)}
                    error={errors.stock}
                  />
                  <RangeField
                    label={t.supplyOpenPackage(values.openTenths * 10)}
                    value={values.openTenths}
                    min={0}
                    max={10}
                    valueText={`${values.openTenths * 10}%`}
                    onChange={(openTenths) => set('openTenths', openTenths)}
                  />
                </div>
              )}
            </div>
          )}
          <TextField
            label={t.supplyStoreLabel}
            placeholder="https://"
            hint={t.supplyStoreHelper}
            type="url"
            autoComplete="url"
            value={values.storeUrl}
            onChange={(storeUrl) => set('storeUrl', storeUrl)}
            error={errors.storeUrl}
          />
          <TextField
            label={t.careNotesLabel}
            value={values.notes}
            rows={3}
            onChange={(notes) => set('notes', notes)}
            error={errors.notes}
          />
          {supply && (
            <CheckboxField
              label={t.supplyActiveLabel}
              hint={t.supplyActiveHelper}
              checked={values.active}
              onChange={(active) => set('active', active)}
            />
          )}
        </fieldset>
        <div className="form-foot">
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {busy ? t.commonSaving : t.commonSave}
          </button>
          <button type="button" className="button button--ghost" onClick={() => void navigate(back)} disabled={busy}>
            {t.commonCancel}
          </button>
        </div>
      </form>
    </>
  );
}

/** What "Find" found: the household's own item, a product (and where its details come from), nothing, or why not. */
function LookupResult({ lookup, onRetry }: { lookup: Lookup; onRetry: () => void }) {
  const { t } = useI18n();
  if (lookup.state === 'looking') {
    return (
      <p className="loading-inline">
        <Spinner />
        {t.supplyLookingUp}
      </p>
    );
  }
  if (lookup.state === 'failed') {
    // A code the server doesn't take for a product's: no try again helps.
    if (fieldErrorsOf(lookup.error).code) return <Notice tone="warning">{t.supplyLookupNotProduct}</Notice>;
    return <ErrorNotice error={lookup.error} onRetry={onRetry} />;
  }
  const { existing, product, source } = lookup.result;
  if (existing) {
    return (
      <Notice tone="warning">
        <p>{t.supplyLookupExisting(existing.name)}</p>
        {!existing.active && <p>{t.supplyLookupExistingInactive}</p>}
        <Link to={`/supplies/${existing.id}`} className="button button--secondary">
          {t.supplyOpenExisting}
        </Link>
      </Notice>
    );
  }
  if (!product) return <Notice>{t.supplyLookupUnknown}</Notice>;
  const from =
    source === 'OpenPetFoodFacts'
      ? t.supplyFromOpenPetFoodFacts
      : source === 'UpcItemDb'
        ? t.supplyFromUpcItemDb
        : t.supplyFromCatalog;
  return (
    <Notice tone="ok">
      <p>{from}</p>
      {product.packageSize === null && source !== 'UpcItemDb' && <p>{t.supplyLookupNoSize}</p>}
    </Notice>
  );
}
