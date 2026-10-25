import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../ai/ai_repository.dart';
import '../billing/open_plan_button.dart';
import '../files/files_repository.dart';
import '../files/media_picker.dart';
import '../files/stored_file.dart';
import 'barcode_reader.dart';
import 'stock_sheets.dart';
import 'supplies_repository.dart';
import 'supply.dart';

/// Adding an item by scanning: the barcode is looked up (the household's own
/// item, the catalog, Open Pet Food Facts, UPCitemdb); what the databases
/// don't know is read from photos of the package by AI. The form opens with
/// what was found, for the user to check. With [photos] it starts with the
/// photos, without a barcode.
class ProductScanScreen extends ConsumerStatefulWidget {
  const ProductScanScreen({super.key, this.photos = false});

  final bool photos;

  @override
  ConsumerState<ProductScanScreen> createState() => _ProductScanScreenState();
}

enum _Step {
  /// The scanner is open, or about to be.
  scanning,
  lookingUp,

  /// The barcode is known: the household's item, or not enough details.
  found,

  /// Photos of the package, before they are sent.
  photos,
  reading,
  failed,
}

class _ProductScanScreenState extends ConsumerState<ProductScanScreen> {
  static const _maxPhotos = 3;

  late var _step = widget.photos ? _Step.photos : _Step.scanning;
  ProductLookup? _lookup;

  /// The scanned code, also when looking it up failed.
  String? _code;

  /// "Bought" for an item already in supplies is on its way.
  var _buying = false;

  /// The scanner is open: "Try again" tapped twice opens one.
  var _scanning = false;
  final _photos = <PickedMedia>[];

  /// What went wrong, and whether trying again can help.
  String? _failure;
  VoidCallback? _retry;

  /// The failure is the group's monthly AI photos: the plan is offered.
  var _aiLimit = false;

  /// Kept for [dispose], where providers can't be read any more.
  late final MediaPicker _picker;

