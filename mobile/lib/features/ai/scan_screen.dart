import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../billing/open_plan_button.dart';
import '../care/widgets/record_photos.dart';
import '../files/files_repository.dart';
import '../files/media_picker.dart';
import '../files/page_viewer_screen.dart';
import '../files/stored_file.dart';
import '../files/widgets/media_sheet.dart';
import '../files/widgets/page_grid.dart';
import '../files/widgets/stored_file_image.dart';
import '../files/widgets/upload_progress.dart';
import 'ai.dart';
import 'ai_labels.dart';
import 'ai_repository.dart';
import 'scan_review_screen.dart';
import 'widgets/note_quote.dart';

/// A scan of the pet's passport pages (or a vet document), or a note: the
/// photos (or the note's text), the wait while AI reads them, and then the
/// draft to check ([ScanReviewScreen]).
///
/// Without [scanId] it starts a new scan: the user scans or picks the
/// pages, they upload, and the server starts reading them; with [note], the
/// user writes or dictates a note instead ("Write it in words" on the
/// Health tab). With [scanId] it picks up a scan or a note started before,
/// e.g. from the Passport tab or the Health tab.
///
/// Leaving while AI reads doesn't stop it: the server goes on, and the
/// Passport tab (for a note, the Health tab) offers to continue. Only
/// uploading and starting keep the user here, because the photos would be
/// lost; a note typed here and not sent yet asks first. While the app is in
/// the background it stops asking; back in front, it asks at once.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({
    super.key,
    required this.petId,
    this.scanId,
    this.readAgain = false,
    this.note = false,
  });

  final String petId;

  /// A scan started before; null for a new one.
  final String? scanId;

  /// Reads the failed scan [scanId] again at once: "Try again" on its card
  /// on the Passport tab (or the Health tab, for a note).
  final bool readAgain;

  /// A new note instead of photos; with [scanId], that it is a note, so
  /// the screen speaks of a note before it has loaded (and if it can't).
  final bool note;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

/// The photos of a scan the app is starting: taken on this phone, or the
/// photos of a failed scan, read again; or the text of a note.
class _Start {
  _Start({
    required this.source,
    this.pages = const [],
    this.files = const [],
    this.text,
    this.retryOf,
  });

  final ScanSource source;

  /// Photos from this phone. A retry reuses the ones that uploaded.
  final List<DraftPhoto> pages;

  /// Photos on the server already, for "Try again" after a failed scan.
  final List<StoredFile> files;

  /// The note, trimmed; null for photos.
  final String? text;

  /// The failed scan or note this reads again ("Try again"): the server
  /// throws it away, whoever started it, and a note keeps the day it was
  /// written.
  final String? retryOf;

  /// One id per scan or note the user starts, sent with every try: the
  /// server answers a retry after a lost response with the one it started.
  final requestId = const Uuid().v4();

  bool get isNote => source == ScanSource.note;

  List<String> get fileIds => files.isNotEmpty
      ? [for (final file in files) file.id]
      : [for (final page in pages) page.file!.id];

  /// The photos on the phone.
  List<PickedMedia> get picked => [for (final page in pages) ?page.picked];
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  /// How often the app asks whether AI has finished reading.
  static const _pollEvery = Duration(seconds: 2);

  /// After this many questions (a minute and a half) the screen says that
  /// reading takes longer than usual.
  static const _slowAfterPolls = 45;

  /// What a new scan reads: the passport, a vet document, or a note.
  late var _source = widget.note ? ScanSource.note : ScanSource.passportPages;

  /// The note being written, or a failed note being read again.
  final _note = TextEditingController();
  final _noteFormKey = GlobalKey<FormState>();

  /// Each text sent from this screen, with its start: sending a text again
  /// (after a failure, or after trying another text) keeps its request id,
  /// so the server never reads the same note twice.
  final _noteStarts = <String, _Start>{};

  /// The failed scan or note this screen reads again ("Try again"): what is
  /// sent from here takes its place.
  String? _retryOf;

  /// "Read" was tapped: the note's field shows its problems as it changes.
  var _noteSubmitted = false;

  /// The server refused the note's text (empty or too long after all).
  var _noteRefused = false;

  /// The scan as the server last described it.
  AiScan? _scan;

