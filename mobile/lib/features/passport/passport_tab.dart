import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/cb_status_tag.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../ai/ai_repository.dart';
import '../ai/widgets/scan_entry.dart';
import '../care/care_repository.dart';
import '../documents/document.dart';
import '../documents/documents_repository.dart';
import '../files/files_repository.dart';
import '../files/media_picker.dart';
import '../files/open_pdf.dart';
import '../files/page_viewer_screen.dart';
import '../files/stored_file.dart';
import '../files/widgets/media_sheet.dart';
import '../files/widgets/page_grid.dart';
import '../files/widgets/upload_progress.dart';
import '../household/current_household.dart';
import '../pets/identifier_rules.dart';
import '../pets/pet.dart';
import '../pets/pet_labels.dart';
import 'passport.dart';
import 'passport_health_sections.dart';
import 'passport_labels.dart';
import 'passport_pages.dart';
import 'passport_repository.dart';

/// The Passport tab: the disclaimer, the AI scan (when the server has AI)
/// and scans to continue, the passport header, the pet's chips and
/// tattoos, the photographed pages of the paper passport, and the health
/// sections V–X built from the care records.
class PassportTab extends ConsumerWidget {
  const PassportTab({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Helpers read the passport; scans and changes are for the others.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(passportProvider(pet.id));
        ref.invalidate(petDocumentsProvider(pet.id));
        ref.invalidate(passportRecordsProvider(pet.id));
        ref.invalidate(petScansProvider(pet.id));
        ref.invalidate(aiStatusProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s12,
        ),
        children: [
          CbNotice(message: l10n.passportDisclaimer),
          if (canEdit) ScanEntry(petId: pet.id),
          const SizedBox(height: CbSpace.s6),
          _PassportHeader(petId: pet.id),
          const SizedBox(height: CbSpace.s6),
          _Identification(pet: pet),
          const SizedBox(height: CbSpace.s6),
          _PassportPages(petId: pet.id),
          const SizedBox(height: CbSpace.s6),
          PassportHealthSections(pet: pet),
        ],
      ),
    );
  }
}

/// Model, number, country, issue date, issuing vet, owners and notes.
class _PassportHeader extends ConsumerWidget {
  const _PassportHeader({required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final passport = ref.watch(passportProvider(petId));
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    final value = passport.value;
    final Widget content;
    if (value != null) {
      content = value.isSaved
          ? _PassportDetails(passport: value)
          : Text(
              canEdit ? l10n.passportEmpty : l10n.passportEmptyHelper,
              style: context.cbText.body.copyWith(color: context.cb.inkMuted),
            );
    } else if (passport.hasError) {
      content = CbErrorState(
        message: errorMessageFor(passport.error!, l10n),
        traceId: traceIdOf(passport.error!),
        onRetry: () => ref.invalidate(passportProvider(petId)),
      );
    } else {
      content = const CbLoadingState();
    }

    return CbSection(
      title: l10n.passportTitle,
      action: value == null || !canEdit
          ? null
          : OutlinedButton.icon(
              key: const ValueKey('editPassport'),
              onPressed: () => context.push(AppRoutes.editPassport(petId)),
              icon: Icon(
                value.isSaved ? Symbols.edit_rounded : Symbols.add_rounded,
              ),
              label: Text(value.isSaved ? l10n.commonEdit : l10n.passportAdd),
            ),
      child: CbCard(child: content),
    );
  }
}

class _PassportDetails extends StatelessWidget {
  const _PassportDetails({required this.passport});

