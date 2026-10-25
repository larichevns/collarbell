import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/offline_copy.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../care/care_labels.dart' show formatDecimal, parseDecimal;
import '../household/current_household.dart';
import 'supplies_repository.dart';
import 'supply.dart';
import 'supply_labels.dart';
import 'supply_plan_offer.dart';
import 'supply_refresh.dart';

/// Adds an item to supplies (from scratch, or with [prefill] from a scan),
/// or edits the item [supplyId].
class SupplyFormScreen extends ConsumerWidget {
  const SupplyFormScreen({super.key, this.supplyId, this.prefill});

  final String? supplyId;
  final SupplyPrefill? prefill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = supplyId;
    if (id == null) return _SupplyForm(prefill: prefill);

    final supply = ref.watch(supplyProvider(id));
    final value = supply.value;
    if (value == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.supplyEditTitle)),
        body: supply.hasError
            ? Center(
                child: CbErrorState(
                  message: errorMessageFor(supply.error!, l10n),
                  traceId: traceIdOf(supply.error!),
                  onRetry: () => ref.invalidate(supplyProvider(id)),
                ),
              )
            : const CbLoadingState.form(),
      );
    }
    if (value.hasUnknownValues) {
      // Saving would replace values a newer version of the app set.
      return Scaffold(
        appBar: AppBar(title: Text(l10n.supplyEditTitle)),
        body: Padding(
          padding: const EdgeInsets.all(CbSpace.s4),
          child: CbNotice(message: l10n.supplyReadOnly),
        ),
      );
    }
    return _SupplyForm(supply: value);
  }
}

/// How the daily use is given by hand: "a package lasts N days" (litter) or
/// "N grams a day".
enum _ManualUsage { packageLasts, perDay }

class _SupplyForm extends ConsumerStatefulWidget {
  const _SupplyForm({this.supply, this.prefill});

  final Supply? supply;
  final SupplyPrefill? prefill;

  @override
  ConsumerState<_SupplyForm> createState() => _SupplyFormState();
}

