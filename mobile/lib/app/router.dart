import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api/app_events.dart';
import '../features/account/delete_account_screen.dart';
import '../features/ai/ai_screen.dart';
import '../features/ai/scan_screen.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/billing/household_plan_screen.dart';
import '../features/care/care.dart';
import '../features/care/done_screen.dart';
import '../features/care/plan_form_screen.dart';
import '../features/care/preset_picker_screen.dart';
import '../features/care/record_detail_screen.dart';
import '../features/care/record_form_screen.dart';
import '../features/documents/document_detail_screen.dart';
import '../features/documents/document_form_screen.dart';
import '../features/feeding/feeding_form_screen.dart';
import '../features/home/home_screen.dart';
import '../features/household/household_screen.dart';
import '../features/household/join_screen.dart';
import '../features/more/more_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/passport/passport_form_screen.dart';
import '../features/pets/pet_detail_screen.dart';
import '../features/pets/pet_form_screen.dart';
import '../features/pets/pets_screen.dart';
import '../features/supplies/product_scan_screen.dart';
import '../features/supplies/supplies_screen.dart';
import '../features/supplies/supply.dart';
import '../features/supplies/supply_detail_screen.dart';
import '../features/supplies/supply_form_screen.dart';
import '../features/supplies/supply_plan_offer.dart';
import '../features/today/today_screen.dart';
import '../features/visits/visit_detail_screen.dart';
import '../features/visits/visit_form_screen.dart';
import '../features/visits/visits_screen.dart';
import 'home_shell.dart';

abstract final class AppRoutes {
  static const signIn = '/sign-in';

  /// The first tab, the one the app opens on: a greeting, the pets, what is
  /// important right now and quick actions.
  static const home = '/home';
  static const today = '/today';
  static const pets = '/pets';
  static const supplies = '/supplies';
  static const more = '/more';

  // The tabs' places in the tab bar: Home, Today, Pets, Supplies, More.
  static const homeBranch = 0;
  static const todayBranch = 1;
  static const suppliesBranch = 3;

  /// The onboarding ("Getting to know the app"): three pages about the app,
  /// then the first steps. Above the tabs, opened with `push`, so Back
  /// returns to the screen under it. Home opens it by itself once, More
  /// again on request.
  static const welcome = '/welcome';

  /// The full pet form and joining with a code, opened from the onboarding:
  /// above the tabs too, so they come up over the onboarding, not inside a
  /// tab hidden under it.
  static const welcomePet = '/welcome/pet';
  static const welcomeJoin = '/welcome/join';

  // Screens inside the Pets tab: the bottom navigation stays visible.
  static const newPet = '/pets/new';

  /// The pet's page; [tab] opens one of its tabs, e.g. Health from Today.
  static String pet(String petId, {PetTab? tab}) =>
      tab == null ? '/pets/$petId' : '/pets/$petId?tab=${tab.name}';
  static String editPet(String petId) => '/pets/$petId/edit';
  static String editPassport(String petId) => '/pets/$petId/passport/edit';
  static String newDocument(String petId) => '/pets/$petId/documents/new';
  static String document(String petId, String documentId) =>
      '/pets/$petId/documents/$documentId';
  static String editDocument(String petId, String documentId) =>
      '/pets/$petId/documents/$documentId/edit';

  // Care: plans, "Done" and records of one pet.
  static String carePresets(String petId) => '/pets/$petId/plans/presets';
  static String newCarePlan(String petId, {String? presetCode}) =>
      _withQuery('/pets/$petId/plans/new', {'preset': presetCode});
  static String editCarePlan(String petId, String planId) =>
      '/pets/$petId/plans/$planId/edit';
  static String carePlanDone(String petId, String planId) =>
      '/pets/$petId/plans/$planId/done';

  /// A record form that starts with [kind] (and [target]), e.g. from a
  /// passport section.
  static String newCareRecord(
    String petId, {
    CareKind? kind,
    VaccineTarget? target,
  }) => _withQuery('/pets/$petId/records/new', {
    'kind': kind?.name,
    'target': target?.name,
  });
  static String careRecord(String petId, String recordId) =>
      '/pets/$petId/records/$recordId';
  static String editCareRecord(String petId, String recordId) =>
      '/pets/$petId/records/$recordId/edit';