  final Passport passport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final model = passport.model;
    final issuedOn = passport.issuedOn;
    final issuer = passport.issuer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model != null)
          CbDetailRow(
            label: l10n.passportModelLabel,
            value: passportModelLabel(l10n, model),
          ),
        if (passport.number != null)
          CbDetailRow(
            label: l10n.passportNumberLabel,
            value: passport.number!,
            monospace: true,
          ),
        if (passport.issuingCountry != null)
          CbDetailRow(
            label: l10n.passportCountryLabel,
            value: passport.issuingCountry!,
          ),
        if (issuedOn != null)
          CbDetailRow(
            label: l10n.passportIssuedOnLabel,
            value: l10n.dateMedium(issuedOn),
          ),
        if (issuer != null && !issuer.isEmpty)
          CbDetailRow(
            label: l10n.passportIssuerTitle,
            value: contactLines(issuer),
          ),
        for (var i = 0; i < passport.owners.length; i++)
          CbDetailRow(
            label: passport.owners.length == 1
                ? l10n.passportOwnerTitle
                : l10n.passportOwnerNumbered(i + 1),
            value: contactLines(passport.owners[i]),
          ),
        if (passport.notes != null)
          CbDetailRow(label: l10n.passportNotesLabel, value: passport.notes!),
      ],
    );
  }
}

/// The pet's microchips and tattoos; they are edited in the pet form.
class _Identification extends ConsumerWidget {
  const _Identification({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    return CbSection(
      title: l10n.identifiersTitle,
      action: ref.watch(householdPermissionsProvider).canEdit
          ? OutlinedButton.icon(
              key: const ValueKey('editIdentifiers'),
              onPressed: () => context.push(AppRoutes.editPet(pet.id)),
              icon: Icon(
                pet.identifiers.isEmpty
                    ? Symbols.add_rounded
                    : Symbols.edit_rounded,
              ),
              label: Text(
                pet.identifiers.isEmpty ? l10n.commonAdd : l10n.commonEdit,
              ),
            )
          : null,
      child: CbCard(
        child: pet.identifiers.isEmpty
            ? Text(
                l10n.identifiersEmpty,
                style: text.body.copyWith(color: cb.inkMuted),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final identifier in pet.identifiers)
                    _IdentifierRow(identifier: identifier),
                ],
              ),
      ),
    );
  }
}

class _IdentifierRow extends StatelessWidget {
  const _IdentifierRow({required this.identifier});

