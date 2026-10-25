import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/offline_copy.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../household/current_household.dart';
import 'passport.dart';
import 'passport_labels.dart';
import 'passport_repository.dart';

/// Edits the passport header of the pet [petId].
class PassportFormScreen extends ConsumerWidget {
  const PassportFormScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passport = ref.watch(passportProvider(petId));
    final value = passport.value;
    if (value != null) return _PassportForm(petId: petId, passport: value);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.passportFormTitle)),
      body: passport.hasError
          ? Center(
              child: CbErrorState(
                message: errorMessageFor(passport.error!, context.l10n),
                traceId: traceIdOf(passport.error!),
                onRetry: () => ref.invalidate(passportProvider(petId)),
              ),
            )
          : const CbLoadingState.form(),
    );
  }
}

/// The text fields of one contact (the issuing vet or an owner).
class _ContactDraft {
  _ContactDraft([PassportContact? contact])
    : name = TextEditingController(text: contact?.name),
      address = TextEditingController(text: contact?.address),
      phone = TextEditingController(text: contact?.phone),
      email = TextEditingController(text: contact?.email);

  final key = UniqueKey();
  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController phone;
  final TextEditingController email;

  PassportContact toContact() {
    String? clean(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    return PassportContact(
      name: clean(name),
      address: clean(address),
      phone: clean(phone),
      email: clean(email),
    );
  }

  void dispose() {
    name.dispose();
    address.dispose();
    phone.dispose();
    email.dispose();
  }
}

class _PassportForm extends ConsumerStatefulWidget {
  const _PassportForm({required this.petId, required this.passport});

  final String petId;
  final Passport passport;

  @override
  ConsumerState<_PassportForm> createState() => _PassportFormState();
}

class _PassportFormState extends ConsumerState<_PassportForm>
    with OpenedInHousehold {
  // The server's limits; checked here so mistakes show before saving.
  static const _maxNotes = 2000;
  static const _maxName = 100;
  static const _maxAddress = 300;
  static const _maxPhone = 40;
  static const _maxEmail = 320;

  final _formKey = GlobalKey<FormState>();
  late PassportModel? _model = widget.passport.model;
  late final _number = TextEditingController(text: widget.passport.number);
  late final _country = TextEditingController(
    text: widget.passport.issuingCountry,
  );
  late DateTime? _issuedOn = widget.passport.issuedOn;
  late final _issuer = _ContactDraft(widget.passport.issuer);
  late final _owners = [
    for (final owner in widget.passport.owners) _ContactDraft(owner),
  ];
  late final _notes = TextEditingController(text: widget.passport.notes);

  var _submitted = false;
  var _busy = false;
  var _serverErrors = <String, List<String>>{};
  String? _failure;

  /// Everything the form holds, to tell whether leaving loses anything.
  List<Object?> _values() => [
    _model,
    _issuedOn,
    for (final field in [_number, _country, _notes]) field.text,
    for (final contact in [_issuer, ..._owners]) ...[
      contact.name.text,
      contact.address.text,
      contact.phone.text,
      contact.email.text,
    ],
    _owners.length,
  ];

  /// What the form opened with.
  late final List<Object?> _opened;

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = openedFromCopy(ref);
    _opened = _values();
  }

  @override
  void dispose() {
    _number.dispose();
    _country.dispose();
    _notes.dispose();
    _issuer.dispose();
    for (final owner in _owners) {
      owner.dispose();
    }
    super.dispose();
  }

  String? _serverError(String field) => _serverErrors.containsKey(field)
      ? context.l10n.formServerFieldError
      : null;

  String? _maxLength(String? value, int max) =>
      (value ?? '').trim().length > max ? context.l10n.formTooLong(max) : null;

  String? _validateNumber(String? value) {
    final number = PassportRules.normalizeNumber(value ?? '');
    if (number.isNotEmpty && !PassportRules.number.hasMatch(number)) {
      return context.l10n.passportNumberInvalid;
    }
    return _serverError('passportNumber');
  }

  String? _validateCountry(String? value) {
    final country = (value ?? '').trim();
    if (country.isNotEmpty && !PassportRules.country.hasMatch(country)) {
      return context.l10n.passportCountryInvalid;
    }
    return _serverError('issuingCountry');
  }

  String? _validateEmail(String? value, String field) {
    final email = (value ?? '').trim();
    if (email.isNotEmpty && !email.contains('@')) {
      return context.l10n.emailInvalid;
    }
    return _maxLength(email, _maxEmail) ?? _serverError(field);
  }

  /// Server error keys this form shows on a field; others go to the banner.
  static final _fieldKeys = RegExp(
    r'^(passportNumber|issuingCountry|issuedOn|notes'
    r'|(issuer|owners\[\d+\])\.(name|address|phone|email))$',
  );

