import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/cb_action_card.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../household/current_household.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';

/// What to set up first, when nothing is planned yet: on an empty Today,
/// and on Home when the pets have nothing set up. Nothing can be planned
/// without a pet, so that comes first (a filled button); with pets, action
/// cards for their feeding and their care plan (vaccinations, treatments),
/// and a visit, which needs no plan. Helpers don't set things up: for them
/// it only says what will show here.
class TodayFirstSteps extends ConsumerWidget {
  const TodayFirstSteps({
    super.key,
    this.header = true,
    this.visit = true,
    this.padding = const EdgeInsets.symmetric(horizontal: CbSpace.s4),
  });

  /// Today says above the cards that nothing is scheduled yet; Home has a
  /// heading of its own and shows the cards only.
  final bool header;

  /// The visit card; Home leaves it out, its quick actions have one.
  final bool visit;

  /// Around the cards: Today's list has no side padding, Home's has.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pets = ref.watch(petsProvider).value;
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    final active = [
      for (final pet in pets ?? const <Pet>[])
        if (pet.isActive) pet,
    ];
    // Until the pets are known, no first step is guessed.
    if (pets != null && active.isEmpty) {
      return Column(
        children: [
          CbEmptyState(
            icon: Symbols.pets_rounded,
            title: canEdit ? l10n.todayStartTitle : l10n.petsEmptyTitle,
            message: canEdit ? l10n.todayStartBody : l10n.todayStartBodyHelper,
          ),
          if (canEdit)
            FilledButton.icon(
              // The Pets tab, with the form open on its list.
              onPressed: () => _goToPets(context, AppRoutes.newPet),
              icon: const Icon(Symbols.add_rounded),
              label: Text(l10n.petsAdd),
            ),
        ],
      );
    }
    final empty = CbEmptyState(
      icon: Symbols.event_available_rounded,
      title: l10n.todayEmptyTitle,
      message: l10n.todayEmptyBody,
    );
    if (!canEdit) return header ? empty : const SizedBox.shrink();
    // With one pet, straight to its form; with several, to the list to
    // pick one.
    final only = active.length == 1 ? active.single : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header) empty,
        Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pets != null) ...[
                CbActionCard(
                  key: const ValueKey('firstFeeding'),
                  icon: Symbols.restaurant_rounded,
                  title: l10n.todayAddFeeding,
                  hint: l10n.todayAddFeedingHint,
                  onTap: () => _goToPets(
                    context,
                    only == null
                        ? AppRoutes.pets
                        : AppRoutes.newFeeding(only.id),
                  ),
                ),
                const SizedBox(height: CbSpace.s2),
                CbActionCard(
                  key: const ValueKey('firstCare'),
                  icon: Symbols.vaccines_rounded,
                  title: l10n.todayAddCare,
                  hint: l10n.todayAddCareHint,
                  onTap: () => _goToPets(
                    context,
                    only == null
                        ? AppRoutes.pets
                        : AppRoutes.carePresets(only.id),
                  ),
                ),
              ],
              if (visit) ...[
                if (pets != null) const SizedBox(height: CbSpace.s2),
                CbActionCard(
                  key: const ValueKey('firstVisit'),
                  icon: Symbols.stethoscope_rounded,
                  title: l10n.visitAddCard,
                  hint: l10n.visitAddCardHint,
                  onTap: () => context.push(AppRoutes.newVisit),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Opens [location] on the Pets tab. That replaces the screens open there,
  /// so a form with typed input on any tab asks first.
  static Future<void> _goToPets(BuildContext context, String location) async {
    if (LeaveGuard.anyChanged() && !await confirmLeave(context)) return;
    if (context.mounted) context.go(location);
  }
}