  final PetIdentifier identifier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final appliedOn = identifier.appliedOn;
    final location = identifier.location;
    final details = [
      if (appliedOn != null)
        identifier.type == IdentifierType.tattoo
            ? l10n.identifierTattooAppliedOn(appliedOn)
            : l10n.identifierChipImplantedOn(appliedOn),
      ?location,
    ];
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CbSpace.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              identifierTypeLabel(l10n, identifier.type),
              style: text.caption.copyWith(color: cb.inkMuted),
            ),
            const SizedBox(height: CbSpace.s1),
            Text(
              IdentifierRules.display(identifier.type, identifier.code),
              style: text.code,
            ),
            if (details.isNotEmpty)
              Text(
                details.join(' · '),
                style: text.bodySm.copyWith(color: cb.inkMuted),
              ),
            if (identifier.type == IdentifierType.legacyChip)
              Padding(
                padding: const EdgeInsets.only(top: CbSpace.s1),
                child: CbStatusTag.soon(
                  l10n.identifierLegacyHint,
                  icon: Symbols.info_rounded,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The grid of photographed passport pages, with "Add pages".
class _PassportPages extends ConsumerStatefulWidget {
  const _PassportPages({required this.petId});

  final String petId;

  @override
  ConsumerState<_PassportPages> createState() => _PassportPagesState();
}

class _PassportPagesState extends ConsumerState<_PassportPages> {
  /// While uploading: how many files are done out of how many.
  (int, int)? _progress;
  String? _failure;

  /// Pages picked whose upload failed: "Upload again" sends them once more,
  /// with no new scan or photo needed.
  List<PickedMedia>? _unsent;

  /// Pages uploaded but maybe not added (the answer may have got lost):
  /// "Upload again" adds them, skipping those already there.
  List<StoredFile>? _unadded;

  Future<void> _addPages() async {
    final picked = await pickPages(context, ref.read(mediaPickerProvider));
    if (picked.isEmpty || !mounted) return;
    await _upload(picked);
  }

  Future<void> _uploadAgain() => _unadded != null
      ? _upload(const [], uploaded: _unadded)
      : _upload(_unsent ?? const []);

  /// Uploads [picked] and adds the pages; or, when [uploaded] is given, only
  /// adds those.
  Future<void> _upload(
    List<PickedMedia> picked, {
    List<StoredFile>? uploaded,
  }) async {
    // Everything is read before the first await: the user may switch tabs
    // during the upload, which disposes this widget (and its ref) while the
    // upload goes on.
    final container = ProviderScope.containerOf(context, listen: false);
    final petId = widget.petId;
    final files = ref.read(filesRepositoryProvider);
    final repository = ref.read(documentsRepositoryProvider);
    final l10n = context.l10n;

    final total = uploaded?.length ?? picked.length;
    setState(() {
      _progress = (uploaded == null ? 0 : total, total);
      _failure = null;
      _unsent = null;
      _unadded = null;
    });
    var uploadedFiles = uploaded;
    try {
      final toAdd =
          uploadedFiles ??
          await uploadAll(
            files,
            picked,
            onProgress: (done) {
              if (mounted) setState(() => _progress = (done, total));
            },
          );
      uploadedFiles = toAdd;
      await addPassportPages(repository, petId: petId, uploaded: toAdd);
    } catch (error) {
      debugPrint('Adding passport pages failed: $error');
      if (mounted) {
        setState(() {
          _failure = errorMessageFor(error, l10n);
          if (uploadedFiles == null) {
            _unsent = picked;
          } else {
            _unadded = uploadedFiles;
          }
        });
      }
    } finally {
      // Refreshes the grid and the Documents tab, even if this widget is gone.
      container.invalidate(petDocumentsProvider(petId));
      if (mounted) setState(() => _progress = null);
    }
  }

  void _openPage(List<PetDocument> documents, StoredFile page) {
    if (page.isPdf) {
      openPdf(context, ref, page);
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = ref.read(documentsRepositoryProvider);
    final canEdit = ref.read(householdPermissionsProvider).canEdit;
    final petId = widget.petId;
    // A page never moves to another document, so this map stays right
    // while the viewer is open.
    final owners = passportPageOwners(documents);
    final photos = [
      for (final p in passportPages(documents))
        if (!p.isPdf) p,
    ];
    openPageViewer(
      context,
      pages: photos,
      initialIndex: photos.indexOf(page),
      // Helpers only look at the pages.
      onDelete: !canEdit
          ? null
          : (photo) async {
              final documentId = owners[photo.id];
              if (documentId != null) {
                await repository.removePage(documentId, photo.id);
              }
              container.invalidate(petDocumentsProvider(petId));
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final documents = ref.watch(petDocumentsProvider(widget.petId));
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    final value = documents.value;
    final progress = _progress;
    final failure = _failure;

    final Widget content;
    // A failed reload shows the error, not the old pages: a page added just
    // before would be missing, and the user might add it again.
    if (documents.hasError && !documents.isLoading) {
      content = CbErrorState(
        message: errorMessageFor(documents.error!, l10n),
        traceId: traceIdOf(documents.error!),
        onRetry: () => ref.invalidate(petDocumentsProvider(widget.petId)),
      );
    } else if (value != null) {
      final pages = passportPages(value);
      content = pages.isEmpty
          ? Text(
              canEdit ? l10n.passportPagesEmpty : l10n.passportPagesEmptyHelper,
              style: context.cbText.body.copyWith(color: context.cb.inkMuted),
            )
          : PageGrid(pages: pages, onTap: (page) => _openPage(value, page));
    } else {
      content = const CbLoadingState();
    }

    return CbSection(
      title: l10n.passportPagesTitle,
      action: canEdit
          ? OutlinedButton.icon(
              key: const ValueKey('addPages'),
              onPressed: progress != null ? null : _addPages,
              icon: const Icon(Symbols.add_a_photo_rounded),
              label: Text(l10n.passportPagesAdd),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress != null) ...[
            UploadProgress(done: progress.$1, total: progress.$2),
            const SizedBox(height: CbSpace.s3),
          ],
          if (failure != null) ...[
            CbNotice.error(message: failure),
            if (_unsent != null || _unadded != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  onPressed: progress != null ? null : _uploadAgain,
                  icon: const Icon(Symbols.refresh_rounded),
                  label: Text(l10n.passportPagesRetry),
                ),
              ),
            const SizedBox(height: CbSpace.s3),
          ],
          content,
        ],
      ),
    );
  }
}
