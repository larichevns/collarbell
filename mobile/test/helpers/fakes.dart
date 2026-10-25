import 'dart:async';
import 'dart:io' show Directory;

import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/data/live/realtime_client.dart';
import 'package:collarbell/features/account/account.dart';
import 'package:collarbell/features/account/account_repository.dart';
import 'package:collarbell/features/account/export_files.dart';
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/ai_repository.dart';
import 'package:collarbell/features/billing/billing_repository.dart';
import 'package:collarbell/features/billing/household_plan.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/care_repository.dart';
import 'package:collarbell/features/care/care_rules.dart';
import 'package:collarbell/features/documents/document.dart';
import 'package:collarbell/features/documents/documents_repository.dart';
import 'package:collarbell/features/feeding/feeding.dart';
import 'package:collarbell/features/feeding/feeding_repository.dart';
import 'package:collarbell/features/files/files_repository.dart';
import 'package:collarbell/features/files/media_picker.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/household/household_repository.dart';
import 'package:collarbell/features/me/me_repository.dart';
import 'package:collarbell/features/notifications/notifications.dart';
import 'package:collarbell/features/notifications/notifications_repository.dart';
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:collarbell/features/passport/passport.dart';
import 'package:collarbell/features/passport/passport_repository.dart';
import 'package:collarbell/features/pets/chip_reader.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/features/supplies/barcode_reader.dart';
import 'package:collarbell/features/supplies/supplies_repository.dart';
import 'package:collarbell/features/supplies/supply.dart';
import 'package:collarbell/features/today/today.dart';
import 'package:collarbell/features/today/today_repository.dart';
import 'package:collarbell/features/visits/visit.dart';
import 'package:collarbell/features/visits/visits_repository.dart';
import 'package:collarbell/features/weight/weight.dart';
import 'package:collarbell/features/weight/weight_repository.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart' show BuildContext, TimeOfDay;

const notFound = ApiException(ApiErrorKind.notFound, statusCode: 404);

/// Nothing deleted: a group's fate isn't the one the person was shown.
const deletionPlanChanged = ApiException(
  ApiErrorKind.conflict,
  statusCode: 409,
  problem: ProblemDetails(type: ProblemTypes.deletionPlanChanged, status: 409),
);
const conflict = ApiException(ApiErrorKind.conflict, statusCode: 409);
const networkError = ApiException(ApiErrorKind.network);

/// A 400 with field errors, as ASP.NET Core sends them.
ApiException validationProblem(Map<String, List<String>> errors) =>
    ApiException(
      ApiErrorKind.validation,
      statusCode: 400,
      problem: ProblemDetails(status: 400, errors: errors),
    );

/// A stored photo (or PDF) with made-up links.
StoredFile testFile(String id, {bool pdf = false}) => StoredFile(
  id: id,
  contentType: pdf ? 'application/pdf' : 'image/jpeg',
  sizeBytes: 1000,
  width: pdf ? null : 800,
  height: pdf ? null : 600,
  url: 'https://files.test/$id',
  thumbnailUrl: pdf ? null : 'https://files.test/$id-thumb',
  expiresAt: DateTime.utc(2030),
);

/// The pet the server would return for [input].
Pet petFromInput(String id, PetInput input, {StoredFile? photo}) => Pet(
  id: id,
  name: input.name,
  species: input.species,
  breed: input.breed,
  sex: input.sex,
  birthDate: input.birthDate,
  birthDateApproximate: input.birthDateApproximate,
  neutered: input.neutered,
  neuteredOn: input.neuteredOn,
  color: input.color,
  markings: input.markings,
  allergies: input.allergies,
  notes: input.notes,
  photo: photo,
  identifiers: input.identifiers,
);

class FakePetsRepository implements PetsRepository {
  FakePetsRepository([List<Pet> pets = const []]) : pets = [...pets];

  List<Pet> pets;

  /// When set, [getPets] and [getPet] throw it.
  Object? error;

  /// When set, [createPet] and [updatePet] throw it, e.g. a 400.
  Object? saveError;
  int calls = 0;

  /// Every [getPet] call.
  int petCalls = 0;
  final created = <PetInput>[];
  final updated = <(String, PetInput)>[];
  final deleted = <String>[];
  final photosSet = <(String, String)>[];
  final photosRemoved = <String>[];

  /// What reading a photo of a chip gives, or an error to throw.
  Object? identifierScanResult;

  /// The photos of every [scanIdentifiers] call, and the tokens that could
  /// call them off.
  final identifierScans = <List<String>>[];
  final identifierScanTokens = <CancelToken?>[];

  /// When set, a reading waits until it completes: AI takes its time.
  Completer<void>? identifierScanGate;

  @override
  Future<List<Pet>> getPets() async {
    calls++;
    final error = this.error;
    if (error != null) throw error;
    return [...pets];
  }

  @override
  Future<Pet> getPet(String id) async {
    petCalls++;
    final error = this.error;
    if (error != null) throw error;
    return pets.firstWhere((pet) => pet.id == id, orElse: () => throw notFound);
  }

  @override
  Future<Pet> createPet(PetInput input) async {
    final error = saveError;
    if (error != null) throw error;
    created.add(input);
    final pet = petFromInput('new-${created.length}', input);
    pets.add(pet);
    return pet;
  }

  @override
  Future<Pet> updatePet(String id, PetInput input) async {
    final error = saveError;
    if (error != null) throw error;
    updated.add((id, input));
    final old = await getPet(id);
    final pet = petFromInput(id, input, photo: old.photo);
    pets[pets.indexOf(old)] = pet;
    return pet;
  }

  @override
  Future<void> deletePet(String id) async {
    deleted.add(id);
    pets.removeWhere((pet) => pet.id == id);
  }

  @override
  Future<Pet> setPhoto(String petId, String fileId) async {
    photosSet.add((petId, fileId));
    final old = await getPet(petId);
    final pet = withPhoto(old, testFile(fileId));
    pets[pets.indexOf(old)] = pet;
    return pet;
  }

  @override
  Future<void> removePhoto(String petId) async {
    photosRemoved.add(petId);
    final old = await getPet(petId);
    pets[pets.indexOf(old)] = withPhoto(old, null);
  }

  @override
  Future<List<IdentifierReading>> scanIdentifiers(
    List<String> fileIds, {
    CancelToken? cancelToken,
  }) async {
    identifierScans.add(fileIds);
    identifierScanTokens.add(cancelToken);
    final gate = identifierScanGate;
    if (gate != null) await gate.future;
    if (cancelToken?.isCancelled ?? false) {
      throw const ApiException(ApiErrorKind.cancelled);
    }
    final result = identifierScanResult;
    if (result is List<IdentifierReading>) return result;
    if (result != null) throw result;
    return const [];
  }

  /// [pet] with another photo.
  static Pet withPhoto(Pet pet, StoredFile? photo) => Pet(
    id: pet.id,
    name: pet.name,
    species: pet.species,
    breed: pet.breed,
    sex: pet.sex,
    birthDate: pet.birthDate,
    birthDateApproximate: pet.birthDateApproximate,
    neutered: pet.neutered,
    neuteredOn: pet.neuteredOn,
    color: pet.color,
    markings: pet.markings,
    allergies: pet.allergies,
    notes: pet.notes,
    status: pet.status,
    photo: photo,
    identifiers: pet.identifiers,
  );
}

class FakeFilesRepository implements FilesRepository {
  final uploads = <PickedMedia>[];

  /// When set, [upload] throws it, e.g. a 413.
  Object? error;

  /// When set, uploads wait until it completes: a slow connection.
  Completer<void>? gate;

  @override
  Future<StoredFile> upload(PickedMedia media) async {
    final gate = this.gate;
    if (gate != null) await gate.future;
    final error = this.error;
    if (error != null) throw error;
    uploads.add(media);
    return testFile('upload-${uploads.length}', pdf: media.isPdf);
  }

  @override
  Future<StoredFile> getLink(String fileId) async => testFile(fileId);
}

class FakePassportRepository implements PassportRepository {
  FakePassportRepository([this.passport = const Passport()]);

  Passport passport;

  /// Every save request, including the refused ones.
  final attempts = <(String, Passport)>[];
  final saved = <(String, Passport)>[];

  /// When set, [savePassport] throws it, e.g. a 400.
  Object? saveError;

  var getCalls = 0;

  @override
  Future<Passport> getPassport(String petId) async {
    getCalls++;
    return passport;
  }

  @override
  Future<Passport> savePassport(String petId, Passport passport) async {
    attempts.add((petId, passport));
    final error = saveError;
    if (error != null) throw error;
    saved.add((petId, passport));
    return this.passport = Passport(
      model: passport.model,
      number: passport.number,
      issuingCountry: passport.issuingCountry,
      issuedOn: passport.issuedOn,
      issuer: passport.issuer,
      owners: passport.owners,
      notes: passport.notes,
      updatedAt: DateTime.utc(2026, 10, 1),
    );
  }
}

/// Works like the API: details and pages change separately, pages are
/// appended or removed one by one, and removing the last page deletes the
/// document.
class FakeDocumentsRepository implements DocumentsRepository {
  FakeDocumentsRepository([List<PetDocument> documents = const []])
    : documents = [...documents];

  /// Newest first, as the API sends them.
  List<PetDocument> documents;

  /// When set, [createDocument] throws it, e.g. a network error.
  Object? createError;
  final created = <(String, DocumentDetails, List<String>)>[];
  final detailsUpdated = <(String, DocumentDetails)>[];
  final pagesAdded = <(String, List<String>)>[];
  final pagesRemoved = <(String, String)>[];
  final deleted = <String>[];

  /// Ids of the pages of the document [id], in order.
  List<String> pageIds(String id) => [
    for (final page in documents.firstWhere((d) => d.id == id).pages) page.id,
  ];

  var listCalls = 0;

  @override
  Future<List<PetDocument>> getDocuments(String petId) async {
    listCalls++;
    return [
      for (final document in documents)
        if (document.petId == petId) document,
    ];
  }

  @override
  Future<PetDocument> getDocument(String id) async => documents.firstWhere(
    (document) => document.id == id,
    orElse: () => throw notFound,
  );