  Future<void> _save() async {
    if (_fromCopy) {
      setState(() => _failure = context.l10n.formOpenedOffline);
      return;
    }
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _submitted = true;
      _serverErrors = {};
      _failure = null;
    });
    final invalid = invalidFields(_formKey.currentState!);
    if (invalid.isNotEmpty) {
      revealTopmost(invalid);
      setState(() => _failure = l10n.formCheckFields);
      return;
    }

    String? clean(String text) => text.trim().isEmpty ? null : text.trim();
    final issuer = _issuer.toContact();
    final passport = Passport(
      model: _model,
      number: clean(PassportRules.normalizeNumber(_number.text)),
      issuingCountry: clean(_country.text)?.toUpperCase(),
      issuedOn: _issuedOn,
      issuer: issuer.isEmpty ? null : issuer,
      // Every card as it is, empty ones too (the server drops those), so
      // an error for `owners[1]` belongs to the second card.
      owners: [for (final owner in _owners) owner.toContact()],
      notes: clean(_notes.text),
    );

    // Read before the first await; leaving is blocked while saving
    // (PopScope), but the app can still close this screen.
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = ref.read(passportRepositoryProvider);
    final petId = widget.petId;
    setState(() => _busy = true);
    try {
      await repository.savePassport(petId, passport);
      container.invalidate(passportProvider(petId));
      if (mounted) navigator.pop();
    } catch (error) {
      debugPrint('Saving the passport failed: $error');
      if (!mounted) return;
      final fieldErrors = fieldErrorsOf(error);
      final placed =
          fieldErrors.isNotEmpty &&
          fieldErrors.keys.every((key) => _fieldKeys.hasMatch(key));
      setState(() {
        _serverErrors = {...fieldErrors};
        _failure = placed ? l10n.formCheckFields : errorMessageFor(error, l10n);
      });
      if (placed) revealTopmost(invalidFields(_formKey.currentState!));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeOwner(_ContactDraft owner) {
    setState(() {
      _owners.remove(owner);
      // Owner errors are named by position, which the removal changes.
      _serverErrors = {};
    });
    // Its text fields still use the controllers until this frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) => owner.dispose());
  }

  /// Name, address, phone and email of one contact. [field] is the API name
  /// of the contact (`issuer`, `owners[0]`), for server errors.
  Widget _contactFields(_ContactDraft draft, String field) {
    final l10n = context.l10n;
    const gap = SizedBox(height: CbSpace.s4);
    String? limit(String? value, int max, String name) =>
        _maxLength(value, max) ?? _serverError('$field.$name');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CbTextField(
          label: l10n.contactNameLabel,
          controller: draft.name,
          textCapitalization: TextCapitalization.words,
          validator: (value) => limit(value, _maxName, 'name'),
        ),
        gap,
        CbTextField(
          label: l10n.contactAddressLabel,
          controller: draft.address,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => limit(value, _maxAddress, 'address'),
        ),
        gap,
        CbTextField(
          label: l10n.contactPhoneLabel,
          controller: draft.phone,
          keyboardType: TextInputType.phone,
          validator: (value) => limit(value, _maxPhone, 'phone'),
        ),
        gap,
        CbTextField(
          label: l10n.contactEmailLabel,
          hintText: l10n.emailHint,
          controller: draft.email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          validator: (value) => _validateEmail(value, '$field.email'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const gap = SizedBox(height: CbSpace.s4);
    const sectionGap = SizedBox(height: CbSpace.s8);

    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened, _values()),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.passportFormTitle)),
        bottomNavigationBar: CbSaveBar(
          busy: _busy,
          error: _failure,
          onSave: () => inOpenedHousehold(_save),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          // Not a lazy list: every field is built, so every field is checked.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CbLabeled(
                  label: l10n.passportModelLabel,
                  child: DropdownButtonFormField<PassportModel?>(
                    icon: cbDropdownIcon,
                    initialValue: _model,
                    isExpanded: true,
                    // Body text, like the text fields (Material's default is bolder).
                    style: context.cbText.body.copyWith(color: context.cb.ink),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.passportModelNotSet),
                      ),
                      for (final model in PassportModel.values)
                        DropdownMenuItem(
                          value: model,
                          child: Text(
                            passportModelLabel(l10n, model),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (model) => setState(() => _model = model),
                  ),
                ),
                gap,
                CbTextField(
                  label: l10n.passportNumberLabel,
                  hintText: l10n.passportNumberHint,
                  controller: _number,
                  monospace: true,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  validator: _validateNumber,
                ),
                gap,
                CbTextField(
                  label: l10n.passportCountryLabel,
                  hintText: l10n.passportCountryHint,
                  controller: _country,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  validator: _validateCountry,
                ),
                gap,
                CbDateField(
                  label: l10n.passportIssuedOnLabel,
                  value: _issuedOn,
                  onChanged: (date) => setState(() => _issuedOn = date),
                  validator: (_) => _serverError('issuedOn'),
                ),
                sectionGap,
                CbSection(
                  title: l10n.passportIssuerTitle,
                  child: _contactFields(_issuer, 'issuer'),
                ),
                sectionGap,
                CbSection(
                  title: l10n.passportOwnersTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _owners.length; i++) ...[
                        _OwnerCard(
                          key: _owners[i].key,
                          title: l10n.passportOwnerNumbered(i + 1),
                          onRemove: () => _removeOwner(_owners[i]),
                          child: _contactFields(_owners[i], 'owners[$i]'),
                        ),
                        const SizedBox(height: CbSpace.s3),
                      ],
                      if (_owners.length < Passport.maxOwners)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _owners.add(_ContactDraft())),
                            icon: const Icon(Symbols.add_rounded),
                            label: Text(l10n.passportOwnerAdd),
                          ),
                        ),
                    ],
                  ),
                ),
                sectionGap,
                CbTextField(
                  label: l10n.passportNotesLabel,
                  controller: _notes,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      _maxLength(value, _maxNotes) ?? _serverError('notes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bordered block for one owner, with a remove button.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    super.key,
    required this.title,
    required this.onRemove,
    required this.child,
  });

  final String title;
  final VoidCallback onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CbSpace.s3),
      decoration: BoxDecoration(
        border: Border.all(color: context.cb.line),
        borderRadius: BorderRadius.circular(CbRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.cbText.subtitle)),
              IconButton(
                tooltip: context.l10n.passportOwnerRemove,
                icon: const Icon(Symbols.delete_rounded),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: CbSpace.s2),
          child,
        ],
      ),
    );
  }
}