  /// The scan of [ScanScreen.scanId] is loading; [_loadError] when that
  /// failed.
  late var _loading = widget.scanId != null;
  Object? _loadError;

  /// A scan being started. It stays while starting fails, so "Try again"
  /// sends the same photos and request id.
  _Start? _start;

  /// Uploading or starting: leaving now would lose the photos.
  var _busy = false;
  (int, int)? _progress;
  String? _failure;

  /// Starting the same way again can't help (AI is off, the photos are
  /// refused for good, or the day's notes are used up): only "Scan again"
  /// is offered; a note's "Read" is off.
  var _startDead = false;

  /// Starting failed for the group's monthly AI photos: the plan is offered.
  var _aiLimit = false;
  var _polls = 0;

  /// The last check failed (no connection for a moment); the next one is
  /// on its way.
  var _pollFailed = false;

  /// The scan no longer exists, e.g. it went with a deleted pet.
  var _gone = false;

  /// The scanner or the photo library is open: another tap waits for it.
  var _picking = false;

  /// Counts the times the scanner or the library opened, so that only the
  /// latest one clears [_picking].
  var _pickRun = 0;

  /// The scanned pages are being shrunk before they upload.
  var _preparing = false;

  /// The app is in the background: no asking until it is back.
  var _background = false;

  /// A check of the scan is on its way.
  var _checking = false;
  Timer? _timer;
  Timer? _pickerTimer;
  late final AppLifecycleListener _lifecycle;

  /// Read in [initState]: [dispose] deletes the photos left on the phone.
  late final MediaPicker _picker;

