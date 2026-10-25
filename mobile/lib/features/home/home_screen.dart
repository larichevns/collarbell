import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/preferences.dart';
import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_action_card.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/cb_status_tag.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../ai/ai_repository.dart';
import '../ai/widgets/ai_status_refresher.dart';
import '../ai/widgets/scan_entry.dart';
import '../auth/auth_providers.dart';
import '../care/care.dart';
import '../feeding/feeding.dart';
import '../feeding/widgets/today_feeding.dart';
import '../household/current_household.dart';
import '../me/profile_sync.dart';
import '../onboarding/onboarding.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../pets/widgets/pet_avatar.dart';
import '../today/first_steps.dart';
import '../today/today.dart';
import '../today/today_reload.dart';
import '../today/today_repository.dart';
import '../today/today_screen.dart';
import '../visits/visit.dart';
import '../visits/widgets/today_visits.dart';
import '../weight/weighing_sheet.dart';
import 'pet_picker.dart';

/// The first tab, the one the app opens on: a greeting, the pets, what is
/// important right now (the next feeding with its "Fed" buttons, what is
/// overdue or due soon, the next visit, what to buy) and quick actions.
/// "Right now" is made of Today's data (`todayProvider`), so it reloads as
/// Today does; the Today tab keeps the full list.
///
/// Once its pets have loaded, it opens the onboarding by itself for a new
/// account with nothing set up ([OnboardingTurn]).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.now});

  /// Fixed clock for tests (the greeting); defaults to the current time.
  final DateTime? now;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TodayReload {
  /// Whether this screen asked about the onboarding: once, whatever
  /// rebuilds and reloads follow.
  var _onboardingAsked = false;

  /// Once the person's groups and the pets are known: the onboarding's
  /// turn ([OnboardingTurn]), and the onboarding on top of Home if it is
  /// due. Pets of any status count: a group with only a deceased pet isn't
  /// starting from nothing.
  void _askAboutOnboarding(List<Pet> pets, int households) {
    final uid = ref.read(authUserProvider)?.uid;
    if (uid == null || !mounted) return;
    final open = OnboardingTurn.takeTurn(
      ref.read(sharedPreferencesProvider),
      uid,
      households: households,
      canEdit: ref.read(householdPermissionsProvider).canEdit,
      hasPets: pets.isNotEmpty,
    );
    if (open) context.push(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pets = ref.watch(petsProvider);
    final me = ref.watch(meProvider);
    final today = ref.watch(todayProvider);
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    // Once loaded, the date is the server's "today" in the household's
    // time zone, as on Today. The greeting follows the phone's clock.
    final clock = widget.now ?? DateTime.now();
    final date = l10n.todayDate(today.value?.date ?? clock);
    final group = todayGroupShown(ref, l10n);

    // Asked once the person's groups and the pets have loaded (an offline
    // copy is real data too), not while either reloads, and only while
    // Home is in view, not under another tab. After the frame: no page is
    // pushed while this builds.
    final petList = pets.value;
    final households = me.value?.households;
    if (!_onboardingAsked &&
        petList != null &&
        !pets.isLoading &&
        households != null &&
        !me.isLoading &&
        TickerMode.of(context)) {
      _onboardingAsked = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _askAboutOnboarding(petList, households.length),
      );
    }
    final active = [
      for (final pet in petList ?? const <Pet>[])
        if (pet.isActive) pet,
    ];

    final List<Widget> content;
    if (pets.hasError && !pets.isLoading && !pets.hasValue) {
      content = [
        CbErrorState(
          message: errorMessageFor(pets.error!, l10n),
          traceId: traceIdOf(pets.error!),
          onRetry: () {
            ref.invalidate(petsProvider);
            ref.invalidate(todayProvider);
          },
        ),
      ];
    } else if (petList == null) {
      content = const [CbLoadingState()];
    } else if (active.isEmpty) {
      content = [_NoPets(canEdit: canEdit)];
    } else {
      content = [
        _PetsRow(pets: active, canEdit: canEdit),
        const SizedBox(height: CbSpace.s6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CbSpace.s4),
          child: CbSection(
            title: l10n.homeNowTitle,
            child: _RightNow(today: today, canEdit: canEdit),
          ),
        ),
        // Helpers mark and look; adding is for the others.
        if (canEdit) ...[
          const SizedBox(height: CbSpace.s6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CbSpace.s4),
            child: CbSection(
              title: l10n.homeQuickTitle,
              child: _QuickActions(pets: active),
            ),
          ),
        ],
      ];
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(petsProvider);
            ref.invalidate(todayProvider);
            try {
              await Future.wait([
                ref.read(petsProvider.future),
                ref.read(todayProvider.future),
              ]);
            } catch (_) {
              // The error is shown by the error states.
            }
          },
          child: ListView(
            // Pull to refresh works on a short screen too.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: CbSpace.s12),
            children: [
              ScreenHeader(
                // "среда, 1 октября" starts a line, so it is capitalised.
                caption: [
                  if (date.isNotEmpty)
                    date[0].toUpperCase() + date.substring(1),
                  ?group,
                ].join(' · '),
                title: homeGreeting(l10n, clock),
              ),
              ...content,
            ],
          ),
        ),
      ),
    );
  }
}