  @override
  Future<PetDocument> createDocument(
    String petId,
    DocumentDetails details,
    List<String> fileIds,
  ) async {
    final error = createError;
    if (error != null) throw error;
    created.add((petId, details, fileIds));
    final document = _document('doc-new-${created.length}', petId, details, [
      for (final fileId in fileIds) testFile(fileId),
    ]);
    documents.insert(0, document);
    return document;
  }

  @override
  Future<PetDocument> updateDetails(String id, DocumentDetails details) async {
    detailsUpdated.add((id, details));
    final old = await getDocument(id);
    return _replace(old, _document(id, old.petId, details, old.pages));
  }

  @override
  Future<PetDocument> addPages(String id, List<String> fileIds) async {
    pagesAdded.add((id, fileIds));
    final old = await getDocument(id);
    return _replace(
      old,
      _document(id, old.petId, _detailsOf(old), [
        ...old.pages,
        for (final fileId in fileIds) testFile(fileId),
      ]),
    );
  }

  @override
  Future<void> removePage(String documentId, String fileId) async {
    pagesRemoved.add((documentId, fileId));
    final old = await getDocument(documentId);
    final pages = [
      for (final page in old.pages)
        if (page.id != fileId) page,
    ];
    if (pages.isEmpty) {
      documents.remove(old);
    } else {
      _replace(old, _document(documentId, old.petId, _detailsOf(old), pages));
    }
  }

  @override
  Future<void> deleteDocument(String id) async {
    deleted.add(id);
    documents.removeWhere((document) => document.id == id);
  }

  PetDocument _replace(PetDocument old, PetDocument document) {
    documents[documents.indexOf(old)] = document;
    return document;
  }

  static DocumentDetails _detailsOf(PetDocument document) => DocumentDetails(
    type: document.type,
    title: document.title,
    documentDate: document.documentDate,
    notes: document.notes,
  );

  static PetDocument _document(
    String id,
    String? petId,
    DocumentDetails details,
    List<StoredFile> pages,
  ) {
    return PetDocument(
      id: id,
      petId: petId,
      type: details.type,
      title: details.title,
      documentDate: details.documentDate,
      notes: details.notes,
      pages: pages,
      createdAt: DateTime.utc(2026, 10, 1),
    );
  }
}

/// Returns prepared files instead of opening the camera, library, Files or
/// the document scanner.
class FakeMediaPicker implements MediaPicker {
  /// One photo per [takePhoto] call, in order; then null (the user cancels).
  final camera = <PickedMedia>[];
  var library = <PickedMedia>[];
  PickedMedia? pdf;

  /// The pages the document scanner returns; null: the user cancels.
  List<PickedMedia>? scanned;

  /// The scanner can't run here, as in a simulator.
  var scannerUnavailable = false;

  /// When set, the scanner stays open until it completes.
  Completer<void>? scanGate;

  /// The page limit of every [scanPages] call, and the limit of every
  /// [pickPhotos] call.
  final scanLimits = <int>[];
  final photoLimits = <int?>[];

  /// The paths of every file the app deleted.
  final deleted = <String>[];

  @override
  Future<PickedMedia?> takePhoto() async =>
      camera.isEmpty ? null : camera.removeAt(0);

  @override
  Future<PickedMedia?> pickPhoto() async =>
      library.isEmpty ? null : library.first;

  /// All of [library], whatever the limit: the app must cope with more.
  @override
  Future<List<PickedMedia>> pickPhotos({int? limit}) async {
    photoLimits.add(limit);
    return [...library];
  }

  @override
  Future<PickedMedia?> pickPdf() async => pdf;

  @override
  Future<List<PickedMedia>?> scanPages({required int maxPages}) async {
    scanLimits.add(maxPages);
    final gate = scanGate;
    if (gate != null) await gate.future;
    if (scannerUnavailable) {
      throw const ScannerUnavailableException('UNAVAILABLE: a simulator');
    }
    final scanned = this.scanned;
    return scanned == null ? null : [...scanned];
  }

  /// The pages of every [prepareScans] call.
  final prepared = <List<PickedMedia>>[];

  /// When set, [prepareScans] waits for it.
  Completer<void>? prepareGate;

  @override
  Future<List<PickedMedia>> prepareScans(List<PickedMedia> pages) async {
    prepared.add(pages);
    final gate = prepareGate;
    if (gate != null) await gate.future;
    return pages;
  }

  @override
  Future<void> deletePicked(List<PickedMedia> media) async {
    deleted.addAll([for (final item in media) item.path]);
  }
}

/// A household of the user, for [FakeMeRepository].
HouseholdSummary testHousehold(
  String id, {
  String name = 'Home',
  HouseholdRole role = HouseholdRole.owner,
  int memberCount = 1,
}) => HouseholdSummary(
  id: id,
  name: name,
  role: role,
  timeZone: 'Europe/Berlin',
  memberCount: memberCount,
);

/// `/me` as the server answers it: for the household the request names
/// ([selected], set by `pumpApp`), or the first one when it names none or
/// one the user isn't in any more.
class FakeMeRepository implements MeRepository {
  FakeMeRepository({List<HouseholdSummary>? households})
    : households = households ?? [testHousehold(homeId)];

  static const homeId = '0199a3b2-0000-7000-8000-000000000002';

  /// The user's households, the first-joined first.
  List<HouseholdSummary> households;

  /// The household the app names in its requests (`X-Household`).
  String? Function() selected = () => null;

  final updates = <({String? locale, String? timeZone})>[];
  var getCalls = 0;

  UserProfile get profile {
    final asked = selected();
    final current = households.firstWhere(
      (household) => household.id == asked,
      orElse: () => households.first,
    );
    return UserProfile(
      id: '0199a3b2-0000-7000-8000-000000000001',
      email: 'dev@collarbell.local',
      locale: 'en',
      timeZone: 'Europe/Berlin',
      household: Household(
        id: current.id,
        name: current.name,
        timeZone: current.timeZone,
        role: current.role,
      ),
      households: [...households],
    );
  }

  @override
  Future<UserProfile> getMe() async {
    getCalls++;
    return profile;
  }

  @override
  Future<UserProfile> updateMe({
    String? displayName,
    String? locale,
    String? timeZone,
  }) async {
    updates.add((locale: locale, timeZone: timeZone));
    return profile;
  }
}

/// A person of a household, for [FakeHouseholdRepository].
HouseholdMember testMember(
  String userId, {
  String? name,
  String? email,
  HouseholdRole role = HouseholdRole.member,
  bool isMe = false,
}) => HouseholdMember(
  userId: userId,
  displayName: name,
  email: email,
  role: role,
  joinedAt: DateTime(2026, 10, 1),
  isMe: isMe,
);

/// An open invite, valid for 7 more days.
HouseholdInvite testInvite(
  String id, {
  String code = 'ABCD-2345',
  HouseholdRole role = HouseholdRole.helper,
}) {
  final now = DateTime.now();
  return HouseholdInvite(
    id: id,
    code: code,
    role: role,
    createdAt: now,
    expiresAt: now.add(const Duration(days: 7)),
  );
}

/// The household on screen, its people and invites, kept in memory like
/// the server would: changes show on the next [getCurrent]. With [me], the
/// user's list of households follows: a created or joined one is added, one
/// left or deleted is gone.
class FakeHouseholdRepository implements HouseholdRepository {
  FakeHouseholdRepository({
    this.id = FakeMeRepository.homeId,
    this.name = 'Home',
    this.role = HouseholdRole.owner,
    this.me,
    List<HouseholdMember>? members,
    List<HouseholdInvite>? invites,
  }) : members =
           members ??
           [
             testMember(
               'me',
               name: 'Anna',
               email: 'anna@example.com',
               role: role,
               isMe: true,
             ),
           ],
       invites = invites ?? [];

  String id;
  String name;

  /// The user's own role.
  HouseholdRole role;
  final FakeMeRepository? me;
  List<HouseholdMember> members;
  List<HouseholdInvite> invites;

  /// When set, the next change throws it (e.g. a 409 for the last owner).
  Object? changeError;

  /// What codes invite to; any other code is a 404.
  final previews = <String, InvitePreview>{};

  /// What accepting a code joins; when null, a new household.
  HouseholdSummary? joined;

  /// When set, [previewInvite] or [acceptInvite] throws it.
  Object? previewError;
  Object? acceptError;

  var getCalls = 0;
  final created = <String>[];
  final renamed = <String>[];
  final roleChanges = <(String, HouseholdRole)>[];
  final removed = <String>[];
  final newInvites = <HouseholdRole>[];
  final revoked = <String>[];
  final previewed = <String>[];
  final accepted = <String>[];
  var deleted = 0;

  /// The household every change named, in order.
  final changedIn = <String>[];

  HouseholdDetails get details => HouseholdDetails(
    id: id,
    name: name,
    timeZone: 'Europe/Berlin',
    role: role,
    members: [...members],
    // Only owners see the invites.
    invites: role == HouseholdRole.owner ? [...invites] : const [],
  );

  void _change(String householdId) {
    changedIn.add(householdId);
    final error = changeError;
    if (error != null) throw error;
  }

  @override
  Future<HouseholdSummary> createHousehold(String name) async {
    final error = changeError;
    if (error != null) throw error;
    created.add(name);
    final household = testHousehold('new-${created.length}', name: name);
    me?.households.add(household);
    return household;
  }

  /// The user isn't in the household on screen any more.
  void _gone() => me?.households.removeWhere((household) => household.id == id);

  @override
  Future<HouseholdDetails> getCurrent() async {
    getCalls++;
    return details;
  }

  @override
  Future<HouseholdDetails> rename(String householdId, String name) async {
    _change(householdId);
    renamed.add(name);
    this.name = name;
    return details;
  }

  @override
  Future<HouseholdDetails> changeRole(
    String householdId,
    String userId,
    HouseholdRole role,
  ) async {
    _change(householdId);
    roleChanges.add((userId, role));
    members = [
      for (final member in members)
        member.userId == userId
            ? testMember(
                member.userId,
                name: member.displayName,
                email: member.email,
                role: role,
                isMe: member.isMe,
              )
            : member,
    ];
    if (members.any((member) => member.isMe && member.userId == userId)) {
      this.role = role;
    }
    return details;
  }

