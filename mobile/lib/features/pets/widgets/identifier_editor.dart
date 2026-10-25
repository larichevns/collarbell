import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_date_field.dart';
import '../../../shared/widgets/cb_notice.dart';
import '../../../shared/widgets/cb_text_field.dart';
import '../../../theme/collarbell_theme.dart';
import '../identifier_rules.dart';
import '../pet.dart';
import '../pet_labels.dart';

/// One microchip or tattoo while the pet form is open.
class IdentifierDraft {
  IdentifierDraft({
    this.id,
    this.type = IdentifierType.isoChip,
    String code = '',
    this.appliedOn,
    this.readOn,
    String location = '',
  }) : code = TextEditingController(text: code),
       location = TextEditingController(text: location);

  /// Starts from a saved identifier: the code as the user once typed it.
  factory IdentifierDraft.fromIdentifier(PetIdentifier identifier) =>
      IdentifierDraft(
        id: identifier.id,
        type: identifier.type,
        code: identifier.rawCode,
        appliedOn: identifier.appliedOn,
        readOn: identifier.readOn,
        location: identifier.location ?? '',
      );

  /// Keeps the card's text fields when cards above it are removed.
  final key = UniqueKey();
  final String? id;
  IdentifierType type;
  final TextEditingController code;
  DateTime? appliedOn;

  /// Not editable in the form, but sent back so saving doesn't lose it.
  final DateTime? readOn;
  final TextEditingController location;

  /// What the last scan has to say on the card: "check it against the
  /// passport", or why nothing was filled in. Gone once the number is typed.
  ({String text, bool failed})? scanNote;

  PetIdentifier toIdentifier() {
    final location = this.location.text.trim();
    return PetIdentifier(
      id: id,
      type: type,
      code: IdentifierRules.normalize(code.text),
      rawCode: code.text.trim(),
      appliedOn: appliedOn,
      readOn: readOn,
      location: location.isEmpty ? null : location,
    );
  }

  void dispose() {
    code.dispose();
    location.dispose();
  }
}