/// The greeting by the phone's time: morning from 05:00, afternoon from
/// 12:00, evening from 17:00, night from 23:00.
String homeGreeting(AppLocalizations l10n, DateTime now) => switch (now.hour) {
  >= 5 && < 12 => l10n.homeGreetingMorning,
  >= 12 && < 17 => l10n.homeGreetingAfternoon,
  >= 17 && < 23 => l10n.homeGreetingEvening,
  _ => l10n.homeGreetingNight,
};

/// The active pets in a row that scrolls sideways: a face and a name each.
/// A tap opens the pet's page on top of Home (as Today does), so a form
/// left open in the Pets tab stays. For those who can add pets, "Add" ends
/// the row.
class _PetsRow extends StatelessWidget {
  const _PetsRow({required this.pets, required this.canEdit});

  final List<Pet> pets;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    return Semantics(
      label: l10n.homePetsLabel,
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: CbSpace.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final pet in pets)
              _PetTile(
                key: ValueKey('homePet-${pet.id}'),
                label: pet.name,
                onTap: () => context.push(AppRoutes.pet(pet.id)),
                face: PetAvatar(
                  name: pet.name,
                  photo: pet.photo,
                  size: CbSize.avatarLg,
                ),
              ),
            if (canEdit)
              _PetTile(
                key: const ValueKey('homeAddPet'),
                label: l10n.commonAdd,
                onTap: () => context.push(AppRoutes.newPet),
                face: Container(
                  width: CbSize.avatarLg,
                  height: CbSize.avatarLg,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cb.lineStrong,
                      width: CbSize.borderWidth,
                    ),
                  ),
                  child: Icon(Symbols.add_rounded, color: cb.primaryText),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({
    super.key,
    required this.face,
    required this.label,
    required this.onTap,
  });

  final Widget face;
  final String label;
  final VoidCallback onTap;

  /// Room for a 64-px face and a name under it, wider with larger text.
  static const width = 80.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CbRadius.md),
        child: SizedBox(
          width: MediaQuery.textScalerOf(context).scale(width),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CbSpace.s2),
            child: Column(
              children: [
                face,
                const SizedBox(height: CbSpace.s1),
                Text(
                  label,
                  style: context.cbText.bodySm,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// No pets in the group yet: adding one comes first, and the onboarding
/// shows what the app does. Helpers don't add pets: for them it says what
/// will show here.
class _NoPets extends StatelessWidget {
  const _NoPets({required this.canEdit});

  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!canEdit) {
      return CbEmptyState(
        icon: Symbols.pets_rounded,
        title: l10n.petsEmptyTitle,
        message: l10n.todayStartBodyHelper,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CbSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CbActionCard(
            key: const ValueKey('homeAddPetCard'),
            primary: true,
            icon: Symbols.pets_rounded,
            title: l10n.homeAddPetTitle,
            hint: l10n.homeAddPetHint,
            onTap: () => context.push(AppRoutes.newPet),
          ),
          const SizedBox(height: CbSpace.s2),
          CbActionCard(
            key: const ValueKey('homeTour'),
            icon: Symbols.waving_hand_rounded,
            title: l10n.homeTourTitle,
            hint: l10n.homeTourHint,
            onTap: () => context.push(AppRoutes.welcome),
          ),
        ],
      ),
    );
  }
}

