import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/barcode_scanner_page.dart';
import '../../theme/collarbell_theme.dart';
import '../ai/ai_repository.dart';
import '../files/media_picker.dart';
import '../files/stored_file.dart';
import '../files/widgets/media_sheet.dart';
import 'identifier_rules.dart';
import 'pet.dart';
import 'widgets/identifier_editor.dart';

/// What the chip scanner gives the pet form.
sealed class ChipScan {
  const ChipScan();
}

/// A microchip number from a barcode: the camera's, or one the phone found
/// in a photo.
@immutable
class ChipBarcode extends ChipScan {
  const ChipBarcode(this.type, this.code);

  final IdentifierType type;

  /// Normalised: digits (or 0–9 and A–F) only.
  final String code;

  /// The same number from two barcodes in sight is one choice, not two.
  @override
  bool operator ==(Object other) =>
      other is ChipBarcode && other.type == type && other.code == code;

  @override
  int get hashCode => Object.hash(type, code);
}

/// A photo of the sticker or the passport page in which the phone found no
/// chip barcode: AI reads it. The form deletes it from the phone when done.
class ChipPhoto extends ChipScan {
  const ChipPhoto(this.photo);

  final PickedMedia photo;
}

/// Reads a microchip number off the sticker in a pet passport. Tests put in
/// a fake that gives a result at once.
abstract interface class ChipReader {
  /// What was read, or null when the user closes the scanner: the number
  /// is typed in the form, as before.
  Future<ChipScan?> read(BuildContext context);
}

final chipReaderProvider = Provider<ChipReader>(
  (ref) => CameraChipReader(ref.watch(mediaPickerProvider)),
);

/// [ChipReader] with the phone's camera (ML Kit on Android, Vision on
/// iPhone), and "From a photo": a photo from the camera or the gallery, e.g.
/// of the passport page someone sent in a messenger. The phone looks for the
/// barcode in it first; a photo without one goes back to the form for AI.
class CameraChipReader implements ChipReader {
  const CameraChipReader(this._picker);

  final MediaPicker _picker;

  /// The codes chip stickers carry, and no product codes (EAN, UPC): a
  /// pack's barcode isn't taken for a chip. Android reads Interleaved 2 of 5
  /// of any length as itf14; an iPhone only ITF-14 there, the rest as
  /// itf2of5.
  static const formats = [
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.itf14,
    BarcodeFormat.itf2of5,
    BarcodeFormat.codabar,
    BarcodeFormat.dataMatrix,
    BarcodeFormat.qrCode,
  ];

  /// The microchip number in a scanned code, or null when it isn't a
  /// chip's.
  static ChipBarcode? _decode(String scanned) =>
      switch (IdentifierRules.chipFromBarcode(scanned)) {
        (:final type, :final code) => ChipBarcode(type, code),
        null => null,
      };

  @override
  Future<ChipScan?> read(BuildContext context) {
    final l10n = context.l10n;
    return showBarcodeScanner(
      context,
      BarcodeScannerPage<ChipScan>(
        title: l10n.chipScanTitle,
        hint: l10n.chipScanHint,
        cameraUnavailable: l10n.chipScanCameraUnavailable,
        wrongCode: l10n.chipScanNotChip,
        formats: formats,
        decode: (code, _) => _decode(code),
        choose: _pick,
        actions: (context, session) => [
          _FromPhotoButton(onPressed: () => _fromPhoto(context, session)),
        ],
      ),
    );
  }

  /// Two different chip numbers in sight (or on the photo): the user picks
  /// the one of this card.
  static Future<ChipScan?> _pick(
    BuildContext context,
    List<ChipScan> found,
  ) async {
    final picked = await pickIdentifierReading(
      context,
      [
        for (final chip in found.whereType<ChipBarcode>())
          IdentifierReading(
            type: chip.type,
            code: chip.code,
            rawCode: chip.code,
          ),
      ],
      title: context.l10n.chipScanPickFound,
      otherCodes: const [],
    );
    return picked == null ? null : ChipBarcode(picked.type, picked.code);
  }

  /// A photo instead of the live camera: the phone's own barcode reading
  /// first, AI (in the form) only when it finds none.
  Future<void> _fromPhoto(
    BuildContext context,
    ScannerSession<ChipScan> session,
  ) async {
    await session.pause();
    if (!context.mounted) return;
    final action = await showMediaActionSheet(
      context,
      actions: const [MediaAction.camera, MediaAction.library],
    );
    PickedMedia? photo;
    try {
      photo = switch (action) {
        MediaAction.camera => await _picker.takePhoto(),
        MediaAction.library => await _picker.pickPhoto(),
        _ => null,
      };
    } catch (error) {
      debugPrint('Picking a photo of the chip failed: $error');
      if (context.mounted) showPickerError(context);
    }
    if (photo == null) {
      await session.resume();
      return;
    }

    final found = await session.readPhoto(photo.path);
    // No barcode the phone can read: AI reads the photo, in the form. A
    // passport page is personal: when it goes nowhere (the barcode says it
    // all, or the user left meanwhile), it doesn't stay on the phone.
    if (found.isEmpty && session.finish(ChipPhoto(photo))) return;
    await _picker.deletePicked([photo]);
    if (found.isEmpty) return;
    final chip = await session.pickOne(found);
    if (chip == null || !session.finish(chip)) await session.resume();
  }
}

/// "From a photo", with a word about where such a photo may go.
class _FromPhotoButton extends ConsumerWidget {
  const _FromPhotoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final freeTier = ref.watch(aiStatusProvider).value?.freeTier ?? false;
    return Column(
      children: [
        FilledButton.tonalIcon(
          key: const ValueKey('chipFromPhoto'),
          onPressed: onPressed,
          icon: const Icon(Symbols.image_rounded),
          label: Text(l10n.chipScanFromPhoto),
        ),
        if (freeTier) ...[
          const SizedBox(height: CbSpace.s2),
          Text(
            l10n.chipScanFreeTier,
            textAlign: TextAlign.center,
            style: context.cbText.caption.copyWith(color: Colors.white),
          ),
        ],
      ],
    );
  }
}
