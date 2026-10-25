import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api_providers.dart';

/// For forms that change something already saved: whether the form opened
/// while the server didn't answer, so from an offline copy. Its values may be
/// old, and saving them could undo newer changes (a plan done meanwhile, a
/// note edited on the other phone): such a form doesn't save, and says to
/// open it again once the server is back. Read once, when the form opens.
bool openedFromCopy(WidgetRef ref) =>
    !ref.read(serverReachabilityProvider).reachable;
