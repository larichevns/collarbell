import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/cb_card.dart';
import '../../theme/collarbell_theme.dart';
import '../care/care.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';

/// A medicine just added from photos of its package says how long a dose
/// protects: its page offers a treatment plan with that interval (spec,
/// scenarios: "a plan with the interval from the package").
@immutable
class SupplyPlanOffer {
  const SupplyPlanOffer({
    required this.kind,
    required this.weeks,
    required this.product,
  });

  final CareKind kind;
  final int weeks;

  /// The medicine's name, the plan's product.
  final String product;
}

/// "This medicine protects for 12 weeks. Add a treatment plan?" Until the
/// user picks a pet (the plan form opens for it) or says no.
class SupplyPlanOfferCard extends ConsumerStatefulWidget {
  const SupplyPlanOfferCard({super.key, required this.offer});

  final SupplyPlanOffer offer;

  @override
  ConsumerState<SupplyPlanOfferCard> createState() =>
      _SupplyPlanOfferCardState();
}

class _SupplyPlanOfferCardState extends ConsumerState<SupplyPlanOfferCard> {
  var _dismissed = false;

  Future<void> _addPlan() async {
    final l10n = context.l10n;
    final pets = [
      for (final pet in ref.read(petsProvider).value ?? const <Pet>[])
        if (pet.isActive) pet,
    ];
    final Pet? pet;
    if (pets.length == 1) {
      pet = pets.single;
    } else {
      pet = await showDialog<Pet>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(l10n.supplyPlanWhichPet),
          children: [
            for (final pet in pets)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(pet),
                child: Text(pet.name),
              ),
          ],
        ),
      );
    }
    if (pet == null || !mounted) return;
    final offer = widget.offer;
    await context.push(
      AppRoutes.newCarePlan(pet.id),
      extra: CarePlanDraft(
        kind: offer.kind,
        title: offer.product,
        interval: CareInterval(offer.weeks, IntervalUnit.week),
        product: offer.product,
      ),
    );
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final l10n = context.l10n;
    final text = context.cbText;
    final hasPets = (ref.watch(petsProvider).value ?? const <Pet>[]).any(
      (pet) => pet.isActive,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: CbSpace.s4),
      child: CbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.supplyPlanOfferTitle(widget.offer.weeks),
              style: text.subtitle,
            ),
            const SizedBox(height: CbSpace.s1),
            Text(l10n.supplyPlanOfferBody, style: text.bodySm),
            const SizedBox(height: CbSpace.s3),
            Wrap(
              spacing: CbSpace.s2,
              children: [
                if (hasPets)
                  FilledButton(
                    key: const ValueKey('addPlan'),
                    onPressed: _addPlan,
                    child: Text(l10n.supplyPlanAdd),
                  ),
                TextButton(
                  onPressed: () => setState(() => _dismissed = true),
                  child: Text(l10n.supplyPlanNo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
