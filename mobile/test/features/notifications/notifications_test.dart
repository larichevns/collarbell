// Notifications: the settings screen (status, test push, kinds, the list of
// reminders), registering the phone after sign-in and again with a new
// token, forgetting it on sign-out, and where a tapped push leads.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/feeding/feeding_labels.dart';
import 'package:collarbell/features/notifications/notifications.dart';
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:collarbell/features/notifications/push_registration.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pet_detail_screen.dart';
import 'package:collarbell/features/visits/visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show Importance;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

ReminderEntry entry(
  String subject,
  ReminderStatus status, {
  ReminderReason? reason,
  NotificationCategory category = NotificationCategory.care,
}) => ReminderEntry(
  id: subject,
  category: category,
  subject: subject,
  fireAt: DateTime.now().subtract(const Duration(hours: 1)),
  status: status,
  reason: reason,
);

void main() {
  group('the screen', () {
    testWidgets(
      'on an iPhone it says reminders come later',
      (tester) async {
        await pumpApp(
          tester,
          location: AppRoutes.notifications,
          overrides: fakeRepositories(push: FakePushPlatform(supported: false)),
        );

        expect(find.textContaining('On iPhone'), findsOneWidget);
        expect(find.text('Send a test notification'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('a registered phone: the test push, and kinds turned off', (
      tester,
    ) async {
      final notifications = FakeNotificationsRepository();
      await pumpApp(
        tester,
        location: AppRoutes.notifications,
        overrides: fakeRepositories(
          notifications: notifications,
          push: FakePushPlatform(),
        ),
      );

      expect(find.text('Reminders come to this phone.'), findsOneWidget);
      await tester.tap(find.text('Send a test notification'));
      await tester.pumpAndSettle();
      expect(notifications.tests, 1);
      expect(find.textContaining('Sent.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kind-feeding')));
      await tester.pumpAndSettle();
      expect(notifications.enabled[NotificationCategory.feeding], isFalse);
    });

    testWidgets('not asked yet: asks after a line saying why; refused: a '
        'way to the phone settings', (tester) async {
      final push = FakePushPlatform(allowed: false);
      await pumpApp(
        tester,
        location: AppRoutes.notifications,
        overrides: fakeRepositories(push: push),
      );
      expect(
        find.textContaining("Notifications aren't allowed yet"),
        findsOneWidget,
      );

      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Allow notifications?'), findsOneWidget);
      await tester.tap(find.text('Allow notifications').last);
      await tester.pumpAndSettle();
      expect(push.permissionRequests, 1);

      // Refused in the system dialog: the way to the settings.
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(push.settingsOpened, 1);
    });

    testWidgets('a server without the Firebase key says so', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.notifications,
        overrides: fakeRepositories(
          notifications: FakeNotificationsRepository(pushReady: false),
          push: FakePushPlatform(),
        ),
      );

      expect(find.textContaining('no Firebase key'), findsOneWidget);
    });

    testWidgets('the list says what happened to each reminder', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.notifications,
        overrides: fakeRepositories(
          notifications: FakeNotificationsRepository(
            log: ReminderLog(
              upcoming: const [],
              recent: [
                entry('Murka: Rabies', ReminderStatus.sent),
                entry(
                  'Barsik, Murka',
                  ReminderStatus.skipped,
                  reason: ReminderReason.notNeeded,
                  category: NotificationCategory.feeding,
                ),
                entry('Rex: Bravecto', ReminderStatus.expired),
              ],
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(find.text('Rex: Bravecto'), 200);
      expect(find.textContaining('sent'), findsOneWidget);
      expect(find.textContaining('not needed: done already'), findsOneWidget);
      expect(
        find.textContaining('too late: the server was off'),
        findsOneWidget,
      );
      expect(find.text('Nothing in the next 7 days.'), findsOneWidget);
    });
  });

  testWidgets('the phone is registered after sign-in, again with a new token, '
      'and forgotten on sign-out', (tester) async {
    final notifications = FakeNotificationsRepository();
    final push = FakePushPlatform();
    await pumpApp(
      tester,
      location: AppRoutes.more,
      overrides: fakeRepositories(notifications: notifications, push: push),
    );

    expect(notifications.devices.values, ['token-1']);
    expect(push.channels?.feeding, 'Feeding');
    expect(push.channels?.feedingUpdates, 'Who fed');
    final deviceId = notifications.devices.keys.single;

    push.refreshToken('token-2');
    await tester.pumpAndSettle();
    expect(notifications.devices, {deviceId: 'token-2'});

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tapVisible(tester, find.text('Sign out'));
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(notifications.forgotten, [deviceId]);
    expect(push.tokensForgotten, 1);
  });

  testWidgets('signing out drops the token even when the server is away', (
    tester,
  ) async {
    final notifications = FakeNotificationsRepository()
      ..forgetError = networkError;
    final push = FakePushPlatform();
    await pumpApp(
      tester,
      location: AppRoutes.more,
      overrides: fakeRepositories(notifications: notifications, push: push),
    );

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tapVisible(tester, find.text('Sign out'));
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(push.tokensForgotten, 1);
  });

  testWidgets('never asked at sign-in or when coming back, only once after '
      'the first feeding', (tester) async {
    final push = FakePushPlatform(allowed: false);
    final feeding = FakeFeedingRepository();
    await pumpApp(
      tester,
      location: AppRoutes.newFeeding('p1'),
      overrides: fakeRepositories(
        push: push,
        feeding: feeding,
        pets: FakePetsRepository([
          const Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat),
        ]),
      ),
    );
    expect(push.permissionRequests, 0, reason: 'not at sign-in');

    for (var i = 0; i < 2; i++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    expect(push.permissionRequests, 0, reason: 'not when coming back');

    // The first schedule: the question, once.
    await tester.tap(find.text('Add time'));
    await tester.pumpAndSettle();
    await enterPickerTime(tester, const TimeOfDay(hour: 8, minute: 0));
    await tapVisible(tester, find.text('Save'));
    expect(find.text('Allow notifications?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(feeding.schedules, hasLength(1));
    expect(push.permissionRequests, 0, reason: '"Not now" asks nothing');

    // The second: no question.
    appRouter(tester).go(AppRoutes.newFeeding('p1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add time'));
    await tester.pumpAndSettle();
    await enterPickerTime(tester, const TimeOfDay(hour: 8, minute: 0));
    await tapVisible(tester, find.text('Save'));
    expect(find.text('Allow notifications?'), findsNothing);
    expect(feeding.schedules, hasLength(2));
  });

  testWidgets('a push tapped while a form is open in Today opens on top of '
      'it', (tester) async {
    final push = FakePushPlatform();
    await pumpApp(
      tester,
      location: AppRoutes.newVisit,
      overrides: fakeRepositories(
        push: push,
        visits: FakeVisitsRepository(
          visits: [
            Visit(
              id: 'v1',
              type: VisitType.vet,
              title: 'Check-up',
              date: testToday().add(const Duration(days: 1)),
              time: const TimeOfDay(hour: 10, minute: 30),
              petIds: const [],
              remindMinutesBefore: const [1440, 120],
              status: VisitStatus.planned,
            ),
          ],
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Rabies vaccination'),
      'Typed, not saved',
    );

    push.tap({'kind': 'appointment', 'appointmentId': 'v1'});
    await tester.pumpAndSettle();
    expect(find.text('Check-up'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Typed, not saved'), findsOneWidget);
  });

  test('days are counted on the calendar, also across a clock change', () {
    // Europe moves the clocks on the last Sunday of March: that day has 23
    // hours wherever the tests run in such a zone.
    expect(
      calendarDaysBetween(DateTime(2027, 3, 27), DateTime(2027, 3, 28)),
      1,
    );
    expect(
      calendarDaysBetween(DateTime(2027, 3, 28, 23), DateTime(2027, 3, 29)),
      1,
    );
    expect(
      calendarDaysBetween(DateTime(2027, 3, 29), DateTime(2027, 3, 27)),
      -2,
    );
  });

  testWidgets('a push that arrives or is tapped reloads Today; a tapped '
      'visit push opens the visit', (tester) async {
    final today = FakeTodayRepository();
    final push = FakePushPlatform();
    await pumpApp(
      tester,
      location: AppRoutes.more,
      overrides: fakeRepositories(today: today, push: push),
    );
    final calls = today.calls;

    push.arrive({'kind': 'feeding', 'date': '2026-10-02', 'time': '08:00'});
    await tester.pumpAndSettle();
    push.tap({'kind': 'feeding'});
    await tester.pumpAndSettle();

    expect(today.calls, greaterThan(calls));
    expect(appRouter(tester).state.matchedLocation, AppRoutes.today);
  });

  testWidgets('back in the app, Today reloads', (tester) async {
    final today = FakeTodayRepository();
    await pumpApp(
      tester,
      location: AppRoutes.today,
      overrides: fakeRepositories(today: today),
    );
    final calls = today.calls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(today.calls, greaterThan(calls));
  });

  test('a tapped push opens its screen', () {
    expect(routeForPush({'kind': 'feeding'}), AppRoutes.today);
    // "Who fed", which replaced the reminder: Today, like the reminder.
    expect(routeForPush({'kind': 'feeding', 'update': '1'}), AppRoutes.today);
    expect(
      routeForPush({'kind': 'care', 'petId': 'p1', 'planId': 'x'}),
      AppRoutes.pet('p1', tab: PetTab.health),
    );
    expect(
      routeForPush({'kind': 'appointment', 'appointmentId': 'v1'}),
      AppRoutes.visit('v1'),
    );
    expect(routeForPush({'kind': 'test'}), isNull);
    expect(routeForPush({}), isNull);
  });

  test('the channels: "Who fed" is quiet, the reminders are not', () {
    final channels = {
      for (final channel in pushChannels(
        const PushChannelNames(
          feeding: 'Feeding',
          feedingUpdates: 'Who fed',
          care: 'Care',
          appointments: 'Visits',
          supplies: 'Supplies',
          general: 'Other',
        ),
      ))
        channel.id: channel,
    };

    expect(channels.keys, [
      'feeding',
      feedingUpdatesChannel,
      'care',
      'appointments',
      'supplies',
      'general',
    ]);
    expect(feedingUpdatesChannel, 'feeding-updates');
    final quiet = channels[feedingUpdatesChannel]!;
    expect(quiet.name, 'Who fed');
    expect(quiet.importance, Importance.low);
    expect(quiet.playSound, isFalse);
    expect(channels['feeding']!.importance, Importance.high);
  });

  testWidgets('the channels are named in the app\'s language', (tester) async {
    final push = FakePushPlatform();
    await pumpApp(
      tester,
      location: AppRoutes.more,
      language: 'ru',
      overrides: fakeRepositories(push: push),
    );

    expect(push.channels?.feeding, 'Кормление');
    expect(push.channels?.feedingUpdates, 'Кто покормил');
  });
}
