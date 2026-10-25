import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// Product name. Not translated.
  ///
  /// In en, this message translates to:
  /// **'Collarbell'**
  String get appTitle;

  /// Bottom navigation: today's full to-do list (feedings, visits, care, shopping).
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// Bottom navigation: list of pets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get navPets;

  /// Bottom navigation: food and litter stock.
  ///
  /// In en, this message translates to:
  /// **'Supplies'**
  String get navSupplies;

  /// Bottom navigation: account and settings.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// Button that repeats a failed request.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Screen reader label for a loading indicator.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// Request failed: no connection or timeout.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection and try again.'**
  String get errorNetwork;

  /// Asked when Back would throw away what was typed on a form.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get leaveTitle;

  /// Body of the leave-without-saving question.
  ///
  /// In en, this message translates to:
  /// **'What you entered on this screen will be lost.'**
  String get leaveBody;

  /// Leaves the form without saving.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveConfirm;

  /// A change made while the screens showed offline copies wasn't sent: the server turned out to be back, and the screens reloaded.
  ///
  /// In en, this message translates to:
  /// **'The server is back and the data was reloaded. Check it and try again.'**
  String get errorRefreshed;

  /// The Firebase sign-in token needed renewing and there is no internet.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t renew the sign-in: no internet. Check the connection.'**
  String get errorSignInRenewal;

  /// Save on an edit form that was opened from an offline copy.
  ///
  /// In en, this message translates to:
  /// **'This form opened without a connection, from the copy on the phone: its data may be old, so it can\'t be saved. Open it again once the server is back.'**
  String get formOpenedOffline;

  /// Banner above the bottom navigation while the server can't be reached and nothing on screen comes from the saved copy.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server'**
  String get offlineBanner;

  /// Banner above the bottom navigation while the server can't be reached: the screens show the copy saved on the phone at {time} (e.g. 14:05, or Oct 1, 14:05).
  ///
  /// In en, this message translates to:
  /// **'No connection to the server · data from {time}'**
  String offlineBannerSince(String time);

  /// Request failed with 401.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Sign in again.'**
  String get errorUnauthorized;

  /// Request failed with 403: the user's role in the group can't do this.
  ///
  /// In en, this message translates to:
  /// **'Your role in the group doesn\'t allow this.'**
  String get errorForbidden;

  /// Request failed with a 5xx status.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Try again in a moment.'**
  String get errorServer;

  /// Any other failed request.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorUnknown;

  /// Trace ID from the server, shown under an error so support can find the request.
  ///
  /// In en, this message translates to:
  /// **'Error ID: {traceId}'**
  String errorReference(String traceId);

  /// Short product description on the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Feeding, vaccinations and supplies for your pets in one place.'**
  String get signInTagline;

  /// Sign-in form heading.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Registration form heading.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get signUpTitle;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Email field placeholder.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get emailHint;

  /// Password field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Tooltip of the eye button in the password field.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Tooltip of the eye button in the password field.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Validation: the email field is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailRequired;

  /// Validation: the email has a wrong format.
  ///
  /// In en, this message translates to:
  /// **'Enter an email like name@example.com'**
  String get emailInvalid;

  /// Validation: the password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordRequired;

  /// Validation: the new password is too short.
  ///
  /// In en, this message translates to:
  /// **'{min, plural, =1{Use at least 1 character} other{Use at least {min} characters}}'**
  String passwordTooShort(int min);

  /// Main button of the sign-in form.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// Main button of the registration form.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpButton;

  /// Switches the form to registration.
  ///
  /// In en, this message translates to:
  /// **'New to Collarbell? Create an account'**
  String get switchToSignUp;

  /// Switches the form to sign-in.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get switchToSignIn;

  /// Sign-in screen: sends a link to set a new password to the e-mail above.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// "Forgot password?" was pressed with no valid e-mail.
  ///
  /// In en, this message translates to:
  /// **'Enter your e-mail above: the link for a new password goes there.'**
  String get passwordResetNeedsEmail;

  /// After "Forgot password?". Doesn't say whether the account exists.
  ///
  /// In en, this message translates to:
  /// **'If there is an account for {email}, a letter with a link for a new password is on its way. Check the spam folder too.'**
  String passwordResetSent(String email);

  /// Sign-in failed: wrong email or password.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get authErrorInvalidCredentials;

  /// Registration failed: the email is taken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in instead.'**
  String get authErrorEmailInUse;

  /// Registration failed: weak password.
  ///
  /// In en, this message translates to:
  /// **'This password is too easy to guess. Choose a longer one.'**
  String get authErrorWeakPassword;

  /// Auth failed: malformed email.
  ///
  /// In en, this message translates to:
  /// **'This email address doesn\'t look right.'**
  String get authErrorInvalidEmail;

  /// Auth failed: the account is disabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authErrorUserDisabled;

  /// Auth failed: rate limited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in a few minutes.'**
  String get authErrorTooManyRequests;

  /// Auth failed: network error.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get authErrorNetwork;

  /// Auth failed: the Email/Password provider is disabled in Firebase.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in is turned off for this app.'**
  String get authErrorNotAllowed;

  /// Auth failed for another reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Try again.'**
  String get authErrorUnknown;

  /// Overline above the developer sign-in block. Always upper case.
  ///
  /// In en, this message translates to:
  /// **'DEVELOPER MODE'**
  String get devModeOverline;

  /// Explains developer sign-in (dev builds only).
  ///
  /// In en, this message translates to:
  /// **'Sign in with a local test account. The API has to run in development mode.'**
  String get devModeBody;

  /// Label of the email used for developer sign-in.
  ///
  /// In en, this message translates to:
  /// **'Developer email'**
  String get devEmailLabel;

  /// The stable user ID derived from the developer email.
  ///
  /// In en, this message translates to:
  /// **'User ID: {uid}'**
  String devUserId(String uid);

  /// Signs in with the developer account.
  ///
  /// In en, this message translates to:
  /// **'Continue as developer'**
  String get devContinue;

  /// Title of the main screen.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// Today's date above the title, e.g. Wednesday, October 1.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String todayDate(DateTime date);

  /// Empty state title on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled yet'**
  String get todayEmptyTitle;

  /// Empty state text on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'Feeding times, visits, and vaccinations and treatments due in the next 30 days will appear here.'**
  String get todayEmptyBody;

  /// Today with no pets yet: the first step.
  ///
  /// In en, this message translates to:
  /// **'Start with a pet'**
  String get todayStartTitle;

  /// Today with no pets yet.
  ///
  /// In en, this message translates to:
  /// **'Add a cat or a dog: their feeding, vaccinations, treatments and what to buy will show up here.'**
  String get todayStartBody;

  /// Empty Today: opens a new feeding schedule (the only pet's, or the Pets list to pick one).
  ///
  /// In en, this message translates to:
  /// **'Add feeding'**
  String get todayAddFeeding;

  /// Action card on an empty Today: the care plan of the pet (presets).
  ///
  /// In en, this message translates to:
  /// **'Vaccinations and treatments'**
  String get todayAddCare;

  /// Title of the pets screen.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get petsTitle;

  /// Empty state title on the pets screen.
  ///
  /// In en, this message translates to:
  /// **'No pets yet'**
  String get petsEmptyTitle;

  /// Empty state text on the pets screen.
  ///
  /// In en, this message translates to:
  /// **'You\'ll add your cats and dogs here.'**
  String get petsEmptyBody;

  /// Species name in the pet list.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get petSpeciesCat;

  /// Species name in the pet list.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get petSpeciesDog;

  /// Species name in the pet list.
  ///
  /// In en, this message translates to:
  /// **'Other animal'**
  String get petSpeciesOther;

  /// Title of the supplies screen.
  ///
  /// In en, this message translates to:
  /// **'Supplies'**
  String get suppliesTitle;

  /// Placeholder title on the supplies screen.
  ///
  /// In en, this message translates to:
  /// **'No supplies yet'**
  String get suppliesEmptyTitle;

  /// Placeholder text on the supplies screen.
  ///
  /// In en, this message translates to:
  /// **'Add food, litter or medicine: the app tells you when it\'s time to buy.'**
  String get suppliesEmptyBody;

  /// Title of the account and settings screen.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get moreAccount;

  /// Caption above the account email.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get moreSignedInAs;

  /// Shown when the account has no email.
  ///
  /// In en, this message translates to:
  /// **'No email'**
  String get moreNoEmail;

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get moreLanguage;

  /// Language option: follow the phone's language.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get moreLanguageSystem;

  /// Language option. Always written in English.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEnglish;

  /// Language option. Always written in Russian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageNameRussian;

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get moreTheme;

  /// Theme option. Light is the default.
  ///
  /// In en, this message translates to:
  /// **'Light (default)'**
  String get moreThemeLight;

  /// Theme option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get moreThemeDark;

  /// Theme option: follow the phone's setting.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get moreThemeSystem;

  /// Signs out of the account.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get moreSignOut;

  /// Asked before signing out on the More screen.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// Body of the sign-out question.
  ///
  /// In en, this message translates to:
  /// **'Reminders stop coming to this phone until you sign in again.'**
  String get signOutBody;

  /// Shown in dev builds: the auth mode and the API address.
  ///
  /// In en, this message translates to:
  /// **'Developer mode · {server}'**
  String moreDeveloperInfo(String server);

  /// Button: adds something, e.g. a microchip.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// Dialog button that closes it without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Confirms deleting in a dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Button or tooltip that opens an edit form.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// Tooltip of the overflow menu button.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get commonMoreActions;

  /// A no answer in details, e.g. Neutered: No.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// A yes answer in details, e.g. Neutered: Yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// Confirms removing a photo.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// Main button of a form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Request failed with 404.
  ///
  /// In en, this message translates to:
  /// **'This wasn\'t found. It may have been deleted.'**
  String get errorNotFound;

  /// Request failed with 400 and the form can't show the problem on a field.
  ///
  /// In en, this message translates to:
  /// **'Some details weren\'t accepted. Check them and try again.'**
  String get errorValidation;

  /// Upload failed with 413.
  ///
  /// In en, this message translates to:
  /// **'This file is too large. Upload files up to 15 MB.'**
  String get errorFileTooLarge;

  /// Upload failed with 415.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported. Use a JPEG, PNG or WebP photo, or a PDF.'**
  String get errorFileUnsupported;

  /// Under a field the server rejected (its own text is English and for developers).
  ///
  /// In en, this message translates to:
  /// **'This value wasn\'t accepted. Check it.'**
  String get formServerFieldError;

  /// Above the Save button when some fields have errors; the form scrolls to the first one.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted fields.'**
  String get formCheckFields;

  /// Validation: the text is too long.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =1{Use 1 character or fewer} other{Use {max} characters or fewer}}'**
  String formTooLong(int max);

  /// A calendar date, e.g. Apr 3, 2021.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String dateMedium(DateTime date);

  /// Placeholder of an empty date field.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get dateNotSet;

  /// Tooltip of the button that empties a date field.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get dateClear;

  /// Label on the tile of a PDF page.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get filePdf;

  /// Sheet action: opens the camera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get mediaTakePhoto;

  /// Sheet action: opens the photo library.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get mediaChooseFromLibrary;

  /// Sheet action: opens Files to pick a PDF.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF file'**
  String get mediaChoosePdf;

  /// Sheet action: removes the pet's photo.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get mediaRemovePhoto;

  /// The camera or library could not be opened (no access, no camera).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera or photos. Check the app\'s access in Settings.'**
  String get mediaPickerFailed;

  /// Dialog after each photo of a page.
  ///
  /// In en, this message translates to:
  /// **'Page added'**
  String get mediaPageAddedTitle;

  /// Dialog after each photo of a page.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of another page?'**
  String get mediaPageAddedBody;

  /// Ends taking photos of pages.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get mediaDone;

  /// Takes one more photo of a page.
  ///
  /// In en, this message translates to:
  /// **'Add another page'**
  String get mediaAddAnotherPage;

  /// Upload progress, counted in files.
  ///
  /// In en, this message translates to:
  /// **'Uploading {current} of {total}'**
  String uploadProgress(int current, int total);

  /// All files are uploaded; the document is being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get uploadSaving;

  /// The phone could not open a PDF link.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the PDF.'**
  String get pdfOpenFailed;

  /// Screen reader label of a page tile.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String pageNumber(int number);

  /// Title of the full-screen page viewer.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageOf(int current, int total);

  /// Tooltip of the remove button on a page in the document form.
  ///
  /// In en, this message translates to:
  /// **'Remove page {number}'**
  String pageRemove(int number);

  /// Tooltip of the delete button in the page viewer.
  ///
  /// In en, this message translates to:
  /// **'Delete page'**
  String get pageDelete;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete this page?'**
  String get pageDeleteTitle;

  /// Confirmation dialog text.
  ///
  /// In en, this message translates to:
  /// **'The photo of this page will be deleted. You can\'t undo this.'**
  String get pageDeleteBody;

  /// The full-size page could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the page.'**
  String get pageLoadFailed;

  /// Floating button on the pets list.
  ///
  /// In en, this message translates to:
  /// **'Add pet'**
  String get petsAdd;

  /// Species in the segmented button of the pet form.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get petSpeciesOtherShort;

  /// Sex of a pet.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get petSexFemale;

  /// Sex of a pet.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get petSexMale;

  /// Sex of a pet when the owner doesn't say.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get petSexUnknown;

  /// Pet status.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get petStatusActive;

  /// Pet status, shown in the pets list.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get petStatusArchived;

  /// Pet status, shown in the pets list. Gender-neutral.
  ///
  /// In en, this message translates to:
  /// **'Deceased'**
  String get petStatusDeceased;

  /// Field label: the pet's name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get petNameLabel;

  /// Validation: the name is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter the pet\'s name'**
  String get petNameRequired;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get petSpeciesLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get petSexLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get petBreedLabel;

  /// Placeholder of the breed field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Maine Coon'**
  String get petBreedHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get petBirthDateLabel;

  /// Switch under the date of birth.
  ///
  /// In en, this message translates to:
  /// **'The date is approximate'**
  String get petBirthDateApproximate;

  /// An approximate date of birth in the details.
  ///
  /// In en, this message translates to:
  /// **'About {date}'**
  String petBirthDateAbout(DateTime date);

  /// Switch in the form and row in the details.
  ///
  /// In en, this message translates to:
  /// **'Neutered or spayed'**
  String get petNeuteredLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Date of neutering (optional)'**
  String get petNeuteredOnLabel;

  /// Neutered on a known date, in the details.
  ///
  /// In en, this message translates to:
  /// **'Yes, {date}'**
  String petNeuteredOnValue(DateTime date);

  /// Validation of the neutering date.
  ///
  /// In en, this message translates to:
  /// **'Neutering can\'t be before the date of birth'**
  String get petNeuteredBeforeBirth;

  /// Field label: the coat colour as in the passport.
  ///
  /// In en, this message translates to:
  /// **'Coat colour'**
  String get petColorLabel;

  /// Placeholder of the coat colour field.
  ///
  /// In en, this message translates to:
  /// **'As in the passport, e.g. black and white'**
  String get petColorHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Markings'**
  String get petMarkingsLabel;

  /// Placeholder of the markings field.
  ///
  /// In en, this message translates to:
  /// **'e.g. white spot on the chest'**
  String get petMarkingsHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get petAllergiesLabel;

  /// Placeholder of the allergies field.
  ///
  /// In en, this message translates to:
  /// **'Food, medicines'**
  String get petAllergiesHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get petNotesLabel;

  /// Title of the form that adds a pet.
  ///
  /// In en, this message translates to:
  /// **'New pet'**
  String get petFormAddTitle;

  /// Title of the form that edits a pet.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get petFormEditTitle;

  /// Button under the pet's photo.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get petPhotoAdd;

  /// Button under the pet's photo.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get petPhotoChange;

  /// Screen reader label of the pet's photo.
  ///
  /// In en, this message translates to:
  /// **'Open photo'**
  String get petPhotoOpen;

  /// Shown in the save button while the photo uploads.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo'**
  String get petPhotoUploading;

  /// Snackbar after saving when only the photo failed.
  ///
  /// In en, this message translates to:
  /// **'The pet is saved, but the photo couldn\'t be uploaded. Try again on the pet\'s page.'**
  String get petPhotoSaveFailed;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Remove the photo?'**
  String get petPhotoRemoveTitle;

  /// Confirmation dialog text.
  ///
  /// In en, this message translates to:
  /// **'The photo will be deleted. You can\'t undo this.'**
  String get petPhotoRemoveBody;

  /// Section title on the Overview tab.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get petDetailsTitle;

  /// Tooltip of the edit button on the pet's page.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get petEdit;

  /// Menu item on the pet's page.
  ///
  /// In en, this message translates to:
  /// **'Delete pet'**
  String get petDelete;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String petDeleteTitle(String name);

  /// Confirmation dialog text.
  ///
  /// In en, this message translates to:
  /// **'This also deletes the passport details, documents and photos. You can\'t undo this.'**
  String get petDeleteBody;

  /// Tab on the pet's page.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get petTabOverview;

  /// Tab on the pet's page.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get petTabPassport;

  /// Tab on the pet's page.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get petTabDocuments;

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Microchips and tattoos'**
  String get identifiersTitle;

  /// Shown when the pet has no identifiers.
  ///
  /// In en, this message translates to:
  /// **'No microchip or tattoo yet.'**
  String get identifiersEmpty;

  /// Button in the pet form.
  ///
  /// In en, this message translates to:
  /// **'Add a microchip or tattoo'**
  String get identifiersAdd;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get identifierTypeLabel;

  /// Identifier type: 15-digit ISO chip.
  ///
  /// In en, this message translates to:
  /// **'ISO microchip'**
  String get identifierTypeIsoChip;

  /// Identifier type: older US chips.
  ///
  /// In en, this message translates to:
  /// **'Non-ISO microchip'**
  String get identifierTypeLegacyChip;

  /// Identifier type.
  ///
  /// In en, this message translates to:
  /// **'Tattoo'**
  String get identifierTypeTattoo;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Chip number'**
  String get identifierChipLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Tattoo code'**
  String get identifierTattooLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Date implanted'**
  String get identifierChipDateLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Date applied'**
  String get identifierTattooDateLabel;

  /// Field label: where the chip or tattoo is.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get identifierLocationLabel;

  /// Placeholder of the location field.
  ///
  /// In en, this message translates to:
  /// **'e.g. left side of the neck'**
  String get identifierLocationHint;

  /// Tooltip of the remove button on an identifier.
  ///
  /// In en, this message translates to:
  /// **'Remove from the list'**
  String get identifierRemove;

  /// Validation: the code is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter the number'**
  String get identifierCodeRequired;

  /// Helper under an ISO chip number.
  ///
  /// In en, this message translates to:
  /// **'15 digits, e.g. 276 098 100 123 456'**
  String get identifierIsoHint;

  /// Validation of an ISO chip number.
  ///
  /// In en, this message translates to:
  /// **'An ISO microchip number has 15 digits'**
  String get identifierIsoLength;

  /// Validation of an ISO chip number.
  ///
  /// In en, this message translates to:
  /// **'Numbers starting with 999 belong to test chips'**
  String get identifierIsoTestChip;

  /// Validation of a non-ISO chip number.
  ///
  /// In en, this message translates to:
  /// **'Use 10 characters 0–9 and A–F, or 9 digits (AVID)'**
  String get identifierLegacyFormat;

  /// Hint for non-ISO chips.
  ///
  /// In en, this message translates to:
  /// **'Not ISO: take your own scanner when travelling.'**
  String get identifierLegacyHint;

  /// Validation of a tattoo code.
  ///
  /// In en, this message translates to:
  /// **'Use 1 to {max} letters and digits'**
  String identifierTattooLength(int max);

  /// Validation: the same code twice.
  ///
  /// In en, this message translates to:
  /// **'This number is already in the list'**
  String get identifierDuplicate;

  /// When the chip was implanted.
  ///
  /// In en, this message translates to:
  /// **'Implanted {date}'**
  String identifierChipImplantedOn(DateTime date);

  /// When the tattoo was applied.
  ///
  /// In en, this message translates to:
  /// **'Applied {date}'**
  String identifierTattooAppliedOn(DateTime date);

  /// Tooltip of the scan button in a microchip's number field.
  ///
  /// In en, this message translates to:
  /// **'Scan the number'**
  String get chipScanAction;

  /// Title of the microchip scanner.
  ///
  /// In en, this message translates to:
  /// **'Microchip number'**
  String get chipScanTitle;

  /// Under the scanner's frame: the sticker in the passport, with the chip's barcode.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the chip sticker'**
  String get chipScanHint;

  /// The chip scanner can't open the camera.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available. Allow camera access in Settings, or use a photo.'**
  String get chipScanCameraUnavailable;

  /// Shown for a moment when the scanner sees another code (a product barcode, a website).
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a microchip number'**
  String get chipScanNotChip;

  /// Button on the chip scanner: a photo of the sticker or the passport page, from the camera or the gallery.
  ///
  /// In en, this message translates to:
  /// **'From a photo'**
  String get chipScanFromPhoto;

  /// Under "From a photo" when AI runs on Gemini's free tier.
  ///
  /// In en, this message translates to:
  /// **'A photo without a readable barcode goes to AI on Gemini\'s free tier: only your own documents.'**
  String get chipScanFreeTier;

  /// While AI reads the photo of a chip.
  ///
  /// In en, this message translates to:
  /// **'Reading the photo… Usually a few seconds, sometimes a minute.'**
  String get chipScanReading;

  /// Title of the sheet to pick one of the numbers AI read.
  ///
  /// In en, this message translates to:
  /// **'Several numbers on the photo. Which one is it?'**
  String get chipScanPickTitle;

  /// Title of the sheet to pick one of several chip barcodes the scanner saw at once, in sight or on a photo.
  ///
  /// In en, this message translates to:
  /// **'Several chip numbers found. Which one is it?'**
  String get chipScanPickFound;

  /// AI found no microchip or tattoo number on the photo.
  ///
  /// In en, this message translates to:
  /// **'No chip number found on the photo — type it in.'**
  String get chipScanNothingFound;

  /// After a number read by AI was put into the form.
  ///
  /// In en, this message translates to:
  /// **'Read from the photo: check it against the passport.'**
  String get chipScanCheck;

  /// All AI models are busy.
  ///
  /// In en, this message translates to:
  /// **'AI is busy right now. Try again in a minute, or type the number in.'**
  String get chipScanBusy;

  /// The phone found no barcode in the photo, and the server has no AI.
  ///
  /// In en, this message translates to:
  /// **'No barcode on the photo, and AI isn\'t set up to read it: type the number in.'**
  String get chipScanNoAi;

  /// The AI provider refused.
  ///
  /// In en, this message translates to:
  /// **'AI refused to read the photo. Type the number in.'**
  String get chipScanRejected;

  /// Section title on the Passport tab.
  ///
  /// In en, this message translates to:
  /// **'Passport details'**
  String get passportTitle;

  /// Disclaimer at the top of the Passport tab.
  ///
  /// In en, this message translates to:
  /// **'This digital copy is for your information. The paper passport stays the official document.'**
  String get passportDisclaimer;

  /// Shown before the passport header is saved.
  ///
  /// In en, this message translates to:
  /// **'Add the passport number, the vet who issued it and the owners.'**
  String get passportEmpty;

  /// Button that opens the passport form.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get passportAdd;

  /// Title of the passport form.
  ///
  /// In en, this message translates to:
  /// **'Passport details'**
  String get passportFormTitle;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Passport model'**
  String get passportModelLabel;

  /// Passport model: Regulation 577/2013.
  ///
  /// In en, this message translates to:
  /// **'EU passport (2014 model)'**
  String get passportModelEu2014;

  /// Passport model: Regulation 2026/705.
  ///
  /// In en, this message translates to:
  /// **'EU passport (2026 model)'**
  String get passportModelEu2026;

  /// Passport model.
  ///
  /// In en, this message translates to:
  /// **'Other passport'**
  String get passportModelOther;

  /// No passport model chosen.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get passportModelNotSet;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Passport number'**
  String get passportNumberLabel;

  /// Placeholder of the passport number.
  ///
  /// In en, this message translates to:
  /// **'e.g. DE01234567'**
  String get passportNumberHint;

  /// Validation of the passport number.
  ///
  /// In en, this message translates to:
  /// **'Use up to 30 letters, digits, hyphens and slashes'**
  String get passportNumberInvalid;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Issuing country'**
  String get passportCountryLabel;

  /// Placeholder of the country field.
  ///
  /// In en, this message translates to:
  /// **'Two-letter code, e.g. DE'**
  String get passportCountryHint;

  /// Validation of the country code.
  ///
  /// In en, this message translates to:
  /// **'Use the two-letter country code, such as DE or FR'**
  String get passportCountryInvalid;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Date of issue'**
  String get passportIssuedOnLabel;

  /// Section title and details row.
  ///
  /// In en, this message translates to:
  /// **'Issuing vet'**
  String get passportIssuerTitle;

  /// Section title in the passport form.
  ///
  /// In en, this message translates to:
  /// **'Owners'**
  String get passportOwnersTitle;

  /// Details row when there is one owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get passportOwnerTitle;

  /// Owner card title and details row.
  ///
  /// In en, this message translates to:
  /// **'Owner {number}'**
  String passportOwnerNumbered(int number);

  /// Button in the passport form.
  ///
  /// In en, this message translates to:
  /// **'Add owner'**
  String get passportOwnerAdd;

  /// Tooltip of the remove button on an owner.
  ///
  /// In en, this message translates to:
  /// **'Remove owner'**
  String get passportOwnerRemove;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get passportNotesLabel;

  /// Section title: photos of the paper passport.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get passportPagesTitle;

  /// Button that photographs passport pages.
  ///
  /// In en, this message translates to:
  /// **'Add pages'**
  String get passportPagesAdd;

  /// After a failed upload of passport pages: sends the same pages again.
  ///
  /// In en, this message translates to:
  /// **'Upload again'**
  String get passportPagesRetry;

  /// Shown when there are no passport pages.
  ///
  /// In en, this message translates to:
  /// **'Photograph the pages of the paper passport to keep a copy at hand.'**
  String get passportPagesEmpty;

  /// Field label of a passport contact.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactNameLabel;

  /// Field label of a passport contact.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get contactAddressLabel;

  /// Field label of a passport contact.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactPhoneLabel;

  /// Field label of a passport contact.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactEmailLabel;

  /// Button on the Documents tab.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get documentsAdd;

  /// Empty state title.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get documentsEmptyTitle;

  /// Empty state text.
  ///
  /// In en, this message translates to:
  /// **'Lab results, prescriptions and certificates will appear here.'**
  String get documentsEmptyBody;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get documentTypeLabel;

  /// Document type.
  ///
  /// In en, this message translates to:
  /// **'Passport pages'**
  String get documentTypePassportPage;

  /// Document type.
  ///
  /// In en, this message translates to:
  /// **'Vaccination certificate'**
  String get documentTypeVaccinationCertificate;

  /// Document type.
  ///
  /// In en, this message translates to:
  /// **'Lab results'**
  String get documentTypeLabResult;

  /// Document type.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get documentTypePrescription;

  /// Document type.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get documentTypeInvoice;

  /// Document type.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get documentTypeInsurance;

  /// Document type.
  ///
  /// In en, this message translates to:
  /// **'Other document'**
  String get documentTypeOther;

  /// Number of pages of a document.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String documentPageCount(int count);

  /// Title of the form that adds a document.
  ///
  /// In en, this message translates to:
  /// **'New document'**
  String get documentFormAddTitle;

  /// Title of the form that edits a document.
  ///
  /// In en, this message translates to:
  /// **'Edit document'**
  String get documentFormEditTitle;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get documentTitleLabel;

  /// Placeholder of the title field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Blood test'**
  String get documentTitleHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Document date'**
  String get documentDateLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get documentNotesLabel;

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get documentPagesTitle;

  /// Button in the document form.
  ///
  /// In en, this message translates to:
  /// **'Add pages'**
  String get documentPagesAdd;

  /// Shown before any page is added.
  ///
  /// In en, this message translates to:
  /// **'Take photos of the pages or choose a PDF.'**
  String get documentPagesEmpty;

  /// Validation: no pages.
  ///
  /// In en, this message translates to:
  /// **'Add at least one page'**
  String get documentPagesRequired;

  /// Validation: too many pages.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =1{Use 1 page or fewer} other{Use {max} pages or fewer}}'**
  String documentPagesTooMany(int max);

  /// Section title on the document page.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get documentDetailsTitle;

  /// Details row: when the document was added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get documentAddedOnLabel;

  /// Menu item on the document page.
  ///
  /// In en, this message translates to:
  /// **'Delete document'**
  String get documentDelete;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete this document?'**
  String get documentDeleteTitle;

  /// Confirmation dialog text.
  ///
  /// In en, this message translates to:
  /// **'All its pages will be deleted too. You can\'t undo this.'**
  String get documentDeleteBody;

  /// Tab on the pet's page: care plans and history.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get petTabHealth;

  /// Field label: the kind of care.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get careKindLabel;

  /// Kind of care.
  ///
  /// In en, this message translates to:
  /// **'Vaccination'**
  String get careKindVaccination;

  /// Kind of care: blood test of the rabies antibody level.
  ///
  /// In en, this message translates to:
  /// **'Rabies antibody test'**
  String get careKindRabiesTiter;

  /// Kind of care.
  ///
  /// In en, this message translates to:
  /// **'Deworming'**
  String get careKindDeworming;

  /// Kind of care: tapeworm treatment before travel (EU passport section VII).
  ///
  /// In en, this message translates to:
  /// **'Echinococcus treatment'**
  String get careKindEchinococcus;

  /// Kind of care: flea and tick treatment.
  ///
  /// In en, this message translates to:
  /// **'Fleas and ticks'**
  String get careKindFleaTick;

  /// Kind of care: heartworm prevention.
  ///
  /// In en, this message translates to:
  /// **'Heartworm'**
  String get careKindHeartworm;

  /// Kind of care: clinical examination by a vet.
  ///
  /// In en, this message translates to:
  /// **'Check-up'**
  String get careKindVetExam;

  /// Kind of care.
  ///
  /// In en, this message translates to:
  /// **'Dental care'**
  String get careKindDental;

  /// Kind of care: nail trim, bath, haircut.
  ///
  /// In en, this message translates to:
  /// **'Grooming'**
  String get careKindGrooming;

  /// Kind of care: any other vet procedure.
  ///
  /// In en, this message translates to:
  /// **'Procedure'**
  String get careKindProcedure;

  /// Kind of care.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get careKindOther;

  /// Field label: what a vaccine protects against.
  ///
  /// In en, this message translates to:
  /// **'Protects against'**
  String get careTargetsLabel;

  /// Vaccine target.
  ///
  /// In en, this message translates to:
  /// **'Rabies'**
  String get vaccineTargetRabies;

  /// Vaccine target, cats.
  ///
  /// In en, this message translates to:
  /// **'Panleukopenia (FPV)'**
  String get vaccineTargetFpv;

  /// Vaccine target, cats: rhinotracheitis.
  ///
  /// In en, this message translates to:
  /// **'Herpesvirus (FHV-1)'**
  String get vaccineTargetFhv1;

  /// Vaccine target, cats.
  ///
  /// In en, this message translates to:
  /// **'Calicivirus (FCV)'**
  String get vaccineTargetFcv;

  /// Vaccine target, cats.
  ///
  /// In en, this message translates to:
  /// **'Leukaemia (FeLV)'**
  String get vaccineTargetFelv;

  /// Vaccine target, cats.
  ///
  /// In en, this message translates to:
  /// **'Chlamydia'**
  String get vaccineTargetChlamydia;

  /// Vaccine target, dogs.
  ///
  /// In en, this message translates to:
  /// **'Distemper (CDV)'**
  String get vaccineTargetCdv;

  /// Vaccine target, dogs: canine adenovirus.
  ///
  /// In en, this message translates to:
  /// **'Hepatitis (CAV-2)'**
  String get vaccineTargetCav2;

  /// Vaccine target, dogs.
  ///
  /// In en, this message translates to:
  /// **'Parvovirus (CPV-2)'**
  String get vaccineTargetCpv2;

  /// Vaccine target, dogs.
  ///
  /// In en, this message translates to:
  /// **'Parainfluenza (CPiV)'**
  String get vaccineTargetCpiv;

  /// Vaccine target, dogs.
  ///
  /// In en, this message translates to:
  /// **'Leptospirosis'**
  String get vaccineTargetLepto;

  /// Vaccine target, dogs.
  ///
  /// In en, this message translates to:
  /// **'Kennel cough (Bordetella)'**
  String get vaccineTargetBordetella;

  /// Vaccine target, dogs.
  ///
  /// In en, this message translates to:
  /// **'Lyme disease'**
  String get vaccineTargetLyme;

  /// Vaccine target, dogs.
  ///
  /// In en, this message translates to:
  /// **'Canine influenza'**
  String get vaccineTargetCanineInfluenza;

  /// Vaccine target, dogs.
  ///
  /// In en, this message translates to:
  /// **'Leishmaniasis'**
  String get vaccineTargetLeishmania;

  /// Interval of a plan that is done once.
  ///
  /// In en, this message translates to:
  /// **'One-off'**
  String get intervalOneOff;

  /// Interval of a repeating plan whose unit this app version doesn't know.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get intervalRepeats;

  /// How often a plan repeats, for an interval of 1 (the plural forms cover the other numbers).
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get intervalEveryDay;

  /// How often a plan repeats, for an interval of 1 (the plural forms cover the other numbers).
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get intervalEveryWeek;

  /// How often a plan repeats, for an interval of 1 (the plural forms cover the other numbers).
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get intervalEveryMonth;

  /// How often a plan repeats, for an interval of 1 (the plural forms cover the other numbers).
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get intervalEveryYear;

  /// How often a plan repeats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every day} other{Every {count} days}}'**
  String intervalEveryDays(int count);

  /// How often a plan repeats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week} other{Every {count} weeks}}'**
  String intervalEveryWeeks(int count);

  /// How often a plan repeats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every month} other{Every {count} months}}'**
  String intervalEveryMonths(int count);

  /// How often a plan repeats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every year} other{Every {count} years}}'**
  String intervalEveryYears(int count);

  /// Interval unit after a number in the plan form (Every 3 days).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day} other{days}}'**
  String intervalUnitDays(int count);

  /// Interval unit after a number in the plan form (Every 3 weeks).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{week} other{weeks}}'**
  String intervalUnitWeeks(int count);

  /// Interval unit after a number in the plan form (Every 3 months).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{month} other{months}}'**
  String intervalUnitMonths(int count);

  /// Interval unit after a number in the plan form (Every 3 years).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{year} other{years}}'**
  String intervalUnitYears(int count);

  /// A plan is due today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dueToday;

  /// A plan is due tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dueTomorrow;

  /// How soon a plan is due.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{In 1 day} other{In {days} days}}'**
  String dueInDays(int days);

  /// How soon a plan is due, for dates two months away or more.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{In 1 month} other{In {months} months}}'**
  String dueInMonths(int months);

  /// How long ago a plan was due. Shown in red with an icon.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day overdue} other{{days} days overdue}}'**
  String dueOverdueDays(int days);

  /// Status of a plan and group title.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get careStatusOverdue;

  /// Status of a plan (within 14 days) and group title.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get careStatusDueSoon;

  /// Status of a plan and group title.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get careStatusUpcoming;

  /// Status of a one-off plan that is done.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get careStatusFinished;

  /// Status of a plan that was turned off.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get careStatusPaused;

  /// Group title on the Health tab.
  ///
  /// In en, this message translates to:
  /// **'Finished or paused'**
  String get healthGroupInactive;

  /// Section title on the Health tab.
  ///
  /// In en, this message translates to:
  /// **'Care plan'**
  String get healthPlansTitle;

  /// Button on the Health tab.
  ///
  /// In en, this message translates to:
  /// **'Add plan'**
  String get healthPlansAdd;

  /// Shown when the pet has no plans.
  ///
  /// In en, this message translates to:
  /// **'No plans yet. Add vaccinations and treatments to see when they are due.'**
  String get healthPlansEmpty;

  /// Button that folds and unfolds the inactive plans; an arrow shows which.
  ///
  /// In en, this message translates to:
  /// **'Finished or paused ({count})'**
  String healthInactiveToggle(int count);

  /// Section title on the Health tab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get healthHistoryTitle;

  /// Button: adds a record by hand, e.g. from the paper passport.
  ///
  /// In en, this message translates to:
  /// **'Add past record'**
  String get healthHistoryAdd;

  /// Shown when the pet has no records.
  ///
  /// In en, this message translates to:
  /// **'No records yet. Add past vaccinations and treatments from the paper passport.'**
  String get healthHistoryEmpty;

  /// Filter chip: records of every kind.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get healthFilterAll;

  /// Button on a plan: marks it done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planDone;

  /// When a plan was last marked done; the date comes already formatted.
  ///
  /// In en, this message translates to:
  /// **'Last done {date}'**
  String planLastDone(String date);

  /// Screen reader label: how many photos a record has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String recordPhotoCount(int count);

  /// Title of the preset picker.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get presetPickerTitle;

  /// Picker row: a plan without a preset.
  ///
  /// In en, this message translates to:
  /// **'Own plan'**
  String get presetOwnTitle;

  /// Picker row text.
  ///
  /// In en, this message translates to:
  /// **'Set the type and how often yourself.'**
  String get presetOwnBody;

  /// Warning on a dog-only product; never for cats.
  ///
  /// In en, this message translates to:
  /// **'Dogs only'**
  String get presetDogOnly;

  /// Shown when no preset suits the pet's species.
  ///
  /// In en, this message translates to:
  /// **'There are no ready-made plans for this animal yet.'**
  String get presetNoneForSpecies;

  /// Preset group.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations'**
  String get presetGroupVaccinations;

  /// Preset group.
  ///
  /// In en, this message translates to:
  /// **'Deworming'**
  String get presetGroupDeworming;

  /// Preset group.
  ///
  /// In en, this message translates to:
  /// **'Fleas, ticks and heartworm'**
  String get presetGroupParasites;

  /// Preset group.
  ///
  /// In en, this message translates to:
  /// **'Check-ups and care'**
  String get presetGroupCheckUps;

  /// Preset group.
  ///
  /// In en, this message translates to:
  /// **'Before travel'**
  String get presetGroupTravel;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'FVRCP (panleukopenia, herpes, calici)'**
  String get presetCatFvrcp;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'After the kitten series and the 6-month booster. Low-risk indoor cats: every 3 years.'**
  String get presetCatFvrcpNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'FVRCP kitten series'**
  String get presetCatFvrcpKitten;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'From 6–8 weeks every 3–4 weeks until 16–20 weeks, then the yearly plan.'**
  String get presetCatFvrcpKittenNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Rabies'**
  String get presetRabies;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'The vaccine label says 1 or 3 years: use its \"valid until\" date.'**
  String get presetRabiesNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Feline leukaemia (FeLV)'**
  String get presetCatFelv;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Test first. Two doses 3–4 weeks apart, then yearly for cats that go outside.'**
  String get presetCatFelvNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Chlamydia'**
  String get presetCatChlamydia;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Only when the cat is at risk.'**
  String get presetCatChlamydiaNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Deworming'**
  String get presetDeworm;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'When the risk is unknown: at least 4 times a year.'**
  String get presetDewormNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Deworming, indoor cat'**
  String get presetCatDewormIndoor;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Indoor cats: 1–2 times a year.'**
  String get presetCatDewormIndoorNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Deworming, cat that hunts'**
  String get presetCatDewormOutdoor;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Cats that go out and hunt: 4–12 times a year.'**
  String get presetCatDewormOutdoorNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Deworming, kitten'**
  String get presetCatDewormKitten;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'From 3 weeks every 2 weeks until weaning, then monthly until 6 months.'**
  String get presetCatDewormKittenNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Fleas and ticks, monthly'**
  String get presetFleaTickMonthly;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Monthly products such as Frontline, Advantage or Revolution.'**
  String get presetCatFleaTickMonthlyNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Bravecto'**
  String get presetBravecto;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Some ticks: 8 weeks.'**
  String get presetBravectoNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Bravecto Plus (also worms and heartworm)'**
  String get presetCatBravectoPlus;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'US label: 2 months.'**
  String get presetCatBravectoPlusNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Seresto collar'**
  String get presetSeresto;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Check-up'**
  String get presetExam;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'From 10 years old: every 6 months.'**
  String get presetCatExamNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Dental check'**
  String get presetDental;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Nail trim'**
  String get presetNails;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'DHPP (distemper, hepatitis, parvo, parainfluenza)'**
  String get presetDogDhpp;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'After the puppy series and the booster at about 6 months or 1 year.'**
  String get presetDogDhppNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'DHPP puppy series'**
  String get presetDogDhppPuppy;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'From 6–8 weeks every 2–4 weeks until at least 16 weeks, then the 3-year plan.'**
  String get presetDogDhppPuppyNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Leptospirosis'**
  String get presetDogLepto;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'First 2 doses 2–4 weeks apart, then yearly.'**
  String get presetDogLeptoNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Kennel cough'**
  String get presetDogKennelCough;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'For dogs that meet other dogs: boarding, training, shows.'**
  String get presetDogKennelCoughNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Lyme disease'**
  String get presetDogLyme;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Where ticks carry Lyme disease.'**
  String get presetDogLymeNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Leishmaniasis'**
  String get presetDogLeishmania;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Southern Europe.'**
  String get presetDogLeishmaniaNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Deworming, mostly indoors'**
  String get presetDogDewormIndoor;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Dogs that stay home: 1–2 times a year.'**
  String get presetDogDewormIndoorNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Deworming, high risk'**
  String get presetDogDewormHigh;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Dogs that hunt, eat snails or grass, or get raw meat: up to 12 times a year.'**
  String get presetDogDewormHighNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Deworming, puppy'**
  String get presetDogDewormPuppy;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'From 14 days every 2 weeks until weaning, then monthly until 6 months.'**
  String get presetDogDewormPuppyNote;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Monthly products such as NexGard, Simparica, Credelio or Frontline.'**
  String get presetDogFleaTickMonthlyNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'K9 Advantix'**
  String get presetDogAdvantix;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Contains permethrin, which is toxic to cats. Never use it on a cat.'**
  String get presetDogAdvantixNote;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Heartworm prevention'**
  String get presetDogHeartworm;

  /// Title of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Tapeworm treatment before travel'**
  String get presetDogEchinococcus;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Finland, Ireland, Malta, Northern Ireland, Norway, the UK: 24–120 hours before entry. The vet writes the date and time.'**
  String get presetDogEchinococcusNote;

  /// Note of a care preset. Product names stay as on the package.
  ///
  /// In en, this message translates to:
  /// **'Senior dogs: every 6 months.'**
  String get presetDogExamNote;

  /// Title of the form that adds a plan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get planFormAddTitle;

  /// Title of the form that edits a plan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get planFormEditTitle;

  /// Field label: the plan's title.
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get planTitleLabel;

  /// Placeholder of the plan's title.
  ///
  /// In en, this message translates to:
  /// **'e.g. Deworming'**
  String get planTitleHint;

  /// Validation: the title is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter what needs to be done'**
  String get planTitleRequired;

  /// Field label above Repeats / Once.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get planRepeatLabel;

  /// Segment: the plan repeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get planRepeats;

  /// Segment: the plan is done once.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get planOnce;

  /// Label above the number and unit of the interval (Every 3 months).
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get planIntervalLabel;

  /// Validation of the interval number.
  ///
  /// In en, this message translates to:
  /// **'Use a whole number from 1 to {max}'**
  String planIntervalInvalid(int max);

  /// Field label: when it was last done.
  ///
  /// In en, this message translates to:
  /// **'Last done (optional)'**
  String get planLastDoneLabel;

  /// Helper under the last-done date.
  ///
  /// In en, this message translates to:
  /// **'The next date is counted from it.'**
  String get planLastDoneHelper;

  /// Field label: the plan's next date.
  ///
  /// In en, this message translates to:
  /// **'Next due'**
  String get planNextDueLabel;

  /// Field label: the date of a one-off plan.
  ///
  /// In en, this message translates to:
  /// **'Due on'**
  String get planDueOnLabel;

  /// Helper under a next date the form worked out.
  ///
  /// In en, this message translates to:
  /// **'Counted from the last time and the interval. You can change it.'**
  String get planNextDueComputed;

  /// Validation: a required date is empty.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get dateRequired;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Usual product (optional)'**
  String get planDefaultProductLabel;

  /// Placeholder of the usual product.
  ///
  /// In en, this message translates to:
  /// **'e.g. Milbemax'**
  String get planDefaultProductHint;

  /// Helper under the usual product.
  ///
  /// In en, this message translates to:
  /// **'Filled in when you mark the plan done.'**
  String get planDefaultProductHelper;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get careNotesLabel;

  /// Switch in the plan form.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get planActiveLabel;

  /// Helper under the Active switch.
  ///
  /// In en, this message translates to:
  /// **'Turn off to pause the plan: it leaves Today.'**
  String get planActiveHelper;

  /// Menu item in the plan form.
  ///
  /// In en, this message translates to:
  /// **'Delete plan'**
  String get planDelete;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete this plan?'**
  String get planDeleteTitle;

  /// Confirmation dialog text.
  ///
  /// In en, this message translates to:
  /// **'Records already made with it stay in the history. You can\'t undo this.'**
  String get planDeleteBody;

  /// Snackbar: a form closes because its plan no longer exists on the server.
  ///
  /// In en, this message translates to:
  /// **'This plan has been deleted, probably on another device.'**
  String get careGonePlan;

  /// Snackbar: a form closes because its record no longer exists on the server.
  ///
  /// In en, this message translates to:
  /// **'This record has been deleted, probably on another device.'**
  String get careGoneRecord;

  /// Snackbar: a form closes because its pet no longer exists on the server.
  ///
  /// In en, this message translates to:
  /// **'This pet has been deleted, probably on another device.'**
  String get careGonePet;

  /// Shown instead of the form for a plan with values this app doesn't know.
  ///
  /// In en, this message translates to:
  /// **'This plan was made in a newer version of Collarbell. Update the app to edit it.'**
  String get planReadOnly;

  /// Title of the Done screen.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get doneTitle;

  /// Field label: the date it was done.
  ///
  /// In en, this message translates to:
  /// **'Done on'**
  String get donePerformedOnLabel;

  /// Field label: the time of a tapeworm treatment.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get careTimeLabel;

  /// Helper under the time.
  ///
  /// In en, this message translates to:
  /// **'Travel rules count the hours from the treatment.'**
  String get careTimeHelper;

  /// Field label: the vaccine or medicine given.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get careProductLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get careManufacturerLabel;

  /// Field label: the batch (lot) number on the sticker.
  ///
  /// In en, this message translates to:
  /// **'Batch number'**
  String get careBatchLabel;

  /// Field label: a vaccination protects from this date.
  ///
  /// In en, this message translates to:
  /// **'Valid from'**
  String get careValidFromLabel;

  /// Field label: a vaccination protects until this date.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get careValidUntilLabel;

  /// Helper under Valid until on the Done screen.
  ///
  /// In en, this message translates to:
  /// **'As on the vaccine sticker. The next date follows it.'**
  String get doneValidUntilHelper;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get careClinicLabel;

  /// Field label: the vet's name.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get careVetLabel;

  /// Title of the block with the plan's next date.
  ///
  /// In en, this message translates to:
  /// **'Next time'**
  String get doneNextTitle;

  /// How the next date was worked out, e.g. Every 3 months from this date.
  ///
  /// In en, this message translates to:
  /// **'{interval} from this date'**
  String doneNextFromInterval(String interval);

  /// How the next date was worked out.
  ///
  /// In en, this message translates to:
  /// **'When the vaccine stops protecting'**
  String get doneNextFromValidUntil;

  /// How the next date was worked out.
  ///
  /// In en, this message translates to:
  /// **'Chosen by you'**
  String get doneNextChosen;

  /// Shown instead of a next date.
  ///
  /// In en, this message translates to:
  /// **'This one-off plan finishes when it\'s done.'**
  String get doneNextFinished;

  /// Shown when the app can't work out the next date itself.
  ///
  /// In en, this message translates to:
  /// **'Worked out when you save.'**
  String get doneNextUnknown;

  /// Button: choose another next date.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get doneNextChange;

  /// Button: drop the chosen next date.
  ///
  /// In en, this message translates to:
  /// **'Use the worked-out date'**
  String get doneNextReset;

  /// Snackbar after Done.
  ///
  /// In en, this message translates to:
  /// **'Marked as done. Next time: {date}.'**
  String doneSaved(DateTime date);

  /// Snackbar after Done on a one-off plan.
  ///
  /// In en, this message translates to:
  /// **'Marked as done. The plan is finished.'**
  String get doneSavedFinished;

  /// Error after Done when only the photos failed.
  ///
  /// In en, this message translates to:
  /// **'Marked as done, but some photos weren\'t attached. Save again to attach them.'**
  String get donePhotosFailed;

  /// Notice at the top of the Done screen after a partial save.
  ///
  /// In en, this message translates to:
  /// **'Already marked as done. Only the photos are left to attach.'**
  String get doneCompletedNotice;

  /// Section title: photos of a record.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get carePhotosTitle;

  /// Button that adds photos to a record.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get carePhotosAdd;

  /// Shown when a record has no photos.
  ///
  /// In en, this message translates to:
  /// **'Photograph the vaccine sticker or the vet\'s notes.'**
  String get carePhotosEmpty;

  /// Validation: too many photos.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =1{Use 1 photo or fewer} other{Use {max} photos or fewer}}'**
  String carePhotosTooMany(int max);

  /// Screen reader label of a photo tile.
  ///
  /// In en, this message translates to:
  /// **'Photo {number}'**
  String photoNumber(int number);

  /// Tooltip of the remove button on a photo in a form.
  ///
  /// In en, this message translates to:
  /// **'Remove photo {number}'**
  String photoRemove(int number);

  /// Title of the form that adds a record.
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get recordFormAddTitle;

  /// Title of the form that edits a record.
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get recordFormEditTitle;

  /// Field label: what was done.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get recordTitleLabel;

  /// Placeholder of the record's title.
  ///
  /// In en, this message translates to:
  /// **'e.g. Rabies'**
  String get recordTitleHint;

  /// Validation: the title is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter what was done'**
  String get recordTitleRequired;

  /// Field label: when it was done.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get recordPerformedOnLabel;

  /// Field label: the lab of a rabies antibody test.
  ///
  /// In en, this message translates to:
  /// **'Laboratory'**
  String get recordLaboratoryLabel;

  /// Field label: the lab's report number.
  ///
  /// In en, this message translates to:
  /// **'Report number'**
  String get recordReportNumberLabel;

  /// Field label: the rabies antibody level.
  ///
  /// In en, this message translates to:
  /// **'Result, IU/ml'**
  String get recordTiterLabel;

  /// Helper under the test result.
  ///
  /// In en, this message translates to:
  /// **'Travel to the EU needs at least 0.5 IU/ml.'**
  String get recordTiterHelper;

  /// Validation of the test result.
  ///
  /// In en, this message translates to:
  /// **'Use a number from 0 to 1000'**
  String get recordTiterInvalid;

  /// Field label: weight at the check-up.
  ///
  /// In en, this message translates to:
  /// **'Weight, kg'**
  String get recordWeightLabel;

  /// Validation of the weight.
  ///
  /// In en, this message translates to:
  /// **'Use a weight above 0 and up to 200 kg'**
  String get recordWeightInvalid;

  /// Switch and detail: the vet confirmed the pet can travel.
  ///
  /// In en, this message translates to:
  /// **'Fit to travel'**
  String get recordFitForTravel;

  /// Detail: the vet said the pet can't travel.
  ///
  /// In en, this message translates to:
  /// **'Not fit to travel'**
  String get recordNotFitForTravel;

  /// Validation of Valid from.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be before the date of the vaccination'**
  String get recordValidFromInvalid;

  /// Validation of Valid until.
  ///
  /// In en, this message translates to:
  /// **'Must be after the date of the vaccination and the start'**
  String get recordValidUntilInvalid;

  /// Shown for a record with values this app doesn't know.
  ///
  /// In en, this message translates to:
  /// **'This record was made in a newer version of Collarbell. Update the app to edit it.'**
  String get recordReadOnly;

  /// Error after saving when only the photos failed.
  ///
  /// In en, this message translates to:
  /// **'The record is saved, but some photos weren\'t attached. Save again to attach them.'**
  String get recordPhotosFailed;

  /// Menu item on the record's page.
  ///
  /// In en, this message translates to:
  /// **'Delete record'**
  String get recordDelete;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete this record?'**
  String get recordDeleteTitle;

  /// Confirmation dialog text.
  ///
  /// In en, this message translates to:
  /// **'Its photos will be deleted too. A plan it completed keeps its date. You can\'t undo this.'**
  String get recordDeleteBody;

  /// Section title on the record's page.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get recordDetailsTitle;

  /// Detail: where the record came from.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get recordSourceLabel;

  /// Record source.
  ///
  /// In en, this message translates to:
  /// **'Added by hand'**
  String get recordSourceManual;

  /// Record source.
  ///
  /// In en, this message translates to:
  /// **'From a scan'**
  String get recordSourceScan;

  /// A rabies antibody test result.
  ///
  /// In en, this message translates to:
  /// **'{value} IU/ml'**
  String recordTiterValue(String value);

  /// A weight.
  ///
  /// In en, this message translates to:
  /// **'{value} kg'**
  String recordWeightValue(String value);

  /// A date with a time, e.g. Jun 1, 2026, 14:30.
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String dateWithTime(DateTime date, String time);

  /// A vaccination's validity.
  ///
  /// In en, this message translates to:
  /// **'Valid {from} – {until}'**
  String careValidRange(DateTime from, DateTime until);

  /// A vaccination's validity.
  ///
  /// In en, this message translates to:
  /// **'Valid from {date}'**
  String careValidFromValue(DateTime date);

  /// A vaccination's validity.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String careValidUntilValue(DateTime date);

  /// A batch number in a row.
  ///
  /// In en, this message translates to:
  /// **'Batch {batch}'**
  String careBatchValue(String batch);

  /// Placeholder of an empty time field.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get timeNotSet;

  /// Tooltip of the button that empties a time field.
  ///
  /// In en, this message translates to:
  /// **'Clear time'**
  String get timeClear;

  /// Passport section title (EU passport V).
  ///
  /// In en, this message translates to:
  /// **'V. Rabies vaccination'**
  String get passportSectionRabies;

  /// Passport section title (EU passport VI).
  ///
  /// In en, this message translates to:
  /// **'VI. Rabies antibody test'**
  String get passportSectionTiter;

  /// Passport section title (EU passport VII).
  ///
  /// In en, this message translates to:
  /// **'VII. Echinococcus treatment'**
  String get passportSectionEchinococcus;

  /// Passport section title (EU passport VIII).
  ///
  /// In en, this message translates to:
  /// **'VIII. Other parasite treatments'**
  String get passportSectionTreatments;

  /// Passport section title (EU passport IX).
  ///
  /// In en, this message translates to:
  /// **'IX. Other vaccinations'**
  String get passportSectionOtherVaccinations;

  /// Passport section title (EU passport X).
  ///
  /// In en, this message translates to:
  /// **'X. Clinical examination'**
  String get passportSectionExaminations;

  /// Shown in an empty passport section.
  ///
  /// In en, this message translates to:
  /// **'No entries yet.'**
  String get passportSectionEmpty;

  /// Group on Today: due in 15 to 30 days.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get todayGroupLater;

  /// Section title on the More screen.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get moreAi;

  /// Title of the AI screen and its row on the More screen.
  ///
  /// In en, this message translates to:
  /// **'Reading photos with AI'**
  String get aiTitle;

  /// AI status: a model is set up on the server.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get aiConnected;

  /// AI status: no model is set up on the server.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get aiNotConnected;

  /// AI status while it loads.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get aiChecking;

  /// Explains the AI connection when it is set up.
  ///
  /// In en, this message translates to:
  /// **'AI reads photos of passport pages and vet documents, and notes written in words, and prepares a draft. Nothing is saved until you check it.'**
  String get aiConnectedBody;

  /// Explains how AI gets set up when it isn't.
  ///
  /// In en, this message translates to:
  /// **'AI is connected in the server settings. Until then the scan and note buttons are hidden; adding records by hand always works.'**
  String get aiNotConnectedBody;

  /// Warning when photos go to Gemini's free tier.
  ///
  /// In en, this message translates to:
  /// **'Free Gemini tier: Google may use what is sent to improve its products, and human reviewers may read it. Scan only your own documents.'**
  String get aiFreeTierWarning;

  /// Section title on the AI screen.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get aiModelsTitle;

  /// Explains the chain of models.
  ///
  /// In en, this message translates to:
  /// **'They are tried in this order: when one is busy or out of free requests, the next one reads the photos.'**
  String get aiModelsHint;

  /// A model is set up.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get aiModelReady;

  /// A model has no API key on the server.
  ///
  /// In en, this message translates to:
  /// **'No key'**
  String get aiModelNotReady;

  /// AI provider. Not translated.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini'**
  String get aiProviderGemini;

  /// AI provider: any service with the OpenAI API.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible service'**
  String get aiProviderOpenAiCompatible;

  /// AI provider: a local Ollama server. Not translated.
  ///
  /// In en, this message translates to:
  /// **'Ollama'**
  String get aiProviderOllama;

  /// AI provider this app doesn't know.
  ///
  /// In en, this message translates to:
  /// **'Other service'**
  String get aiProviderOther;

  /// Section title: AI use this month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get aiUsageTitle;

  /// Number of AI requests this month.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get aiUsageRequests;

  /// Tokens sent to the models this month.
  ///
  /// In en, this message translates to:
  /// **'Tokens sent'**
  String get aiUsageInputTokens;

  /// Tokens the models answered with this month.
  ///
  /// In en, this message translates to:
  /// **'Tokens received'**
  String get aiUsageOutputTokens;

  /// Section title on the AI screen.
  ///
  /// In en, this message translates to:
  /// **'Connection test'**
  String get aiTestTitle;

  /// Explains the connection test.
  ///
  /// In en, this message translates to:
  /// **'A model is asked the colour of a square on a small picture. It can take up to a minute.'**
  String get aiTestHint;

  /// Button that runs the connection test.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get aiTestButton;

  /// Result of a successful connection test.
  ///
  /// In en, this message translates to:
  /// **'It works: {model} answered in {seconds} s.'**
  String aiTestOk(String model, String seconds);

  /// Result of a failed connection test; the reason follows.
  ///
  /// In en, this message translates to:
  /// **'It doesn\'t work.'**
  String get aiTestFailed;

  /// Why the connection test failed.
  ///
  /// In en, this message translates to:
  /// **'No AI model is set up on the server.'**
  String get aiTestProblemNotConfigured;

  /// Why the connection test failed.
  ///
  /// In en, this message translates to:
  /// **'The models are busy or out of free requests. Try again in a few minutes.'**
  String get aiTestProblemBusy;

  /// Why the connection test failed.
  ///
  /// In en, this message translates to:
  /// **'The AI service refused the request: the key on the server may be wrong or expired.'**
  String get aiTestProblemRejected;

  /// Why the connection test failed.
  ///
  /// In en, this message translates to:
  /// **'A model answered but didn\'t see the picture.'**
  String get aiTestProblemWrongAnswer;

  /// Card on the Passport tab that starts a scan.
  ///
  /// In en, this message translates to:
  /// **'Scan passport pages'**
  String get scanCardTitle;

  /// Text of the scan card.
  ///
  /// In en, this message translates to:
  /// **'AI reads vaccinations, treatments, microchips and passport details from photos. You check everything before it\'s saved.'**
  String get scanCardBody;

  /// Button on the scan card.
  ///
  /// In en, this message translates to:
  /// **'Scan pages'**
  String get scanCardButton;

  /// Tooltip of the scan button on the Health tab.
  ///
  /// In en, this message translates to:
  /// **'Scan from passport'**
  String get scanFromPassport;

  /// Card on the Passport tab: a scan is ready to check.
  ///
  /// In en, this message translates to:
  /// **'Continue checking the scan from {date}'**
  String scanResumeReady(String date);

  /// Card on the Passport tab: a scan is still being read.
  ///
  /// In en, this message translates to:
  /// **'Scan from {date}'**
  String scanResumeOpen(String date);

  /// Scan status.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be read'**
  String get scanStatusQueued;

  /// Scan status.
  ///
  /// In en, this message translates to:
  /// **'Reading the pages…'**
  String get scanStatusProcessing;

  /// Scan status.
  ///
  /// In en, this message translates to:
  /// **'Ready to check'**
  String get scanStatusReady;

  /// Scan status: the user saved it.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get scanStatusApplied;

  /// Scan status.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t be read'**
  String get scanStatusFailed;

  /// Scan status: the user threw the draft away.
  ///
  /// In en, this message translates to:
  /// **'Discarded'**
  String get scanStatusDiscarded;

  /// Title of the scan screen.
  ///
  /// In en, this message translates to:
  /// **'Scan passport pages'**
  String get scanTitlePassport;

  /// Title of the scan screen.
  ///
  /// In en, this message translates to:
  /// **'Scan a vet document'**
  String get scanTitleDocument;

  /// Label above the choice of passport or vet document.
  ///
  /// In en, this message translates to:
  /// **'What are you scanning?'**
  String get scanSourceLabel;

  /// Choice: pages of the pet passport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get scanSourcePassport;

  /// Choice: a certificate, invoice or another paper from the vet.
  ///
  /// In en, this message translates to:
  /// **'Vet document'**
  String get scanSourceDocument;

  /// What to photograph.
  ///
  /// In en, this message translates to:
  /// **'Photograph the pages with vaccinations, treatments, the microchip and the passport details. Up to {max} pages at a time.'**
  String scanStartPassportBody(int max);

  /// What to photograph.
  ///
  /// In en, this message translates to:
  /// **'A vaccination certificate, an invoice or another paper from the vet. Up to {max} pages at a time.'**
  String scanStartDocumentBody(int max);

  /// Note on the scan screen.
  ///
  /// In en, this message translates to:
  /// **'AI only prepares a draft: you check every entry and decide what to save.'**
  String get scanStartDraftNote;

  /// Opens the document scanner.
  ///
  /// In en, this message translates to:
  /// **'Scan with the camera'**
  String get scanWithCamera;

  /// Opens the photo library for pages.
  ///
  /// In en, this message translates to:
  /// **'Choose from photos'**
  String get scanChoosePhotos;

  /// Snackbar when the document scanner can't run.
  ///
  /// In en, this message translates to:
  /// **'The scanner isn\'t available on this device. Choose photos of the pages instead.'**
  String get scanScannerUnavailable;

  /// Snackbar: the user picked more pages than a scan takes.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =1{Only the first page is used.} other{Only the first {max} pages are used.}}'**
  String scanTooManyPages(int max);

  /// Shown while the scan starts.
  ///
  /// In en, this message translates to:
  /// **'Sending the pages to AI…'**
  String get scanStarting;

  /// The server refused the uploaded photos.
  ///
  /// In en, this message translates to:
  /// **'Some photos couldn\'t be used. Try again to upload them anew.'**
  String get scanPhotosRefused;

  /// Starts the scan over with new photos.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanStartOver;

  /// How long reading takes.
  ///
  /// In en, this message translates to:
  /// **'Usually 10–60 seconds.'**
  String get scanReadingBody;

  /// Shown when reading takes long.
  ///
  /// In en, this message translates to:
  /// **'Taking longer than usual: the AI models may be busy. You can wait or come back later.'**
  String get scanReadingSlow;

  /// Shown when checking the scan fails for a moment.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Trying again…'**
  String get scanReadingOffline;

  /// Note while the scan is read.
  ///
  /// In en, this message translates to:
  /// **'You can leave this screen: the pages are read on the server, and the scan waits for you on the Passport tab.'**
  String get scanReadingLeave;

  /// Scan failed: all models busy or out of quota.
  ///
  /// In en, this message translates to:
  /// **'The AI models are busy or out of free requests right now. Try again in a few minutes.'**
  String get scanErrorBusy;

  /// Scan failed: no AI model on the server.
  ///
  /// In en, this message translates to:
  /// **'AI isn\'t set up on the server. Connect a model in the server configuration, then scan again. Records can always be added by hand.'**
  String get scanErrorNotConfigured;

  /// Scan failed: the provider refused the request.
  ///
  /// In en, this message translates to:
  /// **'The AI service refused the request. The API key on the server may be wrong or expired.'**
  String get scanErrorRejected;

  /// Scan failed: the photos were deleted.
  ///
  /// In en, this message translates to:
  /// **'The photos of this scan are gone. Scan the pages again.'**
  String get scanErrorPhotosMissing;

  /// Scan failed for another reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while reading the pages. Try again.'**
  String get scanErrorUnexpected;

  /// Closes the scan screen.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get scanClose;

  /// A discarded scan was opened.
  ///
  /// In en, this message translates to:
  /// **'Nothing from this scan was saved.'**
  String get scanDiscardedBody;

  /// The scan was not found.
  ///
  /// In en, this message translates to:
  /// **'This scan no longer exists.'**
  String get scanGone;

  /// Title of the review screen.
  ///
  /// In en, this message translates to:
  /// **'Check the scan'**
  String get scanReviewTitle;

  /// Note at the top of the review.
  ///
  /// In en, this message translates to:
  /// **'AI read these entries from the photos. Check them against the paper, fix what\'s wrong, and untick what you don\'t want to save.'**
  String get scanReviewIntro;

  /// Section title: care records found by the scan.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get scanRecordsTitle;

  /// The draft is empty.
  ///
  /// In en, this message translates to:
  /// **'AI found nothing to save on these photos. You can keep the photos or discard the scan.'**
  String get scanNothingFound;

  /// Switch on the review.
  ///
  /// In en, this message translates to:
  /// **'Keep the photos as passport pages'**
  String get scanKeepPhotosPassport;

  /// Helper under the switch.
  ///
  /// In en, this message translates to:
  /// **'They are added after the pages you have.'**
  String get scanKeepPhotosPassportHelper;

  /// Switch on the review.
  ///
  /// In en, this message translates to:
  /// **'Keep the photos as a document'**
  String get scanKeepPhotosDocument;

  /// Helper under the switch.
  ///
  /// In en, this message translates to:
  /// **'They become a new document on the Documents tab.'**
  String get scanKeepPhotosDocumentHelper;

  /// Main button of the review.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to save} =1{Save 1 selected} other{Save {count} selected}}'**
  String scanSaveSelected(int count);

  /// Main button of the review when no entry is ticked.
  ///
  /// In en, this message translates to:
  /// **'Save the photos only'**
  String get scanSavePhotosOnly;

  /// Button under Save on the review.
  ///
  /// In en, this message translates to:
  /// **'Discard scan'**
  String get scanDiscard;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Discard this scan?'**
  String get scanDiscardTitle;

  /// Confirmation dialog text.
  ///
  /// In en, this message translates to:
  /// **'Nothing from it is saved, and its photos are deleted.'**
  String get scanDiscardBody;

  /// Confirms discarding a scan.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get scanDiscardConfirm;

  /// Snackbar after discarding.
  ///
  /// In en, this message translates to:
  /// **'Scan discarded'**
  String get scanDiscarded;

  /// Screen reader label of an entry's checkbox.
  ///
  /// In en, this message translates to:
  /// **'Save this entry'**
  String get scanSelectEntry;

  /// Badge: the entry is already in the history.
  ///
  /// In en, this message translates to:
  /// **'Already saved'**
  String get scanBadgeAlreadySaved;

  /// Badge: the entry repeats one on another photo.
  ///
  /// In en, this message translates to:
  /// **'Same as another entry'**
  String get scanBadgeRepeated;

  /// Badge: scanned passport details differ from the saved ones.
  ///
  /// In en, this message translates to:
  /// **'Differs from what\'s saved'**
  String get scanBadgeDiffers;

  /// A value the AI couldn't read.
  ///
  /// In en, this message translates to:
  /// **'Not read'**
  String get scanNotRead;

  /// Button: enter a date the AI couldn't read.
  ///
  /// In en, this message translates to:
  /// **'Enter the date'**
  String get scanEnterDate;

  /// Why an entry can't be ticked.
  ///
  /// In en, this message translates to:
  /// **'Enter the date to save this entry.'**
  String get scanNeedsDate;

  /// Why a microchip can't be ticked.
  ///
  /// In en, this message translates to:
  /// **'Enter the number to save this entry.'**
  String get scanNeedsCode;

  /// The passport details are all empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing was read here.'**
  String get scanNothingToFill;

  /// Validation of a scanned date.
  ///
  /// In en, this message translates to:
  /// **'A date in the future can\'t be saved'**
  String get scanDateInFuture;

  /// Warning on a value the AI couldn't read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t be read. Enter it from the paper.'**
  String get scanIssueUnreadable;

  /// Warning on a date like 03/04/2025.
  ///
  /// In en, this message translates to:
  /// **'Day and month could be swapped. Check against the paper.'**
  String get scanIssueAmbiguous;

  /// Button that swaps day and month of a doubtful date.
  ///
  /// In en, this message translates to:
  /// **'Change to {date}'**
  String scanSwapTo(DateTime date);

  /// Warning on a scanned date.
  ///
  /// In en, this message translates to:
  /// **'This date is in the future. Check it.'**
  String get scanIssueInFuture;

  /// Warning on a scanned validity.
  ///
  /// In en, this message translates to:
  /// **'“Valid until” isn\'t after the vaccination date. Check it.'**
  String get scanIssueEndsBeforeStart;

  /// Warning on a scanned number or code.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look right. Check it against the paper.'**
  String get scanIssueInvalidFormat;

  /// Explains the Already saved badge of a record.
  ///
  /// In en, this message translates to:
  /// **'The same entry is already in the history.'**
  String get scanIssueAlreadySaved;

  /// Explains the Already saved badge of a microchip.
  ///
  /// In en, this message translates to:
  /// **'The pet already has this number.'**
  String get scanIssueAlreadySavedCode;

  /// Explains the Same as another entry badge.
  ///
  /// In en, this message translates to:
  /// **'The same entry is on another photo.'**
  String get scanIssueRepeated;

  /// Warning of a kind this app doesn't know.
  ///
  /// In en, this message translates to:
  /// **'Check this value.'**
  String get scanIssueOther;

  /// The passport value already saved, under a scanned one that differs.
  ///
  /// In en, this message translates to:
  /// **'Saved: {value}'**
  String scanSavedValue(String value);

  /// Opens the photo an entry was read from.
  ///
  /// In en, this message translates to:
  /// **'Read on page {number}'**
  String scanReadOnPage(int number);

  /// The text as on the page, in quotes.
  ///
  /// In en, this message translates to:
  /// **'“{text}”'**
  String scanEvidence(String text);

  /// Switch: the record counts as Done of this plan.
  ///
  /// In en, this message translates to:
  /// **'Mark as done in plan “{title}”'**
  String scanPlanDone(String title);

  /// Switch: link the record to a plan.
  ///
  /// In en, this message translates to:
  /// **'Mark as done in a plan'**
  String get scanPlanLink;

  /// Helper under the plan switch.
  ///
  /// In en, this message translates to:
  /// **'The plan moves on only if this entry is newer than its last “Done”.'**
  String get scanPlanHint;

  /// Button under the plan switch.
  ///
  /// In en, this message translates to:
  /// **'Choose another plan'**
  String get scanPlanChange;

  /// Title of the plan picker.
  ///
  /// In en, this message translates to:
  /// **'Mark as done in which plan?'**
  String get scanPlanPickTitle;

  /// Plan picker option: don't link the record.
  ///
  /// In en, this message translates to:
  /// **'No plan'**
  String get scanPlanNone;

  /// Under an entry with problems after Save.
  ///
  /// In en, this message translates to:
  /// **'Fix this entry or untick it.'**
  String get scanEntryFix;

  /// Title of the record editor.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get scanEditRecordTitle;

  /// Title of the identifier editor.
  ///
  /// In en, this message translates to:
  /// **'Edit microchip or tattoo'**
  String get scanEditIdentifierTitle;

  /// Title of the passport editor.
  ///
  /// In en, this message translates to:
  /// **'Edit passport details'**
  String get scanEditPassportTitle;

  /// Button that closes an editor and keeps the changes.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get scanEditDone;

  /// Note in the passport editor.
  ///
  /// In en, this message translates to:
  /// **'An empty field keeps what is saved; a value you change here replaces it.'**
  String get scanPassportKeeps;

  /// Part of the snackbar after saving a scan.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved 1 record} other{Saved {count} records}}'**
  String scanSavedRecords(int count);

  /// Part of the snackbar after saving a scan.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 plan updated} other{{count} plans updated}}'**
  String scanSavedPlans(int count);

  /// Part of the snackbar after saving a scan.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 microchip or tattoo added} other{{count} microchips and tattoos added}}'**
  String scanSavedIdentifiers(int count);

  /// Part of the snackbar after saving a scan (not the first part, so lower case).
  ///
  /// In en, this message translates to:
  /// **'passport details updated'**
  String get scanSavedPassport;

  /// Part of the snackbar after saving a scan.
  ///
  /// In en, this message translates to:
  /// **'photos added to the passport pages'**
  String get scanSavedPhotosPassport;

  /// Part of the snackbar after saving a scan.
  ///
  /// In en, this message translates to:
  /// **'photos saved as a document'**
  String get scanSavedPhotosDocument;

  /// Snackbar after saving a scan with nothing in it.
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved'**
  String get scanSavedNothing;

  /// Title of the passport card on the scan review: ticked, the details fill in the passport header.
  ///
  /// In en, this message translates to:
  /// **'Add to the passport details'**
  String get scanPassportFillIn;

  /// Note in brackets after the save summary when the answer was lost but the scan had been saved.
  ///
  /// In en, this message translates to:
  /// **'saved before the connection dropped'**
  String get scanSavedBeforeDrop;

  /// Note in brackets after the save summary when Discard finds the scan saved.
  ///
  /// In en, this message translates to:
  /// **'this scan was saved already'**
  String get scanSavedNoDiscard;

  /// The save's answer was lost and the scan couldn't be checked.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t tell whether it was saved. Check your connection and save again: nothing is saved twice.'**
  String get scanSaveUnconfirmed;

  /// Validation: the server keeps care records from 1990 on.
  ///
  /// In en, this message translates to:
  /// **'Use a date in 1990 or later'**
  String get scanDateTooEarly;

  /// A ticked microchip would pass the pet's limit.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =1{A pet can have 1 microchip or tattoo.} other{A pet can have up to {max} microchips and tattoos.}}'**
  String scanTooManyIdentifiers(int max);

  /// Part of the save summary: microchip or tattoo numbers the pet had already, so not added.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 number was already on the pet} other{{count} numbers were already on the pet}}'**
  String scanSkippedIdentifiers(int count);

  /// Part of the save summary; fields like: number, date of issue.
  ///
  /// In en, this message translates to:
  /// **'passport details updated: {fields}'**
  String scanSavedPassportFields(String fields);

  /// Passport field in the save summary (lower case).
  ///
  /// In en, this message translates to:
  /// **'number'**
  String get scanPassportFieldNumber;

  /// Passport field in the save summary (lower case).
  ///
  /// In en, this message translates to:
  /// **'country'**
  String get scanPassportFieldCountry;

  /// Passport field in the save summary (lower case).
  ///
  /// In en, this message translates to:
  /// **'date of issue'**
  String get scanPassportFieldIssuedOn;

  /// Switch under a scanned passport value that differs from the saved one; off by default.
  ///
  /// In en, this message translates to:
  /// **'Replace the saved value'**
  String get scanPassportReplace;

  /// Under a scanned passport value equal to the saved one.
  ///
  /// In en, this message translates to:
  /// **'Already in the passport details'**
  String get scanPassportSame;

  /// Why the passport card can't be ticked.
  ///
  /// In en, this message translates to:
  /// **'Nothing new: the passport details already say this.'**
  String get scanPassportNothingNew;

  /// Removes a failed scan from the Passport tab.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get scanDismiss;

  /// AI status on the More screen when it couldn't be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check'**
  String get aiCheckFailed;

  /// Dialog when leaving the review with changes.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get scanLeaveTitle;

  /// Dialog text when leaving the review with changes.
  ///
  /// In en, this message translates to:
  /// **'Your changes here will be lost. The scan stays on the Passport tab to check later.'**
  String get scanLeaveBody;

  /// Leaves the review without saving.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get scanLeaveConfirm;

  /// Title of a scanned rabies vaccination whose page names none.
  ///
  /// In en, this message translates to:
  /// **'Rabies vaccination'**
  String get scanTitleRabiesVaccination;

  /// Hint on a ticked passport card that would change nothing yet.
  ///
  /// In en, this message translates to:
  /// **'Turn on “Replace the saved value” for what should change.'**
  String get scanPassportTurnOnReplace;

  /// Tab of the pet's page with its feeding schedules.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get petTabFeeding;

  /// Title of the Feeding tab's list.
  ///
  /// In en, this message translates to:
  /// **'Feeding schedule'**
  String get feedingTitle;

  /// Button that adds a feeding schedule.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get feedingAdd;

  /// Empty state of the Feeding tab.
  ///
  /// In en, this message translates to:
  /// **'Add feeding times: at each one a reminder comes, and Today shows a \"Fed\" button.'**
  String get feedingEmpty;

  /// Days of a feeding schedule when it is every day.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get feedingEveryDay;

  /// A feeding schedule that is turned off.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get feedingPaused;

  /// Title of the form that adds a feeding schedule.
  ///
  /// In en, this message translates to:
  /// **'New feeding schedule'**
  String get feedingAddTitle;

  /// Title of the form that edits a feeding schedule.
  ///
  /// In en, this message translates to:
  /// **'Edit feeding'**
  String get feedingEditTitle;

  /// Tooltip of the button that deletes a feeding schedule.
  ///
  /// In en, this message translates to:
  /// **'Delete schedule'**
  String get feedingDelete;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete this feeding schedule?'**
  String get feedingDeleteTitle;

  /// Confirmation text for deleting a feeding schedule.
  ///
  /// In en, this message translates to:
  /// **'Its reminders stop, and its \"fed\" marks are deleted too.'**
  String get feedingDeleteBody;

  /// Message when the schedule no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This feeding schedule was deleted on another device.'**
  String get feedingGone;

  /// Shown instead of the form for a schedule with values this app doesn't know.
  ///
  /// In en, this message translates to:
  /// **'This schedule was made in a newer version of the app. Update the app to change it.'**
  String get feedingReadOnly;

  /// Label of the feeding times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get feedingTimesLabel;

  /// Chip that adds a feeding time.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get feedingTimeAdd;

  /// Tooltip of a time chip's delete button.
  ///
  /// In en, this message translates to:
  /// **'Remove this time'**
  String get feedingTimeRemove;

  /// Validation: no feeding time.
  ///
  /// In en, this message translates to:
  /// **'Add at least one time'**
  String get feedingTimesRequired;

  /// Validation: too many feeding times.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, other{Use {max} times or fewer}}'**
  String feedingTimesTooMany(int max);

  /// Label of the days of the week a schedule runs on.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get feedingDaysLabel;

  /// Validation: no day chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day'**
  String get feedingDaysRequired;

  /// Label of what is given.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get feedingFoodLabel;

  /// Hint of the food field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Royal Canin Sterilised'**
  String get feedingFoodHint;

  /// Label of the amount and its unit.
  ///
  /// In en, this message translates to:
  /// **'Portion'**
  String get feedingPortionLabel;

  /// Hint of the amount field.
  ///
  /// In en, this message translates to:
  /// **'40'**
  String get feedingAmountHint;

  /// Validation of the amount.
  ///
  /// In en, this message translates to:
  /// **'Use a number above 0, up to 10 000'**
  String get feedingAmountInvalid;

  /// Switch that pauses a feeding schedule.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get feedingActiveLabel;

  /// Helper of the active switch.
  ///
  /// In en, this message translates to:
  /// **'Paused schedules don\'t remind and don\'t show on Today.'**
  String get feedingActiveHelper;

  /// Note under the feeding form.
  ///
  /// In en, this message translates to:
  /// **'At each time a reminder comes to the phones of the household. Turn feeding reminders off in More → Notifications.'**
  String get feedingRemindersNote;

  /// A portion in grams.
  ///
  /// In en, this message translates to:
  /// **'{amount} g'**
  String portionGrams(String amount);

  /// A portion in millilitres.
  ///
  /// In en, this message translates to:
  /// **'{amount} ml'**
  String portionMilliliters(String amount);

  /// A portion in pieces.
  ///
  /// In en, this message translates to:
  /// **'{amount} pcs'**
  String portionPieces(String amount);

  /// Unit button: grams.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get portionUnitGrams;

  /// Unit button: millilitres.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get portionUnitMilliliters;

  /// Unit button: pieces.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get portionUnitPieces;

  /// Title of today's feedings on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get todayFeedingTitle;

  /// Button that marks one pet's feeding done.
  ///
  /// In en, this message translates to:
  /// **'Fed'**
  String get feedingFed;

  /// Button that marks every pet of one feeding time.
  ///
  /// In en, this message translates to:
  /// **'All fed'**
  String get feedingAll;

  /// Someone else marked the feeding first.
  ///
  /// In en, this message translates to:
  /// **'Already marked: {name}, {time}'**
  String feedingAlreadyMarked(String name, String time);

  /// Who marked the feeding and when.
  ///
  /// In en, this message translates to:
  /// **'{name}, {time}'**
  String feedingFedBy(String name, String time);

  /// Who marked a feeding, when their name is unknown.
  ///
  /// In en, this message translates to:
  /// **'someone else'**
  String get feedingSomeoneElse;

  /// A feeding skipped on purpose.
  ///
  /// In en, this message translates to:
  /// **'Skipped, {time}'**
  String feedingSkippedAt(String time);

  /// Asks before taking a feeding mark back.
  ///
  /// In en, this message translates to:
  /// **'{pet}: take the mark back?'**
  String feedingUndoTitle(String pet);

  /// Text of the take-back dialog.
  ///
  /// In en, this message translates to:
  /// **'The feeding will show as not done, and its reminder may come again.'**
  String get feedingUndoBody;

  /// Button that takes a feeding mark back.
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get feedingUndo;

  /// Title of the planned visits on Today.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get todayVisitsTitle;

  /// Outlined button beside the Visits title on Today: opens every visit.
  ///
  /// In en, this message translates to:
  /// **'All visits'**
  String get todayVisitsAll;

  /// Today without planned visits.
  ///
  /// In en, this message translates to:
  /// **'No visits planned.'**
  String get todayVisitsEmpty;

  /// Status tag of a past visit not marked yet, under when it was.
  ///
  /// In en, this message translates to:
  /// **'Mark how it went'**
  String get todayVisitMarkHowItWent;

  /// Title of the list of visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitsTitle;

  /// Group of planned visits.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get visitsPlanned;

  /// Group of past and cancelled visits.
  ///
  /// In en, this message translates to:
  /// **'Past and cancelled'**
  String get visitsPast;

  /// Empty list of visits.
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get visitsEmptyTitle;

  /// Empty list of visits, text.
  ///
  /// In en, this message translates to:
  /// **'Add a visit to the vet or the groomer: reminders come a day and two hours before.'**
  String get visitsEmptyBody;

  /// Button that adds a visit.
  ///
  /// In en, this message translates to:
  /// **'Add a visit'**
  String get visitAdd;

  /// Title of the form that adds a visit.
  ///
  /// In en, this message translates to:
  /// **'New visit'**
  String get visitAddTitle;

  /// Title of the form that edits a visit.
  ///
  /// In en, this message translates to:
  /// **'Edit visit'**
  String get visitEditTitle;

  /// Shown instead of the form for a visit this app can't edit.
  ///
  /// In en, this message translates to:
  /// **'This visit was made in a newer version of the app. Update the app to change it.'**
  String get visitReadOnly;

  /// Message when the visit no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This visit was deleted on another device.'**
  String get visitGone;

  /// Label of the kind of visit.
  ///
  /// In en, this message translates to:
  /// **'Kind of visit'**
  String get visitTypeLabel;

  /// Kind of visit: the vet.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get visitTypeVet;

  /// Kind of visit: the groomer.
  ///
  /// In en, this message translates to:
  /// **'Groomer'**
  String get visitTypeGrooming;

  /// Kind of visit: training.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get visitTypeTraining;

  /// Kind of visit: other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get visitTypeOther;

  /// Label of the visit's title.
  ///
  /// In en, this message translates to:
  /// **'What for'**
  String get visitTitleLabel;

  /// Hint of the visit's title.
  ///
  /// In en, this message translates to:
  /// **'e.g. Rabies vaccination'**
  String get visitTitleHint;

  /// Label of the visit's date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get visitDateLabel;

  /// Label of the visit's time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get visitTimeLabel;

  /// Validation: no time.
  ///
  /// In en, this message translates to:
  /// **'Choose the time'**
  String get visitTimeRequired;

  /// Label of the pets of a visit.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get visitPetsLabel;

  /// Validation: no pet chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one pet'**
  String get visitPetsRequired;

  /// Label of the clinic or address.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get visitLocationLabel;

  /// Hint of the location field.
  ///
  /// In en, this message translates to:
  /// **'Clinic or address'**
  String get visitLocationHint;

  /// Label of the visit's reminders.
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get visitRemindersLabel;

  /// A visit without reminders.
  ///
  /// In en, this message translates to:
  /// **'No reminders'**
  String get visitRemindersNone;

  /// Reminder at the start of the visit.
  ///
  /// In en, this message translates to:
  /// **'When it starts'**
  String get visitRemindAtStart;

  /// Reminder a week before the visit.
  ///
  /// In en, this message translates to:
  /// **'A week before'**
  String get visitRemindWeek;

  /// Reminder a number of weeks before.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week before} other{{count} weeks before}}'**
  String visitRemindWeeks(int count);

  /// Reminder a day before the visit.
  ///
  /// In en, this message translates to:
  /// **'A day before'**
  String get visitRemindDay;

  /// Reminder a number of days before.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day before} other{{count} days before}}'**
  String visitRemindDays(int count);

  /// Reminder an hour before the visit.
  ///
  /// In en, this message translates to:
  /// **'An hour before'**
  String get visitRemindHour;

  /// Reminder a number of hours before.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour before} other{{count} hours before}}'**
  String visitRemindHours(int count);

  /// Reminder a number of minutes before.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A minute before} other{{count} minutes before}}'**
  String visitRemindMinutes(int count);

  /// When a visit is: today.
  ///
  /// In en, this message translates to:
  /// **'Today at {time}'**
  String visitToday(String time);

  /// When a visit is: tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow at {time}'**
  String visitTomorrow(String time);

  /// When a visit was: yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday at {time}'**
  String visitYesterday(String time);

  /// When a visit is, on another day.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String visitOnDate(DateTime date, String time);

  /// Status of a visit.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get visitStatusPlanned;

  /// Status of a visit.
  ///
  /// In en, this message translates to:
  /// **'Took place'**
  String get visitStatusDone;

  /// Status of a visit.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get visitStatusCancelled;

  /// Action that cancels a visit.
  ///
  /// In en, this message translates to:
  /// **'Cancel visit'**
  String get visitCancel;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Cancel this visit?'**
  String get visitCancelTitle;

  /// Confirmation text for cancelling a visit.
  ///
  /// In en, this message translates to:
  /// **'Its reminders stop. You can plan it again later.'**
  String get visitCancelBody;

  /// Note on a cancelled visit.
  ///
  /// In en, this message translates to:
  /// **'This visit is cancelled.'**
  String get visitCancelledNote;

  /// Action that plans a cancelled visit again.
  ///
  /// In en, this message translates to:
  /// **'Plan again'**
  String get visitPlanAgain;

  /// Action that deletes a visit.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get visitDelete;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete this visit?'**
  String get visitDeleteTitle;

  /// Confirmation text for deleting a visit.
  ///
  /// In en, this message translates to:
  /// **'Records made from it stay in the pets\' history.'**
  String get visitDeleteBody;

  /// Button that marks a visit as done.
  ///
  /// In en, this message translates to:
  /// **'The visit took place'**
  String get visitDone;

  /// Title of the done sheet.
  ///
  /// In en, this message translates to:
  /// **'How did the visit go?'**
  String get visitDoneTitle;

  /// Switch that makes care records from the visit.
  ///
  /// In en, this message translates to:
  /// **'Add to the care history'**
  String get visitDoneWriteRecord;

  /// Helper of the record switch.
  ///
  /// In en, this message translates to:
  /// **'Each pet of the visit gets a record of this kind.'**
  String get visitDoneWriteRecordHelper;

  /// Checkbox: the visit counts as Done for this plan.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{plan}\" done'**
  String visitDonePlan(String plan);

  /// Label of the notes about the visit.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get visitDoneNotesLabel;

  /// Hint of the notes about the visit.
  ///
  /// In en, this message translates to:
  /// **'What the vet said'**
  String get visitDoneNotesHint;

  /// After marking a visit done.
  ///
  /// In en, this message translates to:
  /// **'Saved: the visit took place.'**
  String get visitDoneSaved;

  /// After marking a visit done, with plans moved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved. One plan moved to its next date.} other{Saved. {count} plans moved to their next dates.}}'**
  String visitDoneSavedPlans(int count);

  /// Section of a visit that took place.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get visitResultTitle;

  /// A visit that took place without records.
  ///
  /// In en, this message translates to:
  /// **'No records were made.'**
  String get visitNoRecords;

  /// Link to a pet's history.
  ///
  /// In en, this message translates to:
  /// **'Records in the care history'**
  String get visitRecordsOfPet;

  /// Title of the notification settings.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Subtitle of the Notifications entry in More.
  ///
  /// In en, this message translates to:
  /// **'Reminders, test, history'**
  String get moreNotificationsHelper;

  /// Android notification channel for pushes of no other kind.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get notificationsChannelGeneral;

  /// Section of the kinds of reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notificationsKinds;

  /// Kind of reminder; also the name of its Android notification channel.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get notificationsKindFeeding;

  /// Helper of the feeding kind.
  ///
  /// In en, this message translates to:
  /// **'At each feeding time'**
  String get notificationsKindFeedingHelper;

  /// Kind of reminder; also the name of its Android notification channel.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations and treatments'**
  String get notificationsKindCare;

  /// Helper of the care kind.
  ///
  /// In en, this message translates to:
  /// **'7 days, 1 day and on the day, at 10:00; again while overdue'**
  String get notificationsKindCareHelper;

  /// Kind of reminder; also the name of its Android notification channel.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get notificationsKindVisits;

  /// Helper of the visits kind.
  ///
  /// In en, this message translates to:
  /// **'As set for each visit'**
  String get notificationsKindVisitsHelper;

  /// Push status: all good.
  ///
  /// In en, this message translates to:
  /// **'Reminders come to this phone.'**
  String get notificationsReady;

  /// Push status on iPhone.
  ///
  /// In en, this message translates to:
  /// **'On iPhone, reminders will come later: they need a paid Apple developer account. Until then, everything due is on the Today screen.'**
  String get notificationsIphoneLater;

  /// Push status: permission denied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Collarbell in the phone\'s settings.'**
  String get notificationsDenied;

  /// Notification settings: the app hasn't asked for the permission yet.
  ///
  /// In en, this message translates to:
  /// **'Notifications aren\'t allowed yet. Collarbell asks when you add the first feeding, visit or plan, or allow them now.'**
  String get notificationsNotAsked;

  /// Asked after the first feeding, visit or plan is saved.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications?'**
  String get pushAskTitle;

  /// Why the app asks for notifications.
  ///
  /// In en, this message translates to:
  /// **'Then Collarbell can remind you of feeding, vaccinations and visits, even when the app is closed.'**
  String get pushAskBody;

  /// Declines the notification question for now.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get pushAskLater;

  /// Goes on to the system's notification permission.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get pushAskAllow;

  /// On Today and in the feeding form when the user refused notifications, with Open settings.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off: reminders won\'t come.'**
  String get pushOffNotice;

  /// Button that opens the system notification settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get notificationsOpenSettings;

  /// Push status: no token.
  ///
  /// In en, this message translates to:
  /// **'The phone has no address for notifications yet: it needs Google Play services and the internet.'**
  String get notificationsNoToken;

  /// Push status: registering failed.
  ///
  /// In en, this message translates to:
  /// **'The server couldn\'t be reached to turn on reminders for this phone.'**
  String get notificationsRegisterFailed;

  /// Push status: server not configured.
  ///
  /// In en, this message translates to:
  /// **'The server can\'t send notifications yet: it has no Firebase key.'**
  String get notificationsServerNotReady;

  /// Button that sends a test push.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get notificationsTest;

  /// Test push sent.
  ///
  /// In en, this message translates to:
  /// **'Sent. It should arrive in a few seconds.'**
  String get notificationsTestSent;

  /// Test push: no phones.
  ///
  /// In en, this message translates to:
  /// **'No phone is registered for notifications yet.'**
  String get notificationsTestNoDevices;

  /// Test push failed.
  ///
  /// In en, this message translates to:
  /// **'Firebase didn\'t deliver it. Try again later.'**
  String get notificationsTestFailed;

  /// Section of the reminders of the next 7 days.
  ///
  /// In en, this message translates to:
  /// **'Coming reminders'**
  String get notificationsUpcoming;

  /// No coming reminders.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the next 7 days.'**
  String get notificationsUpcomingEmpty;

  /// Section of the reminders of the last 7 days.
  ///
  /// In en, this message translates to:
  /// **'Recent reminders'**
  String get notificationsRecent;

  /// No recent reminders.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the last 7 days.'**
  String get notificationsRecentEmpty;

  /// When a reminder is: today.
  ///
  /// In en, this message translates to:
  /// **'Today at {time}'**
  String notificationsWhenToday(String time);

  /// When a reminder is: tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, {time}'**
  String notificationsWhenTomorrow(String time);

  /// When a reminder was: yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String notificationsWhenYesterday(String time);

  /// What happened to a reminder.
  ///
  /// In en, this message translates to:
  /// **'sent'**
  String get reminderSent;

  /// What happened to a reminder.
  ///
  /// In en, this message translates to:
  /// **'too late: the server was off'**
  String get reminderExpired;

  /// What happened to a reminder.
  ///
  /// In en, this message translates to:
  /// **'Firebase didn\'t deliver it'**
  String get reminderFailed;

  /// What happened to a reminder.
  ///
  /// In en, this message translates to:
  /// **'not sent'**
  String get reminderSkipped;

  /// What happened to a reminder.
  ///
  /// In en, this message translates to:
  /// **'not needed: done already'**
  String get reminderSkippedNotNeeded;

  /// What happened to a reminder.
  ///
  /// In en, this message translates to:
  /// **'no phone to send to'**
  String get reminderSkippedNoPhones;

  /// What happened to a reminder.
  ///
  /// In en, this message translates to:
  /// **'not sent: the server has no Firebase key'**
  String get reminderSkippedServer;

  /// Screen-reader label of a feeding marked fed.
  ///
  /// In en, this message translates to:
  /// **'Fed at {time}'**
  String feedingFedAtSemantics(String time);

  /// Screen-reader hint on a marked feeding.
  ///
  /// In en, this message translates to:
  /// **'Tap to take the mark back'**
  String get feedingUndoHint;

  /// Under the pet's name: who marked the feeding (someone else).
  ///
  /// In en, this message translates to:
  /// **'Marked by {name}'**
  String feedingMarkedBy(String name);

  /// Asks before skipping a feeding on purpose.
  ///
  /// In en, this message translates to:
  /// **'{pet}: skip this feeding?'**
  String feedingSkipTitle(String pet);

  /// Text of the skip dialog.
  ///
  /// In en, this message translates to:
  /// **'The {time} feeding will be marked as skipped, with no reminder.'**
  String feedingSkipBody(String time);

  /// Button that skips a feeding.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get feedingSkip;

  /// Push status on Android when Firebase didn't start.
  ///
  /// In en, this message translates to:
  /// **'Notifications aren\'t available on this phone: Firebase didn\'t start.'**
  String get notificationsUnavailable;

  /// The server refused "The visit took place".
  ///
  /// In en, this message translates to:
  /// **'This visit can\'t be marked: it was cancelled, or it hasn\'t happened yet.'**
  String get visitDoneNotPossible;

  /// Kind of reminder; also the name of its Android notification channel.
  ///
  /// In en, this message translates to:
  /// **'Supplies'**
  String get notificationsKindSupplies;

  /// Helper of the supplies kind.
  ///
  /// In en, this message translates to:
  /// **'When it\'s time to buy, at 10:00'**
  String get notificationsKindSuppliesHelper;

  /// The barcode scanner can't open the camera.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available. Allow camera access in Settings, or type the digits.'**
  String get barcodeCameraUnavailable;

  /// Button: look up typed digits.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get barcodeFind;

  /// Under the scanner's frame.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the barcode on the package'**
  String get barcodeScanHint;

  /// Title of the barcode scanner.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcodeScanTitle;

  /// Tooltip: turns the phone's light on.
  ///
  /// In en, this message translates to:
  /// **'Torch'**
  String get barcodeTorch;

  /// Button: type the barcode's digits by hand.
  ///
  /// In en, this message translates to:
  /// **'Type the digits'**
  String get barcodeType;

  /// Hint of the typed barcode.
  ///
  /// In en, this message translates to:
  /// **'The digits under the barcode'**
  String get barcodeTypeHint;

  /// Helper of the food-from-supplies picker.
  ///
  /// In en, this message translates to:
  /// **'Portions of this feeding count towards the food\'s daily use in supplies'**
  String get feedingSupplyHelper;

  /// Picker of a supply item in the feeding form.
  ///
  /// In en, this message translates to:
  /// **'Food from supplies'**
  String get feedingSupplyLabel;

  /// No supply item linked.
  ///
  /// In en, this message translates to:
  /// **'Not from supplies'**
  String get feedingSupplyNone;

  /// Takes one more photo of the package.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get productScanAddPhoto;

  /// All AI models are busy.
  ///
  /// In en, this message translates to:
  /// **'AI is busy right now. Try again in a minute, or fill it in by hand.'**
  String get productScanBusy;

  /// Opens the item form.
  ///
  /// In en, this message translates to:
  /// **'Fill in by hand'**
  String get productScanByHand;

  /// Taking a photo failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera'**
  String get productScanCameraFailed;

  /// The scanned code.
  ///
  /// In en, this message translates to:
  /// **'Barcode {code}'**
  String productScanCode(String code);

  /// A scanned barcode belongs to an item.
  ///
  /// In en, this message translates to:
  /// **'This product is in your supplies already'**
  String get productScanExisting;

  /// Before sending photos of a package.
  ///
  /// In en, this message translates to:
  /// **'The photos go to Gemini\'s free tier: keep personal data out of them.'**
  String get productScanFreeTier;

  /// While the barcode is looked up.
  ///
  /// In en, this message translates to:
  /// **'Looking the product up…'**
  String get productScanLookingUp;

  /// The server has no AI model.
  ///
  /// In en, this message translates to:
  /// **'AI isn\'t set up: fill in the details by hand.'**
  String get productScanNoAi;

  /// A QR code or other code was scanned.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a product barcode. Scan the barcode on the package.'**
  String get productScanNotProduct;

  /// Opens the existing item.
  ///
  /// In en, this message translates to:
  /// **'Open the item'**
  String get productScanOpenExisting;

  /// A database knows the name only.
  ///
  /// In en, this message translates to:
  /// **'Not everything was found: the package size is missing. Take photos of the package, or fill it in by hand.'**
  String get productScanPartly;

  /// A taken photo of the package.
  ///
  /// In en, this message translates to:
  /// **'Photo {number}'**
  String productScanPhoto(int number);

  /// What to photograph.
  ///
  /// In en, this message translates to:
  /// **'Take photos of the front and of the side with the weight and composition, up to 3.'**
  String get productScanPhotosHint;

  /// Sends the photos to AI.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get productScanRead;

  /// While AI reads the photos.
  ///
  /// In en, this message translates to:
  /// **'Reading the package… Usually a few seconds, sometimes a minute or two.'**
  String get productScanReading;

  /// The provider refused.
  ///
  /// In en, this message translates to:
  /// **'AI refused to read the photos. Fill in the details by hand.'**
  String get productScanRejected;

  /// Starts the photos.
  ///
  /// In en, this message translates to:
  /// **'Take photos of the package'**
  String get productScanTakePhotos;

  /// Title of the scan screen.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get productScanTitle;

  /// Nothing found for a barcode.
  ///
  /// In en, this message translates to:
  /// **'No product with this barcode was found.'**
  String get productScanUnknown;

  /// Section of the supplies list.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get suppliesInStock;

  /// Section of inactive items.
  ///
  /// In en, this message translates to:
  /// **'No longer bought'**
  String get suppliesNotBought;

  /// Section: buy within a week.
  ///
  /// In en, this message translates to:
  /// **'Running out soon'**
  String get suppliesSoon;

  /// Section: buy now.
  ///
  /// In en, this message translates to:
  /// **'To buy'**
  String get suppliesToBuy;

  /// Helper of the active switch.
  ///
  /// In en, this message translates to:
  /// **'Turn off when you no longer buy it: no reminders, the history stays'**
  String get supplyActiveHelper;

  /// Switch: the item is still bought.
  ///
  /// In en, this message translates to:
  /// **'Still buying'**
  String get supplyActiveLabel;

  /// Adds an item.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get supplyAdd;

  /// Way to add an item.
  ///
  /// In en, this message translates to:
  /// **'Scan the barcode'**
  String get supplyAddByBarcode;

  /// Helper of scanning.
  ///
  /// In en, this message translates to:
  /// **'We look the product up'**
  String get supplyAddByBarcodeHelper;

  /// Way to add an item.
  ///
  /// In en, this message translates to:
  /// **'Fill in by hand'**
  String get supplyAddByHand;

  /// Way to add an item.
  ///
  /// In en, this message translates to:
  /// **'Take photos of the package'**
  String get supplyAddByPhoto;

  /// Helper of photos.
  ///
  /// In en, this message translates to:
  /// **'AI reads the name, weight and energy'**
  String get supplyAddByPhotoHelper;

  /// Title of the item form.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get supplyAddTitle;

  /// Barcode field error.
  ///
  /// In en, this message translates to:
  /// **'Check the barcode\'s digits'**
  String get supplyBarcodeInvalid;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get supplyBarcodeLabel;

  /// Saving failed: duplicate barcode.
  ///
  /// In en, this message translates to:
  /// **'An item with this barcode is in supplies already'**
  String get supplyBarcodeTaken;

  /// Button: marks a purchase.
  ///
  /// In en, this message translates to:
  /// **'Bought'**
  String get supplyBought;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get supplyBrandLabel;

  /// When to buy, and the delivery time.
  ///
  /// In en, this message translates to:
  /// **'Buy by {date} · delivery {delivery}'**
  String supplyBuyBy(String date, String delivery);

  /// Status tag of an item that runs out soon; how long it lasts follows it.
  ///
  /// In en, this message translates to:
  /// **'Time to buy'**
  String get supplyTimeToBuy;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Dry food'**
  String get supplyCategoryDryFood;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get supplyCategoryLabel;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Litter'**
  String get supplyCategoryLitter;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get supplyCategoryMedication;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get supplyCategoryOther;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get supplyCategoryTreats;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Wet food'**
  String get supplyCategoryWetFood;

  /// Button: correct the stock.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get supplyCount;

  /// Saves a count.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get supplyCountSave;

  /// Snack bar.
  ///
  /// In en, this message translates to:
  /// **'Stock saved'**
  String get supplyCountSaved;

  /// Title of the count sheet.
  ///
  /// In en, this message translates to:
  /// **'What\'s left: {name}'**
  String supplyCountTitle(String name);

  /// Sum of a count.
  ///
  /// In en, this message translates to:
  /// **'In all ≈ {amount}'**
  String supplyCountTotal(String amount);

  /// Menu item.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get supplyDelete;

  /// Delete dialog.
  ///
  /// In en, this message translates to:
  /// **'Its purchases and stock are deleted. Feedings keep the food\'s name.'**
  String get supplyDeleteBody;

  /// Delete dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String supplyDeleteTitle(String name);

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get supplyDetailsTitle;

  /// Doses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} dose} other{{count} doses}}'**
  String supplyDoses(int count);

  /// A fractional number of doses.
  ///
  /// In en, this message translates to:
  /// **'{amount} doses'**
  String supplyDosesFraction(String amount);

  /// Title of the item form.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get supplyEditTitle;

  /// Forecast.
  ///
  /// In en, this message translates to:
  /// **'Enough for {lasts}'**
  String supplyEnoughFor(String lasts);

  /// Who entered it.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get supplyEntryByMe;

  /// A count in the history.
  ///
  /// In en, this message translates to:
  /// **'Left: {amount}'**
  String supplyEntryCount(String amount);

  /// A purchase in the history.
  ///
  /// In en, this message translates to:
  /// **'Bought +{amount}'**
  String supplyEntryPurchase(String amount);

  /// Takes an entry back.
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get supplyEntryUndo;

  /// Undo dialog.
  ///
  /// In en, this message translates to:
  /// **'The entry is deleted and the forecast recalculated.'**
  String get supplyEntryUndoBody;

  /// Undo dialog title.
  ///
  /// In en, this message translates to:
  /// **'Take this entry back?'**
  String get supplyEntryUndoTitle;

  /// A feeding that doesn't count.
  ///
  /// In en, this message translates to:
  /// **'No portion, or in another unit: not counted'**
  String get supplyFeedingNotCounted;

  /// A feeding's use.
  ///
  /// In en, this message translates to:
  /// **'{portion} × {times} a day'**
  String supplyFeedingPortion(String portion, String times);

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Feedings with this food'**
  String get supplyFeedingsTitle;

  /// Prefill notice.
  ///
  /// In en, this message translates to:
  /// **'This product was saved before. Check the details.'**
  String get supplyFromCatalog;

  /// Prefill notice with attribution.
  ///
  /// In en, this message translates to:
  /// **'Details from Open Pet Food Facts (ODbL licence). Check them.'**
  String get supplyFromOpenPetFoodFacts;

  /// Prefill notice.
  ///
  /// In en, this message translates to:
  /// **'Read from photos of the package. Check the details.'**
  String get supplyFromPhotos;

  /// Prefill notice.
  ///
  /// In en, this message translates to:
  /// **'The name comes from UPCitemdb. Add the package size.'**
  String get supplyFromUpcItemDb;

  /// Snack bar.
  ///
  /// In en, this message translates to:
  /// **'This item is gone'**
  String get supplyGone;

  /// Empty history.
  ///
  /// In en, this message translates to:
  /// **'No purchases or counts yet'**
  String get supplyHistoryEmpty;

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Purchases and counts'**
  String get supplyHistoryTitle;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'No longer bought'**
  String get supplyInactive;

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'You no longer buy this item: there are no reminders about it.'**
  String get supplyInactiveNote;

  /// Energy.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal/kg'**
  String supplyKcal(int kcal);

  /// Field helper.
  ///
  /// In en, this message translates to:
  /// **'From the package: kcal per kg (kcal per 100 g × 10)'**
  String get supplyKcalHelper;

  /// Field hint.
  ///
  /// In en, this message translates to:
  /// **'3900'**
  String get supplyKcalHint;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'A number from 1 to 10,000'**
  String get supplyKcalInvalid;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Energy, kcal/kg'**
  String get supplyKcalLabel;

  /// Amount.
  ///
  /// In en, this message translates to:
  /// **'{amount} kg'**
  String supplyKg(String amount);

  /// How long it lasts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{about {count} day} other{about {count} days}}'**
  String supplyLastsDays(int count);

  /// How long it lasts.
  ///
  /// In en, this message translates to:
  /// **'less than a day'**
  String get supplyLastsLessThanDay;

  /// Delivery time.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String supplyLeadTimeDays(int count);

  /// Field helper.
  ///
  /// In en, this message translates to:
  /// **'The reminder to buy comes this many days before it runs out'**
  String get supplyLeadTimeHelper;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Use 0 to {max} days'**
  String supplyLeadTimeInvalid(int max);

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Days for delivery'**
  String get supplyLeadTimeLabel;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'{amount} left · daily use not set'**
  String supplyLeftNoUsage(String amount);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Fewer'**
  String get supplyLess;

  /// Amount.
  ///
  /// In en, this message translates to:
  /// **'{amount} l'**
  String supplyLiters(String amount);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get supplyMore;

  /// Field hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Royal Canin Sterilised 37'**
  String get supplyNameHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get supplyNameLabel;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get supplyNameRequired;

  /// Empty feedings.
  ///
  /// In en, this message translates to:
  /// **'No feeding uses this food yet. Open a pet\'s feeding and pick it under “Food from supplies”.'**
  String get supplyNoFeedings;

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'Stock not entered'**
  String get supplyNoStock;

  /// Hint.
  ///
  /// In en, this message translates to:
  /// **'Mark a purchase or correct the stock, and the forecast appears.'**
  String get supplyNoStockHint;

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'Daily use not set'**
  String get supplyNoUsage;

  /// Hint.
  ///
  /// In en, this message translates to:
  /// **'Pick this food in the pets\' feedings: the use is counted from the portions.'**
  String get supplyNoUsageFeedingHint;

  /// Hint.
  ///
  /// In en, this message translates to:
  /// **'Set how many days a package lasts in the item\'s settings.'**
  String get supplyNoUsageManualHint;

  /// Prefill warning.
  ///
  /// In en, this message translates to:
  /// **'The photos don\'t seem to show a pet product. Check the details.'**
  String get supplyNotPetProduct;

  /// Button: count of zero.
  ///
  /// In en, this message translates to:
  /// **'None left'**
  String get supplyNothingLeft;

  /// Slider label.
  ///
  /// In en, this message translates to:
  /// **'Open package: about {percent}%'**
  String supplyOpenPackage(int percent);

  /// Opens the store link.
  ///
  /// In en, this message translates to:
  /// **'Open the shop'**
  String get supplyOpenStore;

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'Ran out'**
  String get supplyOutOfStock;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get supplyPackageLabel;

  /// Amount in packages.
  ///
  /// In en, this message translates to:
  /// **'≈ {packages} pkg'**
  String supplyPackages(String packages);

  /// Counter label.
  ///
  /// In en, this message translates to:
  /// **'Packages of {package}'**
  String supplyPackagesBought(String package);

  /// Counter label.
  ///
  /// In en, this message translates to:
  /// **'Unopened packages of {package}'**
  String supplyPackagesClosed(String package);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add a plan'**
  String get supplyPlanAdd;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'No, thanks'**
  String get supplyPlanNo;

  /// Offer.
  ///
  /// In en, this message translates to:
  /// **'Add a treatment plan with this interval? A reminder comes when it\'s due.'**
  String get supplyPlanOfferBody;

  /// Offer title.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, one{Protects for {weeks} week} other{Protects for {weeks} weeks}}'**
  String supplyPlanOfferTitle(int weeks);

  /// Pet picker.
  ///
  /// In en, this message translates to:
  /// **'Which pet is it for?'**
  String get supplyPlanWhichPet;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save the purchase'**
  String get supplyPurchaseSave;

  /// Snack bar.
  ///
  /// In en, this message translates to:
  /// **'Purchase saved'**
  String get supplyPurchaseSaved;

  /// Title of the purchase sheet.
  ///
  /// In en, this message translates to:
  /// **'Bought: {name}'**
  String supplyPurchaseTitle(String name);

  /// Forecast line.
  ///
  /// In en, this message translates to:
  /// **'Ran out around {date}'**
  String supplyRanOutOn(String date);

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'This item was changed by a newer version of the app. Update the app to edit it.'**
  String get supplyReadOnly;

  /// Forecast line.
  ///
  /// In en, this message translates to:
  /// **'Left: ≈ {amount} ({packages})'**
  String supplyRemaining(String amount, String packages);

  /// Forecast line.
  ///
  /// In en, this message translates to:
  /// **'Runs out around {date}'**
  String supplyRunsOutOn(String date);

  /// Field hint.
  ///
  /// In en, this message translates to:
  /// **'2'**
  String get supplySizeHint;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'A number above 0'**
  String get supplySizeInvalid;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'Buy by {date} · enough for {lasts}'**
  String supplySoonLeft(String date, String lasts);

  /// Switch helper.
  ///
  /// In en, this message translates to:
  /// **'Usually the one unopened package you just bought'**
  String get supplyStockNowHelper;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Say how much there is now'**
  String get supplyStockNowLabel;

  /// Snack bar.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link'**
  String get supplyStoreFailed;

  /// Field helper.
  ///
  /// In en, this message translates to:
  /// **'A link to the product in a shop, to order it quickly'**
  String get supplyStoreHelper;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Where to buy'**
  String get supplyStoreLabel;

  /// Unit.
  ///
  /// In en, this message translates to:
  /// **'doses'**
  String get supplyUnitDoses;

  /// Unit.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get supplyUnitKg;

  /// Unit.
  ///
  /// In en, this message translates to:
  /// **'l'**
  String get supplyUnitLiters;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Use a link starting with https:// or http://'**
  String get supplyUrlInvalid;

  /// Segment.
  ///
  /// In en, this message translates to:
  /// **'By hand'**
  String get supplyUsageByHand;

  /// Suffix.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get supplyUsageDaysSuffix;

  /// Segment.
  ///
  /// In en, this message translates to:
  /// **'From feedings'**
  String get supplyUsageFeeding;

  /// Helper.
  ///
  /// In en, this message translates to:
  /// **'The use is counted from the portions of the feedings that give this food.'**
  String get supplyUsageFeedingHelper;

  /// Forecast line.
  ///
  /// In en, this message translates to:
  /// **'Uses {amount} a day, from the feedings'**
  String supplyUsageFromFeeding(String amount);

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'A number above 0'**
  String get supplyUsageInvalid;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Daily use'**
  String get supplyUsageLabel;

  /// Forecast line.
  ///
  /// In en, this message translates to:
  /// **'Uses {amount} a day, set by hand'**
  String supplyUsageManual(String amount);

  /// Segment.
  ///
  /// In en, this message translates to:
  /// **'A package lasts'**
  String get supplyUsagePackageLasts;

  /// Helper.
  ///
  /// In en, this message translates to:
  /// **'How many days one package ({package}) lasts'**
  String supplyUsagePackageLastsHelper(String package);

  /// Segment.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get supplyUsagePerDay;

  /// Helper.
  ///
  /// In en, this message translates to:
  /// **'How much is used a day'**
  String get supplyUsagePerDayHelper;

  /// Link to the Supplies tab.
  ///
  /// In en, this message translates to:
  /// **'All supplies'**
  String get todayShoppingAll;

  /// Today section.
  ///
  /// In en, this message translates to:
  /// **'To buy'**
  String get todayShoppingTitle;

  /// Picks photos of the package from the gallery.
  ///
  /// In en, this message translates to:
  /// **'From the gallery'**
  String get productScanFromLibrary;

  /// Note from a medicine's DataMatrix.
  ///
  /// In en, this message translates to:
  /// **'Batch {batch}'**
  String supplyBatch(String batch);

  /// Note from a medicine's DataMatrix.
  ///
  /// In en, this message translates to:
  /// **'expires {date}'**
  String supplyExpires(String date);

  /// A scanned item is no longer bought.
  ///
  /// In en, this message translates to:
  /// **'You marked it as no longer bought: a purchase brings it back to supplies.'**
  String get productScanExistingInactive;

  /// More: section with the household (group) the app shows.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get moreHousehold;

  /// The name of a person's first group, which the server calls Home.
  ///
  /// In en, this message translates to:
  /// **'My home'**
  String get householdDefaultName;

  /// Role in a group: everything, and the people.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get householdRoleOwner;

  /// Role in a group: everything with the pets, not the people.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get householdRoleMember;

  /// Role in a group: sees everything, only marks feedings, Done, visits and purchases.
  ///
  /// In en, this message translates to:
  /// **'Helper'**
  String get householdRoleHelper;

  /// What an owner may do, in one line.
  ///
  /// In en, this message translates to:
  /// **'Everything, and the people and settings of the group.'**
  String get householdRoleOwnerHelper;

  /// What a member may do, in one line.
  ///
  /// In en, this message translates to:
  /// **'Everything with the pets and records, but not the people.'**
  String get householdRoleMemberHelper;

  /// What a helper may do, in one line.
  ///
  /// In en, this message translates to:
  /// **'Sees everything and marks feedings, “Done”, visits and purchases.'**
  String get householdRoleHelperHelper;

  /// How many people are in a group.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String householdMemberCount(int count);

  /// More: opens the list of the user's groups.
  ///
  /// In en, this message translates to:
  /// **'Switch group'**
  String get householdSwitch;

  /// More: opens the group screen.
  ///
  /// In en, this message translates to:
  /// **'Members and invites'**
  String get householdPeople;

  /// Title of the sheet that switches groups.
  ///
  /// In en, this message translates to:
  /// **'Your groups'**
  String get householdSwitchTitle;

  /// Screen reader label of the check mark at the group on screen.
  ///
  /// In en, this message translates to:
  /// **'Current group'**
  String get householdCurrent;

  /// Starts a new group, e.g. Office.
  ///
  /// In en, this message translates to:
  /// **'Create a group'**
  String get householdCreate;

  /// Opens the screen to join a group with an invite code.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get householdJoin;

  /// Title of the dialog that creates a group.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get householdCreateTitle;

  /// Label of the group name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get householdNameLabel;

  /// Hint of the group name field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Office'**
  String get householdNameHint;

  /// The group name field is empty.
  ///
  /// In en, this message translates to:
  /// **'Give the group a name.'**
  String get householdNameRequired;

  /// Confirms creating a group.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get householdCreateAction;

  /// After switching to another group, or creating one.
  ///
  /// In en, this message translates to:
  /// **'You\'re in “{name}” now.'**
  String householdSwitched(String name);

  /// The server says the user isn't in the group on screen any more (removed, or left on another phone); the app moved to their first group.
  ///
  /// In en, this message translates to:
  /// **'You\'re no longer in “{name}”.'**
  String householdLeftNotice(String name);

  /// Like householdLeftNotice, when the app never learned the group's name.
  ///
  /// In en, this message translates to:
  /// **'You\'re no longer in that group.'**
  String get householdLeftNoticeUnnamed;

  /// Group screen: section with the people.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get householdMembers;

  /// Next to the signed-in user in the list of members.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get householdYou;

  /// A member without a name or e-mail.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get householdNoName;

  /// Group screen: starts an invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get householdInvite;

  /// Group screen: section with the codes nobody has used yet.
  ///
  /// In en, this message translates to:
  /// **'Open invites'**
  String get householdInvites;

  /// When an invite code stops working.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String householdInviteUntil(DateTime date);

  /// Takes an invite back before someone uses it.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get householdInviteRevoke;

  /// After revoking an invite.
  ///
  /// In en, this message translates to:
  /// **'The invite was revoked.'**
  String get householdInviteRevoked;

  /// Group screen: the user leaves the group.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get householdLeave;

  /// Asked before leaving a group.
  ///
  /// In en, this message translates to:
  /// **'Leave “{name}”?'**
  String householdLeaveTitle(String name);

  /// Body of the leave question.
  ///
  /// In en, this message translates to:
  /// **'The pets and records stay in the group. To come back, you\'ll need a new invite.'**
  String get householdLeaveBody;

  /// Confirms leaving a group.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get householdLeaveConfirm;

  /// After leaving a group.
  ///
  /// In en, this message translates to:
  /// **'You left “{name}”.'**
  String householdLeftSelf(String name);

  /// The last owner tried to leave or stop being an owner.
  ///
  /// In en, this message translates to:
  /// **'Make someone else an owner first.'**
  String get householdLastOwner;

  /// Tooltip of the button that renames the group.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get householdRename;

  /// Title of the dialog that renames the group.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get householdRenameTitle;

  /// Group screen: deletes an empty group the owner is alone in.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get householdDelete;

  /// Asked before deleting a group.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String householdDeleteTitle(String name);

  /// Body of the delete question.
  ///
  /// In en, this message translates to:
  /// **'Nobody else is in it, and it has no pets or supplies. You can\'t undo this.'**
  String get householdDeleteBody;

  /// After deleting a group.
  ///
  /// In en, this message translates to:
  /// **'The group “{name}” was deleted.'**
  String householdDeleted(String name);

  /// The server refused to delete a group that isn't empty.
  ///
  /// In en, this message translates to:
  /// **'Only an empty group can be deleted, and this one has pets or supplies.'**
  String get householdNotEmpty;

  /// Removes another person from the group (owners).
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get householdMemberRemove;

  /// Asked before removing a person.
  ///
  /// In en, this message translates to:
  /// **'Remove from the group?'**
  String get householdMemberRemoveTitle;

  /// Body of the remove question.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer see the pets of this group. Their marks stay.'**
  String householdMemberRemoveBody(String name);

  /// Confirms removing a person.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get householdMemberRemoveConfirm;

  /// Title of the sheet that picks the role of an invite.
  ///
  /// In en, this message translates to:
  /// **'Who are you inviting?'**
  String get householdInviteTitle;

  /// Title of the sheet with a new invite code.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get householdInviteCodeTitle;

  /// Under the invite code.
  ///
  /// In en, this message translates to:
  /// **'The code works once, for {days, plural, =1{1 day} other{{days} days}}.'**
  String householdInviteCodeBody(int days);

  /// Opens the phone's share sheet with the invite.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get householdShare;

  /// Copies the invite code.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get householdCopy;

  /// After copying an invite code.
  ///
  /// In en, this message translates to:
  /// **'The code was copied.'**
  String get householdCopied;

  /// The message shared with an invite code.
  ///
  /// In en, this message translates to:
  /// **'Join “{name}” in Collarbell: code {code}, valid for {days, plural, =1{1 day} other{{days} days}}.'**
  String householdShareText(String name, String code, int days);

  /// The server refused a new invite: too many open ones.
  ///
  /// In en, this message translates to:
  /// **'There are 20 open invites already: revoke the ones you don\'t need.'**
  String get householdInviteLimit;

  /// The server refused to create or join a group: too many groups.
  ///
  /// In en, this message translates to:
  /// **'You can be in up to 20 groups.'**
  String get householdLimit;

  /// Title of the screen to join a group with an invite code.
  ///
  /// In en, this message translates to:
  /// **'Join a group'**
  String get joinTitle;

  /// Label of the invite code field.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get joinCodeLabel;

  /// Under the invite code field.
  ///
  /// In en, this message translates to:
  /// **'8 letters and digits, like ABCD-2345'**
  String get joinCodeHelper;

  /// What an invite code invites to. role is helper or member.
  ///
  /// In en, this message translates to:
  /// **'{inviter} invites you to “{name}” as {role, select, helper{a helper} other{a member}}.'**
  String joinPreview(String inviter, String name, String role);

  /// Like joinPreview, when the inviter has no name.
  ///
  /// In en, this message translates to:
  /// **'You\'re invited to “{name}” as {role, select, helper{a helper} other{a member}}.'**
  String joinPreviewNoName(String name, String role);

  /// Under the invite preview.
  ///
  /// In en, this message translates to:
  /// **'The code works until {date}.'**
  String joinValidUntil(DateTime date);

  /// Joins the group of the code.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinAction;

  /// The invite code is wrong, used, revoked or expired.
  ///
  /// In en, this message translates to:
  /// **'This code doesn\'t work: check it or ask for a new one.'**
  String get joinNotFound;

  /// The invite code is for a group the user is in.
  ///
  /// In en, this message translates to:
  /// **'You\'re already in this group.'**
  String get joinAlreadyMember;

  /// The server refused more invite codes for now (429).
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again in a few minutes.'**
  String get joinTooManyAttempts;

  /// After joining a group.
  ///
  /// In en, this message translates to:
  /// **'You joined “{name}”.'**
  String joinJoined(String name);

  /// A request failed because the user isn't in the group on screen any more.
  ///
  /// In en, this message translates to:
  /// **'You\'re no longer in this group.'**
  String get errorNotInHousehold;

  /// Pets list without pets, for a helper (can't add).
  ///
  /// In en, this message translates to:
  /// **'The group\'s cats and dogs will show here.'**
  String get petsEmptyBodyHelper;

  /// Today without pets, for a helper (can't add).
  ///
  /// In en, this message translates to:
  /// **'When the group has pets, their feeding, care and shopping show up here.'**
  String get todayStartBodyHelper;

  /// Feeding tab without schedules, for a helper.
  ///
  /// In en, this message translates to:
  /// **'No feeding times yet.'**
  String get feedingEmptyHelper;

  /// Health tab without plans, for a helper.
  ///
  /// In en, this message translates to:
  /// **'No plans yet.'**
  String get healthPlansEmptyHelper;

  /// Health tab without records, for a helper.
  ///
  /// In en, this message translates to:
  /// **'No records yet.'**
  String get healthHistoryEmptyHelper;

  /// Passport tab without details, for a helper.
  ///
  /// In en, this message translates to:
  /// **'No passport details yet.'**
  String get passportEmptyHelper;

  /// Passport tab without pages, for a helper.
  ///
  /// In en, this message translates to:
  /// **'No passport pages yet.'**
  String get passportPagesEmptyHelper;

  /// Visits list without visits, for a helper.
  ///
  /// In en, this message translates to:
  /// **'Visits to the vet or the groomer will show here.'**
  String get visitsEmptyBodyHelper;

  /// Supplies without items, for a helper.
  ///
  /// In en, this message translates to:
  /// **'The group\'s food, litter and medicine will show here.'**
  String get suppliesEmptyBodyHelper;

  /// Supply page, for a helper: no feeding gives this food.
  ///
  /// In en, this message translates to:
  /// **'No feeding uses this food yet.'**
  String get supplyNoFeedingsHelper;

  /// The server's default group name Home, for anyone but its owner (who sees My home).
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get householdDefaultNameOther;

  /// Asked before an owner gives themselves another role.
  ///
  /// In en, this message translates to:
  /// **'Stop being an owner?'**
  String get householdStepDownTitle;

  /// Body of the step-down question.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be able to invite people or change roles, and your open invites will stop working.'**
  String get householdStepDownBody;

  /// Confirms an owner giving themselves another role.
  ///
  /// In en, this message translates to:
  /// **'Change my role'**
  String get householdStepDownConfirm;

  /// A tapped push opened another group whose name the app doesn't know yet.
  ///
  /// In en, this message translates to:
  /// **'You\'re in another group now.'**
  String get householdSwitchedUnnamed;

  /// The typed invite code has a character codes never have.
  ///
  /// In en, this message translates to:
  /// **'Codes have no letters O and I and no digits 0 and 1: check the code.'**
  String get joinCodeBadCharacters;

  /// Android notification channel: quiet pushes that someone fed a pet, replacing the feeding reminder.
  ///
  /// In en, this message translates to:
  /// **'Who fed'**
  String get notificationsChannelFeedingUpdates;

  /// The group's plan (Free or Premium): screen title, the row in More and the section on the group screen.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get householdPlanTitle;

  /// Name of the free plan; a product name, the same in every language.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get householdPlanFree;

  /// Name of the paid plan; a product name, the same in every language.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get householdPlanPremium;

  /// Plan screen, above the plan's name: a plan belongs to a group.
  ///
  /// In en, this message translates to:
  /// **'The plan of “{name}”'**
  String householdPlanOf(String name);

  /// When Premium ends.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String householdPlanUntil(DateTime date);

  /// Premium without an end.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get householdPlanNoEnd;

  /// Plan screen: the section with this month's AI photos.
  ///
  /// In en, this message translates to:
  /// **'AI photos this month'**
  String get householdPlanAiPhotos;

  /// AI photos used this month of what the plan allows, e.g. 7 of 20.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit}'**
  String householdPlanAiPhotosUsed(int used, int limit);

  /// Plan screen: the month's AI photos are used up.
  ///
  /// In en, this message translates to:
  /// **'This month\'s AI photos are used up. Typing things in and scanning barcodes work as before.'**
  String get householdPlanAiPhotosUsedUp;

  /// When the month's AI photos are counted from zero again: the first of next month.
  ///
  /// In en, this message translates to:
  /// **'The count starts again on {date}.'**
  String householdPlanResetsOn(DateTime date);

  /// Plan screen: what counts as an AI photo.
  ///
  /// In en, this message translates to:
  /// **'Every photo AI reads counts: a passport page, a chip sticker, a package.'**
  String get householdPlanAiPhotosHelp;

  /// Plan screen, on Free: the section about Premium.
  ///
  /// In en, this message translates to:
  /// **'What Premium gives'**
  String get householdPlanPremiumTitle;

  /// What Premium gives.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} AI photos a month'**
  String householdPlanPremiumAiPhotos(int count);

  /// Plan screen: an honest note that nothing can be bought yet. No buttons or links to buy (store rules).
  ///
  /// In en, this message translates to:
  /// **'There are no payments in the app yet: for now, Premium is given by hand.'**
  String get householdPlanPaymentsNote;

  /// Button under an AI-limit error: opens the plan screen.
  ///
  /// In en, this message translates to:
  /// **'See the plan'**
  String get householdPlanOpen;

  /// Group screen: the plan's line under its name.
  ///
  /// In en, this message translates to:
  /// **'AI photos this month: {used} of {limit}'**
  String householdPlanAiPhotosLine(int used, int limit);

  /// AI refused to read photos: the group's AI photos for the month are used up.
  ///
  /// In en, this message translates to:
  /// **'AI has read {used} of {limit} photos this month: that\'s the limit of the {plan} plan. The count starts again on {date}.'**
  String errorAiLimitUsedUp(int used, int limit, String plan, DateTime date);

  /// AI refused to read photos: fewer are left this month than were sent.
  ///
  /// In en, this message translates to:
  /// **'{left} of {limit} photos are left this month: choose fewer.'**
  String errorAiLimitNotEnough(int left, int limit);

  /// AI refused to read photos for the month's limit, and the server didn't say the numbers.
  ///
  /// In en, this message translates to:
  /// **'This month\'s AI limit is used up.'**
  String get errorAiLimit;

  /// Request failed with 429, e.g. more than 10 AI readings a minute.
  ///
  /// In en, this message translates to:
  /// **'Too many requests in a row. Try again in a minute.'**
  String get errorTooManyRequests;

  /// Like errorTooManyRequests, when the server says how long to wait.
  ///
  /// In en, this message translates to:
  /// **'Too many requests in a row. Try again in {seconds, plural, =1{1 second} other{{seconds} seconds}}.'**
  String errorTooManyRequestsIn(int seconds);

  /// AI refused to read photos: on Free, one person may send only so many a month in all their Free groups together, and they have.
  ///
  /// In en, this message translates to:
  /// **'You\'ve sent AI {used} of {limit} photos this month in all your groups on {plan}. The count starts again on {date}.'**
  String errorAiLimitPersonUsedUp(
    int used,
    int limit,
    String plan,
    DateTime date,
  );

  /// Like errorAiLimitPersonUsedUp, when some are left but fewer than were sent.
  ///
  /// In en, this message translates to:
  /// **'You have {left} of {limit} photos left this month in all your groups on {plan}: choose fewer.'**
  String errorAiLimitPersonNotEnough(int left, int limit, String plan);

  /// Closes a sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// More: section with downloading the person's data and deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get moreYourData;

  /// More: downloads a ZIP of everything of the person's; also the title of its sheet.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get dataExportTitle;

  /// What the data download has in it.
  ///
  /// In en, this message translates to:
  /// **'A ZIP file with your account, groups, photos and scans'**
  String get dataExportHelper;

  /// The data download has started; nothing has come yet.
  ///
  /// In en, this message translates to:
  /// **'Preparing the file…'**
  String get dataExportPreparing;

  /// How much of the data download has come; the total isn't known. size is fileSizeKb or fileSizeMb.
  ///
  /// In en, this message translates to:
  /// **'Downloaded: {size}'**
  String dataExportProgress(String size);

  /// The data download is done: its size (fileSizeKb or fileSizeMb).
  ///
  /// In en, this message translates to:
  /// **'Ready: {size}'**
  String dataExportReady(String size);

  /// A file size under a megabyte, in whole kilobytes.
  ///
  /// In en, this message translates to:
  /// **'{kb} KB'**
  String fileSizeKb(int kb);

  /// A file size in megabytes, one decimal.
  ///
  /// In en, this message translates to:
  /// **'{mb} MB'**
  String fileSizeMb(double mb);

  /// The share sheet failed; on Android it first copies the whole file, so space can run out.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share the file. Check that the phone has free space and try again.'**
  String get dataExportShareFailed;

  /// Under the size of the downloaded data.
  ///
  /// In en, this message translates to:
  /// **'It has your pets\' documents: keep it somewhere safe.'**
  String get dataExportKeepSafe;

  /// Opens the phone's share sheet with the downloaded data.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get dataExportShare;

  /// The downloaded data was saved where the person picked.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get dataExportSaved;

  /// The phone couldn't open the place to save the data to.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the file. Try “Share”.'**
  String get dataExportSaveFailed;

  /// The download is too big for Save; Share takes any size.
  ///
  /// In en, this message translates to:
  /// **'The file is large: save it with “Share”, e.g. to Files or Drive.'**
  String get dataExportTooLarge;

  /// The server refused the data download (429) without saying how long to wait.
  ///
  /// In en, this message translates to:
  /// **'You\'ve downloaded your data several times this hour. Try again later.'**
  String get dataExportTooOften;

  /// The server refused the data download (429): a few are allowed an hour.
  ///
  /// In en, this message translates to:
  /// **'You\'ve downloaded your data several times this hour. Try again in {minutes, plural, =1{1 minute} other{{minutes} minutes}}.'**
  String dataExportTooOftenIn(int minutes);

  /// More: opens the delete screen; its title; the button that deletes the account.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// More: under Delete account.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see first what happens to each group'**
  String get deleteAccountHelper;

  /// Top of the delete screen.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted for good. This can\'t be undone.'**
  String get deleteAccountWarning;

  /// Delete screen: section with each group and its fate.
  ///
  /// In en, this message translates to:
  /// **'What happens to your groups'**
  String get deleteAccountGroups;

  /// A group nobody would be left to look after: deleted with its pets.
  ///
  /// In en, this message translates to:
  /// **'{pets, plural, =0{Will be deleted with everything in it.} =1{Will be deleted with its pet and all its records, photos and documents.} other{Will be deleted with its {pets} pets and all their records, photos and documents.}}'**
  String deleteAccountFateDeleted(int pets);

  /// A deleted group that has helpers besides the person: they lose it.
  ///
  /// In en, this message translates to:
  /// **'Only helpers would be left in it, and they lose access.'**
  String get deleteAccountFateDeletedHelpers;

  /// A group someone else owns: the others keep it.
  ///
  /// In en, this message translates to:
  /// **'Stays with the others as it is.'**
  String get deleteAccountFateKept;

  /// The person is the last owner: the member who joined first becomes the owner.
  ///
  /// In en, this message translates to:
  /// **'Stays with the others; {name} becomes its owner.'**
  String deleteAccountFateHandedOver(String name);

  /// Like deleteAccountFateHandedOver, when the server didn't name the new owner.
  ///
  /// In en, this message translates to:
  /// **'Stays with the others; the member who joined first becomes its owner.'**
  String get deleteAccountFateHandedOverUnnamed;

  /// Delete screen: section.
  ///
  /// In en, this message translates to:
  /// **'What gets deleted'**
  String get deleteAccountGoes;

  /// Delete screen: what is deleted.
  ///
  /// In en, this message translates to:
  /// **'Your account: e-mail, name, settings, the phones that get reminders, and the record of what your apps did in the last 7 days.'**
  String get deleteAccountGoesAccount;

  /// Delete screen: what is deleted.
  ///
  /// In en, this message translates to:
  /// **'Groups where you\'re alone, or where only helpers would be left, with their pets, records, photos and documents.'**
  String get deleteAccountGoesGroups;

  /// Delete screen: what is deleted (the Firebase account).
  ///
  /// In en, this message translates to:
  /// **'Your sign-in: the e-mail and password.'**
  String get deleteAccountGoesSignIn;

  /// Delete screen: section.
  ///
  /// In en, this message translates to:
  /// **'What stays'**
  String get deleteAccountStays;

  /// Delete screen: what stays.
  ///
  /// In en, this message translates to:
  /// **'In shared groups your records and feeding marks stay without your name, and what is written in them (e.g. the owner\'s details in a pet passport) stays as it is.'**
  String get deleteAccountStaysRecords;

  /// Delete screen: what stays (nightly backups).
  ///
  /// In en, this message translates to:
  /// **'Backups keep the data for up to 14 days, then it\'s gone from them too.'**
  String get deleteAccountStaysBackups;

  /// Delete screen: what stays (photos AI has read).
  ///
  /// In en, this message translates to:
  /// **'Photos already sent to the AI (Gemini) to be read were handled under Google\'s terms: deleting the account can\'t recall them.'**
  String get deleteAccountStaysAiPhotos;

  /// Delete screen: opens the data download.
  ///
  /// In en, this message translates to:
  /// **'Download my data first'**
  String get deleteAccountExportFirst;

  /// Under the password field of the delete screen.
  ///
  /// In en, this message translates to:
  /// **'Type your password to confirm it\'s you.'**
  String get deleteAccountPasswordHelper;

  /// Asked before deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmTitle;

  /// Body of the delete question: the groups that go with the account (count of them, and their names joined with namesAnd).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{This can\'t be undone.} =1{{names} will be deleted with everything in it. This can\'t be undone.} other{{names} will be deleted with everything in them. This can\'t be undone.}}'**
  String deleteAccountConfirmBody(int count, String names);

  /// A group's name in quotes, in a sentence.
  ///
  /// In en, this message translates to:
  /// **'“{name}”'**
  String quotedName(String name);

  /// The end of a list: the others (joined with commas) and the last one.
  ///
  /// In en, this message translates to:
  /// **'{names} and {last}'**
  String namesAnd(String names, String last);

  /// The password typed to delete the account is wrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong password. Try again.'**
  String get deleteAccountWrongPassword;

  /// The server wants the password typed again before deleting the account.
  ///
  /// In en, this message translates to:
  /// **'For your safety, type your password again.'**
  String get deleteAccountPasswordAgain;

  /// Checking the password failed for another reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check your password. Try again.'**
  String get deleteAccountPasswordCheckFailed;

  /// The deletion went through, but signing out on this phone failed twice.
  ///
  /// In en, this message translates to:
  /// **'Your account is deleted, but this phone couldn\'t sign out of it. The app will sign out the next time it starts.'**
  String get deleteAccountSignOutFailed;

  /// Nothing was deleted: since the groups were shown, someone joined, left or became an owner (409). The screen shows them anew.
  ///
  /// In en, this message translates to:
  /// **'Something changed in your groups. Check again what happens to them, then delete.'**
  String get deleteAccountPlanChanged;

  /// Sign-in screen after the account was deleted, here or on another phone.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeletedNotice;

  /// Tab of the pet's page with its weight log.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get petTabWeight;

  /// The pet's latest weight among its details on the Overview, and a check-up's weight on a scanned entry.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightLabel;

  /// The latest weight and the day it was taken, on the Overview.
  ///
  /// In en, this message translates to:
  /// **'{weight} on {date}'**
  String weightOnDate(String weight, DateTime date);

  /// Section of the Weight tab: the latest weight, large.
  ///
  /// In en, this message translates to:
  /// **'Latest weighing'**
  String get weightLatestTitle;

  /// Section of the Weight tab: the chart of the weight over time.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get weightTrendTitle;

  /// Section of the Weight tab: every weight, newest first.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get weightHistoryTitle;

  /// Button in the Weight tab's header that adds a weighing.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get weightAdd;

  /// Button of the Weight tab while it has no weighings.
  ///
  /// In en, this message translates to:
  /// **'Add weight'**
  String get weightAddFirst;

  /// Empty state of the Weight tab.
  ///
  /// In en, this message translates to:
  /// **'No weighings yet'**
  String get weightEmptyTitle;

  /// Empty state of the Weight tab: why and how often to weigh.
  ///
  /// In en, this message translates to:
  /// **'Weigh your pet once a month, kittens and puppies every 1–2 weeks: the log shows early when a pet starts losing or gaining weight.'**
  String get weightEmptyBody;

  /// Empty Weight tab, for a helper (can't add).
  ///
  /// In en, this message translates to:
  /// **'The pet\'s weighings will show here.'**
  String get weightEmptyBodyHelper;

  /// A weight the household entered: the chart's legend and the label of its row's icon.
  ///
  /// In en, this message translates to:
  /// **'Weighing'**
  String get weightSourceWeighing;

  /// A weight a vet noted in a check-up record: the chart's legend, the label of its row's icon, after the date of the latest weight.
  ///
  /// In en, this message translates to:
  /// **'Vet check-up'**
  String get weightSourceVet;

  /// The change of the latest weight from the one before it.
  ///
  /// In en, this message translates to:
  /// **'{change} since {date}'**
  String weightChangeSince(String change, String date);

  /// The latest weight is the same as the one before it.
  ///
  /// In en, this message translates to:
  /// **'No change since {date}'**
  String weightNoChangeSince(String date);

  /// A row of the weight history: the same weight as the one before it.
  ///
  /// In en, this message translates to:
  /// **'no change'**
  String get weightNoChange;

  /// A body condition score in short.
  ///
  /// In en, this message translates to:
  /// **'BCS {score}/{scale}'**
  String weightBodyCondition(int score, int scale);

  /// After the body condition score of the latest weighing: the ideal scores on its scale.
  ///
  /// In en, this message translates to:
  /// **'ideal {range}'**
  String weightBcsIdeal(String range);

  /// Chip: the chart shows the last 3 months.
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get weightPeriodThreeMonths;

  /// Chip: the chart shows the last year.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get weightPeriodYear;

  /// Chip: the chart shows the whole log.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get weightPeriodAll;

  /// Instead of the chart while the log has one weight.
  ///
  /// In en, this message translates to:
  /// **'The chart shows after the second weighing.'**
  String get weightChartNeedsTwo;

  /// Instead of the chart when the chosen period has fewer than two weights.
  ///
  /// In en, this message translates to:
  /// **'Fewer than two weighings in this period.'**
  String get weightChartTooFew;

  /// What the chart shows, for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Weight chart from {from} to {to}: {first} at the start, {last} at the end, lowest {lowest}, highest {highest}.'**
  String weightChartSummary(
    String from,
    String to,
    String first,
    String last,
    String lowest,
    String highest,
  );

  /// The unit after the latest weight, set smaller than the number.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get weightUnitKg;

  /// Title of the sheet that adds a weighing.
  ///
  /// In en, this message translates to:
  /// **'New weighing'**
  String get weightAddTitle;

  /// Title of the sheet that changes a weighing.
  ///
  /// In en, this message translates to:
  /// **'Edit weighing'**
  String get weightEditTitle;

  /// Field label: the day of the weighing.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get weightMeasuredOnLabel;

  /// Placeholder of the weight field, in kilograms.
  ///
  /// In en, this message translates to:
  /// **'e.g. 4.2'**
  String get weightHint;

  /// Validation: the weight is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter the weight'**
  String get weightRequired;

  /// Validation: a weight typed with too many decimals (3 for a weighing: to the gram; 2 for a check-up).
  ///
  /// In en, this message translates to:
  /// **'{decimals, plural, =1{Use 1 decimal at most} other{Use {decimals} decimals at most}}'**
  String weightTooPrecise(int decimals);

  /// Validation: a weighing before the pet's exact date of birth.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be before the pet was born'**
  String get weightDateBeforeBirth;

  /// Label of the score of how lean or heavy the pet is (BCS).
  ///
  /// In en, this message translates to:
  /// **'Body condition score'**
  String get weightBcsLabel;

  /// Opens the body condition score of the weighing sheet.
  ///
  /// In en, this message translates to:
  /// **'Add body condition score'**
  String get weightBcsAdd;

  /// Closes the body condition score and leaves it out.
  ///
  /// In en, this message translates to:
  /// **'Remove the score'**
  String get weightBcsRemove;

  /// A body condition scale to choose: 1–9 or 1–5.
  ///
  /// In en, this message translates to:
  /// **'Scale 1–{max}'**
  String weightBcsScale(int max);

  /// Under the body condition score: the ideal scores on the chosen scale, and what they look like.
  ///
  /// In en, this message translates to:
  /// **'Ideal is {ideal} of {max}: the ribs are easy to feel, and the waist shows from above.'**
  String weightBcsHelp(String ideal, int max);

  /// Field label: a note to the weighing.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get weightNoteLabel;

  /// Placeholder of the weighing's note.
  ///
  /// In en, this message translates to:
  /// **'e.g. before breakfast'**
  String get weightNoteHint;

  /// Tooltip of the button that deletes a weighing.
  ///
  /// In en, this message translates to:
  /// **'Delete weighing'**
  String get weightDelete;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete this weighing?'**
  String get weightDeleteTitle;

  /// Confirmation text for deleting a weighing.
  ///
  /// In en, this message translates to:
  /// **'It disappears from the history and the chart. You can\'t undo this.'**
  String get weightDeleteBody;

  /// Message when the weighing no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This weighing has been deleted, probably on another device.'**
  String get weightGone;

  /// Shown instead of the sheet's fields for a weighing with values this app doesn't know.
  ///
  /// In en, this message translates to:
  /// **'This weighing was made in a newer version of the app. Update the app to change it.'**
  String get weightReadOnly;

  /// Quick text input: the tooltip of the button on the Health tab (next to the scan button) that opens a note to AI, and the title of that screen. The user writes or dictates what was done for the pet; AI turns it into entries to check.
  ///
  /// In en, this message translates to:
  /// **'Write it in words'**
  String get noteTitle;

  /// Text at the top of the note screen.
  ///
  /// In en, this message translates to:
  /// **'Write what was done and when, in your own words: vaccinations, treatments, a visit to the vet, the weight. AI turns it into entries for you to check.'**
  String get noteIntro;

  /// Label of the note's text field.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// Placeholder of the empty note field: an example of a note, in the user's language.
  ///
  /// In en, this message translates to:
  /// **'e.g. Yesterday the rabies shot, Nobivac; weighs 4.2 kg'**
  String get noteHint;

  /// Under the note field: the phone's keyboard can type what is said.
  ///
  /// In en, this message translates to:
  /// **'To dictate, tap the microphone on the keyboard.'**
  String get noteDictate;

  /// Button that sends the note to AI to be read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get noteRead;

  /// Validation: the note is empty, or has no letter or digit (only punctuation, emoji or spaces).
  ///
  /// In en, this message translates to:
  /// **'Write what was done, in words.'**
  String get noteRequired;

  /// On the Read button while the note is sent.
  ///
  /// In en, this message translates to:
  /// **'Sending the note to AI…'**
  String get noteStarting;

  /// A note refused: one person may have so many notes read in 24 hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{AI has already read 1 note in the last 24 hours. Try again tomorrow or add the record by hand.} other{AI has already read {count} notes in the last 24 hours. Try again tomorrow or add the record by hand.}}'**
  String noteLimitReached(int count);

  /// A note couldn't be read: no AI model on the server.
  ///
  /// In en, this message translates to:
  /// **'AI isn\'t set up on the server. Connect a model in the server configuration, then try again. Records can always be added by hand.'**
  String get noteErrorNotConfigured;

  /// A note couldn't be read for another reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while reading the note. Try again.'**
  String get noteErrorUnexpected;

  /// Status of a note while AI reads it.
  ///
  /// In en, this message translates to:
  /// **'Reading the note…'**
  String get noteStatusProcessing;

  /// How long reading a note takes.
  ///
  /// In en, this message translates to:
  /// **'Usually 5–30 seconds.'**
  String get noteReadingBody;

  /// Note while AI reads the note.
  ///
  /// In en, this message translates to:
  /// **'You can leave this screen: the note is read on the server and waits for you on the Health tab.'**
  String get noteReadingLeave;

  /// The note was not found (thrown away or gone with the pet).
  ///
  /// In en, this message translates to:
  /// **'This note no longer exists.'**
  String get noteGone;

  /// A thrown-away note was opened.
  ///
  /// In en, this message translates to:
  /// **'Nothing from this note was saved.'**
  String get noteDiscardedBody;

  /// Card on the Health tab: a note is ready to check.
  ///
  /// In en, this message translates to:
  /// **'Continue checking the note from {date}'**
  String noteResumeReady(String date);

  /// Card on the Health tab: a note that is still being read, or couldn't be read.
  ///
  /// In en, this message translates to:
  /// **'Note from {date}'**
  String noteResumeOpen(String date);

  /// Title of the review of a note's draft.
  ///
  /// In en, this message translates to:
  /// **'Check the note'**
  String get noteReviewTitle;

  /// Note at the top of the review of a note.
  ///
  /// In en, this message translates to:
  /// **'AI read these entries from your note. Check them against what you wrote, fix what\'s wrong, and untick what you don\'t want to save.'**
  String get noteReviewIntro;

  /// The draft of a note is empty.
  ///
  /// In en, this message translates to:
  /// **'AI found nothing to save in this note. Discard it, or write it again in other words.'**
  String get noteNothingFound;

  /// Warning on the note screen when notes go to Gemini's free tier (like the scans' warning, for a note).
  ///
  /// In en, this message translates to:
  /// **'Free Gemini tier: Google may use what is sent to improve its products, and human reviewers may read it. Don\'t write personal details such as phone numbers or addresses.'**
  String get noteFreeTierWarning;

  /// Above the note quoted on its review: when it was written (a note read again keeps that day).
  ///
  /// In en, this message translates to:
  /// **'Written {when}'**
  String noteWrittenAt(String when);

  /// Section of the review that quotes the note, to check the entries against it.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get noteSectionTitle;

  /// Above the words of the note an entry was read from.
  ///
  /// In en, this message translates to:
  /// **'From your note'**
  String get noteEvidence;

  /// Button under Save on the review of a note.
  ///
  /// In en, this message translates to:
  /// **'Discard note'**
  String get noteDiscard;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Discard this note?'**
  String get noteDiscardTitle;

  /// Confirmation dialog text.
  ///
  /// In en, this message translates to:
  /// **'Nothing from it is saved, and its text is deleted.'**
  String get noteDiscardBody;

  /// Snackbar after discarding a note.
  ///
  /// In en, this message translates to:
  /// **'Note discarded'**
  String get noteDiscarded;

  /// Dialog text when leaving the review of a note with changes.
  ///
  /// In en, this message translates to:
  /// **'Your changes here will be lost. The note stays on the Health tab to check later.'**
  String get noteLeaveBody;

  /// Note in brackets after the save summary when Discard finds the note saved.
  ///
  /// In en, this message translates to:
  /// **'this note was saved already'**
  String get noteSavedNoDiscard;

  /// Warning on a value AI couldn't find in the note.
  ///
  /// In en, this message translates to:
  /// **'The note doesn\'t say. Enter it.'**
  String get noteIssueUnreadable;

  /// Warning on a date of a note like 03/04/2025.
  ///
  /// In en, this message translates to:
  /// **'Day and month could be swapped. Check what you meant.'**
  String get noteIssueAmbiguous;

  /// Warning on a value of a note that can't be saved as it is.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look right. Check it.'**
  String get noteIssueInvalidFormat;

  /// Explains the Same as another entry badge on an entry of a note.
  ///
  /// In en, this message translates to:
  /// **'The same entry is in the note twice.'**
  String get noteIssueRepeated;

  /// Section of the review: weights read from a note or photos, saved as weighings on the Weight tab.
  ///
  /// In en, this message translates to:
  /// **'Weighings'**
  String get scanWeightsTitle;

  /// Explains the Already saved badge of a weight.
  ///
  /// In en, this message translates to:
  /// **'This weight is already on the Weight tab.'**
  String get scanWeightAlreadySaved;

  /// Explains the Same as another entry badge of a weight: given twice, or the same as a check-up's in this draft.
  ///
  /// In en, this message translates to:
  /// **'An entry above has the same weight.'**
  String get scanWeightRepeated;

  /// Why a weight entry can't be ticked.
  ///
  /// In en, this message translates to:
  /// **'Enter the weight to save this entry.'**
  String get scanNeedsWeight;

  /// Part of the snackbar after saving a scan or a note.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 weighing added} other{{count} weighings added}}'**
  String scanSavedWeights(int count);

  /// Bottom navigation: the first tab, a greeting, the pets, what is important now and quick actions.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Home title from 05:00 to 12:00.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// Home title from 12:00 to 17:00.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// Home title from 17:00 to 23:00.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// Home title from 23:00 to 05:00 (English has no 'good night' greeting).
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingNight;

  /// Screen reader label of the row of pets on Home.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get homePetsLabel;

  /// Primary action card on Home when the group has no pets.
  ///
  /// In en, this message translates to:
  /// **'Add a pet'**
  String get homeAddPetTitle;

  /// Second line of the Add a pet card on Home.
  ///
  /// In en, this message translates to:
  /// **'A cat or a dog: everything else starts with it'**
  String get homeAddPetHint;

  /// Action card on Home without pets: opens the onboarding.
  ///
  /// In en, this message translates to:
  /// **'Take the tour'**
  String get homeTourTitle;

  /// Second line of the Take the tour card.
  ///
  /// In en, this message translates to:
  /// **'What the app does, in a minute'**
  String get homeTourHint;

  /// Home section: the next feeding, what is overdue or due soon, the next visit, what to buy.
  ///
  /// In en, this message translates to:
  /// **'Right now'**
  String get homeNowTitle;

  /// Home: how many care items are overdue, in a red tag. Opens Today.
  ///
  /// In en, this message translates to:
  /// **'Overdue: {count}'**
  String homeOverdue(int count);

  /// Home: how many care items are due within 14 days, in a yellow tag. Opens Today.
  ///
  /// In en, this message translates to:
  /// **'Due soon: {count}'**
  String homeDueSoon(int count);

  /// Second line of the overdue / due soon rows on Home.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations and treatments'**
  String get homeCareHint;

  /// Home: how many supplies to buy now. Opens the Supplies tab.
  ///
  /// In en, this message translates to:
  /// **'To buy: {count}'**
  String homeToBuy(int count);

  /// Second line of the To buy row on Home.
  ///
  /// In en, this message translates to:
  /// **'Food, litter, medicine'**
  String get homeToBuyHint;

  /// Home when nothing needs doing now.
  ///
  /// In en, this message translates to:
  /// **'All done for today'**
  String get homeAllDoneTitle;

  /// Under All done for today.
  ///
  /// In en, this message translates to:
  /// **'New things show up here when they are due.'**
  String get homeAllDoneBody;

  /// Header of the next feeding on Home, e.g. Feeding at 08:00.
  ///
  /// In en, this message translates to:
  /// **'Feeding at {time}'**
  String homeNextFeeding(String time);

  /// Home section of action cards (not for helpers).
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeQuickTitle;

  /// Quick action: a new care record for a pet.
  ///
  /// In en, this message translates to:
  /// **'Vaccination or treatment'**
  String get homeQuickCare;

  /// Second line of the Vaccination or treatment quick action.
  ///
  /// In en, this message translates to:
  /// **'Record what was done'**
  String get homeQuickCareHint;

  /// Quick action: a new AI scan of a pet's passport.
  ///
  /// In en, this message translates to:
  /// **'Scan the passport'**
  String get homeQuickScan;

  /// Second line of the Scan the passport quick action.
  ///
  /// In en, this message translates to:
  /// **'AI copies the records'**
  String get homeQuickScanHint;

  /// Quick action: a new note for AI to read (the Health tab's noteTitle).
  ///
  /// In en, this message translates to:
  /// **'Write it in words'**
  String get homeQuickNote;

  /// Second line of the Write it in words quick action.
  ///
  /// In en, this message translates to:
  /// **'AI reads the note'**
  String get homeQuickNoteHint;

  /// Quick action: a new weighing of a pet.
  ///
  /// In en, this message translates to:
  /// **'Weigh'**
  String get homeQuickWeigh;

  /// Second line of the Weigh quick action.
  ///
  /// In en, this message translates to:
  /// **'Keep an eye on weight'**
  String get homeQuickWeighHint;

  /// Quick action: scan the barcode of a bought product into supplies.
  ///
  /// In en, this message translates to:
  /// **'Scan a purchase'**
  String get homeQuickPurchase;

  /// Second line of the Scan a purchase quick action.
  ///
  /// In en, this message translates to:
  /// **'Food, medicine'**
  String get homeQuickPurchaseHint;

  /// Title of the sheet that picks a pet for a quick action.
  ///
  /// In en, this message translates to:
  /// **'Which pet?'**
  String get homePickPet;

  /// Action card: a new visit (Today's first steps, Home's quick actions).
  ///
  /// In en, this message translates to:
  /// **'Add a visit'**
  String get visitAddCard;

  /// Second line of the Add a visit card.
  ///
  /// In en, this message translates to:
  /// **'Vet, grooming'**
  String get visitAddCardHint;

  /// Second line of the Add feeding card on an empty Today.
  ///
  /// In en, this message translates to:
  /// **'We\'ll remind you when to feed'**
  String get todayAddFeedingHint;

  /// Second line of the Vaccinations and treatments card.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tell you when they\'re due'**
  String get todayAddCareHint;

  /// Row in More: opens the onboarding again.
  ///
  /// In en, this message translates to:
  /// **'Getting to know the app'**
  String get welcomeMoreTitle;

  /// Second line of the Getting to know the app row.
  ///
  /// In en, this message translates to:
  /// **'What the app does and the first steps'**
  String get welcomeMoreHint;

  /// Onboarding, first page title.
  ///
  /// In en, this message translates to:
  /// **'Reminders on time'**
  String get welcomeIntro1Title;

  /// Onboarding, first page text.
  ///
  /// In en, this message translates to:
  /// **'Feeding, vaccinations, treatments and vet visits: the notification comes at the right minute.'**
  String get welcomeIntro1Body;

  /// Onboarding, second page title.
  ///
  /// In en, this message translates to:
  /// **'The passport in a minute'**
  String get welcomeIntro2Title;

  /// Onboarding, second page text.
  ///
  /// In en, this message translates to:
  /// **'Take photos of the vet passport\'s pages: AI copies the vaccinations and due dates, and you check them before saving.'**
  String get welcomeIntro2Body;

  /// Onboarding, third page title.
  ///
  /// In en, this message translates to:
  /// **'Together with the family'**
  String get welcomeIntro3Title;

  /// Onboarding, third page text.
  ///
  /// In en, this message translates to:
  /// **'Everyone sees who has already fed the pet, and supplies tell you when it\'s time to buy food.'**
  String get welcomeIntro3Body;

  /// Onboarding: the main button that goes on.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get welcomeNext;

  /// Onboarding: the main button of the last intro page.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get welcomeStart;

  /// Onboarding: skips the intro or a setup step.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get welcomeSkip;

  /// Onboarding: the main button of the last step; back to Home.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get welcomeDone;

  /// Onboarding: saves the step (the pet, the feeding) and goes on.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get welcomeSaveNext;

  /// Onboarding: where the setup is.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {count}'**
  String welcomeStep(int step, int count);

  /// Screen reader text of the page dots of the onboarding.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String welcomePage(int page, int count);

  /// Tooltip of the button that closes the onboarding.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get welcomeClose;

  /// Tooltip of the button that goes to the previous page or step of the onboarding.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get welcomeBack;

  /// Onboarding, pet step title.
  ///
  /// In en, this message translates to:
  /// **'Who lives with you?'**
  String get welcomePetTitle;

  /// Onboarding, pet step text.
  ///
  /// In en, this message translates to:
  /// **'Start with a pet: feeding, care and supplies are set up for it. The rest of the details can wait.'**
  String get welcomePetBody;

  /// Onboarding, pet step when the group has pets.
  ///
  /// In en, this message translates to:
  /// **'Already here: {names}'**
  String welcomePetHere(String names);

  /// Onboarding, pet step: opens the full pet form.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get welcomePetAddMore;

  /// Onboarding action card: join a group with a code instead of adding the pet again.
  ///
  /// In en, this message translates to:
  /// **'I was invited to a family'**
  String get welcomeInvitedTitle;

  /// Second line of the I was invited card.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code'**
  String get welcomeInvitedHint;

  /// Onboarding, feeding step title.
  ///
  /// In en, this message translates to:
  /// **'Feeding times'**
  String get welcomeFeedingTitle;

  /// Onboarding, feeding step text.
  ///
  /// In en, this message translates to:
  /// **'Everyone gets a reminder at these times, every day. Tap a time to change it.'**
  String get welcomeFeedingBody;

  /// Onboarding, feeding step when the pet has a schedule.
  ///
  /// In en, this message translates to:
  /// **'Feeding is already set up'**
  String get welcomeFeedingSet;

  /// Onboarding, feeding step without a pet.
  ///
  /// In en, this message translates to:
  /// **'Feeding is set up for a pet. Add one first, or come back here later from More.'**
  String get welcomeFeedingNoPet;

  /// Onboarding, notifications step title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get welcomePushTitle;

  /// Onboarding, notifications step text.
  ///
  /// In en, this message translates to:
  /// **'Reminders come as notifications: feeding, vaccinations, visits and what to buy. Without them the app shows what is due only when you open it.'**
  String get welcomePushBody;

  /// Onboarding: asks the phone for permission to notify.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get welcomePushAllow;

  /// Onboarding, notifications step when they are allowed.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on'**
  String get welcomePushOn;

  /// Onboarding, family step title (owners only).
  ///
  /// In en, this message translates to:
  /// **'Invite your family'**
  String get welcomeFamilyTitle;

  /// Onboarding, family step text.
  ///
  /// In en, this message translates to:
  /// **'Send a code to the people who look after the pets with you: they will see the feedings, care and supplies.'**
  String get welcomeFamilyBody;

  /// Onboarding, family step after an invite was made.
  ///
  /// In en, this message translates to:
  /// **'Invite created. The code works for 7 days.'**
  String get welcomeFamilyInvited;

  /// Onboarding, family step: another invite.
  ///
  /// In en, this message translates to:
  /// **'Invite someone else'**
  String get welcomeFamilyInviteMore;

  /// Section in More with the onboarding.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get moreHelp;

  /// Second line of Fill in by hand (adding a supply).
  ///
  /// In en, this message translates to:
  /// **'Name and package size'**
  String get supplyAddByHandHelper;

  /// Second line of the Add past record card on an empty history.
  ///
  /// In en, this message translates to:
  /// **'By hand, one at a time'**
  String get healthHistoryAddHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
