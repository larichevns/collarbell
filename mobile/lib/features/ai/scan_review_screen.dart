import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../care/care.dart';
import '../care/care_labels.dart';
import '../care/care_rules.dart';
import '../care/widgets/kind_icon.dart';
import '../files/page_viewer_screen.dart';
import '../files/widgets/page_grid.dart';
import '../pets/identifier_rules.dart';
import '../weight/weight.dart';
import 'ai.dart';
import 'ai_labels.dart';
import 'ai_repository.dart';
import 'scan_editors.dart';
import 'scan_refresh.dart';
import 'scan_review.dart';
import 'widgets/draft_cards.dart';
import 'widgets/note_quote.dart';

/// Checking a scan (or a note) before anything is saved (spec 5.5): every
/// entry the AI read, with what it doubts highlighted. The user ticks what
/// to save, fixes values, links records to the pet's plans and saves, or
/// discards the scan. AI never saves anything itself. A note has no photos
/// to keep: the review quotes it instead, to check the entries against.
class ScanReviewScreen extends ConsumerWidget {
  const ScanReviewScreen({
    super.key,
    required this.scan,
    required this.onReload,
  });

  /// A scan whose draft is ready.
  final AiScan scan;

  /// Fetches the scan again after the server said it can't be saved any
  /// more (saved or discarded elsewhere); the scan screen then shows what
  /// it is now. Throws when that fails.
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Fetched afresh for this review: the pet's species decides the vaccine
    // targets offered, its plans which "Done" a record can be, its passport
    // header what the scanned details would change, and its birth date the
    // first day of a weighing.
    final data = ref.watch(scanReviewDataProvider(scan.petId));
    final value = data.value;
    if (value != null) {
      return _Review(scan: scan, data: value, onReload: onReload);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(scan.isNote ? l10n.noteReviewTitle : l10n.scanReviewTitle),
      ),
      body: data.hasError
          ? Center(
              child: CbErrorState(
                message: errorMessageFor(data.error!, l10n),
                traceId: traceIdOf(data.error!),
                onRetry: () =>
                    ref.invalidate(scanReviewDataProvider(scan.petId)),
              ),
            )
          : const CbLoadingState.spinner(),
    );
  }
}

class _Review extends ConsumerStatefulWidget {
  const _Review({
    required this.scan,
    required this.data,
    required this.onReload,
  });

  final AiScan scan;
  final ScanReviewData data;
  final Future<void> Function() onReload;

  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  final _formKey = GlobalKey<FormState>();

  /// The draft as the user has it now: made once, so a reload of the pet's
  /// data or of the scan keeps the user's changes.
  late final _review = ScanReview.fromDraft(
    widget.scan.draft ?? ScanDraft.empty,
    planIds: {for (final plan in widget.data.plans) plan.id},
    savedPassport: widget.data.passport,
    savedCodes: {
      for (final identifier in widget.data.pet.identifiers)
        IdentifierRules.normalize(identifier.code),
    },
  );

  /// A note has no photos to keep.
  late var _keepPhotos = !widget.scan.isNote;
  var _submitted = false;
  var _busy = false;
  String? _failure;

  /// The user changed something here: leaving asks first.
  var _dirty = false;

  /// The last save may have gone through with its answer lost. A second
  /// save would get the first one's answer and drop the changes since, so
  /// the next save asks the server first.
  var _unconfirmed = false;

  AiScan get _scan => widget.scan;
  String get _petId => widget.scan.petId;
  List<CarePlan> get _plans => widget.data.plans;

  /// The draft was read from a note, not from photos.
  bool get _fromNote => widget.scan.isNote;