  @override
  void initState() {
    super.initState();
    _picker = ref.read(mediaPickerProvider);
    _lifecycle = AppLifecycleListener(onHide: _onHide, onResume: _onResume);
    final scanId = widget.scanId;
    if (scanId != null) _load(scanId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pickerTimer?.cancel();
    _lifecycle.dispose();
    _note.dispose();
    // Photos that never became a scan: they are personal documents.
    final start = _start;
    if (start != null) unawaited(_picker.deletePicked(start.picked));
    super.dispose();
  }

  void _onHide() {
    _background = true;
    _timer?.cancel();
  }

  void _onResume() {
    // The scanner or the library may never answer, e.g. when the system
    // closed it: after a moment, the buttons work again.
    if (_picking) {
      final run = _pickRun;
      _pickerTimer?.cancel();
      _pickerTimer = Timer(const Duration(seconds: 2), () {
        if (run == _pickRun) _picking = false;
      });
    }
    if (!_background) return;
    _background = false;
    // AI may have finished meanwhile: ask at once.
    final scan = _scan;
    if (scan != null && scan.status.isReading && !_checking) {
      _timer?.cancel();
      _check(scan.id);
    }
  }

  // --- Loading and waiting ----------------------------------------------

  Future<void> _load(String id) async {
    final ai = ref.read(aiRepositoryProvider);
    try {
      final scan = await ai.getScan(id);
      if (!mounted) return;
      _show(scan);
      if (widget.readAgain && scan.canReadAgain) _readAgain(scan);
    } catch (error) {
      debugPrint('Loading the scan failed: $error');
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _gone = isNotFound(error);
      });
    }
  }

  /// Shows [scan] and, while AI is reading it, asks again in a moment.
  void _show(AiScan scan) {
    _timer?.cancel();
    setState(() {
      _scan = scan;
      _loading = false;
      _pollFailed = false;
    });
    if (scan.status.isReading && !_background) {
      _timer = Timer(_pollEvery, () => _check(scan.id));
    }
  }

  Future<void> _check(String id) async {
    final ai = ref.read(aiRepositoryProvider);
    _polls++;
    _checking = true;
    try {
      final scan = await ai.getScan(id);
      _checking = false;
      // A scan started over or read again meanwhile is another one.
      if (mounted && _start == null && _scan?.id == id) _show(scan);
    } catch (error) {
      _checking = false;
      debugPrint('Checking the scan failed: $error');
      if (!mounted || _start != null || _scan?.id != id) return;
      if (isNotFound(error)) {
        setState(() => _gone = true);
        return;
      }
      // Most likely no connection for a moment: say so and ask again.
      setState(() => _pollFailed = true);
      if (!_background) _timer = Timer(_pollEvery, () => _check(id));
    }
  }

  /// Fetches the scan again after the server refused to save it because it
  /// isn't ready any more (saved or discarded elsewhere), and shows what it
  /// is now. Throws when that fails; the review says so.
  Future<void> _reload(String id) async {
    final ai = ref.read(aiRepositoryProvider);
    try {
      final scan = await ai.getScan(id);
      if (mounted) _show(scan);
    } catch (error) {
      if (mounted && isNotFound(error)) setState(() => _gone = true);
      rethrow;
    }
  }

  // --- Taking the pages -------------------------------------------------

  /// The screen still offers to take the pages: nothing was started.
  bool get _choosing =>
      _start == null && _scan == null && !_loading && !_gone && !_preparing;

  Future<void> _scanPages() async {
    if (_picking || _preparing) return;
    final run = ++_pickRun;
    _picking = true;
    final picker = _picker;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      // One page more than a scan takes: the scanner on iPhone drops pages
      // past the limit without a word, so more pages than that must show.
      final scanned = await picker.scanPages(maxPages: AiScan.maxPages + 1);
      if (run == _pickRun) _picking = false;
      // Cancelled: the user stays here and may choose photos instead.
      if (scanned == null || scanned.isEmpty) return;
      if (!mounted || !_choosing) {
        // Came too late (see _onResume): another scan is on its way.
        await picker.deletePicked(scanned);
        return;
      }
      setState(() => _preparing = true);
      final List<PickedMedia> pages;
      try {
        pages = await picker.prepareScans(scanned);
      } finally {
        if (mounted) setState(() => _preparing = false);
      }
      if (!mounted) {
        await picker.deletePicked(pages);
        return;
      }
      _begin(pages);
    } on ScannerUnavailableException catch (error) {
      debugPrint('The document scanner is not available: $error');
      if (!mounted) return;
      // A simulator, or a phone without the scanner: photos of the pages
      // do the same job.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.scanScannerUnavailable)),
      );
      await _pickPhotos();
    } on PlatformException catch (error) {
      // No access to the camera.
      debugPrint('Opening the scanner failed: $error');
      if (mounted) showPickerError(context);
    } finally {
      if (run == _pickRun) _picking = false;
    }
  }

  Future<void> _choosePhotos() async {
    if (_picking || _preparing) return;
    final run = ++_pickRun;
    _picking = true;
    try {
      await _pickPhotos();
    } finally {
      if (run == _pickRun) _picking = false;
    }
  }

  Future<void> _pickPhotos() async {
    final picker = _picker;
    try {
      final photos = await picker.pickPhotos(limit: AiScan.maxPages);
      if (photos.isEmpty) return;
      if (!mounted || !_choosing) {
        await picker.deletePicked(photos);
        return;
      }
      _begin(photos);
    } on PlatformException catch (error) {
      // No access to the photos.
      debugPrint('Picking photos failed: $error');
      if (mounted) showPickerError(context);
    }
  }

  /// Starts a new scan of [picked]; pages past the limit are dropped.
  void _begin(List<PickedMedia> picked) {
    if (picked.length > AiScan.maxPages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.scanTooManyPages(AiScan.maxPages))),
      );
      unawaited(_picker.deletePicked(picked.skip(AiScan.maxPages).toList()));
    }
    setState(() {
      _start = _Start(
        source: _source,
        pages: [
          for (final media in picked.take(AiScan.maxPages))
            DraftPhoto.picked(media),
        ],
      );
      _failure = null;
      _startDead = false;
      _aiLimit = false;
    });
    _run();
  }

  /// "Try again" after a failed scan: the same photos (or the same note),
  /// read anew. That is a new scan with its own request id, naming the
  /// failed one: the server throws that away, whoever started it, and a
  /// note keeps the day it was written.
  void _readAgain(AiScan failed) {
    _retryOf = failed.id;
    final text = failed.isNote ? failed.text?.trim() : null;
    final start = _Start(
      source: failed.source,
      files: failed.pages,
      text: text,
      retryOf: failed.id,
    );
    if (text != null) {
      // Should starting fail, the note is there to send again (with the
      // same request id) or to change.
      _note.text = text;
      _noteStarts[text] = start;
    }
    setState(() {
      _start = start;
      _failure = null;
      _startDead = false;
      _aiLimit = false;
      _noteRefused = false;
    });
    _run();
  }

  /// Back to choosing pages, e.g. when the photos are gone.
  void _startOver() {
    _timer?.cancel();
    final start = _start;
    if (start != null) unawaited(_picker.deletePicked(start.picked));
    // New photos are a new scan: they don't read the failed one again.
    _retryOf = null;
    setState(() {
      _source = _start?.source ?? _scan?.source ?? _source;
      _start = null;
      _scan = null;
      _loading = false;
      _loadError = null;
      _gone = false;
      _failure = null;
      _startDead = false;
      _aiLimit = false;
    });
  }

  // --- Writing a note ---------------------------------------------------

  /// What the screen reads: the scan or note being started, else the one
  /// shown, else what a new scan will read.
  ScanSource get _currentSource => _start?.source ?? _scan?.source ?? _source;

  /// The note's text is on screen to write or change: a new note, or one
  /// that is being sent (or failed to be) and isn't read yet.
  bool get _writingNote =>
      _currentSource == ScanSource.note &&
      !_loading &&
      !_gone &&
      (_start != null || _scan == null);

  /// A note typed here that the server may not have: leaving asks first. A
  /// failed note read again unchanged is on the server already.
  bool get _noteAtRisk {
    if (!_writingNote) return false;
    final text = _note.text.trim();
    return text.isNotEmpty && text != _scan?.text;
  }

  /// The note's problems before it is sent, as the server sees them: some
  /// words (a letter or a digit), and up to [AiScan.maxNoteLength]
  /// characters, counted as the counter counts them.
  String? _noteProblem(String? value) {
    final l10n = context.l10n;
    final text = value ?? '';
    if (!noteHasWords(text)) return l10n.noteRequired;
    if (CbTextField.countedLength(text) > AiScan.maxNoteLength) {
      return l10n.formTooLong(AiScan.maxNoteLength);
    }
    if (_noteRefused) return l10n.formServerFieldError;
    return null;
  }

  /// "Read": the note is checked here and sent. A text sent before from this
  /// screen (a retry after a failure, or back to it after trying another)
  /// keeps its request id; a new text is another note, with an id of its
  /// own.
  void _readNote() {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _noteSubmitted = true;
      _noteRefused = false;
      // What went wrong last time; the field says what is wrong now.
      _failure = null;
    });
    if (!_noteFormKey.currentState!.validate()) return;
    final text = _note.text.trim();
    final start = _noteStarts.putIfAbsent(
      text,
      () => _Start(source: ScanSource.note, text: text, retryOf: _retryOf),
    );
    if (!identical(start, _start)) setState(() => _start = start);
    _run();
  }

  /// Uploads the photos that aren't uploaded yet and starts the scan (or
  /// sends the note). A retry sends the same request id, so a scan that
  /// started with only the answer lost isn't started twice.
  Future<void> _run() async {
    final start = _start;
    if (start == null || _busy) return;
    // Everything is read before the first await. Leaving is blocked while
    // this runs (LeaveGuard), but the app can still close the screen, e.g.
    // on sign-out.
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final files = ref.read(filesRepositoryProvider);
    final ai = ref.read(aiRepositoryProvider);
    final petId = widget.petId;
    ref
        .read(appEventsProvider)
        .action(start.isNote ? AppAction.noteStarted : AppAction.scanStarted);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await uploadNewPhotos(
        files,
        start.pages,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = (done, total));
        },
      );
      if (mounted) setState(() => _progress = null);
      final scan = await ai.startScan(
        petId,
        source: start.source,
        fileIds: start.fileIds,
        text: start.text,
        retryOf: start.retryOf,
        requestId: start.requestId,
      );
      refreshPetImports(container, petId);
      // The photos are on the server now: the copies on the phone go.
      unawaited(_picker.deletePicked(start.picked));
      if (!mounted) return;
      _polls = 0;
      setState(() => _start = null);
      _show(scan);
    } catch (error) {
      debugPrint('Starting the scan failed: $error');
      if (isNotFound(error)) {
        // The pet was deleted elsewhere: there is nothing to scan for.
        messenger.showSnackBar(SnackBar(content: Text(l10n.careGonePet)));
        if (mounted) navigator.pop();
        return;
      }
      final kind = error is ApiException ? error.kind : null;
      // The month's AI photos: a 409 of its own type. The same pages fail
      // again; fewer may not.
      final aiLimit = isAiLimit(error);
      // The day's notes: a 429 of its own type. Any note fails until
      // tomorrow.
      final noteLimit = isNoteLimit(error);
      // AI was turned off on the server meanwhile: the buttons go too.
      if (kind == ApiErrorKind.conflict && !aiLimit) {
        container.invalidate(aiStatusProvider);
      }
      if (!mounted) return;
      // The note's text refused (empty or too long after all): said on its
      // field, to change it.
      final textRefused =
          start.isNote && fieldErrorsOf(error).containsKey('text');
      final (failure, dead) = switch (kind) {
        _ when aiLimit => (errorMessageFor(error, l10n), true),
        _ when noteLimit => (scanStartErrorMessage(error, l10n), true),
        ApiErrorKind.conflict => (
          start.isNote
              ? l10n.noteErrorNotConfigured
              : l10n.scanErrorNotConfigured,
          true,
        ),
        _ when textRefused => (l10n.formCheckFields, false),
        // The photos of a failed scan can't be used any more.
        ApiErrorKind.validation when start.files.isNotEmpty => (
          l10n.scanErrorPhotosMissing,
          true,
        ),
        ApiErrorKind.validation when start.isNote => (
          errorMessageFor(error, l10n),
          false,
        ),
        // The uploads were refused (used elsewhere meanwhile, or gone):
        // "Try again" uploads the photos anew (see below).
        ApiErrorKind.validation => (l10n.scanPhotosRefused, false),
        // A photo itself is refused: only other photos help.
        ApiErrorKind.payloadTooLarge || ApiErrorKind.unsupportedMediaType => (
          errorMessageFor(error, l10n),
          true,
        ),
        _ => (errorMessageFor(error, l10n), false),
      };
      if (kind == ApiErrorKind.validation) {
        for (final page in start.pages) {
          page.file = null;
        }
      }
      setState(() {
        _progress = null;
        _failure = failure;
        _startDead = dead;
        _aiLimit = aiLimit;
        _noteRefused = textRefused;
      });
      if (textRefused) _noteFormKey.currentState?.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Layout -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scan = _scan;
    if (_start == null &&
        !_gone &&
        scan != null &&
        scan.status == ScanStatus.ready) {
      return ScanReviewScreen(
        key: ValueKey(scan.id),
        scan: scan,
        onReload: () => _reload(scan.id),
      );
    }
    final l10n = context.l10n;
    final writing = _writingNote;
    final choosing = !writing && (_choosing || _preparing);
    return LeaveGuard(
      // No leaving while the photos upload or the scan starts: they would
      // be lost. Reading goes on without the screen. A note typed here and
      // not sent asks first. Otherwise Back (and iOS's back swipe) leave at
      // once: the screen rebuilds as the note is typed.
      busy: _busy,
      changed: () => _noteAtRisk,
      rebuildsOnChange: true,
      child: Scaffold(
        appBar: AppBar(title: Text(scanTitle(l10n, _currentSource))),
        bottomNavigationBar: writing
            ? CbSaveBar(
                busy: _busy,
                busyLabel: l10n.noteStarting,
                error: _failure,
                label: l10n.noteRead,
                // Sending again can't help today (AI is off, or the day's
                // notes are used up).
                onSave: _startDead ? null : _readNote,
              )
            // The ways to take the pages stay in reach on any phone.
            : choosing
            ? CbSaveBar(
                // The scanned pages are being made ready to upload.
                busy: _preparing,
                label: l10n.scanWithCamera,
                onSave: _scanPages,
                secondary: OutlinedButton.icon(
                  onPressed: _preparing ? null : _choosePhotos,
                  icon: const Icon(Symbols.photo_library_rounded),
                  label: Text(l10n.scanChoosePhotos),
                ),
              )
            : null,
        body: IgnorePointer(
          ignoring: _busy || _preparing,
          child: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final start = _start;
    final scan = _scan;
    if (_writingNote) {
      return _NoteView(
        formKey: _noteFormKey,
        controller: _note,
        submitted: _noteSubmitted,
        freeTier: ref.watch(aiStatusProvider).value?.freeTier ?? false,
        validator: _noteProblem,
        // Rebuilt as the note is typed: whether leaving would lose it, and
        // the counter; a change also answers the server's refusal of it.
        onChanged: (_) => setState(() => _noteRefused = false),
      );
    }
    if (start != null) {
      return _StartingView(
        start: start,
        busy: _busy,
        progress: _progress,
        failure: _failure,
        canRetry: !_startDead,
        aiLimit: _aiLimit,
        onRetry: _run,
        onStartOver: _startOver,
      );
    }
    final note = _currentSource == ScanSource.note;
    if (_gone) {
      return _ResultView(
        icon: Symbols.search_off_rounded,
        title: note ? l10n.noteGone : l10n.scanGone,
        actions: [_closeButton(context)],
      );
    }
    if (scan != null) {
      return switch (scan.status) {
        ScanStatus.queued || ScanStatus.processing => _ReadingView(
          scan: scan,
          slow: _polls >= _slowAfterPolls,
          offline: _pollFailed,
        ),
        ScanStatus.failed => _failedView(context, scan),
        ScanStatus.applied => _ResultView(
          icon: Symbols.check_circle_rounded,
          title: scanStatusLabel(l10n, scan.status),
          message: scanResultSummary(
            l10n,
            scan.result ?? const ScanResult(),
            scan.source,
          ),
          actions: [_closeButton(context)],
        ),
        ScanStatus.discarded => _ResultView(
          icon: Symbols.delete_rounded,
          title: scanStatusLabel(l10n, scan.status),
          message: scan.isNote
              ? l10n.noteDiscardedBody
              : l10n.scanDiscardedBody,
          actions: [_closeButton(context)],
        ),
        // Shown by the review (see build).
        ScanStatus.ready => const SizedBox.shrink(),
      };
    }
    if (_loading) {
      final error = _loadError;
      return error == null
          ? const CbLoadingState.spinner()
          : Center(
              child: CbErrorState(
                message: errorMessageFor(error, l10n),
                traceId: traceIdOf(error),
                onRetry: () {
                  setState(() => _loadError = null);
                  _load(widget.scanId!);
                },
              ),
            );
    }
    return _ChooseView(
      source: _source,
      freeTier: ref.watch(aiStatusProvider).value?.freeTier ?? false,
      onSource: (source) => setState(() => _source = source),
    );
  }

  Widget _failedView(BuildContext context, AiScan scan) {
    final l10n = context.l10n;
    final error = scan.error;
    // Reading again can help whatever went wrong (the models busy, the key
    // fixed on the server since) while the photos (or the note) are there.
    final canReadAgain = scan.canReadAgain;
    if (scan.isNote) {
      final text = scan.text;
      return _ResultView(
        icon: Symbols.error_rounded,
        danger: true,
        title: scanStatusLabel(l10n, scan.status),
        message: scanErrorMessage(l10n, error, fromNote: true),
        noteText: text,
        actions: [
          if (canReadAgain)
            FilledButton(
              onPressed: () => _readAgain(scan),
              child: Text(l10n.commonTryAgain),
            ),
          _closeButton(context),
        ],
      );
    }
    final photosGone = error == ScanError.photosMissing || scan.pages.isEmpty;
    return _ResultView(
      icon: Symbols.error_rounded,
      danger: true,
      title: scanStatusLabel(l10n, scan.status),
      message: photosGone
          ? l10n.scanErrorPhotosMissing
          : scanErrorMessage(l10n, error),
      pages: scan.pages,
      actions: [
        if (canReadAgain)
          FilledButton(
            onPressed: () => _readAgain(scan),
            child: Text(l10n.commonTryAgain),
          )
        else if (photosGone)
          FilledButton(onPressed: _startOver, child: Text(l10n.scanStartOver)),
        _closeButton(context),
      ],
    );
  }

  Widget _closeButton(BuildContext context) => TextButton(
    onPressed: () => Navigator.of(context).maybePop(),
    child: Text(context.l10n.scanClose),
  );
}

/// Choosing what to scan, with what happens to it; the bottom bar takes
/// the pages (the document scanner, or photos).
class _ChooseView extends StatelessWidget {
  const _ChooseView({
    required this.source,
    required this.freeTier,
    required this.onSource,
  });

  final ScanSource source;
  final bool freeTier;
  final ValueChanged<ScanSource> onSource;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s12,
      ),
      children: [
        CbLabeled(
          label: l10n.scanSourceLabel,
          child: SegmentedButton<ScanSource>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ScanSource.passportPages,
                label: Text(l10n.scanSourcePassport),
              ),
              ButtonSegment(
                value: ScanSource.vetDocument,
                label: Text(l10n.scanSourceDocument),
              ),
            ],
            selected: {source},
            onSelectionChanged: (value) => onSource(value.single),
          ),
        ),
        const SizedBox(height: CbSpace.s4),
        Text(
          source == ScanSource.passportPages
              ? l10n.scanStartPassportBody(AiScan.maxPages)
              : l10n.scanStartDocumentBody(AiScan.maxPages),
          style: context.cbText.body,
        ),
        const SizedBox(height: CbSpace.s4),
        CbNotice(message: l10n.scanStartDraftNote),
        if (freeTier) ...[
          const SizedBox(height: CbSpace.s3),
          CbNotice.warning(message: l10n.aiFreeTierWarning),
        ],
      ],
    );
  }
}

