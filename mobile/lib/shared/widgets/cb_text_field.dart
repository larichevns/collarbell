import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/collarbell_theme.dart';

/// The arrow of every `DropdownButtonFormField`: `expand_more`, 16 in from
/// the field's right edge like the words from its left. Flutter places a
/// dropdown's icon 12 from the edge; the padding adds the other 4.
const cbDropdownIcon = Padding(
  padding: EdgeInsetsDirectional.only(end: CbSpace.s1),
  child: Icon(Symbols.expand_more_rounded),
);

/// A text field with its label above it (never floating inside the border),
/// as the design system asks. The label and the field are one node for
/// screen readers.
class CbTextField extends StatelessWidget {
  const CbTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.helperText,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.obscureText = false,
    this.autocorrect = true,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.monospace = false,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.inputFormatters,
  }) : assert(
         maxLength == null || controller != null,
         'The counter reads the text from the controller',
       );

  final String label;
  final TextEditingController? controller;
  final String? hintText;

  /// A hint under the field, e.g. what format a code has.
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autocorrect;
  final bool enabled;

  /// More than 1 for notes: the field grows up to this many lines.
  final int maxLines;

  /// The lines the field has when it is empty; 1 by default.
  final int? minLines;

  /// Shows a counter under the field ("12/1000") of the text as the server
  /// counts it ([countedLength]): trimmed, an emoji counting 2. Typing past
  /// it isn't stopped, so a pasted text keeps its end: the counter turns
  /// red, and the [validator] says what is wrong. Needs the [controller].
  final int? maxLength;

  /// The length of [text] as the server counts it against a limit: trimmed,
  /// in UTF-16 code units (an emoji counts 2, as .NET's `string.Length`).
  static int countedLength(String text) => text.trim().length;

  /// JetBrains Mono, for chip and passport numbers.
  final bool monospace;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;

  /// E.g. digits only, for numbers.
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final text = context.cbText;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: text.label),
          const SizedBox(height: CbSpace.s2),
          TextFormField(
            controller: controller,
            validator: validator,
            onChanged: onChanged,
            keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            autofillHints: autofillHints,
            obscureText: obscureText,
            autocorrect: autocorrect,
            enableSuggestions: !obscureText && autocorrect,
            enabled: enabled,
            minLines: minLines ?? 1,
            maxLines: maxLines,
            // The field's own counter counts characters as shown, and it would
            // stop typing at the limit: this one counts as the server does.
            buildCounter: maxLength == null ? null : _counter,
            onFieldSubmitted: onFieldSubmitted,
            inputFormatters: inputFormatters,
            style: monospace ? text.code : text.body,
            decoration: InputDecoration(
              hintText: hintText,
              helperText: helperText,
              helperMaxLines: 3,
              suffixIcon: suffixIcon,
            ),
          ),
        ],
      ),
    );
  }

  /// "12/1000" under the field, red past the limit. Rebuilt with the field
  /// as it is typed in.
  Widget _counter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    final cb = context.cb;
    final max = this.maxLength!;
    final length = countedLength(controller!.text);
    return Text(
      '$length/$max',
      style: context.cbText.caption.copyWith(
        color: length > max ? cb.danger : cb.inkMuted,
      ),
      semanticsLabel: MaterialLocalizations.of(
        context,
      ).remainingTextFieldCharacterCount((max - length).clamp(0, max)),
    );
  }
}

/// A label above any control (segmented buttons, chips, a dropdown), in the
/// same style as [CbTextField]'s label. [errorText] appears under the
/// control in `danger`, as under a text field.
class CbLabeled extends StatelessWidget {
  const CbLabeled({
    super.key,
    required this.label,
    required this.child,
    this.helperText,
    this.errorText,
  });

  final String label;
  final Widget child;
  final String? helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = context.cbText;
    final helperText = this.helperText;
    final errorText = this.errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: text.label),
        const SizedBox(height: CbSpace.s2),
        child,
        if (errorText != null) ...[
          const SizedBox(height: CbSpace.s1),
          Text(errorText, style: text.caption.copyWith(color: cb.danger)),
        ] else if (helperText != null) ...[
          const SizedBox(height: CbSpace.s1),
          Text(helperText, style: text.caption.copyWith(color: cb.inkMuted)),
        ],
      ],
    );
  }
}
