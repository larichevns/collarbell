import 'package:flutter/foundation.dart';

import '../household/household.dart';

/// What deleting the account does to one of the person's households.
enum HouseholdFate {
  /// Nobody would be left to look after it (the person is alone there, or
  /// only helpers would remain): it goes with its pets, records and files.
  deleted,

  /// The others keep it as it is: the person isn't its last owner.
  kept,

  /// The others keep it, and the member who joined first becomes its owner.
  handedOver,
}

/// One of the person's households and what deleting the account does to it.
@immutable
class HouseholdOutcome {
  const HouseholdOutcome({
    required this.id,
    required this.name,
    required this.role,
    required this.fate,
    required this.pets,
    required this.others,
    this.newOwner,
  });

  final String id;
  final String name;

  /// The person's role there.
  final HouseholdRole role;
  final HouseholdFate fate;

  /// Its pets: what goes when it is deleted.
  final int pets;

  /// The other people in it: who keeps it, or, when it is deleted, the
  /// helpers who lose it.
  final int others;

  /// Who becomes its owner ([HouseholdFate.handedOver]): their name, else
  /// their e-mail.
  final String? newOwner;
}

/// What deleting the account would do: each household's fate, the
/// first-joined first, and the server's fingerprint of these fates ([plan]).
/// The deletion sends [plan] back, and the server deletes only while the
/// fates are still these: the person agrees to what they were shown, not to
/// what changed meanwhile (someone joined, left or became an owner).
@immutable
class DeletionPreview {
  const DeletionPreview({required this.households, required this.plan});

  final List<HouseholdOutcome> households;
  final String plan;
}

/// The person's data as downloaded (a ZIP), in a temporary folder on the
/// phone until it is saved or shared.
@immutable
class ExportFile {
  const ExportFile({
    required this.path,
    required this.name,
    required this.bytes,
  });

  final String path;

  /// E.g. `collarbell-export-2026-10-06.zip`.
  final String name;
  final int bytes;
}
