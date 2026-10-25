import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/keep_tab_alive.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../care/health_tab.dart';
import '../documents/documents_tab.dart';
import '../feeding/feeding_tab.dart';
import '../household/current_household.dart';
import '../passport/passport_tab.dart';
import '../supplies/supply_refresh.dart';
import '../today/today_repository.dart';
import '../weight/weight_tab.dart';
import 'pet.dart';
import 'pet_overview_tab.dart';
import 'pets_repository.dart';

/// The tabs of the pet's page, in order.
enum PetTab { overview, health, passport, documents, feeding, weight }

/// One pet with the tabs Overview, Health, Passport, Documents, Feeding and
/// Weight.
class PetDetailScreen extends ConsumerWidget {
  const PetDetailScreen({super.key, required this.petId, this.initialTab});

  final String petId;

  /// The tab to open first; Overview when null. Today opens Health.
  final PetTab? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pet = ref.watch(petProvider(petId));
    // Until the pet's own answer comes, the list's copy of it: the page
    // opens at once instead of with a spinner, and stays when the server
    // can't be reached. The pet deleted on another phone shows as an error.
    final listed = ref
        .watch(petsProvider)
        .value
        ?.where((candidate) => candidate.id == petId)
        .firstOrNull;
    final value = pet.value ?? (isNotFound(pet.error ?? '') ? null : listed);
    if (value == null) {
      return Scaffold(
        appBar: AppBar(),
        body: pet.hasError
            ? Center(
                child: CbErrorState(
                  message: errorMessageFor(pet.error!, l10n),
                  traceId: traceIdOf(pet.error!),
                  onRetry: () => ref.invalidate(petProvider(petId)),
                ),
              )
            : const CbLoadingState(),
      );
    }

    final initialTab = this.initialTab ?? PetTab.overview;
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    return DefaultTabController(
      // A link to another tab while this page is open starts the tabs again
      // on that one. (Today opens a new page every time instead.)
      key: ValueKey(initialTab),
      length: PetTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(value.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (canEdit) ...[
              IconButton(
                tooltip: l10n.petEdit,
                icon: const Icon(Symbols.edit_rounded),
                onPressed: () => context.push(AppRoutes.editPet(petId)),
              ),
              PopupMenuButton<_PetAction>(
                tooltip: l10n.commonMoreActions,
                // ⋮ in Material Symbols, as every other icon.
                icon: const Icon(Symbols.more_vert_rounded),
                onSelected: (action) => switch (action) {
                  _PetAction.delete => _delete(context, ref, value),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _PetAction.delete,
                    child: Row(
                      children: [
                        Icon(Symbols.delete_rounded, color: context.cb.danger),
                        const SizedBox(width: CbSpace.s3),
                        Text(
                          l10n.petDelete,
                          style: TextStyle(color: context.cb.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
          bottom: TabBar(
            // Six tabs don't fit a phone side by side in every language: the
            // bar scrolls instead of cutting a name off.
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            // Narrower than Material's 16: more of the tabs show at once,
            // and less of the bar has to be scrolled.
            labelPadding: const EdgeInsets.symmetric(horizontal: CbSpace.s3),
            tabs: [
              for (final tab in PetTab.values)
                Tab(
                  text: switch (tab) {
                    PetTab.overview => l10n.petTabOverview,
                    PetTab.health => l10n.petTabHealth,
                    PetTab.passport => l10n.petTabPassport,
                    PetTab.documents => l10n.petTabDocuments,
                    PetTab.feeding => l10n.petTabFeeding,
                    PetTab.weight => l10n.petTabWeight,
                  },
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in PetTab.values)
              // Each tab stays loaded while the others are shown.
              KeepTabAlive(
                child: switch (tab) {
                  PetTab.overview => PetOverviewTab(pet: value),
                  PetTab.health => HealthTab(pet: value),
                  PetTab.passport => PassportTab(pet: value),
                  PetTab.documents => DocumentsTab(pet: value),
                  PetTab.feeding => FeedingTab(pet: value),
                  PetTab.weight => WeightTab(pet: value),
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Asks first: deleting also removes the passport, documents and photos.
  Future<void> _delete(BuildContext context, WidgetRef ref, Pet pet) async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.petDeleteTitle(pet.name),
      message: l10n.petDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !context.mounted) return;

    // Read before the request: the screen may be gone when it returns, and
    // its ref with it.
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = ref.read(petsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    try {
      await repository.deletePet(pet.id);
      container.invalidate(petsProvider);
      // Its plans leave Today too, its feedings the estimates of supplies.
      container.invalidate(todayProvider);
      refreshSupplyEstimates(container);
      if (!context.mounted) return;
      // Back to where the page was opened from: the pets list, or Today.
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        router.go(AppRoutes.pets);
      }
    } catch (error) {
      debugPrint('Deleting the pet failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    }
  }
}

enum _PetAction { delete }