  /// Applies a change of the user and rebuilds.
  void _update(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  // --- Problems ---------------------------------------------------------

  Map<String, String> _recordProblems(ReviewRecord entry) =>
      recordProblems(entry, context.l10n, today: CbDateField.today());

  Map<String, String> _identifierProblems(ReviewIdentifier entry) =>
      identifierProblems(
        entry,
        context.l10n,
        today: CbDateField.today(),
        otherCodes: _review.codesBefore(entry),
        overLimit: _review.overLimit(entry),
      );

  Map<String, String> _passportProblems(ReviewPassport entry) =>
      passportProblems(entry, context.l10n, today: CbDateField.today());

  Map<String, String> _weightProblems(ReviewWeight entry) {
    final today = CbDateField.today();
    return weightProblems(
      entry,
      context.l10n,
      today: today,
      firstDate: WeightRules.firstDateFor(widget.data.pet, today),
    );
  }

  // --- Editing ----------------------------------------------------------

  /// Opens the photo of page [page] (counted from 1); null when it is gone.
  VoidCallback? _openPage(int page) {
    final pages = _scan.pages;
    if (page < 1 || page > pages.length) return null;
    return () => openPageViewer(context, pages: pages, initialIndex: page - 1);
  }

  Future<void> _editRecord(ReviewRecord entry) async {
    final edited = await editScanRecord(
      context,
      entry: entry,
      pet: widget.data.pet,
      pages: _scan.pages,
      fromNote: _fromNote,
    );
    if (edited == null || !mounted) return;
    _update(() {
      // A plan of another kind (or against other diseases) can't take this
      // record's "Done" any more.
      final planId = edited.planId;
      if (planId != null &&
          !planChoices(edited, _plans).any((p) => p.id == planId)) {
        edited.setPlan(null);
      }
      _afterEdit(entry, edited);
      _review.replaceRecord(edited);
    });
  }

  Future<void> _editIdentifier(ReviewIdentifier entry) async {
    final edited = await editScanIdentifier(
      context,
      entry: entry,
      otherCodes: _review.codesBefore(entry),
      pages: _scan.pages,
      fromNote: _fromNote,
    );
    if (edited == null || !mounted) return;
    _update(() {
      _afterEdit(entry, edited);
      _review.replaceIdentifier(edited);
    });
  }

  Future<void> _editPassport(ReviewPassport entry) async {
    final edited = await editScanPassport(
      context,
      entry: entry,
      pages: _scan.pages,
      fromNote: _fromNote,
    );
    if (edited == null || !mounted) return;
    _update(() {
      _afterEdit(entry, edited);
      _review.passport = edited;
    });
  }

  Future<void> _editWeight(ReviewWeight entry) async {
    final edited = await editScanWeight(
      context,
      entry: entry,
      pet: widget.data.pet,
      pages: _scan.pages,
      fromNote: _fromNote,
    );
    if (edited == null || !mounted) return;
    _update(() {
      _afterEdit(entry, edited);
      _review.replaceWeight(edited);
    });
  }

  /// After an edit: an entry that can't be saved any more is unticked, and
  /// one that couldn't be saved before (no date, no number, no weight) but
  /// can now is ticked, unless it repeats something.
  static void _afterEdit(ReviewEntry before, ReviewEntry edited) {
    if (!edited.canSelect) {
      edited.selected = false;
    } else if (!before.canSelect && !_repeats(edited)) {
      edited.selected = true;
    }
  }

  /// Already saved, or on another photo too: ticking it stays the user's
  /// choice.
  static bool _repeats(ReviewEntry entry) =>
      entry.hasIssue(DraftIssue.alreadySaved) ||
      entry.hasIssue(DraftIssue.repeated);

  /// Asks for the date the AI couldn't read, and ticks the entry: the user
  /// fills it in to save it.
  Future<void> _enterDate(ReviewRecord entry) async {
    final today = CbDateField.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: earliestCareDate,
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    _update(() {
      entry.setDate('performedOn', picked);
      if (!_repeats(entry)) entry.selected = true;
    });
  }

  Future<void> _choosePlan(ReviewRecord entry) async {
    final choice = await _pickPlan(
      context,
      plans: planChoices(entry, _plans),
      current: entry.planId,
    );
    if (choice == null || !mounted) return;
    _update(() => entry.setPlan(choice.planId));
  }

  // --- Saving and discarding --------------------------------------------

  /// An error after which the save may have gone through with only its
  /// answer lost (no connection, a timeout, a server error), unlike an
  /// answer that refuses it.
  static bool _mayHaveGoneThrough(Object error) => switch (error) {
    ApiException(
      kind: ApiErrorKind.validation ||
          ApiErrorKind.notFound ||
          ApiErrorKind.conflict ||
          ApiErrorKind.unauthorized ||
          ApiErrorKind.forbidden,
    ) =>
      false,
    _ => true,
  };

  Future<void> _save() async {
    if (_busy) return;
    final l10n = context.l10n;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitted = true;
      _failure = null;
      _review.clearServerErrors();
    });
    final invalid = invalidFields(_formKey.currentState!);
    if (invalid.isNotEmpty) {
      revealTopmost(invalid);
      setState(() => _failure = l10n.formCheckFields);
      return;
    }

