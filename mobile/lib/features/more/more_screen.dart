import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_config.dart';
import '../../app/app_settings.dart';
import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/collarbell_theme.dart';
import '../account/data_export_sheet.dart';
import '../ai/ai_repository.dart';
import '../ai/widgets/ai_status_refresher.dart';
import '../auth/auth_providers.dart';
import '../billing/billing_labels.dart';
import '../billing/billing_repository.dart';
import '../household/current_household.dart';
import '../household/household_labels.dart';
import '../household/household_sheets.dart';
import '../me/me_repository.dart';
import '../me/profile_sync.dart';
import '../notifications/push_registration.dart';

/// Account, the group on screen, language, theme, AI, the onboarding again,
/// the person's data (download it, delete the account) and sign-out.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final user = ref.watch(authUserProvider);
    final settings = ref.watch(appSettingsProvider);
    final config = ref.watch(appConfigProvider);
    final ai = ref.watch(aiStatusProvider);
    // The status couldn't be loaded (no connection): say so, with a retry,
    // rather than "Checking…" for ever.
    final failed = ai.hasError && !ai.isLoading && !ai.hasValue;

    // Lined up with the rows with icons in the other cards.
    Widget option<T>(T value, String label) => ListTileTheme.merge(
      horizontalTitleGap: CbRadioTile.titleGap,
      child: RadioListTile<T>(
        value: value,
        contentPadding: CbRadioTile.contentPadding,
        title: Text(label, style: text.body),
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: CbSpace.s12),
          children: [
            ScreenHeader(title: l10n.moreTitle),
            _Section(
              title: l10n.moreAccount,
              child: CbCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.moreSignedInAs,
                      style: text.caption.copyWith(color: cb.inkMuted),
                    ),
                    const SizedBox(height: CbSpace.s1),
                    Text(user?.email ?? l10n.moreNoEmail, style: text.subtitle),
                    if (config.authMode == AuthMode.dev) ...[
                      const SizedBox(height: CbSpace.s2),
                      Text(
                        l10n.moreDeveloperInfo(config.apiBaseUrl),
                        style: text.caption.copyWith(color: cb.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _Section(title: l10n.moreHousehold, child: const _HouseholdCard()),
            _Section(
              title: l10n.moreLanguage,
              child: CbCard(
                padding: EdgeInsets.zero,
                child: RadioGroup<LanguagePreference>(
                  groupValue: settings.language,
                  onChanged: (value) {
                    if (value != null) _setLanguage(ref, value);
                  },
                  child: Column(
                    children: [
                      option(
                        LanguagePreference.system,
                        l10n.moreLanguageSystem,
                      ),
                      option(LanguagePreference.en, l10n.languageNameEnglish),
                      option(LanguagePreference.ru, l10n.languageNameRussian),
                    ],
                  ),
                ),
              ),
            ),
            _Section(
              title: l10n.moreTheme,
              child: CbCard(
                padding: EdgeInsets.zero,
                child: RadioGroup<ThemeMode>(
                  groupValue: settings.themeMode,
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(appSettingsProvider.notifier).setThemeMode(value);
                  },
                  child: Column(
                    children: [
                      option(ThemeMode.light, l10n.moreThemeLight),
                      option(ThemeMode.dark, l10n.moreThemeDark),
                      option(ThemeMode.system, l10n.moreThemeSystem),
                    ],
                  ),
                ),
              ),
            ),
            _Section(
              title: l10n.notificationsTitle,
              child: CbCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Symbols.notifications_rounded),
                  title: Text(l10n.notificationsTitle, style: text.body),
                  subtitle: Text(
                    l10n.moreNotificationsHelper,
                    style: text.bodySm.copyWith(color: cb.inkMuted),
                  ),
                  trailing: const Icon(Symbols.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.notifications),
                ),
              ),
            ),
            _Section(
              title: l10n.moreAi,
              child: CbCard(
                padding: EdgeInsets.zero,
                // Asks again when the status couldn't be loaded and the
                // user comes back to More.
                child: AiStatusRefresher(
                  child: ListTile(
                    leading: const Icon(Symbols.document_scanner_rounded),
                    title: Text(l10n.aiTitle, style: text.body),
                    subtitle: Text(switch (ai.value?.configured) {
                      true => l10n.aiConnected,
                      false => l10n.aiNotConnected,
                      null when failed => l10n.aiCheckFailed,
                      null => l10n.aiChecking,
                    }, style: text.bodySm.copyWith(color: cb.inkMuted)),
                    trailing: failed
                        ? OutlinedButton(
                            style: cbCompactOutlinedButtonStyle,
                            onPressed: () => ref.invalidate(aiStatusProvider),
                            child: Text(l10n.commonTryAgain),
                          )
                        : const Icon(Symbols.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.ai),
                  ),
                ),
              ),
            ),
            _Section(
              title: l10n.moreHelp,
              child: CbCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  key: const ValueKey('welcome'),
                  leading: const Icon(Symbols.waving_hand_rounded),
                  title: Text(l10n.welcomeMoreTitle, style: text.body),
                  subtitle: Text(
                    l10n.welcomeMoreHint,
                    style: text.bodySm.copyWith(color: cb.inkMuted),
                  ),
                  trailing: const Icon(Symbols.chevron_right_rounded),
                  // Above the tabs, from its first page; Back returns here.
                  onTap: () => context.push(AppRoutes.welcome),
                ),
              ),
            ),
            _Section(
              title: l10n.moreYourData,
              child: CbCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      key: const ValueKey('downloadData'),
                      leading: const Icon(Symbols.download_rounded),
                      title: Text(l10n.dataExportTitle, style: text.body),
                      subtitle: Text(
                        l10n.dataExportHelper,
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                      ),
                      onTap: () => showDataExport(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const ValueKey('deleteAccount'),
                      leading: Icon(Symbols.delete_rounded, color: cb.danger),
                      title: Text(
                        l10n.deleteAccountTitle,
                        style: text.body.copyWith(color: cb.danger),
                      ),
                      subtitle: Text(
                        l10n.deleteAccountHelper,
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                      ),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => context.push(AppRoutes.deleteAccount),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CbSpace.s4,
                CbSpace.s8,
                CbSpace.s4,
                0,
              ),
              child: const _SignOutButton(),
            ),
          ],
        ),
      ),
    );
  }

  /// Saves the choice, then tells the API the new language. Failures of the
  /// API call are ignored, as in the profile sync after sign-in.
  Future<void> _setLanguage(WidgetRef ref, LanguagePreference value) async {
    final me = ref.read(meRepositoryProvider);
    await ref.read(appSettingsProvider.notifier).setLanguage(value);
    final locale = effectiveLanguageCode(
      value,
      PlatformDispatcher.instance.locales,
    );
    try {
      await me.updateMe(locale: locale);
    } catch (error) {
      debugPrint('Language sync failed, ignored: $error');
    }
  }
}

