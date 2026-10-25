import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/api/api_providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../billing/billing_labels.dart';
import '../billing/billing_repository.dart';
import '../me/profile_sync.dart';
import 'current_household.dart';
import 'household.dart';
import 'household_labels.dart';
import 'household_repository.dart';
import 'household_sheets.dart';

/// More → Members and invites: the people of the household on screen and
/// their roles. Owners invite people (a code to pass on), change roles,
/// remove people and rename the group; everyone can leave it. An owner
/// alone in an empty group can delete it.
///
/// Every change names the household it was made on ([HouseholdDetails.id]),
/// not the one on screen when it is sent: a dialog left open while the app
/// moved to another household (a tapped push) can't act on that one.
class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  var _busy = false;

  /// Runs [action] with the buttons off; a refusal is said in a snackbar.
  /// True when it went through.
  Future<bool> _run(Future<void> Function() action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (error) {
      debugPrint('A household change failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(householdErrorMessage(error, l10n))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The people or the user's own role changed: the list, and More with it.
  void _reload() {
    ref.invalidate(householdDetailsProvider);
    ref.invalidate(meProvider);
  }

  Future<void> _rename(HouseholdDetails details) async {
    final l10n = context.l10n;
    final repository = ref.read(householdRepositoryProvider);
    final renamed = await showGroupNameDialog<HouseholdDetails>(
      context,
      title: l10n.householdRenameTitle,
      action: l10n.commonSave,
      // The server's "Home" is no name the user gave: they type one.
      initial: details.name == defaultHouseholdName ? '' : details.name,
      save: (name) => repository.rename(details.id, name),
    );
    if (renamed != null && mounted) _reload();
  }

  Future<void> _invite(HouseholdDetails details) => inviteToHousehold(
    context,
    ref,
    householdId: details.id,
    householdName: details.name,
    run: _run,
  );

  Future<void> _revoke(HouseholdDetails details, HouseholdInvite invite) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(householdRepositoryProvider);
    final done = await _run(
      () => repository.revokeInvite(details.id, invite.id),
    );
    if (!done) return;
    ref.invalidate(householdDetailsProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.householdInviteRevoked)),
    );
  }

  /// An owner's choices for a person: another role, or removing them.
  Future<void> _memberActions(
    HouseholdDetails details,
    HouseholdMember member,
  ) async {
    final l10n = context.l10n;
    final repository = ref.read(householdRepositoryProvider);
    final action = await showModalBottomSheet<_MemberAction>(
      context: context,
      showDragHandle: true,
      // Three roles with what each may do: taller than a usual sheet.
      isScrollControlled: true,
      builder: (sheet) => _MemberSheet(member: member),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _ChangeRole(:final role) when role != member.role:
        // An owner stepping down: no more inviting or changing roles, and
        // their open invites stop working. One tap shouldn't do that.
        if (member.isMe) {
          final sure = await confirmDestructive(
            context,
            title: l10n.householdStepDownTitle,
            message: l10n.householdStepDownBody,
            confirmLabel: l10n.householdStepDownConfirm,
          );
          if (!sure || !mounted) return;
        }
        if (await _run(
          () => repository.changeRole(details.id, member.userId, role),
        )) {
          _reload();
        }
      case _ChangeRole():
        return;
      case _Remove():
        final sure = await confirmDestructive(
          context,
          title: l10n.householdMemberRemoveTitle,
          message: l10n.householdMemberRemoveBody(memberName(l10n, member)),
          confirmLabel: l10n.householdMemberRemoveConfirm,
        );
        if (!sure || !mounted) return;
        if (await _run(
          () => repository.removeMember(details.id, member.userId),
        )) {
          _reload();
        }
    }
  }

  Future<void> _leave(HouseholdDetails details) async {
    final me = details.members.where((member) => member.isMe).firstOrNull;
    if (me == null) return;
    final l10n = context.l10n;
    final name = householdName(l10n, details.name, role: details.role);
    final sure = await confirmDestructive(
      context,
      title: l10n.householdLeaveTitle(name),
      message: l10n.householdLeaveBody,
      confirmLabel: l10n.householdLeaveConfirm,
    );
    if (!sure || !mounted) return;
    final repository = ref.read(householdRepositoryProvider);
    if (await _run(() => repository.removeMember(details.id, me.userId))) {
      _gone(details, l10n.householdLeftSelf(name));
    }
  }

  Future<void> _delete(HouseholdDetails details) async {
    final l10n = context.l10n;
    final name = householdName(l10n, details.name, role: details.role);
    final sure = await confirmDestructive(
      context,
      title: l10n.householdDeleteTitle(name),
      message: l10n.householdDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!sure || !mounted) return;
    final repository = ref.read(householdRepositoryProvider);
    if (await _run(() => repository.delete(details.id))) {
      _gone(details, l10n.householdDeleted(name));
    }
  }

  /// The user left [details]' household or deleted it: the app moves to
  /// their first household (every screen starts afresh), forgets its copies
  /// kept for offline use, and goes back to More.
  void _gone(HouseholdDetails details, String message) {
    if (!mounted) return;
    ref.read(currentHouseholdProvider.notifier).forget(details.id);
    unawaited(forgetOfflineCopies(ref, details.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final details = ref.watch(householdDetailsProvider);
    final current = ref.watch(currentHouseholdProvider);
    // The people of a household the app has left meanwhile (still there
    // while this one's load): not shown, as if loading.
    final value = switch (details.value) {
      final value? when current == null || value.id == current.id => value,
      _ => null,
    };
    final name = value?.name ?? current?.name;
    // The role from the newest answer: an owner may have just changed it.
    final permissions = value == null
        ? ref.watch(householdPermissionsProvider)
        : HouseholdPermissions(value.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          name == null
              ? l10n.moreHousehold
              : householdName(l10n, name, role: permissions.role),
        ),
        actions: [
          if (value != null && permissions.canManagePeople)
            IconButton(
              key: const ValueKey('rename'),
              tooltip: l10n.householdRename,
              onPressed: _busy ? null : () => _rename(value),
              icon: const Icon(Symbols.edit_rounded),
            ),
        ],
      ),
      body: switch (value) {
        null when details.hasError && !details.isLoading => CbErrorState(
          message: errorMessageFor(details.error!, l10n),
          traceId: traceIdOf(details.error!),
          onRetry: () => ref.invalidate(householdDetailsProvider),
        ),
        null => const CbLoadingState(),
        final value => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(householdDetailsProvider);
            try {
              await ref.read(householdDetailsProvider.future);
            } catch (error) {
              if (context.mounted) showRefreshFailed(context, error);
            }
          },
          child: _list(context, value, permissions),
        ),
      },
    );
  }

  Widget _list(
    BuildContext context,
    HouseholdDetails details,
    HouseholdPermissions permissions,
  ) {
    final l10n = context.l10n;
    final danger = context.cb.danger;
    final alone = details.members.length == 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s12,
      ),
      children: [
        CbSection(
          title: l10n.householdMembers,
          action: permissions.canManagePeople
              ? OutlinedButton.icon(
                  key: const ValueKey('invite'),
                  onPressed: _busy ? null : () => _invite(details),
                  icon: const Icon(Symbols.person_add_rounded),
                  label: Text(l10n.householdInvite),
                )
              : null,
          child: CbCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final member in details.members)
                  _MemberRow(
                    member: member,
                    onTap: permissions.canManagePeople && !_busy
                        ? () => _memberActions(details, member)
                        : null,
                  ),
              ],
            ),
          ),
        ),
        if (permissions.canManagePeople && details.invites.isNotEmpty) ...[
          const SizedBox(height: CbSpace.s6),
          CbSection(
            title: l10n.householdInvites,
            child: CbCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final invite in details.invites)
                    _InviteRow(
                      invite: invite,
                      onTap: () => showInviteCodeSheet(
                        context,
                        invite: invite,
                        householdName: details.name,
                      ),
                      onRevoke: _busy ? null : () => _revoke(details, invite),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: CbSpace.s6),
        CbSection(
          title: l10n.householdPlanTitle,
          child: const CbCard(padding: EdgeInsets.zero, child: _PlanRow()),
        ),
        const SizedBox(height: CbSpace.s8),
        // Alone in the group there is nobody to leave it to.
        if (!alone)
          OutlinedButton.icon(
            key: const ValueKey('leave'),
            style: OutlinedButton.styleFrom(foregroundColor: danger),
            onPressed: _busy ? null : () => _leave(details),
            icon: const Icon(Symbols.logout_rounded),
            label: Text(l10n.householdLeave),
          ),
        if (alone && permissions.canManagePeople)
          OutlinedButton.icon(
            key: const ValueKey('delete'),
            style: OutlinedButton.styleFrom(foregroundColor: danger),
            onPressed: _busy ? null : () => _delete(details),
            icon: const Icon(Symbols.delete_rounded),
            label: Text(l10n.householdDelete),
          ),
      ],
    );
  }
}

