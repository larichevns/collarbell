import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/reload_on_resume.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../household/current_household.dart';
import 'pet.dart';
import 'pet_labels.dart';
import 'pets_repository.dart';
import 'widgets/pet_avatar.dart';

class PetsScreen extends ConsumerWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pets = ref.watch(petsProvider);
    // Helpers look after the pets but don't add them.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;

    final Widget content;
    if (pets.isLoading && !pets.hasValue) {
      content = const SliverFillRemaining(
        hasScrollBody: false,
        child: CbLoadingState(),
      );
    } else if (pets.hasError && !pets.hasValue) {
      final error = pets.error!;
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CbErrorState(
            message: errorMessageFor(error, l10n),
            traceId: traceIdOf(error),
            onRetry: () => ref.invalidate(petsProvider),
          ),
        ),
      );
    } else {
      final list = pets.value ?? const <Pet>[];
      content = list.isEmpty
          ? SliverToBoxAdapter(
              child: CbEmptyState(
                icon: Symbols.pets_rounded,
                title: l10n.petsEmptyTitle,
                message: canEdit
                    ? l10n.petsEmptyBody
                    : l10n.petsEmptyBodyHelper,
              ),
            )
          : SliverPadding(
              // The bottom space keeps the last pet clear of the button.
              padding: EdgeInsets.fromLTRB(
                CbSpace.s4,
                0,
                CbSpace.s4,
                canEdit ? CbSpace.s12 + CbSize.controlMd : CbSpace.s12,
              ),
              sliver: SliverToBoxAdapter(child: _PetList(pets: list)),
            );
    }

    return ReloadOnResume(
      // Another phone may have added or changed a pet meanwhile.
      onResume: () => ref.invalidate(petsProvider),
      child: Scaffold(
        floatingActionButton: canEdit
            ? FloatingActionButton.extended(
                onPressed: () => context.push(AppRoutes.newPet),
                icon: const Icon(Symbols.add_rounded),
                label: Text(l10n.petsAdd),
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(petsProvider);
              try {
                await ref.read(petsProvider.future);
              } catch (_) {
                // The error is shown by the error state.
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: ScreenHeader(title: l10n.petsTitle)),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PetList extends StatelessWidget {
  const _PetList({required this.pets});

  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    // The API sends active pets first; keep that order whatever happens.
    final ordered = [
      ...pets.where((pet) => pet.isActive),
      ...pets.where((pet) => !pet.isActive),
    ];
    return CbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0)
              const Divider(indent: CbSpace.s4 + CbSize.avatarMd + CbSpace.s3),
            PetRow(
              pet: ordered[i],
              onTap: () => context.push(AppRoutes.pet(ordered[i].id)),
            ),
          ],
        ],
      ),
    );
  }
}

/// One pet in the list: avatar, name and species (with the breed if known).
/// Archived and deceased pets are drawn quieter, with their status.
class PetRow extends StatelessWidget {
  const PetRow({super.key, required this.pet, this.onTap});

  final Pet pet;
  final VoidCallback? onTap;

  /// Archived and deceased pets stay in the list, but fade back.
  static const inactiveOpacity = 0.6;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final breed = pet.breed?.trim();
    final details = [
      if (!pet.isActive) petStatusLabel(l10n, pet.status),
      petSpeciesLabel(l10n, pet.species),
      if (breed != null && breed.isNotEmpty) breed,
    ];

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CbSpace.s4,
            vertical: CbSpace.s3,
          ),
          child: Row(
            children: [
              Opacity(
                opacity: pet.isActive ? 1 : inactiveOpacity,
                child: PetAvatar(name: pet.name, photo: pet.photo),
              ),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: text.subtitle.copyWith(
                        color: pet.isActive ? cb.ink : cb.inkMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      details.join(' · '),
                      style: text.bodySm.copyWith(color: cb.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