  @override
  Future<void> removeMember(String householdId, String userId) async {
    _change(householdId);
    removed.add(userId);
    if (members.any((member) => member.isMe && member.userId == userId)) {
      _gone();
    }
    members = [
      for (final member in members)
        if (member.userId != userId) member,
    ];
  }

  @override
  Future<void> delete(String householdId) async {
    _change(householdId);
    deleted++;
    _gone();
  }

  @override
  Future<HouseholdInvite> createInvite(
    String householdId,
    HouseholdRole role,
  ) async {
    _change(householdId);
    newInvites.add(role);
    final invite = testInvite(
      'invite-${newInvites.length}',
      code: 'WXYZ-678${newInvites.length}',
      role: role,
    );
    invites = [...invites, invite];
    return invite;
  }

  @override
  Future<void> revokeInvite(String householdId, String inviteId) async {
    _change(householdId);
    revoked.add(inviteId);
    invites = [
      for (final invite in invites)
        if (invite.id != inviteId) invite,
    ];
  }

  @override
  Future<InvitePreview> previewInvite(String code) async {
    previewed.add(code);
    final error = previewError;
    if (error != null) throw error;
    return previews[code] ?? (throw notFound);
  }

  @override
  Future<HouseholdSummary> acceptInvite(String code) async {
    accepted.add(code);
    final error = acceptError;
    if (error != null) throw error;
    final preview = previews[code];
    if (preview == null) throw notFound;
    final household =
        joined ??
        testHousehold(
          'joined',
          name: preview.householdName,
          role: preview.role,
          memberCount: 2,
        );
    me?.households.add(household);
    return household;
  }
}

/// A group's plan as the server answers it: Free, 7 of 20 AI photos used,
/// counted from zero again on November 1.
HouseholdPlan testHouseholdPlan({
  PlanKind kind = PlanKind.free,
  DateTime? expiresAt,
  int? aiPhotosPerMonth,
  int aiPhotosUsed = 7,
}) => HouseholdPlan(
  kind: kind,
  expiresAt: expiresAt,
  aiPhotosPerMonth: aiPhotosPerMonth ?? (kind == PlanKind.premium ? 300 : 20),
  aiPhotosUsed: aiPhotosUsed,
  resetsAt: DateTime(2026, 11, 1),
  premiumAiPhotosPerMonth: 300,
);

/// The plan of the group the request names ([household], set by the test
/// like the X-Household header), else [plan].
class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({
    HouseholdPlan? plan,
    Map<String, HouseholdPlan>? byHousehold,
  }) : plan = plan ?? testHouseholdPlan(),
       byHousehold = byHousehold ?? {};

  HouseholdPlan plan;

  /// Other groups' plans, by group id.
  final Map<String, HouseholdPlan> byHousehold;

  /// The group the requests name.
  String? Function() household = () => null;

  /// When set, [getPlan] throws it.
  Object? error;
  var calls = 0;

  @override
  Future<HouseholdPlan> getPlan() async {
    calls++;
    final error = this.error;
    if (error != null) throw error;
    return byHousehold[household()] ?? plan;
  }
}

/// Shares nothing, and remembers what would have been shared.
class FakeShare {
  final texts = <String>[];

  Future<void> share(String text) async => texts.add(text);
}

/// Today as a calendar date, like the server's "today".
DateTime testToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Days from today to [date] (negative when it has passed).
int daysFromToday(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day)
        .difference(
          DateTime.utc(testToday().year, testToday().month, testToday().day),
        )
        .inDays;

/// A plan as the server would return it, due in [daysLeft] days.
CarePlan testPlan(
  String id, {
  String petId = 'p1',
  CareKind kind = CareKind.deworming,
  String title = 'Deworming',
  CareInterval? interval = const CareInterval(3, IntervalUnit.month),
  int daysLeft = 5,
  bool active = true,
  DateTime? lastDoneOn,
  String? defaultProduct,
  List<VaccineTarget> targets = const [],
  String? presetCode,
  bool intervalUnknown = false,
  bool hasUnknownValues = false,
}) {
  final today = testToday();
  return CarePlan(
    id: id,
    petId: petId,
    kind: kind,
    title: title,
    interval: interval,
    intervalUnknown: intervalUnknown,
    nextDueOn: DateTime(today.year, today.month, today.day + daysLeft),
    status: statusFor(active: active, daysLeft: daysLeft),
    daysLeft: daysLeft,
    lastDoneOn: lastDoneOn,
    defaultProduct: defaultProduct,
    targets: targets,
    presetCode: presetCode,
    active: active,
    hasUnknownValues: hasUnknownValues,
  );
}

/// A record as the server would return it.
CareRecord testRecord(
  String id, {
  String petId = 'p1',
  String? planId,
  CareKind kind = CareKind.vaccination,
  String title = 'Rabies',
  DateTime? performedOn,
  String? product,
  String? batchNumber,
  DateTime? validFrom,
  DateTime? validUntil,
  List<VaccineTarget> targets = const [],
  double? weightKg,
  CareRecordDetails details = CareRecordDetails.empty,
  List<StoredFile> files = const [],
  bool hasUnknownValues = false,
}) => CareRecord(
  id: id,
  petId: petId,
  planId: planId,
  kind: kind,
  title: title,
  performedOn: performedOn ?? DateTime(2025, 3, 1),
  product: product,
  batchNumber: batchNumber,
  validFrom: validFrom,
  validUntil: validUntil,
  targets: targets,
  weightKg: weightKg,
  details: details,
  files: files,
  hasUnknownValues: hasUnknownValues,
);

/// Some presets from the server's catalog: two for cats, three for dogs
/// (one of them dog-only).
const testPresets = [
  CarePreset(
    code: 'cat-rabies',
    species: PetSpecies.cat,
    kind: CareKind.vaccination,
    title: 'Rabies',
    interval: CareInterval(1, IntervalUnit.year),
    targets: [VaccineTarget.rabies],
    note: 'The vaccine label says 1 or 3 years.',
  ),
  CarePreset(
    code: 'cat-deworm',
    species: PetSpecies.cat,
    kind: CareKind.deworming,
    title: 'Deworming',
    interval: CareInterval(3, IntervalUnit.month),
    note: 'When the risk is unknown: at least 4 times a year.',
  ),
  CarePreset(
    code: 'dog-rabies',
    species: PetSpecies.dog,
    kind: CareKind.vaccination,
    title: 'Rabies',
    interval: CareInterval(1, IntervalUnit.year),
    targets: [VaccineTarget.rabies],
  ),
  CarePreset(
    code: 'dog-advantix',
    species: PetSpecies.dog,
    kind: CareKind.fleaTick,
    title: 'K9 Advantix',
    interval: CareInterval(1, IntervalUnit.month),
    dogOnly: true,
    note: 'Contains permethrin, which is toxic to cats.',
  ),
  CarePreset(
    code: 'dog-echinococcus',
    species: PetSpecies.dog,
    kind: CareKind.echinococcus,
    title: 'Tapeworm treatment before travel',
  ),
];

/// Works like the API: "Done" adds a record and moves the plan (a one-off
/// finishes), records never move plans, photos are added and removed one
/// by one (at most 10 per record), and the passport sections are built from
/// the records. A retry of "Done", of adding a plan or of adding a record
/// with the same request id gets the first result; a plan is done once per
/// day; attaching a photo that is already there changes nothing. Something
/// deleted (removed from the lists by a test) is "not found".
class FakeCareRepository implements CareRepository {
  FakeCareRepository({
    List<CarePreset> presets = testPresets,
    List<CarePlan> plans = const [],
    List<CareRecord> records = const [],
  }) : presets = [...presets],
       plans = [...plans],
       records = [...records];

  List<CarePreset> presets;

  /// In the server's order: active first, soonest first.
  List<CarePlan> plans;

  /// Newest first.
  List<CareRecord> records;

  final presetRequests = <PetSpecies>[];
  final createdPlans = <(String, CarePlanInput)>[];
  final updatedPlans = <(String, CarePlanInput)>[];
  final deletedPlans = <String>[];
  final completions = <(String, CompletionInput)>[];

  /// The request id of every "Done" and every new record sent, retries
  /// included.
  final completeRequestIds = <String>[];
  final createRequestIds = <String>[];
  final createPlanRequestIds = <String>[];
  final _doneByRequest = <String, ({CarePlan plan, CareRecord record})>{};
  final _doneByPlanAndDay = <String, ({CarePlan plan, CareRecord record})>{};
  final _recordIdByRequest = <String, String>{};
  final _planIdByRequest = <String, String>{};

  /// When set, the next "Done" or new record goes through on the "server",
  /// but the app gets a network error, as when the response is lost.
  var loseNextCompleteResponse = false;
  var loseNextCreateResponse = false;
  var loseNextCreatePlanResponse = false;
  final createdRecords = <(String, CareRecordInput)>[];
  final updatedRecords = <(String, CareRecordInput)>[];
  final deletedRecords = <String>[];
  final filesAdded = <(String, String)>[];
  final filesRemoved = <(String, String)>[];
  var planListCalls = 0;
  var recordListCalls = 0;

  /// Every [getPlan] (one plan) and [getPassportRecords] call.
  var planCalls = 0;
  var passportRecordCalls = 0;

  /// When set, these calls throw it, e.g. a 400 or a network error.
  Object? savePlanError;
  Object? completeError;
  Object? saveRecordError;
  Object? addFileError;

  /// When set, "Done" waits until it completes: a slow connection.
  Completer<void>? completeGate;

  /// When set, adding a plan waits until it completes.
  Completer<void>? savePlanGate;

  @override
  Future<List<CarePreset>> getPresets(PetSpecies species) async {
    presetRequests.add(species);
    return [
      for (final preset in presets)
        if (preset.species == null || preset.species == species) preset,
    ];
  }

  @override
  Future<List<CarePlan>> getPlans(String petId) async {
    planListCalls++;
    return [
      for (final plan in plans)
        if (plan.petId == petId) plan,
    ];
  }

  @override
  Future<CarePlan> getPlan(String id) async {
    planCalls++;
    return plans.firstWhere(
      (plan) => plan.id == id,
      orElse: () => throw notFound,
    );
  }

