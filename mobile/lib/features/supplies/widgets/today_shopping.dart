import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_card.dart';
import '../../../shared/widgets/cb_section.dart';
import '../../../theme/collarbell_theme.dart';
import '../stock_sheets.dart';
import '../supply.dart';
import '../supply_labels.dart';
import 'supply_status_line.dart';

/// "To buy" on the Today screen: supplies that ran out or run out within
/// their delivery time, with "Bought" right there.
class TodayShoppingSection extends StatelessWidget {
  const TodayShoppingSection({super.key, required this.items});

  final List<TodaySupply> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CbSection(
      title: l10n.todayShoppingTitle,
      // The Supplies tab as the user left it (a form there stays), like a
      // tap on the tab bar.
      action: OutlinedButton.icon(
        key: const ValueKey('allSupplies'),
        onPressed: () =>
            openTab(context, AppRoutes.suppliesBranch, AppRoutes.supplies),
        icon: const Icon(Symbols.inventory_2_rounded),
        label: Text(l10n.todayShoppingAll),
      ),
      child: CbCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(indent: CbSpace.s4 + 40 + CbSpace.s3),
              _ShoppingRow(key: ValueKey(items[i].id), item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({super.key, required this.item});

  final TodaySupply item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    return InkWell(
      onTap: () => context.push(AppRoutes.supply(item.id)),
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
              foregroundColor: cb.primaryText,
              child: Icon(supplyCategoryIcon(item.category)),
            ),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: text.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    SupplyStatusLine(
                      status: item.status,
                      daysLeft: item.daysLeft,
                      otherwise: l10n.supplyOutOfStock,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CbSpace.s2),
            FilledButton.tonal(
              key: ValueKey('todayBought-${item.id}'),
              onPressed: () =>
                  showPurchaseSheet(context, StockTarget.ofToday(item)),
              child: Text(l10n.supplyBought),
            ),
          ],
        ),
      ),
    );
  }
}
