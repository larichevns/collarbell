import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_text_field.dart';
import '../../../theme/collarbell_theme.dart';
import '../../pets/pet.dart';
import '../care.dart';
import '../care_labels.dart';
import '../care_rules.dart';

/// "Protects against": a chip for every vaccine target of the pet's
/// species. Targets already chosen are always shown, even another
/// species' ones, so saving never drops them unseen.
class TargetChips extends StatelessWidget {
  const TargetChips({
    super.key,
    required this.species,
    required this.selected,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final PetSpecies species;
  final List<VaccineTarget> selected;

  /// Gets the new selection in the usual order (rabies first).
  final ValueChanged<List<VaccineTarget>> onChanged;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final forSpecies = targetsFor(species);
    final offered = [
      for (final target in VaccineTarget.values)
        if (forSpecies.contains(target) || selected.contains(target)) target,
    ];

    void toggle(VaccineTarget target, bool on) {
      onChanged([
        for (final t in VaccineTarget.values)
          if (t == target ? on : selected.contains(t)) t,
      ]);
    }

    return CbLabeled(
      label: l10n.careTargetsLabel,
      errorText: errorText,
      child: Wrap(
        spacing: CbSpace.s2,
        runSpacing: CbSpace.s2,
        children: [
          for (final target in offered)
            FilterChip(
              label: Text(vaccineTargetLabel(l10n, target)),
              selected: selected.contains(target),
              onSelected: enabled ? (on) => toggle(target, on) : null,
            ),
        ],
      ),
    );
  }
}

/// The vaccine targets as a form field, so a server error on "targets"
/// is counted by the form and scrolled to.
class TargetsFormField extends StatelessWidget {
  const TargetsFormField({
    super.key,
    required this.species,
    required this.selected,
    required this.onChanged,
    this.serverError,
  });

  final PetSpecies species;
  final List<VaccineTarget> selected;
  final ValueChanged<List<VaccineTarget>> onChanged;
  final String? serverError;

  @override
  Widget build(BuildContext context) {
    return FormField<List<VaccineTarget>>(
      validator: (_) => serverError,
      builder: (field) => TargetChips(
        species: species,
        selected: selected,
        errorText: field.errorText,
        onChanged: onChanged,
      ),
    );
  }
}