  @override
  Future<CarePlan> createPlan(
    String petId,
    CarePlanInput input, {
    required String requestId,
  }) async {
    final gate = savePlanGate;
    if (gate != null) await gate.future;
    final error = savePlanError;
    if (error != null) throw error;
    createPlanRequestIds.add(requestId);
    final earlier = _planIdByRequest[requestId];
    if (earlier != null) return getPlan(earlier);
    createdPlans.add((petId, input));
    final plan = _plan('plan-new-${createdPlans.length}', petId, input, null);
    plans.add(plan);
    _planIdByRequest[requestId] = plan.id;
    if (loseNextCreatePlanResponse) {
      loseNextCreatePlanResponse = false;
      throw const ApiException(ApiErrorKind.network);
    }
    return plan;
  }

  @override
  Future<CarePlan> updatePlan(String id, CarePlanInput input) async {
    final error = savePlanError;
    if (error != null) throw error;
    updatedPlans.add((id, input));
    final old = await getPlan(id);
    final plan = _plan(id, old.petId, input, old);
    plans[plans.indexOf(old)] = plan;
    return plan;
  }

  @override
  Future<void> deletePlan(String id) async {
    deletedPlans.add(id);
    plans.removeWhere((plan) => plan.id == id);
  }

  @override
  Future<({CarePlan plan, CareRecord record})> completePlan(
    String id,
    CompletionInput input, {
    required String requestId,
  }) async {
    final gate = completeGate;
    if (gate != null) await gate.future;
    final error = completeError;
    if (error != null) throw error;
    completeRequestIds.add(requestId);
    final earlier = _doneByRequest[requestId];
    if (earlier != null) return earlier;
    final old = await getPlan(id);
    // Done once per day: the same plan and day give the first answer again.
    final day = '$id ${input.performedOn}';
    final sameDay = _doneByPlanAndDay[day];
    if (sameDay != null) return sameDay;
    completions.add((id, input));
    final next = nextDueAfterDone(
      interval: old.interval,
      performedOn: input.performedOn,
      validUntil: input.validUntil,
      chosen: input.nextDueOn,
    );
    final nextDueOn = next ?? input.validUntil ?? old.nextDueOn;
    final active = next != null && old.active;
    final plan = CarePlan(
      id: old.id,
      petId: old.petId,
      kind: old.kind,
      title: old.title,
      interval: old.interval,
      nextDueOn: nextDueOn,
      status: statusFor(active: active, daysLeft: daysFromToday(nextDueOn)),
      daysLeft: daysFromToday(nextDueOn),
      lastDoneOn: input.performedOn,
      defaultProduct: old.defaultProduct,
      targets: old.targets,
      presetCode: old.presetCode,
      notes: old.notes,
      active: active,
    );
    plans[plans.indexOf(old)] = plan;
    final record = CareRecord(
      id: 'rec-done-${completions.length}',
      petId: old.petId,
      planId: old.id,
      kind: old.kind,
      title: old.title,
      performedOn: input.performedOn,
      performedTime: input.performedTime,
      product: input.product,
      manufacturer: input.manufacturer,
      batchNumber: input.batchNumber,
      validFrom: input.validFrom,
      validUntil: input.validUntil,
      targets: old.targets,
      clinic: input.clinic,
      veterinarian: input.veterinarian,
      notes: input.notes,
    );
    records.insert(0, record);
    final done = (plan: plan, record: record);
    _doneByRequest[requestId] = done;
    _doneByPlanAndDay[day] = done;
    if (loseNextCompleteResponse) {
      loseNextCompleteResponse = false;
      throw const ApiException(ApiErrorKind.network);
    }
    return done;
  }

  @override
  Future<List<CareRecord>> getRecords(String petId) async {
    recordListCalls++;
    return [
      for (final record in records)
        if (record.petId == petId) record,
    ];
  }

  @override
  Future<CareRecord> getRecord(String id) async => records.firstWhere(
    (record) => record.id == id,
    orElse: () => throw notFound,
  );

  @override
  Future<CareRecord> createRecord(
    String petId,
    CareRecordInput input, {
    required String requestId,
  }) async {
    final error = saveRecordError;
    if (error != null) throw error;
    createRequestIds.add(requestId);
    final earlier = _recordIdByRequest[requestId];
    if (earlier != null) return getRecord(earlier);
    createdRecords.add((petId, input));
    final record = _record(
      'rec-new-${createdRecords.length}',
      petId,
      input,
      const [],
    );
    records.insert(0, record);
    _recordIdByRequest[requestId] = record.id;
    if (loseNextCreateResponse) {
      loseNextCreateResponse = false;
      throw const ApiException(ApiErrorKind.network);
    }
    return record;
  }

  @override
  Future<CareRecord> updateRecord(String id, CareRecordInput input) async {
    final error = saveRecordError;
    if (error != null) throw error;
    updatedRecords.add((id, input));
    final old = await getRecord(id);
    return _replace(old, _record(id, old.petId, input, old.files));
  }

  @override
  Future<void> deleteRecord(String id) async {
    deletedRecords.add(id);
    records.removeWhere((record) => record.id == id);
  }

  @override
  Future<CareRecord> addRecordFile(String recordId, String fileId) async {
    final error = addFileError;
    if (error != null) throw error;
    filesAdded.add((recordId, fileId));
    final old = await getRecord(recordId);
    // Already there (a retry after a lost response): nothing changes.
    if (old.files.any((file) => file.id == fileId)) return old;
    if (old.files.length >= CareRecord.maxFiles) {
      throw const ApiException(
        ApiErrorKind.validation,
        statusCode: 400,
        problem: ProblemDetails(
          status: 400,
          errors: {
            'fileIds': ['A record has 10 files or fewer.'],
          },
        ),
      );
    }
    return _replace(old, _withFiles(old, [...old.files, testFile(fileId)]));
  }

  @override
  Future<void> removeRecordFile(String recordId, String fileId) async {
    filesRemoved.add((recordId, fileId));
    // Like the API repository: a photo (or record) that is gone is no error.
    final old = records.where((r) => r.id == recordId).firstOrNull;
    if (old == null) return;
    _replace(
      old,
      _withFiles(old, [
        for (final file in old.files)
          if (file.id != fileId) file,
      ]),
    );
  }

  @override
  Future<PassportRecords> getPassportRecords(String petId) async {
    passportRecordCalls++;
    final oldestFirst = [
      for (final record in records.reversed)
        if (record.petId == petId) record,
    ]..sort((a, b) => a.performedOn.compareTo(b.performedOn));
    bool rabies(CareRecord r) =>
        r.kind == CareKind.vaccination &&
        r.targets.contains(VaccineTarget.rabies);
    List<CareRecord> section(bool Function(CareRecord) belongs) => [
      for (final record in oldestFirst)
        if (belongs(record)) record,
    ];
    return PassportRecords(
      rabies: section(rabies),
      rabiesTiters: section((r) => r.kind == CareKind.rabiesTiter),
      echinococcus: section((r) => r.kind == CareKind.echinococcus),
      treatments: section(
        (r) =>
            r.kind == CareKind.deworming ||
            r.kind == CareKind.fleaTick ||
            r.kind == CareKind.heartworm,
      ),
      otherVaccinations: section(
        (r) => r.kind == CareKind.vaccination && !rabies(r),
      ),
      examinations: section((r) => r.kind == CareKind.vetExam),
    );
  }

  /// Ids of the photos of the record [id], in order.
  List<String> fileIds(String id) => [
    for (final file in records.firstWhere((r) => r.id == id).files) file.id,
  ];

  CareRecord _replace(CareRecord old, CareRecord record) {
    records[records.indexOf(old)] = record;
    return record;
  }

  static CarePlan _plan(
    String id,
    String petId,
    CarePlanInput input,
    CarePlan? old,
  ) {
    final active = input.active ?? old?.active ?? true;
    final daysLeft = daysFromToday(input.nextDueOn);
    return CarePlan(
      id: id,
      petId: petId,
      kind: input.kind,
      title: input.title,
      interval: input.interval,
      nextDueOn: input.nextDueOn,
      status: statusFor(active: active, daysLeft: daysLeft),
      daysLeft: daysLeft,
      lastDoneOn: old?.lastDoneOn,
      remindOffsetsDays: input.remindOffsetsDays ?? const [7, 1, 0],
      defaultProduct: input.defaultProduct,
      targets: input.targets,
      presetCode: input.presetCode,
      notes: input.notes,
      active: active,
    );
  }

  static CareRecord _record(
    String id,
    String petId,
    CareRecordInput input,
    List<StoredFile> files,
  ) => CareRecord(
    id: id,
    petId: petId,
    kind: input.kind,
    title: input.title,
    performedOn: input.performedOn,
    performedTime: input.performedTime,
    product: input.product,
    manufacturer: input.manufacturer,
    batchNumber: input.batchNumber,
    validFrom: input.validFrom,
    validUntil: input.validUntil,
    targets: input.targets,
    clinic: input.clinic,
    veterinarian: input.veterinarian,
    weightKg: input.weightKg,
    details: input.details,
    notes: input.notes,
    files: files,
  );

  static CareRecord _withFiles(CareRecord r, List<StoredFile> files) =>
      CareRecord(
        id: r.id,
        petId: r.petId,
        planId: r.planId,
        kind: r.kind,
        title: r.title,
        performedOn: r.performedOn,
        performedTime: r.performedTime,
        product: r.product,
        manufacturer: r.manufacturer,
        batchNumber: r.batchNumber,
        validFrom: r.validFrom,
        validUntil: r.validUntil,
        targets: r.targets,
        clinic: r.clinic,
        veterinarian: r.veterinarian,
        weightKg: r.weightKg,
        details: r.details,
        notes: r.notes,
        source: r.source,
        files: files,
        hasUnknownValues: r.hasUnknownValues,
      );
}

/// Today as the server builds it: the active plans of active pets that are
/// overdue or due within 30 days, soonest first. Without a [care] fake it
/// returns [items].
class FakeTodayRepository implements TodayRepository {
  FakeTodayRepository({
    this.care,
    this.pets,
    this.feedingMarks,
    this.supplies,
    this.items = const [],
    List<TodayFeeding> feedings = const [],
    this.visits = const [],
  }) : _feedings = feedings;