/// Writing a note: what to write, the field with an example and a counter,
/// that the keyboard's microphone can dictate it, and what AI does with it
/// (with the free tier's warning) before anything is sent. "Read" is in the
/// bottom bar, with what went wrong when sending failed.
class _NoteView extends StatelessWidget {
  const _NoteView({
    required this.formKey,
    required this.controller,
    required this.submitted,
    required this.freeTier,
    required this.validator,
    required this.onChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;

  /// "Read" was tapped: problems show as the text changes.
  final bool submitted;
  final bool freeTier;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: formKey,
      autovalidateMode: submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.noteIntro, style: context.cbText.body),
            const SizedBox(height: CbSpace.s4),
            CbTextField(
              key: const ValueKey('note'),
              label: l10n.noteLabel,
              hintText: l10n.noteHint,
              helperText: l10n.noteDictate,
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              minLines: 5,
              maxLines: 12,
              maxLength: AiScan.maxNoteLength,
              validator: validator,
              onChanged: onChanged,
            ),
            const SizedBox(height: CbSpace.s4),
            CbNotice(message: l10n.scanStartDraftNote),
            if (freeTier) ...[
              const SizedBox(height: CbSpace.s3),
              CbNotice.warning(message: l10n.noteFreeTierWarning),
            ],
          ],
        ),
      ),
    );
  }
}

