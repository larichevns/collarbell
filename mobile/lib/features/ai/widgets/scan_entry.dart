import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/cb_card.dart';
import '../../../shared/widgets/cb_status_tag.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../theme/collarbell_theme.dart';
import '../ai.dart';
import '../ai_labels.dart';
import '../ai_repository.dart';
import 'ai_status_refresher.dart';

/// Opens the scan screen: a new scan for the pet [petId], or the scan (or
/// [note]) [scanId] started before ([readAgain]: a failed one, read again
/// at once). When the user comes back, the pet's scans and notes load
/// again: the scan may still be reading, ready to check, or saved.
Future<void> openScan(
  BuildContext context,
  String petId, {
  String? scanId,
  bool readAgain = false,
  bool note = false,
}) => _openAndReload(
  context,
  petId,
  scanId == null
      ? AppRoutes.newScan(petId)
      : AppRoutes.scan(petId, scanId, readAgain: readAgain, note: note),
);

/// Opens a new note for the pet [petId] ("Write it in words"); when the
/// user comes back, the pet's scans and notes load again.
Future<void> openNote(BuildContext context, String petId) =>
    _openAndReload(context, petId, AppRoutes.newNote(petId));

Future<void> _openAndReload(
  BuildContext context,
  String petId,
  String location,
) async {
  // Taken before the await: the tab that opened the scan may be gone by
  // the time it closes.
  final container = ProviderScope.containerOf(context, listen: false);
  await context.push(location);
  refreshPetImports(container, petId);
}

/// The pet's [scans] the user still has to deal with: ready to check, still
/// being read, or failed.
List<AiScan> _waiting(Iterable<AiScan> scans) => [
  for (final scan in scans)
    if (scan.status == ScanStatus.ready ||
        scan.status.isReading ||
        scan.status == ScanStatus.failed)
      scan,
];

/// The scan block at the top of the Passport tab: scans waiting for the
/// user (ready to check, still being read, or failed) and, when the server
/// has AI, "Scan passport pages". Nothing at all otherwise: without AI the
/// import is hidden, and typing records in always works. Notes wait on the
/// Health tab, where they are written ([NoteEntry]).
class ScanEntry extends ConsumerWidget {
  const ScanEntry({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AiStatusRefresher(child: _cards(context, ref));
  }

  Widget _cards(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(aiStatusProvider).value?.configured ?? false;
    // The cards are a shortcut: when the list can't be loaded they are left
    // out, and the scans wait on the server. The list has no notes (should
    // a server send some, they wait on the Health tab).
    final scans = ref.watch(petScansProvider(petId)).value ?? const <AiScan>[];
    final open = _waiting([
      for (final scan in scans)
        if (!scan.isNote) scan,
    ]);
    if (!configured && open.isEmpty) return const SizedBox.shrink();

    final cards = [
      for (final scan in open)
        scan.status == ScanStatus.failed
            ? _FailedCard(key: ValueKey(scan.id), scan: scan)
            : _ResumeCard(key: ValueKey(scan.id), scan: scan),
      if (configured) _ScanCard(petId: petId),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: CbSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: CbSpace.s3),
            cards[i],
          ],
        ],
      ),
    );
  }
}

/// The notes waiting for the user on the Health tab, where they were
/// written: ready to check, still being read, or failed ("Try again" reads
/// the same text as a new note in its place, "Dismiss" throws it away after
/// asking). Offered even without AI now: checking and saving need none.
/// Nothing when there are none; "Write it in words" itself sits next to the
/// scan button.
class NoteEntry extends ConsumerWidget {
  const NoteEntry({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A shortcut, like the scan cards: left out when the list can't load.
    final scans = ref.watch(petNotesProvider(petId)).value ?? const <AiScan>[];
    final notes = _waiting([
      for (final scan in scans)
        if (scan.isNote) scan,
    ]);
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: CbSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < notes.length; i++) ...[
            if (i > 0) const SizedBox(height: CbSpace.s3),
            notes[i].status == ScanStatus.failed
                ? _FailedCard(key: ValueKey(notes[i].id), scan: notes[i])
                : _ResumeCard(key: ValueKey(notes[i].id), scan: notes[i]),
          ],
        ],
      ),
    );
  }
}

/// "Scan passport pages": what the scan does, and the button that starts it.
class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    return CbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconDisc(Symbols.document_scanner_rounded),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.scanCardTitle, style: text.subtitle),
                      const SizedBox(height: CbSpace.s1),
                      Text(
                        l10n.scanCardBody,
                        style: text.bodySm.copyWith(color: context.cb.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CbSpace.s3),
          OutlinedButton.icon(
            onPressed: () => openScan(context, petId),
            icon: const Icon(Symbols.document_scanner_rounded),
            label: Text(l10n.scanCardButton),
          ),
        ],
      ),
    );
  }
}

