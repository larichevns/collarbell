import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_config.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../theme/collarbell_theme.dart';
import '../account/deleted_account.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';
import 'dev_auth_repository.dart';

enum _FormMode { signIn, signUp }

/// Email and password sign-in or registration. In dev auth mode it also
/// offers "Continue as developer" with an editable email.
///
/// On success the auth state changes and the router leaves this screen.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _developerFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final TextEditingController _developerEmail;

  var _mode = _FormMode.signIn;
  var _submitted = false;
  var _busy = false;
  var _obscurePassword = true;
  AuthFailure? _failure;

  /// "Forgot password?" was pressed without a usable e-mail.
  var _resetNeedsEmail = false;

  /// Where the link for a new password went.
  String? _resetSentTo;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(authRepositoryProvider);
    _developerEmail = TextEditingController(
      text: repository is DevAuthRepository
          ? repository.lastEmail
          : DevAuthRepository.defaultEmail,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _developerEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _failure = null;
      _resetNeedsEmail = false;
      _resetSentTo = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final password = _password.text;
    await _run(
      (repository) => _mode == _FormMode.signIn
          ? repository.signIn(email, password)
          : repository.signUp(email, password),
    );
  }

  Future<void> _continueAsDeveloper() async {
    setState(() => _failure = null);
    if (!(_developerFormKey.currentState?.validate() ?? false)) return;
    await _run((repository) async {
      if (repository is! DevAuthRepository) {
        throw const AuthException(AuthFailure.notAllowed);
      }
      return repository.signInAsDeveloper(_developerEmail.text);
    });
  }

  Future<void> _run(
    Future<AuthUser> Function(AuthRepository repository) action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(authRepositoryProvider));
      TextInput.finishAutofillContext();
    } on AuthException catch (error) {
      if (mounted) setState(() => _failure = error.failure);
    } catch (error) {
      debugPrint('Sign-in failed: $error');
      if (mounted) setState(() => _failure = AuthFailure.unknown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _FormMode.signIn ? _FormMode.signUp : _FormMode.signIn;
      _failure = null;
      _resetNeedsEmail = false;
      _resetSentTo = null;
    });
  }

  /// "Forgot password?": Firebase sends a letter with a link to set a new
  /// one, in the app's language, to the e-mail typed above.
  Future<void> _resetPassword() async {
    if (_busy) return;
    final email = _email.text.trim();
    final languageCode = Localizations.localeOf(context).languageCode;
    setState(() {
      _failure = null;
      _resetSentTo = null;
      _resetNeedsEmail = !looksLikeEmail(email);
    });
    if (_resetNeedsEmail) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordReset(email, languageCode: languageCode);
      if (mounted) setState(() => _resetSentTo = email);
    } on AuthException catch (error) {
      if (mounted) setState(() => _failure = error.failure);
    } catch (error) {
      debugPrint('Sending the password link failed: $error');
      if (mounted) setState(() => _failure = AuthFailure.unknown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateEmail(String? value) {
    final l10n = context.l10n;
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l10n.emailRequired;
    if (!looksLikeEmail(email)) return l10n.emailInvalid;
    return null;
  }

  String? _validatePassword(String? value) {
    final l10n = context.l10n;
    final password = value ?? '';
    if (password.isEmpty) return l10n.passwordRequired;
    if (_mode == _FormMode.signUp && password.length < minPasswordLength) {
      return l10n.passwordTooShort(minPasswordLength);
    }
    return null;
  }

  String? _validateDeveloperEmail(String? value) {
    final l10n = context.l10n;
    final email = DevAuthRepository.normalizeEmail(value ?? '');
    if (email.isEmpty) return l10n.emailRequired;
    if (!DevAuthRepository.isValidDeveloperEmail(email)) {
      return l10n.emailInvalid;
    }
    return null;
  }

  String _failureMessage(AuthFailure failure) {
    final l10n = context.l10n;
    return switch (failure) {
      AuthFailure.invalidCredentials => l10n.authErrorInvalidCredentials,
      AuthFailure.emailInUse => l10n.authErrorEmailInUse,
      AuthFailure.weakPassword => l10n.authErrorWeakPassword,
      AuthFailure.invalidEmail => l10n.authErrorInvalidEmail,
      AuthFailure.userDisabled => l10n.authErrorUserDisabled,
      AuthFailure.tooManyRequests => l10n.authErrorTooManyRequests,
      AuthFailure.network => l10n.authErrorNetwork,
      AuthFailure.notAllowed => l10n.authErrorNotAllowed,
      AuthFailure.unknown => l10n.authErrorUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final devMode = ref.watch(appConfigProvider).authMode == AuthMode.dev;
    // Signed out because the account was deleted, here or elsewhere.
    final accountDeleted = ref.watch(deletedAccountProvider);
    final signUp = _mode == _FormMode.signUp;
    final failure = _failure;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                CbSpace.s4,
                CbSpace.s12,
                CbSpace.s4,
                CbSpace.s6,
              ),
              children: [
                Text(l10n.appTitle, style: text.displayLg),
                const SizedBox(height: CbSpace.s2),
                Text(
                  l10n.signInTagline,
                  style: text.body.copyWith(color: cb.inkMuted),
                ),
                if (accountDeleted) ...[
                  const SizedBox(height: CbSpace.s6),
                  CbNotice(message: l10n.accountDeletedNotice),
                ],
                const SizedBox(height: CbSpace.s8),
                if (devMode) ...[
                  _DeveloperSignIn(
                    formKey: _developerFormKey,
                    controller: _developerEmail,
                    validator: _validateDeveloperEmail,
                    onContinue: _busy ? null : _continueAsDeveloper,
                  ),
                  const SizedBox(height: CbSpace.s8),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    signUp ? l10n.signUpTitle : l10n.signInTitle,
                    style: text.title,
                  ),
                ),
                const SizedBox(height: CbSpace.s4),
                AutofillGroup(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _submitted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        CbTextField(
                          label: l10n.emailLabel,
                          hintText: l10n.emailHint,
                          controller: _email,
                          validator: _validateEmail,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.username,
                          ],
                          autocorrect: false,
                          enabled: !_busy,
                        ),
                        const SizedBox(height: CbSpace.s4),
                        CbTextField(
                          label: l10n.passwordLabel,
                          controller: _password,
                          validator: _validatePassword,
                          obscureText: _obscurePassword,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          autofillHints: [
                            signUp
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          enabled: !_busy,
                          onFieldSubmitted: (_) => _submit(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? l10n.showPassword
                                : l10n.hidePassword,
                            icon: Icon(
                              _obscurePassword
                                  ? Symbols.visibility_rounded
                                  : Symbols.visibility_off_rounded,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!signUp)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _busy ? null : _resetPassword,
                      child: Text(l10n.forgotPassword),
                    ),
                  ),
                if (_resetNeedsEmail) ...[
                  const SizedBox(height: CbSpace.s2),
                  CbNotice.warning(message: l10n.passwordResetNeedsEmail),
                ],
                if (_resetSentTo case final email?) ...[
                  const SizedBox(height: CbSpace.s2),
                  CbNotice(message: l10n.passwordResetSent(email)),
                ],
                if (failure != null) ...[
                  const SizedBox(height: CbSpace.s4),
                  CbNotice.error(message: _failureMessage(failure)),
                ],
                const SizedBox(height: CbSpace.s6),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(signUp ? l10n.signUpButton : l10n.signInButton),
                ),
                const SizedBox(height: CbSpace.s2),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _toggleMode,
                    child: Text(
                      signUp ? l10n.switchToSignIn : l10n.switchToSignUp,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dev auth mode only: sign in with an email, no password. The uid shown is
/// what the API receives in `X-Dev-User`.
class _DeveloperSignIn extends StatelessWidget {
  const _DeveloperSignIn({
    required this.formKey,
    required this.controller,
    required this.validator,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    return CbCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.devModeOverline,
              style: text.overline.copyWith(color: cb.inkMuted),
            ),
            const SizedBox(height: CbSpace.s1),
            Text(
              l10n.devModeBody,
              style: text.bodySm.copyWith(color: cb.inkMuted),
            ),
            const SizedBox(height: CbSpace.s4),
            CbTextField(
              label: l10n.devEmailLabel,
              controller: controller,
              validator: validator,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.go,
              onFieldSubmitted: (_) => onContinue?.call(),
            ),
            const SizedBox(height: CbSpace.s2),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final email = DevAuthRepository.normalizeEmail(value.text);
                if (!DevAuthRepository.isValidDeveloperEmail(email)) {
                  return const SizedBox.shrink();
                }
                return SelectableText(
                  l10n.devUserId(DevAuthRepository.uidForEmail(email)),
                  style: text.code.copyWith(color: cb.inkMuted),
                );
              },
            ),
            const SizedBox(height: CbSpace.s3),
            OutlinedButton(
              onPressed: onContinue,
              child: Text(l10n.devContinue),
            ),
          ],
        ),
      ),
    );
  }
}
