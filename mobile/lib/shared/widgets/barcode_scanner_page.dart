import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/l10n.dart';
import '../../theme/collarbell_theme.dart';
import 'cb_notice.dart';

/// What the buttons under a [BarcodeScannerPage]'s hint can do with it.
abstract interface class ScannerSession<T> {
  /// Stops the camera while a dialog, the photo library or the phone's own
  /// camera is open: a code it saw meanwhile would close the page under
  /// them.
  Future<void> pause();

  /// Starts the camera again after [pause].
  Future<void> resume();

  /// Closes the page with [result]. False when the page is closing already
  /// (the user left it): then [result] goes nowhere.
  bool finish(T result);

  /// The different codes the page takes in the photo at [path]. None when
  /// there are none, or the phone can't look for codes in photos (an iPhone
  /// simulator can't).
  Future<List<T>> readPhoto(String path);

  /// One of several different codes found at once: the one the user picks
  /// ([BarcodeScannerPage.choose]), or the first when the page has no
  /// choice to offer. Null when the user picks none.
  Future<T?> pickOne(List<T> found);
}

/// Opens [page] over the whole app, the tab bar included: a scanner left
/// open in another tab would keep the camera on.
Future<T?> showBarcodeScanner<T>(
  BuildContext context,
  BarcodeScannerPage<T> page,
) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<T>(fullscreenDialog: true, builder: (_) => page));

/// A camera that reads codes of [formats] (ML Kit on Android, Vision on
/// iPhone) and closes with what [decode] makes of the first one it takes.
/// [actions] are buttons under the [hint], e.g. "Type the digits".
class BarcodeScannerPage<T> extends StatefulWidget {
  const BarcodeScannerPage({
    super.key,
    required this.title,
    required this.hint,
    required this.cameraUnavailable,
    required this.formats,
    required this.decode,
    this.wrongCode,
    this.choose,
    this.actions,
  });

  final String title;

  /// Under the frame: what to point the camera at.
  final String hint;

  /// Instead of the picture when the camera can't be opened (no access).
  final String cameraUnavailable;

  /// Only these: the scanner is quicker, and other codes aren't taken by
  /// mistake.
  final List<BarcodeFormat> formats;

  /// The result for a code the camera saw, or null when this page doesn't
  /// take it: then [wrongCode] shows for a moment and scanning goes on.
  final T? Function(String code, BarcodeFormat format) decode;
  final String? wrongCode;

  /// Lets the user pick one when the camera sees several different codes at
  /// once (or a photo holds them); null when they pick none. Without it, the
  /// first is taken.
  final Future<T?> Function(BuildContext context, List<T> found)? choose;

  /// Buttons (and notes about them) under the hint.
  final List<Widget> Function(BuildContext context, ScannerSession<T> session)?
  actions;

  @override
  State<BarcodeScannerPage<T>> createState() => _BarcodeScannerPageState<T>();
}

