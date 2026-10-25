import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_action_card.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/reload_on_resume.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../ai/ai_repository.dart';
import '../ai/widgets/ai_status_refresher.dart';
import '../household/current_household.dart';
import 'stock_sheets.dart';
import 'supplies_repository.dart';
import 'supply.dart';
import 'supply_labels.dart';
import 'widgets/supply_status_line.dart';

/// Food, litter and medication with how long they last: what to buy now
/// first, then what runs out soon, then the rest; items no longer bought at
/// the end.
class SuppliesScreen extends ConsumerWidget {
  const SuppliesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final supplies = ref.watch(suppliesProvider);
    // Helpers mark purchases; adding items is for the others.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    final value = supplies.value;
    // Loaded here, so the add sheet knows whether photos can be read.
    final ai = ref.watch(aiStatusProvider);

    final Widget content;
    if (supplies.hasError && !supplies.isLoading) {
      content = CbErrorState(
        message: errorMessageFor(supplies.error!, l10n),
        traceId: traceIdOf(supplies.error!),
        onRetry: () => ref.invalidate(suppliesProvider),
      );
    } else if (value == null) {
      content = const CbLoadingState();
    } else if (value.isEmpty) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CbEmptyState(
            icon: Symbols.inventory_2_rounded,
            title: l10n.suppliesEmptyTitle,
            message: canEdit
                ? l10n.suppliesEmptyBody
                : l10n.suppliesEmptyBodyHelper,
          ),
          // The ways to add the first item, right here (the button over
          // the list comes with it).
          if (canEdit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CbSpace.s4),
              child: _FirstSupply(aiReady: ai.value?.configured ?? false),
            ),
        ],
      );
    } else {
      final buy = [
        for (final s in value)
          if (s.needsBuying) s,
      ];
      final soon = [
        for (final s in value)
          if (s.active && s.forecast.status == SupplyStatus.soon) s,
      ];
      final rest = [
        for (final s in value)
          if (s.active &&
              !s.needsBuying &&
              s.forecast.status != SupplyStatus.soon)
            s,
      ];
      final paused = [
        for (final s in value)
          if (!s.active) s,
      ];
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: CbSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (title, items) in [
              (l10n.suppliesToBuy, buy),
              (l10n.suppliesSoon, soon),
              (l10n.suppliesInStock, rest),
              (l10n.suppliesNotBought, paused),
            ])
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: CbSpace.s6),
                  child: CbSection(
                    title: title,
                    child: SupplyList(supplies: items),
                  ),
                ),
          ],
        ),
      );
    }

    return ReloadOnResume(
      // Another phone may have marked a purchase meanwhile: it must not look
      // due here and be bought twice.
      onResume: () => ref.invalidate(suppliesProvider),
      child: Scaffold(
        floatingActionButton: canEdit && showsAddOverList(supplies)
            ? FloatingActionButton.extended(
                key: const ValueKey('addSupply'),
                onPressed: () => showAddSupplySheet(context, ref),
                icon: const Icon(Symbols.add_rounded),
                label: Text(l10n.supplyAdd),
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: AiStatusRefresher(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(suppliesProvider);
                try {
                  await ref.read(suppliesProvider.future);
                } catch (_) {
                  // The error is shown by the error state.
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                // Room for the button over the last row.
                padding: EdgeInsets.only(
                  bottom: canEdit ? CbSpace.s12 * 2 : CbSpace.s12,
                ),
                children: [
                  ScreenHeader(title: l10n.suppliesTitle),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ways to add an item: scan its barcode, take photos of the package (with
/// AI set up), or type it in.
Future<void> showAddSupplySheet(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final aiReady = ref.read(aiStatusProvider).value?.configured ?? false;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('addByBarcode'),
            leading: const Icon(Symbols.qr_code_scanner_rounded),
            title: Text(l10n.supplyAddByBarcode),
            subtitle: Text(l10n.supplyAddByBarcodeHelper),
            onTap: () {
              Navigator.of(sheet).pop();
              context.push(AppRoutes.supplyScan());
            },
          ),
          if (aiReady)
            ListTile(
              key: const ValueKey('addByPhoto'),
              leading: const Icon(Symbols.photo_camera_rounded),
              title: Text(l10n.supplyAddByPhoto),
              subtitle: Text(l10n.supplyAddByPhotoHelper),
              onTap: () {
                Navigator.of(sheet).pop();
                context.push(AppRoutes.supplyScan(photos: true));
              },
            ),
          ListTile(
            key: const ValueKey('addByHand'),
            leading: const Icon(Symbols.edit_rounded),
            title: Text(l10n.supplyAddByHand),
            onTap: () {
              Navigator.of(sheet).pop();
              context.push(AppRoutes.newSupply);
            },
          ),
          const SizedBox(height: CbSpace.s2),
        ],
      ),
    ),
  );
}

/// No supplies yet: the ways to add the first one, as action cards (the
/// same as the add sheet's).
class _FirstSupply extends StatelessWidget {
  const _FirstSupply({required this.aiReady});

  final bool aiReady;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CbActionCard(
          key: const ValueKey('firstByBarcode'),
          icon: Symbols.barcode_scanner_rounded,
          title: l10n.supplyAddByBarcode,
          hint: l10n.supplyAddByBarcodeHelper,
          onTap: () => context.push(AppRoutes.supplyScan()),
        ),
        if (aiReady) ...[
          const SizedBox(height: CbSpace.s2),
          CbActionCard(
            key: const ValueKey('firstByPhoto'),
            icon: Symbols.photo_camera_rounded,
            title: l10n.supplyAddByPhoto,
            hint: l10n.supplyAddByPhotoHelper,
            onTap: () => context.push(AppRoutes.supplyScan(photos: true)),
          ),
        ],
        const SizedBox(height: CbSpace.s2),
        CbActionCard(
          key: const ValueKey('firstByHand'),
          icon: Symbols.edit_rounded,
          title: l10n.supplyAddByHand,
          hint: l10n.supplyAddByHandHelper,
          onTap: () => context.push(AppRoutes.newSupply),
        ),
      ],
    );
  }
}

