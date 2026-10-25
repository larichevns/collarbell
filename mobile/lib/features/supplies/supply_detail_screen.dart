import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/cb_status_tag.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../care/care_labels.dart' show formatDecimal;
import '../feeding/feeding_labels.dart' show portionLabel;
import '../household/current_household.dart';
import '../pets/pet_detail_screen.dart';
import 'stock_sheets.dart';
import 'supplies_repository.dart';
import 'supply.dart';
import 'supply_labels.dart';
import 'supply_plan_offer.dart';
import 'supply_refresh.dart';

/// One item: how long it lasts and when to buy it, "Bought" and "Correct
/// the stock", the feedings that use it, its details and its purchases.
class SupplyDetailScreen extends ConsumerWidget {
  const SupplyDetailScreen({super.key, required this.supplyId, this.planOffer});

  final String supplyId;

  /// A medicine just added from photos: the page offers a treatment plan.
  final SupplyPlanOffer? planOffer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final supply = ref.watch(supplyProvider(supplyId));
    final value = supply.value;
    if (value == null) {
      return Scaffold(
        appBar: AppBar(),
        body: supply.hasError
            ? Center(
                child: CbErrorState(
                  message: errorMessageFor(supply.error!, l10n),
                  traceId: traceIdOf(supply.error!),
                  onRetry: () => ref.invalidate(supplyProvider(supplyId)),
                ),
              )
            : const CbLoadingState(),
      );
    }

