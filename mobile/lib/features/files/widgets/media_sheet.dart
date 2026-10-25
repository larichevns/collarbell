import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../../../l10n/l10n.dart';
import '../../../theme/collarbell_theme.dart';
import '../media_picker.dart';
import '../stored_file.dart';

/// What the user can do in the "add a photo or page" sheet.
enum MediaAction { camera, library, pdf, remove }

/// A bottom sheet with the given actions; returns the chosen one, or null
/// when the user closes the sheet.
Future<MediaAction?> showMediaActionSheet(
  BuildContext context, {
  required List<MediaAction> actions,
}) {
  return showModalBottomSheet<MediaAction>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      final danger = context.cb.danger;
      Widget tile(MediaAction action) {
        final (icon, label) = switch (action) {
          MediaAction.camera => (
            Symbols.photo_camera_rounded,
            l10n.mediaTakePhoto,
          ),
          MediaAction.library => (
            Symbols.photo_library_rounded,
            l10n.mediaChooseFromLibrary,
          ),
          MediaAction.pdf => (
            Symbols.picture_as_pdf_rounded,
            l10n.mediaChoosePdf,
          ),
          MediaAction.remove => (Symbols.delete_rounded, l10n.mediaRemovePhoto),
        };
        final remove = action == MediaAction.remove;
        return ListTile(
          leading: Icon(icon, color: remove ? danger : null),
          title: Text(label, style: remove ? TextStyle(color: danger) : null),
          onTap: () => Navigator.of(context).pop(action),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: CbSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (final action in actions) tile(action)],
          ),
        ),
      );
    },
  );
}

/// Lets the user add document pages: photos from the camera one after
/// another (asking "add another page?" after each shot), several photos
/// from the library, or, when [allowPdf] is set, a PDF. Returns the picked
/// files; empty when the user cancels.
Future<List<PickedMedia>> pickPages(
  BuildContext context,
  MediaPicker picker, {
  bool allowPdf = false,
}) async {
  final action = await showMediaActionSheet(
    context,
    actions: [
      MediaAction.camera,
      MediaAction.library,
      if (allowPdf) MediaAction.pdf,
    ],
  );
  if (action == null || !context.mounted) return const [];

  final pages = <PickedMedia>[];
  try {
    switch (action) {
      case MediaAction.camera:
        while (true) {
          final photo = await picker.takePhoto();
          if (photo == null) break;
          pages.add(photo);
          if (!context.mounted || !await _askForAnotherPage(context)) break;
        }
      case MediaAction.library:
        pages.addAll(await picker.pickPhotos());
      case MediaAction.pdf:
        final pdf = await picker.pickPdf();
        if (pdf != null) pages.add(pdf);
      case MediaAction.remove:
        break;
    }
  } on PlatformException catch (error) {
    // No camera (simulator) or no access to the photos.
    debugPrint('Picking failed: $error');
    if (context.mounted) showPickerError(context);
  }
  return pages;
}

/// Tells the user the camera or library could not be opened.
void showPickerError(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.mediaPickerFailed)));
}

Future<bool> _askForAnotherPage(BuildContext context) async {
  final another = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.mediaPageAddedTitle),
        content: Text(l10n.mediaPageAddedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.mediaDone),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mediaAddAnotherPage),
          ),
        ],
      );
    },
  );
  return another ?? false;
}
