import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/offline_copy.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../files/files_repository.dart';
import '../files/media_picker.dart';
import '../files/stored_file.dart';
import '../files/widgets/media_sheet.dart';
import '../files/widgets/page_grid.dart';
import '../files/widgets/stored_file_image.dart';
import '../household/current_household.dart';
import 'document.dart';
import 'document_labels.dart';
import 'documents_repository.dart';

/// Adds a document to the pet [petId], or edits the document [documentId].
class DocumentFormScreen extends ConsumerWidget {
  const DocumentFormScreen({super.key, required this.petId, this.documentId});

  final String petId;

  /// Null when adding a document.
  final String? documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentId = this.documentId;
    if (documentId == null) return _DocumentForm(petId: petId, document: null);

    final document = ref.watch(documentProvider(documentId));
    final value = document.value;
    if (value != null) return _DocumentForm(petId: petId, document: value);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.documentFormEditTitle)),
      body: document.hasError
          ? Center(
              child: CbErrorState(
                message: errorMessageFor(document.error!, context.l10n),
                traceId: traceIdOf(document.error!),
                onRetry: () => ref.invalidate(documentProvider(documentId)),
              ),
            )
          : const CbLoadingState.form(),
    );
  }
}

/// A page in the form. [file] is set once the page is uploaded, [attached]
/// once it belongs to the saved document. A retry after a failed save
/// reuses both: nothing is uploaded or attached twice.
class _DraftPage {
  _DraftPage.saved(StoredFile this.file) : picked = null, attached = true;
  _DraftPage.picked(PickedMedia this.picked) : attached = false;

  /// The file on the phone, for pages added in this form.
  final PickedMedia? picked;
  StoredFile? file;
  bool attached;
}

class _DocumentForm extends ConsumerStatefulWidget {
  const _DocumentForm({required this.petId, required this.document});

  final String petId;
  final PetDocument? document;

  @override
  ConsumerState<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends ConsumerState<_DocumentForm>
    with OpenedInHousehold {
  // The server's limits.
  static const _maxTitle = 200;
  static const _maxNotes = 2000;

  final _formKey = GlobalKey<FormState>();
  final _pagesKey = GlobalKey();
  late var _type = widget.document?.type ?? DocumentType.other;
  late final _title = TextEditingController(text: widget.document?.title);
  late var _date = widget.document?.documentDate;
  late final _notes = TextEditingController(text: widget.document?.notes);
  late final _pages = [
    for (final page in widget.document?.pages ?? const <StoredFile>[])
      _DraftPage.saved(page),
  ];

  /// Saved pages the user removed; they are deleted one by one on save.
  /// Pages the form doesn't know about (added elsewhere meanwhile) are never
  /// touched.
  final _removedFileIds = <String>{};

  var _submitted = false;
  var _busy = false;

  /// While uploading: how many new pages are done out of how many.
  (int, int)? _progress;
  var _serverErrors = <String, List<String>>{};

  /// Shown above the Save button.
  String? _failure;

  bool get _isEdit => widget.document != null;

  /// Everything the form holds, to tell whether leaving loses anything.
  List<Object?> _values() => [
    _type,
    _date,
    for (final field in [_title, _notes]) field.text,
    ..._pages,
    _pages.length,
    _removedFileIds.length,
  ];

  /// What the form opened with.
  late final List<Object?> _opened;

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = widget.document != null && openedFromCopy(ref);
    _opened = _values();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _serverError(String field) => _serverErrors.containsKey(field)
      ? context.l10n.formServerFieldError
      : null;

  String? _maxLength(String? value, int max) =>
      (value ?? '').trim().length > max ? context.l10n.formTooLong(max) : null;

  /// Shown under the pages when they can't be saved as they are.
  String? get _pagesError {
    final l10n = context.l10n;
    if (_submitted && _pages.isEmpty) return l10n.documentPagesRequired;
    if (_pages.length > PetDocument.maxPages) {
      return l10n.documentPagesTooMany(PetDocument.maxPages);
    }
    return _serverError('fileIds');
  }

  static final _fieldKeys = RegExp(r'^(title|documentDate|notes|fileIds)$');

  /// Validates all fields and the pages, and scrolls to the first problem.
  bool _validateAndReveal() {
    final invalid = invalidFields(_formKey.currentState!);
    final pages = _pagesKey.currentContext;
    if (_pagesError != null && pages != null) invalid.add(pages);
    revealTopmost(invalid);
    return invalid.isEmpty;
  }

  Future<void> _addPages() async {
    final picked = await pickPages(
      context,
      ref.read(mediaPickerProvider),
      allowPdf: true,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _pages.addAll([for (final media in picked) _DraftPage.picked(media)]);
      _serverErrors.remove('fileIds');
    });
  }

