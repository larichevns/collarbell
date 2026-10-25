// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Collarbell';

  @override
  String get navToday => 'Today';

  @override
  String get navPets => 'Pets';

  @override
  String get navSupplies => 'Supplies';

  @override
  String get navMore => 'More';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonLoading => 'Loading';

  @override
  String get errorNetwork =>
      'Can\'t reach the server. Check your connection and try again.';

  @override
  String get leaveTitle => 'Leave without saving?';

  @override
  String get leaveBody => 'What you entered on this screen will be lost.';

  @override
  String get leaveConfirm => 'Leave';

  @override
  String get errorRefreshed =>
      'The server is back and the data was reloaded. Check it and try again.';

  @override
  String get errorSignInRenewal =>
      'Couldn\'t renew the sign-in: no internet. Check the connection.';

  @override
  String get formOpenedOffline =>
      'This form opened without a connection, from the copy on the phone: its data may be old, so it can\'t be saved. Open it again once the server is back.';

  @override
  String get offlineBanner => 'No connection to the server';

  @override
  String offlineBannerSince(String time) {
    return 'No connection to the server · data from $time';
  }

  @override
  String get errorUnauthorized => 'Your session has expired. Sign in again.';

  @override
  String get errorForbidden => 'Your role in the group doesn\'t allow this.';

  @override
  String get errorServer =>
      'Something went wrong on our side. Try again in a moment.';

  @override
  String get errorUnknown => 'Something went wrong. Try again.';

  @override
  String errorReference(String traceId) {
    return 'Error ID: $traceId';
  }

  @override
  String get signInTagline =>
      'Feeding, vaccinations and supplies for your pets in one place.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signUpTitle => 'Create an account';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get emailRequired => 'Enter your email';

  @override
  String get emailInvalid => 'Enter an email like name@example.com';

  @override
  String get passwordRequired => 'Enter your password';

  @override
  String passwordTooShort(int min) {
    String _temp0 = intl.Intl.pluralLogic(
      min,
      locale: localeName,
      other: 'Use at least $min characters',
      one: 'Use at least 1 character',
    );
    return '$_temp0';
  }

  @override
  String get signInButton => 'Sign in';

  @override
  String get signUpButton => 'Create account';

  @override
  String get switchToSignUp => 'New to Collarbell? Create an account';

  @override
  String get switchToSignIn => 'Already have an account? Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get passwordResetNeedsEmail =>
      'Enter your e-mail above: the link for a new password goes there.';

  @override
  String passwordResetSent(String email) {
    return 'If there is an account for $email, a letter with a link for a new password is on its way. Check the spam folder too.';
  }

  @override
  String get authErrorInvalidCredentials => 'Wrong email or password.';

  @override
  String get authErrorEmailInUse =>
      'An account with this email already exists. Sign in instead.';

  @override
  String get authErrorWeakPassword =>
      'This password is too easy to guess. Choose a longer one.';

  @override
  String get authErrorInvalidEmail => 'This email address doesn\'t look right.';

  @override
  String get authErrorUserDisabled => 'This account has been disabled.';

  @override
  String get authErrorTooManyRequests =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get authErrorNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get authErrorNotAllowed => 'Email sign-in is turned off for this app.';

  @override
  String get authErrorUnknown => 'Couldn\'t sign in. Try again.';

  @override
  String get devModeOverline => 'DEVELOPER MODE';

  @override
  String get devModeBody =>
      'Sign in with a local test account. The API has to run in development mode.';

  @override
  String get devEmailLabel => 'Developer email';

  @override
  String devUserId(String uid) {
    return 'User ID: $uid';
  }

  @override
  String get devContinue => 'Continue as developer';

  @override
  String get todayTitle => 'Today';

  @override
  String todayDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMEEEEd(
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get todayEmptyTitle => 'Nothing scheduled yet';

  @override
  String get todayEmptyBody =>
      'Feeding times, visits, and vaccinations and treatments due in the next 30 days will appear here.';

  @override
  String get todayStartTitle => 'Start with a pet';

  @override
  String get todayStartBody =>
      'Add a cat or a dog: their feeding, vaccinations, treatments and what to buy will show up here.';

  @override
  String get todayAddFeeding => 'Add feeding';

  @override
  String get todayAddCare => 'Vaccinations and treatments';

  @override
  String get petsTitle => 'Pets';

  @override
  String get petsEmptyTitle => 'No pets yet';

  @override
  String get petsEmptyBody => 'You\'ll add your cats and dogs here.';

  @override
  String get petSpeciesCat => 'Cat';

  @override
  String get petSpeciesDog => 'Dog';

  @override
  String get petSpeciesOther => 'Other animal';

  @override
  String get suppliesTitle => 'Supplies';

  @override
  String get suppliesEmptyTitle => 'No supplies yet';

  @override
  String get suppliesEmptyBody =>
      'Add food, litter or medicine: the app tells you when it\'s time to buy.';

  @override
  String get moreTitle => 'More';

  @override
  String get moreAccount => 'Account';

  @override
  String get moreSignedInAs => 'Signed in as';

  @override
  String get moreNoEmail => 'No email';

  @override
  String get moreLanguage => 'Language';

  @override
  String get moreLanguageSystem => 'System';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameRussian => 'Русский';

  @override
  String get moreTheme => 'Theme';

  @override
  String get moreThemeLight => 'Light (default)';

  @override
  String get moreThemeDark => 'Dark';

  @override
  String get moreThemeSystem => 'System';

  @override
  String get moreSignOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody =>
      'Reminders stop coming to this phone until you sign in again.';

  @override
  String moreDeveloperInfo(String server) {
    return 'Developer mode · $server';
  }

  @override
  String get commonAdd => 'Add';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonMoreActions => 'More actions';

  @override
  String get commonNo => 'No';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonSave => 'Save';

  @override
  String get errorNotFound => 'This wasn\'t found. It may have been deleted.';

  @override
  String get errorValidation =>
      'Some details weren\'t accepted. Check them and try again.';

  @override
  String get errorFileTooLarge =>
      'This file is too large. Upload files up to 15 MB.';

  @override
  String get errorFileUnsupported =>
      'This file type isn\'t supported. Use a JPEG, PNG or WebP photo, or a PDF.';

  @override
  String get formServerFieldError => 'This value wasn\'t accepted. Check it.';

  @override
  String get formCheckFields => 'Check the highlighted fields.';

  @override
  String formTooLong(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Use $max characters or fewer',
      one: 'Use 1 character or fewer',
    );
    return '$_temp0';
  }

  @override
  String dateMedium(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get dateNotSet => 'Not set';

  @override
  String get dateClear => 'Clear date';

  @override
  String get filePdf => 'PDF';

  @override
  String get mediaTakePhoto => 'Take photo';

  @override
  String get mediaChooseFromLibrary => 'Choose from library';

  @override
  String get mediaChoosePdf => 'Choose a PDF file';

  @override
  String get mediaRemovePhoto => 'Remove photo';

  @override
  String get mediaPickerFailed =>
      'Couldn\'t open the camera or photos. Check the app\'s access in Settings.';

  @override
  String get mediaPageAddedTitle => 'Page added';

  @override
  String get mediaPageAddedBody => 'Take a photo of another page?';

  @override
  String get mediaDone => 'Done';

  @override
  String get mediaAddAnotherPage => 'Add another page';

  @override
  String uploadProgress(int current, int total) {
    return 'Uploading $current of $total';
  }

  @override
  String get uploadSaving => 'Saving';

  @override
  String get pdfOpenFailed => 'Couldn\'t open the PDF.';

  @override
  String pageNumber(int number) {
    return 'Page $number';
  }

  @override
  String pageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String pageRemove(int number) {
    return 'Remove page $number';
  }

  @override
  String get pageDelete => 'Delete page';

  @override
  String get pageDeleteTitle => 'Delete this page?';

  @override
  String get pageDeleteBody =>
      'The photo of this page will be deleted. You can\'t undo this.';

  @override
  String get pageLoadFailed => 'Couldn\'t load the page.';

  @override
  String get petsAdd => 'Add pet';

  @override
  String get petSpeciesOtherShort => 'Other';

  @override
  String get petSexFemale => 'Female';

  @override
  String get petSexMale => 'Male';

  @override
  String get petSexUnknown => 'Unknown';

  @override
  String get petStatusActive => 'Active';

  @override
  String get petStatusArchived => 'Archived';

  @override
  String get petStatusDeceased => 'Deceased';

  @override
  String get petNameLabel => 'Name';

  @override
  String get petNameRequired => 'Enter the pet\'s name';

  @override
  String get petSpeciesLabel => 'Species';

  @override
  String get petSexLabel => 'Sex';

  @override
  String get petBreedLabel => 'Breed';

  @override
  String get petBreedHint => 'e.g. Maine Coon';

  @override
  String get petBirthDateLabel => 'Date of birth';

  @override
  String get petBirthDateApproximate => 'The date is approximate';

  @override
  String petBirthDateAbout(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'About $dateString';
  }

  @override
  String get petNeuteredLabel => 'Neutered or spayed';

  @override
  String get petNeuteredOnLabel => 'Date of neutering (optional)';

  @override
  String petNeuteredOnValue(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Yes, $dateString';
  }

  @override
  String get petNeuteredBeforeBirth =>
      'Neutering can\'t be before the date of birth';

  @override
  String get petColorLabel => 'Coat colour';

  @override
  String get petColorHint => 'As in the passport, e.g. black and white';

  @override
  String get petMarkingsLabel => 'Markings';

  @override
  String get petMarkingsHint => 'e.g. white spot on the chest';

  @override
  String get petAllergiesLabel => 'Allergies';

  @override
  String get petAllergiesHint => 'Food, medicines';

  @override
  String get petNotesLabel => 'Notes';

  @override
  String get petFormAddTitle => 'New pet';

  @override
  String get petFormEditTitle => 'Edit details';

  @override
  String get petPhotoAdd => 'Add photo';

  @override
  String get petPhotoChange => 'Change photo';

  @override
  String get petPhotoOpen => 'Open photo';

  @override
  String get petPhotoUploading => 'Uploading photo';

  @override
  String get petPhotoSaveFailed =>
      'The pet is saved, but the photo couldn\'t be uploaded. Try again on the pet\'s page.';

  @override
  String get petPhotoRemoveTitle => 'Remove the photo?';

  @override
  String get petPhotoRemoveBody =>
      'The photo will be deleted. You can\'t undo this.';

  @override
  String get petDetailsTitle => 'Details';

  @override
  String get petEdit => 'Edit details';

  @override
  String get petDelete => 'Delete pet';

  @override
  String petDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get petDeleteBody =>
      'This also deletes the passport details, documents and photos. You can\'t undo this.';

  @override
  String get petTabOverview => 'Overview';

  @override
  String get petTabPassport => 'Passport';

  @override
  String get petTabDocuments => 'Documents';

  @override
  String get identifiersTitle => 'Microchips and tattoos';

  @override
  String get identifiersEmpty => 'No microchip or tattoo yet.';

  @override
  String get identifiersAdd => 'Add a microchip or tattoo';

  @override
  String get identifierTypeLabel => 'Type';

  @override
  String get identifierTypeIsoChip => 'ISO microchip';

  @override
  String get identifierTypeLegacyChip => 'Non-ISO microchip';

  @override
  String get identifierTypeTattoo => 'Tattoo';

  @override
  String get identifierChipLabel => 'Chip number';

  @override
  String get identifierTattooLabel => 'Tattoo code';

  @override
  String get identifierChipDateLabel => 'Date implanted';

  @override
  String get identifierTattooDateLabel => 'Date applied';

  @override
  String get identifierLocationLabel => 'Location';

  @override
  String get identifierLocationHint => 'e.g. left side of the neck';

  @override
  String get identifierRemove => 'Remove from the list';

  @override
  String get identifierCodeRequired => 'Enter the number';

  @override
  String get identifierIsoHint => '15 digits, e.g. 276 098 100 123 456';

  @override
  String get identifierIsoLength => 'An ISO microchip number has 15 digits';

  @override
  String get identifierIsoTestChip =>
      'Numbers starting with 999 belong to test chips';

  @override
  String get identifierLegacyFormat =>
      'Use 10 characters 0–9 and A–F, or 9 digits (AVID)';

  @override
  String get identifierLegacyHint =>
      'Not ISO: take your own scanner when travelling.';

  @override
  String identifierTattooLength(int max) {
    return 'Use 1 to $max letters and digits';
  }

  @override
  String get identifierDuplicate => 'This number is already in the list';

  @override
  String identifierChipImplantedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Implanted $dateString';
  }

  @override
  String identifierTattooAppliedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Applied $dateString';
  }

  @override
  String get chipScanAction => 'Scan the number';

  @override
  String get chipScanTitle => 'Microchip number';

  @override
  String get chipScanHint => 'Point the camera at the chip sticker';

  @override
  String get chipScanCameraUnavailable =>
      'The camera isn\'t available. Allow camera access in Settings, or use a photo.';

  @override
  String get chipScanNotChip => 'That isn\'t a microchip number';

  @override
  String get chipScanFromPhoto => 'From a photo';

  @override
  String get chipScanFreeTier =>
      'A photo without a readable barcode goes to AI on Gemini\'s free tier: only your own documents.';

  @override
  String get chipScanReading =>
      'Reading the photo… Usually a few seconds, sometimes a minute.';

  @override
  String get chipScanPickTitle =>
      'Several numbers on the photo. Which one is it?';

  @override
  String get chipScanPickFound =>
      'Several chip numbers found. Which one is it?';

  @override
  String get chipScanNothingFound =>
      'No chip number found on the photo — type it in.';

  @override
  String get chipScanCheck =>
      'Read from the photo: check it against the passport.';

  @override
  String get chipScanBusy =>
      'AI is busy right now. Try again in a minute, or type the number in.';

  @override
  String get chipScanNoAi =>
      'No barcode on the photo, and AI isn\'t set up to read it: type the number in.';

  @override
  String get chipScanRejected =>
      'AI refused to read the photo. Type the number in.';

  @override
  String get passportTitle => 'Passport details';

  @override
  String get passportDisclaimer =>
      'This digital copy is for your information. The paper passport stays the official document.';

  @override
  String get passportEmpty =>
      'Add the passport number, the vet who issued it and the owners.';

  @override
  String get passportAdd => 'Add details';

  @override
  String get passportFormTitle => 'Passport details';

  @override
  String get passportModelLabel => 'Passport model';

  @override
  String get passportModelEu2014 => 'EU passport (2014 model)';

  @override
  String get passportModelEu2026 => 'EU passport (2026 model)';

  @override
  String get passportModelOther => 'Other passport';

  @override
  String get passportModelNotSet => 'Not specified';

  @override
  String get passportNumberLabel => 'Passport number';

  @override
  String get passportNumberHint => 'e.g. DE01234567';

  @override
  String get passportNumberInvalid =>
      'Use up to 30 letters, digits, hyphens and slashes';

  @override
  String get passportCountryLabel => 'Issuing country';

  @override
  String get passportCountryHint => 'Two-letter code, e.g. DE';

  @override
  String get passportCountryInvalid =>
      'Use the two-letter country code, such as DE or FR';

  @override
  String get passportIssuedOnLabel => 'Date of issue';

  @override
  String get passportIssuerTitle => 'Issuing vet';

  @override
  String get passportOwnersTitle => 'Owners';

  @override
  String get passportOwnerTitle => 'Owner';

  @override
  String passportOwnerNumbered(int number) {
    return 'Owner $number';
  }

  @override
  String get passportOwnerAdd => 'Add owner';

  @override
  String get passportOwnerRemove => 'Remove owner';

  @override
  String get passportNotesLabel => 'Notes';

  @override
  String get passportPagesTitle => 'Pages';

  @override
  String get passportPagesAdd => 'Add pages';

  @override
  String get passportPagesRetry => 'Upload again';

  @override
  String get passportPagesEmpty =>
      'Photograph the pages of the paper passport to keep a copy at hand.';

  @override
  String get contactNameLabel => 'Name';

  @override
  String get contactAddressLabel => 'Address';

  @override
  String get contactPhoneLabel => 'Phone';

  @override
  String get contactEmailLabel => 'Email';

  @override
  String get documentsAdd => 'Add document';

  @override
  String get documentsEmptyTitle => 'No documents yet';

  @override
  String get documentsEmptyBody =>
      'Lab results, prescriptions and certificates will appear here.';

  @override
  String get documentTypeLabel => 'Type';

  @override
  String get documentTypePassportPage => 'Passport pages';

  @override
  String get documentTypeVaccinationCertificate => 'Vaccination certificate';

  @override
  String get documentTypeLabResult => 'Lab results';

  @override
  String get documentTypePrescription => 'Prescription';

  @override
  String get documentTypeInvoice => 'Invoice';

  @override
  String get documentTypeInsurance => 'Insurance';

  @override
  String get documentTypeOther => 'Other document';

  @override
  String documentPageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get documentFormAddTitle => 'New document';

  @override
  String get documentFormEditTitle => 'Edit document';

  @override
  String get documentTitleLabel => 'Title (optional)';

  @override
  String get documentTitleHint => 'e.g. Blood test';

  @override
  String get documentDateLabel => 'Document date';

  @override
  String get documentNotesLabel => 'Notes';

  @override
  String get documentPagesTitle => 'Pages';

  @override
  String get documentPagesAdd => 'Add pages';

  @override
  String get documentPagesEmpty => 'Take photos of the pages or choose a PDF.';

  @override
  String get documentPagesRequired => 'Add at least one page';

  @override
  String documentPagesTooMany(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Use $max pages or fewer',
      one: 'Use 1 page or fewer',
    );
    return '$_temp0';
  }

  @override
  String get documentDetailsTitle => 'Details';

  @override
  String get documentAddedOnLabel => 'Added';

  @override
  String get documentDelete => 'Delete document';

  @override
  String get documentDeleteTitle => 'Delete this document?';

  @override
  String get documentDeleteBody =>
      'All its pages will be deleted too. You can\'t undo this.';

  @override
  String get petTabHealth => 'Health';

  @override
  String get careKindLabel => 'Type';

  @override
  String get careKindVaccination => 'Vaccination';

  @override
  String get careKindRabiesTiter => 'Rabies antibody test';

  @override
  String get careKindDeworming => 'Deworming';

  @override
  String get careKindEchinococcus => 'Echinococcus treatment';

  @override
  String get careKindFleaTick => 'Fleas and ticks';

  @override
  String get careKindHeartworm => 'Heartworm';

  @override
  String get careKindVetExam => 'Check-up';

  @override
  String get careKindDental => 'Dental care';

  @override
  String get careKindGrooming => 'Grooming';

  @override
  String get careKindProcedure => 'Procedure';

  @override
  String get careKindOther => 'Other';

  @override
  String get careTargetsLabel => 'Protects against';

  @override
  String get vaccineTargetRabies => 'Rabies';

  @override
  String get vaccineTargetFpv => 'Panleukopenia (FPV)';

  @override
  String get vaccineTargetFhv1 => 'Herpesvirus (FHV-1)';

  @override
  String get vaccineTargetFcv => 'Calicivirus (FCV)';

  @override
  String get vaccineTargetFelv => 'Leukaemia (FeLV)';

  @override
  String get vaccineTargetChlamydia => 'Chlamydia';

  @override
  String get vaccineTargetCdv => 'Distemper (CDV)';

  @override
  String get vaccineTargetCav2 => 'Hepatitis (CAV-2)';

  @override
  String get vaccineTargetCpv2 => 'Parvovirus (CPV-2)';

  @override
  String get vaccineTargetCpiv => 'Parainfluenza (CPiV)';

  @override
  String get vaccineTargetLepto => 'Leptospirosis';

  @override
  String get vaccineTargetBordetella => 'Kennel cough (Bordetella)';

  @override
  String get vaccineTargetLyme => 'Lyme disease';

  @override
  String get vaccineTargetCanineInfluenza => 'Canine influenza';

  @override
  String get vaccineTargetLeishmania => 'Leishmaniasis';

  @override
  String get intervalOneOff => 'One-off';

  @override
  String get intervalRepeats => 'Repeats';

  @override
  String get intervalEveryDay => 'Every day';

  @override
  String get intervalEveryWeek => 'Every week';

  @override
  String get intervalEveryMonth => 'Every month';

  @override
  String get intervalEveryYear => 'Every year';

  @override
  String intervalEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String intervalEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String intervalEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String intervalEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String intervalUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String intervalUnitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'weeks',
      one: 'week',
    );
    return '$_temp0';
  }

  @override
  String intervalUnitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$_temp0';
  }

  @override
  String intervalUnitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'years',
      one: 'year',
    );
    return '$_temp0';
  }

  @override
  String get dueToday => 'Today';

  @override
  String get dueTomorrow => 'Tomorrow';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String dueInMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'In $months months',
      one: 'In 1 month',
    );
    return '$_temp0';
  }

  @override
  String dueOverdueDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String get careStatusOverdue => 'Overdue';

  @override
  String get careStatusDueSoon => 'Due soon';

  @override
  String get careStatusUpcoming => 'Upcoming';

  @override
  String get careStatusFinished => 'Finished';

  @override
  String get careStatusPaused => 'Paused';

  @override
  String get healthGroupInactive => 'Finished or paused';

  @override
  String get healthPlansTitle => 'Care plan';

  @override
  String get healthPlansAdd => 'Add plan';

  @override
  String get healthPlansEmpty =>
      'No plans yet. Add vaccinations and treatments to see when they are due.';

  @override
  String healthInactiveToggle(int count) {
    return 'Finished or paused ($count)';
  }

  @override
  String get healthHistoryTitle => 'History';

  @override
  String get healthHistoryAdd => 'Add past record';

  @override
  String get healthHistoryEmpty =>
      'No records yet. Add past vaccinations and treatments from the paper passport.';

  @override
  String get healthFilterAll => 'All';

  @override
  String get planDone => 'Done';

  @override
  String planLastDone(String date) {
    return 'Last done $date';
  }

  @override
  String recordPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get presetPickerTitle => 'Choose a plan';

  @override
  String get presetOwnTitle => 'Own plan';

  @override
  String get presetOwnBody => 'Set the type and how often yourself.';

  @override
  String get presetDogOnly => 'Dogs only';

  @override
  String get presetNoneForSpecies =>
      'There are no ready-made plans for this animal yet.';

  @override
  String get presetGroupVaccinations => 'Vaccinations';

  @override
  String get presetGroupDeworming => 'Deworming';

  @override
  String get presetGroupParasites => 'Fleas, ticks and heartworm';

  @override
  String get presetGroupCheckUps => 'Check-ups and care';

  @override
  String get presetGroupTravel => 'Before travel';

  @override
  String get presetCatFvrcp => 'FVRCP (panleukopenia, herpes, calici)';

  @override
  String get presetCatFvrcpNote =>
      'After the kitten series and the 6-month booster. Low-risk indoor cats: every 3 years.';

  @override
  String get presetCatFvrcpKitten => 'FVRCP kitten series';

  @override
  String get presetCatFvrcpKittenNote =>
      'From 6–8 weeks every 3–4 weeks until 16–20 weeks, then the yearly plan.';

  @override
  String get presetRabies => 'Rabies';

  @override
  String get presetRabiesNote =>
      'The vaccine label says 1 or 3 years: use its \"valid until\" date.';

  @override
  String get presetCatFelv => 'Feline leukaemia (FeLV)';

  @override
  String get presetCatFelvNote =>
      'Test first. Two doses 3–4 weeks apart, then yearly for cats that go outside.';

  @override
  String get presetCatChlamydia => 'Chlamydia';

  @override
  String get presetCatChlamydiaNote => 'Only when the cat is at risk.';

  @override
  String get presetDeworm => 'Deworming';

  @override
  String get presetDewormNote =>
      'When the risk is unknown: at least 4 times a year.';

  @override
  String get presetCatDewormIndoor => 'Deworming, indoor cat';

  @override
  String get presetCatDewormIndoorNote => 'Indoor cats: 1–2 times a year.';

  @override
  String get presetCatDewormOutdoor => 'Deworming, cat that hunts';

  @override
  String get presetCatDewormOutdoorNote =>
      'Cats that go out and hunt: 4–12 times a year.';

  @override
  String get presetCatDewormKitten => 'Deworming, kitten';

  @override
  String get presetCatDewormKittenNote =>
      'From 3 weeks every 2 weeks until weaning, then monthly until 6 months.';

  @override
  String get presetFleaTickMonthly => 'Fleas and ticks, monthly';

  @override
  String get presetCatFleaTickMonthlyNote =>
      'Monthly products such as Frontline, Advantage or Revolution.';

  @override
  String get presetBravecto => 'Bravecto';

  @override
  String get presetBravectoNote => 'Some ticks: 8 weeks.';

  @override
  String get presetCatBravectoPlus =>
      'Bravecto Plus (also worms and heartworm)';

  @override
  String get presetCatBravectoPlusNote => 'US label: 2 months.';

  @override
  String get presetSeresto => 'Seresto collar';

  @override
  String get presetExam => 'Check-up';

  @override
  String get presetCatExamNote => 'From 10 years old: every 6 months.';

  @override
  String get presetDental => 'Dental check';

  @override
  String get presetNails => 'Nail trim';

  @override
  String get presetDogDhpp =>
      'DHPP (distemper, hepatitis, parvo, parainfluenza)';

  @override
  String get presetDogDhppNote =>
      'After the puppy series and the booster at about 6 months or 1 year.';

  @override
  String get presetDogDhppPuppy => 'DHPP puppy series';

  @override
  String get presetDogDhppPuppyNote =>
      'From 6–8 weeks every 2–4 weeks until at least 16 weeks, then the 3-year plan.';

  @override
  String get presetDogLepto => 'Leptospirosis';

  @override
  String get presetDogLeptoNote =>
      'First 2 doses 2–4 weeks apart, then yearly.';

  @override
  String get presetDogKennelCough => 'Kennel cough';

  @override
  String get presetDogKennelCoughNote =>
      'For dogs that meet other dogs: boarding, training, shows.';

  @override
  String get presetDogLyme => 'Lyme disease';

  @override
  String get presetDogLymeNote => 'Where ticks carry Lyme disease.';

  @override
  String get presetDogLeishmania => 'Leishmaniasis';

  @override
  String get presetDogLeishmaniaNote => 'Southern Europe.';

  @override
  String get presetDogDewormIndoor => 'Deworming, mostly indoors';

  @override
  String get presetDogDewormIndoorNote =>
      'Dogs that stay home: 1–2 times a year.';

  @override
  String get presetDogDewormHigh => 'Deworming, high risk';

  @override
  String get presetDogDewormHighNote =>
      'Dogs that hunt, eat snails or grass, or get raw meat: up to 12 times a year.';

  @override
  String get presetDogDewormPuppy => 'Deworming, puppy';

  @override
  String get presetDogDewormPuppyNote =>
      'From 14 days every 2 weeks until weaning, then monthly until 6 months.';

  @override
  String get presetDogFleaTickMonthlyNote =>
      'Monthly products such as NexGard, Simparica, Credelio or Frontline.';

  @override
  String get presetDogAdvantix => 'K9 Advantix';

  @override
  String get presetDogAdvantixNote =>
      'Contains permethrin, which is toxic to cats. Never use it on a cat.';

  @override
  String get presetDogHeartworm => 'Heartworm prevention';

  @override
  String get presetDogEchinococcus => 'Tapeworm treatment before travel';

  @override
  String get presetDogEchinococcusNote =>
      'Finland, Ireland, Malta, Northern Ireland, Norway, the UK: 24–120 hours before entry. The vet writes the date and time.';

  @override
  String get presetDogExamNote => 'Senior dogs: every 6 months.';

  @override
  String get planFormAddTitle => 'New plan';

  @override
  String get planFormEditTitle => 'Edit plan';

  @override
  String get planTitleLabel => 'What to do';

  @override
  String get planTitleHint => 'e.g. Deworming';

  @override
  String get planTitleRequired => 'Enter what needs to be done';

  @override
  String get planRepeatLabel => 'How often';

  @override
  String get planRepeats => 'Repeats';

  @override
  String get planOnce => 'Once';

  @override
  String get planIntervalLabel => 'Every';

  @override
  String planIntervalInvalid(int max) {
    return 'Use a whole number from 1 to $max';
  }

  @override
  String get planLastDoneLabel => 'Last done (optional)';

  @override
  String get planLastDoneHelper => 'The next date is counted from it.';

  @override
  String get planNextDueLabel => 'Next due';

  @override
  String get planDueOnLabel => 'Due on';

  @override
  String get planNextDueComputed =>
      'Counted from the last time and the interval. You can change it.';

  @override
  String get dateRequired => 'Choose a date';

  @override
  String get planDefaultProductLabel => 'Usual product (optional)';

  @override
  String get planDefaultProductHint => 'e.g. Milbemax';

  @override
  String get planDefaultProductHelper =>
      'Filled in when you mark the plan done.';

  @override
  String get careNotesLabel => 'Notes';

  @override
  String get planActiveLabel => 'Active';

  @override
  String get planActiveHelper => 'Turn off to pause the plan: it leaves Today.';

  @override
  String get planDelete => 'Delete plan';

  @override
  String get planDeleteTitle => 'Delete this plan?';

  @override
  String get planDeleteBody =>
      'Records already made with it stay in the history. You can\'t undo this.';

  @override
  String get careGonePlan =>
      'This plan has been deleted, probably on another device.';

  @override
  String get careGoneRecord =>
      'This record has been deleted, probably on another device.';

  @override
  String get careGonePet =>
      'This pet has been deleted, probably on another device.';

  @override
  String get planReadOnly =>
      'This plan was made in a newer version of Collarbell. Update the app to edit it.';

  @override
  String get doneTitle => 'Mark as done';

  @override
  String get donePerformedOnLabel => 'Done on';

  @override
  String get careTimeLabel => 'Time';

  @override
  String get careTimeHelper =>
      'Travel rules count the hours from the treatment.';

  @override
  String get careProductLabel => 'Product';

  @override
  String get careManufacturerLabel => 'Manufacturer';

  @override
  String get careBatchLabel => 'Batch number';

  @override
  String get careValidFromLabel => 'Valid from';

  @override
  String get careValidUntilLabel => 'Valid until';

  @override
  String get doneValidUntilHelper =>
      'As on the vaccine sticker. The next date follows it.';

  @override
  String get careClinicLabel => 'Clinic';

  @override
  String get careVetLabel => 'Vet';

  @override
  String get doneNextTitle => 'Next time';

  @override
  String doneNextFromInterval(String interval) {
    return '$interval from this date';
  }

  @override
  String get doneNextFromValidUntil => 'When the vaccine stops protecting';

  @override
  String get doneNextChosen => 'Chosen by you';

  @override
  String get doneNextFinished => 'This one-off plan finishes when it\'s done.';

  @override
  String get doneNextUnknown => 'Worked out when you save.';

  @override
  String get doneNextChange => 'Change';

  @override
  String get doneNextReset => 'Use the worked-out date';

  @override
  String doneSaved(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Marked as done. Next time: $dateString.';
  }

  @override
  String get doneSavedFinished => 'Marked as done. The plan is finished.';

  @override
  String get donePhotosFailed =>
      'Marked as done, but some photos weren\'t attached. Save again to attach them.';

  @override
  String get doneCompletedNotice =>
      'Already marked as done. Only the photos are left to attach.';

  @override
  String get carePhotosTitle => 'Photos';

  @override
  String get carePhotosAdd => 'Add photos';

  @override
  String get carePhotosEmpty =>
      'Photograph the vaccine sticker or the vet\'s notes.';

  @override
  String carePhotosTooMany(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Use $max photos or fewer',
      one: 'Use 1 photo or fewer',
    );
    return '$_temp0';
  }

  @override
  String photoNumber(int number) {
    return 'Photo $number';
  }

  @override
  String photoRemove(int number) {
    return 'Remove photo $number';
  }

  @override
  String get recordFormAddTitle => 'New record';

  @override
  String get recordFormEditTitle => 'Edit record';

  @override
  String get recordTitleLabel => 'Title';

  @override
  String get recordTitleHint => 'e.g. Rabies';

  @override
  String get recordTitleRequired => 'Enter what was done';

  @override
  String get recordPerformedOnLabel => 'Date';

  @override
  String get recordLaboratoryLabel => 'Laboratory';

  @override
  String get recordReportNumberLabel => 'Report number';

  @override
  String get recordTiterLabel => 'Result, IU/ml';

  @override
  String get recordTiterHelper => 'Travel to the EU needs at least 0.5 IU/ml.';

  @override
  String get recordTiterInvalid => 'Use a number from 0 to 1000';

  @override
  String get recordWeightLabel => 'Weight, kg';

  @override
  String get recordWeightInvalid => 'Use a weight above 0 and up to 200 kg';

  @override
  String get recordFitForTravel => 'Fit to travel';

  @override
  String get recordNotFitForTravel => 'Not fit to travel';

  @override
  String get recordValidFromInvalid =>
      'Can\'t be before the date of the vaccination';

  @override
  String get recordValidUntilInvalid =>
      'Must be after the date of the vaccination and the start';

  @override
  String get recordReadOnly =>
      'This record was made in a newer version of Collarbell. Update the app to edit it.';

  @override
  String get recordPhotosFailed =>
      'The record is saved, but some photos weren\'t attached. Save again to attach them.';

  @override
  String get recordDelete => 'Delete record';

  @override
  String get recordDeleteTitle => 'Delete this record?';

  @override
  String get recordDeleteBody =>
      'Its photos will be deleted too. A plan it completed keeps its date. You can\'t undo this.';

  @override
  String get recordDetailsTitle => 'Details';

  @override
  String get recordSourceLabel => 'Source';

  @override
  String get recordSourceManual => 'Added by hand';

  @override
  String get recordSourceScan => 'From a scan';

  @override
  String recordTiterValue(String value) {
    return '$value IU/ml';
  }

  @override
  String recordWeightValue(String value) {
    return '$value kg';
  }

  @override
  String dateWithTime(DateTime date, String time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString, $time';
  }

  @override
  String careValidRange(DateTime from, DateTime until) {
    final intl.DateFormat fromDateFormat = intl.DateFormat.yMMMd(localeName);
    final String fromString = fromDateFormat.format(from);
    final intl.DateFormat untilDateFormat = intl.DateFormat.yMMMd(localeName);
    final String untilString = untilDateFormat.format(until);

    return 'Valid $fromString – $untilString';
  }

  @override
  String careValidFromValue(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Valid from $dateString';
  }

  @override
  String careValidUntilValue(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Valid until $dateString';
  }

  @override
  String careBatchValue(String batch) {
    return 'Batch $batch';
  }

  @override
  String get timeNotSet => 'Not set';

  @override
  String get timeClear => 'Clear time';

  @override
  String get passportSectionRabies => 'V. Rabies vaccination';

  @override
  String get passportSectionTiter => 'VI. Rabies antibody test';

  @override
  String get passportSectionEchinococcus => 'VII. Echinococcus treatment';

  @override
  String get passportSectionTreatments => 'VIII. Other parasite treatments';

  @override
  String get passportSectionOtherVaccinations => 'IX. Other vaccinations';

  @override
  String get passportSectionExaminations => 'X. Clinical examination';

  @override
  String get passportSectionEmpty => 'No entries yet.';

  @override
  String get todayGroupLater => 'Later';

  @override
  String get moreAi => 'AI';

  @override
  String get aiTitle => 'Reading photos with AI';

  @override
  String get aiConnected => 'Connected';

  @override
  String get aiNotConnected => 'Not set up';

  @override
  String get aiChecking => 'Checking…';

  @override
  String get aiConnectedBody =>
      'AI reads photos of passport pages and vet documents, and notes written in words, and prepares a draft. Nothing is saved until you check it.';

  @override
  String get aiNotConnectedBody =>
      'AI is connected in the server settings. Until then the scan and note buttons are hidden; adding records by hand always works.';

  @override
  String get aiFreeTierWarning =>
      'Free Gemini tier: Google may use what is sent to improve its products, and human reviewers may read it. Scan only your own documents.';

  @override
  String get aiModelsTitle => 'Models';

  @override
  String get aiModelsHint =>
      'They are tried in this order: when one is busy or out of free requests, the next one reads the photos.';

  @override
  String get aiModelReady => 'Ready';

  @override
  String get aiModelNotReady => 'No key';

  @override
  String get aiProviderGemini => 'Google Gemini';

  @override
  String get aiProviderOpenAiCompatible => 'OpenAI-compatible service';

  @override
  String get aiProviderOllama => 'Ollama';

  @override
  String get aiProviderOther => 'Other service';

  @override
  String get aiUsageTitle => 'This month';

  @override
  String get aiUsageRequests => 'Requests';

  @override
  String get aiUsageInputTokens => 'Tokens sent';

  @override
  String get aiUsageOutputTokens => 'Tokens received';

  @override
  String get aiTestTitle => 'Connection test';

  @override
  String get aiTestHint =>
      'A model is asked the colour of a square on a small picture. It can take up to a minute.';

  @override
  String get aiTestButton => 'Test connection';

  @override
  String aiTestOk(String model, String seconds) {
    return 'It works: $model answered in $seconds s.';
  }

  @override
  String get aiTestFailed => 'It doesn\'t work.';

  @override
  String get aiTestProblemNotConfigured =>
      'No AI model is set up on the server.';

  @override
  String get aiTestProblemBusy =>
      'The models are busy or out of free requests. Try again in a few minutes.';

  @override
  String get aiTestProblemRejected =>
      'The AI service refused the request: the key on the server may be wrong or expired.';

  @override
  String get aiTestProblemWrongAnswer =>
      'A model answered but didn\'t see the picture.';

  @override
  String get scanCardTitle => 'Scan passport pages';

  @override
  String get scanCardBody =>
      'AI reads vaccinations, treatments, microchips and passport details from photos. You check everything before it\'s saved.';

  @override
  String get scanCardButton => 'Scan pages';

  @override
  String get scanFromPassport => 'Scan from passport';

  @override
  String scanResumeReady(String date) {
    return 'Continue checking the scan from $date';
  }

  @override
  String scanResumeOpen(String date) {
    return 'Scan from $date';
  }

  @override
  String get scanStatusQueued => 'Waiting to be read';

  @override
  String get scanStatusProcessing => 'Reading the pages…';

  @override
  String get scanStatusReady => 'Ready to check';

  @override
  String get scanStatusApplied => 'Saved';

  @override
  String get scanStatusFailed => 'Couldn\'t be read';

  @override
  String get scanStatusDiscarded => 'Discarded';

  @override
  String get scanTitlePassport => 'Scan passport pages';

  @override
  String get scanTitleDocument => 'Scan a vet document';

  @override
  String get scanSourceLabel => 'What are you scanning?';

  @override
  String get scanSourcePassport => 'Passport';

  @override
  String get scanSourceDocument => 'Vet document';

  @override
  String scanStartPassportBody(int max) {
    return 'Photograph the pages with vaccinations, treatments, the microchip and the passport details. Up to $max pages at a time.';
  }

  @override
  String scanStartDocumentBody(int max) {
    return 'A vaccination certificate, an invoice or another paper from the vet. Up to $max pages at a time.';
  }

  @override
  String get scanStartDraftNote =>
      'AI only prepares a draft: you check every entry and decide what to save.';

  @override
  String get scanWithCamera => 'Scan with the camera';

  @override
  String get scanChoosePhotos => 'Choose from photos';

  @override
  String get scanScannerUnavailable =>
      'The scanner isn\'t available on this device. Choose photos of the pages instead.';

  @override
  String scanTooManyPages(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Only the first $max pages are used.',
      one: 'Only the first page is used.',
    );
    return '$_temp0';
  }

  @override
  String get scanStarting => 'Sending the pages to AI…';

  @override
  String get scanPhotosRefused =>
      'Some photos couldn\'t be used. Try again to upload them anew.';

  @override
  String get scanStartOver => 'Scan again';

  @override
  String get scanReadingBody => 'Usually 10–60 seconds.';

  @override
  String get scanReadingSlow =>
      'Taking longer than usual: the AI models may be busy. You can wait or come back later.';

  @override
  String get scanReadingOffline => 'Can\'t reach the server. Trying again…';

  @override
  String get scanReadingLeave =>
      'You can leave this screen: the pages are read on the server, and the scan waits for you on the Passport tab.';

  @override
  String get scanErrorBusy =>
      'The AI models are busy or out of free requests right now. Try again in a few minutes.';

  @override
  String get scanErrorNotConfigured =>
      'AI isn\'t set up on the server. Connect a model in the server configuration, then scan again. Records can always be added by hand.';

  @override
  String get scanErrorRejected =>
      'The AI service refused the request. The API key on the server may be wrong or expired.';

  @override
  String get scanErrorPhotosMissing =>
      'The photos of this scan are gone. Scan the pages again.';

  @override
  String get scanErrorUnexpected =>
      'Something went wrong while reading the pages. Try again.';

  @override
  String get scanClose => 'Close';

  @override
  String get scanDiscardedBody => 'Nothing from this scan was saved.';

  @override
  String get scanGone => 'This scan no longer exists.';

  @override
  String get scanReviewTitle => 'Check the scan';

  @override
  String get scanReviewIntro =>
      'AI read these entries from the photos. Check them against the paper, fix what\'s wrong, and untick what you don\'t want to save.';

  @override
  String get scanRecordsTitle => 'Records';

  @override
  String get scanNothingFound =>
      'AI found nothing to save on these photos. You can keep the photos or discard the scan.';

  @override
  String get scanKeepPhotosPassport => 'Keep the photos as passport pages';

  @override
  String get scanKeepPhotosPassportHelper =>
      'They are added after the pages you have.';

  @override
  String get scanKeepPhotosDocument => 'Keep the photos as a document';

  @override
  String get scanKeepPhotosDocumentHelper =>
      'They become a new document on the Documents tab.';

  @override
  String scanSaveSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save $count selected',
      one: 'Save 1 selected',
      zero: 'Nothing to save',
    );
    return '$_temp0';
  }

  @override
  String get scanSavePhotosOnly => 'Save the photos only';

  @override
  String get scanDiscard => 'Discard scan';

  @override
  String get scanDiscardTitle => 'Discard this scan?';

  @override
  String get scanDiscardBody =>
      'Nothing from it is saved, and its photos are deleted.';

  @override
  String get scanDiscardConfirm => 'Discard';

  @override
  String get scanDiscarded => 'Scan discarded';

  @override
  String get scanSelectEntry => 'Save this entry';

  @override
  String get scanBadgeAlreadySaved => 'Already saved';

  @override
  String get scanBadgeRepeated => 'Same as another entry';

  @override
  String get scanBadgeDiffers => 'Differs from what\'s saved';

  @override
  String get scanNotRead => 'Not read';

  @override
  String get scanEnterDate => 'Enter the date';

  @override
  String get scanNeedsDate => 'Enter the date to save this entry.';

  @override
  String get scanNeedsCode => 'Enter the number to save this entry.';

  @override
  String get scanNothingToFill => 'Nothing was read here.';

  @override
  String get scanDateInFuture => 'A date in the future can\'t be saved';

  @override
  String get scanIssueUnreadable =>
      'Couldn\'t be read. Enter it from the paper.';

  @override
  String get scanIssueAmbiguous =>
      'Day and month could be swapped. Check against the paper.';

  @override
  String scanSwapTo(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Change to $dateString';
  }

  @override
  String get scanIssueInFuture => 'This date is in the future. Check it.';

  @override
  String get scanIssueEndsBeforeStart =>
      '“Valid until” isn\'t after the vaccination date. Check it.';

  @override
  String get scanIssueInvalidFormat =>
      'This doesn\'t look right. Check it against the paper.';

  @override
  String get scanIssueAlreadySaved =>
      'The same entry is already in the history.';

  @override
  String get scanIssueAlreadySavedCode => 'The pet already has this number.';

  @override
  String get scanIssueRepeated => 'The same entry is on another photo.';

  @override
  String get scanIssueOther => 'Check this value.';

  @override
  String scanSavedValue(String value) {
    return 'Saved: $value';
  }

  @override
  String scanReadOnPage(int number) {
    return 'Read on page $number';
  }

  @override
  String scanEvidence(String text) {
    return '“$text”';
  }

  @override
  String scanPlanDone(String title) {
    return 'Mark as done in plan “$title”';
  }

  @override
  String get scanPlanLink => 'Mark as done in a plan';

  @override
  String get scanPlanHint =>
      'The plan moves on only if this entry is newer than its last “Done”.';

  @override
  String get scanPlanChange => 'Choose another plan';

  @override
  String get scanPlanPickTitle => 'Mark as done in which plan?';

  @override
  String get scanPlanNone => 'No plan';

  @override
  String get scanEntryFix => 'Fix this entry or untick it.';

  @override
  String get scanEditRecordTitle => 'Edit entry';

  @override
  String get scanEditIdentifierTitle => 'Edit microchip or tattoo';

  @override
  String get scanEditPassportTitle => 'Edit passport details';

  @override
  String get scanEditDone => 'Done';

  @override
  String get scanPassportKeeps =>
      'An empty field keeps what is saved; a value you change here replaces it.';

  @override
  String scanSavedRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count records',
      one: 'Saved 1 record',
    );
    return '$_temp0';
  }

  @override
  String scanSavedPlans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plans updated',
      one: '1 plan updated',
    );
    return '$_temp0';
  }

  @override
  String scanSavedIdentifiers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count microchips and tattoos added',
      one: '1 microchip or tattoo added',
    );
    return '$_temp0';
  }

  @override
  String get scanSavedPassport => 'passport details updated';

  @override
  String get scanSavedPhotosPassport => 'photos added to the passport pages';

  @override
  String get scanSavedPhotosDocument => 'photos saved as a document';

  @override
  String get scanSavedNothing => 'Nothing was saved';

  @override
  String get scanPassportFillIn => 'Add to the passport details';

  @override
  String get scanSavedBeforeDrop => 'saved before the connection dropped';

  @override
  String get scanSavedNoDiscard => 'this scan was saved already';

  @override
  String get scanSaveUnconfirmed =>
      'Couldn\'t tell whether it was saved. Check your connection and save again: nothing is saved twice.';

  @override
  String get scanDateTooEarly => 'Use a date in 1990 or later';

  @override
  String scanTooManyIdentifiers(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'A pet can have up to $max microchips and tattoos.',
      one: 'A pet can have 1 microchip or tattoo.',
    );
    return '$_temp0';
  }

  @override
  String scanSkippedIdentifiers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numbers were already on the pet',
      one: '1 number was already on the pet',
    );
    return '$_temp0';
  }

  @override
  String scanSavedPassportFields(String fields) {
    return 'passport details updated: $fields';
  }

  @override
  String get scanPassportFieldNumber => 'number';

  @override
  String get scanPassportFieldCountry => 'country';

  @override
  String get scanPassportFieldIssuedOn => 'date of issue';

  @override
  String get scanPassportReplace => 'Replace the saved value';

  @override
  String get scanPassportSame => 'Already in the passport details';

  @override
  String get scanPassportNothingNew =>
      'Nothing new: the passport details already say this.';

  @override
  String get scanDismiss => 'Dismiss';

  @override
  String get aiCheckFailed => 'Couldn\'t check';

  @override
  String get scanLeaveTitle => 'Leave without saving?';

  @override
  String get scanLeaveBody =>
      'Your changes here will be lost. The scan stays on the Passport tab to check later.';

  @override
  String get scanLeaveConfirm => 'Leave';

  @override
  String get scanTitleRabiesVaccination => 'Rabies vaccination';

  @override
  String get scanPassportTurnOnReplace =>
      'Turn on “Replace the saved value” for what should change.';

  @override
  String get petTabFeeding => 'Feeding';

  @override
  String get feedingTitle => 'Feeding schedule';

  @override
  String get feedingAdd => 'Add';

  @override
  String get feedingEmpty =>
      'Add feeding times: at each one a reminder comes, and Today shows a \"Fed\" button.';

  @override
  String get feedingEveryDay => 'Every day';

  @override
  String get feedingPaused => 'Paused';

  @override
  String get feedingAddTitle => 'New feeding schedule';

  @override
  String get feedingEditTitle => 'Edit feeding';

  @override
  String get feedingDelete => 'Delete schedule';

  @override
  String get feedingDeleteTitle => 'Delete this feeding schedule?';

  @override
  String get feedingDeleteBody =>
      'Its reminders stop, and its \"fed\" marks are deleted too.';

  @override
  String get feedingGone =>
      'This feeding schedule was deleted on another device.';

  @override
  String get feedingReadOnly =>
      'This schedule was made in a newer version of the app. Update the app to change it.';

  @override
  String get feedingTimesLabel => 'Times';

  @override
  String get feedingTimeAdd => 'Add time';

  @override
  String get feedingTimeRemove => 'Remove this time';

  @override
  String get feedingTimesRequired => 'Add at least one time';

  @override
  String feedingTimesTooMany(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Use $max times or fewer',
    );
    return '$_temp0';
  }

  @override
  String get feedingDaysLabel => 'Days';

  @override
  String get feedingDaysRequired => 'Choose at least one day';

  @override
  String get feedingFoodLabel => 'Food';

  @override
  String get feedingFoodHint => 'e.g. Royal Canin Sterilised';

  @override
  String get feedingPortionLabel => 'Portion';

  @override
  String get feedingAmountHint => '40';

  @override
  String get feedingAmountInvalid => 'Use a number above 0, up to 10 000';

  @override
  String get feedingActiveLabel => 'Active';

  @override
  String get feedingActiveHelper =>
      'Paused schedules don\'t remind and don\'t show on Today.';

  @override
  String get feedingRemindersNote =>
      'At each time a reminder comes to the phones of the household. Turn feeding reminders off in More → Notifications.';

  @override
  String portionGrams(String amount) {
    return '$amount g';
  }

  @override
  String portionMilliliters(String amount) {
    return '$amount ml';
  }

  @override
  String portionPieces(String amount) {
    return '$amount pcs';
  }

  @override
  String get portionUnitGrams => 'g';

  @override
  String get portionUnitMilliliters => 'ml';

  @override
  String get portionUnitPieces => 'pcs';

  @override
  String get todayFeedingTitle => 'Feeding';

  @override
  String get feedingFed => 'Fed';

  @override
  String get feedingAll => 'All fed';

  @override
  String feedingAlreadyMarked(String name, String time) {
    return 'Already marked: $name, $time';
  }

  @override
  String feedingFedBy(String name, String time) {
    return '$name, $time';
  }

  @override
  String get feedingSomeoneElse => 'someone else';

  @override
  String feedingSkippedAt(String time) {
    return 'Skipped, $time';
  }

  @override
  String feedingUndoTitle(String pet) {
    return '$pet: take the mark back?';
  }

  @override
  String get feedingUndoBody =>
      'The feeding will show as not done, and its reminder may come again.';

  @override
  String get feedingUndo => 'Take back';

  @override
  String get todayVisitsTitle => 'Visits';

  @override
  String get todayVisitsAll => 'All visits';

  @override
  String get todayVisitsEmpty => 'No visits planned.';

  @override
  String get todayVisitMarkHowItWent => 'Mark how it went';

  @override
  String get visitsTitle => 'Visits';

  @override
  String get visitsPlanned => 'Planned';

  @override
  String get visitsPast => 'Past and cancelled';

  @override
  String get visitsEmptyTitle => 'No visits yet';

  @override
  String get visitsEmptyBody =>
      'Add a visit to the vet or the groomer: reminders come a day and two hours before.';

  @override
  String get visitAdd => 'Add a visit';

  @override
  String get visitAddTitle => 'New visit';

  @override
  String get visitEditTitle => 'Edit visit';

  @override
  String get visitReadOnly =>
      'This visit was made in a newer version of the app. Update the app to change it.';

  @override
  String get visitGone => 'This visit was deleted on another device.';

  @override
  String get visitTypeLabel => 'Kind of visit';

  @override
  String get visitTypeVet => 'Vet';

  @override
  String get visitTypeGrooming => 'Groomer';

  @override
  String get visitTypeTraining => 'Training';

  @override
  String get visitTypeOther => 'Other';

  @override
  String get visitTitleLabel => 'What for';

  @override
  String get visitTitleHint => 'e.g. Rabies vaccination';

  @override
  String get visitDateLabel => 'Date';

  @override
  String get visitTimeLabel => 'Time';

  @override
  String get visitTimeRequired => 'Choose the time';

  @override
  String get visitPetsLabel => 'Pets';

  @override
  String get visitPetsRequired => 'Choose at least one pet';

  @override
  String get visitLocationLabel => 'Where';

  @override
  String get visitLocationHint => 'Clinic or address';

  @override
  String get visitRemindersLabel => 'Remind';

  @override
  String get visitRemindersNone => 'No reminders';

  @override
  String get visitRemindAtStart => 'When it starts';

  @override
  String get visitRemindWeek => 'A week before';

  @override
  String visitRemindWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks before',
      one: '1 week before',
    );
    return '$_temp0';
  }

  @override
  String get visitRemindDay => 'A day before';

  @override
  String visitRemindDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get visitRemindHour => 'An hour before';

  @override
  String visitRemindHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours before',
      one: '1 hour before',
    );
    return '$_temp0';
  }

  @override
  String visitRemindMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes before',
      one: 'A minute before',
    );
    return '$_temp0';
  }

  @override
  String visitToday(String time) {
    return 'Today at $time';
  }

  @override
  String visitTomorrow(String time) {
    return 'Tomorrow at $time';
  }

  @override
  String visitYesterday(String time) {
    return 'Yesterday at $time';
  }

  @override
  String visitOnDate(DateTime date, String time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMEd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString at $time';
  }

  @override
  String get visitStatusPlanned => 'Planned';

  @override
  String get visitStatusDone => 'Took place';

  @override
  String get visitStatusCancelled => 'Cancelled';

  @override
  String get visitCancel => 'Cancel visit';

  @override
  String get visitCancelTitle => 'Cancel this visit?';

  @override
  String get visitCancelBody =>
      'Its reminders stop. You can plan it again later.';

  @override
  String get visitCancelledNote => 'This visit is cancelled.';

  @override
  String get visitPlanAgain => 'Plan again';

  @override
  String get visitDelete => 'Delete';

  @override
  String get visitDeleteTitle => 'Delete this visit?';

  @override
  String get visitDeleteBody =>
      'Records made from it stay in the pets\' history.';

  @override
  String get visitDone => 'The visit took place';

  @override
  String get visitDoneTitle => 'How did the visit go?';

  @override
  String get visitDoneWriteRecord => 'Add to the care history';

  @override
  String get visitDoneWriteRecordHelper =>
      'Each pet of the visit gets a record of this kind.';

  @override
  String visitDonePlan(String plan) {
    return 'Mark \"$plan\" done';
  }

  @override
  String get visitDoneNotesLabel => 'Notes';

  @override
  String get visitDoneNotesHint => 'What the vet said';

  @override
  String get visitDoneSaved => 'Saved: the visit took place.';

  @override
  String visitDoneSavedPlans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved. $count plans moved to their next dates.',
      one: 'Saved. One plan moved to its next date.',
    );
    return '$_temp0';
  }

  @override
  String get visitResultTitle => 'Result';

  @override
  String get visitNoRecords => 'No records were made.';

  @override
  String get visitRecordsOfPet => 'Records in the care history';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get moreNotificationsHelper => 'Reminders, test, history';

  @override
  String get notificationsChannelGeneral => 'Other';

  @override
  String get notificationsKinds => 'Reminders';

  @override
  String get notificationsKindFeeding => 'Feeding';

  @override
  String get notificationsKindFeedingHelper => 'At each feeding time';

  @override
  String get notificationsKindCare => 'Vaccinations and treatments';

  @override
  String get notificationsKindCareHelper =>
      '7 days, 1 day and on the day, at 10:00; again while overdue';

  @override
  String get notificationsKindVisits => 'Visits';

  @override
  String get notificationsKindVisitsHelper => 'As set for each visit';

  @override
  String get notificationsReady => 'Reminders come to this phone.';

  @override
  String get notificationsIphoneLater =>
      'On iPhone, reminders will come later: they need a paid Apple developer account. Until then, everything due is on the Today screen.';

  @override
  String get notificationsDenied =>
      'Notifications are off for Collarbell in the phone\'s settings.';

  @override
  String get notificationsNotAsked =>
      'Notifications aren\'t allowed yet. Collarbell asks when you add the first feeding, visit or plan, or allow them now.';

  @override
  String get pushAskTitle => 'Allow notifications?';

  @override
  String get pushAskBody =>
      'Then Collarbell can remind you of feeding, vaccinations and visits, even when the app is closed.';

  @override
  String get pushAskLater => 'Not now';

  @override
  String get pushAskAllow => 'Allow notifications';

  @override
  String get pushOffNotice => 'Notifications are off: reminders won\'t come.';

  @override
  String get notificationsOpenSettings => 'Open settings';

  @override
  String get notificationsNoToken =>
      'The phone has no address for notifications yet: it needs Google Play services and the internet.';

  @override
  String get notificationsRegisterFailed =>
      'The server couldn\'t be reached to turn on reminders for this phone.';

  @override
  String get notificationsServerNotReady =>
      'The server can\'t send notifications yet: it has no Firebase key.';

  @override
  String get notificationsTest => 'Send a test notification';

  @override
  String get notificationsTestSent =>
      'Sent. It should arrive in a few seconds.';

  @override
  String get notificationsTestNoDevices =>
      'No phone is registered for notifications yet.';

  @override
  String get notificationsTestFailed =>
      'Firebase didn\'t deliver it. Try again later.';

  @override
  String get notificationsUpcoming => 'Coming reminders';

  @override
  String get notificationsUpcomingEmpty => 'Nothing in the next 7 days.';

  @override
  String get notificationsRecent => 'Recent reminders';

  @override
  String get notificationsRecentEmpty => 'Nothing in the last 7 days.';

  @override
  String notificationsWhenToday(String time) {
    return 'Today at $time';
  }

  @override
  String notificationsWhenTomorrow(String time) {
    return 'Tomorrow, $time';
  }

  @override
  String notificationsWhenYesterday(String time) {
    return 'Yesterday, $time';
  }

  @override
  String get reminderSent => 'sent';

  @override
  String get reminderExpired => 'too late: the server was off';

  @override
  String get reminderFailed => 'Firebase didn\'t deliver it';

  @override
  String get reminderSkipped => 'not sent';

  @override
  String get reminderSkippedNotNeeded => 'not needed: done already';

  @override
  String get reminderSkippedNoPhones => 'no phone to send to';

  @override
  String get reminderSkippedServer =>
      'not sent: the server has no Firebase key';

  @override
  String feedingFedAtSemantics(String time) {
    return 'Fed at $time';
  }

  @override
  String get feedingUndoHint => 'Tap to take the mark back';

  @override
  String feedingMarkedBy(String name) {
    return 'Marked by $name';
  }

  @override
  String feedingSkipTitle(String pet) {
    return '$pet: skip this feeding?';
  }

  @override
  String feedingSkipBody(String time) {
    return 'The $time feeding will be marked as skipped, with no reminder.';
  }

  @override
  String get feedingSkip => 'Skip';

  @override
  String get notificationsUnavailable =>
      'Notifications aren\'t available on this phone: Firebase didn\'t start.';

  @override
  String get visitDoneNotPossible =>
      'This visit can\'t be marked: it was cancelled, or it hasn\'t happened yet.';

  @override
  String get notificationsKindSupplies => 'Supplies';

  @override
  String get notificationsKindSuppliesHelper =>
      'When it\'s time to buy, at 10:00';

  @override
  String get barcodeCameraUnavailable =>
      'The camera isn\'t available. Allow camera access in Settings, or type the digits.';

  @override
  String get barcodeFind => 'Find';

  @override
  String get barcodeScanHint =>
      'Point the camera at the barcode on the package';

  @override
  String get barcodeScanTitle => 'Barcode';

  @override
  String get barcodeTorch => 'Torch';

  @override
  String get barcodeType => 'Type the digits';

  @override
  String get barcodeTypeHint => 'The digits under the barcode';

  @override
  String get feedingSupplyHelper =>
      'Portions of this feeding count towards the food\'s daily use in supplies';

  @override
  String get feedingSupplyLabel => 'Food from supplies';

  @override
  String get feedingSupplyNone => 'Not from supplies';

  @override
  String get productScanAddPhoto => 'Add a photo';

  @override
  String get productScanBusy =>
      'AI is busy right now. Try again in a minute, or fill it in by hand.';

  @override
  String get productScanByHand => 'Fill in by hand';

  @override
  String get productScanCameraFailed => 'Couldn\'t open the camera';

  @override
  String productScanCode(String code) {
    return 'Barcode $code';
  }

  @override
  String get productScanExisting => 'This product is in your supplies already';

  @override
  String get productScanFreeTier =>
      'The photos go to Gemini\'s free tier: keep personal data out of them.';

  @override
  String get productScanLookingUp => 'Looking the product up…';

  @override
  String get productScanNoAi =>
      'AI isn\'t set up: fill in the details by hand.';

  @override
  String get productScanNotProduct =>
      'That isn\'t a product barcode. Scan the barcode on the package.';

  @override
  String get productScanOpenExisting => 'Open the item';

  @override
  String get productScanPartly =>
      'Not everything was found: the package size is missing. Take photos of the package, or fill it in by hand.';

  @override
  String productScanPhoto(int number) {
    return 'Photo $number';
  }

  @override
  String get productScanPhotosHint =>
      'Take photos of the front and of the side with the weight and composition, up to 3.';

  @override
  String get productScanRead => 'Read';

  @override
  String get productScanReading =>
      'Reading the package… Usually a few seconds, sometimes a minute or two.';

  @override
  String get productScanRejected =>
      'AI refused to read the photos. Fill in the details by hand.';

  @override
  String get productScanTakePhotos => 'Take photos of the package';

  @override
  String get productScanTitle => 'New item';

  @override
  String get productScanUnknown => 'No product with this barcode was found.';

  @override
  String get suppliesInStock => 'In stock';

  @override
  String get suppliesNotBought => 'No longer bought';

  @override
  String get suppliesSoon => 'Running out soon';

  @override
  String get suppliesToBuy => 'To buy';

  @override
  String get supplyActiveHelper =>
      'Turn off when you no longer buy it: no reminders, the history stays';

  @override
  String get supplyActiveLabel => 'Still buying';

  @override
  String get supplyAdd => 'Add';

  @override
  String get supplyAddByBarcode => 'Scan the barcode';

  @override
  String get supplyAddByBarcodeHelper => 'We look the product up';

  @override
  String get supplyAddByHand => 'Fill in by hand';

  @override
  String get supplyAddByPhoto => 'Take photos of the package';

  @override
  String get supplyAddByPhotoHelper => 'AI reads the name, weight and energy';

  @override
  String get supplyAddTitle => 'New item';

  @override
  String get supplyBarcodeInvalid => 'Check the barcode\'s digits';

  @override
  String get supplyBarcodeLabel => 'Barcode';

  @override
  String get supplyBarcodeTaken =>
      'An item with this barcode is in supplies already';

  @override
  String get supplyBought => 'Bought';

  @override
  String get supplyBrandLabel => 'Brand';

  @override
  String supplyBuyBy(String date, String delivery) {
    return 'Buy by $date · delivery $delivery';
  }

  @override
  String get supplyTimeToBuy => 'Time to buy';

  @override
  String get supplyCategoryDryFood => 'Dry food';

  @override
  String get supplyCategoryLabel => 'Kind';

  @override
  String get supplyCategoryLitter => 'Litter';

  @override
  String get supplyCategoryMedication => 'Medicine';

  @override
  String get supplyCategoryOther => 'Other';

  @override
  String get supplyCategoryTreats => 'Treats';

  @override
  String get supplyCategoryWetFood => 'Wet food';

  @override
  String get supplyCount => 'Correct';

  @override
  String get supplyCountSave => 'Save';

  @override
  String get supplyCountSaved => 'Stock saved';

  @override
  String supplyCountTitle(String name) {
    return 'What\'s left: $name';
  }

  @override
  String supplyCountTotal(String amount) {
    return 'In all ≈ $amount';
  }

  @override
  String get supplyDelete => 'Delete item';

  @override
  String get supplyDeleteBody =>
      'Its purchases and stock are deleted. Feedings keep the food\'s name.';

  @override
  String supplyDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get supplyDetailsTitle => 'Details';

  @override
  String supplyDoses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses',
      one: '$count dose',
    );
    return '$_temp0';
  }

  @override
  String supplyDosesFraction(String amount) {
    return '$amount doses';
  }

  @override
  String get supplyEditTitle => 'Edit item';

  @override
  String supplyEnoughFor(String lasts) {
    return 'Enough for $lasts';
  }

  @override
  String get supplyEntryByMe => 'you';

  @override
  String supplyEntryCount(String amount) {
    return 'Left: $amount';
  }

  @override
  String supplyEntryPurchase(String amount) {
    return 'Bought +$amount';
  }

  @override
  String get supplyEntryUndo => 'Take back';

  @override
  String get supplyEntryUndoBody =>
      'The entry is deleted and the forecast recalculated.';

  @override
  String get supplyEntryUndoTitle => 'Take this entry back?';

  @override
  String get supplyFeedingNotCounted =>
      'No portion, or in another unit: not counted';

  @override
  String supplyFeedingPortion(String portion, String times) {
    return '$portion × $times a day';
  }

  @override
  String get supplyFeedingsTitle => 'Feedings with this food';

  @override
  String get supplyFromCatalog =>
      'This product was saved before. Check the details.';

  @override
  String get supplyFromOpenPetFoodFacts =>
      'Details from Open Pet Food Facts (ODbL licence). Check them.';

  @override
  String get supplyFromPhotos =>
      'Read from photos of the package. Check the details.';

  @override
  String get supplyFromUpcItemDb =>
      'The name comes from UPCitemdb. Add the package size.';

  @override
  String get supplyGone => 'This item is gone';

  @override
  String get supplyHistoryEmpty => 'No purchases or counts yet';

  @override
  String get supplyHistoryTitle => 'Purchases and counts';

  @override
  String get supplyInactive => 'No longer bought';

  @override
  String get supplyInactiveNote =>
      'You no longer buy this item: there are no reminders about it.';

  @override
  String supplyKcal(int kcal) {
    return '$kcal kcal/kg';
  }

  @override
  String get supplyKcalHelper =>
      'From the package: kcal per kg (kcal per 100 g × 10)';

  @override
  String get supplyKcalHint => '3900';

  @override
  String get supplyKcalInvalid => 'A number from 1 to 10,000';

  @override
  String get supplyKcalLabel => 'Energy, kcal/kg';

  @override
  String supplyKg(String amount) {
    return '$amount kg';
  }

  @override
  String supplyLastsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'about $count days',
      one: 'about $count day',
    );
    return '$_temp0';
  }

  @override
  String get supplyLastsLessThanDay => 'less than a day';

  @override
  String supplyLeadTimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String get supplyLeadTimeHelper =>
      'The reminder to buy comes this many days before it runs out';

  @override
  String supplyLeadTimeInvalid(int max) {
    return 'Use 0 to $max days';
  }

  @override
  String get supplyLeadTimeLabel => 'Days for delivery';

  @override
  String supplyLeftNoUsage(String amount) {
    return '$amount left · daily use not set';
  }

  @override
  String get supplyLess => 'Fewer';

  @override
  String supplyLiters(String amount) {
    return '$amount l';
  }

  @override
  String get supplyMore => 'More';

  @override
  String get supplyNameHint => 'e.g. Royal Canin Sterilised 37';

  @override
  String get supplyNameLabel => 'Name';

  @override
  String get supplyNameRequired => 'Enter a name';

  @override
  String get supplyNoFeedings =>
      'No feeding uses this food yet. Open a pet\'s feeding and pick it under “Food from supplies”.';

  @override
  String get supplyNoStock => 'Stock not entered';

  @override
  String get supplyNoStockHint =>
      'Mark a purchase or correct the stock, and the forecast appears.';

  @override
  String get supplyNoUsage => 'Daily use not set';

  @override
  String get supplyNoUsageFeedingHint =>
      'Pick this food in the pets\' feedings: the use is counted from the portions.';

  @override
  String get supplyNoUsageManualHint =>
      'Set how many days a package lasts in the item\'s settings.';

  @override
  String get supplyNotPetProduct =>
      'The photos don\'t seem to show a pet product. Check the details.';

  @override
  String get supplyNothingLeft => 'None left';

  @override
  String supplyOpenPackage(int percent) {
    return 'Open package: about $percent%';
  }

  @override
  String get supplyOpenStore => 'Open the shop';

  @override
  String get supplyOutOfStock => 'Ran out';

  @override
  String get supplyPackageLabel => 'Package';

  @override
  String supplyPackages(String packages) {
    return '≈ $packages pkg';
  }

  @override
  String supplyPackagesBought(String package) {
    return 'Packages of $package';
  }

  @override
  String supplyPackagesClosed(String package) {
    return 'Unopened packages of $package';
  }

  @override
  String get supplyPlanAdd => 'Add a plan';

  @override
  String get supplyPlanNo => 'No, thanks';

  @override
  String get supplyPlanOfferBody =>
      'Add a treatment plan with this interval? A reminder comes when it\'s due.';

  @override
  String supplyPlanOfferTitle(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'Protects for $weeks weeks',
      one: 'Protects for $weeks week',
    );
    return '$_temp0';
  }

  @override
  String get supplyPlanWhichPet => 'Which pet is it for?';

  @override
  String get supplyPurchaseSave => 'Save the purchase';

  @override
  String get supplyPurchaseSaved => 'Purchase saved';

  @override
  String supplyPurchaseTitle(String name) {
    return 'Bought: $name';
  }

  @override
  String supplyRanOutOn(String date) {
    return 'Ran out around $date';
  }

  @override
  String get supplyReadOnly =>
      'This item was changed by a newer version of the app. Update the app to edit it.';

  @override
  String supplyRemaining(String amount, String packages) {
    return 'Left: ≈ $amount ($packages)';
  }

  @override
  String supplyRunsOutOn(String date) {
    return 'Runs out around $date';
  }

  @override
  String get supplySizeHint => '2';

  @override
  String get supplySizeInvalid => 'A number above 0';

  @override
  String supplySoonLeft(String date, String lasts) {
    return 'Buy by $date · enough for $lasts';
  }

  @override
  String get supplyStockNowHelper =>
      'Usually the one unopened package you just bought';

  @override
  String get supplyStockNowLabel => 'Say how much there is now';

  @override
  String get supplyStoreFailed => 'Couldn\'t open the link';

  @override
  String get supplyStoreHelper =>
      'A link to the product in a shop, to order it quickly';

  @override
  String get supplyStoreLabel => 'Where to buy';

  @override
  String get supplyUnitDoses => 'doses';

  @override
  String get supplyUnitKg => 'kg';

  @override
  String get supplyUnitLiters => 'l';

  @override
  String get supplyUrlInvalid => 'Use a link starting with https:// or http://';

  @override
  String get supplyUsageByHand => 'By hand';

  @override
  String get supplyUsageDaysSuffix => 'days';

  @override
  String get supplyUsageFeeding => 'From feedings';

  @override
  String get supplyUsageFeedingHelper =>
      'The use is counted from the portions of the feedings that give this food.';

  @override
  String supplyUsageFromFeeding(String amount) {
    return 'Uses $amount a day, from the feedings';
  }

  @override
  String get supplyUsageInvalid => 'A number above 0';

  @override
  String get supplyUsageLabel => 'Daily use';

  @override
  String supplyUsageManual(String amount) {
    return 'Uses $amount a day, set by hand';
  }

  @override
  String get supplyUsagePackageLasts => 'A package lasts';

  @override
  String supplyUsagePackageLastsHelper(String package) {
    return 'How many days one package ($package) lasts';
  }

  @override
  String get supplyUsagePerDay => 'Per day';

  @override
  String get supplyUsagePerDayHelper => 'How much is used a day';

  @override
  String get todayShoppingAll => 'All supplies';

  @override
  String get todayShoppingTitle => 'To buy';

  @override
  String get productScanFromLibrary => 'From the gallery';

  @override
  String supplyBatch(String batch) {
    return 'Batch $batch';
  }

  @override
  String supplyExpires(String date) {
    return 'expires $date';
  }

  @override
  String get productScanExistingInactive =>
      'You marked it as no longer bought: a purchase brings it back to supplies.';

  @override
  String get moreHousehold => 'Group';

  @override
  String get householdDefaultName => 'My home';

  @override
  String get householdRoleOwner => 'Owner';

  @override
  String get householdRoleMember => 'Member';

  @override
  String get householdRoleHelper => 'Helper';

  @override
  String get householdRoleOwnerHelper =>
      'Everything, and the people and settings of the group.';

  @override
  String get householdRoleMemberHelper =>
      'Everything with the pets and records, but not the people.';

  @override
  String get householdRoleHelperHelper =>
      'Sees everything and marks feedings, “Done”, visits and purchases.';

  @override
  String householdMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get householdSwitch => 'Switch group';

  @override
  String get householdPeople => 'Members and invites';

  @override
  String get householdSwitchTitle => 'Your groups';

  @override
  String get householdCurrent => 'Current group';

  @override
  String get householdCreate => 'Create a group';

  @override
  String get householdJoin => 'Join with a code';

  @override
  String get householdCreateTitle => 'New group';

  @override
  String get householdNameLabel => 'Name';

  @override
  String get householdNameHint => 'e.g. Office';

  @override
  String get householdNameRequired => 'Give the group a name.';

  @override
  String get householdCreateAction => 'Create';

  @override
  String householdSwitched(String name) {
    return 'You\'re in “$name” now.';
  }

  @override
  String householdLeftNotice(String name) {
    return 'You\'re no longer in “$name”.';
  }

  @override
  String get householdLeftNoticeUnnamed => 'You\'re no longer in that group.';

  @override
  String get householdMembers => 'Members';

  @override
  String get householdYou => 'you';

  @override
  String get householdNoName => 'No name';

  @override
  String get householdInvite => 'Invite';

  @override
  String get householdInvites => 'Open invites';

  @override
  String householdInviteUntil(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'until $dateString';
  }

  @override
  String get householdInviteRevoke => 'Revoke';

  @override
  String get householdInviteRevoked => 'The invite was revoked.';

  @override
  String get householdLeave => 'Leave group';

  @override
  String householdLeaveTitle(String name) {
    return 'Leave “$name”?';
  }

  @override
  String get householdLeaveBody =>
      'The pets and records stay in the group. To come back, you\'ll need a new invite.';

  @override
  String get householdLeaveConfirm => 'Leave';

  @override
  String householdLeftSelf(String name) {
    return 'You left “$name”.';
  }

  @override
  String get householdLastOwner => 'Make someone else an owner first.';

  @override
  String get householdRename => 'Rename';

  @override
  String get householdRenameTitle => 'Group name';

  @override
  String get householdDelete => 'Delete group';

  @override
  String householdDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get householdDeleteBody =>
      'Nobody else is in it, and it has no pets or supplies. You can\'t undo this.';

  @override
  String householdDeleted(String name) {
    return 'The group “$name” was deleted.';
  }

  @override
  String get householdNotEmpty =>
      'Only an empty group can be deleted, and this one has pets or supplies.';

  @override
  String get householdMemberRemove => 'Remove from group';

  @override
  String get householdMemberRemoveTitle => 'Remove from the group?';

  @override
  String householdMemberRemoveBody(String name) {
    return '$name will no longer see the pets of this group. Their marks stay.';
  }

  @override
  String get householdMemberRemoveConfirm => 'Remove';

  @override
  String get householdInviteTitle => 'Who are you inviting?';

  @override
  String get householdInviteCodeTitle => 'Invite code';

  @override
  String householdInviteCodeBody(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'The code works once, for $_temp0.';
  }

  @override
  String get householdShare => 'Share';

  @override
  String get householdCopy => 'Copy';

  @override
  String get householdCopied => 'The code was copied.';

  @override
  String householdShareText(String name, String code, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Join “$name” in Collarbell: code $code, valid for $_temp0.';
  }

  @override
  String get householdInviteLimit =>
      'There are 20 open invites already: revoke the ones you don\'t need.';

  @override
  String get householdLimit => 'You can be in up to 20 groups.';

  @override
  String get joinTitle => 'Join a group';

  @override
  String get joinCodeLabel => 'Invite code';

  @override
  String get joinCodeHelper => '8 letters and digits, like ABCD-2345';

  @override
  String joinPreview(String inviter, String name, String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'helper': 'a helper',
      'other': 'a member',
    });
    return '$inviter invites you to “$name” as $_temp0.';
  }

  @override
  String joinPreviewNoName(String name, String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'helper': 'a helper',
      'other': 'a member',
    });
    return 'You\'re invited to “$name” as $_temp0.';
  }

  @override
  String joinValidUntil(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'The code works until $dateString.';
  }

  @override
  String get joinAction => 'Join';

  @override
  String get joinNotFound =>
      'This code doesn\'t work: check it or ask for a new one.';

  @override
  String get joinAlreadyMember => 'You\'re already in this group.';

  @override
  String get joinTooManyAttempts =>
      'Too many tries. Try again in a few minutes.';

  @override
  String joinJoined(String name) {
    return 'You joined “$name”.';
  }

  @override
  String get errorNotInHousehold => 'You\'re no longer in this group.';

  @override
  String get petsEmptyBodyHelper =>
      'The group\'s cats and dogs will show here.';

  @override
  String get todayStartBodyHelper =>
      'When the group has pets, their feeding, care and shopping show up here.';

  @override
  String get feedingEmptyHelper => 'No feeding times yet.';

  @override
  String get healthPlansEmptyHelper => 'No plans yet.';

  @override
  String get healthHistoryEmptyHelper => 'No records yet.';

  @override
  String get passportEmptyHelper => 'No passport details yet.';

  @override
  String get passportPagesEmptyHelper => 'No passport pages yet.';

  @override
  String get visitsEmptyBodyHelper =>
      'Visits to the vet or the groomer will show here.';

  @override
  String get suppliesEmptyBodyHelper =>
      'The group\'s food, litter and medicine will show here.';

  @override
  String get supplyNoFeedingsHelper => 'No feeding uses this food yet.';

  @override
  String get householdDefaultNameOther => 'Home';

  @override
  String get householdStepDownTitle => 'Stop being an owner?';

  @override
  String get householdStepDownBody =>
      'You won\'t be able to invite people or change roles, and your open invites will stop working.';

  @override
  String get householdStepDownConfirm => 'Change my role';

  @override
  String get householdSwitchedUnnamed => 'You\'re in another group now.';

  @override
  String get joinCodeBadCharacters =>
      'Codes have no letters O and I and no digits 0 and 1: check the code.';

  @override
  String get notificationsChannelFeedingUpdates => 'Who fed';

  @override
  String get householdPlanTitle => 'Plan';

  @override
  String get householdPlanFree => 'Free';

  @override
  String get householdPlanPremium => 'Premium';

  @override
  String householdPlanOf(String name) {
    return 'The plan of “$name”';
  }

  @override
  String householdPlanUntil(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Until $dateString';
  }

  @override
  String get householdPlanNoEnd => 'No end date';

  @override
  String get householdPlanAiPhotos => 'AI photos this month';

  @override
  String householdPlanAiPhotosUsed(int used, int limit) {
    return '$used of $limit';
  }

  @override
  String get householdPlanAiPhotosUsedUp =>
      'This month\'s AI photos are used up. Typing things in and scanning barcodes work as before.';

  @override
  String householdPlanResetsOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'The count starts again on $dateString.';
  }

  @override
  String get householdPlanAiPhotosHelp =>
      'Every photo AI reads counts: a passport page, a chip sticker, a package.';

  @override
  String get householdPlanPremiumTitle => 'What Premium gives';

  @override
  String householdPlanPremiumAiPhotos(int count) {
    return 'Up to $count AI photos a month';
  }

  @override
  String get householdPlanPaymentsNote =>
      'There are no payments in the app yet: for now, Premium is given by hand.';

  @override
  String get householdPlanOpen => 'See the plan';

  @override
  String householdPlanAiPhotosLine(int used, int limit) {
    return 'AI photos this month: $used of $limit';
  }

  @override
  String errorAiLimitUsedUp(int used, int limit, String plan, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'AI has read $used of $limit photos this month: that\'s the limit of the $plan plan. The count starts again on $dateString.';
  }

  @override
  String errorAiLimitNotEnough(int left, int limit) {
    return '$left of $limit photos are left this month: choose fewer.';
  }

  @override
  String get errorAiLimit => 'This month\'s AI limit is used up.';

  @override
  String get errorTooManyRequests =>
      'Too many requests in a row. Try again in a minute.';

  @override
  String errorTooManyRequestsIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Too many requests in a row. Try again in $_temp0.';
  }

  @override
  String errorAiLimitPersonUsedUp(
    int used,
    int limit,
    String plan,
    DateTime date,
  ) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'You\'ve sent AI $used of $limit photos this month in all your groups on $plan. The count starts again on $dateString.';
  }

  @override
  String errorAiLimitPersonNotEnough(int left, int limit, String plan) {
    return 'You have $left of $limit photos left this month in all your groups on $plan: choose fewer.';
  }

  @override
  String get commonClose => 'Close';

  @override
  String get moreYourData => 'Your data';

  @override
  String get dataExportTitle => 'Download my data';

  @override
  String get dataExportHelper =>
      'A ZIP file with your account, groups, photos and scans';

  @override
  String get dataExportPreparing => 'Preparing the file…';

  @override
  String dataExportProgress(String size) {
    return 'Downloaded: $size';
  }

  @override
  String dataExportReady(String size) {
    return 'Ready: $size';
  }

  @override
  String fileSizeKb(int kb) {
    return '$kb KB';
  }

  @override
  String fileSizeMb(double mb) {
    final intl.NumberFormat mbNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String mbString = mbNumberFormat.format(mb);

    return '$mbString MB';
  }

  @override
  String get dataExportShareFailed =>
      'Couldn\'t share the file. Check that the phone has free space and try again.';

  @override
  String get dataExportKeepSafe =>
      'It has your pets\' documents: keep it somewhere safe.';

  @override
  String get dataExportShare => 'Share';

  @override
  String get dataExportSaved => 'Saved.';

  @override
  String get dataExportSaveFailed => 'Couldn\'t save the file. Try “Share”.';

  @override
  String get dataExportTooLarge =>
      'The file is large: save it with “Share”, e.g. to Files or Drive.';

  @override
  String get dataExportTooOften =>
      'You\'ve downloaded your data several times this hour. Try again later.';

  @override
  String dataExportTooOftenIn(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'You\'ve downloaded your data several times this hour. Try again in $_temp0.';
  }

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountHelper =>
      'You\'ll see first what happens to each group';

  @override
  String get deleteAccountWarning =>
      'Your account will be deleted for good. This can\'t be undone.';

  @override
  String get deleteAccountGroups => 'What happens to your groups';

  @override
  String deleteAccountFateDeleted(int pets) {
    String _temp0 = intl.Intl.pluralLogic(
      pets,
      locale: localeName,
      other:
          'Will be deleted with its $pets pets and all their records, photos and documents.',
      one:
          'Will be deleted with its pet and all its records, photos and documents.',
      zero: 'Will be deleted with everything in it.',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountFateDeletedHelpers =>
      'Only helpers would be left in it, and they lose access.';

  @override
  String get deleteAccountFateKept => 'Stays with the others as it is.';

  @override
  String deleteAccountFateHandedOver(String name) {
    return 'Stays with the others; $name becomes its owner.';
  }

  @override
  String get deleteAccountFateHandedOverUnnamed =>
      'Stays with the others; the member who joined first becomes its owner.';

  @override
  String get deleteAccountGoes => 'What gets deleted';

  @override
  String get deleteAccountGoesAccount =>
      'Your account: e-mail, name, settings, the phones that get reminders, and the record of what your apps did in the last 7 days.';

  @override
  String get deleteAccountGoesGroups =>
      'Groups where you\'re alone, or where only helpers would be left, with their pets, records, photos and documents.';

  @override
  String get deleteAccountGoesSignIn =>
      'Your sign-in: the e-mail and password.';

  @override
  String get deleteAccountStays => 'What stays';

  @override
  String get deleteAccountStaysRecords =>
      'In shared groups your records and feeding marks stay without your name, and what is written in them (e.g. the owner\'s details in a pet passport) stays as it is.';

  @override
  String get deleteAccountStaysBackups =>
      'Backups keep the data for up to 14 days, then it\'s gone from them too.';

  @override
  String get deleteAccountStaysAiPhotos =>
      'Photos already sent to the AI (Gemini) to be read were handled under Google\'s terms: deleting the account can\'t recall them.';

  @override
  String get deleteAccountExportFirst => 'Download my data first';

  @override
  String get deleteAccountPasswordHelper =>
      'Type your password to confirm it\'s you.';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account?';

  @override
  String deleteAccountConfirmBody(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names will be deleted with everything in them. This can\'t be undone.',
      one:
          '$names will be deleted with everything in it. This can\'t be undone.',
      zero: 'This can\'t be undone.',
    );
    return '$_temp0';
  }

  @override
  String quotedName(String name) {
    return '“$name”';
  }

  @override
  String namesAnd(String names, String last) {
    return '$names and $last';
  }

  @override
  String get deleteAccountWrongPassword => 'Wrong password. Try again.';

  @override
  String get deleteAccountPasswordAgain =>
      'For your safety, type your password again.';

  @override
  String get deleteAccountPasswordCheckFailed =>
      'Couldn\'t check your password. Try again.';

  @override
  String get deleteAccountSignOutFailed =>
      'Your account is deleted, but this phone couldn\'t sign out of it. The app will sign out the next time it starts.';

  @override
  String get deleteAccountPlanChanged =>
      'Something changed in your groups. Check again what happens to them, then delete.';

  @override
  String get accountDeletedNotice => 'Your account has been deleted.';

  @override
  String get petTabWeight => 'Weight';

  @override
  String get weightLabel => 'Weight';

  @override
  String weightOnDate(String weight, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$weight on $dateString';
  }

  @override
  String get weightLatestTitle => 'Latest weighing';

  @override
  String get weightTrendTitle => 'Trend';

  @override
  String get weightHistoryTitle => 'History';

  @override
  String get weightAdd => 'Add';

  @override
  String get weightAddFirst => 'Add weight';

  @override
  String get weightEmptyTitle => 'No weighings yet';

  @override
  String get weightEmptyBody =>
      'Weigh your pet once a month, kittens and puppies every 1–2 weeks: the log shows early when a pet starts losing or gaining weight.';

  @override
  String get weightEmptyBodyHelper => 'The pet\'s weighings will show here.';

  @override
  String get weightSourceWeighing => 'Weighing';

  @override
  String get weightSourceVet => 'Vet check-up';

  @override
  String weightChangeSince(String change, String date) {
    return '$change since $date';
  }

  @override
  String weightNoChangeSince(String date) {
    return 'No change since $date';
  }

  @override
  String get weightNoChange => 'no change';

  @override
  String weightBodyCondition(int score, int scale) {
    return 'BCS $score/$scale';
  }

  @override
  String weightBcsIdeal(String range) {
    return 'ideal $range';
  }

  @override
  String get weightPeriodThreeMonths => '3 months';

  @override
  String get weightPeriodYear => '1 year';

  @override
  String get weightPeriodAll => 'All time';

  @override
  String get weightChartNeedsTwo =>
      'The chart shows after the second weighing.';

  @override
  String get weightChartTooFew => 'Fewer than two weighings in this period.';

  @override
  String weightChartSummary(
    String from,
    String to,
    String first,
    String last,
    String lowest,
    String highest,
  ) {
    return 'Weight chart from $from to $to: $first at the start, $last at the end, lowest $lowest, highest $highest.';
  }

  @override
  String get weightUnitKg => 'kg';

  @override
  String get weightAddTitle => 'New weighing';

  @override
  String get weightEditTitle => 'Edit weighing';

  @override
  String get weightMeasuredOnLabel => 'Date';

  @override
  String get weightHint => 'e.g. 4.2';

  @override
  String get weightRequired => 'Enter the weight';

  @override
  String weightTooPrecise(int decimals) {
    String _temp0 = intl.Intl.pluralLogic(
      decimals,
      locale: localeName,
      other: 'Use $decimals decimals at most',
      one: 'Use 1 decimal at most',
    );
    return '$_temp0';
  }

  @override
  String get weightDateBeforeBirth => 'Can\'t be before the pet was born';

  @override
  String get weightBcsLabel => 'Body condition score';

  @override
  String get weightBcsAdd => 'Add body condition score';

  @override
  String get weightBcsRemove => 'Remove the score';

  @override
  String weightBcsScale(int max) {
    return 'Scale 1–$max';
  }

  @override
  String weightBcsHelp(String ideal, int max) {
    return 'Ideal is $ideal of $max: the ribs are easy to feel, and the waist shows from above.';
  }

  @override
  String get weightNoteLabel => 'Note';

  @override
  String get weightNoteHint => 'e.g. before breakfast';

  @override
  String get weightDelete => 'Delete weighing';

  @override
  String get weightDeleteTitle => 'Delete this weighing?';

  @override
  String get weightDeleteBody =>
      'It disappears from the history and the chart. You can\'t undo this.';

  @override
  String get weightGone =>
      'This weighing has been deleted, probably on another device.';

  @override
  String get weightReadOnly =>
      'This weighing was made in a newer version of the app. Update the app to change it.';

  @override
  String get noteTitle => 'Write it in words';

  @override
  String get noteIntro =>
      'Write what was done and when, in your own words: vaccinations, treatments, a visit to the vet, the weight. AI turns it into entries for you to check.';

  @override
  String get noteLabel => 'Note';

  @override
  String get noteHint =>
      'e.g. Yesterday the rabies shot, Nobivac; weighs 4.2 kg';

  @override
  String get noteDictate => 'To dictate, tap the microphone on the keyboard.';

  @override
  String get noteRead => 'Read';

  @override
  String get noteRequired => 'Write what was done, in words.';

  @override
  String get noteStarting => 'Sending the note to AI…';

  @override
  String noteLimitReached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'AI has already read $count notes in the last 24 hours. Try again tomorrow or add the record by hand.',
      one:
          'AI has already read 1 note in the last 24 hours. Try again tomorrow or add the record by hand.',
    );
    return '$_temp0';
  }

  @override
  String get noteErrorNotConfigured =>
      'AI isn\'t set up on the server. Connect a model in the server configuration, then try again. Records can always be added by hand.';

  @override
  String get noteErrorUnexpected =>
      'Something went wrong while reading the note. Try again.';

  @override
  String get noteStatusProcessing => 'Reading the note…';

  @override
  String get noteReadingBody => 'Usually 5–30 seconds.';

  @override
  String get noteReadingLeave =>
      'You can leave this screen: the note is read on the server and waits for you on the Health tab.';

  @override
  String get noteGone => 'This note no longer exists.';

  @override
  String get noteDiscardedBody => 'Nothing from this note was saved.';

  @override
  String noteResumeReady(String date) {
    return 'Continue checking the note from $date';
  }

  @override
  String noteResumeOpen(String date) {
    return 'Note from $date';
  }

  @override
  String get noteReviewTitle => 'Check the note';

  @override
  String get noteReviewIntro =>
      'AI read these entries from your note. Check them against what you wrote, fix what\'s wrong, and untick what you don\'t want to save.';

  @override
  String get noteNothingFound =>
      'AI found nothing to save in this note. Discard it, or write it again in other words.';

  @override
  String get noteFreeTierWarning =>
      'Free Gemini tier: Google may use what is sent to improve its products, and human reviewers may read it. Don\'t write personal details such as phone numbers or addresses.';

  @override
  String noteWrittenAt(String when) {
    return 'Written $when';
  }

  @override
  String get noteSectionTitle => 'Your note';

  @override
  String get noteEvidence => 'From your note';

  @override
  String get noteDiscard => 'Discard note';

  @override
  String get noteDiscardTitle => 'Discard this note?';

  @override
  String get noteDiscardBody =>
      'Nothing from it is saved, and its text is deleted.';

  @override
  String get noteDiscarded => 'Note discarded';

  @override
  String get noteLeaveBody =>
      'Your changes here will be lost. The note stays on the Health tab to check later.';

  @override
  String get noteSavedNoDiscard => 'this note was saved already';

  @override
  String get noteIssueUnreadable => 'The note doesn\'t say. Enter it.';

  @override
  String get noteIssueAmbiguous =>
      'Day and month could be swapped. Check what you meant.';

  @override
  String get noteIssueInvalidFormat => 'This doesn\'t look right. Check it.';

  @override
  String get noteIssueRepeated => 'The same entry is in the note twice.';

  @override
  String get scanWeightsTitle => 'Weighings';

  @override
  String get scanWeightAlreadySaved =>
      'This weight is already on the Weight tab.';

  @override
  String get scanWeightRepeated => 'An entry above has the same weight.';

  @override
  String get scanNeedsWeight => 'Enter the weight to save this entry.';

  @override
  String scanSavedWeights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weighings added',
      one: '1 weighing added',
    );
    return '$_temp0';
  }

  @override
  String get navHome => 'Home';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeGreetingNight => 'Good evening';

  @override
  String get homePetsLabel => 'Pets';

  @override
  String get homeAddPetTitle => 'Add a pet';

  @override
  String get homeAddPetHint => 'A cat or a dog: everything else starts with it';

  @override
  String get homeTourTitle => 'Take the tour';

  @override
  String get homeTourHint => 'What the app does, in a minute';

  @override
  String get homeNowTitle => 'Right now';

  @override
  String homeOverdue(int count) {
    return 'Overdue: $count';
  }

  @override
  String homeDueSoon(int count) {
    return 'Due soon: $count';
  }

  @override
  String get homeCareHint => 'Vaccinations and treatments';

  @override
  String homeToBuy(int count) {
    return 'To buy: $count';
  }

  @override
  String get homeToBuyHint => 'Food, litter, medicine';

  @override
  String get homeAllDoneTitle => 'All done for today';

  @override
  String get homeAllDoneBody => 'New things show up here when they are due.';

  @override
  String homeNextFeeding(String time) {
    return 'Feeding at $time';
  }

  @override
  String get homeQuickTitle => 'Quick actions';

  @override
  String get homeQuickCare => 'Vaccination or treatment';

  @override
  String get homeQuickCareHint => 'Record what was done';

  @override
  String get homeQuickScan => 'Scan the passport';

  @override
  String get homeQuickScanHint => 'AI copies the records';

  @override
  String get homeQuickNote => 'Write it in words';

  @override
  String get homeQuickNoteHint => 'AI reads the note';

  @override
  String get homeQuickWeigh => 'Weigh';

  @override
  String get homeQuickWeighHint => 'Keep an eye on weight';

  @override
  String get homeQuickPurchase => 'Scan a purchase';

  @override
  String get homeQuickPurchaseHint => 'Food, medicine';

  @override
  String get homePickPet => 'Which pet?';

  @override
  String get visitAddCard => 'Add a visit';

  @override
  String get visitAddCardHint => 'Vet, grooming';

  @override
  String get todayAddFeedingHint => 'We\'ll remind you when to feed';

  @override
  String get todayAddCareHint => 'We\'ll tell you when they\'re due';

  @override
  String get welcomeMoreTitle => 'Getting to know the app';

  @override
  String get welcomeMoreHint => 'What the app does and the first steps';

  @override
  String get welcomeIntro1Title => 'Reminders on time';

  @override
  String get welcomeIntro1Body =>
      'Feeding, vaccinations, treatments and vet visits: the notification comes at the right minute.';

  @override
  String get welcomeIntro2Title => 'The passport in a minute';

  @override
  String get welcomeIntro2Body =>
      'Take photos of the vet passport\'s pages: AI copies the vaccinations and due dates, and you check them before saving.';

  @override
  String get welcomeIntro3Title => 'Together with the family';

  @override
  String get welcomeIntro3Body =>
      'Everyone sees who has already fed the pet, and supplies tell you when it\'s time to buy food.';

  @override
  String get welcomeNext => 'Next';

  @override
  String get welcomeStart => 'Start';

  @override
  String get welcomeSkip => 'Skip';

  @override
  String get welcomeDone => 'Done';

  @override
  String get welcomeSaveNext => 'Save and continue';

  @override
  String welcomeStep(int step, int count) {
    return 'Step $step of $count';
  }

  @override
  String welcomePage(int page, int count) {
    return 'Page $page of $count';
  }

  @override
  String get welcomeClose => 'Close';

  @override
  String get welcomeBack => 'Back';

  @override
  String get welcomePetTitle => 'Who lives with you?';

  @override
  String get welcomePetBody =>
      'Start with a pet: feeding, care and supplies are set up for it. The rest of the details can wait.';

  @override
  String welcomePetHere(String names) {
    return 'Already here: $names';
  }

  @override
  String get welcomePetAddMore => 'Add another';

  @override
  String get welcomeInvitedTitle => 'I was invited to a family';

  @override
  String get welcomeInvitedHint => 'Enter the invite code';

  @override
  String get welcomeFeedingTitle => 'Feeding times';

  @override
  String get welcomeFeedingBody =>
      'Everyone gets a reminder at these times, every day. Tap a time to change it.';

  @override
  String get welcomeFeedingSet => 'Feeding is already set up';

  @override
  String get welcomeFeedingNoPet =>
      'Feeding is set up for a pet. Add one first, or come back here later from More.';

  @override
  String get welcomePushTitle => 'Notifications';

  @override
  String get welcomePushBody =>
      'Reminders come as notifications: feeding, vaccinations, visits and what to buy. Without them the app shows what is due only when you open it.';

  @override
  String get welcomePushAllow => 'Turn on notifications';

  @override
  String get welcomePushOn => 'Notifications are on';

  @override
  String get welcomeFamilyTitle => 'Invite your family';

  @override
  String get welcomeFamilyBody =>
      'Send a code to the people who look after the pets with you: they will see the feedings, care and supplies.';

  @override
  String get welcomeFamilyInvited =>
      'Invite created. The code works for 7 days.';

  @override
  String get welcomeFamilyInviteMore => 'Invite someone else';

  @override
  String get moreHelp => 'Help';

  @override
  String get supplyAddByHandHelper => 'Name and package size';

  @override
  String get healthHistoryAddHint => 'By hand, one at a time';
}
