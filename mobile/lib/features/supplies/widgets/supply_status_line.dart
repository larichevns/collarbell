import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_status_tag.dart';
import '../../../theme/collarbell_theme.dart';
import '../supply.dart';
import '../supply_labels.dart';

/// An item's status under its name. "Ran out" is a red tag; "Time to buy" is
/// a yellow one, followed by how long the rest lasts; any other status is
/// the calm, muted [otherwise].
class SupplyStatusLine extends StatelessWidget {
  const SupplyStatusLine({
    super.key,
    required this.status,
    required this.daysLeft,
    required this.otherwise,
  });

  /// Null for an item no longer bought: no tag.
  final SupplyStatus? status;
  final double? daysLeft;

  /// The words for a status without a tag (see [supplyStatusLine]).
  final String otherwise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = context.cbText.bodySm.copyWith(color: context.cb.inkMuted);
    final days = daysLeft;
    return switch (status) {
      SupplyStatus.outOfStock => Align(
        alignment: AlignmentDirectional.centerStart,
        child: CbStatusTag.overdue(l10n.supplyOutOfStock),
      ),
      SupplyStatus.buyNow => MergeSemantics(
        child: Wrap(
          spacing: CbSpace.s2,
          runSpacing: CbSpace.s1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CbStatusTag.soon(
              l10n.supplyTimeToBuy,
              icon: Symbols.shopping_cart_rounded,
            ),
            if (days != null)
              Text(
                l10n.supplyEnoughFor(supplyDaysLabel(l10n, days)),
                style: style,
              ),
          ],
        ),
      ),
      _ => Text(otherwise, style: style),
    };
  }
}
