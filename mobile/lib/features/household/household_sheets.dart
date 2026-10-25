import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/share_text.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../me/profile_sync.dart';
import 'current_household.dart';
import 'household.dart';
import 'household_labels.dart';
import 'household_repository.dart';

/// The role of a person or an invite, as a small grey label.
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role});

  final HouseholdRole role;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final owner = role == HouseholdRole.owner;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: owner ? cb.primarySoft : cb.sunken,
        borderRadius: BorderRadius.circular(CbRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CbSpace.s2,
          vertical: 2,
        ),
        child: Text(
          householdRoleLabel(context.l10n, role),
          style: context.cbText.caption.copyWith(
            color: owner ? cb.primaryText : cb.ink,
          ),
        ),
      ),
    );
  }
}

/// "Owner · 2 people": the user's role in a household and its size.
String householdSummaryLine(
  AppLocalizations l10n,
  HouseholdSummary household,
) =>
    '${householdRoleLabel(l10n, household.role)} · '
    '${l10n.householdMemberCount(household.memberCount)}';

/// The households of the user to switch between, with "Create a group" and
/// "Join with a code". Another household reloads every screen. What is
/// chosen happens on the page under the sheet ([context] and [ref]), which
/// stays when the sheet closes.
Future<void> showHouseholdSwitchSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _SwitchSheet(page: context, pageRef: ref),
    );

class _SwitchSheet extends ConsumerWidget {
  const _SwitchSheet({required this.page, required this.pageRef});

  final BuildContext page;
  final WidgetRef pageRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final me = ref.watch(meProvider);
    final households = me.value?.households;
    final current =
        ref.watch(currentHouseholdProvider)?.id ?? me.value?.household.id;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              0,
              CbSpace.s4,
              CbSpace.s2,
            ),
            child: Semantics(
              header: true,
              child: Text(l10n.householdSwitchTitle, style: text.title),
            ),
          ),
          if (households == null)
            me.hasError && !me.isLoading
                ? CbErrorState(
                    message: errorMessageFor(me.error!, l10n),
                    traceId: traceIdOf(me.error!),
                    onRetry: () => ref.invalidate(meProvider),
                  )
                : const CbLoadingState()
          else
            for (final household in households)
              ListTile(
                key: ValueKey('household-${household.id}'),
                leading: const Icon(Symbols.home_rounded),
                title: Text(
                  householdName(l10n, household.name, role: household.role),
                ),
                subtitle: Text(
                  householdSummaryLine(l10n, household),
                  style: text.bodySm.copyWith(color: cb.inkMuted),
                ),
                trailing: household.id == current
                    ? Icon(
                        Symbols.check_rounded,
                        color: cb.primaryText,
                        semanticLabel: l10n.householdCurrent,
                      )
                    : null,
                selected: household.id == current,
                onTap: () {
                  Navigator.of(context).pop();
                  if (household.id == current) return;
                  switchHousehold(
                    page,
                    pageRef,
                    CurrentHousehold.ofSummary(household),
                  );
                },
              ),
          const Divider(),
          ListTile(
            key: const ValueKey('createHousehold'),
            leading: const Icon(Symbols.add_home_rounded),
            title: Text(l10n.householdCreate),
            onTap: () {
              Navigator.of(context).pop();
              createHousehold(page, pageRef);
            },
          ),
          ListTile(
            key: const ValueKey('joinHousehold'),
            leading: const Icon(Symbols.vpn_key_rounded),
            title: Text(l10n.householdJoin),
            onTap: () {
              Navigator.of(context).pop();
              page.push(AppRoutes.joinHousehold);
            },
          ),
          const SizedBox(height: CbSpace.s2),
        ],
      ),
    );
  }
}

/// Moves the app to [household] and says so: every screen reloads with its
/// data (the profile sync watches the household on screen).
void switchHousehold(
  BuildContext context,
  WidgetRef ref,
  CurrentHousehold household,
) {
  ref.read(currentHouseholdProvider.notifier).switchTo(household);
  ref.read(appEventsProvider).action(AppAction.groupSwitched);
  if (!context.mounted) return;
  final l10n = context.l10n;
  final name = household.name;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        name == null
            ? l10n.householdSwitchedUnnamed
            : l10n.householdSwitched(
                householdName(l10n, name, role: household.role),
              ),
      ),
    ),
  );
}

/// Asks for a name, creates the group with the user as its owner, and moves
/// the app there.
Future<void> createHousehold(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final repository = ref.read(householdRepositoryProvider);
  final created = await showGroupNameDialog<HouseholdSummary>(
    context,
    title: l10n.householdCreateTitle,
    action: l10n.householdCreateAction,
    save: repository.createHousehold,
  );
  if (created == null || !context.mounted) return;
  switchHousehold(context, ref, CurrentHousehold.ofSummary(created));
}

/// A dialog with the group's name: [save] runs while it shows, so a refusal
/// is shown in it and the typed name stays. Returns what [save] returned,
/// or null when the user cancelled.
Future<T?> showGroupNameDialog<T>(
  BuildContext context, {
  required String title,
  required String action,
  required Future<T> Function(String name) save,
  String initial = '',
}) => showDialog<T>(
  context: context,
  builder: (_) => _GroupNameDialog<T>(
    title: title,
    action: action,
    save: save,
    initial: initial,
  ),
);

class _GroupNameDialog<T> extends StatefulWidget {
  const _GroupNameDialog({
    required this.title,
    required this.action,
    required this.save,
    required this.initial,
  });

  final String title;
  final String action;
  final Future<T> Function(String name) save;
  final String initial;

  @override
  State<_GroupNameDialog<T>> createState() => _GroupNameDialogState<T>();
}

