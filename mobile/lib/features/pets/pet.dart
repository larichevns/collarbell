import 'package:flutter/foundation.dart';

import '../files/stored_file.dart';

enum PetSpecies { cat, dog, other }

enum PetSex { male, female, unknown }

enum PetStatus { active, archived, deceased }

/// How a pet is identified (section III of the EU passport).
enum IdentifierType {
  /// ISO 11784/11785 microchip: 15 digits.
  isoChip,

  /// An older, non-ISO microchip (10 hex characters, or 9 digits for AVID).
  /// Not every scanner reads it.
  legacyChip,

  tattoo,
}

/// A microchip or tattoo of a pet.
@immutable
class PetIdentifier {
  const PetIdentifier({
    required this.type,
    required this.code,
    required this.rawCode,
    this.id,
    this.appliedOn,
    this.readOn,
    this.location,
  });

  /// Null until the identifier is saved.
  final String? id;
  final IdentifierType type;

  /// Normalised: upper case, without spaces, hyphens, dots and asterisks.
  final String code;

  /// As the user typed it; the form shows this text again.
  final String rawCode;

  /// When the chip was implanted or the tattoo applied.
  final DateTime? appliedOn;

  /// When a vet last read the chip. Not editable in the app yet, but kept.
  final DateTime? readOn;

  /// Where it is, e.g. "left side of the neck".
  final String? location;

  @override
  bool operator ==(Object other) =>
      other is PetIdentifier &&
      other.id == id &&
      other.type == type &&
      other.code == code &&
      other.rawCode == rawCode &&
      other.appliedOn == appliedOn &&
      other.readOn == readOn &&
      other.location == location;

  @override
  int get hashCode =>
      Object.hash(id, type, code, rawCode, appliedOn, readOn, location);

  @override
  String toString() => 'PetIdentifier(${type.name}, $code)';
}

/// A microchip or tattoo number AI read from a photo, for the pet form.
@immutable
class IdentifierReading {
  const IdentifierReading({
    required this.type,
    required this.code,
    required this.rawCode,
    this.appliedOn,
    this.location,
    this.problem,
  });

  final IdentifierType type;

  /// Normalised, like [PetIdentifier.code].
  final String code;

  /// As written on the paper.
  final String rawCode;

  /// Only when written on the paper.
  final DateTime? appliedOn;
  final String? location;

  /// What saving the number would refuse, in the server's English; null
  /// when it fits its type. The app says it in the user's language by its
  /// own copy of the rules.
  final String? problem;

  @override
  String toString() => 'IdentifierReading(${type.name}, $code)';
}

/// A pet as the API returns it. Dates are calendar dates: the time part is
/// always midnight.
@immutable
class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.sex = PetSex.unknown,
    this.birthDate,
    this.birthDateApproximate = false,
    this.neutered,
    this.neuteredOn,
    this.color,
    this.markings,
    this.allergies,
    this.notes,
    this.status = PetStatus.active,
    this.photo,
    this.identifiers = const [],
  });

  final String id;
  final String name;
  final PetSpecies species;
  final String? breed;
  final PetSex sex;
  final DateTime? birthDate;

  /// The owner knows only roughly when the pet was born.
  final bool birthDateApproximate;

  /// Null when the owner didn't say.
  final bool? neutered;
  final DateTime? neuteredOn;

  /// Colour as written in the passport, e.g. "black and white".
  final String? color;
  final String? markings;
  final String? allergies;
  final String? notes;
  final PetStatus status;
  final StoredFile? photo;
  final List<PetIdentifier> identifiers;

  bool get isActive => status == PetStatus.active;

  @override
  bool operator ==(Object other) =>
      other is Pet &&
      other.id == id &&
      other.name == name &&
      other.species == species &&
      other.breed == breed &&
      other.sex == sex &&
      other.birthDate == birthDate &&
      other.birthDateApproximate == birthDateApproximate &&
      other.neutered == neutered &&
      other.neuteredOn == neuteredOn &&
      other.color == color &&
      other.markings == markings &&
      other.allergies == allergies &&
      other.notes == notes &&
      other.status == status &&
      other.photo == photo &&
      listEquals(other.identifiers, identifiers);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    species,
    breed,
    sex,
    birthDate,
    birthDateApproximate,
    neutered,
    neuteredOn,
    color,
    markings,
    allergies,
    notes,
    status,
    photo,
    Object.hashAll(identifiers),
  );

  @override
  String toString() => 'Pet($id, $name, ${species.name})';
}

/// What the pet form saves (`POST /pets` and `PUT /pets/{id}`). Saving
/// replaces all the pet's details and identifiers.
@immutable
class PetInput {
  const PetInput({
    required this.name,
    required this.species,
    this.sex = PetSex.unknown,
    this.breed,
    this.birthDate,
    this.birthDateApproximate = false,
    this.neutered,
    this.neuteredOn,
    this.color,
    this.markings,
    this.allergies,
    this.notes,
    this.identifiers = const [],
  });

  final String name;
  final PetSpecies species;
  final PetSex sex;
  final String? breed;
  final DateTime? birthDate;
  final bool birthDateApproximate;
  final bool? neutered;
  final DateTime? neuteredOn;
  final String? color;
  final String? markings;
  final String? allergies;
  final String? notes;
  final List<PetIdentifier> identifiers;

  @override
  bool operator ==(Object other) =>
      other is PetInput &&
      other.name == name &&
      other.species == species &&
      other.sex == sex &&
      other.breed == breed &&
      other.birthDate == birthDate &&
      other.birthDateApproximate == birthDateApproximate &&
      other.neutered == neutered &&
      other.neuteredOn == neuteredOn &&
      other.color == color &&
      other.markings == markings &&
      other.allergies == allergies &&
      other.notes == notes &&
      listEquals(other.identifiers, identifiers);

  @override
  int get hashCode => Object.hash(
    name,
    species,
    sex,
    breed,
    birthDate,
    birthDateApproximate,
    neutered,
    neuteredOn,
    color,
    markings,
    allergies,
    notes,
    Object.hashAll(identifiers),
  );

  @override
  String toString() => 'PetInput($name, ${species.name})';
}
