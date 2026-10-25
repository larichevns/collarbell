import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/preferences.dart';
import '../../app/router.dart';
import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_action_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../auth/auth_providers.dart';
import '../feeding/feeding.dart';
import '../feeding/feeding_labels.dart';
import '../feeding/feeding_refresh.dart';
import '../feeding/feeding_repository.dart';
import '../household/current_household.dart';
import '../household/household_labels.dart';
import '../household/household_sheets.dart';
import '../notifications/push_platform.dart';
import '../notifications/push_registration.dart';
import '../pets/pet.dart';
import '../pets/pet_form_screen.dart' show refreshPet;
import '../pets/pet_labels.dart';
import '../pets/pets_repository.dart';
import '../pets/widgets/pet_avatar.dart';
import 'onboarding.dart';

/// The onboarding, "Getting to know the app": three pages about what the
/// app does, then, for those who can edit, the first steps: a pet, its
/// feeding times, notifications and, for owners, the family. Helpers end
/// after the pages: they don't set things up.
///
/// Above the tabs (pushed), so Back and Android's back swipe return to the
/// screen under it. Home opens it by itself once for a new account
/// (`OnboardingTurn`), More whenever asked. Every step can be skipped, and
/// Back goes to the page or step before (nothing saved is undone); from the
/// first page it closes the onboarding, asking first when a typed name would
/// be lost. What it saves goes to the group it opened in.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  /// How long the main button waits after the page or step changed: a
  /// double tap on "Next" must not also press the next step's button (ask
  /// for notifications, save the feeding times unseen). Tests that tap
  /// through quickly set it to zero.
  @visibleForTesting
  static var settleAfterMove = const Duration(milliseconds: 300);

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

