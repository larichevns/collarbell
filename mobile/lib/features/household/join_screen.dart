import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import 'current_household.dart';
import 'household.dart';
import 'household_labels.dart';
import 'household_repository.dart';
import 'household_sheets.dart';

/// More → Switch group → Join with a code: the code someone gave the user,
/// what it invites to, and "Join". The app then moves to that group.
///
/// The server allows a few codes per person in 10 minutes, against
/// guessing, so a code is checked once, when all 8 characters are in.
class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({super.key});

  @override
  ConsumerState<JoinHouseholdScreen> createState() =>
      _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends ConsumerState<JoinHouseholdScreen> {
  final _code = TextEditingController();

  /// The code [_preview] or [_error] is about, without the hyphen.
  String? _checked;
  InvitePreview? _preview;
  String? _error;

  /// The check got no answer: it can be tried again as it is.
  var _unreachable = false;
  var _checking = false;
  var _joining = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _digits => InviteCodeFormatter.digitsOf(_code.text);

  void _changed(String _) {
    final code = _digits;
    if (code == _checked) return;
    // A code with a character codes never have can't work: said at once,
    // without spending one of the few tries the server allows.
    final impossible = InviteCodeFormatter.impossible(code);
    setState(() {
      _checked = null;
      _preview = null;
      // A check still on its way is about the code before: its answer is
      // dropped (see [_check]).
      _checking = false;
      _error = impossible ? context.l10n.joinCodeBadCharacters : null;
      _unreachable = false;
    });
    if (!impossible && code.length == InviteCodeFormatter.length) {
      _check(code);
    }
  }

  Future<void> _check(String code) async {
    final l10n = context.l10n;
    final repository = ref.read(householdRepositoryProvider);
    setState(() {
      _checked = code;
      _checking = true;
      _error = null;
      _unreachable = false;
    });
    try {
      final preview = await repository.previewInvite(code);
      // Typed on meanwhile: this answer is about another code.
      if (!mounted || _checked != code) return;
      setState(() => _preview = preview);
    } catch (error) {
      if (!mounted || _checked != code) return;
      setState(() {
        _error = _message(error, l10n);
        _unreachable = isUnreachable(error);
      });
    } finally {
      if (mounted && _checked == code) setState(() => _checking = false);
    }
  }

  Future<void> _join() async {
    final code = _checked;
    if (code == null) return;
    final l10n = context.l10n;
    final repository = ref.read(householdRepositoryProvider);
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final joined = await repository.acceptInvite(code);
      if (!mounted) return;
      ref.read(appEventsProvider).action(AppAction.joinedGroup);
      ref
          .read(currentHouseholdProvider.notifier)
          .switchTo(CurrentHousehold.ofSummary(joined));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.joinJoined(
              householdName(l10n, joined.name, role: joined.role),
            ),
          ),
        ),
      );
      context.pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = _message(error, l10n);
        });
      }
    }
  }

  /// A code that is wrong, used, taken back or expired is a 404.
  static String _message(Object error, AppLocalizations l10n) =>
      error is ApiException && error.kind == ApiErrorKind.notFound
      ? l10n.joinNotFound
      : householdErrorMessage(error, l10n);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = _preview;
    final error = _error;
    final canJoin = preview != null && !preview.alreadyMember;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinTitle)),
      body: ListView(
        padding: const EdgeInsets.all(CbSpace.s4),
        children: [
          CbTextField(
            key: const ValueKey('inviteCode'),
            label: l10n.joinCodeLabel,
            helperText: l10n.joinCodeHelper,
            controller: _code,
            monospace: true,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            inputFormatters: [InviteCodeFormatter()],
            onChanged: _changed,
            enabled: !_joining,
          ),
          const SizedBox(height: CbSpace.s4),
          if (_checking)
            const Center(
              child: SizedBox.square(
                dimension: CbSpace.s6,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (error != null && _unreachable)
            CbErrorState(message: error, onRetry: () => _check(_checked!))
          else if (error != null)
            CbNotice.error(message: error),
          if (preview != null) ...[
            _Preview(preview: preview),
            if (preview.alreadyMember) ...[
              const SizedBox(height: CbSpace.s3),
              CbNotice(message: l10n.joinAlreadyMember),
            ],
          ],
        ],
      ),
      bottomNavigationBar: CbSaveBar(
        busy: _joining,
        label: l10n.joinAction,
        onSave: canJoin ? _join : null,
      ),
    );
  }
}

/// "Anna invites you to “Home” as a helper", until when the code works,
/// and what the role may do.
class _Preview extends StatelessWidget {
  const _Preview({required this.preview});

  final InvitePreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final name = householdName(l10n, preview.householdName);
    final role = preview.role.name;
    final inviter = preview.invitedBy;
    return CbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inviter == null
                ? l10n.joinPreviewNoName(name, role)
                : l10n.joinPreview(inviter, name, role),
            key: const ValueKey('invitePreview'),
            style: text.subtitle,
          ),
          const SizedBox(height: CbSpace.s2),
          Wrap(
            spacing: CbSpace.s2,
            runSpacing: CbSpace.s1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RoleChip(role: preview.role),
              Text(
                householdRoleHelper(l10n, preview.role),
                style: text.bodySm.copyWith(color: cb.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: CbSpace.s2),
          Text(
            l10n.joinValidUntil(preview.expiresAt),
            style: text.bodySm.copyWith(color: cb.inkMuted),
          ),
        ],
      ),
    );
  }
}