  final FakeCareRepository? care;
  final FakePetsRepository? pets;

  /// Where purchases are kept, so a reload shows what is still to buy.
  final FakeSuppliesRepository? supplies;

  /// Supplies to buy now, as the server would list them.
  List<TodaySupply> get shopping => [
    for (final supply in supplies?.supplies ?? const <Supply>[])
      if (supply.needsBuying)
        TodaySupply(
          id: supply.id,
          name: supply.name,
          brand: supply.brand,
          category: supply.category,
          unit: supply.unit,
          packageSize: supply.packageSize,
          status: supply.forecast.status,
          remaining: supply.forecast.remaining,
          daysLeft: supply.forecast.daysLeft,
          runsOutOn: supply.forecast.runsOutOn,
        ),
  ];

  /// Where marks made on the screen are kept, so a reload shows them.
  final FakeFeedingRepository? feedingMarks;
  List<TodayCareItem> items;
  final List<TodayFeeding> _feedings;
  List<TodayVisit> visits;

  /// Today's feedings as the server would send them, with the marks made.
  List<TodayFeeding> get feedings => [
    for (final item in _feedings)
      switch (feedingMarks?.current[(
        item.routineId,
        item.time.hour * 60 + item.time.minute,
      )]) {
        final mark? => item.withMark(mark),
        null => item,
      },
  ];

  /// When set, [getToday] throws it.
  Object? error;
  var calls = 0;

  @override
  Future<TodayOverview> getToday() async {
    calls++;
    final error = this.error;
    if (error != null) throw error;
    final care = this.care;
    if (care == null) {
      return TodayOverview(
        date: testToday(),
        items: items,
        feedings: feedings,
        visits: visits,
        shopping: shopping,
      );
    }

    final petsById = {
      for (final pet in pets?.pets ?? const <Pet>[]) pet.id: pet,
    };
    final due = [
      for (final plan in care.plans)
        if (plan.active &&
            plan.daysLeft <= TodayOverview.windowDays &&
            (petsById[plan.petId]?.isActive ?? false))
          plan,
    ]..sort((a, b) => a.nextDueOn.compareTo(b.nextDueOn));
    return TodayOverview(
      date: testToday(),
      feedings: feedings,
      visits: visits,
      shopping: shopping,
      items: [
        for (final plan in due)
          TodayCareItem(
            planId: plan.id,
            petId: plan.petId,
            petName: petsById[plan.petId]!.name,
            petPhoto: petsById[plan.petId]!.photo,
            kind: plan.kind,
            title: plan.title,
            nextDueOn: plan.nextDueOn,
            status: plan.status,
            daysLeft: plan.daysLeft,
          ),
      ],
    );
  }
}

/// AI set up on the server, on Gemini's free tier.
const testAiStatus = AiStatus(
  configured: true,
  models: [
    AiModel(provider: AiProvider.gemini, name: 'gemini-3.8-flash', ready: true),
    AiModel(provider: AiProvider.gemini, name: 'gemini-3.7-flash', ready: true),
  ],
  freeTier: true,
  thisMonth: AiUsage(requests: 12, inputTokens: 20400, outputTokens: 9800),
);

/// A scan as the server would return it: still reading, by default. A note
/// ([ScanSource.note]) has [text] and no photos.
AiScan testScan(
  String id, {
  String petId = 'p1',
  ScanSource source = ScanSource.passportPages,
  ScanStatus status = ScanStatus.processing,
  List<StoredFile>? pages,
  String? text,
  ScanDraft? draft,
  ScanError? error,
  ScanResult? result,
  DateTime? createdAt,
}) => AiScan(
  id: id,
  petId: petId,
  source: source,
  status: status,
  pages:
      pages ??
      (source == ScanSource.note ? const [] : [testFile('$id-page-1')]),
  text: text,
  draft: draft,
  error: error,
  model: status == ScanStatus.ready ? 'gemini-3.8-flash' : null,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 2, 9, 30),
  result: result,
);

/// A note as the server would return it: still being read, by default.
AiScan testNote(
  String id, {
  String text = 'Yesterday the rabies shot, Nobivac; weighs 4.2 kg',
  ScanStatus status = ScanStatus.processing,
  ScanDraft? draft,
  ScanError? error,
  ScanResult? result,
  DateTime? createdAt,
}) => testScan(
  id,
  source: ScanSource.note,
  status: status,
  text: text,
  draft: draft,
  error: error,
  result: result,
  createdAt: createdAt,
);

/// Works like the API: a scan (or a note) starts once per request id; one
/// read again throws the failed one away (the one it names, whoever started
/// it, else the person's own of the same photos or text), and a note read
/// again keeps the day it was written; while AI reads, [getScan] returns
/// the next step of the scan's script (the server's state afterwards); a
/// ready scan is saved once (saving again answers with the first result),
/// anything else is a conflict; a discarded scan is marked so (a note
/// forgets its text), a saved one stays saved. Scans and notes are listed
/// apart, the newest 20 of each.
class FakeAiRepository implements AiRepository {
  FakeAiRepository({
    this.status = AiStatus.notConfigured,
    List<AiScan> scans = const [],
  }) : scans = {for (final scan in scans) scan.id: scan};

  AiStatus status;

  /// When set, [getStatus] throws it.
  Object? statusError;
  var statusCalls = 0;

  AiTestResult testResult = const AiTestResult(
    ok: true,
    model: 'gemini-3.8-flash',
    latency: Duration(milliseconds: 1240),
  );
  var testCalls = 0;

  /// When set, [testConnection] throws it, e.g. the month's AI limit.
  Object? testError;

  /// The scans by id, as the server has them now.
  final Map<String, AiScan> scans;

  /// What [getScan] returns next for a scan, one step per call; then
  /// [scans] answers.
  final scripts = <String, List<AiScan>>{};

  /// When set, [getScan] throws it (a dropped connection).
  Object? getError;
  var getCalls = 0;

  /// Every start request, retries included.
  final starts =
      <
        ({
          String petId,
          ScanSource source,
          List<String> fileIds,
          String? text,
          String? retryOf,
          String requestId,
        })
      >[];

  /// Failed notes another member of the household wrote: a new note of the
  /// same text leaves them be (the server throws away only the person's
  /// own); one that names them ("Try again": retryOf) throws them away.
  final othersNotes = <String>{};
  final _scanByRequest = <String, String>{};

  /// When set, [startScan] throws it, e.g. a 409 or a 400.
  Object? startError;

  /// The next start goes through, but the app gets a network error.
  var loseNextStartResponse = false;

  /// What a new scan reads into, step by step (see [scripts]); by default
  /// it stays processing.
  List<AiScan> Function(AiScan started)? scriptForStart;

  /// Every save request, retries included.
  final applies = <(String, ScanApplyInput)>[];

  /// When set, [applyScan] throws it, e.g. a 400.
  Object? applyError;

  /// The next save goes through, but the app gets a network error.
  var loseNextApplyResponse = false;

  /// When set, [discardScan] throws it.
  Object? discardError;
  ScanResult applyResult = const ScanResult(
    recordIds: ['rec-1'],
    plansMoved: 1,
    documentId: 'doc-1',
  );
  final discarded = <String>[];

  @override
  Future<AiStatus> getStatus() async {
    statusCalls++;
    final error = statusError;
    if (error != null) throw error;
    return status;
  }

  @override
  Future<AiTestResult> testConnection() async {
    testCalls++;
    final error = testError;
    if (error != null) throw error;
    return testResult;
  }

  @override
  Future<AiScan> startScan(
    String petId, {
    required ScanSource source,
    List<String> fileIds = const [],
    String? text,
    String? retryOf,
    required String requestId,
  }) async {
    final error = startError;
    if (error != null) throw error;
    starts.add((
      petId: petId,
      source: source,
      fileIds: fileIds,
      text: text,
      retryOf: retryOf,
      requestId: requestId,
    ));
    final earlier = _scanByRequest[requestId];
    if (earlier != null) return scans[earlier]!;
    // Like the server: a failed note read again keeps the day it was
    // written.
    final retried = scans[retryOf];
    final writtenAt =
        source == ScanSource.note &&
            retried != null &&
            retried.isNote &&
            retried.status == ScanStatus.failed
        ? retried.createdAt
        : null;
    // Like the server: reading a failed scan's photos (or a failed note's
    // text) again replaces it: the one named, or the person's own.
    for (final failed in [...scans.values]) {
      final readAgain =
          failed.id == retryOf ||
          (source == ScanSource.note
              ? failed.isNote &&
                    failed.text == text &&
                    !othersNotes.contains(failed.id)
              : failed.pages.isNotEmpty &&
                    failed.pages.every((page) => fileIds.contains(page.id)));
      if (failed.status == ScanStatus.failed &&
          failed.petId == petId &&
          readAgain) {
        scans[failed.id] = testScan(
          failed.id,
          petId: failed.petId,
          source: failed.source,
          status: ScanStatus.discarded,
          pages: failed.pages,
        );
      }
    }
    final scan = testScan(
      'scan-new-${_scanByRequest.length + 1}',
      petId: petId,
      source: source,
      status: ScanStatus.queued,
      pages: [for (final id in fileIds) testFile(id)],
      text: text,
      createdAt: writtenAt,
    );
    scans[scan.id] = scan;
    _scanByRequest[requestId] = scan.id;
    final script = scriptForStart;
    if (script != null) scripts[scan.id] = script(scan);
    if (loseNextStartResponse) {
      loseNextStartResponse = false;
      throw networkError;
    }
    return scan;
  }

  @override
  Future<AiScan> getScan(String id) async {
    getCalls++;
    final error = getError;
    if (error != null) throw error;
    final script = scripts[id];
    if (script != null && script.isNotEmpty) scans[id] = script.removeAt(0);
    return scans[id] ?? (throw notFound);
  }

  var listCalls = 0;

  /// What each list asked for: notes (true), photo scans (false), or both.
  final listedNotes = <bool?>[];