/// The card for one microchip or tattoo: type, code, date and location.
class IdentifierCard extends StatelessWidget {
  const IdentifierCard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
    required this.codeValidator,
    required this.fieldError,
    this.onScan,
  });

  final IdentifierDraft draft;

  /// Called after the type, the date or the scan note changed, so the form
  /// rebuilds.
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final FormFieldValidator<String> codeValidator;

  /// A server error for one of this card's fields ("code", "appliedOn",
  /// "location"), or null.
  final String? Function(String field) fieldError;

  /// Scans a microchip's number into the card; tattoos have no scan.
  final VoidCallback? onScan;

  static const maxLocationLength = 60;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final tattoo = draft.type == IdentifierType.tattoo;
    final onScan = this.onScan;
    final scanNote = draft.scanNote;
    return Container(
      padding: const EdgeInsets.all(CbSpace.s3),
      decoration: BoxDecoration(
        border: Border.all(color: cb.line),
        borderRadius: BorderRadius.circular(CbRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CbLabeled(
                  label: l10n.identifierTypeLabel,
                  child: DropdownButtonFormField<IdentifierType>(
                    icon: cbDropdownIcon,
                    initialValue: draft.type,
                    isExpanded: true,
                    // Body text, like the text fields (Material's default is bolder).
                    style: context.cbText.body.copyWith(color: context.cb.ink),
                    items: [
                      for (final type in IdentifierType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(
                            identifierTypeLabel(l10n, type),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (type) {
                      if (type == null) return;
                      draft.type = type;
                      onChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(width: CbSpace.s2),
              IconButton(
                tooltip: l10n.identifierRemove,
                icon: const Icon(Symbols.delete_rounded),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: CbSpace.s3),
          CbTextField(
            label: tattoo
                ? l10n.identifierTattooLabel
                : l10n.identifierChipLabel,
            controller: draft.code,
            monospace: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            keyboardType: draft.type == IdentifierType.isoChip
                ? TextInputType.number
                : TextInputType.text,
            helperText: switch (draft.type) {
              IdentifierType.isoChip => l10n.identifierIsoHint,
              IdentifierType.legacyChip => l10n.identifierLegacyHint,
              IdentifierType.tattoo => null,
            },
            suffixIcon: onScan == null || tattoo
                ? null
                : IconButton(
                    tooltip: l10n.chipScanAction,
                    icon: const Icon(Symbols.qr_code_scanner_rounded),
                    onPressed: onScan,
                  ),
            validator: codeValidator,
            onChanged: (_) {
              if (draft.scanNote == null) return;
              draft.scanNote = null;
              onChanged();
            },
          ),
          if (scanNote != null) ...[
            const SizedBox(height: CbSpace.s2),
            scanNote.failed
                ? CbNotice.error(message: scanNote.text)
                : CbNotice(message: scanNote.text),
          ],
          const SizedBox(height: CbSpace.s3),
          CbDateField(
            label: tattoo
                ? l10n.identifierTattooDateLabel
                : l10n.identifierChipDateLabel,
            value: draft.appliedOn,
            onChanged: (date) {
              draft.appliedOn = date;
              onChanged();
            },
            validator: (_) => fieldError('appliedOn'),
          ),
          const SizedBox(height: CbSpace.s3),
          CbTextField(
            label: l10n.identifierLocationLabel,
            hintText: l10n.identifierLocationHint,
            controller: draft.location,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if ((value ?? '').trim().length > maxLocationLength) {
                return l10n.formTooLong(maxLocationLength);
              }
              return fieldError('location');
            },
          ),
        ],
      ),
    );
  }
}

/// While AI reads the photo of a chip: a spinner, how long it takes, and
/// "Cancel". Closes with how [reading] ended, or with null when the user
/// cancels: the reading then goes on, and its answer is dropped.
class ChipReadingDialog extends StatefulWidget {
  const ChipReadingDialog({super.key, required this.reading});

  /// Started before the dialog opens, so a rebuild doesn't read twice.
  final Future<AsyncResult<List<IdentifierReading>>> reading;

  @override
  State<ChipReadingDialog> createState() => _ChipReadingDialogState();
}

class _ChipReadingDialogState extends State<ChipReadingDialog> {
  @override
  void initState() {
    super.initState();
    _wait();
  }

  Future<void> _wait() => widget.reading.then(_close);

  /// Closes the dialog with [outcome], unless it is closing already (the
  /// user cancelled): a pop then would close the screen under it.
  void _close(AsyncResult<List<IdentifierReading>>? outcome) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: CbSpace.s4),
          Expanded(
            child: Text(l10n.chipScanReading, style: context.cbText.body),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _close(null),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

/// Lets the user pick one of several numbers read on a photo or seen by the
/// scanner; null when the sheet is closed. [title] says where they come from
/// (on the photo by default). [otherCodes] are the normalised numbers of the
/// form's other cards: a number among them is marked as in the list already.
Future<IdentifierReading?> pickIdentifierReading(
  BuildContext context,
  List<IdentifierReading> readings, {
  required List<String> otherCodes,
  String? title,
}) {
  return showModalBottomSheet<IdentifierReading>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;
      final cb = context.cb;
      final text = context.cbText;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: CbSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CbSpace.s4,
                  CbSpace.s4,
                  CbSpace.s4,
                  CbSpace.s2,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    title ?? l10n.chipScanPickTitle,
                    style: text.title,
                  ),
                ),
              ),
              for (final reading in readings)
                ListTile(
                  key: ValueKey(reading.code),
                  title: Text(
                    IdentifierRules.display(reading.type, reading.code),
                    style: text.code,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        [
                          identifierTypeLabel(l10n, reading.type),
                          ?reading.location,
                        ].join(' · '),
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                      ),
                      if (_readingProblem(l10n, reading, otherCodes)
                          case final problem?)
                        Text(
                          problem,
                          style: text.caption.copyWith(color: cb.danger),
                        ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).pop(reading),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// What saving [reading] would refuse, in the user's language: the app's own
/// check, or only the fact for a rule of the server the app doesn't know.
String? _readingProblem(
  AppLocalizations l10n,
  IdentifierReading reading,
  List<String> otherCodes,
) {
  final problem = IdentifierRules.check(
    reading.type,
    reading.rawCode,
    otherCodes: otherCodes,
  );
  if (problem != null) return identifierProblemLabel(l10n, problem);
  return reading.problem == null ? null : l10n.formServerFieldError;
}