/// The setup steps, in order.
enum _Step { pet, feeding, notifications, family }

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with OpenedInHousehold {
  static const _pageCount = 3;

  var _pager = PageController();
  var _page = 0;

  /// The setup step on screen (its place in [_steps]); null on the pages.
  int? _step;

  /// Saving, inviting or asking for notifications: the buttons wait, and
  /// Back does nothing.
  var _busy = false;

  /// Since the page or step last changed.
  final _sinceMove = Stopwatch();

  /// The group the onboarding opened in, as it was then: its saves and the
  /// invite go there ([OpenedInHousehold]).
  CurrentHousehold? _household;

  /// Why the last save or invite failed, over the main button.
  String? _failure;

  // The pet step.
  final _petForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  var _species = PetSpecies.cat;
  var _petSubmitted = false;
  var _petServerErrors = <String, List<String>>{};

  /// The pet added here: the feeding is for it.
  Pet? _addedPet;

  // The feeding step: twice a day by default, as most cats and dogs eat.
  var _times = const [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 19, minute: 0),
  ];

  /// One id for adding a pet's schedule, sent with every try: a retry
  /// after a lost response gets the schedule that was added, not a second
  /// one. Per pet: the server answers an id it knows with that schedule,
  /// so another pet needs another id.
  final _feedingRequestIds = <String, String>{};

  /// As many times a day as the feeding form (and the server) allow.
  static const _maxTimes = 8;

  // The family step.
  var _invited = false;

  static const _maxName = 60;

  @override
  void initState() {
    super.initState();
    _household = ref.read(currentHouseholdProvider);
    // Seen now, however it was opened: from More it doesn't open again by
    // itself afterwards.
    final uid = ref.read(authUserProvider)?.uid;
    if (uid != null) {
      OnboardingTurn.markSeen(ref.read(sharedPreferencesProvider), uid);
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    _name.dispose();
    super.dispose();
  }

  /// The steps for the user's role (`build` watches it).
  List<_Step> get _steps => [
    _Step.pet,
    _Step.feeding,
    _Step.notifications,
    if (ref.read(householdPermissionsProvider).canManagePeople) _Step.family,
  ];

  bool get _canEdit => ref.read(householdPermissionsProvider).canEdit;

  /// The first page: Back closes the onboarding from here.
  bool get _atStart => _step == null && _page == 0;

  /// A name typed and not saved: closing would lose it. Not when the pet
  /// step shows the pets already there (the save went through after all).
  bool get _changed =>
      _name.text.trim().isNotEmpty &&
      !(ref.read(petsProvider).value?.any((pet) => pet.isActive) ?? false);

  /// Right after the page or step changed ([WelcomeScreen.settleAfterMove]).
  bool get _justMoved =>
      _sinceMove.isRunning &&
      _sinceMove.elapsed < WelcomeScreen.settleAfterMove;

  void _moved() => _sinceMove
    ..reset()
    ..start();

  // --- Moving between pages and steps -------------------------------------

  void _goToStep(int step) {
    _moved();
    setState(() {
      _step = step;
      _failure = null;
    });
  }

  /// On from the pages: to the first step, or for a helper, done.
  void _afterPages() => _canEdit ? _goToStep(0) : _finish();

  void _nextStep() {
    final step = _step!;
    step + 1 < _steps.length ? _goToStep(step + 1) : _finish();
  }

  void _nextPage() => _page + 1 < _pageCount
      ? _pager.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
      : _afterPages();

  /// Back one step or page. From the first step, the last page again: its
  /// pager starts there.
  void _back() {
    final step = _step;
    if (step == null) {
      _pager.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else if (step == 0) {
      _moved();
      final old = _pager;
      setState(() {
        _pager = PageController(initialPage: _pageCount - 1);
        _page = _pageCount - 1;
        _step = null;
        _failure = null;
      });
      // Not on screen any more: the pages were replaced by the steps.
      old.dispose();
    } else {
      _goToStep(step - 1);
    }
  }

  void _skip() => _step == null ? _afterPages() : _nextStep();

  /// Back to the screen under the onboarding; Home if there is none (a
  /// link opened it on its own).
  void _finish() => context.canPop()
      ? Navigator.of(context).pop()
      : context.go(AppRoutes.home);

  Future<void> _close() async {
    if (_changed && !await confirmLeave(context)) return;
    if (mounted) _finish();
  }

  // --- The pet ------------------------------------------------------------

  String? _validateName(String? value) {
    final l10n = context.l10n;
    final name = (value ?? '').trim();
    if (name.isEmpty) return l10n.petNameRequired;
    if (name.length > _maxName) return l10n.formTooLong(_maxName);
    return _petServerErrors.containsKey('name')
        ? l10n.formServerFieldError
        : null;
  }

  /// Adds the pet with its name and species, the way the pet form does;
  /// the rest of its details can be filled in later.
  Future<void> _savePet() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _petSubmitted = true;
      _petServerErrors = {};
      _failure = null;
    });
    if (!(_petForm.currentState?.validate() ?? false)) {
      setState(() => _failure = l10n.formCheckFields);
      return;
    }
    // Read before the first await: the app may close the onboarding (a
    // sign-out) while it saves.
    final container = ProviderScope.containerOf(context, listen: false);
    final pets = ref.read(petsRepositoryProvider);
    final input = PetInput(name: _name.text.trim(), species: _species);
    setState(() => _busy = true);
    try {
      final saved = await pets.createPet(input);
      container.read(appEventsProvider).action(AppAction.petSaved);
      refreshPet(container, saved.id);
      if (!mounted) return;
      setState(() {
        _addedPet = saved;
        _name.clear();
        _petSubmitted = false;
      });
      _nextStep();
    } catch (error) {
      debugPrint('Saving the pet failed: $error');
      final fieldErrors = fieldErrorsOf(error);
      // The save may have gone through and only the answer got lost: the
      // pets load again, and a pet the server added shows as "Already
      // here", so it isn't added a second time.
      if (fieldErrors.isEmpty) container.invalidate(petsProvider);
      if (!mounted) return;
      setState(() {
        _petServerErrors = {...fieldErrors};
        _failure = fieldErrors.containsKey('name')
            ? l10n.formCheckFields
            : errorMessageFor(error, l10n);
      });
      _petForm.currentState?.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "I was invited to a family": joining with the code instead of adding
  /// the pet a second time. Joined, the app shows that family, with its
  /// pets: the steps here were for the group the onboarding opened in.
  Future<void> _join() async {
    final before = ref.read(currentHouseholdProvider)?.id;
    await context.push(AppRoutes.welcomeJoin);
    if (!mounted) return;
    if (ref.read(currentHouseholdProvider)?.id != before) _finish();
  }

  // --- The feeding --------------------------------------------------------

  Future<void> _changeTime(TimeOfDay? time) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _failure = null;
      _times = {
        for (final kept in _times)
          if (kept != time) kept,
        picked,
      }.toList()..sort((a, b) => minutesOf(a) - minutesOf(b));
    });
  }

  /// A schedule every day at [_times] for [pet]: food and portion can be
  /// added later in the pet's Feeding tab.
  Future<void> _saveFeeding(Pet pet) async {
    if (_busy) return;
    final l10n = context.l10n;
    if (_times.isEmpty) {
      setState(() => _failure = l10n.feedingTimesRequired);
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final feeding = ref.read(feedingRepositoryProvider);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final saved = await feeding.createSchedule(
        pet.id,
        FeedingInput(times: _times, days: everyDay),
        requestId: _feedingRequestIds.putIfAbsent(
          pet.id,
          () => const Uuid().v4(),
        ),
      );
      refreshFeeding(container, pet.id, scheduleId: saved.id);
      if (mounted) _nextStep();
    } catch (error) {
      debugPrint('Saving the feeding schedule failed: $error');
      // The save may have gone through and only the answer got lost.
      refreshFeeding(container, pet.id);
      if (mounted) {
        setState(
          () => _failure = isNotFound(error)
              ? l10n.careGonePet
              : errorMessageFor(error, l10n),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Notifications ------------------------------------------------------

  /// Asks the phone for permission to notify, once at a time: a second tap
  /// meanwhile does nothing.
  Future<void> _allowPushes() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await askForPushesOnce(context, ref, explained: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- The family ---------------------------------------------------------

  /// Makes an invite with [action]: the buttons wait meanwhile, and a
  /// refusal shows over the main button.
  Future<bool> _run(Future<void> Function() action) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action();
      return true;
    } catch (error) {
      debugPrint('Inviting failed: $error');
      if (mounted) {
        setState(() => _failure = householdErrorMessage(error, l10n));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// An invite to the group the onboarding opened in, like its other
  /// steps' saves.
  Future<void> _invite() async {
    final household = _household;
    if (household == null || _busy) return;
    final made = await inviteToHousehold(
      context,
      ref,
      householdId: household.id,
      householdName: household.name ?? defaultHouseholdName,
      run: (action) => _run(() => inOpenedHousehold(action)),
    );
    if (made && mounted) setState(() => _invited = true);
  }

  // --- Layout -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Who may do what decides the steps (a helper has none).
    ref.watch(householdPermissionsProvider);
    final steps = _steps;
    final step = _step == null
        ? null
        : steps[_step!.clamp(0, steps.length - 1)];
    final last = step != null && _step! >= steps.length - 1;

    final Widget body;
    final ({String label, VoidCallback? onPressed}) action;
    if (step == null) {
      body = _pages(context);
      action = (
        label: _page == _pageCount - 1 ? l10n.welcomeStart : l10n.welcomeNext,
        onPressed: _nextPage,
      );
    } else {
      final next = last ? l10n.welcomeDone : l10n.welcomeNext;
      (body, action) = switch (step) {
        _Step.pet => _petStep(context, next),
        _Step.feeding => _feedingStep(context, next),
        _Step.notifications => _pushStep(context, next),
        _Step.family => _familyStep(context),
      };
    }

    return PopScope<Object?>(
      // Back walks back through the steps and pages first.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        _atStart ? _close() : _back();
      },
      child: Scaffold(
        bottomNavigationBar: CbSaveBar(
          busy: _busy,
          error: _failure,
          label: action.label,
          onSave: switch (action.onPressed) {
            final onPressed? => () {
              if (!_justMoved) onPressed();
            },
            null => null,
          },
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(context, steps.length),
              Expanded(
                child: IgnorePointer(ignoring: _busy, child: body),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Close (on the first page) or back, where the setup is, and "Skip".
  Widget _topBar(BuildContext context, int stepCount) {
    final l10n = context.l10n;
    final step = _step;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CbSpace.s1),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            _atStart
                ? IconButton(
                    key: const ValueKey('welcomeClose'),
                    tooltip: l10n.welcomeClose,
                    onPressed: _busy ? null : _close,
                    icon: const Icon(Symbols.close_rounded),
                  )
                : IconButton(
                    key: const ValueKey('welcomeBack'),
                    tooltip: l10n.welcomeBack,
                    onPressed: _busy ? null : _back,
                    icon: const BackButtonIcon(),
                  ),
            Expanded(
              child: step == null
                  ? const SizedBox.shrink()
                  : Text(
                      l10n.welcomeStep(step + 1, stepCount),
                      key: const ValueKey('welcomeStep'),
                      style: context.cbText.label.copyWith(
                        color: context.cb.inkMuted,
                      ),
                    ),
            ),
            // An escape, not a call to action: it stays text.
            TextButton(
              key: const ValueKey('welcomeSkip'),
              onPressed: _busy ? null : _skip,
              child: Text(l10n.welcomeSkip),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pages(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      (
        Symbols.notifications_rounded,
        l10n.welcomeIntro1Title,
        l10n.welcomeIntro1Body,
      ),
      (
        Symbols.document_scanner_rounded,
        l10n.welcomeIntro2Title,
        l10n.welcomeIntro2Body,
      ),
      (Symbols.group_rounded, l10n.welcomeIntro3Title, l10n.welcomeIntro3Body),
    ];
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pager,
            onPageChanged: (page) {
              _moved();
              setState(() => _page = page);
            },
            children: [
              for (final (icon, title, body) in pages)
                _IntroPage(icon: icon, title: title, body: body),
            ],
          ),
        ),
        _Dots(count: _pageCount, current: _page),
        const SizedBox(height: CbSpace.s4),
      ],
    );
  }

  (Widget, ({String label, VoidCallback? onPressed})) _petStep(
    BuildContext context,
    String next,
  ) {
    final l10n = context.l10n;
    final pets = ref.watch(petsProvider);
    final value = pets.value;
    final active = [
      for (final pet in value ?? const <Pet>[])
        if (pet.isActive) pet,
    ];
    final invited = CbActionCard(
      key: const ValueKey('welcomeInvited'),
      icon: Symbols.key_rounded,
      title: l10n.welcomeInvitedTitle,
      hint: l10n.welcomeInvitedHint,
      onTap: _join,
    );

    final Widget content;
    ({String label, VoidCallback? onPressed}) action = (
      label: next,
      onPressed: _nextStep,
    );
    if (pets.hasError && !pets.isLoading && !pets.hasValue) {
      content = CbErrorState(
        message: errorMessageFor(pets.error!, l10n),
        traceId: traceIdOf(pets.error!),
        onRetry: () => ref.invalidate(petsProvider),
      );
    } else if (value == null) {
      content = const CbLoadingState.form();
      action = (label: next, onPressed: null);
    } else if (active.isNotEmpty) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Done(
            key: const ValueKey('welcomePetsHere'),
            text: l10n.welcomePetHere(
              [for (final pet in active) pet.name].join(', '),
            ),
          ),
          const SizedBox(height: CbSpace.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const ValueKey('welcomeAddMore'),
              onPressed: () => context.push(AppRoutes.welcomePet),
              icon: const Icon(Symbols.add_rounded),
              label: Text(l10n.welcomePetAddMore),
            ),
          ),
          const SizedBox(height: CbSpace.s6),
          invited,
        ],
      );
    } else {
      content = Form(
        key: _petForm,
        autovalidateMode: _petSubmitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CbTextField(
              key: const ValueKey('welcomeName'),
              label: l10n.petNameLabel,
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              validator: _validateName,
            ),
            const SizedBox(height: CbSpace.s4),
            CbLabeled(
              label: l10n.petSpeciesLabel,
              child: SegmentedButton<PetSpecies>(
                key: const ValueKey('welcomeSpecies'),
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                segments: [
                  for (final species in [PetSpecies.cat, PetSpecies.dog])
                    ButtonSegment(
                      value: species,
                      label: Text(petSpeciesShortLabel(l10n, species)),
                    ),
                ],
                selected: {_species},
                onSelectionChanged: (value) =>
                    setState(() => _species = value.single),
              ),
            ),
            const SizedBox(height: CbSpace.s6),
            invited,
          ],
        ),
      );
      action = (
        label: l10n.welcomeSaveNext,
        onPressed: () => inOpenedHousehold(_savePet),
      );
    }
    return (
      _StepPage(
        icon: Symbols.pets_rounded,
        title: l10n.welcomePetTitle,
        body: l10n.welcomePetBody,
        child: content,
      ),
      action,
    );
  }

  (Widget, ({String label, VoidCallback? onPressed})) _feedingStep(
    BuildContext context,
    String next,
  ) {
    final l10n = context.l10n;
    final pets = ref.watch(petsProvider);
    // The pet added here, else the first one the group has.
    final pet =
        _addedPet ?? pets.value?.where((pet) => pet.isActive).firstOrNull;

    final Widget content;
    ({String label, VoidCallback? onPressed}) action = (
      label: next,
      onPressed: _nextStep,
    );
    if (pet == null) {
      content = pets.value == null && !pets.hasError
          ? const CbLoadingState.form()
          : CbNotice(message: l10n.welcomeFeedingNoPet);
    } else {
      final schedules = ref.watch(feedingSchedulesProvider(pet.id));
      final header = Row(
        children: [
          PetAvatar(name: pet.name, photo: pet.photo, size: CbSize.avatarSm),
          const SizedBox(width: CbSpace.s2),
          Expanded(
            child: Text(
              pet.name,
              style: context.cbText.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
      final Widget times;
      if (schedules.hasError && !schedules.isLoading) {
        times = CbErrorState(
          message: errorMessageFor(schedules.error!, l10n),
          traceId: traceIdOf(schedules.error!),
          onRetry: () => ref.invalidate(feedingSchedulesProvider(pet.id)),
        );
      } else if (schedules.value == null) {
        times = const CbLoadingState.form();
        action = (label: next, onPressed: null);
      } else if (schedules.value!.isNotEmpty) {
        times = _Done(
          key: const ValueKey('welcomeFeedingSet'),
          text: l10n.welcomeFeedingSet,
        );
      } else {
        times = CbLabeled(
          label: l10n.feedingTimesLabel,
          child: Wrap(
            spacing: CbSpace.s2,
            runSpacing: CbSpace.s2,
            children: [
              for (final time in _times)
                InputChip(
                  key: ValueKey('welcomeTime-${minutesOf(time)}'),
                  label: Text(timeLabel(context, time)),
                  onPressed: () => _changeTime(time),
                  deleteButtonTooltipMessage: l10n.feedingTimeRemove,
                  onDeleted: () =>
                      setState(() => _times = [..._times]..remove(time)),
                ),
              if (_times.length < _maxTimes)
                ActionChip(
                  key: const ValueKey('welcomeAddTime'),
                  avatar: const Icon(Symbols.add_rounded),
                  label: Text(l10n.feedingTimeAdd),
                  onPressed: () => _changeTime(null),
                ),
            ],
          ),
        );
        action = (
          label: l10n.welcomeSaveNext,
          onPressed: () => inOpenedHousehold(() => _saveFeeding(pet)),
        );
      }
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: CbSpace.s4),
          times,
        ],
      );
    }
    return (
      _StepPage(
        icon: Symbols.restaurant_rounded,
        title: l10n.welcomeFeedingTitle,
        body: l10n.welcomeFeedingBody,
        child: content,
      ),
      action,
    );
  }

  (Widget, ({String label, VoidCallback? onPressed})) _pushStep(
    BuildContext context,
    String next,
  ) {
    final l10n = context.l10n;
    final state = ref.watch(pushRegistrationProvider).value;
    final Widget content;
    ({String label, VoidCallback? onPressed}) action = (
      label: next,
      onPressed: _nextStep,
    );
    switch (state) {
      case null:
        content = const CbLoadingState.spinner();
      case PushState.notAsked:
        content = const SizedBox.shrink();
        action = (label: l10n.welcomePushAllow, onPressed: _allowPushes);
      case PushState.denied:
        // As on Today: the way to the system settings.
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CbNotice.warning(message: l10n.notificationsDenied),
            const SizedBox(height: CbSpace.s3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const ValueKey('welcomePushSettings'),
                onPressed: () => ref.read(pushPlatformProvider).openSettings(),
                icon: const Icon(Symbols.settings_rounded),
                label: Text(l10n.notificationsOpenSettings),
              ),
            ),
          ],
        );
      case PushState.unsupported:
        content = CbNotice(
          message: defaultTargetPlatform == TargetPlatform.iOS
              ? l10n.notificationsIphoneLater
              : l10n.notificationsUnavailable,
        );
      // Allowed: whether the phone is registered yet, the notification
      // settings screen tells.
      case PushState.registered || PushState.noToken || PushState.failed:
        content = _Done(
          key: const ValueKey('welcomePushOn'),
          text: l10n.welcomePushOn,
        );
    }
    return (
      _StepPage(
        icon: Symbols.notifications_active_rounded,
        title: l10n.welcomePushTitle,
        body: l10n.welcomePushBody,
        child: content,
      ),
      action,
    );
  }

  (Widget, ({String label, VoidCallback? onPressed})) _familyStep(
    BuildContext context,
  ) {
    final l10n = context.l10n;
    return (
      _StepPage(
        icon: Symbols.group_add_rounded,
        title: l10n.welcomeFamilyTitle,
        body: l10n.welcomeFamilyBody,
        child: _invited
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Done(
                    key: const ValueKey('welcomeInvitedDone'),
                    text: l10n.welcomeFamilyInvited,
                  ),
                  const SizedBox(height: CbSpace.s3),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      key: const ValueKey('welcomeInviteMore'),
                      onPressed: _invite,
                      icon: const Icon(Symbols.person_add_rounded),
                      label: Text(l10n.welcomeFamilyInviteMore),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
      _invited
          ? (label: l10n.welcomeDone, onPressed: _finish)
          : (label: l10n.householdInvite, onPressed: _invite),
    );
  }
}