  /// Like the server: the scans still waiting for the user, newest first;
  /// with [notes], only the notes (true) or the photo scans (false), the
  /// newest 20 of each kind.
  @override
  Future<List<AiScan>> getPetScans(String petId, {bool? notes}) async {
    listCalls++;
    listedNotes.add(notes);
    // The ones added last first, then by the moment they were started (a
    // sort that keeps the order of equal moments).
    final waiting =
        [
          for (final (index, scan) in scans.values.toList().reversed.indexed)
            if (scan.petId == petId &&
                scan.status != ScanStatus.discarded &&
                scan.status != ScanStatus.applied &&
                (notes == null || scan.isNote == notes))
              (index, scan),
        ]..sort((a, b) {
          final byMoment = b.$2.createdAt.compareTo(a.$2.createdAt);
          return byMoment != 0 ? byMoment : a.$1.compareTo(b.$1);
        });
    return [for (final (_, scan) in waiting.take(20)) scan];
  }

  @override
  Future<ScanResult> applyScan(String id, ScanApplyInput input) async {
    applies.add((id, input));
    final error = applyError;
    if (error != null) throw error;
    final scan = scans[id] ?? (throw notFound);
    if (scan.status == ScanStatus.applied) return scan.result!;
    if (scan.status != ScanStatus.ready) throw conflict;
    scans[id] = testScan(
      id,
      petId: scan.petId,
      source: scan.source,
      status: ScanStatus.applied,
      pages: scan.pages,
      text: scan.text,
      draft: scan.draft,
      result: applyResult,
    );
    if (loseNextApplyResponse) {
      loseNextApplyResponse = false;
      throw networkError;
    }
    return applyResult;
  }

  /// Like the server: a saved scan can't be thrown away (409).
  @override
  Future<void> discardScan(String id) async {
    final error = discardError;
    if (error != null) throw error;
    final scan = scans[id];
    if (scan?.status == ScanStatus.applied) throw conflict;
    discarded.add(id);
    if (scan == null) return;
    // A note's text goes with it.
    scans[id] = testScan(
      id,
      petId: scan.petId,
      source: scan.source,
      status: ScanStatus.discarded,
      pages: scan.pages,
    );
  }
}

/// Feeding schedules and "fed" marks in memory. A test makes someone else's
/// mark come first with [takenBy].
class FakeFeedingRepository implements FeedingRepository {
  FakeFeedingRepository({List<FeedingSchedule>? schedules})
    : schedules = schedules ?? [];

  final List<FeedingSchedule> schedules;

  /// The marks made, in order: routine id, date, time, skipped.
  final marks = <(String, DateTime, TimeOfDay, bool)>[];

  /// The marks taken back, by id.
  final undone = <String>[];

  /// A mark someone else made first, by routine id: marking it throws.
  final takenBy = <String, FeedingMark>{};

  /// Thrown by every mark, e.g. a network error; [markAttempts] counts them.
  Object? markError;
  var markAttempts = 0;

  /// What the last create or update sent.
  FeedingInput? lastInput;
  String? lastRequestId;
  var _next = 0;

  @override
  Future<List<FeedingSchedule>> getSchedules(String petId) async => [
    for (final schedule in schedules)
      if (schedule.petId == petId) schedule,
  ];

  @override
  Future<FeedingSchedule> getSchedule(String id) async =>
      schedules.firstWhere((s) => s.id == id, orElse: () => throw notFound);

  @override
  Future<FeedingSchedule> createSchedule(
    String petId,
    FeedingInput input, {
    required String requestId,
  }) async {
    lastInput = input;
    lastRequestId = requestId;
    final schedule = _fromInput('routine${++_next}', petId, input, true);
    schedules.add(schedule);
    return schedule;
  }

  @override
  Future<FeedingSchedule> updateSchedule(String id, FeedingInput input) async {
    lastInput = input;
    final index = schedules.indexWhere((s) => s.id == id);
    if (index < 0) throw notFound;
    final old = schedules[index];
    return schedules[index] = _fromInput(
      id,
      old.petId,
      input,
      input.active ?? old.active,
    );
  }

  @override
  Future<void> deleteSchedule(String id) async =>
      schedules.removeWhere((s) => s.id == id);

  /// The marks as the server keeps them, by routine and time: Today shows
  /// them when it reloads ([FakeTodayRepository.feedingMarks]).
  final current = <(String, int), FeedingMark>{};

  @override
  Future<FeedingMark> mark(
    String routineId,
    DateTime date,
    TimeOfDay time, {
    bool skipped = false,
  }) async {
    markAttempts++;
    if (markError case final error?) throw error;
    final key = (routineId, time.hour * 60 + time.minute);
    final taken = takenBy[routineId];
    if (taken != null) {
      current[key] = taken;
      throw FeedingAlreadyMarked(taken);
    }
    // Marked already by the same person: the first mark comes back.
    final earlier = current[key];
    if (earlier != null) return earlier;
    marks.add((routineId, date, time, skipped));
    return current[key] = FeedingMark(
      id: 'mark${marks.length}',
      routineId: routineId,
      date: date,
      time: time,
      skipped: skipped,
      doneAt: DateTime(date.year, date.month, date.day, 8, 2),
      byMe: true,
      byName: 'Me',
    );
  }

  @override
  Future<void> undo(String routineId, String markId) async {
    undone.add(markId);
    current.removeWhere((_, mark) => mark.id == markId);
  }

  static FeedingSchedule _fromInput(
    String id,
    String petId,
    FeedingInput input,
    bool active,
  ) => FeedingSchedule(
    id: id,
    petId: petId,
    times: input.times,
    days: input.days,
    food: input.food,
    amount: input.amount,
    unit: input.unit,
    notes: input.notes,
    active: active,
  );
}

/// A weight of the log as the server would return it: a weighing, or with
/// [source] another kind, e.g. a vet's weight.
WeightEntry testWeight(
  String id, {
  required DateTime on,
  required double kg,
  String petId = 'p1',
  WeightSource source = WeightSource.weighing,
  BodyCondition? bodyCondition,
  String? note,
  DateTime? createdAt,
  bool hasUnknownValues = false,
}) => WeightEntry(
  id: id,
  petId: petId,
  source: source,
  measuredOn: on,
  weightKg: kg,
  bodyCondition: bodyCondition,
  note: note,
  createdAt: createdAt ?? on,
  hasUnknownValues: hasUnknownValues,
);

/// The weight log as the server builds it: the weighings kept here and,
/// with a [care] fake, the weights its records note (titled like the
/// record), newest first. A retry of adding a weighing with the same
/// request id gets the first one; a weighing that is gone (removed by a
/// test) is "not found".
class FakeWeightRepository implements WeightRepository {
  FakeWeightRepository({List<WeightEntry>? weighings, this.care})
    : weighings = weighings ?? [];

  /// In any order.
  final List<WeightEntry> weighings;

  /// The records whose weights join the log.
  final FakeCareRepository? care;

  /// When set, reading the log throws it, e.g. a network error.
  Object? listError;

  /// When set, adding and changing a weighing throw it, e.g. a 400.
  Object? saveError;

  /// When set, deleting throws it.
  Object? deleteError;

  /// When set, the next weighing is added on the "server", but the app gets
  /// a network error, as when the response is lost.
  var loseNextCreateResponse = false;

  var listCalls = 0;

  /// The request id of every weighing sent, retries included.
  final createRequestIds = <String>[];
  final created = <(String, WeighingInput)>[];
  final updated = <(String, WeighingInput)>[];
  final deleted = <String>[];
  final _idByRequest = <String, String>{};
  var _next = 0;

  @override
  Future<List<WeightEntry>> getLog(String petId) async {
    listCalls++;
    if (listError case final error?) throw error;
    return [
      for (final weighing in weighings)
        if (weighing.petId == petId) weighing,
      for (final record in care?.records ?? const <CareRecord>[])
        if (record.petId == petId && record.weightKg != null)
          testWeight(
            record.id,
            petId: petId,
            source: WeightSource.careRecord,
            on: record.performedOn,
            kg: record.weightKg!,
            note: record.title,
          ),
    ]..sort(newestFirst);
  }

  @override
  Future<WeightEntry> createWeighing(
    String petId,
    WeighingInput input, {
    required String requestId,
  }) async {
    createRequestIds.add(requestId);
    if (saveError case final error?) throw error;
    final earlier = _idByRequest[requestId];
    if (earlier != null) return weighings.firstWhere((w) => w.id == earlier);
    created.add((petId, input));
    final weighing = _fromInput('weighing-new-${++_next}', petId, input);
    weighings.add(weighing);
    _idByRequest[requestId] = weighing.id;
    if (loseNextCreateResponse) {
      loseNextCreateResponse = false;
      throw networkError;
    }
    return weighing;
  }