/// The group's plan and this month's AI photos; opens the plan screen.
class _PlanRow extends ConsumerWidget {
  const _PlanRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plan = ref.watch(householdPlanProvider).value;
    return ListTile(
      key: const ValueKey('plan'),
      leading: const Icon(Symbols.workspace_premium_rounded),
      title: Text(plan == null ? '…' : planKindName(l10n, plan.kind)),
      subtitle: plan == null
          ? null
          : Text(
              l10n.householdPlanAiPhotosLine(
                plan.aiPhotosUsed,
                plan.aiPhotosPerMonth,
              ),
              style: context.cbText.bodySm.copyWith(color: context.cb.inkMuted),
            ),
      trailing: const Icon(Symbols.chevron_right_rounded),
      onTap: () => context.push(AppRoutes.householdPlan),
    );
  }
}

/// A person: the name (else the e-mail), "you", and the role.
class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, this.onTap});

  final HouseholdMember member;

  /// Owners: the person's role and removing them.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = member.email;
    final details = [
      if (member.displayName != null && email != null) email,
      if (member.isMe) l10n.householdYou,
    ];
    return ListTile(
      key: ValueKey('member-${member.userId}'),
      leading: const Icon(Symbols.person_rounded),
      title: Text(memberName(l10n, member)),
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join(' · '),
              style: context.cbText.bodySm.copyWith(color: context.cb.inkMuted),
            ),
      trailing: RoleChip(role: member.role),
      onTap: onTap,
    );
  }
}