    final cb = context.cb;
    // Helpers mark purchases and counts; the item itself is for the others.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    return Scaffold(
      appBar: AppBar(
        title: Text(value.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (canEdit && !value.hasUnknownValues)
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Symbols.edit_rounded),
              onPressed: () => context.push(AppRoutes.editSupply(value.id)),
            ),
          if (canEdit)
            PopupMenuButton<_SupplyAction>(
              tooltip: l10n.commonMoreActions,
              // ⋮ in Material Symbols, as every other icon.
              icon: const Icon(Symbols.more_vert_rounded),
              onSelected: (action) => switch (action) {
                _SupplyAction.delete => _delete(context, ref, value),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _SupplyAction.delete,
                  child: Text(
                    l10n.supplyDelete,
                    style: TextStyle(color: cb.danger),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshSupplies(
            ProviderScope.containerOf(context, listen: false),
            supplyId: supplyId,
          );
          try {
            await ref.read(supplyProvider(supplyId).future);
          } catch (_) {
            // The error is shown by the error state.
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(CbSpace.s4),
          children: [
            if (planOffer case final offer? when canEdit)
              SupplyPlanOfferCard(offer: offer),
            if (!value.active) ...[
              CbNotice(message: l10n.supplyInactiveNote),
              const SizedBox(height: CbSpace.s4),
            ],
            _ForecastCard(supply: value, canEdit: canEdit),
            const SizedBox(height: CbSpace.s4),
            // "Bought" as wide as its word; "Correct the stock" takes the
            // rest, so its longer words stay on one line.
            Row(
              children: [
                FilledButton.icon(
                  key: const ValueKey('bought'),
                  onPressed: () =>
                      showPurchaseSheet(context, StockTarget.of(value)),
                  icon: const Icon(Symbols.add_shopping_cart_rounded),
                  label: Text(l10n.supplyBought),
                ),
                const SizedBox(width: CbSpace.s2),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('count'),
                    onPressed: () =>
                        showCountSheet(context, StockTarget.of(value)),
                    icon: const Icon(Symbols.tune_rounded),
                    label: Text(l10n.supplyCount),
                  ),
                ),
              ],
            ),
            if (value.usageMode == SupplyUsageMode.feeding) ...[
              const SizedBox(height: CbSpace.s6),
              CbSection(
                title: l10n.supplyFeedingsTitle,
                child: _Feedings(supply: value, canEdit: canEdit),
              ),
            ],
            const SizedBox(height: CbSpace.s6),
            CbSection(
              title: l10n.supplyDetailsTitle,
              child: _Details(supply: value),
            ),
            const SizedBox(height: CbSpace.s6),
            CbSection(
              title: l10n.supplyHistoryTitle,
              child: _History(supply: value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Supply supply,
  ) async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.supplyDeleteTitle(supply.name),
      message: l10n.supplyDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final supplies = ref.read(suppliesRepositoryProvider);
    try {
      await supplies.deleteSupply(supply.id);
      refreshSupplies(container);
      if (context.mounted) navigator.pop();
    } catch (error) {
      debugPrint('Deleting the supply failed: $error');
      refreshSupplies(container, supplyId: supply.id);
      if (isNotFound(error)) {
        if (context.mounted) navigator.pop();
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    }
  }
}

/// How long it lasts, when it runs out and when to buy it; what is left and
/// how much is used a day.
class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.supply, required this.canEdit});

  final Supply supply;

  /// Says how to set the use up: not to helpers.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    final forecast = supply.forecast;
    final remaining = forecast.remaining;
    final perDay = forecast.usagePerDay;
    final days = forecast.daysLeft;
    final runsOutOn = forecast.runsOutOn;
    final buyBy = forecast.buyBy;

    final headline = switch (forecast.status) {
      SupplyStatus.noStock => l10n.supplyNoStock,
      SupplyStatus.noUsage => l10n.supplyNoUsage,
      SupplyStatus.outOfStock => l10n.supplyOutOfStock,
      _ when days != null => l10n.supplyEnoughFor(supplyDaysLabel(l10n, days)),
      _ => l10n.supplyNoUsage,
    };
    final lines = <String>[
      if (remaining != null)
        l10n.supplyRemaining(
          supplyAmount(l10n, supply.unit, remaining),
          supplyPackages(l10n, remaining / supply.packageSize),
        ),
      if (runsOutOn != null && forecast.status != SupplyStatus.outOfStock)
        l10n.supplyRunsOutOn(supplyLongDate(l10n, runsOutOn)),
      if (runsOutOn != null && forecast.status == SupplyStatus.outOfStock)
        l10n.supplyRanOutOn(supplyLongDate(l10n, runsOutOn)),
      if (buyBy != null && forecast.status != SupplyStatus.outOfStock)
        l10n.supplyBuyBy(
          supplyLongDate(l10n, buyBy),
          l10n.supplyLeadTimeDays(supply.leadTimeDays),
        ),
      if (perDay != null)
        supply.usageMode == SupplyUsageMode.feeding
            ? l10n.supplyUsageFromFeeding(
                supplyAmount(l10n, supply.unit, perDay),
              )
            : l10n.supplyUsageManual(supplyAmount(l10n, supply.unit, perDay)),
    ];
    final hint = switch (forecast.status) {
      SupplyStatus.noStock => l10n.supplyNoStockHint,
      // How to set the use up: in forms helpers don't open.
      SupplyStatus.noUsage when !canEdit => null,
      SupplyStatus.noUsage when supply.usageMode == SupplyUsageMode.feeding =>
        l10n.supplyNoUsageFeedingHint,
      SupplyStatus.noUsage => l10n.supplyNoUsageManualHint,
      _ => null,
    };

    return CbCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            supplyCategoryIcon(supply.category),
            color: supply.active ? cb.primaryText : cb.inkMuted,
          ),
          const SizedBox(width: CbSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Ran out" and "Time to buy" as status tags, as in the list.
                if (supply.active && forecast.status == SupplyStatus.outOfStock)
                  CbStatusTag.overdue(headline)
                else ...[
                  if (supply.active && forecast.status == SupplyStatus.buyNow)
                    Padding(
                      padding: const EdgeInsets.only(bottom: CbSpace.s1),
                      child: CbStatusTag.soon(
                        l10n.supplyTimeToBuy,
                        icon: Symbols.shopping_cart_rounded,
                      ),
                    ),
                  Text(
                    headline,
                    style: text.subtitle.copyWith(
                      color: supply.active ? null : cb.inkMuted,
                    ),
                  ),
                ],
                for (final line in lines) ...[
                  const SizedBox(height: CbSpace.s1),
                  Text(line, style: text.bodySm),
                ],
                if (hint != null) ...[
                  const SizedBox(height: CbSpace.s2),
                  Text(hint, style: text.bodySm.copyWith(color: cb.inkMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The feedings that give this food: the pet, the portion and how often.
class _Feedings extends StatelessWidget {
  const _Feedings({required this.supply, required this.canEdit});

  final Supply supply;

  /// Says how to pick this food in a feeding: not to helpers.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    if (supply.feedings.isEmpty) {
      return Text(
        canEdit ? l10n.supplyNoFeedings : l10n.supplyNoFeedingsHelper,
        style: text.bodySm.copyWith(color: cb.inkMuted),
      );
    }
    return CbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final feeding in supply.feedings)
            ListTile(
              key: ValueKey('feeding-${feeding.routineId}'),
              title: Text(feeding.petName),
              // A feeding that isn't counted is something to check.
              subtitle: feeding.counted
                  ? Text(
                      l10n.supplyFeedingPortion(
                        feeding.amount == null || feeding.unit == null
                            ? ''
                            : portionLabel(
                                l10n,
                                feeding.amount!,
                                feeding.unit!,
                              ),
                        formatDecimal(
                          l10n,
                          (feeding.timesPerDay * 10).round() / 10,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: CbSpace.s1),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: CbStatusTag.soon(
                          l10n.supplyFeedingNotCounted,
                          icon: Symbols.info_rounded,
                        ),
                      ),
                    ),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () => context.push(
                AppRoutes.pet(feeding.petId, tab: PetTab.feeding),
              ),
            ),
        ],
      ),
    );
  }
}