    // Everything is read before the first await. Leaving is blocked while
    // saving (PopScope), but the app can still close the screen, e.g. on
    // sign-out, and the save must finish all the same.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final ai = ref.read(aiRepositoryProvider);
    final petId = _petId;
    final scan = _scan;
    // A record without a title of its own goes under its kind's name, in
    // the language the user has now.
    final sent = _review.sending(
      keepPhotos: _keepPhotos,
      defaultTitle: (kind, targets) => scanDefaultTitle(l10n, kind, targets),
    );
    void closeAsSaved(AiScan saved) => _closeAsSaved(
      saved,
      note: l10n.scanSavedBeforeDrop,
      navigator: navigator,
      messenger: messenger,
      container: container,
      l10n: l10n,
    );

    setState(() => _busy = true);
    try {
      if (_unconfirmed) {
        final now = await ai.getScan(scan.id);
        if (now.status == ScanStatus.applied) {
          closeAsSaved(now);
          return;
        }
        _unconfirmed = false;
      }
      final result = await ai.applyScan(scan.id, sent.input);
      refreshAfterScan(container, petId);
      if (mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            scanResultSummary(
              l10n,
              result,
              scan.source,
              passportFields: sent.passportFields,
              identifiersSent: sent.input.identifiers.length,
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Saving the scan failed: $error');
      // Part of it may have gone through: the lists reload anyway.
      refreshAfterScan(container, petId);
      if (isNotFound(error)) {
        messenger.showSnackBar(
          SnackBar(content: Text(scan.isNote ? l10n.noteGone : l10n.scanGone)),
        );
        if (mounted) navigator.pop();
        return;
      }
      if (!mounted) return;
      if (error is ApiException && error.kind == ApiErrorKind.conflict) {
        // Not ready any more: saved or discarded elsewhere. The scan
        // screen shows what it is now.
        await _reload(l10n);
        return;
      }
      if (_mayHaveGoneThrough(error)) {
        // The save may be done with only its answer lost: ask the server.
        AiScan? now;
        try {
          now = await ai.getScan(scan.id);
        } catch (checkError) {
          debugPrint(
            'Checking the scan after a failed save failed: $checkError',
          );
        }
        if (now?.status == ScanStatus.applied) {
          closeAsSaved(now!);
          return;
        }
        if (!mounted) return;
        if (now != null && now.status != ScanStatus.ready) {
          await _reload(l10n);
          return;
        }
        // Still waiting for the user (nothing saved): change and save
        // again. Unknown (still no connection): the next save asks first.
        _unconfirmed = now == null;
        setState(() {
          _failure = now == null
              ? l10n.scanSaveUnconfirmed
              : errorMessageFor(error, l10n);
        });
        return;
      }
      final fieldErrors = fieldErrorsOf(error);
      final placed =
          fieldErrors.isNotEmpty &&
          _review.placeServerErrors(fieldErrors, sent);
      setState(() {
        _failure = placed ? l10n.formCheckFields : errorMessageFor(error, l10n);
      });
      if (placed) revealTopmost(invalidFields(_formKey.currentState!));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Closes the review of a scan that turned out saved, with what it saved
  /// and [note] on why the user sees this.
  void _closeAsSaved(
    AiScan saved, {
    required String note,
    required NavigatorState navigator,
    required ScaffoldMessengerState messenger,
    required ProviderContainer container,
    required AppLocalizations l10n,
  }) {
    refreshAfterScan(container, saved.petId);
    if (mounted) navigator.pop();
    final summary = scanResultSummary(
      l10n,
      saved.result ?? const ScanResult(),
      saved.source,
    );
    messenger.showSnackBar(SnackBar(content: Text('$summary ($note)')));
  }

  Future<void> _reload(AppLocalizations l10n) async {
    try {
      await widget.onReload();
      // Still here: the scan is ready after all, so saving can be tried
      // again.
      if (mounted) setState(() => _failure = l10n.errorUnknown);
    } catch (error) {
      debugPrint('Reloading the scan failed: $error');
      if (mounted) setState(() => _failure = errorMessageFor(error, l10n));
    }
  }

  Future<void> _discard() async {
    if (_busy) return;
    final l10n = context.l10n;
    final note = _fromNote;
    final confirmed = await confirmDestructive(
      context,
      title: note ? l10n.noteDiscardTitle : l10n.scanDiscardTitle,
      message: note ? l10n.noteDiscardBody : l10n.scanDiscardBody,
      confirmLabel: l10n.scanDiscardConfirm,
    );
    if (!confirmed || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final ai = ref.read(aiRepositoryProvider);
    final petId = _petId;
    final scanId = _scan.id;
    void closeAsDiscarded() {
      refreshPetImports(container, petId);
      if (mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(note ? l10n.noteDiscarded : l10n.scanDiscarded)),
      );
    }

    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ai.discardScan(scanId);
      closeAsDiscarded();
    } catch (error) {
      debugPrint('Discarding the scan failed: $error');
      // Saved meanwhile (409, perhaps by a save whose answer was lost), or
      // the answer itself lost: ask the server what the scan is now.
      AiScan? now;
      try {
        now = await ai.getScan(scanId);
      } catch (checkError) {
        debugPrint('Checking the scan after discarding failed: $checkError');
      }
      switch (now?.status) {
        case ScanStatus.applied:
          _closeAsSaved(
            now!,
            note: note ? l10n.noteSavedNoDiscard : l10n.scanSavedNoDiscard,
            navigator: navigator,
            messenger: messenger,
            container: container,
            l10n: l10n,
          );
        case ScanStatus.discarded:
          closeAsDiscarded();
        default:
          if (mounted) setState(() => _failure = errorMessageFor(error, l10n));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Asks before Back (or tapping the tab again) drops the changes made
  /// here; the scan or note itself stays to be checked later.
  Future<bool> _confirmLeave(BuildContext context) {
    final l10n = context.l10n;
    return confirmDestructive(
      context,
      title: l10n.scanLeaveTitle,
      message: _fromNote ? l10n.noteLeaveBody : l10n.scanLeaveBody,
      confirmLabel: l10n.scanLeaveConfirm,
    );
  }

  // --- Layout -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final count = _review.selectedCount;
    final passport = _review.passport;
    final note = _fromNote;
    final noteText = _scan.text;
    const gap = SizedBox(height: CbSpace.s3);

    return LeaveGuard(
      // No leaving while saving: the save goes on, and the lists would show
      // the pet before it. With changes made here, leaving asks first (also
      // when the tab is tapped again); without, Back and iOS's back swipe
      // just leave. Every change rebuilds the review.
      busy: _busy,
      changed: () => _dirty,
      rebuildsOnChange: true,
      confirm: _confirmLeave,
      child: Scaffold(
        appBar: AppBar(
          title: Text(note ? l10n.noteReviewTitle : l10n.scanReviewTitle),
        ),
        bottomNavigationBar: CbSaveBar(
          busy: _busy,
          error: _failure,
          label: count == 0 && _keepPhotos
              ? l10n.scanSavePhotosOnly
              : l10n.scanSaveSelected(count),
          // Nothing ticked and no photos kept (a note has none): nothing to
          // save.
          onSave: count > 0 || _keepPhotos ? _save : null,
          secondary: TextButton(
            style: TextButton.styleFrom(foregroundColor: cb.inkMuted),
            onPressed: _busy ? null : _discard,
            child: Text(note ? l10n.noteDiscard : l10n.scanDiscard),
          ),
        ),
        body: Form(
          key: _formKey,
          // Not a lazy list: every entry is built, so every ticked entry is
          // checked when saving.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s12,
            ),
            // No input while saving: an editor or a date picker opened now
            // would be too late to change what is sent.
            child: IgnorePointer(
              ignoring: _busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CbNotice(
                    message: note ? l10n.noteReviewIntro : l10n.scanReviewIntro,
                  ),
                  if (_review.isEmpty) ...[
                    const SizedBox(height: CbSpace.s6),
                    Text(
                      note ? l10n.noteNothingFound : l10n.scanNothingFound,
                      style: text.body.copyWith(color: cb.inkMuted),
                    ),
                  ],
                  if (_review.records.isNotEmpty) ...[
                    const SizedBox(height: CbSpace.s6),
                    CbSection(
                      title: l10n.scanRecordsTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _review.records.length; i++) ...[
                            if (i > 0) gap,
                            _recordCard(_review.records[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // Right under the records: a weight repeated by a
                  // check-up is "the same as an entry above".
                  if (_review.weights.isNotEmpty) ...[
                    const SizedBox(height: CbSpace.s6),
                    CbSection(
                      title: l10n.scanWeightsTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _review.weights.length; i++) ...[
                            if (i > 0) gap,
                            _weightCard(_review.weights[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_review.identifiers.isNotEmpty) ...[
                    const SizedBox(height: CbSpace.s6),
                    CbSection(
                      title: l10n.identifiersTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var i = 0;
                            i < _review.identifiers.length;
                            i++
                          ) ...[
                            if (i > 0) gap,
                            _identifierCard(_review.identifiers[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (passport != null) ...[
                    const SizedBox(height: CbSpace.s6),
                    CbSection(
                      title: l10n.passportTitle,
                      child: PassportDraftCard(
                        key: const ValueKey('passport'),
                        entry: passport,
                        problems: () => _passportProblems(passport),
                        showProblems: _submitted,
                        update: _update,
                        onEdit: () => _editPassport(passport),
                        onOpenPage: _openPage(passport.draft.page),
                        fromNote: note,
                      ),
                    ),
                  ],
                  const SizedBox(height: CbSpace.s6),
                  // A note is quoted where a scan's photos are, to check
                  // the entries against what the user wrote; it has no
                  // photos to keep.
                  if (note)
                    CbSection(
                      title: l10n.noteSectionTitle,
                      child: NoteQuote(
                        text: noteText ?? '',
                        writtenAt: _scan.createdAt,
                      ),
                    )
                  else
                    CbSection(
                      title: l10n.carePhotosTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_scan.pages.isNotEmpty)
                            PageGrid(
                              pages: _scan.pages,
                              onTap: (page) => openPageViewer(
                                context,
                                pages: _scan.pages,
                                initialIndex: _scan.pages.indexOf(page),
                              ),
                            ),
                          SwitchListTile(
                            key: const ValueKey('keepPhotos'),
                            contentPadding: EdgeInsets.zero,
                            value: _keepPhotos,
                            title: Text(
                              _scan.source == ScanSource.passportPages
                                  ? l10n.scanKeepPhotosPassport
                                  : l10n.scanKeepPhotosDocument,
                              style: text.body,
                            ),
                            subtitle: Text(
                              _scan.source == ScanSource.passportPages
                                  ? l10n.scanKeepPhotosPassportHelper
                                  : l10n.scanKeepPhotosDocumentHelper,
                              style: text.bodySm.copyWith(color: cb.inkMuted),
                            ),
                            onChanged: (value) =>
                                _update(() => _keepPhotos = value),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordCard(ReviewRecord entry) => RecordDraftCard(
    // The entry's key: an edited entry (a new object) keeps its card.
    key: ValueKey('record-${entry.key}'),
    entry: entry,
    plans: _plans,
    problems: () => _recordProblems(entry),
    showProblems: _submitted,
    update: _update,
    onEdit: () => _editRecord(entry),
    onEnterDate: () => _enterDate(entry),
    onChoosePlan: () => _choosePlan(entry),
    onOpenPage: _openPage(entry.draft.page),
    fromNote: _fromNote,
  );

  Widget _identifierCard(ReviewIdentifier entry) => IdentifierDraftCard(
    key: ValueKey('identifier-${entry.key}'),
    entry: entry,
    problems: () => _identifierProblems(entry),
    showProblems: _submitted,
    update: _update,
    onEdit: () => _editIdentifier(entry),
    onOpenPage: _openPage(entry.draft.page),
    fromNote: _fromNote,
  );

  Widget _weightCard(ReviewWeight entry) => WeightDraftCard(
    key: ValueKey('weight-${entry.key}'),
    entry: entry,
    problems: () => _weightProblems(entry),
    showProblems: _submitted,
    update: _update,
    onEdit: () => _editWeight(entry),
    onOpenPage: _openPage(entry.draft.page),
    fromNote: _fromNote,
  );
}

/// Asks which plan a record is a "Done" of: one of [plans], or none.
/// Returns null when the user closes the sheet.
Future<({String? planId})?> _pickPlan(
  BuildContext context, {
  required List<CarePlan> plans,
  required String? current,
}) {
  return showModalBottomSheet<({String? planId})>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;
      final cb = context.cb;
      final text = context.cbText;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: CbSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CbSpace.s4,
                  CbSpace.s4,
                  CbSpace.s4,
                  CbSpace.s2,
                ),
                child: Semantics(
                  header: true,
                  child: Text(l10n.scanPlanPickTitle, style: text.title),
                ),
              ),
              for (final plan in plans)
                ListTile(
                  key: ValueKey(plan.id),
                  leading: KindIcon(kind: plan.kind),
                  title: Text(plan.title),
                  subtitle: Text(
                    [
                      planIntervalLabel(l10n, plan),
                      keepTogether(l10n.dateMedium(plan.nextDueOn)),
                    ].join(' · '),
                    style: text.bodySm.copyWith(color: cb.inkMuted),
                  ),
                  trailing: plan.id == current
                      ? Icon(Symbols.check_rounded, color: cb.primaryText)
                      : null,
                  onTap: () => Navigator.of(context).pop((planId: plan.id)),
                ),
              ListTile(
                leading: const SizedBox(
                  width: CbSize.avatarMd,
                  child: Icon(Symbols.link_off_rounded),
                ),
                title: Text(l10n.scanPlanNone),
                trailing: current == null
                    ? Icon(Symbols.check_rounded, color: cb.primaryText)
                    : null,
                onTap: () => Navigator.of(context).pop((planId: null)),
              ),
            ],
          ),
        ),
      );
    },
  );
}