class _SupplyFormState extends ConsumerState<_SupplyForm>
    with OpenedInHousehold {
  // The server's limits; checked here so mistakes show before saving.
  static const _maxName = 100;
  static const _maxNotes = 500;
  static const _maxUrl = 500;
  static const _maxLeadTime = 60;
  static const _maxPackages = 99;
  static const _maxSize = 1000000.0;

  final _formKey = GlobalKey<FormState>();

  /// One id for adding this item, sent with every try.
  final _requestId = const Uuid().v4();

  late final Supply? _supply = widget.supply;
  late final SupplyPrefill? _prefill = widget.prefill;

  late final _name = TextEditingController(
    text: _supply?.name ?? _prefill?.name,
  );
  late final _brand = TextEditingController(
    text: _supply?.brand ?? _prefill?.brand,
  );
  late final _barcode = TextEditingController(
    text: _supply?.barcode ?? _prefill?.barcode,
  );
  late var _category =
      _supply?.category ?? _prefill?.category ?? SupplyCategory.dryFood;
  late var _inputUnit = _initialInputUnit();

  /// The user picked the unit: a category change keeps it.
  late var _unitTouched = _supply != null || _prefill?.unit != null;
  late final _size = TextEditingController(text: _initialSize());
  late final _kcal = TextEditingController(
    text: (_supply?.kcalPerKg ?? _prefill?.kcalPerKg)?.toString(),
  );
  late var _usageMode = _supply?.usageMode ?? _defaultUsage(_category);
  late var _manualUsage = _initialManualUsage();
  late final _manual = TextEditingController(text: _initialManual());
  late final _leadTime = TextEditingController(
    text: '${_supply?.leadTimeDays ?? 5}',
  );
  late final _storeUrl = TextEditingController(text: _supply?.storeUrl);
  late final _notes = TextEditingController(
    text: _supply?.notes ?? _batchNote(),
  );

  /// "Batch L-2209 · expires Dec 31, 2027" from a medicine's DataMatrix.
  String? _batchNote() {
    final l10n = context.l10n;
    final batch = _prefill?.batch;
    final expires = _prefill?.expiresOn;
    final parts = [
      if (batch != null) l10n.supplyBatch(batch),
      if (expires != null)
        l10n.supplyExpires(DateFormat.yMMMd(l10n.localeName).format(expires)),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  late var _active = _supply?.active ?? true;

  /// Adding only: what is there now. A new bag is usually just bought.
  var _setStock = true;
  var _closed = 1;
  var _openTenths = 0;

  /// The user picked how the use is counted: a category change keeps it.
  var _usageTouched = false;

  var _submitted = false;
  var _busy = false;
  var _serverErrors = <String, List<String>>{};
  String? _failure;

  bool get _isEdit => _supply != null;

  static SupplyUsageMode _defaultUsage(SupplyCategory category) =>
      switch (category) {
        SupplyCategory.dryFood ||
        SupplyCategory.wetFood => SupplyUsageMode.feeding,
        _ => SupplyUsageMode.manual,
      };

  SupplyInputUnit _initialInputUnit() {
    final unit = _supply?.unit ?? _prefill?.unit;
    final size = _supply?.packageSize ?? _prefill?.packageSize;
    if (unit != null && size != null) return inputUnitFor(unit, size);
    if (unit != null) return inputUnitFor(unit, 0);
    return _defaultUnit(_category);
  }

  /// What a package of the category is usually counted in: a bag of dry food
  /// in kilograms, a box of pouches in pieces, tablets in doses.
  static SupplyInputUnit _defaultUnit(SupplyCategory category) =>
      switch (category) {
        SupplyCategory.dryFood ||
        SupplyCategory.litter => SupplyInputUnit.kilogram,
        SupplyCategory.wetFood => SupplyInputUnit.piece,
        SupplyCategory.treats => SupplyInputUnit.gram,
        SupplyCategory.medication => SupplyInputUnit.dose,
        SupplyCategory.other => SupplyInputUnit.piece,
      };

  String? _initialSize() {
    final size = _supply?.packageSize ?? _prefill?.packageSize;
    return size == null
        ? null
        : formatDecimal(context.l10n, size / inputFactor(_inputUnit));
  }

  _ManualUsage _initialManualUsage() {
    final supply = _supply;
    final daily = supply?.manualDailyUsage;
    if (supply == null || daily == null) return _ManualUsage.packageLasts;
    // The server keeps six decimals: a package lasting 504 days is 0.001984
    // a day, so whole days are compared with a relative tolerance.
    final days = (supply.packageSize / daily).round();
    return days >= 1 &&
            (supply.packageSize / days - daily).abs() <= daily * 1e-3
        ? _ManualUsage.packageLasts
        : _ManualUsage.perDay;
  }

  String? _initialManual() {
    final supply = _supply;
    final daily = supply?.manualDailyUsage;
    if (supply == null || daily == null) {
      // A medicine's package lasts as long as its doses protect.
      final weeks = _prefill?.protectionWeeks;
      final size = _prefill?.packageSize;
      return weeks != null && _prefill?.unit == SupplyUnit.dose && size != null
          ? '${(weeks * 7 * size).round()}'
          : null;
    }
    return _manualUsage == _ManualUsage.packageLasts
        ? '${(supply.packageSize / daily).round()}'
        : formatDecimal(
            context.l10n,
            double.parse(daily.toStringAsPrecision(4)),
          );
  }

  /// Everything the form holds, to tell whether leaving loses anything.
  List<Object?> _values() => [
    for (final field in [
      _name,
      _brand,
      _barcode,
      _size,
      _kcal,
      _manual,
      _leadTime,
      _storeUrl,
      _notes,
    ])
      field.text,
    _category,
    _inputUnit,
    _usageMode,
    _manualUsage,
    _active,
    _setStock,
    _closed,
    _openTenths,
  ];

  /// What the form opened with. Taken once the context can give the
  /// locale: sizes and notes are written in the user's language.
  List<Object?>? _opened;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _opened ??= _values();
  }

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = widget.supply != null && openedFromCopy(ref);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _brand,
      _barcode,
      _size,
      _kcal,
      _manual,
      _leadTime,
      _storeUrl,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _serverError(String field) => _serverErrors.containsKey(field)
      ? context.l10n.formServerFieldError
      : null;

  String? _maxLength(String? value, int max) =>
      (value ?? '').trim().length > max ? context.l10n.formTooLong(max) : null;

  static final _fieldKeys = RegExp(
    r'^(name|brand|barcode|category|unit|packageSize|kcalPerKg|usageMode|'
    r'manualDailyUsage|leadTimeDays|storeUrl|notes|initialStock)$',
  );

  /// The package size in the stored unit, or null when it isn't a number.
  double? get _packageSize {
    final size = parseDecimal(_size.text);
    return size == null ? null : size * inputFactor(_inputUnit);
  }

  String? _validateSize(String? value) {
    final size = _packageSize;
    if (size == null || size <= 0 || size > _maxSize) {
      return context.l10n.supplySizeInvalid;
    }
    return _serverError('packageSize') ?? _serverError('unit');
  }

  String? _validateKcal(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final kcal = int.tryParse(text);
    if (kcal == null || kcal < 1 || kcal > 10000) {
      return context.l10n.supplyKcalInvalid;
    }
    return _serverError('kcalPerKg');
  }

  String? _validateManual(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final number = parseDecimal(text);
    final valid = _manualUsage == _ManualUsage.packageLasts
        ? number != null && number >= 1 && number <= 3650
        : number != null && number > 0 && number <= _maxSize;
    return valid
        ? _serverError('manualDailyUsage')
        : context.l10n.supplyUsageInvalid;
  }

  String? _validateLeadTime(String? value) {
    final days = int.tryParse((value ?? '').trim());
    return days == null || days < 0 || days > _maxLeadTime
        ? context.l10n.supplyLeadTimeInvalid(_maxLeadTime)
        : _serverError('leadTimeDays');
  }

  String? _validateUrl(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return context.l10n.supplyUrlInvalid;
    }
    return _maxLength(text, _maxUrl) ?? _serverError('storeUrl');
  }

  String? _validateBarcode(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    return isValidGtin(text)
        ? _serverError('barcode')
        : context.l10n.supplyBarcodeInvalid;
  }

  double? _manualDaily(double packageSize) {
    final number = parseDecimal(_manual.text);
    if (number == null || number <= 0) return null;
    return _manualUsage == _ManualUsage.packageLasts
        ? packageSize / number
        : number;
  }

  SupplyInput _input() {
    String? clean(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    final size = _packageSize!;
    final usage = isFood(_category) ? _usageMode : SupplyUsageMode.manual;
    return SupplyInput(
      name: _name.text.trim(),
      brand: clean(_brand),
      barcode: clean(_barcode),
      category: _category,
      unit: storedUnit(_inputUnit),
      packageSize: size,
      kcalPerKg: isFood(_category) ? int.tryParse(_kcal.text.trim()) : null,
      usageMode: usage,
      manualDailyUsage: usage == SupplyUsageMode.manual
          ? _manualDaily(size)
          : null,
      leadTimeDays: int.parse(_leadTime.text.trim()),
      storeUrl: clean(_storeUrl),
      notes: clean(_notes),
      // Sent only when the user changed it: null keeps it as it is.
      active: _isEdit && _active != _supply!.active ? _active : null,
      initialStock: !_isEdit && _setStock
          ? size * (_closed + _openTenths / 10)
          : null,
      dataSource: _isEdit ? null : _prefill?.dataSource,
    );
  }

  Future<void> _save() async {
    if (_fromCopy) {
      setState(() => _failure = context.l10n.formOpenedOffline);
      return;
    }
    if (_busy) return;
    final l10n = context.l10n;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitted = true;
      _serverErrors = {};
      _failure = null;
    });
    final invalid = invalidFields(_formKey.currentState!);
    if (invalid.isNotEmpty) {
      revealTopmost(invalid);
      setState(() => _failure = l10n.formCheckFields);
      return;
    }

    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final supplies = ref.read(suppliesRepositoryProvider);
    final input = _input();
    final supply = _supply;
    final prefill = _prefill;
    setState(() => _busy = true);
    try {
      final saved = supply == null
          ? await supplies.createSupply(input, requestId: _requestId)
          : await supplies.updateSupply(supply.id, input);
      refreshSupplies(container, supplyId: saved.id);
      if (!mounted) return;
      if (supply != null) {
        navigator.pop();
        return;
      }
      // The new item's page, instead of the form (and the scan before it).
      // A medicine that says how long a dose protects offers a plan there.
      final treatment = prefill?.treatment;
      final weeks = prefill?.protectionWeeks;
      router.go(
        AppRoutes.supply(saved.id),
        extra: treatment != null && weeks != null
            ? SupplyPlanOffer(
                kind: treatment,
                weeks: weeks,
                product: saved.name,
              )
            : null,
      );
    } catch (error) {
      debugPrint('Saving the supply failed: $error');
      refreshSupplies(container, supplyId: supply?.id);
      if (isNotFound(error) && supply != null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.supplyGone)));
        if (mounted) navigator.pop();
        return;
      }
      if (!mounted) return;
      final fieldErrors = fieldErrorsOf(error);
      final placed =
          fieldErrors.isNotEmpty &&
          fieldErrors.keys.every((key) => _fieldKeys.hasMatch(key));
      setState(() {
        _serverErrors = {...fieldErrors};
        _failure = !placed
            ? errorMessageFor(error, l10n)
            : fieldErrors.containsKey('barcode')
            ? l10n.supplyBarcodeTaken
            : l10n.formCheckFields;
      });
      if (placed) revealTopmost(invalidFields(_formKey.currentState!));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Layout -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    const gap = SizedBox(height: CbSpace.s5);
    final prefill = _prefill;
    final food = isFood(_category);
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final size = _packageSize;
    final unitAmount = supplyAmount(
      l10n,
      storedUnit(_inputUnit),
      size ?? inputFactor(_inputUnit),
    );

    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened!, _values()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l10n.supplyEditTitle : l10n.supplyAddTitle),
        ),
        bottomNavigationBar: CbSaveBar(
          busy: _busy,
          error: _failure,
          onSave: () => inOpenedHousehold(_save),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s12,
            ),
            child: IgnorePointer(
              ignoring: _busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (prefill != null && !_isEdit) ...[
                    if (prefill.notPetProduct) ...[
                      CbNotice.warning(message: l10n.supplyNotPetProduct),
                      const SizedBox(height: CbSpace.s3),
                    ],
                    for (final source in [
                      if (prefill.dataSource ==
                          SupplyDataSource.openPetFoodFacts)
                        l10n.supplyFromOpenPetFoodFacts,
                      if (prefill.readFromPhotos)
                        l10n.supplyFromPhotos
                      else if (prefill.dataSource == SupplyDataSource.upcItemDb)
                        l10n.supplyFromUpcItemDb
                      else if (prefill.dataSource == SupplyDataSource.catalog)
                        l10n.supplyFromCatalog,
                    ]) ...[CbNotice(message: source), gap],
                  ],
                  CbTextField(
                    key: const ValueKey('name'),
                    label: l10n.supplyNameLabel,
                    hintText: l10n.supplyNameHint,
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.supplyNameRequired
                        : _maxLength(value, _maxName) ?? _serverError('name'),
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('brand'),
                    label: l10n.supplyBrandLabel,
                    controller: _brand,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        _maxLength(value, _maxName) ?? _serverError('brand'),
                  ),
                  gap,
                  CbLabeled(
                    key: const ValueKey('category'),
                    label: l10n.supplyCategoryLabel,
                    errorText: _serverError('category'),
                    child: Wrap(
                      spacing: CbSpace.s2,
                      runSpacing: CbSpace.s2,
                      children: [
                        for (final category in SupplyCategory.values)
                          ChoiceChip(
                            // Chosen: mint, the icon and words green. No tick:
                            // Material draws it over the icon on a dark disc.
                            showCheckmark: false,
                            avatar: Icon(supplyCategoryIcon(category)),
                            label: Text(supplyCategoryLabel(l10n, category)),
                            selected: _category == category,
                            onSelected: (_) => setState(() {
                              _category = category;
                              if (!_usageTouched) {
                                _usageMode = _defaultUsage(category);
                              }
                              if (!_unitTouched) {
                                _inputUnit = _defaultUnit(category);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  gap,
                  CbLabeled(
                    key: const ValueKey('package'),
                    label: l10n.supplyPackageLabel,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 112,
                          child: TextFormField(
                            key: const ValueKey('packageSize'),
                            controller: _size,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: numbers,
                            style: text.body,
                            decoration: InputDecoration(
                              hintText: l10n.supplySizeHint,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: _validateSize,
                          ),
                        ),
                        const SizedBox(width: CbSpace.s2),
                        Expanded(
                          child: DropdownButtonFormField<SupplyInputUnit>(
                            icon: cbDropdownIcon,
                            // A new key when the category picks the unit, so
                            // the field shows it.
                            key: ValueKey('unit-${_inputUnit.name}'),
                            initialValue: _inputUnit,
                            items: [
                              for (final unit in SupplyInputUnit.values)
                                DropdownMenuItem(
                                  value: unit,
                                  child: Text(supplyInputUnitLabel(l10n, unit)),
                                ),
                            ],
                            onChanged: (unit) => setState(() {
                              _inputUnit = unit ?? _inputUnit;
                              _unitTouched = true;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (food) ...[
                    gap,
                    CbTextField(
                      key: const ValueKey('kcal'),
                      label: l10n.supplyKcalLabel,
                      hintText: l10n.supplyKcalHint,
                      helperText: l10n.supplyKcalHelper,
                      controller: _kcal,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      validator: _validateKcal,
                    ),
                  ],
                  gap,
                  CbLabeled(
                    key: const ValueKey('usage'),
                    label: l10n.supplyUsageLabel,
                    errorText: _serverError('usageMode'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (food) ...[
                          SegmentedButton<SupplyUsageMode>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: SupplyUsageMode.feeding,
                                label: Text(l10n.supplyUsageFeeding),
                              ),
                              ButtonSegment(
                                value: SupplyUsageMode.manual,
                                label: Text(l10n.supplyUsageByHand),
                              ),
                            ],
                            selected: {_usageMode},
                            onSelectionChanged: (value) => setState(() {
                              _usageMode = value.single;
                              _usageTouched = true;
                            }),
                          ),
                          const SizedBox(height: CbSpace.s2),
                        ],
                        if (food && _usageMode == SupplyUsageMode.feeding)
                          Text(
                            l10n.supplyUsageFeedingHelper,
                            style: text.bodySm.copyWith(color: cb.inkMuted),
                          )
                        else ...[
                          SegmentedButton<_ManualUsage>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: _ManualUsage.packageLasts,
                                label: Text(l10n.supplyUsagePackageLasts),
                              ),
                              ButtonSegment(
                                value: _ManualUsage.perDay,
                                label: Text(l10n.supplyUsagePerDay),
                              ),
                            ],
                            selected: {_manualUsage},
                            onSelectionChanged: (value) => setState(() {
                              _manualUsage = value.single;
                              _manual.clear();
                            }),
                          ),
                          const SizedBox(height: CbSpace.s2),
                          TextFormField(
                            key: const ValueKey('manual'),
                            controller: _manual,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: numbers,
                            style: text.body,
                            decoration: InputDecoration(
                              suffixText:
                                  _manualUsage == _ManualUsage.packageLasts
                                  ? l10n.supplyUsageDaysSuffix
                                  : supplyInputUnitLabel(
                                      l10n,
                                      switch (storedUnit(_inputUnit)) {
                                        SupplyUnit.gram => SupplyInputUnit.gram,
                                        SupplyUnit.milliliter =>
                                          SupplyInputUnit.milliliter,
                                        SupplyUnit.piece =>
                                          SupplyInputUnit.piece,
                                        SupplyUnit.dose => SupplyInputUnit.dose,
                                      },
                                    ),
                              helperText:
                                  _manualUsage == _ManualUsage.packageLasts
                                  ? l10n.supplyUsagePackageLastsHelper(
                                      unitAmount,
                                    )
                                  : l10n.supplyUsagePerDayHelper,
                            ),
                            validator: _validateManual,
                          ),
                        ],
                      ],
                    ),
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('leadTime'),
                    label: l10n.supplyLeadTimeLabel,
                    helperText: l10n.supplyLeadTimeHelper,
                    controller: _leadTime,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    validator: _validateLeadTime,
                  ),
                  if (!_isEdit) ...[
                    gap,
                    SwitchListTile(
                      key: const ValueKey('setStock'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.supplyStockNowLabel, style: text.body),
                      subtitle: Text(l10n.supplyStockNowHelper),
                      value: _setStock,
                      onChanged: (value) => setState(() => _setStock = value),
                    ),
                    if (_setStock) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.supplyPackagesClosed(unitAmount),
                              style: text.body,
                            ),
                          ),
                          IconButton.outlined(
                            style: cbOutlinedIconButtonStyle(context),
                            tooltip: l10n.supplyLess,
                            onPressed: _closed > 0
                                ? () => setState(() => _closed--)
                                : null,
                            icon: const Icon(Symbols.remove_rounded),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '$_closed',
                              key: const ValueKey('closed'),
                              textAlign: TextAlign.center,
                              style: text.title,
                            ),
                          ),
                          IconButton.outlined(
                            style: cbOutlinedIconButtonStyle(context),
                            tooltip: l10n.supplyMore,
                            onPressed: _closed < _maxPackages
                                ? () => setState(() => _closed++)
                                : null,
                            icon: const Icon(Symbols.add_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: CbSpace.s2),
                      Text(
                        l10n.supplyOpenPackage(_openTenths * 10),
                        style: text.body,
                      ),
                      Slider(
                        key: const ValueKey('open'),
                        value: _openTenths.toDouble(),
                        max: 10,
                        divisions: 10,
                        label: '${_openTenths * 10}%',
                        onChanged: (value) =>
                            setState(() => _openTenths = value.round()),
                      ),
                    ],
                  ],
                  gap,
                  CbTextField(
                    key: const ValueKey('storeUrl'),
                    label: l10n.supplyStoreLabel,
                    hintText: 'https://',
                    helperText: l10n.supplyStoreHelper,
                    controller: _storeUrl,
                    keyboardType: TextInputType.url,
                    validator: _validateUrl,
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('barcode'),
                    label: l10n.supplyBarcodeLabel,
                    controller: _barcode,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    validator: _validateBarcode,
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('notes'),
                    label: l10n.careNotesLabel,
                    controller: _notes,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    validator: (value) =>
                        _maxLength(value, _maxNotes) ?? _serverError('notes'),
                  ),
                  if (_isEdit) ...[
                    gap,
                    SwitchListTile(
                      key: const ValueKey('active'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.supplyActiveLabel, style: text.body),
                      subtitle: Text(l10n.supplyActiveHelper),
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
