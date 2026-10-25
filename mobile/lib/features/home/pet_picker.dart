import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../theme/collarbell_theme.dart';
import '../pets/pet.dart';
import '../pets/widgets/pet_avatar.dart';

/// Runs [action] for a pet, for a quick action that needs one: with one
/// active pet at once, with several after the user picks one in a sheet.
/// With none there is nothing to do it for: the new-pet form opens instead.
Future<void> forPet(
  BuildContext context,
  List<Pet> active,
  void Function(Pet pet) action,
) async {
  if (active.isEmpty) {
    await context.push(AppRoutes.newPet);
    return;
  }
  final pet = active.length == 1
      ? active.single
      : await showPetPicker(context, active);
  if (pet == null || !context.mounted) return;
  action(pet);
}

/// "Which pet?": the [pets] with their faces and names; null when the
/// sheet is closed.
Future<Pet?> showPetPicker(BuildContext context, List<Pet> pets) =>
    showModalBottomSheet<Pet>(
      context: context,
      showDragHandle: true,
      // Many pets, or large text: the sheet scrolls instead of overflowing.
      isScrollControlled: true,
      builder: (sheet) {
        final text = sheet.cbText;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CbSpace.s4,
                    0,
                    CbSpace.s4,
                    CbSpace.s2,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(sheet.l10n.homePickPet, style: text.title),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final pet in pets)
                        ListTile(
                          key: ValueKey('pickPet-${pet.id}'),
                          leading: PetAvatar(name: pet.name, photo: pet.photo),
                          title: Text(
                            pet.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(sheet).pop(pet),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: CbSpace.s2),
              ],
            ),
          ),
        );
      },
    );
