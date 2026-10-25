import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_section.dart';
import '../../../theme/collarbell_theme.dart';
import '../../files/files_repository.dart';
import '../../files/media_picker.dart';
import '../../files/stored_file.dart';
import '../../files/widgets/media_sheet.dart';
import '../../files/widgets/page_grid.dart';
import '../../files/widgets/stored_file_image.dart';
import '../care.dart';
import '../care_repository.dart';

/// A photo in the Done screen or the record form. [file] is set once the
/// photo is uploaded, [attached] once it belongs to the saved record. A
/// retry after a failed save reuses both: nothing is uploaded or attached
/// twice.
class DraftPhoto {
  DraftPhoto.saved(StoredFile this.file) : picked = null, attached = true;
  DraftPhoto.picked(PickedMedia this.picked) : attached = false;

  /// The file on the phone, for photos added in this form.
  final PickedMedia? picked;
  StoredFile? file;
  bool attached;
}

/// Lets the user take a photo or choose some from the library. Returns the
/// picked photos; empty when the user cancels.
Future<List<PickedMedia>> pickCarePhotos(
  BuildContext context,
  MediaPicker picker,
) async {
  final action = await showMediaActionSheet(
    context,
    actions: const [MediaAction.camera, MediaAction.library],
  );
  if (action == null || !context.mounted) return const [];
  try {
    if (action == MediaAction.camera) {
      final photo = await picker.takePhoto();
      return photo == null ? const [] : [photo];
    }
    return await picker.pickPhotos();
  } on PlatformException catch (error) {
    // No camera (simulator) or no access to the photos.
    debugPrint('Picking photos failed: $error');
    if (context.mounted) showPickerError(context);
    return const [];
  }
}

/// Uploads the photos that aren't uploaded yet, one after another.
/// [onProgress] gets how many are done out of how many.
Future<void> uploadNewPhotos(
  FilesRepository files,
  List<DraftPhoto> photos, {
  void Function(int done, int total)? onProgress,
}) async {
  final toUpload = [
    for (final photo in photos)
      if (photo.file == null) photo,
  ];
  for (var i = 0; i < toUpload.length; i++) {
    onProgress?.call(i, toUpload.length);
    toUpload[i].file = await files.upload(toUpload[i].picked!);
  }
}

/// Attaches the uploaded photos that aren't attached yet to the record
/// [recordId], one request per photo: the app never sends a list that
/// replaces the record's photos.
Future<void> attachNewPhotos(
  CareRepository care,
  String recordId,
  List<DraftPhoto> photos,
) async {
  for (final photo in photos) {
    if (photo.attached) continue;
    await care.addRecordFile(recordId, photo.file!.id);
    photo.attached = true;
  }
}

/// The photos of a record in a form: tiles with a remove button, and "Add
/// photos". Up to [CareRecord.maxFiles].
class PhotosField extends StatelessWidget {
  const PhotosField({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.canRemove,
    this.errorText,
    this.enabled = true,
  });

  final List<DraftPhoto> photos;
  final VoidCallback onAdd;
  final ValueChanged<DraftPhoto> onRemove;

  /// Which photos have a remove button; all of them when null.
  final bool Function(DraftPhoto photo)? canRemove;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final errorText = this.errorText;
    final canAdd = enabled && photos.length < CareRecord.maxFiles;
    return CbSection(
      title: l10n.carePhotosTitle,
      action: OutlinedButton.icon(
        onPressed: canAdd ? onAdd : null,
        icon: const Icon(Symbols.add_a_photo_rounded),
        label: Text(l10n.carePhotosAdd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photos.isEmpty)
            Text(
              l10n.carePhotosEmpty,
              style: context.cbText.body.copyWith(color: cb.inkMuted),
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
                for (var i = 0; i < photos.length; i++)
                  _RemovablePhoto(
                    key: ObjectKey(photos[i]),
                    photo: photos[i],
                    number: i + 1,
                    onRemove: enabled && (canRemove?.call(photos[i]) ?? true)
                        ? () => onRemove(photos[i])
                        : null,
                  ),
              ],
            ),
          if (errorText != null) ...[
            const SizedBox(height: CbSpace.s2),
            Text(
              errorText,
              style: context.cbText.caption.copyWith(color: cb.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// A photo tile with a remove button in its corner.
class _RemovablePhoto extends StatelessWidget {
  const _RemovablePhoto({
    super.key,
    required this.photo,
    required this.number,
    required this.onRemove,
  });

  final DraftPhoto photo;
  final int number;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final picked = photo.picked;
    final file = photo.file;
    final cb = context.cb;
    final l10n = context.l10n;
    final label = l10n.photoNumber(number);
    return Stack(
      fit: StackFit.expand,
      children: [
        // A photo added in this form shows the file on the phone.
        if (picked != null)
          PickedMediaTile(media: picked, semanticLabel: label)
        else if (file != null)
          PageTile(file: file, semanticLabel: label),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            tooltip: l10n.photoRemove(number),
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