class _GroupNameDialogState<T> extends State<_GroupNameDialog<T>> {
  /// The server's limit (`HouseholdsEndpoints.MaxNameLength`).
  static const _maxLength = 100;

  late final _name = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.save(_name.text.trim());
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = householdErrorMessage(error, l10n);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = _error;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CbTextField(
              label: l10n.householdNameLabel,
              hintText: l10n.householdNameHint,
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _busy ? null : _save(),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return l10n.householdNameRequired;
                if (name.length > _maxLength) {
                  return l10n.formTooLong(_maxLength);
                }
                return null;
              },
            ),
            if (error != null) ...[
              const SizedBox(height: CbSpace.s3),
              Text(
                error,
                style: context.cbText.bodySm.copyWith(color: context.cb.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _busy ? null : _save, child: Text(widget.action)),
      ],
    );
  }
}

/// Inviting someone to the household [householdId] (the group screen's
/// "Invite", the onboarding's family step): who (a member or a helper),
/// then the new invite's code to pass on. [run] makes the invite: the
/// screen turns its buttons off meanwhile and says a refusal its way; it
/// answers whether the invite was made. True when an invite was made.
Future<bool> inviteToHousehold(
  BuildContext context,
  WidgetRef ref, {
  required String householdId,
  required String householdName,
  required Future<bool> Function(Future<void> Function() action) run,
}) async {
  final repository = ref.read(householdRepositoryProvider);
  final role = await showInviteRoleSheet(context);
  if (role == null || !context.mounted) return false;
  HouseholdInvite? invite;
  final done = await run(() async {
    invite = await repository.createInvite(householdId, role);
    ref.invalidate(householdDetailsProvider);
  });
  if (!done || !context.mounted) return false;
  ref.read(appEventsProvider).action(AppAction.inviteCreated);
  await showInviteCodeSheet(
    context,
    invite: invite!,
    householdName: householdName,
  );
  return true;
}

/// Who to invite: a member or a helper, each with what they may do.
/// Returns the role, or null when the user closed the sheet.
Future<HouseholdRole?> showInviteRoleSheet(BuildContext context) =>
    showModalBottomSheet<HouseholdRole>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final l10n = sheet.l10n;
        final text = sheet.cbText;
        Widget option(HouseholdRole role, IconData icon) => ListTile(
          key: ValueKey('invite-${role.name}'),
          leading: Icon(icon),
          title: Text(householdRoleLabel(l10n, role)),
          subtitle: Text(
            householdRoleHelper(l10n, role),
            style: text.bodySm.copyWith(color: sheet.cb.inkMuted),
          ),
          onTap: () => Navigator.of(sheet).pop(role),
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CbSpace.s4,
                  0,
                  CbSpace.s4,
                  CbSpace.s2,
                ),
                child: Semantics(
                  header: true,
                  child: Text(l10n.householdInviteTitle, style: text.title),
                ),
              ),
              option(HouseholdRole.member, Symbols.person_rounded),
              option(HouseholdRole.helper, Symbols.volunteer_activism_rounded),
              const SizedBox(height: CbSpace.s2),
            ],
          ),
        );
      },
    );

/// An invite code to pass on: large, to read out, with "Share" and "Copy".
Future<void> showInviteCodeSheet(
  BuildContext context, {
  required HouseholdInvite invite,
  required String householdName,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) =>
      _InviteCodeSheet(invite: invite, householdName: householdName),
);

class _InviteCodeSheet extends ConsumerStatefulWidget {
  const _InviteCodeSheet({required this.invite, required this.householdName});

  final HouseholdInvite invite;
  final String householdName;

  @override
  ConsumerState<_InviteCodeSheet> createState() => _InviteCodeSheetState();
}

class _InviteCodeSheetState extends ConsumerState<_InviteCodeSheet> {
  var _copied = false;

  int get _days => inviteDaysLeft(widget.invite, DateTime.now());

  Future<void> _share() async {
    final l10n = context.l10n;
    final share = ref.read(shareTextProvider);
    try {
      await share(
        // As the person invited will see it: not "My home" but "Home".
        l10n.householdShareText(
          householdName(l10n, widget.householdName),
          widget.invite.code,
          _days,
        ),
      );
    } catch (error) {
      debugPrint('Sharing the invite failed: $error');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.invite.code));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          0,
          CbSpace.s4,
          CbSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.householdInviteCodeTitle, style: text.title),
            ),
            const SizedBox(height: CbSpace.s4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cb.sunken,
                borderRadius: BorderRadius.circular(CbRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CbSpace.s5),
                child: SelectableText(
                  widget.invite.code,
                  key: const ValueKey('inviteCode'),
                  textAlign: TextAlign.center,
                  style: text.code.copyWith(
                    fontSize: 34,
                    height: 1.2,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: CbSpace.s3),
            Wrap(
              spacing: CbSpace.s2,
              runSpacing: CbSpace.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RoleChip(role: widget.invite.role),
                Text(
                  l10n.householdInviteCodeBody(_days),
                  style: text.bodySm.copyWith(color: cb.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: CbSpace.s4),
            FilledButton.icon(
              onPressed: _share,
              icon: const Icon(Symbols.share_rounded),
              label: Text(l10n.householdShare),
            ),
            const SizedBox(height: CbSpace.s2),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: Icon(
                _copied ? Symbols.check_rounded : Symbols.content_copy_rounded,
              ),
              label: Text(l10n.householdCopy),
            ),
            if (_copied) ...[
              const SizedBox(height: CbSpace.s2),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.householdCopied,
                  textAlign: TextAlign.center,
                  style: text.bodySm.copyWith(color: cb.inkMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