/// The photos upload and the scan starts; or that failed, with "Try again"
/// (and the plan, when the month's AI photos are the reason).
class _StartingView extends StatelessWidget {
  const _StartingView({
    required this.start,
    required this.busy,
    required this.progress,
    required this.failure,
    required this.canRetry,
    required this.aiLimit,
    required this.onRetry,
    required this.onStartOver,
  });

  final _Start start;
  final bool busy;
  final (int, int)? progress;
  final String? failure;
  final bool canRetry;
  final bool aiLimit;
  final VoidCallback onRetry;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = this.progress;
    final failure = this.failure;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s12,
      ),
      children: [
        if (busy)
          progress != null
              ? UploadProgress(done: progress.$1, total: progress.$2)
              : _Working(text: l10n.scanStarting)
        else if (failure != null) ...[
          CbNotice.error(message: failure),
          if (aiLimit)
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: OpenPlanButton(),
            ),
          const SizedBox(height: CbSpace.s3),
          if (canRetry)
            FilledButton(onPressed: onRetry, child: Text(l10n.commonTryAgain)),
          const SizedBox(height: CbSpace.s2),
          OutlinedButton(
            onPressed: onStartOver,
            child: Text(l10n.scanStartOver),
          ),
        ],
        const SizedBox(height: CbSpace.s4),
        _Pages(
          picked: [for (final page in start.pages) ?page.picked],
          stored: start.files,
        ),
      ],
    );
  }
}

