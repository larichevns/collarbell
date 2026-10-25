import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../theme/collarbell_theme.dart';
import '../files/files_repository.dart';
import '../files/media_picker.dart';
import '../files/page_viewer_screen.dart';
import '../files/stored_file.dart';
import '../files/widgets/media_sheet.dart';
import '../household/current_household.dart';
import '../today/today_repository.dart';
import '../weight/weight_labels.dart';
import '../weight/weight_repository.dart';
import 'pet.dart';
import 'pet_labels.dart';
import 'pets_repository.dart';
import 'widgets/pet_avatar.dart';

/// The Overview tab: the photo, with actions to change it, and the details.
class PetOverviewTab extends ConsumerStatefulWidget {
  const PetOverviewTab({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<PetOverviewTab> createState() => _PetOverviewTabState();
}

class _PetOverviewTabState extends ConsumerState<PetOverviewTab> {
  var _photoBusy = false;

  Future<void> _changePhoto() async {
    final hasPhoto = widget.pet.photo != null;
    final action = await showMediaActionSheet(
      context,
      actions: [
        MediaAction.camera,
        MediaAction.library,
        if (hasPhoto) MediaAction.remove,
      ],
    );
    if (action == null || !mounted) return;
    if (action == MediaAction.remove) {
      await _removePhoto();
      return;
    }

    // Read before the first await: the user may leave the pet's screen
    // during the upload, and this widget's ref goes with it.
    final container = ProviderScope.containerOf(context, listen: false);
    final picker = ref.read(mediaPickerProvider);
    final files = ref.read(filesRepositoryProvider);
    final pets = ref.read(petsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final petId = widget.pet.id;
    final PickedMedia? photo;
    try {
      photo = action == MediaAction.camera
          ? await picker.takePhoto()
          : await picker.pickPhoto();
    } on PlatformException catch (error) {
      // No camera (simulator) or no access to the photos.
      debugPrint('Picking a photo failed: $error');
      if (mounted) showPickerError(context);
      return;
    }
    if (photo == null || !mounted) return;

    setState(() => _photoBusy = true);
    try {
      final uploaded = await files.upload(photo);
      await pets.setPhoto(petId, uploaded.id);
      _refresh(container, petId);
    } catch (error) {
      debugPrint('Changing the photo failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.petPhotoRemoveTitle,
      message: l10n.petPhotoRemoveBody,
      confirmLabel: l10n.commonRemove,
    );
    if (!confirmed || !mounted) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final pets = ref.read(petsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final petId = widget.pet.id;
    setState(() => _photoBusy = true);
    try {
      await pets.removePhoto(petId);
      _refresh(container, petId);
    } catch (error) {
      debugPrint('Removing the photo failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  /// Reloads the pet, the list and Today (which shows the photo), through
  /// the container: it works even after this widget is gone.
  static void _refresh(ProviderContainer container, String petId) {
    container.invalidate(petProvider(petId));
    container.invalidate(petsProvider);
    container.invalidate(todayProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pet = widget.pet;
    final photo = pet.photo;
    return RefreshIndicator(
      // Pull to refresh: another phone may have changed the pet.
      onRefresh: () async {
        ref.invalidate(petProvider(pet.id));
        // Its latest weight too; a failure there leaves the row out.
        ref.invalidate(weightLogProvider(pet.id));
        try {
          await ref.read(petProvider(pet.id).future);
        } catch (error) {
          // The screen keeps what it shows: the snackbar says why.
          if (context.mounted) showRefreshFailed(context, error);
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s6,
          CbSpace.s4,
          CbSpace.s12,
        ),
        children: [
          Center(
            child: Semantics(
              button: photo != null,
              label: photo != null ? l10n.petPhotoOpen : null,
              child: GestureDetector(
                onTap: photo == null
                    ? null
                    : () => openPageViewer(context, pages: [photo]),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PetAvatar(
                      name: pet.name,
                      photo: photo,
                      size: PetAvatar.photoSize,
                    ),
                    if (_photoBusy) const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
          if (ref.watch(householdPermissionsProvider).canEdit) ...[
            const SizedBox(height: CbSpace.s2),
            Center(
              child: OutlinedButton.icon(
                style: cbCompactOutlinedButtonStyle,
                onPressed: _photoBusy ? null : _changePhoto,
                icon: const Icon(Symbols.photo_camera_rounded),
                label: Text(
                  photo == null ? l10n.petPhotoAdd : l10n.petPhotoChange,
                ),
              ),
            ),
          ],
          const SizedBox(height: CbSpace.s6),
          CbSection(
            title: l10n.petDetailsTitle,
            child: CbCard(child: _PetDetails(pet: pet)),
          ),
        ],
      ),
    );
  }
}

/// The filled-in details of the pet, one fact per row, with its latest
/// weight.
class _PetDetails extends ConsumerWidget {
  const _PetDetails({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final birthDate = pet.birthDate;
    final neuteredOn = pet.neuteredOn;
    // From the Weight tab's log. Until it first comes, or when its last
    // reading failed, the row is simply not there: the Weight tab says why.
    // (After a failure the log still holds the old answer, and a weighing
    // just added would be missing from it.)
    final log = ref.watch(weightLogProvider(pet.id));
    final weight = log.hasError && !log.isLoading
        ? null
        : log.value?.firstOrNull;
    String? text(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    final rows = <(String, String?)>[
      (l10n.petSpeciesLabel, petSpeciesLabel(l10n, pet.species)),
      (l10n.petSexLabel, petSexLabel(l10n, pet.sex)),
      (l10n.petBreedLabel, text(pet.breed)),
      (
        l10n.petBirthDateLabel,
        birthDate == null
            ? null
            : pet.birthDateApproximate
            ? l10n.petBirthDateAbout(birthDate)
            : l10n.dateMedium(birthDate),
      ),
      (
        l10n.weightLabel,
        weight == null
            ? null
            : l10n.weightOnDate(
                weightValueLabel(l10n, weight.weightKg),
                weight.measuredOn,
              ),
      ),
      (
        l10n.petNeuteredLabel,
        switch (pet.neutered) {
          true when neuteredOn != null => l10n.petNeuteredOnValue(neuteredOn),
          true => l10n.commonYes,
          false => l10n.commonNo,
          null => null,
        },
      ),
      (l10n.petColorLabel, text(pet.color)),
      (l10n.petMarkingsLabel, text(pet.markings)),
      (l10n.petAllergiesLabel, text(pet.allergies)),
      (l10n.petNotesLabel, text(pet.notes)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value) in rows)
          if (value != null) CbDetailRow(label: label, value: value),
      ],
    );
  }
}