/// A scan (or a note) to pick up again: ready to check, or still being
/// read.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({super.key, required this.scan});

  final AiScan scan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final started = scan.createdAt.toLocal();
    final when = l10n.dateWithTime(
      started,
      TimeOfDay.fromDateTime(started).format(context),
    );
    final ready = scan.status == ScanStatus.ready;
    final note = scan.isNote;
    return CbCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => openScan(context, scan.petId, scanId: scan.id, note: note),
        child: Padding(
          padding: const EdgeInsets.all(CbSpace.s4),
          child: Row(
            children: [
              ready
                  ? const _IconDisc(Symbols.fact_check_rounded)
                  : const _IconDisc(Symbols.hourglass_top_rounded, fill: 1),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ready: a yellow "check this" tag; still being read:
                      // calm, muted words.
                      if (ready)
                        CbStatusTag(
                          label: scanStatusLabel(
                            l10n,
                            scan.status,
                            fromNote: note,
                          ),
                          tone: CbStatusTone.soon,
                        )
                      else
                        Text(
                          scanStatusLabel(l10n, scan.status, fromNote: note),
                          style: text.caption.copyWith(color: cb.inkMuted),
                        ),
                      const SizedBox(height: CbSpace.s1),
                      Text(switch ((note, ready)) {
                        (true, true) => l10n.noteResumeReady(when),
                        (true, false) => l10n.noteResumeOpen(when),
                        (false, true) => l10n.scanResumeReady(when),
                        (false, false) => l10n.scanResumeOpen(when),
                      }, style: text.subtitle),
                      ?_noteLine(context, scan),
                    ],
                  ),
                ),
              ),
              Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scan (or a note) that couldn't be read, with why. "Try again" reads
/// its photos (or text) anew: a new scan that names this one, which the
/// server then throws away, whoever started it. "Dismiss" throws it away
/// (a note, after asking: its text goes with it).
class _FailedCard extends ConsumerStatefulWidget {
  const _FailedCard({super.key, required this.scan});

  final AiScan scan;

  @override
  ConsumerState<_FailedCard> createState() => _FailedCardState();
}

class _FailedCardState extends ConsumerState<_FailedCard> {
  var _busy = false;

  Future<void> _dismiss() async {
    if (_busy) return;
    final l10n = context.l10n;
    final scan = widget.scan;
    // The note's text is deleted for good: asked first, like "Discard note".
    if (scan.isNote) {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.noteDiscardTitle,
        message: l10n.noteDiscardBody,
        confirmLabel: l10n.scanDiscardConfirm,
      );
      if (!confirmed || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final ai = ref.read(aiRepositoryProvider);
    setState(() => _busy = true);
    try {
      await ai.discardScan(scan.id);
    } catch (error) {
      debugPrint('Dismissing the scan failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Gone from the list, or as it is now on the server.
    refreshPetImports(container, scan.petId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final scan = widget.scan;
    final started = scan.createdAt.toLocal();
    final when = l10n.dateWithTime(
      started,
      TimeOfDay.fromDateTime(started).format(context),
    );
    final note = scan.isNote;
    final photosGone =
        !note && (scan.error == ScanError.photosMissing || scan.pages.isEmpty);
    return CbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconDisc(Symbols.error_rounded),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scanStatusLabel(l10n, scan.status),
                        style: text.caption.copyWith(color: cb.danger),
                      ),
                      const SizedBox(height: CbSpace.s1),
                      Text(
                        note
                            ? l10n.noteResumeOpen(when)
                            : l10n.scanResumeOpen(when),
                        style: text.subtitle,
                      ),
                      ?_noteLine(context, scan),
                      const SizedBox(height: CbSpace.s1),
                      Text(
                        photosGone
                            ? l10n.scanErrorPhotosMissing
                            : scanErrorMessage(
                                l10n,
                                scan.error,
                                fromNote: note,
                              ),
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CbSpace.s3),
          Wrap(
            spacing: CbSpace.s2,
            runSpacing: CbSpace.s2,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : _dismiss,
                child: Text(l10n.scanDismiss),
              ),
              if (scan.canReadAgain)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => openScan(
                          context,
                          scan.petId,
                          scanId: scan.id,
                          readAgain: true,
                          note: note,
                        ),
                  child: Text(l10n.commonTryAgain),
                )
              // A note with no text to read again (it can't happen; the
              // server keeps a failed note's text) is only dismissed.
              else if (!note)
                OutlinedButton(
                  onPressed: _busy ? null : () => openScan(context, scan.petId),
                  child: Text(l10n.scanStartOver),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The start of a note on its card, quoted on two lines at most, to tell
/// notes apart; null for a scan.
Widget? _noteLine(BuildContext context, AiScan scan) {
  final text = scan.text;
  if (!scan.isNote || text == null) return null;
  return Padding(
    padding: const EdgeInsets.only(top: CbSpace.s1),
    child: Text(
      context.l10n.scanEvidence(text),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.cbText.bodySm.copyWith(color: context.cb.inkMuted),
    ),
  );
}

/// An icon on a grey disc at the start of a card, like the kind icons of
/// the Health tab. Decorative: the card's text says what it is.
class _IconDisc extends StatelessWidget {
  const _IconDisc(this.icon, {this.fill});

  final IconData icon;

  /// 1 for a solid glyph; the theme's 0 (outlined) when null.
  final double? fill;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return ExcludeSemantics(
      child: Container(
        width: CbSize.avatarMd,
        height: CbSize.avatarMd,
        decoration: BoxDecoration(color: cb.sunken, shape: BoxShape.circle),
        child: Icon(icon, fill: fill, color: cb.inkMuted, size: 22),
      ),
    );
  }
}
