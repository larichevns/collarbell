import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import 'files_repository.dart';
import 'stored_file.dart';

/// Opens a PDF in the phone's viewer (Safari on iOS). The link in a list may
/// have expired, so it asks the API for a fresh one first.
Future<void> openPdf(
  BuildContext context,
  WidgetRef ref,
  StoredFile file,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final fresh = await ref.read(filesRepositoryProvider).getLink(file.id);
    final opened = await launchUrl(
      Uri.parse(fresh.url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.pdfOpenFailed)));
    }
  } catch (error) {
    debugPrint('Opening the PDF failed: $error');
    messenger.showSnackBar(
      SnackBar(content: Text(errorMessageFor(error, l10n))),
    );
  }
}