  /// "Done" from the Today tab: it opens inside Today, so going back
  /// returns there.
  static String todayDone(String planId) => '/today/plans/$planId/done';

  // Visits live in the Today tab: they are shown there, and pushes about
  // them open there.
  static const visits = '/today/visits';
  static const newVisit = '/today/visits/new';
  static String visit(String visitId) => '/today/visits/$visitId';
  static String editVisit(String visitId) => '/today/visits/$visitId/edit';

  // Feeding schedules of one pet.
  static String newFeeding(String petId) => '/pets/$petId/feeding/new';
  static String editFeeding(String petId, String scheduleId) =>
      '/pets/$petId/feeding/$scheduleId/edit';

  // Supplies: the tab, an item, the form, and scanning a product.
  static const newSupply = '/supplies/new';
  static String supply(String supplyId) => '/supplies/$supplyId';
  static String editSupply(String supplyId) => '/supplies/$supplyId/edit';

  /// Scans a barcode, or with [photos] takes photos of the package for AI.
  static String supplyScan({bool photos = false}) =>
      photos ? '/supplies/scan?photos=1' : '/supplies/scan';

  /// Notification settings, the test push and the list of reminders.
  static const notifications = '/more/notifications';

  // AI: scans of a pet's passport, notes, and the AI screen in More.

  /// A new scan of the pet's passport pages (or a vet document).
  static String newScan(String petId) => '/pets/$petId/scan';

  /// A new note about the pet, written or dictated, for AI to read ("Write
  /// it in words" on the Health tab).
  static String newNote(String petId) => '/pets/$petId/note';

  /// A scan (or a [note]) started before: still being read, ready to check,
  /// or done. With [readAgain], a failed one is read again at once. [note]
  /// lets the screen speak of a note before it has loaded (and if it can't
  /// load).
  static String scan(
    String petId,
    String scanId, {
    bool readAgain = false,
    bool note = false,
  }) => _withQuery('/pets/$petId/scans/$scanId', {
    'again': readAgain ? '1' : null,
    'note': note ? '1' : null,
  });

  /// Whether AI is set up, its models, this month's use, a connection test.
  static const ai = '/more/ai';

  /// The people of the household on screen, their roles and the invites.
  static const household = '/more/household';

  /// Joining a household with an invite code.
  static const joinHousehold = '/more/join';

  /// What deleting the account does to each group, and deleting it.
  static const deleteAccount = '/more/delete-account';

  /// The group's plan (Free or Premium) and this month's AI photos. Above
  /// the tabs: More, the group screen and the AI-limit errors of every tab
  /// open it, and Back returns there.
  static const householdPlan = '/plan';