  @override
  void initState() {
    super.initState();
    _picker = ref.read(mediaPickerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.photos) {
        _takePhoto();
      } else {
        _scan();
      }
    });
  }

  @override
  void dispose() {
    // Photos of a package aren't personal, but they are big: not kept. While
    // they are being read, the reading deletes them when it ends.
    final picked = [..._photos];
    if (picked.isNotEmpty && _step != _Step.reading) {
      _picker.deletePicked(picked);
    }
    super.dispose();
  }

  bool get _aiReady => ref.read(aiStatusProvider).value?.configured ?? false;

  Future<void> _scan() async {
    if (_scanning) return;
    _scanning = true;
    setState(() => _step = _Step.scanning);
    final String? code;
    try {
      code = await ref.read(barcodeReaderProvider).read(context);
    } finally {
      _scanning = false;
    }
    if (!mounted) return;
    if (code == null) {
      // Closed the scanner: back to supplies, unless this screen isn't on top
      // any more (then a pop would close another one).
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        Navigator.of(context).pop();
      }
      return;
    }
    await _find(code);
  }

  Future<void> _find(String code) async {
    final l10n = context.l10n;
    setState(() {
      _step = _Step.lookingUp;
      _failure = null;
      _code = code;
      _lookup = null;
    });
    try {
      final lookup = await ref.read(suppliesRepositoryProvider).lookup(code);
      if (!mounted) return;
      _lookup = lookup;
      final product = lookup.product;
      if (lookup.existing == null &&
          product != null &&
          product.packageSize != null) {
        _openForm(SupplyPrefill.from(lookup: lookup));
        return;
      }
      setState(() => _step = _Step.found);
    } on NotAProductCode {
      if (mounted) _fail(l10n.productScanNotProduct, retry: _scan);
    } catch (error) {
      debugPrint('Looking up the barcode failed: $error');
      if (mounted) {
        _fail(errorMessageFor(error, l10n), retry: () => _find(code));
      }
    }
  }

  void _fail(String message, {VoidCallback? retry, bool aiLimit = false}) =>
      setState(() {
        _step = _Step.failed;
        _failure = message;
        _retry = retry;
        _aiLimit = aiLimit;
      });

  /// The form instead of this screen: Back from the form returns to the
  /// list, not to a finished scan.
  void _openForm(SupplyPrefill prefill) =>
      context.pushReplacement(AppRoutes.newSupply, extra: prefill);

  Future<void> _takePhoto() async {
    final l10n = context.l10n;
    setState(() => _step = _Step.photos);
    try {
      final photo = await _picker.takePhoto();
      if (photo == null || !mounted) return;
      setState(() => _photos.add(photo));
    } catch (error) {
      debugPrint('Taking a photo failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.productScanCameraFailed)));
      }
    }
  }

  /// Photos taken earlier, from the library: up to the limit.
  Future<void> _pickPhotos() async {
    final l10n = context.l10n;
    setState(() => _step = _Step.photos);
    try {
      final room = _maxPhotos - _photos.length;
      final picked = await _picker.pickPhotos(limit: room);
      if (!mounted) return;
      // A library may give more than asked: the extra ones are dropped.
      final kept = picked.take(room).toList();
      await _picker.deletePicked(picked.skip(room).toList());
      if (!mounted) return;
      setState(() => _photos.addAll(kept));
    } catch (error) {
      debugPrint('Picking photos failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.productScanCameraFailed)));
      }
    }
  }

  Future<void> _read() async {
    final l10n = context.l10n;
    final files = ref.read(filesRepositoryProvider);
    final supplies = ref.read(suppliesRepositoryProvider);
    ref.read(appEventsProvider).action(AppAction.scanStarted);
    setState(() {
      _step = _Step.reading;
      _failure = null;
    });
    try {
      final uploaded = <String>[];
      for (final photo in _photos) {
        uploaded.add((await files.upload(photo)).id);
      }
      final draft = await supplies.scan(uploaded, barcode: _lookup?.code);
      await _picker.deletePicked([..._photos]);
      _photos.clear();
      if (!mounted) return;
      _openForm(SupplyPrefill.from(lookup: _lookup, draft: draft, code: _code));
    } on ProductScanFailed catch (failure) {
      if (!mounted) return;
      switch (failure.problem) {
        case ProductScanProblem.busy:
          _fail(l10n.productScanBusy, retry: _read);
        case ProductScanProblem.notConfigured:
          _fail(l10n.productScanNoAi);
        case ProductScanProblem.rejected:
          _fail(l10n.productScanRejected);
      }
    } catch (error) {
      debugPrint('Reading the package failed: $error');
      if (!mounted) return;
      // The month's AI photos: the same photos fail again.
      final aiLimit = isAiLimit(error);
      _fail(
        errorMessageFor(error, l10n),
        retry: aiLimit ? null : _read,
        aiLimit: aiLimit,
      );
    } finally {
      // The user left while AI was reading: no retry will need them.
      if (!mounted && _photos.isNotEmpty) {
        unawaited(_picker.deletePicked([..._photos]));
      }
    }
  }

  Future<void> _buyExisting(ExistingSupply existing) async {
    if (_buying) return;
    final l10n = context.l10n;
    setState(() => _buying = true);
    try {
      final supply = await ref
          .read(suppliesRepositoryProvider)
          .getSupply(existing.id);
      if (!mounted) return;
      await showPurchaseSheet(context, StockTarget.of(supply));
      if (mounted) context.pushReplacement(AppRoutes.supply(existing.id));
    } catch (error) {
      debugPrint('Opening the item failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessageFor(error, l10n))));
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Only the AI status: whether photos can be read.
    ref.watch(aiStatusProvider);
    // Back works while AI reads (it can take minutes): the reading goes on
    // and its answer is dropped.
    return Scaffold(
      appBar: AppBar(title: Text(l10n.productScanTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CbSpace.s4),
          children: switch (_step) {
            _Step.scanning => [const CbLoadingState.spinner()],
            _Step.lookingUp => [_Waiting(message: l10n.productScanLookingUp)],
            _Step.reading => [
              _Waiting(message: l10n.productScanReading),
              // Not waiting for AI: the form with what is known so far.
              Center(
                child: OutlinedButton(
                  onPressed: () => _openForm(
                    SupplyPrefill.from(lookup: _lookup, code: _code),
                  ),
                  child: Text(l10n.productScanByHand),
                ),
              ),
            ],
            _Step.found => _found(context),
            _Step.photos => _photoStep(context),
            _Step.failed => _failed(context),
          },
        ),
      ),
    );
  }

  List<Widget> _found(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final lookup = _lookup!;
    final existing = lookup.existing;
    if (existing != null) {
      return [
        CbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.productScanExisting, style: text.bodySm),
              const SizedBox(height: CbSpace.s1),
              Text(existing.name, style: text.title),
              if (!existing.active) ...[
                const SizedBox(height: CbSpace.s2),
                Text(l10n.productScanExistingInactive, style: text.bodySm),
              ],
              const SizedBox(height: CbSpace.s4),
              FilledButton.icon(
                key: const ValueKey('buyExisting'),
                onPressed: _buying ? null : () => _buyExisting(existing),
                icon: const Icon(Symbols.add_shopping_cart_rounded),
                label: Text(l10n.supplyBought),
              ),
              const SizedBox(height: CbSpace.s2),
              OutlinedButton(
                onPressed: () =>
                    context.pushReplacement(AppRoutes.supply(existing.id)),
                child: Text(l10n.productScanOpenExisting),
              ),
            ],
          ),
        ),
      ];
    }
    final product = lookup.product;
    return [
      CbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (product != null) ...[
              Text(product.name, style: text.title),
              if (product.brand case final brand?)
                Text(brand, style: text.bodySm),
              const SizedBox(height: CbSpace.s2),
              Text(l10n.productScanPartly, style: text.body),
            ] else
              Text(l10n.productScanUnknown, style: text.body),
            const SizedBox(height: CbSpace.s1),
            Text(
              l10n.productScanCode(lookup.code),
              style: text.bodySm.copyWith(color: context.cb.inkMuted),
            ),
          ],
        ),
      ),
      const SizedBox(height: CbSpace.s4),
      if (_aiReady) ...[
        FilledButton.icon(
          key: const ValueKey('takePhotos'),
          onPressed: _takePhoto,
          icon: const Icon(Symbols.photo_camera_rounded),
          label: Text(l10n.productScanTakePhotos),
        ),
        const SizedBox(height: CbSpace.s2),
      ],
      OutlinedButton(
        key: const ValueKey('fillByHand'),
        onPressed: () => _openForm(SupplyPrefill.from(lookup: lookup)),
        child: Text(l10n.productScanByHand),
      ),
    ];
  }

  /// What the form starts with when the user gives up on scanning: the
  /// product found, or at least the scanned code.
  SupplyPrefill get _soFar => SupplyPrefill.from(lookup: _lookup, code: _code);

  List<Widget> _photoStep(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final freeTier = ref.read(aiStatusProvider).value?.freeTier ?? false;
    return [
      Text(l10n.productScanPhotosHint, style: text.body),
      const SizedBox(height: CbSpace.s3),
      if (freeTier) ...[
        CbNotice(message: l10n.productScanFreeTier),
        const SizedBox(height: CbSpace.s3),
      ],
      Wrap(
        spacing: CbSpace.s2,
        runSpacing: CbSpace.s2,
        children: [
          for (var i = 0; i < _photos.length; i++)
            InputChip(
              avatar: const Icon(Symbols.image_rounded),
              label: Text(l10n.productScanPhoto(i + 1)),
              onDeleted: () => setState(() {
                _picker.deletePicked([_photos.removeAt(i)]);
              }),
            ),
          if (_photos.length < _maxPhotos) ...[
            ActionChip(
              key: const ValueKey('addPhoto'),
              avatar: const Icon(Symbols.add_a_photo_rounded),
              label: Text(l10n.productScanAddPhoto),
              onPressed: _takePhoto,
            ),
            ActionChip(
              key: const ValueKey('pickPhotos'),
              avatar: const Icon(Symbols.photo_library_rounded),
              label: Text(l10n.productScanFromLibrary),
              onPressed: _pickPhotos,
            ),
          ],
        ],
      ),
      const SizedBox(height: CbSpace.s5),
      FilledButton(
        key: const ValueKey('readPhotos'),
        onPressed: _photos.isEmpty ? null : _read,
        child: Text(l10n.productScanRead),
      ),
      const SizedBox(height: CbSpace.s2),
      OutlinedButton(
        key: const ValueKey('photosByHand'),
        onPressed: () => _openForm(_soFar),
        child: Text(l10n.productScanByHand),
      ),
    ];
  }

  List<Widget> _failed(BuildContext context) {
    final l10n = context.l10n;
    final retry = _retry;
    return [
      CbNotice.error(message: _failure ?? l10n.productScanUnknown),
      if (_aiLimit)
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: OpenPlanButton(),
        ),
      const SizedBox(height: CbSpace.s4),
      if (retry != null) ...[
        FilledButton(
          key: const ValueKey('retry'),
          onPressed: retry,
          child: Text(l10n.commonTryAgain),
        ),
        const SizedBox(height: CbSpace.s2),
      ],
      OutlinedButton(
        key: const ValueKey('fillByHand'),
        onPressed: () => _openForm(_soFar),
        child: Text(l10n.productScanByHand),
      ),
    ];
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CbSpace.s12),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: CbSpace.s4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.cbText.body,
          ),
        ],
      ),
    );
  }
}