/// What needs doing now, from Today's data: the next feeding (its "Fed"
/// buttons work as on Today), the care that is overdue or due soon, the
/// next visit (a past one waiting for "How did it go?" first) and what to
/// buy. Nothing of that: all done. Nothing set up at all: the first steps.
class _RightNow extends ConsumerWidget {
  const _RightNow({required this.today, required this.canEdit});

  final AsyncValue<TodayOverview> today;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final value = today.value;
    // A failed reload shows the error, not the old data: a feeding just
    // marked would still look open.
    if (today.hasError && !today.isLoading) {
      return CbErrorState(
        message: errorMessageFor(today.error!, l10n),
        traceId: traceIdOf(today.error!),
        onRetry: () => ref.invalidate(todayProvider),
      );
    }
    if (value == null) return const CbLoadingState();
    if (value.isEmpty) {
      return canEdit
          ? const TodayFirstSteps(
              header: false,
              visit: false,
              padding: EdgeInsets.zero,
            )
          : _Calm(title: l10n.todayEmptyTitle, body: l10n.todayEmptyBody);
    }

    final next = nextFeeding(value.feedings);
    final overdue = value.items
        .where((item) => item.status == CareStatus.overdue)
        .length;
    final soon = value.items
        .where((item) => item.status == CareStatus.dueSoon)
        .length;
    final visit = nextVisit(value.visits);
    final toBuy = value.shopping.length;
    if (next == null &&
        overdue == 0 &&
        soon == 0 &&
        visit == null &&
        toBuy == 0) {
      return _Calm(
        key: const ValueKey('allDone'),
        title: l10n.homeAllDoneTitle,
        body: l10n.homeAllDoneBody,
        done: true,
      );
    }

    final rows = <Widget>[
      if (overdue > 0 || soon > 0)
        _NowRow(
          key: const ValueKey('nowCare'),
          icon: Symbols.vaccines_rounded,
          hint: l10n.homeCareHint,
          // The Today tab as the user left it, like a tap on the tab bar.
          onTap: () => openTab(context, AppRoutes.todayBranch, AppRoutes.today),
          title: Wrap(
            spacing: CbSpace.s2,
            runSpacing: CbSpace.s1,
            children: [
              if (overdue > 0) CbStatusTag.overdue(l10n.homeOverdue(overdue)),
              if (soon > 0) CbStatusTag.soon(l10n.homeDueSoon(soon)),
            ],
          ),
        ),
      if (visit != null)
        TodayVisitRow(
          key: ValueKey('nowVisit-${visit.id}'),
          visit: visit,
          today: value.date,
          chevron: true,
        ),
      if (toBuy > 0)
        _NowRow(
          key: const ValueKey('nowBuy'),
          icon: Symbols.shopping_cart_rounded,
          hint: l10n.homeToBuyHint,
          onTap: () =>
              openTab(context, AppRoutes.suppliesBranch, AppRoutes.supplies),
          title: Text(l10n.homeToBuy(toBuy), style: context.cbText.subtitle),
        ),
    ];