/// AI is reading the pages (or the note).
class _ReadingView extends StatelessWidget {
  const _ReadingView({
    required this.scan,
    required this.slow,
    required this.offline,
  });

  final AiScan scan;
  final bool slow;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final note = scan.isNote;
    final noteText = scan.text;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s4,
        CbSpace.s8,
        CbSpace.s4,
        CbSpace.s12,
      ),
      children: [
        const Center(
          child: SizedBox.square(
            dimension: CbSpace.s12,
            child: CircularProgressIndicator(),
          ),
        ),
        const SizedBox(height: CbSpace.s4),
        // Waiting in the queue usually takes a moment: both read as
        // "Reading the pages…" ("Reading the note…").
        Semantics(
          liveRegion: true,
          child: Text(
            scanStatusLabel(l10n, ScanStatus.processing, fromNote: note),
            style: text.title,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: CbSpace.s1),
        Text(
          note ? l10n.noteReadingBody : l10n.scanReadingBody,
          style: text.body.copyWith(color: context.cb.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: CbSpace.s6),
        if (offline) ...[
          CbNotice.warning(message: l10n.scanReadingOffline),
          const SizedBox(height: CbSpace.s3),
        ] else if (slow) ...[
          CbNotice.warning(message: l10n.scanReadingSlow),
          const SizedBox(height: CbSpace.s3),
        ],
        CbNotice(message: note ? l10n.noteReadingLeave : l10n.scanReadingLeave),
        const SizedBox(height: CbSpace.s4),
        if (!note)
          _Pages(stored: scan.pages)
        else if (noteText != null)
          NoteQuote(text: noteText),
      ],
    );
  }
}