/// Package size, energy, barcode, delivery time, the shop and notes.
class _Details extends StatelessWidget {
  const _Details({required this.supply});

  final Supply supply;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = supply.brand;
    final kcal = supply.kcalPerKg;
    final barcode = supply.barcode;
    final url = supply.storeUrl;
    final notes = supply.notes;
    return CbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CbDetailRow(
            label: l10n.supplyCategoryLabel,
            value: supplyCategoryLabel(l10n, supply.category),
          ),
          if (brand != null)
            CbDetailRow(label: l10n.supplyBrandLabel, value: brand),
          CbDetailRow(
            label: l10n.supplyPackageLabel,
            value: supplyAmount(l10n, supply.unit, supply.packageSize),
          ),
          if (kcal != null)
            CbDetailRow(
              label: l10n.supplyKcalLabel,
              value: l10n.supplyKcal(kcal),
            ),
          CbDetailRow(
            label: l10n.supplyLeadTimeLabel,
            value: l10n.supplyLeadTimeDays(supply.leadTimeDays),
          ),
          if (barcode != null)
            CbDetailRow(label: l10n.supplyBarcodeLabel, value: barcode),
          if (notes != null)
            CbDetailRow(label: l10n.careNotesLabel, value: notes),
          if (url != null) ...[
            const SizedBox(height: CbSpace.s2),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('store'),
                style: cbInlineTextButtonStyle,
                onPressed: () => _open(context, url),
                icon: const Icon(Symbols.open_in_new_rounded),
                label: Text(l10n.supplyOpenStore),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final uri = Uri.tryParse(url);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.supplyStoreFailed)));
    }
  }
}

/// Purchases and counts, newest first; one entered by mistake can be taken
/// back.
class _History extends ConsumerWidget {
  const _History({required this.supply});

  final Supply supply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    final stock = ref.watch(stockProvider(supply.id));
    final permissions = ref.watch(householdPermissionsProvider);
    final entries = stock.value;
    if (entries == null) {
      return stock.hasError
          ? CbErrorState(
              message: errorMessageFor(stock.error!, l10n),
              traceId: traceIdOf(stock.error!),
              onRetry: () => ref.invalidate(stockProvider(supply.id)),
            )
          : const CbLoadingState();
    }
    if (entries.isEmpty) {
      return Text(
        l10n.supplyHistoryEmpty,
        style: text.bodySm.copyWith(color: cb.inkMuted),
      );
    }
    final format = DateFormat.MMMd(l10n.localeName);
    return CbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final entry in entries)
            ListTile(
              key: ValueKey('entry-${entry.id}'),
              leading: Icon(
                entry.kind == StockEventKind.purchase
                    ? Symbols.add_shopping_cart_rounded
                    : Symbols.tune_rounded,
              ),
              title: Text(switch (entry.kind) {
                StockEventKind.purchase => l10n.supplyEntryPurchase(
                  supplyAmount(l10n, supply.unit, entry.quantity),
                ),
                StockEventKind.adjustment => l10n.supplyEntryCount(
                  supplyAmount(l10n, supply.unit, entry.quantity),
                ),
                null => supplyAmount(l10n, supply.unit, entry.quantity),
              }),
              subtitle: Text(
                [
                  format.format(entry.at),
                  if (entry.byMe)
                    l10n.supplyEntryByMe
                  else if (entry.byName != null)
                    entry.byName!,
                ].join(' · '),
              ),
              // Helpers take back only their own.
              trailing: permissions.canTakeBack(byMe: entry.byMe)
                  ? IconButton(
                      tooltip: l10n.supplyEntryUndo,
                      icon: const Icon(Symbols.undo_rounded),
                      onPressed: () => _undo(context, ref, entry),
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _undo(
    BuildContext context,
    WidgetRef ref,
    StockEntry entry,
  ) async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.supplyEntryUndoTitle,
      message: l10n.supplyEntryUndoBody,
      confirmLabel: l10n.supplyEntryUndo,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final supplies = ref.read(suppliesRepositoryProvider);
    try {
      await supplies.deleteStock(supply.id, entry.id);
    } catch (error) {
      debugPrint('Taking the stock entry back failed: $error');
      if (!isNotFound(error)) {
        messenger.showSnackBar(
          SnackBar(content: Text(errorMessageFor(error, l10n))),
        );
      }
    } finally {
      refreshSupplies(container, supplyId: supply.id);
    }
  }
}

enum _SupplyAction { delete }