class _BarcodeScannerPageState<T> extends State<BarcodeScannerPage<T>>
    implements ScannerSession<T> {
  late final _controller = MobileScannerController(formats: widget.formats);

  /// The page is closing: with a result, or because the user left it. The
  /// camera keeps seeing codes until it is gone, and they go nowhere.
  var _done = false;

  /// A button's dialog or picker is open: the camera rests.
  var _paused = false;

  /// The phone is looking for codes in a photo.
  var _readingPhoto = false;

  /// Shows [BarcodeScannerPage.wrongCode] instead of the hint until it
  /// fires.
  Timer? _wrongCode;

  @override
  void dispose() {
    _wrongCode?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// While this page's route is on top: not when it is closing, when a pop
  /// would close the screen under it instead.
  bool get _current =>
      mounted && !_done && (ModalRoute.of(context)?.isCurrent ?? false);

  void _detected(BarcodeCapture capture) {
    if (_done || _paused) return;
    final found = _decodeAll(capture.barcodes);
    if (found.isEmpty) {
      if (capture.barcodes.any((code) => code.rawValue?.isNotEmpty ?? false)) {
        _showWrongCode();
      }
      return;
    }
    HapticFeedback.mediumImpact();
    if (found.length == 1 || widget.choose == null) {
      finish(found.first);
    } else {
      _pickAndFinish(found);
    }
  }

  /// What [BarcodeScannerPage.decode] makes of [barcodes], each result once.
  List<T> _decodeAll(List<Barcode> barcodes) {
    final found = <T>[];
    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final result = widget.decode(raw, barcode.format);
      if (result != null && !found.contains(result)) found.add(result);
    }
    return found;
  }

  /// Several different codes in sight: the camera rests while the user picks.
  Future<void> _pickAndFinish(List<T> found) async {
    await pause();
    final picked = await pickOne(found);
    if (picked == null || !finish(picked)) await resume();
  }

  /// The camera sees the same code several times a second: each sighting
  /// keeps the message up a little longer.
  void _showWrongCode() {
    if (widget.wrongCode == null) return;
    final showing = _wrongCode?.isActive ?? false;
    _wrongCode?.cancel();
    _wrongCode = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() {});
    });
    if (!showing) setState(() {});
  }

  @override
  Future<void> pause() async {
    if (!mounted || _done) return;
    setState(() => _paused = true);
    await _controller.stop();
  }

  @override
  Future<void> resume() async {
    if (!mounted || _done) return;
    setState(() => _paused = false);
    await _controller.start();
  }

  @override
  bool finish(T result) {
    if (!_current) return false;
    _done = true;
    Navigator.of(context).pop(result);
    return true;
  }

  @override
  Future<List<T>> readPhoto(String path) async {
    setState(() => _readingPhoto = true);
    try {
      final capture = await _controller.analyzeImage(
        path,
        formats: widget.formats,
      );
      return _decodeAll(capture?.barcodes ?? const []);
    } catch (error) {
      // Not on an iPhone simulator; a photo the phone can't open has no
      // code for it either.
      debugPrint('Looking for a code in the photo failed: $error');
      return const [];
    } finally {
      if (mounted) setState(() => _readingPhoto = false);
    }
  }

  @override
  Future<T?> pickOne(List<T> found) async {
    final choose = widget.choose;
    if (found.length == 1 || choose == null) return found.first;
    if (!_current) return null;
    return choose(context, found);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final wrongCode = widget.wrongCode;
    final actions = widget.actions?.call(context, this) ?? const <Widget>[];
    // Any way out (the close button, Back) ends the scanning at once.
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _done = true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: l10n.barcodeTorch,
              onPressed: _controller.toggleTorch,
              icon: const Icon(Symbols.flashlight_on_rounded),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _detected,
              errorBuilder: (context, error) => ColoredBox(
                color: context.cb.paper,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(CbSpace.s6),
                    child: Text(
                      widget.cameraUnavailable,
                      textAlign: TextAlign.center,
                      style: text.body,
                    ),
                  ),
                ),
              ),
            ),
            // Where to hold the barcode.
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 280,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(CbRadius.md),
                  ),
                  child: _readingPhoto
                      ? const Center(child: CircularProgressIndicator())
                      : null,
                ),
              ),
            ),
            Positioned(
              left: CbSpace.s4,
              right: CbSpace.s4,
              bottom: CbSpace.s6,
              child: SafeArea(
                child: Column(
                  children: [
                    if (wrongCode != null && (_wrongCode?.isActive ?? false))
                      CbNotice.warning(message: wrongCode)
                    else
                      Text(
                        widget.hint,
                        textAlign: TextAlign.center,
                        style: text.body.copyWith(color: Colors.white),
                      ),
                    // While a button's dialog or picker is open, the others
                    // wait.
                    IgnorePointer(
                      ignoring: _paused,
                      child: Column(
                        children: [
                          for (final action in actions) ...[
                            const SizedBox(height: CbSpace.s3),
                            action,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
