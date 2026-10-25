import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/barcode_scanner_page.dart';

/// Reads a product's barcode with the camera. Tests put in a fake that
/// gives a code at once.
abstract interface class BarcodeReader {
  /// The scanned code (digits, or a medicine's GS1 DataMatrix), or null
  /// when the user closes the scanner.
  Future<String?> read(BuildContext context);
}

final barcodeReaderProvider = Provider<BarcodeReader>(
  (ref) => const CameraBarcodeReader(),
);

/// [BarcodeReader] with the phone's camera (ML Kit on Android, Vision on
/// iPhone). The digits can also be typed when the camera can't read them.
class CameraBarcodeReader implements BarcodeReader {
  const CameraBarcodeReader();

  /// Product codes only: the scanner is quicker, and a QR code of a shop
  /// isn't taken for a product.
  static const formats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.dataMatrix,
    BarcodeFormat.code128,
  ];

  @override
  Future<String?> read(BuildContext context) {
    final l10n = context.l10n;
    return showBarcodeScanner(
      context,
      BarcodeScannerPage<String>(
        title: l10n.barcodeScanTitle,
        hint: l10n.barcodeScanHint,
        cameraUnavailable: l10n.barcodeCameraUnavailable,
        formats: formats,
        decode: (code, format) =>
            format == BarcodeFormat.upcE ? expandUpcE(code) : code,
        actions: (context, session) => [
          FilledButton.tonal(
            key: const ValueKey('typeCode'),
            onPressed: () => _type(context, session),
            child: Text(context.l10n.barcodeType),
          ),
        ],
      ),
    );
  }

  /// The camera rests while the digits are typed: a code it saw meanwhile
  /// would close the page under the dialog.
  static Future<void> _type(
    BuildContext context,
    ScannerSession<String> session,
  ) async {
    await session.pause();
    if (!context.mounted) return;
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _TypeCodeDialog(),
    );
    if (code != null) {
      session.finish(code);
      return;
    }
    await session.resume();
  }
}

/// The digits a UPC-E stands for: its UPC-A (spec: one product, one code).
/// Small American packs carry UPC-E; the server knows them as UPC-A.
String expandUpcE(String code) {
  if (code.length != 8 || int.tryParse(code) == null) return code;
  final n = code[0];
  final s = code.substring(1, 7);
  final check = code[7];
  final middle = switch (s[5]) {
    '0' || '1' || '2' => '${s.substring(0, 2)}${s[5]}0000${s.substring(2, 5)}',
    '3' => '${s.substring(0, 3)}00000${s.substring(3, 5)}',
    '4' => '${s.substring(0, 4)}00000${s[4]}',
    _ => '${s.substring(0, 5)}0000${s[5]}',
  };
  return '$n$middle$check';
}

/// The digits under the barcode, typed by hand.
class _TypeCodeDialog extends StatefulWidget {
  const _TypeCodeDialog();

  @override
  State<_TypeCodeDialog> createState() => _TypeCodeDialogState();
}

class _TypeCodeDialogState extends State<_TypeCodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^\d{8,14}$').hasMatch(_code.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.barcodeType),
      content: TextField(
        key: const ValueKey('code'),
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(hintText: l10n.barcodeTypeHint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(_code.text.trim())
              : null,
          child: Text(l10n.barcodeFind),
        ),
      ],
    );
  }
}
