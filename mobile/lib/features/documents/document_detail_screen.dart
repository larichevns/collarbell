import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../files/open_pdf.dart';
import '../files/page_viewer_screen.dart';
import '../files/stored_file.dart';
import '../files/widgets/page_grid.dart';
import '../household/current_household.dart';
import 'document.dart';
import 'document_labels.dart';
import 'documents_repository.dart';

/// One document: its pages and details, with Edit and Delete.
class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({
    super.key,
    required this.petId,
    required this.documentId,
  });

  final String petId;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final document = ref.watch(documentProvider(documentId));
    final value = document.value;
    if (value == null) {
      return Scaffold(
        appBar: AppBar(),
        body: document.hasError
            ? Center(
                child: CbErrorState(
                  message: errorMessageFor(document.error!, l10n),
                  traceId: traceIdOf(document.error!),
                  onRetry: () => ref.invalidate(documentProvider(documentId)),
                ),
              )
            : const CbLoadingState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          documentTitle(l10n, value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (ref.watch(householdPermissionsProvider).canEdit) ...[
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Symbols.edit_rounded),
              onPressed: () =>
                  context.push(AppRoutes.editDocument(petId, documentId)),
            ),
            PopupMenuButton<_DocumentAction>(
              tooltip: l10n.commonMoreActions,
              // ⋮ in Material Symbols, as every other icon.
              icon: const Icon(Symbols.more_vert_rounded),
              onSelected: (action) => switch (action) {
                _DocumentAction.delete => _delete(context, ref, value),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _DocumentAction.delete,
                  child: Row(
                    children: [
                      Icon(Symbols.delete_rounded, color: context.cb.danger),
                      const SizedBox(width: CbSpace.s3),
                      Text(
                        l10n.documentDelete,
                        style: TextStyle(color: context.cb.danger),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        // Pull to refresh: another phone may have changed the document.
        onRefresh: () async {
          try {
            ref.invalidate(documentProvider(documentId));
            await ref.read(documentProvider(documentId).future);
          } catch (error) {
            // The screen keeps what it shows: the snackbar says why.
            if (context.mounted) showRefreshFailed(context, error);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            CbSpace.s4,
            CbSpace.s4,
            CbSpace.s4,
            CbSpace.s12,
          ),
          children: [
            CbSection(
              title: l10n.documentPagesTitle,
              child: PageGrid(
                pages: value.pages,
                onTap: (page) => _openPage(context, ref, value.pages, page),
              ),
            ),
            const SizedBox(height: CbSpace.s6),
            CbSection(
              title: l10n.documentDetailsTitle,
              child: CbCard(child: _DocumentDetails(document: value)),
            ),
          ],
        ),
      ),
    );
  }

  /// Photos open in the viewer; PDFs open in the phone's PDF viewer.
  void _openPage(
    BuildContext context,
    WidgetRef ref,
    List<StoredFile> pages,
    StoredFile page,
  ) {
    if (page.isPdf) {
      openPdf(context, ref, page);
      return;
    }
    final photos = [
      for (final p in pages)
        if (!p.isPdf) p,
    ];
    openPageViewer(context, pages: photos, initialIndex: photos.indexOf(page));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PetDocument document,
  ) async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.documentDeleteTitle,
      message: l10n.documentDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !context.mounted) return;

    // Read before the request: the screen may be gone when it returns, and
    // its ref with it.
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = ref.read(documentsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await repository.deleteDocument(document.id);
      container.invalidate(petDocumentsProvider(petId));
      if (context.mounted) navigator.pop();
    } catch (error) {
      debugPrint('Deleting the document failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    }
  }
}

enum _DocumentAction { delete }

class _DocumentDetails extends StatelessWidget {
  const _DocumentDetails({required this.document});

  final PetDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = document.documentDate;
    final notes = document.notes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CbDetailRow(
          label: l10n.documentTypeLabel,
          value: documentTypeLabel(l10n, document.type),
        ),
        if (date != null)
          CbDetailRow(
            label: l10n.documentDateLabel,
            value: l10n.dateMedium(date),
          ),
        CbDetailRow(
          label: l10n.documentPagesTitle,
          value: l10n.documentPageCount(document.pages.length),
        ),
        CbDetailRow(
          label: l10n.documentAddedOnLabel,
          value: l10n.dateMedium(document.createdAt.toLocal()),
        ),
        if (notes != null)
          CbDetailRow(label: l10n.documentNotesLabel, value: notes),
      ],
    );
  }
}
