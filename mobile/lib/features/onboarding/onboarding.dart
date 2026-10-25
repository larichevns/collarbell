import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// When the onboarding opens by itself: once per account on this phone,
/// for a person starting from nothing: in exactly one group (their own, as
/// the server makes it at the first sign-in), which has no pets at all,
/// and where they can add them. Home asks once the person's groups and the
/// pets have loaded ([takeTurn]).
///
/// Anyone else never gets it by itself, and their turn is marked as taken
/// without showing it: a group with pets, even only a deceased or archived
/// one (people who used the app before the onboarding existed); someone in
/// two or more groups (a family member who joined keeps their own empty
/// group, and on a new phone the server may show that one: "Who lives with
/// you?" there would add the family's cat a second time); a helper. More →
/// "Getting to know the app" opens it any time, and takes the turn too
/// ([markSeen]).
abstract final class OnboardingTurn {
  /// Where the account [uid] has had its turn, saved on the phone. Per
  /// account: someone else signing in on this phone gets their own.
  static String keyFor(String uid) => 'onboarding.seen.$uid';

  /// Whether the onboarding should open now for [uid], who is in
  /// [households] groups; [hasPets] counts pets of any status. The turn is
  /// taken at once, whatever the answer, so it opens at most once, whatever
  /// rebuilds, reloads or group switches follow.
  static bool takeTurn(
    SharedPreferences preferences,
    String uid, {
    required int households,
    required bool canEdit,
    required bool hasPets,
  }) {
    if (preferences.getBool(keyFor(uid)) ?? false) return false;
    markSeen(preferences, uid);
    return households == 1 && canEdit && !hasPets;
  }

  /// The onboarding was shown to [uid] (opened from More, or by itself):
  /// it won't open by itself after that.
  static void markSeen(SharedPreferences preferences, String uid) {
    // The value is in memory at once; the write to the disk follows.
    unawaited(preferences.setBool(keyFor(uid), true));
  }
}
