import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the phone's share sheet (messengers, mail, notes) with a text, e.g.
/// an invite code. Tests replace it.
final shareTextProvider = Provider<Future<void> Function(String text)>(
  (ref) =>
      (text) => SharePlus.instance.share(ShareParams(text: text)),
);