/// An invite nobody has used yet: its code, role and last day, with
/// "Revoke". A tap shows the code again, to share it.
class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.onTap,
    required this.onRevoke,
  });

  final HouseholdInvite invite;
  final VoidCallback onTap;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    return ListTile(
      key: ValueKey('invite-${invite.id}'),
      title: Text(invite.code, style: text.code),
      subtitle: Text(
        '${householdRoleLabel(l10n, invite.role)} · '
        '${l10n.householdInviteUntil(invite.expiresAt)}',
        style: text.bodySm.copyWith(color: context.cb.inkMuted),
      ),
      trailing: OutlinedButton(
        style: cbCompactOutlinedButtonStyle,
        onPressed: onRevoke,
        child: Text(l10n.householdInviteRevoke),
      ),
      onTap: onTap,
    );
  }
}

/// What an owner chose for a person.
sealed class _MemberAction {
  const _MemberAction();
}

class _ChangeRole extends _MemberAction {
  const _ChangeRole(this.role);

  final HouseholdRole role;
}

class _Remove extends _MemberAction {
  const _Remove();
}

/// A person's role (each with what it may do) and, for others, removing
/// them from the group.
class _MemberSheet extends StatelessWidget {
  const _MemberSheet({required this.member});

  final HouseholdMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    return SafeArea(
      child: SingleChildScrollView(
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
                child: Text(memberName(l10n, member), style: text.title),
              ),
            ),
            RadioGroup<HouseholdRole>(
              groupValue: member.role,
              onChanged: (role) {
                if (role != null) Navigator.of(context).pop(_ChangeRole(role));
              },
              // Lined up with "Remove from the group" and its icon below.
              child: ListTileTheme.merge(
                horizontalTitleGap: CbRadioTile.titleGap,
                child: Column(
                  children: [
                    for (final role in HouseholdRole.values)
                      RadioListTile<HouseholdRole>(
                        key: ValueKey('role-${role.name}'),
                        value: role,
                        contentPadding: CbRadioTile.contentPadding,
                        title: Text(householdRoleLabel(l10n, role)),
                        subtitle: Text(
                          householdRoleHelper(l10n, role),
                          style: text.bodySm.copyWith(color: cb.inkMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!member.isMe) ...[
              const Divider(),
              ListTile(
                key: const ValueKey('removeMember'),
                leading: Icon(Symbols.person_remove_rounded, color: cb.danger),
                title: Text(
                  l10n.householdMemberRemove,
                  style: TextStyle(color: cb.danger),
                ),
                onTap: () => Navigator.of(context).pop(const _Remove()),
              ),
            ],
            const SizedBox(height: CbSpace.s2),
          ],
        ),
      ),
    );
  }
}