/// Items in a card, one per row.
class SupplyList extends StatelessWidget {
  const SupplyList({super.key, required this.supplies});

  final List<Supply> supplies;

  @override
  Widget build(BuildContext context) {
    return CbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < supplies.length; i++) ...[
            if (i > 0) const Divider(indent: CbSpace.s4 + 40 + CbSpace.s3),
            SupplyRow(key: ValueKey(supplies[i].id), supply: supplies[i]),
          ],
        ],
      ),
    );
  }
}

/// One item: its kind, name and brand, how long it lasts, and "Bought" when
/// it's time to buy it.
class SupplyRow extends StatelessWidget {
  const SupplyRow({super.key, required this.supply});

  final Supply supply;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    final brand = supply.brand;
    return InkWell(
      onTap: () => context.push(AppRoutes.supply(supply.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s3,
          CbSpace.s4,
          CbSpace.s3,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cb.sunken,
              foregroundColor: supply.active ? cb.primaryText : cb.inkMuted,
              child: Icon(supplyCategoryIcon(supply.category)),
            ),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supply.name,
                      style: text.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (brand != null)
                      Text(
                        brand,
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    SupplyStatusLine(
                      status: supply.active ? supply.forecast.status : null,
                      daysLeft: supply.forecast.daysLeft,
                      otherwise: supplyStatusLine(l10n, supply),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CbSpace.s2),
            if (supply.needsBuying)
              FilledButton.tonal(
                key: ValueKey('bought-${supply.id}'),
                onPressed: () =>
                    showPurchaseSheet(context, StockTarget.of(supply)),
                child: Text(l10n.supplyBought),
              )
            else
              const Icon(Symbols.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