  void _removePage(_DraftPage page) {
    setState(() {
      _pages.remove(page);
      final file = page.file;
      if (page.attached && file != null) _removedFileIds.add(file.id);
    });
  }

  Future<void> _save() async {
    if (_fromCopy) {
      setState(() => _failure = context.l10n.formOpenedOffline);
      return;
    }
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _submitted = true;
      _serverErrors = {};
      _failure = null;
    });
    if (!_validateAndReveal()) {
      setState(() => _failure = l10n.formCheckFields);
      return;
    }

    // Everything is read before the first await. Leaving the form is
    // blocked while it saves (PopScope), but the app can still close it,
    // e.g. on sign-out, and the save must finish all the same.
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final files = ref.read(filesRepositoryProvider);
    final repository = ref.read(documentsRepositoryProvider);
    String? clean(String text) => text.trim().isEmpty ? null : text.trim();
    final details = DocumentDetails(
      type: _type,
      title: clean(_title.text),
      documentDate: _date,
      notes: clean(_notes.text),
    );
    final toUpload = [
      for (final page in _pages)
        if (page.file == null) page,
    ];
    setState(() {
      _busy = true;
      _progress = toUpload.isEmpty ? null : (0, toUpload.length);
    });
    try {
      for (var i = 0; i < toUpload.length; i++) {
        toUpload[i].file = await files.upload(toUpload[i].picked!);
        if (mounted) setState(() => _progress = (i + 1, toUpload.length));
      }

      final document = widget.document;
      if (document == null) {
        await repository.createDocument(widget.petId, details, [
          for (final page in _pages) page.file!.id,
        ]);
      } else {
        await repository.updateDetails(document.id, details);
        // New pages before removals: removing first could delete the whole
        // document when the user replaced every page.
        final added = [
          for (final page in _pages)
            if (!page.attached) page,
        ];
        if (added.isNotEmpty) {
          await repository.addPages(document.id, [
            for (final page in added) page.file!.id,
          ]);
          for (final page in added) {
            page.attached = true;
          }
        }
        for (final fileId in [..._removedFileIds]) {
          await repository.removePage(document.id, fileId);
          _removedFileIds.remove(fileId);
        }
        container.invalidate(documentProvider(document.id));
      }
      container.invalidate(petDocumentsProvider(widget.petId));
      if (mounted) navigator.pop();
    } catch (error) {
      debugPrint('Saving the document failed: $error');
      // Part of the save may have gone through; the lists show what did.
      final document = widget.document;
      if (document != null) container.invalidate(documentProvider(document.id));
      container.invalidate(petDocumentsProvider(widget.petId));
      if (!mounted) return;
      final fieldErrors = fieldErrorsOf(error);
      final placed =
          fieldErrors.isNotEmpty &&
          fieldErrors.keys.every((key) => _fieldKeys.hasMatch(key));
      setState(() {
        _serverErrors = {...fieldErrors};
        _failure = placed ? l10n.formCheckFields : errorMessageFor(error, l10n);
      });
      if (placed) _validateAndReveal();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pagesError = _pagesError;
    final progress = _progress;
    const gap = SizedBox(height: CbSpace.s4);

    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened, _values()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEdit ? l10n.documentFormEditTitle : l10n.documentFormAddTitle,
          ),
        ),
        bottomNavigationBar: CbSaveBar(
          busy: _busy,
          error: _failure,
          busyLabel: progress == null
              ? null
              : l10n.uploadProgress(
                  progress.$1 < progress.$2 ? progress.$1 + 1 : progress.$2,
                  progress.$2,
                ),
          onSave: () => inOpenedHousehold(_save),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          // Not a lazy list: every field is built, so every field is checked.
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
                CbLabeled(
                  label: l10n.documentTypeLabel,
                  child: DropdownButtonFormField<DocumentType>(
                    icon: cbDropdownIcon,
                    initialValue: _type,
                    isExpanded: true,
                    // Body text, like the text fields (Material's default is bolder).
                    style: context.cbText.body.copyWith(color: context.cb.ink),
                    items: [
                      for (final type in DocumentType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(
                                documentTypeIcon(type),
                                color: context.cb.inkMuted,
                              ),
                              const SizedBox(width: CbSpace.s3),
                              Expanded(
                                child: Text(
                                  documentTypeLabel(l10n, type),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (type) {
                      if (type != null) setState(() => _type = type);
                    },
                  ),
                ),
                gap,
                CbTextField(
                  label: l10n.documentTitleLabel,
                  hintText: l10n.documentTitleHint,
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      _maxLength(value, _maxTitle) ?? _serverError('title'),
                ),
                gap,
                CbDateField(
                  label: l10n.documentDateLabel,
                  value: _date,
                  onChanged: (date) => setState(() => _date = date),
                  validator: (_) => _serverError('documentDate'),
                ),
                gap,
                CbTextField(
                  label: l10n.documentNotesLabel,
                  controller: _notes,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      _maxLength(value, _maxNotes) ?? _serverError('notes'),
                ),
                const SizedBox(height: CbSpace.s8),
                CbSection(
                  key: _pagesKey,
                  title: l10n.documentPagesTitle,
                  action: OutlinedButton.icon(
                    onPressed: _busy ? null : _addPages,
                    icon: const Icon(Symbols.add_a_photo_rounded),
                    label: Text(l10n.documentPagesAdd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_pages.isEmpty)
                        Text(
                          l10n.documentPagesEmpty,
                          style: context.cbText.body.copyWith(
                            color: context.cb.inkMuted,
                          ),
                        )
                      else
                        GridView.count(
                          crossAxisCount: PageGrid.columns,
                          childAspectRatio: PageGrid.tileAspectRatio,
                          mainAxisSpacing: CbSpace.s2,
                          crossAxisSpacing: CbSpace.s2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 0; i < _pages.length; i++)
                              _RemovablePage(
                                key: ObjectKey(_pages[i]),
                                page: _pages[i],
                                number: i + 1,
                                onRemove: _busy
                                    ? null
                                    : () => _removePage(_pages[i]),
                              ),
                          ],
                        ),
                      if (pagesError != null) ...[
                        const SizedBox(height: CbSpace.s2),
                        Text(
                          pagesError,
                          style: context.cbText.caption.copyWith(
                            color: context.cb.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A page tile with a remove button in its corner.
class _RemovablePage extends StatelessWidget {
  const _RemovablePage({
    super.key,
    required this.page,
    required this.number,
    required this.onRemove,
  });

  final _DraftPage page;

  /// The page number, counted from 1.
  final int number;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final picked = page.picked;
    final file = page.file;
    final cb = context.cb;
    final label = context.l10n.pageNumber(number);
    return Stack(
      fit: StackFit.expand,
      children: [
        // A page added in this form shows the file on the phone.
        if (picked != null)
          PickedMediaTile(media: picked, semanticLabel: label)
        else if (file != null)
          PageTile(file: file, semanticLabel: label),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            tooltip: context.l10n.pageRemove(number),
            onPressed: onRemove,
            style: IconButton.styleFrom(
              backgroundColor: cb.surface,
              foregroundColor: cb.ink,
            ),
            icon: const Icon(Symbols.close_rounded),
          ),
        ),
      ],
    );
  }
}
