import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../care/care_refresh.dart';
import '../care/care_repository.dart';
import '../documents/documents_repository.dart';
import '../passport/passport_repository.dart';
import '../pets/pets_repository.dart';
import 'ai_repository.dart';

/// Reloads everything a saved scan (or note) can change for [petId]: its
/// care (plans, every open plan screen, history, passport sections, Today,
/// and the weight log, with the weighings and check-up weights saved), the
/// pet (chips and tattoos), the passport header, the documents (the kept
/// photos) and the pet's scans and notes.
///
/// Like `refreshCare`, it goes through the [container], so it works after
/// the review screen is gone. Screens take the container before their first
/// `await`.
void refreshAfterScan(ProviderContainer container, String petId) {
  refreshCare(container, petId);
  // A "Done" moves the plans it names: any of them may be open.
  container.invalidate(carePlanProvider);
  container.invalidate(petProvider(petId));
  container.invalidate(petsProvider);
  container.invalidate(passportProvider(petId));
  container.invalidate(petDocumentsProvider(petId));
  refreshPetImports(container, petId);
  // A review still open (the save failed) checks against the pet as it is.
  container.invalidate(scanReviewDataProvider(petId));
}
