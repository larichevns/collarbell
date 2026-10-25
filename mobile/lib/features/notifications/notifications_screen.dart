import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../feeding/feeding_labels.dart' show calendarDaysBetween;
import 'notifications.dart';
import 'notifications_repository.dart';
import 'push_platform.dart';
import 'push_registration.dart';

/// More → Notifications: whether pushes reach this phone (with a test),
/// which kinds of reminders come, and the reminders of the next and last
/// days with what happened to each, so a missed one can be explained.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  var _testing = false;

  /// The kinds being switched now, with the value they are switched to: the
  /// switch shows it until the server's answer is loaded.
  final _switching = <NotificationCategory, bool>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the system settings: notifications may be allowed now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pushRegistrationProvider);
    }
  }

  Future<void> _setEnabled(NotificationCategory category, bool enabled) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = ref.read(notificationsRepositoryProvider);
    setState(() => _switching[category] = enabled);
    try {
      await repository.setEnabled(category, enabled);
    } catch (error) {
      debugPrint('Changing the notification setting failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    } finally {
      container.invalidate(notificationSettingsProvider);
      try {
        await container.read(notificationSettingsProvider.future);
      } catch (_) {
        // The error is shown by the error state.
      }
      if (mounted) setState(() => _switching.remove(category));
    }
  }

  Future<void> _test() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = ref.read(notificationsRepositoryProvider);
    setState(() => _testing = true);
    try {
      final result = await repository.sendTest();
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (result.problem) {
            null => l10n.notificationsTestSent,
            TestPushProblem.notConfigured => l10n.notificationsServerNotReady,
            TestPushProblem.noDevices => l10n.notificationsTestNoDevices,
            TestPushProblem.failed => l10n.notificationsTestFailed,
          }),
        ),
      );
    } catch (error) {
      debugPrint('The test push failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    } finally {
      // A phone Firebase no longer knows may have been forgotten.
      container.invalidate(notificationSettingsProvider);
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationSettingsProvider);
          ref.invalidate(reminderLogProvider);
          ref.invalidate(pushRegistrationProvider);
          try {
            await Future.wait([
              ref.read(notificationSettingsProvider.future),
              ref.read(reminderLogProvider.future),
            ]);
          } catch (_) {
            // The errors are shown by the error states.
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            CbSpace.s4,
            CbSpace.s4,
            CbSpace.s4,
            CbSpace.s12,
          ),
          children: [
            _status(context),
            const SizedBox(height: CbSpace.s6),
            CbSection(title: l10n.notificationsKinds, child: _kinds(context)),
            const SizedBox(height: CbSpace.s6),
            _log(context),
          ],
        ),
      ),
    );
  }

  /// Whether pushes reach this phone, and what to do when they don't.
  Widget _status(BuildContext context) {
    final l10n = context.l10n;
    final registration = ref.watch(pushRegistrationProvider);
    final settings = ref.watch(notificationSettingsProvider).value;
    final state = registration.value;
    final serverReady = settings?.pushReady ?? true;

    if (state == null) {
      return const CbLoadingState();
    }

    final (message, warning) = switch (state) {
      PushState.unsupported when defaultTargetPlatform == TargetPlatform.iOS =>
        (l10n.notificationsIphoneLater, true),
      PushState.unsupported => (l10n.notificationsUnavailable, true),
      PushState.denied => (l10n.notificationsDenied, true),
      PushState.notAsked => (l10n.notificationsNotAsked, false),
      PushState.noToken => (l10n.notificationsNoToken, true),
      PushState.failed => (l10n.notificationsRegisterFailed, true),
      PushState.registered when !serverReady => (
        l10n.notificationsServerNotReady,
        true,
      ),
      PushState.registered => (l10n.notificationsReady, false),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        warning
            ? CbNotice.warning(key: const ValueKey('status'), message: message)
            : CbNotice(key: const ValueKey('status'), message: message),
        const SizedBox(height: CbSpace.s3),
        if (state == PushState.notAsked)
          OutlinedButton.icon(
            onPressed: () => askForPushesOnce(context, ref),
            icon: const Icon(Symbols.notifications_rounded),
            label: Text(l10n.pushAskAllow),
          )
        else if (state == PushState.denied)
          OutlinedButton.icon(
            onPressed: () => ref.read(pushPlatformProvider).openSettings(),
            icon: const Icon(Symbols.settings_rounded),
            label: Text(l10n.notificationsOpenSettings),
          )
        else if (state == PushState.failed || state == PushState.noToken)
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(pushRegistrationProvider),
            icon: const Icon(Symbols.refresh_rounded),
            label: Text(l10n.commonTryAgain),
          )
        else if (state == PushState.registered && serverReady)
          OutlinedButton.icon(
            key: const ValueKey('test'),
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox.square(
                    dimension: CbSpace.s4,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.notifications_active_rounded),
            label: Text(l10n.notificationsTest),
          ),
      ],
    );
  }

  Widget _kinds(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(notificationSettingsProvider);
    final value = settings.value;
    if (settings.hasError && !settings.isLoading) {
      return CbErrorState(
        message: errorMessageFor(settings.error!, l10n),
        traceId: traceIdOf(settings.error!),
        onRetry: () => ref.invalidate(notificationSettingsProvider),
      );
    }
    if (value == null) return const CbLoadingState();
    return CbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final category in NotificationCategory.values)
            SwitchListTile(
              key: ValueKey('kind-${category.name}'),
              secondary: Icon(categoryIcon(category)),
              title: Text(categoryLabel(l10n, category)),
              subtitle: Text(categoryHelper(l10n, category)),
              value: _switching[category] ?? value.isEnabled(category),
              onChanged: _switching.containsKey(category)
                  ? null
                  : (enabled) => _setEnabled(category, enabled),
            ),
        ],
      ),
    );
  }

  Widget _log(BuildContext context) {
    final l10n = context.l10n;
    final log = ref.watch(reminderLogProvider);
    final value = log.value;
    if (log.hasError && !log.isLoading) {
      return CbErrorState(
        message: errorMessageFor(log.error!, l10n),
        traceId: traceIdOf(log.error!),
        onRetry: () => ref.invalidate(reminderLogProvider),
      );
    }
    if (value == null) return const CbLoadingState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CbSection(
          title: l10n.notificationsUpcoming,
          child: _entries(
            context,
            value.upcoming,
            l10n.notificationsUpcomingEmpty,
          ),
        ),
        const SizedBox(height: CbSpace.s6),
        CbSection(
          title: l10n.notificationsRecent,
          child: _entries(context, value.recent, l10n.notificationsRecentEmpty),
        ),
      ],
    );
  }

  Widget _entries(
    BuildContext context,
    List<ReminderEntry> entries,
    String empty,
  ) {
    final text = context.cbText;
    final cb = context.cb;
    if (entries.isEmpty) {
      return Text(empty, style: text.body.copyWith(color: cb.inkMuted));
    }
    return CbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final entry in entries)
            ListTile(
              key: ValueKey(entry.id),
              leading: Icon(
                entry.category == null
                    ? Symbols.notifications_rounded
                    : categoryIcon(entry.category!),
              ),
              title: Text(
                entry.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  _when(context, entry.fireAt),
                  ?reminderOutcomeLabel(context.l10n, entry),
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
  }

  /// "Today, 20:00", "Tomorrow, 10:00", "Oct 5, 10:00".
  String _when(BuildContext context, DateTime at) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final day = DateTime(at.year, at.month, at.day);
    final time = TimeOfDay.fromDateTime(at).format(context);
    return switch (calendarDaysBetween(now, at)) {
      0 => l10n.notificationsWhenToday(time),
      1 => l10n.notificationsWhenTomorrow(time),
      -1 => l10n.notificationsWhenYesterday(time),
      _ => l10n.dateWithTime(day, time),
    };
  }
}