/// One page about the app: a large icon in green circles, a title and a
/// sentence. Scrolls when the text is large.
class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = context.cbText;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: CbSpace.s6,
          vertical: CbSpace.s4,
        ),
        child: Column(
          children: [
            // Decorative: the title says it.
            ExcludeSemantics(
              child: Container(
                width: 176,
                height: 176,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cb.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: cb.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 52, fill: 1, color: cb.onPrimary),
                ),
              ),
            ),
            const SizedBox(height: CbSpace.s8),
            Semantics(
              header: true,
              child: Text(
                title,
                style: text.displayLg,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: CbSpace.s3),
            Text(
              body,
              style: text.body.copyWith(color: cb.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the pages are: a dot each, the current one long and green.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Semantics(
      label: context.l10n.welcomePage(current + 1, count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: CbSpace.s1),
                width: i == current ? CbSpace.s6 : CbSpace.s2,
                height: CbSpace.s2,
                decoration: BoxDecoration(
                  color: i == current ? cb.primary : cb.lineStrong,
                  borderRadius: BorderRadius.circular(CbRadius.full),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A setup step: its icon in a mint circle, the title, why it matters,
/// then what it asks for.
class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = context.cbText;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s4,
        CbSpace.s2,
        CbSpace.s4,
        CbSpace.s8,
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: CbSize.avatarLg,
            height: CbSize.avatarLg,
            decoration: BoxDecoration(
              color: cb.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, fill: 1, color: cb.primaryText),
          ),
        ),
        const SizedBox(height: CbSpace.s4),
        Semantics(header: true, child: Text(title, style: text.displayLg)),
        const SizedBox(height: CbSpace.s2),
        Text(body, style: text.body.copyWith(color: cb.inkMuted)),
        const SizedBox(height: CbSpace.s6),
        child,
      ],
    );
  }
}

/// Something already in place: the green check and what it is.
class _Done extends StatelessWidget {
  const _Done({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Done: the round check filled bright green, as a feeding's mark.
          Icon(Symbols.check_circle_rounded, fill: 1, color: cb.success),
          const SizedBox(width: CbSpace.s2),
          Expanded(child: Text(text, style: context.cbText.body)),
        ],
      ),
    );
  }
}