/// The group on screen: its name, the user's role there and how many people
/// are in it; switching to another group, its people, and its plan.
class _HouseholdCard extends ConsumerWidget {
  const _HouseholdCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final current = ref.watch(currentHouseholdProvider);
    final me = ref.watch(meProvider).value;
    final id = current?.id ?? me?.household.id;
    final listed = me?.households.where((h) => h.id == id).firstOrNull;
    final name = current?.name ?? me?.household.name;
    final role = current?.role ?? listed?.role;
    final plan = ref.watch(householdPlanProvider);
    final details = [
      if (role != null) householdRoleLabel(l10n, role),
      if (listed != null) l10n.householdMemberCount(listed.memberCount),
    ];
    return CbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            key: const ValueKey('currentHousehold'),
            leading: const Icon(Symbols.home_rounded),
            title: Text(
              name == null ? '…' : householdName(l10n, name, role: role),
              style: text.subtitle,
            ),
            subtitle: details.isEmpty
                ? null
                : Text(
                    details.join(' · '),
                    style: text.bodySm.copyWith(color: cb.inkMuted),
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('switchHousehold'),
            leading: const Icon(Symbols.swap_horiz_rounded),
            title: Text(l10n.householdSwitch, style: text.body),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () => showHouseholdSwitchSheet(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('householdPeople'),
            leading: const Icon(Symbols.group_rounded),
            title: Text(l10n.householdPeople, style: text.body),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.household),
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('householdPlan'),
            leading: const Icon(Symbols.workspace_premium_rounded),
            title: Text(l10n.householdPlanTitle, style: text.body),
            subtitle: switch (plan.value) {
              final plan? => Text(
                planKindName(l10n, plan.kind),
                style: text.bodySm.copyWith(color: cb.inkMuted),
              ),
              null when plan.isLoading => const Text('…'),
              null => null,
            },
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.householdPlan),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(CbSpace.s4, CbSpace.s6, CbSpace.s4, 0),
      child: Column(
        // Cards span the full width, whatever their content.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: context.cbText.title),
          ),
          const SizedBox(height: CbSpace.s3),
          child,
        ],
      ),
    );
  }
}

/// Signing out asks first: a stray tap is costly when the password isn't at
/// hand. Pushes to this phone stop before the sign-out (the next person to
/// sign in here must not get this household's reminders), which takes up to
/// a few seconds without a connection: the button shows it is working.
class _SignOutButton extends ConsumerStatefulWidget {
  const _SignOutButton();

  @override
  ConsumerState<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<_SignOutButton> {
  var _busy = false;

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final sure = await confirmDestructive(
      context,
      title: l10n.signOutTitle,
      message: l10n.signOutBody,
      confirmLabel: l10n.moreSignOut,
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    try {
      await signOutOfThisPhone(ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _signOut,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Symbols.logout_rounded),
      label: Text(context.l10n.moreSignOut),
    );
  }
}