/// A scan that is over: saved, discarded, failed or gone, with what to do.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.icon,
    required this.title,
    required this.actions,
    this.message,
    this.danger = false,
    this.pages = const [],
    this.noteText,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// A failure: the icon is `danger` red (with words, never alone).
  final bool danger;
  final List<Widget> actions;
  final List<StoredFile> pages;

  /// The note, for a note that failed.
  final String? noteText;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = context.cbText;
    final message = this.message;
    final noteText = this.noteText;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s4,
        CbSpace.s8,
        CbSpace.s4,
        CbSpace.s12,
      ),
      children: [
        Icon(icon, size: 32, color: danger ? cb.danger : cb.inkMuted),
        const SizedBox(height: CbSpace.s3),
        Semantics(
          liveRegion: true,
          child: Text(title, style: text.title, textAlign: TextAlign.center),
        ),
        if (message != null) ...[
          const SizedBox(height: CbSpace.s2),
          Text(message, style: text.body, textAlign: TextAlign.center),
        ],
        const SizedBox(height: CbSpace.s6),
        for (final action in actions) ...[
          action,
          const SizedBox(height: CbSpace.s2),
        ],
        if (pages.isNotEmpty) ...[
          const SizedBox(height: CbSpace.s4),
          _Pages(stored: pages),
        ],
        if (noteText != null) ...[
          const SizedBox(height: CbSpace.s4),
          NoteQuote(text: noteText),
        ],
      ],
    );
  }
}

/// A spinner with what is going on.
class _Working extends StatelessWidget {
  const _Working({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(CbSpace.s3),
        decoration: BoxDecoration(
          color: cb.sunken,
          borderRadius: BorderRadius.circular(CbRadius.md),
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: CbSpace.s5,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: CbSpace.s3),
            Expanded(child: Text(text, style: context.cbText.body)),
          ],
        ),
      ),
    );
  }
}

/// The scan's photos, three in a row: the ones on the server open full
/// screen; the ones on the phone show while they upload.
class _Pages extends StatelessWidget {
  const _Pages({this.picked = const [], this.stored = const []});

  final List<PickedMedia> picked;
  final List<StoredFile> stored;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (stored.isNotEmpty) {
      return PageGrid(
        pages: stored,
        onTap: (page) => openPageViewer(
          context,
          pages: stored,
          initialIndex: stored.indexOf(page),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: PageGrid.columns,
      childAspectRatio: PageGrid.tileAspectRatio,
      mainAxisSpacing: CbSpace.s2,
      crossAxisSpacing: CbSpace.s2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < picked.length; i++)
          PickedMediaTile(
            media: picked[i],
            semanticLabel: l10n.pageNumber(i + 1),
          ),
      ],
    );
  }
}
