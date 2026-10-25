import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../files/widgets/stored_file_image.dart';
import '../household/current_household.dart';
import '../pets/pet.dart';
import 'document.dart';
import 'document_labels.dart';
import 'documents_repository.dart';

/// The Documents tab: every document of the pet, newest first, passport
/// pages included.
class DocumentsTab extends ConsumerWidget {
  const DocumentsTab({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final documents = ref.watch(petDocumentsProvider(pet.id));
    final value = documents.value;
    // Helpers read the documents but don't add them.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    Widget add({required bool filled}) {
      void onPressed() => context.push(AppRoutes.newDocument(pet.id));
      const icon = Icon(Symbols.add_rounded);
      final label = Text(l10n.documentsAdd);
      return filled
          ? FilledButton.icon(
              key: const ValueKey('addDocument'),
              onPressed: onPressed,
              icon: icon,
              label: label,
            )
          : OutlinedButton.icon(
              key: const ValueKey('addDocument'),
              onPressed: onPressed,
              icon: icon,
              label: label,
            );
    }

    final Widget content;
    // A failed reload shows the error, not the old list, which may miss
    // a document just added.
    if (documents.hasError && !documents.isLoading) {
      content = CbErrorState(
        message: errorMessageFor(documents.error!, l10n),
        traceId: traceIdOf(documents.error!),
        onRetry: () => ref.invalidate(petDocumentsProvider(pet.id)),
      );
    } else if (value != null) {
      content = value.isEmpty
          ? Column(
              children: [
                CbEmptyState(
                  icon: Symbols.description_rounded,
                  title: l10n.documentsEmptyTitle,
                  message: l10n.documentsEmptyBody,
                ),
                // The tab's main action, while there is nothing else.
                if (canEdit) add(filled: true),
              ],
            )
          : CbCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < value.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        indent:
                            CbSpace.s4 + DocumentRow.thumbnailSize + CbSpace.s3,
                      ),
                    DocumentRow(
                      document: value[i],
                      onTap: () =>
                          context.push(AppRoutes.document(pet.id, value[i].id)),
                    ),
                  ],
                ],
              ),
            );
    } else {
      content = const CbLoadingState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(petDocumentsProvider(pet.id));
        try {
          await ref.read(petDocumentsProvider(pet.id).future);
        } catch (_) {
          // The error is shown by the error state.
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s12,
        ),
        children: [
          // No documents yet: the button is under the empty state.
          if (canEdit && !showsEmptyList(documents)) ...[
            Align(alignment: Alignment.centerLeft, child: add(filled: false)),
            const SizedBox(height: CbSpace.s4),
          ],
          content,
        ],
      ),
    );
  }
}

/// One document: the first page's thumbnail (or a PDF icon), the title or
/// type, and the type, date and number of pages.
class DocumentRow extends StatelessWidget {
  const DocumentRow({super.key, required this.document, this.onTap});

  final PetDocument document;
  final VoidCallback? onTap;

  /// Big enough to recognise a page.
  static const thumbnailSize = 52.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final firstPage = document.pages.isEmpty ? null : document.pages.first;
    final hasTitle = document.title?.trim().isNotEmpty ?? false;
    final details = [
      // Without a title, the type is already the row's title.
      if (hasTitle) documentTypeLabel(l10n, document.type),
      l10n.dateMedium(document.documentDate ?? document.createdAt.toLocal()),
      l10n.documentPageCount(document.pages.length),
    ];

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CbSpace.s4,
            vertical: CbSpace.s3,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: thumbnailSize,
                child: firstPage == null
                    ? FilePlaceholder(icon: documentTypeIcon(document.type))
                    : PageTile(file: firstPage),
              ),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      documentTitle(l10n, document),
                      style: text.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: CbSpace.s1),
                    Row(
                      children: [
                        Icon(
                          documentTypeIcon(document.type),
                          size: text.bodySm.fontSize,
                          color: cb.inkMuted,
                        ),
                        const SizedBox(width: CbSpace.s1),
                        Expanded(
                          child: Text(
                            // Lines break between the parts, never inside
                            // "Oct 1, 2026" or "2 pages".
                            [
                              for (final part in details)
                                part.replaceAll(' ', '\u00A0'),
                            ].join(' · '),
                            style: text.bodySm.copyWith(color: cb.inkMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