IconData categoryIcon(NotificationCategory category) => switch (category) {
  NotificationCategory.feeding => Symbols.restaurant_rounded,
  NotificationCategory.care => Symbols.vaccines_rounded,
  NotificationCategory.appointments => Symbols.event_rounded,
  NotificationCategory.supplies => Symbols.inventory_2_rounded,
};

String categoryLabel(AppLocalizations l10n, NotificationCategory category) =>
    switch (category) {
      NotificationCategory.feeding => l10n.notificationsKindFeeding,
      NotificationCategory.care => l10n.notificationsKindCare,
      NotificationCategory.appointments => l10n.notificationsKindVisits,
      NotificationCategory.supplies => l10n.notificationsKindSupplies,
    };

String categoryHelper(AppLocalizations l10n, NotificationCategory category) =>
    switch (category) {
      NotificationCategory.feeding => l10n.notificationsKindFeedingHelper,
      NotificationCategory.care => l10n.notificationsKindCareHelper,
      NotificationCategory.appointments => l10n.notificationsKindVisitsHelper,
      NotificationCategory.supplies => l10n.notificationsKindSuppliesHelper,
    };

/// What happened to a reminder; null for one still waiting.
String? reminderOutcomeLabel(AppLocalizations l10n, ReminderEntry entry) =>
    switch (entry.status) {
      ReminderStatus.pending || null => null,
      ReminderStatus.sent => l10n.reminderSent,
      ReminderStatus.expired => l10n.reminderExpired,
      ReminderStatus.failed => l10n.reminderFailed,
      ReminderStatus.skipped => switch (entry.reason) {
        ReminderReason.notNeeded => l10n.reminderSkippedNotNeeded,
        ReminderReason.noRecipients => l10n.reminderSkippedNoPhones,
        ReminderReason.pushNotConfigured => l10n.reminderSkippedServer,
        _ => l10n.reminderSkipped,
      },
    };