  @override
  Future<WeightEntry> updateWeighing(String id, WeighingInput input) async {
    if (saveError case final error?) throw error;
    final index = weighings.indexWhere((w) => w.id == id);
    if (index < 0) throw notFound;
    updated.add((id, input));
    final old = weighings[index];
    return weighings[index] = _fromInput(
      id,
      old.petId,
      input,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> deleteWeighing(String id) async {
    if (deleteError case final error?) throw error;
    final index = weighings.indexWhere((w) => w.id == id);
    if (index < 0) throw notFound;
    deleted.add(id);
    weighings.removeAt(index);
  }

  static WeightEntry _fromInput(
    String id,
    String petId,
    WeighingInput input, {
    DateTime? createdAt,
  }) => testWeight(
    id,
    petId: petId,
    on: input.measuredOn,
    // To the gram, as the server keeps it.
    kg: (input.weightKg * 1000).round() / 1000,
    bodyCondition: input.bodyCondition,
    note: input.note,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Visits in memory.
class FakeVisitsRepository implements VisitsRepository {
  FakeVisitsRepository({List<Visit>? visits}) : visits = visits ?? [];

  final List<Visit> visits;

  /// When set, reading and saving a visit throw it (no connection).
  Object? error;

  /// What the last create or update sent.
  VisitInput? lastInput;

  /// The "took place" requests: visit id, record kind, plans.
  final completions = <(String, CareKind?, List<String>)>[];
  var _next = 0;

  @override
  Future<List<Visit>> getVisits() async => [...visits];

  @override
  Future<Visit> getVisit(String id) async {
    if (error case final error?) throw error;
    return visits.firstWhere((v) => v.id == id, orElse: () => throw notFound);
  }

  @override
  Future<Visit> createVisit(
    VisitInput input, {
    required String requestId,
  }) async {
    lastInput = input;
    final visit = _fromInput('visit${++_next}', input, VisitStatus.planned);
    visits.add(visit);
    return visit;
  }

  @override
  Future<Visit> updateVisit(String id, VisitInput input) async {
    if (error case final error?) throw error;
    lastInput = input;
    final index = visits.indexWhere((v) => v.id == id);
    if (index < 0) throw notFound;
    return visits[index] = _fromInput(
      id,
      input,
      input.status ?? visits[index].status,
    );
  }

  @override
  Future<void> deleteVisit(String id) async =>
      visits.removeWhere((v) => v.id == id);

  @override
  Future<({Visit visit, List<String> movedPlanIds})> completeVisit(
    String id, {
    CareKind? recordKind,
    List<String> planIds = const [],
    String? notes,
  }) async {
    completions.add((id, recordKind, planIds));
    final index = visits.indexWhere((v) => v.id == id);
    final old = visits[index];
    final done = Visit(
      id: old.id,
      type: old.type,
      title: old.title,
      date: old.date,
      time: old.time,
      petIds: old.petIds,
      remindMinutesBefore: old.remindMinutesBefore,
      status: VisitStatus.done,
      location: old.location,
      notes: old.notes,
      recordIds: [
        if (recordKind != null)
          for (final petId in old.petIds) 'record-$petId',
      ],
    );
    visits[index] = done;
    return (visit: done, movedPlanIds: planIds);
  }

  static Visit _fromInput(String id, VisitInput input, VisitStatus status) =>
      Visit(
        id: id,
        type: input.type,
        title: input.title,
        date: input.date,
        time: input.time,
        petIds: input.petIds,
        remindMinutesBefore: input.remindMinutesBefore,
        status: status,
        location: input.location,
        notes: input.notes,
      );
}

/// Notification settings and reminders in memory.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({
    this.pushReady = true,
    this.log = const ReminderLog(upcoming: [], recent: []),
  });

  bool pushReady;
  ReminderLog log;
  final enabled = <NotificationCategory, bool>{};

  /// Phones registered, by device id: their tokens.
  final devices = <String, String>{};
  final forgotten = <String>[];
  var tests = 0;
  TestPushResult testResult = const TestPushResult(devices: 1, delivered: 1);

  @override
  Future<void> registerDevice(String deviceId, String token) async =>
      devices[deviceId] = token;

  /// When set, forgetting a phone throws it (the server can't be reached).
  Object? forgetError;

  @override
  Future<void> forgetDevice(String deviceId) async {
    if (forgetError case final error?) throw error;
    forgotten.add(deviceId);
    devices.remove(deviceId);
  }

  @override
  Future<NotificationSettings> getSettings() async => _settings();

  @override
  Future<NotificationSettings> setEnabled(
    NotificationCategory category,
    bool on,
  ) async {
    enabled[category] = on;
    return _settings();
  }

  @override
  Future<ReminderLog> getReminders() async => log;

  @override
  Future<TestPushResult> sendTest() async {
    tests++;
    return testResult;
  }

  NotificationSettings _settings() => NotificationSettings(
    pushReady: pushReady,
    enabled: {
      for (final category in NotificationCategory.values)
        category: enabled[category] ?? true,
    },
    deviceIds: [...devices.keys],
  );
}

/// A phone's push platform: Android with a token by default; a test can
/// turn it into an iPhone ([supported] false) or deny the permission.
class FakePushPlatform implements PushPlatform {
  FakePushPlatform({
    this.supported = true,
    this.allowed = true,
    this.currentToken = 'token-1',
  });

  @override
  bool supported;
  bool allowed;
  String? currentToken;
  var settingsOpened = 0;

  /// How many times the user was asked for permission.
  var permissionRequests = 0;
  var tokensForgotten = 0;

  /// The push that started the app, if any.
  Map<String, String>? launch;
  PushChannelNames? channels;
  final _taps = StreamController<Map<String, String>>.broadcast();
  final _arrivals = StreamController<Map<String, String>>.broadcast();
  final _refreshes = StreamController<String>.broadcast();

  /// Simulates a tap on a push with this data.
  void tap(Map<String, String> data) => _taps.add(data);

  /// Simulates a push arriving while the app is open.
  void arrive(Map<String, String> data) => _arrivals.add(data);

  /// Simulates Firebase giving the phone a new address.
  void refreshToken(String token) {
    currentToken = token;
    _refreshes.add(token);
  }

  @override
  Future<void> start(PushChannelNames names) async => channels = names;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<bool> permissionGranted() async => allowed;

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Stream<Map<String, String>> get taps => _taps.stream;

  @override
  Stream<Map<String, String>> get arrivals => _arrivals.stream;

  @override
  Future<Map<String, String>?> launchTap() async => launch;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<void> forgetToken() async {
    tokensForgotten++;
    currentToken = null;
  }
}

/// A supply item for tests: a 2 kg bag of dry food, [remaining] grams left
/// at [perDay] grams a day (the estimate as the fake repository makes it).
Supply testSupply(
  String id,
  String name, {
  double? remaining = 2000,
  double? perDay = 80,
  SupplyCategory category = SupplyCategory.dryFood,
  SupplyUnit unit = SupplyUnit.gram,
  double packageSize = 2000,
  int leadTimeDays = 5,
  bool active = true,
  List<SupplyFeeding> feedings = const [],
  String? brand,
  String? storeUrl,
}) => Supply(
  id: id,
  name: name,
  brand: brand,
  category: category,
  unit: unit,
  packageSize: packageSize,
  usageMode: isFood(category) && category != SupplyCategory.treats
      ? SupplyUsageMode.feeding
      : SupplyUsageMode.manual,
  leadTimeDays: leadTimeDays,
  storeUrl: storeUrl,
  active: active,
  feedings: feedings,
  forecast: FakeSuppliesRepository.forecastOf(remaining, perDay, leadTimeDays),
);

class FakeSuppliesRepository implements SuppliesRepository {
  FakeSuppliesRepository({List<Supply>? supplies}) : supplies = supplies ?? [];

  final List<Supply> supplies;

  /// Purchases and counts by item, newest first.
  final stock = <String, List<StockEntry>>{};

  final created = <(SupplyInput, String)>[];
  final updated = <(String, SupplyInput)>[];
  final added = <(String, StockEventKind, double, String)>[];

  /// What a scanned code is; a code not here is a product nobody knows.
  final lookups = <String, ProductLookup>{};

  /// Codes that aren't product barcodes.
  final notProducts = <String>{};

  /// What reading photos of a package gives, or an error to throw.
  Object? scanResult;
  final scans = <(List<String>, String?)>[];

  /// When set, every call throws it (no connection).
  Object? error;

  static Exception get notFound => const ApiException(ApiErrorKind.notFound);

  /// The estimate the server would make, from today.
  static SupplyForecast forecastOf(
    double? remaining,
    double? perDay,
    int lead,
  ) {
    if (remaining == null) {
      return SupplyForecast(status: SupplyStatus.noStock, usagePerDay: perDay);
    }
    if (perDay == null || perDay <= 0) {
      return SupplyForecast(status: SupplyStatus.noUsage, remaining: remaining);
    }
    final days = remaining / perDay;
    final today = testToday();
    final runsOutOn = today.add(Duration(days: days.floor()));
    final buyBy = runsOutOn.subtract(Duration(days: lead));
    final status = remaining <= 0
        ? SupplyStatus.outOfStock
        : !buyBy.isAfter(today)
        ? SupplyStatus.buyNow
        : !buyBy.isAfter(today.add(const Duration(days: 7)))
        ? SupplyStatus.soon
        : SupplyStatus.enough;
    return SupplyForecast(
      status: status,
      remaining: remaining,
      usagePerDay: perDay,
      daysLeft: days,
      runsOutOn: runsOutOn,
      buyBy: buyBy,
    );
  }

  void _check() {
    final error = this.error;
    if (error != null) throw error;
  }

  Supply _find(String id) => supplies.firstWhere(
    (supply) => supply.id == id,
    orElse: () => throw notFound,
  );

  Supply _replace(Supply supply, {double? remaining, bool clearStock = false}) {
    final updated = Supply(
      id: supply.id,
      name: supply.name,
      brand: supply.brand,
      barcode: supply.barcode,
      category: supply.category,
      unit: supply.unit,
      packageSize: supply.packageSize,
      kcalPerKg: supply.kcalPerKg,
      usageMode: supply.usageMode,
      manualDailyUsage: supply.manualDailyUsage,
      leadTimeDays: supply.leadTimeDays,
      storeUrl: supply.storeUrl,
      notes: supply.notes,
      active: supply.active,
      feedings: supply.feedings,
      forecast: forecastOf(
        clearStock ? null : remaining ?? supply.forecast.remaining,
        supply.forecast.usagePerDay,
        supply.leadTimeDays,
      ),
    );
    supplies[supplies.indexWhere((s) => s.id == supply.id)] = updated;
    return updated;
  }

  var listCalls = 0;

  @override
  Future<List<Supply>> getSupplies() async {
    listCalls++;
    _check();
    return [...supplies];
  }

  @override
  Future<Supply> getSupply(String id) async {
    _check();
    return _find(id);
  }

  Supply _fromInput(String id, SupplyInput input, {Supply? before}) {
    final perDay = input.usageMode == SupplyUsageMode.manual
        ? input.manualDailyUsage
        : before?.forecast.usagePerDay;
    return Supply(
      id: id,
      name: input.name,
      brand: input.brand,
      barcode: input.barcode,
      category: input.category,
      unit: input.unit,
      packageSize: input.packageSize,
      kcalPerKg: input.kcalPerKg,
      usageMode: input.usageMode,
      manualDailyUsage: input.manualDailyUsage,
      leadTimeDays: input.leadTimeDays,
      storeUrl: input.storeUrl,
      notes: input.notes,
      active: input.active ?? before?.active ?? true,
      feedings: before?.feedings ?? const [],
      forecast: forecastOf(
        before?.forecast.remaining ?? input.initialStock,
        perDay,
        input.leadTimeDays,
      ),
    );
  }

