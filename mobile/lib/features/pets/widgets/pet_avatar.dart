import 'package:flutter/material.dart';

import '../../../theme/collarbell_theme.dart';
import '../../files/stored_file.dart';
import '../../files/widgets/stored_file_image.dart';

/// The pet's photo in a circle; without a photo, the pet's initial: bold,
/// `on-avatar` on the neutral `avatar` circle. Every pet gets the same
/// colours: the photo and the name tell pets apart.
class PetAvatar extends StatelessWidget {
  const PetAvatar({
    super.key,
    required this.name,
    this.photo,
    this.size = CbSize.avatarMd,
  });

  final String name;

  /// Shown as its thumbnail; the initial is the fallback.
  final StoredFile? photo;

  /// One of `CbSize.avatarSm`, `avatarMd` (default) or `avatarLg`, or
  /// [photoSize].
  final double size;

  /// The big photo on the pet's screen and in the pet form.
  static const photoSize = CbSize.avatarLg * 2;

  /// The first character (grapheme) of the name, upper-cased.
  static String initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    // Decorative: the name is always next to the avatar.
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: photo == null || photo.isPdf
            ? _initial(context)
            : ClipOval(
                child: StoredFileImage(
                  file: photo,
                  placeholder: _initial(context),
                ),
              ),
      ),
    );
  }

  Widget _initial(BuildContext context) {
    final colors = context.cb;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.avatar, shape: BoxShape.circle),
      child: Text(
        initialOf(name),
        textScaler: TextScaler.noScaling,
        style: context.cbText.title.copyWith(
          color: colors.onAvatar,
          fontSize: size * 0.42,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
