import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../theme/collarbell_theme.dart';
import 'supplies_repository.dart';
import 'supply.dart';
import 'supply_labels.dart';
import 'supply_refresh.dart';

/// What the stock sheets need of an item: from its page, or from Today.
@immutable
class StockTarget {
  const StockTarget({
    required this.id,
    required this.name,
    required this.unit,
    required this.packageSize,
    this.remaining,
  });

  StockTarget.of(Supply supply)
    : this(
        id: supply.id,
        name: supply.name,
        unit: supply.unit,
        packageSize: supply.packageSize,
        remaining: supply.forecast.remaining,
      );

  StockTarget.ofToday(TodaySupply supply)
    : this(
        id: supply.id,
        name: supply.name,
        unit: supply.unit,
        packageSize: supply.packageSize,
        remaining: supply.remaining,
      );

  final String id;
  final String name;
  final SupplyUnit unit;
  final double packageSize;
  final double? remaining;
}

/// "Bought": how many packages, added to what is left.
Future<void> showPurchaseSheet(BuildContext context, StockTarget supply) =>
    _show(context, supply, StockEventKind.purchase);

/// "Correct the stock": closed packages and how full the open one is.
Future<void> showCountSheet(BuildContext context, StockTarget supply) =>
    _show(context, supply, StockEventKind.adjustment);

Future<void> _show(
  BuildContext context,
  StockTarget supply,
  StockEventKind kind,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _StockSheet(supply: supply, kind: kind),
);

class _StockSheet extends ConsumerStatefulWidget {
  const _StockSheet({required this.supply, required this.kind});

  final StockTarget supply;
  final StockEventKind kind;

  @override
  ConsumerState<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends ConsumerState<_StockSheet> {
  static const _maxPackages = 99;

  /// One id for this entry, sent with every try: a purchase is counted once.
  final _requestId = const Uuid().v4();

  late var _packages = _initialPackages();

  /// How full the open package is, in tenths.
  late var _openTenths = _initialOpenTenths();
  var _busy = false;
  String? _failure;

  bool get _isPurchase => widget.kind == StockEventKind.purchase;

  /// A purchase is one package; a count starts from the estimate, in tenths
  /// of a package: a bag just bought is "1 unopened", not "0, the open one
  /// at 100 %".
  int _initialPackages() {
    if (_isPurchase) return 1;
    return (_estimateTenths() ~/ 10).clamp(0, _maxPackages);
  }

  int _initialOpenTenths() => _isPurchase ? 0 : _estimateTenths() % 10;

  int _estimateTenths() {
    final remaining = widget.supply.remaining ?? 0;
    return (remaining / widget.supply.packageSize * 10).round();
  }

  double get _quantity =>
      widget.supply.packageSize *
      (_packages + (_isPurchase ? 0 : _openTenths / 10));

  Future<void> _save({bool nothingLeft = false}) async {
    if (_busy) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final supplies = ref.read(suppliesRepositoryProvider);
    final supply = widget.supply;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await supplies.addStock(
        supply.id,
        widget.kind,
        nothingLeft ? 0 : _quantity,
        requestId: _requestId,
      );
      if (_isPurchase) {
        container.read(appEventsProvider).action(AppAction.bought);
      }
      refreshSupplies(container, supplyId: supply.id);
      if (mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isPurchase ? l10n.supplyPurchaseSaved : l10n.supplyCountSaved,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Saving the stock failed: $error');
      refreshSupplies(container, supplyId: supply.id);
      if (isNotFound(error)) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.supplyGone)));
        if (mounted) navigator.pop();
        return;
      }
      if (mounted) setState(() => _failure = errorMessageFor(error, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final supply = widget.supply;
    final package = supplyAmount(l10n, supply.unit, supply.packageSize);
    final failure = _failure;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CbSpace.s4,
            0,
            CbSpace.s4,
            CbSpace.s4,
          ),
          child: IgnorePointer(
            ignoring: _busy,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isPurchase
                      ? l10n.supplyPurchaseTitle(supply.name)
                      : l10n.supplyCountTitle(supply.name),
                  style: text.title,
                ),
                const SizedBox(height: CbSpace.s4),
                _Counter(
                  key: const ValueKey('packages'),
                  label: _isPurchase
                      ? l10n.supplyPackagesBought(package)
                      : l10n.supplyPackagesClosed(package),
                  value: _packages,
                  min: _isPurchase ? 1 : 0,
                  max: _maxPackages,
                  onChanged: (value) => setState(() => _packages = value),
                ),
                if (!_isPurchase) ...[
                  const SizedBox(height: CbSpace.s4),
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
                  Text(
                    l10n.supplyCountTotal(
                      supplyAmount(l10n, supply.unit, _quantity),
                    ),
                    style: text.bodySm.copyWith(color: context.cb.inkMuted),
                  ),
                ],
                if (failure != null) ...[
                  const SizedBox(height: CbSpace.s3),
                  CbNotice.error(message: failure),
                ],
                const SizedBox(height: CbSpace.s4),
                FilledButton(
                  key: const ValueKey('saveStock'),
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: CbSpace.s5,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isPurchase
                              ? l10n.supplyPurchaseSave
                              : l10n.supplyCountSave,
                        ),
                ),
                if (!_isPurchase) ...[
                  const SizedBox(height: CbSpace.s2),
                  OutlinedButton(
                    key: const ValueKey('nothingLeft'),
                    onPressed: _busy ? null : () => _save(nothingLeft: true),
                    child: Text(l10n.supplyNothingLeft),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A number with − and + buttons.
class _Counter extends StatelessWidget {
  const _Counter({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    return Row(
      children: [
        Expanded(child: Text(label, style: text.body)),
        IconButton.outlined(
          style: cbOutlinedIconButtonStyle(context),
          tooltip: l10n.supplyLess,
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Symbols.remove_rounded),
        ),
        SizedBox(
          width: 48,
          child: Text('$value', textAlign: TextAlign.center, style: text.title),
        ),
        IconButton.outlined(
          style: cbOutlinedIconButtonStyle(context),
          tooltip: l10n.supplyMore,
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Symbols.add_rounded),
        ),
      ],
    );
  }
}