  @override
  Future<Supply> createSupply(
    SupplyInput input, {
    required String requestId,
  }) async {
    _check();
    for (final (_, id) in created) {
      if (id == requestId) return _find('supply-$requestId');
    }
    created.add((input, requestId));
    final supply = _fromInput('supply-$requestId', input);
    supplies.add(supply);
    return supply;
  }

  @override
  Future<Supply> updateSupply(String id, SupplyInput input) async {
    _check();
    final before = _find(id);
    updated.add((id, input));
    final supply = _fromInput(id, input, before: before);
    supplies[supplies.indexOf(before)] = supply;
    return supply;
  }

  @override
  Future<void> deleteSupply(String id) async {
    _check();
    final before = _find(id);
    supplies.remove(before);
  }

  @override
  Future<List<StockEntry>> getStock(String supplyId) async {
    _check();
    _find(supplyId);
    return [...?stock[supplyId]];
  }

  @override
  Future<Supply> addStock(
    String supplyId,
    StockEventKind kind,
    double quantity, {
    required String requestId,
  }) async {
    _check();
    final supply = _find(supplyId);
    for (final entry in added) {
      if (entry.$4 == requestId) return supply;
    }
    added.add((supplyId, kind, quantity, requestId));
    stock
        .putIfAbsent(supplyId, () => [])
        .insert(
          0,
          StockEntry(
            id: 'entry-${added.length}',
            kind: kind,
            quantity: quantity,
            at: testToday().add(const Duration(hours: 12)),
            byMe: true,
          ),
        );
    return _replace(
      supply,
      remaining: kind == StockEventKind.purchase
          ? (supply.forecast.remaining ?? 0) + quantity
          : quantity,
    );
  }

  @override
  Future<void> deleteStock(String supplyId, String entryId) async {
    _check();
    final entries = stock[supplyId] ?? [];
    final before = entries.length;
    entries.removeWhere((entry) => entry.id == entryId);
    if (entries.length == before) throw notFound;
  }

  @override
  Future<ProductLookup> lookup(String code) async {
    _check();
    if (notProducts.contains(code)) throw const NotAProductCode();
    return lookups[code] ?? ProductLookup(code: code);
  }

  @override
  Future<ProductDraft> scan(List<String> fileIds, {String? barcode}) async {
    _check();
    scans.add((fileIds, barcode));
    final result = scanResult;
    if (result is ProductDraft) return result;
    if (result != null) throw result;
    return const ProductDraft(isPetProduct: true);
  }
}

/// A chip scanner that gives the next of [scans]; none left: the user
/// closes the scanner.
class FakeChipReader implements ChipReader {
  FakeChipReader([List<ChipScan>? scans]) : scans = scans ?? [];

  final List<ChipScan> scans;
  var reads = 0;

  /// When set, the scanner stays open until it completes.
  Completer<void>? gate;

  @override
  Future<ChipScan?> read(BuildContext context) async {
    reads++;
    final gate = this.gate;
    if (gate != null) await gate.future;
    return scans.isEmpty ? null : scans.removeAt(0);
  }
}

/// A barcode scanner that "reads" the next of [codes]; none left: the user
/// closes the scanner.
class FakeBarcodeReader implements BarcodeReader {
  FakeBarcodeReader([List<String>? codes]) : codes = codes ?? [];

  final List<String> codes;
  var reads = 0;

  /// When set, the scanner stays open until it completes.
  Completer<void>? gate;

  @override
  Future<String?> read(BuildContext context) async {
    reads++;
    final gate = this.gate;
    if (gate != null) await gate.future;
    return codes.isEmpty ? null : codes.removeAt(0);
  }
}

/// One of the person's households and what deleting the account does to
/// it, for [FakeAccountRepository]: by default "Home", which the person owns
/// alone, deleted with nothing in it.
HouseholdOutcome testOutcome(
  String id, {
  String name = 'Home',
  HouseholdRole role = HouseholdRole.owner,
  HouseholdFate fate = HouseholdFate.deleted,
  int pets = 0,
  int others = 0,
  String? newOwner,
}) => HouseholdOutcome(
  id: id,
  name: name,
  role: role,
  fate: fate,
  pets: pets,
  others: others,
  newOwner: newOwner,
);

/// What deleting the account would do ([households], fingerprinted as
/// [plan]), the deletion and the data export, as the server answers them.
/// A deletion with another plan than the current one deletes nothing (409
/// `deletion-plan-changed`): a test changes the groups by setting both. The
/// export reports [exportProgress], waits for [exportGate] when one is set
/// ("Cancel" stops it), then gives a file of [exportBytes], or fails with
/// [exportError]. No file is written.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({List<HouseholdOutcome>? households})
    : households = households ?? [testOutcome(FakeMeRepository.homeId)];

  List<HouseholdOutcome> households;
  var plan = 'plan-1';
  Object? previewError;
  var previewCalls = 0;

  Object? deleteError;

  /// Every deletion asked for, deleted or not.
  var deletions = 0;

  /// The plan each deletion sent.
  final deletedPlans = <String>[];

  List<int> exportProgress = const [];
  Completer<void>? exportGate;
  Object? exportError;
  var exportBytes = 24500000;
  var exports = 0;
  CancelToken? exportCancel;

  static const exportName = 'collarbell-export-2026-10-06.zip';

  @override
  Future<DeletionPreview> getDeletionPreview() async {
    previewCalls++;
    final error = previewError;
    if (error != null) throw error;
    return DeletionPreview(households: [...households], plan: plan);
  }

  @override
  Future<void> deleteAccount(String plan) async {
    deletions++;
    deletedPlans.add(plan);
    final error = deleteError;
    if (error != null) throw error;
    if (plan != this.plan) throw deletionPlanChanged;
  }

  @override
  Future<ExportFile> downloadExport(
    Directory folder, {
    void Function(int received)? onReceived,
    CancelToken? cancelToken,
  }) async {
    exports++;
    exportCancel = cancelToken;
    final error = exportError;
    if (error != null) throw error;
    for (final received in exportProgress) {
      onReceived?.call(received);
    }
    final gate = exportGate;
    if (gate != null) {
      await Future.any<void>([
        gate.future,
        if (cancelToken != null) cancelToken.whenCancel,
      ]);
    }
    if (cancelToken?.isCancelled ?? false) {
      throw const ApiException(ApiErrorKind.cancelled);
    }
    return ExportFile(
      path: '${folder.path}/$exportName',
      name: exportName,
      bytes: exportBytes,
    );
  }
}

/// The downloaded export without files: [freshFolder] names a folder it
/// doesn't make; what is saved, shared and cleared is remembered. "Save"
/// answers [saveAnswer] (false: the person cancelled), or fails with
/// [saveError]; "Share" fails with [shareError].
class FakeExportFiles implements ExportFiles {
  final saved = <ExportFile>[];
  final shared = <ExportFile>[];
  var folders = 0;
  var clears = 0;

  /// Every copy deleted: a new export, a sign-out.
  var clearAlls = 0;
  var saveAnswer = true;
  Object? saveError;
  Object? shareError;

  @override
  Future<Directory> freshFolder() async {
    folders++;
    return Directory('/fake/data_export');
  }

  @override
  Future<bool> save(ExportFile file) async {
    final error = saveError;
    if (error != null) throw error;
    if (saveAnswer) saved.add(file);
    return saveAnswer;
  }

  @override
  Future<void> share(ExportFile file) async {
    final error = shareError;
    if (error != null) throw error;
    shared.add(file);
  }

  @override
  Future<void> clear() async => clears++;

  @override
  Future<void> clearAll() async => clearAlls++;
}

/// The server's live updates as a test plays them. Every connection the app
/// opens is a [FakeRealtimeClient] here ([newClient]); by default it opens.
class FakeLiveServer {
  /// Every client the app made, the newest last: one per connection.
  final clients = <FakeRealtimeClient>[];

  /// What the next connections do, in turn: null opens, an error fails
  /// (a [RealtimeRefused] refuses). None left: they open.
  final outcomes = <Object?>[];

  /// When set, opening waits until it completes.
  Completer<void>? gate;

  /// For `realtimeClientFactoryProvider`.
  RealtimeClient newClient() {
    final client = FakeRealtimeClient(this);
    clients.add(client);
    return client;
  }

  /// The connections open now.
  List<FakeRealtimeClient> get open => [
    for (final client in clients)
      if (client.state == RealtimeState.connected) client,
  ];

  /// [topics] changed: every open connection hears it. [origin] is the
  /// `X-Client` of the request that made the change; the server sends it
  /// only to the connections of whoever made it, and null to everyone else
  /// (and for its own changes).
  void change(List<String> topics, {String? origin}) {
    for (final client in open) {
      client.hear(LiveChange(topics, origin: origin));
    }
  }
}

/// One connection of [FakeLiveServer]: it keeps the headers it was opened
/// with.
class FakeRealtimeClient implements RealtimeClient {
  FakeRealtimeClient(this._server);

  final FakeLiveServer _server;
  final _changes = StreamController<LiveChange>.broadcast();
  var _state = RealtimeState.disconnected;

  Uri? url;
  Map<String, String>? headers;

  /// The app closed it.
  var closed = false;

  @override
  RealtimeState get state => _state;

  @override
  Stream<LiveChange> get changes => _changes.stream;

  @override
  Future<void> connect(Uri url, Map<String, String> headers) async {
    this.url = url;
    this.headers = headers;
    _state = RealtimeState.connecting;
    final outcome = _server.outcomes.isEmpty
        ? null
        : _server.outcomes.removeAt(0);
    await _server.gate?.future;
    if (closed) throw StateError('Closed while opening.');
    if (outcome != null) {
      _finish();
      throw outcome;
    }
    _state = RealtimeState.connected;
  }

  /// The server tells this connection about a change.
  void hear(LiveChange change) => _changes.add(change);

  /// The network or the server drops the connection.
  void drop() => _finish();

  @override
  Future<void> close() async {
    closed = true;
    _finish();
  }

  void _finish() {
    _state = RealtimeState.disconnected;
    if (!_changes.isClosed) unawaited(_changes.close());
  }
}