  /// [path] with the given query values; null values are left out.
  static String _withQuery(String path, Map<String, String?> values) {
    final query = {
      for (final entry in values.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    return query.isEmpty
        ? path
        : Uri(path: path, queryParameters: query).toString();
  }
}

/// Signed-out users only see sign-in; signed-in users never see it.
String? authRedirect({required bool signedIn, required String location}) {
  final onSignIn = location == AppRoutes.signIn;
  if (!signedIn) return onSignIn ? null : AppRoutes.signIn;
  if (onSignIn) return AppRoutes.home;
  return null;
}

/// The tab on screen, by its place in the tab bar ([AppRoutes.todayBranch]
/// and the others); null when no tab is (sign-in). A screen of another tab
/// pushed on top (Home opens a visit form, `/today/visits/new`) doesn't
/// change it: the tab under it is the one shown.
int? shownTab(GoRouter router) {
  for (final match in router.routerDelegate.currentConfiguration.matches) {
    final route = match.route;
    if (match is ShellRouteMatch && route is StatefulShellRoute) {
      return route.branches.indexWhere(
        (branch) => branch.navigatorKey == match.navigatorKey,
      );
    }
  }
  return null;
}

/// Shows the tab [branch] as the user left it (a form open there stays),
/// like a tap on the tab bar; [location] when there is no tab bar (a test
/// that shows one screen).
void openTab(BuildContext context, int branch, String location) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell == null) {
    context.go(location);
    return;
  }
  shell.goBranch(branch);
}

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier<bool>(ref.read(authUserProvider) != null);
  ref.listen(authUserProvider, (_, user) => signedIn.value = user != null);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: signedIn,
    redirect: (context, state) =>
        authRedirect(signedIn: signedIn.value, location: state.matchedLocation),
    // Unknown links go to the main screen instead of an error page.
    onException: (context, state, router) => router.go(AppRoutes.home),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: AppRoutes.householdPlan,
        builder: (_, _) => const HouseholdPlanScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeScreen(),
        routes: [
          GoRoute(path: 'pet', builder: (_, _) => const PetFormScreen()),
          GoRoute(path: 'join', builder: (_, _) => const JoinHouseholdScreen()),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (_, _) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: 'plans/:planId/done',
                    builder: (_, state) =>
                        DoneScreen(planId: state.pathParameters['planId']!),
                  ),
                  GoRoute(
                    path: 'visits',
                    builder: (_, _) => const VisitsScreen(),
                    routes: [
                      // Before ':visitId', so that "new" is not taken for
                      // an id.
                      GoRoute(
                        path: 'new',
                        builder: (_, state) => VisitFormScreen(
                          petId: state.uri.queryParameters['pet'],
                        ),
                      ),
                      GoRoute(
                        path: ':visitId',
                        builder: (_, state) => VisitDetailScreen(
                          // Another visit is another screen.
                          key: ValueKey(state.pathParameters['visitId']),
                          visitId: state.pathParameters['visitId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (_, state) => VisitFormScreen(
                              visitId: state.pathParameters['visitId'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pets,
                builder: (_, _) => const PetsScreen(),
                routes: [
                  // Before ':petId', so that "new" is not taken for an id.
                  GoRoute(
                    path: 'new',
                    builder: (_, _) => const PetFormScreen(),
                  ),
                  GoRoute(
                    path: ':petId',
                    builder: (_, state) => PetDetailScreen(
                      petId: state.pathParameters['petId']!,
                      initialTab: _byName(
                        PetTab.values,
                        state.uri.queryParameters['tab'],
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) =>
                            PetFormScreen(petId: state.pathParameters['petId']),
                      ),
                      GoRoute(
                        path: 'passport/edit',
                        builder: (_, state) => PassportFormScreen(
                          petId: state.pathParameters['petId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'documents/new',
                        builder: (_, state) => DocumentFormScreen(
                          petId: state.pathParameters['petId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'documents/:documentId',
                        builder: (_, state) => DocumentDetailScreen(
                          petId: state.pathParameters['petId']!,
                          documentId: state.pathParameters['documentId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (_, state) => DocumentFormScreen(
                              petId: state.pathParameters['petId']!,
                              documentId: state.pathParameters['documentId'],
                            ),
                          ),
                        ],
                      ),
                      // Siblings, not nested: an open scan must not have
                      // the new-scan page under it.
                      GoRoute(
                        path: 'scan',
                        builder: (_, state) =>
                            ScanScreen(petId: state.pathParameters['petId']!),
                      ),
                      GoRoute(
                        path: 'note',
                        builder: (_, state) => ScanScreen(
                          petId: state.pathParameters['petId']!,
                          note: true,
                        ),
                      ),
                      GoRoute(
                        path: 'scans/:scanId',
                        builder: (_, state) => ScanScreen(
                          // Another scan is another screen, not this one
                          // with a new id.
                          key: ValueKey(state.pathParameters['scanId']),
                          petId: state.pathParameters['petId']!,
                          scanId: state.pathParameters['scanId'],
                          readAgain: state.uri.queryParameters['again'] == '1',
                          note: state.uri.queryParameters['note'] == '1',
                        ),
                      ),
                      // Before 'feeding/:scheduleId', so that "new" is
                      // not taken for an id.
                      GoRoute(
                        path: 'feeding/new',
                        builder: (_, state) => FeedingFormScreen(
                          petId: state.pathParameters['petId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'feeding/:scheduleId/edit',
                        builder: (_, state) => FeedingFormScreen(
                          petId: state.pathParameters['petId']!,
                          scheduleId: state.pathParameters['scheduleId'],
                        ),
                      ),
                      GoRoute(
                        path: 'plans/presets',
                        builder: (_, state) => PresetPickerScreen(
                          petId: state.pathParameters['petId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'plans/new',
                        builder: (_, state) => PlanFormScreen(
                          petId: state.pathParameters['petId']!,
                          presetCode: state.uri.queryParameters['preset'],
                          draft: state.extra is CarePlanDraft
                              ? state.extra! as CarePlanDraft
                              : null,
                        ),
                      ),
                      GoRoute(
                        path: 'plans/:planId/edit',
                        builder: (_, state) => PlanFormScreen(
                          petId: state.pathParameters['petId']!,
                          planId: state.pathParameters['planId'],
                        ),
                      ),
                      GoRoute(
                        path: 'plans/:planId/done',
                        builder: (_, state) =>
                            DoneScreen(planId: state.pathParameters['planId']!),
                      ),
                      // Before 'records/:recordId', so that "new" is not
                      // taken for an id.
                      GoRoute(
                        path: 'records/new',
                        builder: (_, state) => RecordFormScreen(
                          petId: state.pathParameters['petId']!,
                          kind: _byName(
                            CareKind.values,
                            state.uri.queryParameters['kind'],
                          ),
                          target: _byName(
                            VaccineTarget.values,
                            state.uri.queryParameters['target'],
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'records/:recordId',
                        builder: (_, state) => RecordDetailScreen(
                          petId: state.pathParameters['petId']!,
                          recordId: state.pathParameters['recordId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (_, state) => RecordFormScreen(
                              petId: state.pathParameters['petId']!,
                              recordId: state.pathParameters['recordId'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplies,
                builder: (_, _) => const SuppliesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, state) => SupplyFormScreen(
                      prefill: state.extra is SupplyPrefill
                          ? state.extra! as SupplyPrefill
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'scan',
                    builder: (_, state) => ProductScanScreen(
                      photos: state.uri.queryParameters['photos'] == '1',
                    ),
                  ),
                  GoRoute(
                    path: ':supplyId',
                    builder: (_, state) => SupplyDetailScreen(
                      key: ValueKey(state.pathParameters['supplyId']),
                      supplyId: state.pathParameters['supplyId']!,
                      planOffer: state.extra is SupplyPlanOffer
                          ? state.extra! as SupplyPlanOffer
                          : null,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => SupplyFormScreen(
                          supplyId: state.pathParameters['supplyId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(path: 'ai', builder: (_, _) => const AiScreen()),
                  GoRoute(
                    path: 'notifications',
                    builder: (_, _) => const NotificationsScreen(),
                  ),
                  GoRoute(
                    path: 'household',
                    builder: (_, _) => const HouseholdScreen(),
                  ),
                  GoRoute(
                    path: 'join',
                    builder: (_, _) => const JoinHouseholdScreen(),
                  ),
                  GoRoute(
                    path: 'delete-account',
                    builder: (_, _) => const DeleteAccountScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  // The visor hears of each screen that comes up, tabs included, by its
  // route's pattern (data/api/app_events.dart).
  final delegate = router.routerDelegate;
  delegate.addListener(
    () => ref
        .read(appEventsProvider)
        .screen(screenPattern(delegate.currentConfiguration)),
  );
  ref.onDispose(() {
    router.dispose();
    signedIn.dispose();
  });
  return router;
});

/// The enum value called [name] (from a link), or null when there is none.
T? _byName<T extends Enum>(List<T> values, String? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// The pattern of the screen on top, as the visor gets it:
/// `/pets/:petId/edit`, never the ids or the query. A screen opened with
/// `push` is the last match and has matches of its own.
String screenPattern(RouteMatchList routes) {
  final top = routes.lastOrNull;
  return top is ImperativeRouteMatch ? top.matches.fullPath : routes.fullPath;
}