    // While it reloads (pulled, back in the app, the server back after
    // offline copies), the old data stays in view but takes no taps: "Fed"
    // on it could act on yesterday or on what is already done.
    return IgnorePointer(
      ignoring: today.isLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // All of today's feedings, the same list until Today reloads: the
          // section picks the next time itself and keeps a mark made here
          // in view while Today reloads.
          if (next != null)
            TodayFeedingSection(
              date: value.date,
              items: value.feedings,
              next: true,
            ),
          if (next != null && rows.isNotEmpty)
            const SizedBox(height: CbSpace.s3),
          if (rows.isNotEmpty)
            CbCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const Divider(indent: CbSpace.s4),
                    rows[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The visit to show first: a past one waiting for "How did it go?", else
/// the next one; null without visits.
TodayVisit? nextVisit(List<TodayVisit> visits) {
  for (final visit in visits) {
    if (visit.daysAway < 0) return visit;
  }
  return visits.firstOrNull;
}

/// A row of "Right now" that leads to a tab: an icon, what it is (a status
/// tag, a count) with a line under it, and a chevron.
class _NowRow extends StatelessWidget {
  const _NowRow({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final Widget title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(CbSpace.s4),
        child: Row(
          children: [
            Icon(icon, color: cb.primaryText),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: CbSpace.s1),
                    Text(
                      hint,
                      style: context.cbText.bodySm.copyWith(color: cb.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CbSpace.s2),
            Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// A quiet card: all done for today (with the green check), or nothing
/// planned yet.
class _Calm extends StatelessWidget {
  const _Calm({
    super.key,
    required this.title,
    required this.body,
    this.done = false,
  });

  final String title;
  final String body;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = context.cbText;
    return CbCard(
      child: Row(
        children: [
          Icon(
            done
                ? Symbols.check_circle_rounded
                : Symbols.event_available_rounded,
            // Done: the round check filled bright green, as a feeding's mark.
            fill: done ? 1 : 0,
            color: done ? cb.success : cb.inkMuted,
            size: 32,
          ),
          const SizedBox(width: CbSpace.s3),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.subtitle),
                  Text(body, style: text.bodySm.copyWith(color: cb.inkMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What can be started from Home in one tap, two cards a row. Those that
/// need a pet go straight to the only one, or ask which ([forPet]). The
/// scan and the note need AI on the server, as on the Health tab.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.pets});

  final List<Pet> pets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ai = ref.watch(aiStatusProvider).value?.configured ?? false;
    return AiStatusRefresher(
      child: CbActionGrid(
        cards: [
          CbActionCard.compact(
            key: const ValueKey('quickCare'),
            icon: Symbols.vaccines_rounded,
            title: l10n.homeQuickCare,
            hint: l10n.homeQuickCareHint,
            onTap: () => forPet(
              context,
              pets,
              (pet) => context.push(AppRoutes.newCareRecord(pet.id)),
            ),
          ),
          CbActionCard.compact(
            key: const ValueKey('quickVisit'),
            icon: Symbols.stethoscope_rounded,
            title: l10n.visitAddCard,
            hint: l10n.visitAddCardHint,
            onTap: () => context.push(AppRoutes.newVisit),
          ),
          if (ai) ...[
            CbActionCard.compact(
              key: const ValueKey('quickScan'),
              icon: Symbols.document_scanner_rounded,
              title: l10n.homeQuickScan,
              hint: l10n.homeQuickScanHint,
              onTap: () =>
                  forPet(context, pets, (pet) => openScan(context, pet.id)),
            ),
            CbActionCard.compact(
              key: const ValueKey('quickNote'),
              icon: Symbols.edit_note_rounded,
              title: l10n.homeQuickNote,
              hint: l10n.homeQuickNoteHint,
              onTap: () =>
                  forPet(context, pets, (pet) => openNote(context, pet.id)),
            ),
          ],
          CbActionCard.compact(
            key: const ValueKey('quickWeigh'),
            icon: Symbols.monitor_weight_rounded,
            title: l10n.homeQuickWeigh,
            hint: l10n.homeQuickWeighHint,
            onTap: () => forPet(
              context,
              pets,
              (pet) => showWeighingSheet(context, pet: pet),
            ),
          ),
          CbActionCard.compact(
            key: const ValueKey('quickPurchase'),
            icon: Symbols.barcode_scanner_rounded,
            title: l10n.homeQuickPurchase,
            hint: l10n.homeQuickPurchaseHint,
            onTap: () => context.push(AppRoutes.supplyScan()),
          ),
        ],
      ),
    );
  }
}
