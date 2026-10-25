import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api/api_providers.dart';
import '../features/household/current_household.dart';
import '../features/household/household_labels.dart';
import '../features/me/profile_sync.dart';
import '../l10n/l10n.dart';
import '../shared/widgets/leave_guard.dart';
import '../theme/collarbell_theme.dart';
import 'offline_banner.dart';

/// The five tabs with the bottom navigation bar: Home (the app opens on
/// it), Today, Pets, Supplies and More. Each tab keeps its own navigation
/// stack (StatefulShellRoute.indexedStack). Above the bar, a strip says when
/// the server can't be reached.
///
/// It also follows the household on screen. After a move to another
/// household the tabs start afresh there: dialogs close, and for one frame
/// the tabs leave the tree, so every screen is built again and its data is
/// loaded again with nothing of the old household on it (Riverpod keeps a
/// provider's last value while it reloads; a provider made anew has none).
/// The other tabs open at their first screens. When the user was removed
/// from the household, the tab on screen goes back to its first screen too,
/// and a message says why.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late final AppLifecycleListener _lifecycle;

  /// The frame the tabs are out of the tree, after a move.
  var _remounting = false;

  @override
  void initState() {
    super.initState();
    // Back in the app: an owner may have changed the user's role meanwhile.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(roleCheckProvider.notifier).again(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Dialogs over the pages ("Leave the group?") were about the household
  /// shown before. Sheets go with their tab.
  void _closeDialogs() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.settings is Page);
  });

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shell = widget.navigationShell;
    // Loaded while the user is signed in: the households to switch between,
    // and the role, checked again when asked (roleCheckProvider).
    ref.listen(meProvider, (_, _) {});
    ref.listen(currentHouseholdProvider.select((household) => household?.id), (
      previous,
      next,
    ) {
      // From "not known yet" to the household the server chose: no move.
      if (previous == null || previous == next) return;
      _closeDialogs();
      setState(() => _remounting = true);
    });
    ref.listen(householdNoticeProvider, (_, notice) {
      switch (notice) {
        case HouseholdLeft(:final id, :final name, :final role):
          // The screen open in this tab was about the household left.
          shell.goBranch(shell.currentIndex, initialLocation: true);
          unawaited(forgetOfflineCopies(ref, id));
          _say(
            name == null
                ? l10n.householdLeftNoticeUnnamed
                : l10n.householdLeftNotice(
                    householdName(l10n, name, role: role),
                  ),
          );
        case HouseholdOpened(:final name, :final role):
          _say(
            name == null
                ? l10n.householdSwitchedUnnamed
                : l10n.householdSwitched(householdName(l10n, name, role: role)),
          );
        case null:
          break;
      }
    });
    if (_remounting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _remounting = false);
      });
    }
    return Scaffold(
      body: _remounting ? const SizedBox.shrink() : shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OfflineBanner(),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.cb.line)),
            ),
            // Five labels side by side: on a narrow phone with large text
            // they stay a little smaller than the rest, so "Питомцы" isn't
            // broken in two (the bar's own limit is 1.3).
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: MediaQuery.sizeOf(context).width < 360
                  ? 1.15
                  : 1.3,
              child: NavigationBar(
                selectedIndex: shell.currentIndex,
                // Tapping the current tab again returns to its first screen.
                // That drops the screens on top without a Back, so a form there
                // with typed input asks first.
                onDestinationSelected: (index) async {
                  final toFirst = index == shell.currentIndex;
                  // A screen busy saving (or deleting the account) stays.
                  if (toFirst && LeaveGuard.busyInView()) return;
                  if (toFirst &&
                      LeaveGuard.changedInView() &&
                      !await LeaveGuard.confirmInView(context)) {
                    return;
                  }
                  shell.goBranch(index, initialLocation: toFirst);
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Symbols.home_rounded),
                    selectedIcon: const Icon(Symbols.home_rounded, fill: 1),
                    label: l10n.navHome,
                  ),
                  NavigationDestination(
                    icon: const Icon(Symbols.today_rounded),
                    selectedIcon: const Icon(Symbols.today_rounded, fill: 1),
                    label: l10n.navToday,
                  ),
                  NavigationDestination(
                    icon: const Icon(Symbols.pets_rounded),
                    selectedIcon: const Icon(Symbols.pets_rounded, fill: 1),
                    label: l10n.navPets,
                  ),
                  NavigationDestination(
                    icon: const Icon(Symbols.inventory_2_rounded),
                    selectedIcon: const Icon(
                      Symbols.inventory_2_rounded,
                      fill: 1,
                    ),
                    label: l10n.navSupplies,
                  ),
                  NavigationDestination(
                    icon: const Icon(Symbols.more_horiz_rounded),
                    selectedIcon: const Icon(Symbols.more_horiz_rounded),
                    label: l10n.navMore,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
