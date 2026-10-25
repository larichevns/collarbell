import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../pets/pets_repository.dart';
import 'care.dart';
import 'care_labels.dart';
import 'care_repository.dart';
import 'care_rules.dart';

/// "Add plan": the ready-made plans for the pet's species, grouped by
/// kind, and "Own plan". Choosing one opens the plan form with it.
class PresetPickerScreen extends ConsumerWidget {
  const PresetPickerScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pet = ref.watch(petProvider(petId));
    final species = pet.value?.species;
    final presets = species == null
        ? null
        : ref.watch(carePresetsProvider(species));

    final Widget body;
    final error = pet.error ?? presets?.error;
    final value = presets?.value;
    if (error != null) {
      body = Center(
        child: CbErrorState(
          message: errorMessageFor(error, l10n),
          traceId: traceIdOf(error),
          onRetry: () {
            ref.invalidate(petProvider(petId));
            if (species != null) ref.invalidate(carePresetsProvider(species));
          },
        ),
      );
    } else if (value == null) {
      body = const CbLoadingState();
    } else {
      body = _PresetList(
        presets: value,
        onChoose: (code) => _open(context, code),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.presetPickerTitle)),
      body: body,
    );
  }

  /// Opens the plan form; once the plan is saved, this screen closes too.
  Future<void> _open(BuildContext context, String? presetCode) async {
    final saved = await context.push<bool>(
      AppRoutes.newCarePlan(petId, presetCode: presetCode),
    );
    if (saved == true && context.mounted) context.pop();
  }
}

class _PresetList extends StatelessWidget {
  const _PresetList({required this.presets, required this.onChoose});

  final List<CarePreset> presets;

  /// Gets the preset's code, or null for "Own plan".
  final ValueChanged<String?> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s4,
        CbSpace.s12,
      ),
      children: [
        CbCard(
          padding: EdgeInsets.zero,
          child: _ChoiceRow(
            icon: Symbols.edit_note_rounded,
            title: l10n.presetOwnTitle,
            lines: [l10n.presetOwnBody],
            onTap: () => onChoose(null),
          ),
        ),
        if (presets.isEmpty) ...[
          const SizedBox(height: CbSpace.s6),
          Text(
            l10n.presetNoneForSpecies,
            style: context.cbText.body.copyWith(color: context.cb.inkMuted),
          ),
        ],
        for (final group in PresetGroup.values)
          if (presets.any((p) => presetGroupOf(p.kind) == group)) ...[
            const SizedBox(height: CbSpace.s6),
            _PresetGroup(
              title: presetGroupLabel(l10n, group),
              presets: [
                for (final preset in presets)
                  if (presetGroupOf(preset.kind) == group) preset,
              ],
              onChoose: onChoose,
            ),
          ],
      ],
    );
  }
}

/// One group of presets, e.g. "Vaccinations", in a card.
class _PresetGroup extends StatelessWidget {
  const _PresetGroup({
    required this.title,
    required this.presets,
    required this.onChoose,
  });

  final String title;
  final List<CarePreset> presets;
  final ValueChanged<String?> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CbSection(
      title: title,
      child: CbCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < presets.length; i++) ...[
              if (i > 0)
                const Divider(
                  indent: CbSpace.s4 + CbSize.avatarMd + CbSpace.s3,
                ),
              _ChoiceRow(
                key: ValueKey(presets[i].code),
                icon: careKindIcon(presets[i].kind),
                title: presetTitle(l10n, presets[i]),
                lines: [
                  intervalLabel(l10n, presets[i].interval),
                  ?presetNote(l10n, presets[i]),
                ],
                dogOnly: presets[i].dogOnly,
                onTap: () => onChoose(presets[i].code),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A row to choose: icon, title, a few lines of text and, for products
/// that must never be given to cats, a warning.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    required this.onTap,
    this.dogOnly = false,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onTap;
  final bool dogOnly;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = context.cbText;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CbSpace.s4,
            vertical: CbSpace.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: CbSize.avatarMd,
                  height: CbSize.avatarMd,
                  decoration: BoxDecoration(
                    color: cb.sunken,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: cb.inkMuted, size: 22),
                ),
              ),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.subtitle),
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(top: CbSpace.s1),
                        child: Text(
                          line,
                          style: text.bodySm.copyWith(color: cb.inkMuted),
                        ),
                      ),
                    if (dogOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: CbSpace.s1),
                        child: Row(
                          children: [
                            Icon(
                              Symbols.warning_rounded,
                              size: 16,
                              color: cb.danger,
                            ),
                            const SizedBox(width: CbSpace.s1),
                            Expanded(
                              child: Text(
                                context.l10n.presetDogOnly,
                                style: text.bodySm.copyWith(color: cb.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
