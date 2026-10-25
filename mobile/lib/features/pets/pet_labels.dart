import '../../l10n/l10n.dart';
import 'identifier_rules.dart';
import 'pet.dart';

// Localized names of the pet enums, used by the list, the details and the
// form.

String petSpeciesLabel(AppLocalizations l10n, PetSpecies species) =>
    switch (species) {
      PetSpecies.cat => l10n.petSpeciesCat,
      PetSpecies.dog => l10n.petSpeciesDog,
      PetSpecies.other => l10n.petSpeciesOther,
    };

/// Shorter species names for the segmented buttons of the form.
String petSpeciesShortLabel(AppLocalizations l10n, PetSpecies species) =>
    switch (species) {
      PetSpecies.cat => l10n.petSpeciesCat,
      PetSpecies.dog => l10n.petSpeciesDog,
      PetSpecies.other => l10n.petSpeciesOtherShort,
    };

String petSexLabel(AppLocalizations l10n, PetSex sex) => switch (sex) {
  PetSex.female => l10n.petSexFemale,
  PetSex.male => l10n.petSexMale,
  PetSex.unknown => l10n.petSexUnknown,
};

String petStatusLabel(AppLocalizations l10n, PetStatus status) =>
    switch (status) {
      PetStatus.active => l10n.petStatusActive,
      PetStatus.archived => l10n.petStatusArchived,
      PetStatus.deceased => l10n.petStatusDeceased,
    };

String identifierTypeLabel(AppLocalizations l10n, IdentifierType type) =>
    switch (type) {
      IdentifierType.isoChip => l10n.identifierTypeIsoChip,
      IdentifierType.legacyChip => l10n.identifierTypeLegacyChip,
      IdentifierType.tattoo => l10n.identifierTypeTattoo,
    };

/// What is wrong with a microchip or tattoo code, as the pet form and the
/// scan say it.
String identifierProblemLabel(
  AppLocalizations l10n,
  IdentifierProblem problem,
) => switch (problem) {
  IdentifierProblem.empty => l10n.identifierCodeRequired,
  IdentifierProblem.tooLong => l10n.formTooLong(IdentifierRules.maxRawLength),
  IdentifierProblem.isoLength => l10n.identifierIsoLength,
  IdentifierProblem.isoTestChip => l10n.identifierIsoTestChip,
  IdentifierProblem.legacyFormat => l10n.identifierLegacyFormat,
  IdentifierProblem.tattooLength => l10n.identifierTattooLength(
    IdentifierRules.maxTattooLength,
  ),
  IdentifierProblem.duplicate => l10n.identifierDuplicate,
};
