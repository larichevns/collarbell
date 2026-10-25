import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_config.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../auth/auth_repository.dart';
import '../household/household_labels.dart';
import 'account.dart';
import 'account_deletion.dart';
import 'account_labels.dart';
import 'account_repository.dart';
import 'data_export_sheet.dart';

/// More → Delete account (spec, "Удаление аккаунта"; the stores want it in
/// the app): what happens to each of the person's groups, what is deleted
/// and what stays, a way to download the data first, then the deletion:
/// the password again (Firebase) and a last question. After it the app
/// signs out here, and the sign-in screen says the account is gone.
///
/// The deletion itself runs in [accountDeletionProvider]: its outcome
/// survives this screen being built anew meanwhile.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _scroll = ScrollController();
  var _submitted = false;
  var _obscurePassword = true;

  /// The plan of the groups the person has seen: the first ones shown, the
  /// ones a pull to refresh brought, and the ones shown with "something
  /// changed". New groups that came on their own (a live update, perhaps
  /// off screen) aren't deleted before they were shown with that message.
  String? _seen;

  /// "Something changed" found here, before anything was sent.
  var _changed = false;

  @override
  void dispose() {
    _password.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final deletion = ref.read(accountDeletionProvider.notifier);
    // Also from the keyboard's "Done": not while a try runs or the groups
    // load anew.
    if (ref.read(accountDeletionProvider).busy ||
        ref.read(deletionPreviewProvider).isLoading) {
      return;
    }
    final l10n = context.l10n;
    final withPassword =
        ref.read(appConfigProvider).authMode == AuthMode.firebase;
    deletion.start();
    setState(() {
      _submitted = true;
      _changed = false;
    });
    if (withPassword && !(_formKey.currentState?.validate() ?? false)) return;
    // The last deletion got no answer: it may have gone through. The server
    // is asked first; if the account is gone, the app signs out.
    if (ref.read(accountDeletionProvider).outcomeUnknown &&
        !await deletion.recheck()) {
      return;
    }
    if (!mounted) return;
    final shown = ref.read(deletionPreviewProvider).value;
    if (shown == null) return;
    if (shown.plan != _seen) return _showChanged(shown);
    final sure = await confirmDestructive(
      context,
      title: l10n.deleteAccountConfirmTitle,
      message: deleteAccountConfirmMessage(l10n, shown.households),
      confirmLabel: l10n.deleteAccountTitle,
    );
    if (!sure || !mounted) return;
    // The groups changed while the question was open (the screen behind it
    // shows them anew): the answer was about the old ones.
    final now = ref.read(deletionPreviewProvider).value;
    if (now?.plan != shown.plan) return _showChanged(now);
    await deletion.delete(
      plan: shown.plan,
      password: withPassword ? _password.text : null,
    );
  }

  /// "Something changed in your groups", with the groups [now] in view:
  /// from now on they count as seen, and the next tap goes on.
  void _showChanged(DeletionPreview? now) {
    setState(() {
      _changed = true;
      if (now != null) _seen = now.plan;
    });
    _toGroups();
  }

  /// Up to the groups, under the warning at the top.
  void _toGroups() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// What became of a try, also one started before this screen was built.
  void _heard(AccountDeletionState? before, AccountDeletionState now) {
    final error = now.error;
    if (error == null || identical(error, before?.error)) return;
    final typeAgain =
        isRecentSignInRequired(error) ||
        (error is AuthException &&
            error.failure == AuthFailure.invalidCredentials);
    if (typeAgain) {
      // An empty field, and no "Enter your password" under it until the
      // next try: the form checks as you type only after a try.
      _password.clear();
      setState(() => _submitted = false);
    }
    // The groups load anew: up to them. The password stays in its field,
    // and the next try checks it again by itself.
    if (isDeletionPlanChanged(error)) _toGroups();
  }

  String? _validatePassword(String? value) =>
      (value ?? '').isEmpty ? context.l10n.passwordRequired : null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = ref.watch(deletionPreviewProvider);
    final deletion = ref.watch(accountDeletionProvider);
    ref.listen(accountDeletionProvider, _heard);
    final changed =
        _changed ||
        (deletion.error != null && isDeletionPlanChanged(deletion.error!));
    if (preview.value case final shown? when !preview.isLoading) {
      // The first groups shown, and those shown with "something changed",
      // are the ones seen.
      if (_seen == null || changed) _seen = shown.plan;
    }
    return LeaveGuard(
      // Not while the deletion runs: its end signs out, or says here what
      // went wrong.
      changed: () => false,
      busy: deletion.busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
        body: switch (preview.value) {
          null when preview.hasError && !preview.isLoading => CbErrorState(
            message: errorMessageFor(preview.error!, l10n),
            traceId: traceIdOf(preview.error!),
            onRetry: () => ref.invalidate(deletionPreviewProvider),
          ),
          null => const CbLoadingState(),
          final shown => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(deletionPreviewProvider);
              try {
                final fresh = await ref.read(deletionPreviewProvider.future);
                // Pulled to see them: these groups are seen.
                _seen = fresh.plan;
              } catch (error) {
                if (context.mounted) showRefreshFailed(context, error);
              }
            },
            child: _content(
              context,
              shown,
              deletion,
              changed: changed,
              // While the groups load anew, the button waits for them.
              reloading: preview.isLoading,
            ),
          ),
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    DeletionPreview shown,
    AccountDeletionState deletion, {
    required bool changed,
    required bool reloading,
  }) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final busy = deletion.busy;
    final error = deletion.error;
    // "Something changed" shows by the groups; the rest by the button.
    final failure = error == null || isDeletionPlanChanged(error)
        ? null
        : deleteAccountErrorMessage(error, l10n);
    final households = shown.households;
    final withPassword =
        ref.watch(appConfigProvider).authMode == AuthMode.firebase;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s12,
      ),
      children: [
        CbNotice.warning(message: l10n.deleteAccountWarning),
        if (changed) ...[
          const SizedBox(height: CbSpace.s4),
          CbNotice.warning(
            key: const ValueKey('planChanged'),
            message: l10n.deleteAccountPlanChanged,
          ),
        ],
        if (households.isNotEmpty) ...[
          const SizedBox(height: CbSpace.s6),
          CbSection(
            title: l10n.deleteAccountGroups,
            child: CbCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (index, household) in households.indexed) ...[
                    if (index > 0) const Divider(height: 1),
                    _OutcomeRow(household: household),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: CbSpace.s6),
        CbSection(
          title: l10n.deleteAccountGoes,
          child: CbCard(
            child: Column(
              children: [
                _Fact(Symbols.person_rounded, l10n.deleteAccountGoesAccount),
                _Fact(Symbols.home_rounded, l10n.deleteAccountGoesGroups),
                _Fact(Symbols.key_rounded, l10n.deleteAccountGoesSignIn),
              ],
            ),
          ),
        ),
        const SizedBox(height: CbSpace.s6),
        CbSection(
          title: l10n.deleteAccountStays,
          child: CbCard(
            child: Column(
              children: [
                _Fact(Symbols.group_rounded, l10n.deleteAccountStaysRecords),
                _Fact(Symbols.history_rounded, l10n.deleteAccountStaysBackups),
                _Fact(
                  Symbols.document_scanner_rounded,
                  l10n.deleteAccountStaysAiPhotos,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CbSpace.s6),
        CbCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            key: const ValueKey('exportFirst'),
            leading: const Icon(Symbols.download_rounded),
            title: Text(l10n.deleteAccountExportFirst, style: text.body),
            subtitle: Text(
              l10n.dataExportHelper,
              style: text.bodySm.copyWith(color: cb.inkMuted),
            ),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: busy ? null : () => showDataExport(context),
          ),
        ),
        const SizedBox(height: CbSpace.s8),
        if (withPassword) ...[
          Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: CbTextField(
              key: const ValueKey('password'),
              label: l10n.passwordLabel,
              helperText: l10n.deleteAccountPasswordHelper,
              controller: _password,
              validator: _validatePassword,
              obscureText: _obscurePassword,
              autocorrect: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              enabled: !busy,
              onFieldSubmitted: (_) => _delete(),
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? l10n.showPassword
                    : l10n.hidePassword,
                icon: Icon(
                  _obscurePassword
                      ? Symbols.visibility_rounded
                      : Symbols.visibility_off_rounded,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: CbSpace.s4),
        ],
        if (failure != null) ...[
          CbNotice.error(message: failure),
          const SizedBox(height: CbSpace.s4),
        ],
        FilledButton(
          key: const ValueKey('deleteAccountButton'),
          style: FilledButton.styleFrom(
            backgroundColor: cb.danger,
            foregroundColor: cb.onDanger,
          ),
          onPressed: busy || reloading ? null : _delete,
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.deleteAccountTitle),
        ),
      ],
    );
  }
}

/// One of the person's groups and what deleting the account does to it.
class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({required this.household});

  final HouseholdOutcome household;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final deleted = household.fate == HouseholdFate.deleted;
    return ListTile(
      key: ValueKey('outcome-${household.id}'),
      leading: Icon(
        deleted ? Symbols.delete_rounded : Symbols.home_rounded,
        color: deleted ? cb.danger : null,
      ),
      title: Text(householdName(l10n, household.name, role: household.role)),
      subtitle: Text(
        householdFateLines(l10n, household).join(' '),
        style: context.cbText.bodySm.copyWith(
          color: deleted ? cb.ink : cb.inkMuted,
        ),
      ),
    );
  }
}

/// One thing that is deleted or stays, with an icon.
class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CbSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.cb.inkMuted),
          const SizedBox(width: CbSpace.s3),
          Expanded(child: Text(text, style: context.cbText.body)),
        ],
      ),
    );
  }
}
