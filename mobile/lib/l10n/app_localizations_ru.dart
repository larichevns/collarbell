// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Collarbell';

  @override
  String get navToday => 'Сегодня';

  @override
  String get navPets => 'Питомцы';

  @override
  String get navSupplies => 'Запасы';

  @override
  String get navMore => 'Ещё';

  @override
  String get commonTryAgain => 'Повторить';

  @override
  String get commonLoading => 'Загрузка';

  @override
  String get errorNetwork =>
      'Не удаётся связаться с сервером. Проверьте подключение и попробуйте снова.';

  @override
  String get leaveTitle => 'Уйти без сохранения?';

  @override
  String get leaveBody => 'Введённое на этом экране пропадёт.';

  @override
  String get leaveConfirm => 'Уйти';

  @override
  String get errorRefreshed =>
      'Связь с сервером восстановилась, данные обновились. Проверьте их и повторите.';

  @override
  String get errorSignInRenewal =>
      'Не удалось обновить вход: нет интернета. Проверьте подключение.';

  @override
  String get formOpenedOffline =>
      'Форма открыта без связи с сервером, по сохранённой копии: данные могли устареть, сохранять их нельзя. Откройте её снова, когда связь появится.';

  @override
  String get offlineBanner => 'Нет связи с сервером';

  @override
  String offlineBannerSince(String time) {
    return 'Нет связи с сервером · данные на $time';
  }

  @override
  String get errorUnauthorized => 'Сеанс истёк. Войдите снова.';

  @override
  String get errorForbidden => 'Ваша роль в группе не позволяет это сделать.';

  @override
  String get errorServer =>
      'На сервере что-то пошло не так. Попробуйте чуть позже.';

  @override
  String get errorUnknown => 'Что-то пошло не так. Попробуйте снова.';

  @override
  String errorReference(String traceId) {
    return 'Код ошибки: $traceId';
  }

  @override
  String get signInTagline =>
      'Кормление, прививки и запасы ваших питомцев в одном месте.';

  @override
  String get signInTitle => 'Вход';

  @override
  String get signUpTitle => 'Регистрация';

  @override
  String get emailLabel => 'Эл. почта';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get emailRequired => 'Введите эл. почту';

  @override
  String get emailInvalid => 'Введите адрес в формате name@example.com';

  @override
  String get passwordRequired => 'Введите пароль';

  @override
  String passwordTooShort(int min) {
    String _temp0 = intl.Intl.pluralLogic(
      min,
      locale: localeName,
      other: 'Не меньше $min символа',
      many: 'Не меньше $min символов',
      few: 'Не меньше $min символов',
      one: 'Не меньше $min символа',
    );
    return '$_temp0';
  }

  @override
  String get signInButton => 'Войти';

  @override
  String get signUpButton => 'Создать аккаунт';

  @override
  String get switchToSignUp => 'Впервые в Collarbell? Создайте аккаунт';

  @override
  String get switchToSignIn => 'Уже есть аккаунт? Войдите';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get passwordResetNeedsEmail =>
      'Введите e-mail выше: на него придёт ссылка для нового пароля.';

  @override
  String passwordResetSent(String email) {
    return 'Если аккаунт с адресом $email есть, на него придёт письмо со ссылкой для нового пароля. Проверьте и папку «Спам».';
  }

  @override
  String get authErrorInvalidCredentials => 'Неверная почта или пароль.';

  @override
  String get authErrorEmailInUse =>
      'Аккаунт с этой почтой уже есть. Войдите в него.';

  @override
  String get authErrorWeakPassword =>
      'Такой пароль легко подобрать. Выберите пароль длиннее.';

  @override
  String get authErrorInvalidEmail => 'Похоже, в адресе почты ошибка.';

  @override
  String get authErrorUserDisabled => 'Этот аккаунт отключён.';

  @override
  String get authErrorTooManyRequests =>
      'Слишком много попыток. Попробуйте через несколько минут.';

  @override
  String get authErrorNetwork =>
      'Нет соединения. Проверьте интернет и попробуйте снова.';

  @override
  String get authErrorNotAllowed =>
      'Вход по почте отключён для этого приложения.';

  @override
  String get authErrorUnknown => 'Не удалось войти. Попробуйте снова.';

  @override
  String get devModeOverline => 'РЕЖИМ РАЗРАБОТЧИКА';

  @override
  String get devModeBody =>
      'Вход с локальной тестовой учётной записью. API должен работать в режиме разработки.';

  @override
  String get devEmailLabel => 'Почта разработчика';

  @override
  String devUserId(String uid) {
    return 'ID пользователя: $uid';
  }

  @override
  String get devContinue => 'Продолжить как разработчик';

  @override
  String get todayTitle => 'Сегодня';

  @override
  String todayDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMEEEEd(
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get todayEmptyTitle => 'Пока ничего не запланировано';

  @override
  String get todayEmptyBody =>
      'Здесь появятся кормления, визиты, а также прививки и обработки на ближайшие 30 дней.';

  @override
  String get todayStartTitle => 'Начните с питомца';

  @override
  String get todayStartBody =>
      'Добавьте кошку или собаку: потом здесь появятся кормления, прививки, обработки и что пора купить.';

  @override
  String get todayAddFeeding => 'Добавить кормление';

  @override
  String get todayAddCare => 'Прививки и обработки';

  @override
  String get petsTitle => 'Питомцы';

  @override
  String get petsEmptyTitle => 'Пока нет питомцев';

  @override
  String get petsEmptyBody => 'Здесь появятся ваши кошки и собаки.';

  @override
  String get petSpeciesCat => 'Кошка';

  @override
  String get petSpeciesDog => 'Собака';

  @override
  String get petSpeciesOther => 'Другое животное';

  @override
  String get suppliesTitle => 'Запасы';

  @override
  String get suppliesEmptyTitle => 'Пока нет запасов';

  @override
  String get suppliesEmptyBody =>
      'Добавьте корм, наполнитель или препарат — приложение подскажет, когда пора купить.';

  @override
  String get moreTitle => 'Ещё';

  @override
  String get moreAccount => 'Аккаунт';

  @override
  String get moreSignedInAs => 'Вы вошли как';

  @override
  String get moreNoEmail => 'Почта не указана';

  @override
  String get moreLanguage => 'Язык';

  @override
  String get moreLanguageSystem => 'Как в системе';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameRussian => 'Русский';

  @override
  String get moreTheme => 'Тема';

  @override
  String get moreThemeLight => 'Светлая (по умолчанию)';

  @override
  String get moreThemeDark => 'Тёмная';

  @override
  String get moreThemeSystem => 'Как в системе';

  @override
  String get moreSignOut => 'Выйти';

  @override
  String get signOutTitle => 'Выйти из аккаунта?';

  @override
  String get signOutBody =>
      'Напоминания перестанут приходить на этот телефон, пока вы снова не войдёте.';

  @override
  String moreDeveloperInfo(String server) {
    return 'Режим разработчика · $server';
  }

  @override
  String get commonAdd => 'Добавить';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get commonMoreActions => 'Другие действия';

  @override
  String get commonNo => 'Нет';

  @override
  String get commonYes => 'Да';

  @override
  String get commonRemove => 'Удалить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get errorNotFound => 'Не найдено. Возможно, это удалили.';

  @override
  String get errorValidation =>
      'Некоторые данные не приняты. Проверьте их и попробуйте снова.';

  @override
  String get errorFileTooLarge =>
      'Файл слишком большой. Загружайте файлы до 15 МБ.';

  @override
  String get errorFileUnsupported =>
      'Такой тип файла не поддерживается. Нужно фото в JPEG, PNG или WebP либо PDF.';

  @override
  String get formServerFieldError => 'Это значение не принято. Проверьте его.';

  @override
  String get formCheckFields => 'Проверьте выделенные поля.';

  @override
  String formTooLong(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Не больше $max символа',
      many: 'Не больше $max символов',
      few: 'Не больше $max символов',
      one: 'Не больше $max символа',
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
  String get dateNotSet => 'Не указана';

  @override
  String get dateClear => 'Очистить дату';

  @override
  String get filePdf => 'PDF';

  @override
  String get mediaTakePhoto => 'Сфотографировать';

  @override
  String get mediaChooseFromLibrary => 'Выбрать из галереи';

  @override
  String get mediaChoosePdf => 'Выбрать PDF-файл';

  @override
  String get mediaRemovePhoto => 'Удалить фото';

  @override
  String get mediaPickerFailed =>
      'Не удалось открыть камеру или фото. Проверьте доступ приложения в Настройках.';

  @override
  String get mediaPageAddedTitle => 'Страница добавлена';

  @override
  String get mediaPageAddedBody => 'Сфотографировать ещё одну страницу?';

  @override
  String get mediaDone => 'Готово';

  @override
  String get mediaAddAnotherPage => 'Добавить ещё страницу';

  @override
  String uploadProgress(int current, int total) {
    return 'Загрузка: $current из $total';
  }

  @override
  String get uploadSaving => 'Сохранение';

  @override
  String get pdfOpenFailed => 'Не удалось открыть PDF.';

  @override
  String pageNumber(int number) {
    return 'Страница $number';
  }

  @override
  String pageOf(int current, int total) {
    return 'Страница $current из $total';
  }

  @override
  String pageRemove(int number) {
    return 'Убрать страницу $number';
  }

  @override
  String get pageDelete => 'Удалить страницу';

  @override
  String get pageDeleteTitle => 'Удалить эту страницу?';

  @override
  String get pageDeleteBody =>
      'Фото этой страницы будет удалено. Отменить это нельзя.';

  @override
  String get pageLoadFailed => 'Не удалось загрузить страницу.';

  @override
  String get petsAdd => 'Добавить питомца';

  @override
  String get petSpeciesOtherShort => 'Другое';

  @override
  String get petSexFemale => 'Самка';

  @override
  String get petSexMale => 'Самец';

  @override
  String get petSexUnknown => 'Не указан';

  @override
  String get petStatusActive => 'Активный';

  @override
  String get petStatusArchived => 'В архиве';

  @override
  String get petStatusDeceased => 'Нет в живых';

  @override
  String get petNameLabel => 'Кличка';

  @override
  String get petNameRequired => 'Введите кличку';

  @override
  String get petSpeciesLabel => 'Вид';

  @override
  String get petSexLabel => 'Пол';

  @override
  String get petBreedLabel => 'Порода';

  @override
  String get petBreedHint => 'Например, мейн-кун';

  @override
  String get petBirthDateLabel => 'Дата рождения';

  @override
  String get petBirthDateApproximate => 'Дата примерная';

  @override
  String petBirthDateAbout(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Примерно $dateString';
  }

  @override
  String get petNeuteredLabel => 'Стерилизация';

  @override
  String get petNeuteredOnLabel => 'Дата стерилизации (необязательно)';

  @override
  String petNeuteredOnValue(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Да, $dateString';
  }

  @override
  String get petNeuteredBeforeBirth =>
      'Стерилизация не может быть раньше даты рождения';

  @override
  String get petColorLabel => 'Окрас';

  @override
  String get petColorHint => 'Как в паспорте, например чёрно-белый';

  @override
  String get petMarkingsLabel => 'Особые приметы';

  @override
  String get petMarkingsHint => 'Например, белое пятно на груди';

  @override
  String get petAllergiesLabel => 'Аллергии';

  @override
  String get petAllergiesHint => 'Корм, лекарства';

  @override
  String get petNotesLabel => 'Заметки';

  @override
  String get petFormAddTitle => 'Новый питомец';

  @override
  String get petFormEditTitle => 'Изменить данные';

  @override
  String get petPhotoAdd => 'Добавить фото';

  @override
  String get petPhotoChange => 'Изменить фото';

  @override
  String get petPhotoOpen => 'Открыть фото';

  @override
  String get petPhotoUploading => 'Загрузка фото';

  @override
  String get petPhotoSaveFailed =>
      'Питомец сохранён, но фото загрузить не удалось. Попробуйте ещё раз на странице питомца.';

  @override
  String get petPhotoRemoveTitle => 'Удалить фото?';

  @override
  String get petPhotoRemoveBody => 'Фото будет удалено. Отменить это нельзя.';

  @override
  String get petDetailsTitle => 'Данные';

  @override
  String get petEdit => 'Изменить данные';

  @override
  String get petDelete => 'Удалить питомца';

  @override
  String petDeleteTitle(String name) {
    return 'Удалить питомца по кличке $name?';
  }

  @override
  String get petDeleteBody =>
      'Вместе с ним удалятся данные паспорта, документы и фото. Отменить это нельзя.';

  @override
  String get petTabOverview => 'Обзор';

  @override
  String get petTabPassport => 'Паспорт';

  @override
  String get petTabDocuments => 'Документы';

  @override
  String get identifiersTitle => 'Чипы и татуировки';

  @override
  String get identifiersEmpty => 'Чипов и татуировок пока нет.';

  @override
  String get identifiersAdd => 'Добавить чип или татуировку';

  @override
  String get identifierTypeLabel => 'Тип';

  @override
  String get identifierTypeIsoChip => 'Чип ISO';

  @override
  String get identifierTypeLegacyChip => 'Чип не ISO';

  @override
  String get identifierTypeTattoo => 'Татуировка';

  @override
  String get identifierChipLabel => 'Номер чипа';

  @override
  String get identifierTattooLabel => 'Код татуировки';

  @override
  String get identifierChipDateLabel => 'Дата вживления';

  @override
  String get identifierTattooDateLabel => 'Дата нанесения';

  @override
  String get identifierLocationLabel => 'Место';

  @override
  String get identifierLocationHint => 'Например, левая сторона шеи';

  @override
  String get identifierRemove => 'Убрать из списка';

  @override
  String get identifierCodeRequired => 'Введите номер';

  @override
  String get identifierIsoHint => '15 цифр, например 276 098 100 123 456';

  @override
  String get identifierIsoLength => 'В номере чипа ISO 15 цифр';

  @override
  String get identifierIsoTestChip =>
      'Номера, которые начинаются с 999, бывают только у тестовых чипов';

  @override
  String get identifierLegacyFormat =>
      'Нужно 10 символов 0–9 и A–F или 9 цифр (AVID)';

  @override
  String get identifierLegacyHint => 'Не ISO: в поездку берите свой сканер.';

  @override
  String identifierTattooLength(int max) {
    return 'От 1 до $max букв и цифр';
  }

  @override
  String get identifierDuplicate => 'Этот номер уже есть в списке';

  @override
  String identifierChipImplantedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Вживлён $dateString';
  }

  @override
  String identifierTattooAppliedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Нанесена $dateString';
  }

  @override
  String get chipScanAction => 'Сканировать номер';

  @override
  String get chipScanTitle => 'Номер чипа';

  @override
  String get chipScanHint => 'Наведите камеру на наклейку с чипом';

  @override
  String get chipScanCameraUnavailable =>
      'Камера недоступна. Разрешите доступ к камере в настройках или выберите фото.';

  @override
  String get chipScanNotChip => 'Это не номер чипа';

  @override
  String get chipScanFromPhoto => 'С фото';

  @override
  String get chipScanFreeTier =>
      'Фото без читаемого штрихкода прочитает AI в бесплатном Gemini: только свои документы.';

  @override
  String get chipScanReading =>
      'Читаем фото… Обычно несколько секунд, иногда минуту.';

  @override
  String get chipScanPickTitle => 'На фото несколько номеров. Какой из них?';

  @override
  String get chipScanPickFound =>
      'Нашлось несколько номеров чипов. Какой из них?';

  @override
  String get chipScanNothingFound =>
      'На фото не нашлось номера чипа — введите его вручную.';

  @override
  String get chipScanCheck => 'Прочитано с фото: сверьте с паспортом.';

  @override
  String get chipScanBusy =>
      'AI сейчас занят. Попробуйте через минуту или введите номер вручную.';

  @override
  String get chipScanNoAi =>
      'На фото нет штрихкода, а AI не подключён: введите номер вручную.';

  @override
  String get chipScanRejected =>
      'AI отказался читать фото. Введите номер вручную.';

  @override
  String get passportTitle => 'Данные паспорта';

  @override
  String get passportDisclaimer =>
      'Цифровая копия — только для справки. Официальным документом остаётся бумажный паспорт.';

  @override
  String get passportEmpty =>
      'Добавьте номер паспорта, ветеринара, который его выдал, и владельцев.';

  @override
  String get passportAdd => 'Добавить данные';

  @override
  String get passportFormTitle => 'Данные паспорта';

  @override
  String get passportModelLabel => 'Образец паспорта';

  @override
  String get passportModelEu2014 => 'Паспорт ЕС (образец 2014 г.)';

  @override
  String get passportModelEu2026 => 'Паспорт ЕС (образец 2026 г.)';

  @override
  String get passportModelOther => 'Другой паспорт';

  @override
  String get passportModelNotSet => 'Не указан';

  @override
  String get passportNumberLabel => 'Номер паспорта';

  @override
  String get passportNumberHint => 'Например, DE01234567';

  @override
  String get passportNumberInvalid =>
      'До 30 латинских букв, цифр, дефисов и косых черт';

  @override
  String get passportCountryLabel => 'Страна выдачи';

  @override
  String get passportCountryHint => 'Код из двух букв, например DE';

  @override
  String get passportCountryInvalid =>
      'Нужен код страны из двух латинских букв, например DE или FR';

  @override
  String get passportIssuedOnLabel => 'Дата выдачи';

  @override
  String get passportIssuerTitle => 'Ветеринар, выдавший паспорт';

  @override
  String get passportOwnersTitle => 'Владельцы';

  @override
  String get passportOwnerTitle => 'Владелец';

  @override
  String passportOwnerNumbered(int number) {
    return 'Владелец $number';
  }

  @override
  String get passportOwnerAdd => 'Добавить владельца';

  @override
  String get passportOwnerRemove => 'Убрать владельца';

  @override
  String get passportNotesLabel => 'Заметки';

  @override
  String get passportPagesTitle => 'Страницы';

  @override
  String get passportPagesAdd => 'Добавить страницы';

  @override
  String get passportPagesRetry => 'Загрузить ещё раз';

  @override
  String get passportPagesEmpty =>
      'Сфотографируйте страницы бумажного паспорта, чтобы копия всегда была под рукой.';

  @override
  String get contactNameLabel => 'Имя';

  @override
  String get contactAddressLabel => 'Адрес';

  @override
  String get contactPhoneLabel => 'Телефон';

  @override
  String get contactEmailLabel => 'Эл. почта';

  @override
  String get documentsAdd => 'Добавить документ';

  @override
  String get documentsEmptyTitle => 'Пока нет документов';

  @override
  String get documentsEmptyBody => 'Здесь появятся анализы, рецепты и справки.';

  @override
  String get documentTypeLabel => 'Тип';

  @override
  String get documentTypePassportPage => 'Страницы паспорта';

  @override
  String get documentTypeVaccinationCertificate => 'Сертификат о вакцинации';

  @override
  String get documentTypeLabResult => 'Анализы';

  @override
  String get documentTypePrescription => 'Рецепт';

  @override
  String get documentTypeInvoice => 'Счёт';

  @override
  String get documentTypeInsurance => 'Страховка';

  @override
  String get documentTypeOther => 'Другой документ';

  @override
  String documentPageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count страницы',
      many: '$count страниц',
      few: '$count страницы',
      one: '$count страница',
    );
    return '$_temp0';
  }

  @override
  String get documentFormAddTitle => 'Новый документ';

  @override
  String get documentFormEditTitle => 'Изменить документ';

  @override
  String get documentTitleLabel => 'Название (необязательно)';

  @override
  String get documentTitleHint => 'Например, анализ крови';

  @override
  String get documentDateLabel => 'Дата документа';

  @override
  String get documentNotesLabel => 'Заметки';

  @override
  String get documentPagesTitle => 'Страницы';

  @override
  String get documentPagesAdd => 'Добавить страницы';

  @override
  String get documentPagesEmpty => 'Сфотографируйте страницы или выберите PDF.';

  @override
  String get documentPagesRequired => 'Добавьте хотя бы одну страницу';

  @override
  String documentPagesTooMany(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Не больше $max страницы',
      many: 'Не больше $max страниц',
      few: 'Не больше $max страниц',
      one: 'Не больше $max страницы',
    );
    return '$_temp0';
  }

  @override
  String get documentDetailsTitle => 'Сведения';

  @override
  String get documentAddedOnLabel => 'Добавлен';

  @override
  String get documentDelete => 'Удалить документ';

  @override
  String get documentDeleteTitle => 'Удалить этот документ?';

  @override
  String get documentDeleteBody =>
      'Все его страницы тоже удалятся. Отменить это нельзя.';

  @override
  String get petTabHealth => 'Здоровье';

  @override
  String get careKindLabel => 'Тип';

  @override
  String get careKindVaccination => 'Прививка';

  @override
  String get careKindRabiesTiter => 'Тест на антитела к бешенству';

  @override
  String get careKindDeworming => 'Обработка от глистов';

  @override
  String get careKindEchinococcus => 'Обработка от эхинококка';

  @override
  String get careKindFleaTick => 'Блохи и клещи';

  @override
  String get careKindHeartworm => 'Дирофиляриоз';

  @override
  String get careKindVetExam => 'Осмотр';

  @override
  String get careKindDental => 'Уход за зубами';

  @override
  String get careKindGrooming => 'Груминг';

  @override
  String get careKindProcedure => 'Процедура';

  @override
  String get careKindOther => 'Другое';

  @override
  String get careTargetsLabel => 'От чего защищает';

  @override
  String get vaccineTargetRabies => 'Бешенство';

  @override
  String get vaccineTargetFpv => 'Панлейкопения (FPV)';

  @override
  String get vaccineTargetFhv1 => 'Герпесвирус (FHV-1)';

  @override
  String get vaccineTargetFcv => 'Калицивирус (FCV)';

  @override
  String get vaccineTargetFelv => 'Лейкоз (FeLV)';

  @override
  String get vaccineTargetChlamydia => 'Хламидиоз';

  @override
  String get vaccineTargetCdv => 'Чума (CDV)';

  @override
  String get vaccineTargetCav2 => 'Гепатит (CAV-2)';

  @override
  String get vaccineTargetCpv2 => 'Парвовироз (CPV-2)';

  @override
  String get vaccineTargetCpiv => 'Парагрипп (CPiV)';

  @override
  String get vaccineTargetLepto => 'Лептоспироз';

  @override
  String get vaccineTargetBordetella => 'Питомниковый кашель (бордетеллёз)';

  @override
  String get vaccineTargetLyme => 'Болезнь Лайма';

  @override
  String get vaccineTargetCanineInfluenza => 'Грипп собак';

  @override
  String get vaccineTargetLeishmania => 'Лейшманиоз';

  @override
  String get intervalOneOff => 'Разовый';

  @override
  String get intervalRepeats => 'Повторяется';

  @override
  String get intervalEveryDay => 'Каждый день';

  @override
  String get intervalEveryWeek => 'Раз в неделю';

  @override
  String get intervalEveryMonth => 'Раз в месяц';

  @override
  String get intervalEveryYear => 'Раз в год';

  @override
  String intervalEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Раз в $count дня',
      many: 'Раз в $count дней',
      few: 'Раз в $count дня',
      one: 'Раз в $count день',
    );
    return '$_temp0';
  }

  @override
  String intervalEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Раз в $count недели',
      many: 'Раз в $count недель',
      few: 'Раз в $count недели',
      one: 'Раз в $count неделю',
    );
    return '$_temp0';
  }

  @override
  String intervalEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Раз в $count месяца',
      many: 'Раз в $count месяцев',
      few: 'Раз в $count месяца',
      one: 'Раз в $count месяц',
    );
    return '$_temp0';
  }

  @override
  String intervalEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Раз в $count года',
      many: 'Раз в $count лет',
      few: 'Раз в $count года',
      one: 'Раз в $count год',
    );
    return '$_temp0';
  }

  @override
  String intervalUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'дня',
      many: 'дней',
      few: 'дня',
      one: 'день',
    );
    return '$_temp0';
  }

  @override
  String intervalUnitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'недели',
      many: 'недель',
      few: 'недели',
      one: 'неделю',
    );
    return '$_temp0';
  }

  @override
  String intervalUnitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'месяца',
      many: 'месяцев',
      few: 'месяца',
      one: 'месяц',
    );
    return '$_temp0';
  }

  @override
  String intervalUnitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'года',
      many: 'лет',
      few: 'года',
      one: 'год',
    );
    return '$_temp0';
  }

  @override
  String get dueToday => 'Сегодня';

  @override
  String get dueTomorrow => 'Завтра';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Через $days дня',
      many: 'Через $days дней',
      few: 'Через $days дня',
      one: 'Через $days день',
    );
    return '$_temp0';
  }

  @override
  String dueInMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Через $months месяца',
      many: 'Через $months месяцев',
      few: 'Через $months месяца',
      one: 'Через $months месяц',
    );
    return '$_temp0';
  }

  @override
  String dueOverdueDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Просрочено на $days дня',
      many: 'Просрочено на $days дней',
      few: 'Просрочено на $days дня',
      one: 'Просрочено на $days день',
    );
    return '$_temp0';
  }

  @override
  String get careStatusOverdue => 'Просрочено';

  @override
  String get careStatusDueSoon => 'Скоро';

  @override
  String get careStatusUpcoming => 'По плану';

  @override
  String get careStatusFinished => 'Завершён';

  @override
  String get careStatusPaused => 'На паузе';

  @override
  String get healthGroupInactive => 'Завершённые и на паузе';

  @override
  String get healthPlansTitle => 'План ухода';

  @override
  String get healthPlansAdd => 'Добавить план';

  @override
  String get healthPlansEmpty =>
      'Планов пока нет. Добавьте прививки и обработки, чтобы видеть их сроки.';

  @override
  String healthInactiveToggle(int count) {
    return 'Завершённые и на паузе ($count)';
  }

  @override
  String get healthHistoryTitle => 'История';

  @override
  String get healthHistoryAdd => 'Добавить запись';

  @override
  String get healthHistoryEmpty =>
      'Записей пока нет. Перенесите прошлые прививки и обработки из бумажного паспорта.';

  @override
  String get healthFilterAll => 'Все';

  @override
  String get planDone => 'Сделано';

  @override
  String planLastDone(String date) {
    return 'Последний раз $date';
  }

  @override
  String recordPhotoCount(int count) {
    return '$count фото';
  }

  @override
  String get presetPickerTitle => 'Выберите план';

  @override
  String get presetOwnTitle => 'Свой план';

  @override
  String get presetOwnBody => 'Тип и периодичность зададите сами.';

  @override
  String get presetDogOnly => 'Только для собак';

  @override
  String get presetNoneForSpecies =>
      'Для этого животного готовых планов пока нет.';

  @override
  String get presetGroupVaccinations => 'Прививки';

  @override
  String get presetGroupDeworming => 'Обработка от глистов';

  @override
  String get presetGroupParasites => 'Блохи, клещи и дирофиляриоз';

  @override
  String get presetGroupCheckUps => 'Осмотры и уход';

  @override
  String get presetGroupTravel => 'Перед поездкой';

  @override
  String get presetCatFvrcp =>
      'Комплексная прививка (панлейкопения, герпес, калицивироз)';

  @override
  String get presetCatFvrcpNote =>
      'После серии котёнка и ревакцинации в 6 месяцев. Домашним кошкам с низким риском — раз в 3 года.';

  @override
  String get presetCatFvrcpKitten => 'Комплексная прививка, серия котёнка';

  @override
  String get presetCatFvrcpKittenNote =>
      'С 6–8 недель каждые 3–4 недели до 16–20 недель, затем ежегодный план.';

  @override
  String get presetRabies => 'Бешенство';

  @override
  String get presetRabiesNote =>
      'На этикетке вакцины срок 1 или 3 года: ориентируйтесь на дату «действует до».';

  @override
  String get presetCatFelv => 'Лейкоз кошек (FeLV)';

  @override
  String get presetCatFelvNote =>
      'Сначала тест. Две дозы с интервалом 3–4 недели, затем раз в год, если кошка гуляет.';

  @override
  String get presetCatChlamydia => 'Хламидиоз';

  @override
  String get presetCatChlamydiaNote => 'Только если кошка в группе риска.';

  @override
  String get presetDeworm => 'Обработка от глистов';

  @override
  String get presetDewormNote => 'Если риск неизвестен — не реже 4 раз в год.';

  @override
  String get presetCatDewormIndoor => 'Обработка от глистов, домашняя кошка';

  @override
  String get presetCatDewormIndoorNote =>
      'Кошкам, которые не выходят на улицу, — 1–2 раза в год.';

  @override
  String get presetCatDewormOutdoor => 'Обработка от глистов, кошка охотится';

  @override
  String get presetCatDewormOutdoorNote =>
      'Кошкам, которые гуляют и охотятся, — 4–12 раз в год.';

  @override
  String get presetCatDewormKitten => 'Обработка от глистов, котёнок';

  @override
  String get presetCatDewormKittenNote =>
      'С 3 недель каждые 2 недели до отъёма, затем раз в месяц до 6 месяцев.';

  @override
  String get presetFleaTickMonthly => 'Блохи и клещи, раз в месяц';

  @override
  String get presetCatFleaTickMonthlyNote =>
      'Средства на месяц, например Frontline, Advantage или Revolution.';

  @override
  String get presetBravecto => 'Бравекто';

  @override
  String get presetBravectoNote => 'Против некоторых клещей — 8 недель.';

  @override
  String get presetCatBravectoPlus =>
      'Бравекто Плюс (также глисты и дирофиляриоз)';

  @override
  String get presetCatBravectoPlusNote => 'По этикетке для США — 2 месяца.';

  @override
  String get presetSeresto => 'Ошейник Seresto';

  @override
  String get presetExam => 'Осмотр у ветеринара';

  @override
  String get presetCatExamNote => 'С 10 лет — раз в полгода.';

  @override
  String get presetDental => 'Осмотр зубов';

  @override
  String get presetNails => 'Стрижка когтей';

  @override
  String get presetDogDhpp =>
      'Комплексная прививка (чума, гепатит, парвовироз, парагрипп)';

  @override
  String get presetDogDhppNote =>
      'После серии щенка и ревакцинации примерно в 6 месяцев или в год.';

  @override
  String get presetDogDhppPuppy => 'Комплексная прививка, серия щенка';

  @override
  String get presetDogDhppPuppyNote =>
      'С 6–8 недель каждые 2–4 недели, не меньше чем до 16 недель, затем план раз в 3 года.';

  @override
  String get presetDogLepto => 'Лептоспироз';

  @override
  String get presetDogLeptoNote =>
      'Первые 2 дозы с интервалом 2–4 недели, затем раз в год.';

  @override
  String get presetDogKennelCough => 'Питомниковый кашель';

  @override
  String get presetDogKennelCoughNote =>
      'Собакам, которые общаются с другими собаками: передержка, дрессировка, выставки.';

  @override
  String get presetDogLyme => 'Болезнь Лайма';

  @override
  String get presetDogLymeNote => 'Там, где клещи переносят болезнь Лайма.';

  @override
  String get presetDogLeishmania => 'Лейшманиоз';

  @override
  String get presetDogLeishmaniaNote => 'Юг Европы.';

  @override
  String get presetDogDewormIndoor => 'Обработка от глистов, собака чаще дома';

  @override
  String get presetDogDewormIndoorNote =>
      'Собакам, которые в основном дома, — 1–2 раза в год.';

  @override
  String get presetDogDewormHigh => 'Обработка от глистов, высокий риск';

  @override
  String get presetDogDewormHighNote =>
      'Собакам, которые охотятся, едят улиток, траву или сырое мясо, — до 12 раз в год.';

  @override
  String get presetDogDewormPuppy => 'Обработка от глистов, щенок';

  @override
  String get presetDogDewormPuppyNote =>
      'С 14 дней каждые 2 недели до отъёма, затем раз в месяц до 6 месяцев.';

  @override
  String get presetDogFleaTickMonthlyNote =>
      'Средства на месяц, например NexGard, Simparica, Credelio или Frontline.';

  @override
  String get presetDogAdvantix => 'K9 Advantix';

  @override
  String get presetDogAdvantixNote =>
      'Содержит перметрин, он ядовит для кошек. Никогда не используйте его для кошки.';

  @override
  String get presetDogHeartworm => 'Профилактика дирофиляриоза';

  @override
  String get presetDogEchinococcus =>
      'Обработка от ленточных глистов перед поездкой';

  @override
  String get presetDogEchinococcusNote =>
      'Финляндия, Ирландия, Мальта, Северная Ирландия, Норвегия, Великобритания: за 24–120 часов до въезда. Ветеринар записывает дату и время.';

  @override
  String get presetDogExamNote => 'Пожилым собакам — раз в полгода.';

  @override
  String get planFormAddTitle => 'Новый план';

  @override
  String get planFormEditTitle => 'Изменить план';

  @override
  String get planTitleLabel => 'Что сделать';

  @override
  String get planTitleHint => 'Например, обработка от глистов';

  @override
  String get planTitleRequired => 'Укажите, что нужно сделать';

  @override
  String get planRepeatLabel => 'Как часто';

  @override
  String get planRepeats => 'Повторяется';

  @override
  String get planOnce => 'Один раз';

  @override
  String get planIntervalLabel => 'Раз в';

  @override
  String planIntervalInvalid(int max) {
    return 'Целое число от 1 до $max';
  }

  @override
  String get planLastDoneLabel => 'Последний раз (необязательно)';

  @override
  String get planLastDoneHelper => 'От этой даты посчитаем следующую.';

  @override
  String get planNextDueLabel => 'Следующий срок';

  @override
  String get planDueOnLabel => 'Срок';

  @override
  String get planNextDueComputed =>
      'Посчитано от последнего раза и интервала. Можно изменить.';

  @override
  String get dateRequired => 'Выберите дату';

  @override
  String get planDefaultProductLabel => 'Обычный препарат (необязательно)';

  @override
  String get planDefaultProductHint => 'Например, Мильбемакс';

  @override
  String get planDefaultProductHelper =>
      'Подставится, когда вы отметите выполнение.';

  @override
  String get careNotesLabel => 'Заметки';

  @override
  String get planActiveLabel => 'Действует';

  @override
  String get planActiveHelper =>
      'Выключите, чтобы поставить план на паузу: он пропадёт с экрана «Сегодня».';

  @override
  String get planDelete => 'Удалить план';

  @override
  String get planDeleteTitle => 'Удалить этот план?';

  @override
  String get planDeleteBody =>
      'Записи, уже сделанные по нему, останутся в истории. Отменить это нельзя.';

  @override
  String get careGonePlan =>
      'Этот план уже удалён — вероятно, на другом устройстве.';

  @override
  String get careGoneRecord =>
      'Эта запись уже удалена — вероятно, на другом устройстве.';

  @override
  String get careGonePet =>
      'Этот питомец уже удалён — вероятно, на другом устройстве.';

  @override
  String get planReadOnly =>
      'Этот план создан в более новой версии Collarbell. Обновите приложение, чтобы изменить его.';

  @override
  String get doneTitle => 'Отметить выполнение';

  @override
  String get donePerformedOnLabel => 'Когда сделано';

  @override
  String get careTimeLabel => 'Время';

  @override
  String get careTimeHelper => 'Правила въезда отсчитывают часы от обработки.';

  @override
  String get careProductLabel => 'Препарат';

  @override
  String get careManufacturerLabel => 'Производитель';

  @override
  String get careBatchLabel => 'Номер серии';

  @override
  String get careValidFromLabel => 'Действует с';

  @override
  String get careValidUntilLabel => 'Действует до';

  @override
  String get doneValidUntilHelper =>
      'Как на наклейке вакцины. Следующий срок будет по этой дате.';

  @override
  String get careClinicLabel => 'Клиника';

  @override
  String get careVetLabel => 'Ветеринар';

  @override
  String get doneNextTitle => 'Следующий раз';

  @override
  String doneNextFromInterval(String interval) {
    return '$interval от этой даты';
  }

  @override
  String get doneNextFromValidUntil => 'Когда закончится действие вакцины';

  @override
  String get doneNextChosen => 'Выбрано вами';

  @override
  String get doneNextFinished =>
      'Это разовый план: после отметки он завершится.';

  @override
  String get doneNextUnknown => 'Посчитается при сохранении.';

  @override
  String get doneNextChange => 'Изменить';

  @override
  String get doneNextReset => 'Вернуть расчётную дату';

  @override
  String doneSaved(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Отмечено. Следующий раз: $dateString.';
  }

  @override
  String get doneSavedFinished => 'Отмечено. План завершён.';

  @override
  String get donePhotosFailed =>
      'Выполнение отмечено, но не все фото прикрепились. Нажмите «Сохранить» ещё раз.';

  @override
  String get doneCompletedNotice =>
      'Выполнение уже отмечено. Осталось прикрепить фото.';

  @override
  String get carePhotosTitle => 'Фото';

  @override
  String get carePhotosAdd => 'Добавить фото';

  @override
  String get carePhotosEmpty =>
      'Сфотографируйте наклейку вакцины или заключение ветеринара.';

  @override
  String carePhotosTooMany(int max) {
    return 'Не больше $max фото';
  }

  @override
  String photoNumber(int number) {
    return 'Фото $number';
  }

  @override
  String photoRemove(int number) {
    return 'Убрать фото $number';
  }

  @override
  String get recordFormAddTitle => 'Новая запись';

  @override
  String get recordFormEditTitle => 'Изменить запись';

  @override
  String get recordTitleLabel => 'Название';

  @override
  String get recordTitleHint => 'Например, бешенство';

  @override
  String get recordTitleRequired => 'Укажите, что было сделано';

  @override
  String get recordPerformedOnLabel => 'Дата';

  @override
  String get recordLaboratoryLabel => 'Лаборатория';

  @override
  String get recordReportNumberLabel => 'Номер протокола';

  @override
  String get recordTiterLabel => 'Результат, МЕ/мл';

  @override
  String get recordTiterHelper => 'Для поездок в ЕС нужно не меньше 0,5 МЕ/мл.';

  @override
  String get recordTiterInvalid => 'Число от 0 до 1000';

  @override
  String get recordWeightLabel => 'Вес, кг';

  @override
  String get recordWeightInvalid => 'Вес больше 0 и не больше 200 кг';

  @override
  String get recordFitForTravel => 'Может путешествовать';

  @override
  String get recordNotFitForTravel => 'Не может путешествовать';

  @override
  String get recordValidFromInvalid => 'Не раньше даты прививки';

  @override
  String get recordValidUntilInvalid =>
      'Должно быть позже даты прививки и начала действия';

  @override
  String get recordReadOnly =>
      'Эта запись создана в более новой версии Collarbell. Обновите приложение, чтобы изменить её.';

  @override
  String get recordPhotosFailed =>
      'Запись сохранена, но не все фото прикрепились. Нажмите «Сохранить» ещё раз.';

  @override
  String get recordDelete => 'Удалить запись';

  @override
  String get recordDeleteTitle => 'Удалить эту запись?';

  @override
  String get recordDeleteBody =>
      'Её фото тоже удалятся. Срок плана, по которому её отметили, не изменится. Отменить это нельзя.';

  @override
  String get recordDetailsTitle => 'Сведения';

  @override
  String get recordSourceLabel => 'Источник';

  @override
  String get recordSourceManual => 'Внесено вручную';

  @override
  String get recordSourceScan => 'Из скана';

  @override
  String recordTiterValue(String value) {
    return '$value МЕ/мл';
  }

  @override
  String recordWeightValue(String value) {
    return '$value кг';
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

    return 'Действует $fromString – $untilString';
  }

  @override
  String careValidFromValue(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Действует с $dateString';
  }

  @override
  String careValidUntilValue(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Действует до $dateString';
  }

  @override
  String careBatchValue(String batch) {
    return 'Серия $batch';
  }

  @override
  String get timeNotSet => 'Не указано';

  @override
  String get timeClear => 'Очистить время';

  @override
  String get passportSectionRabies => 'V. Вакцинация против бешенства';

  @override
  String get passportSectionTiter => 'VI. Тест на антитела к бешенству';

  @override
  String get passportSectionEchinococcus => 'VII. Обработка от эхинококка';

  @override
  String get passportSectionTreatments => 'VIII. Другие обработки от паразитов';

  @override
  String get passportSectionOtherVaccinations => 'IX. Другие прививки';

  @override
  String get passportSectionExaminations => 'X. Клинический осмотр';

  @override
  String get passportSectionEmpty => 'Записей пока нет.';

  @override
  String get todayGroupLater => 'Позже';

  @override
  String get moreAi => 'AI';

  @override
  String get aiTitle => 'Распознавание фото';

  @override
  String get aiConnected => 'Подключено';

  @override
  String get aiNotConnected => 'Не настроено';

  @override
  String get aiChecking => 'Проверяем…';

  @override
  String get aiConnectedBody =>
      'AI читает фото страниц паспорта и документов ветеринара, а также заметки, записанные словами, и готовит черновик. Ничего не сохраняется, пока вы его не проверите.';

  @override
  String get aiNotConnectedBody =>
      'AI подключается в настройках сервера. Пока его нет, кнопки сканирования и заметок скрыты, а вносить записи вручную можно всегда.';

  @override
  String get aiFreeTierWarning =>
      'Бесплатный тариф Gemini: Google может использовать отправленные данные для улучшения своих продуктов, а читать их могут сотрудники-рецензенты. Сканируйте только свои документы.';

  @override
  String get aiModelsTitle => 'Модели';

  @override
  String get aiModelsHint =>
      'Они пробуются по порядку: если модель занята или исчерпала бесплатный лимит, фото читает следующая.';

  @override
  String get aiModelReady => 'Готова';

  @override
  String get aiModelNotReady => 'Нет ключа';

  @override
  String get aiProviderGemini => 'Google Gemini';

  @override
  String get aiProviderOpenAiCompatible => 'Сервис, совместимый с OpenAI';

  @override
  String get aiProviderOllama => 'Ollama';

  @override
  String get aiProviderOther => 'Другой сервис';

  @override
  String get aiUsageTitle => 'В этом месяце';

  @override
  String get aiUsageRequests => 'Запросы';

  @override
  String get aiUsageInputTokens => 'Отправлено токенов';

  @override
  String get aiUsageOutputTokens => 'Получено токенов';

  @override
  String get aiTestTitle => 'Проверка подключения';

  @override
  String get aiTestHint =>
      'Модель спросят, какого цвета квадрат на маленькой картинке. Это может занять до минуты.';

  @override
  String get aiTestButton => 'Проверить подключение';

  @override
  String aiTestOk(String model, String seconds) {
    return 'Работает: модель $model ответила за $seconds с.';
  }

  @override
  String get aiTestFailed => 'Не работает.';

  @override
  String get aiTestProblemNotConfigured =>
      'На сервере не подключена ни одна модель AI.';

  @override
  String get aiTestProblemBusy =>
      'Модели заняты или исчерпали бесплатный лимит. Попробуйте через несколько минут.';

  @override
  String get aiTestProblemRejected =>
      'Сервис AI отклонил запрос: возможно, ключ на сервере неверный или устарел.';

  @override
  String get aiTestProblemWrongAnswer =>
      'Модель ответила, но не увидела картинку.';

  @override
  String get scanCardTitle => 'Сканировать страницы паспорта';

  @override
  String get scanCardBody =>
      'AI прочитает с фото прививки, обработки, чипы и данные паспорта. Перед сохранением вы всё проверите.';

  @override
  String get scanCardButton => 'Сканировать';

  @override
  String get scanFromPassport => 'Сканировать паспорт';

  @override
  String scanResumeReady(String date) {
    return 'Продолжить проверку скана от $date';
  }

  @override
  String scanResumeOpen(String date) {
    return 'Скан от $date';
  }

  @override
  String get scanStatusQueued => 'В очереди';

  @override
  String get scanStatusProcessing => 'Читаем страницы…';

  @override
  String get scanStatusReady => 'Готов к проверке';

  @override
  String get scanStatusApplied => 'Сохранён';

  @override
  String get scanStatusFailed => 'Не удалось прочитать';

  @override
  String get scanStatusDiscarded => 'Удалён';

  @override
  String get scanTitlePassport => 'Скан страниц паспорта';

  @override
  String get scanTitleDocument => 'Скан документа ветеринара';

  @override
  String get scanSourceLabel => 'Что сканируем?';

  @override
  String get scanSourcePassport => 'Паспорт';

  @override
  String get scanSourceDocument => 'Другой документ';

  @override
  String scanStartPassportBody(int max) {
    return 'Сфотографируйте страницы с прививками, обработками, чипом и данными паспорта. За один раз — до $max страниц.';
  }

  @override
  String scanStartDocumentBody(int max) {
    return 'Сертификат о вакцинации, счёт или другой документ из клиники. За один раз — до $max страниц.';
  }

  @override
  String get scanStartDraftNote =>
      'AI только готовит черновик: вы проверяете каждую запись и сами решаете, что сохранить.';

  @override
  String get scanWithCamera => 'Сканировать камерой';

  @override
  String get scanChoosePhotos => 'Выбрать из фото';

  @override
  String get scanScannerUnavailable =>
      'Сканер недоступен на этом устройстве. Выберите фото страниц.';

  @override
  String scanTooManyPages(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Взяты только первые $max страницы.',
      many: 'Взяты только первые $max страниц.',
      few: 'Взяты только первые $max страницы.',
      one: 'Взята только первая $max страница.',
    );
    return '$_temp0';
  }

  @override
  String get scanStarting => 'Отправляем страницы в AI…';

  @override
  String get scanPhotosRefused =>
      'Часть фото не подошла. Нажмите «Повторить», чтобы загрузить их заново.';

  @override
  String get scanStartOver => 'Сканировать заново';

  @override
  String get scanReadingBody => 'Обычно это занимает 10–60 секунд.';

  @override
  String get scanReadingSlow =>
      'Дольше обычного: похоже, модели AI заняты. Можно подождать или вернуться позже.';

  @override
  String get scanReadingOffline => 'Нет связи с сервером. Пробуем снова…';

  @override
  String get scanReadingLeave =>
      'С этого экрана можно уйти: страницы читаются на сервере, а скан будет ждать вас на вкладке «Паспорт».';

  @override
  String get scanErrorBusy =>
      'Модели AI сейчас заняты или исчерпали бесплатный лимит. Попробуйте через несколько минут.';

  @override
  String get scanErrorNotConfigured =>
      'AI не подключён на сервере. Подключите модель в настройках сервера и отсканируйте снова. Записи всегда можно внести вручную.';

  @override
  String get scanErrorRejected =>
      'Сервис AI отклонил запрос. Возможно, ключ API на сервере неверный или устарел.';

  @override
  String get scanErrorPhotosMissing =>
      'Фото этого скана уже удалены. Отсканируйте страницы заново.';

  @override
  String get scanErrorUnexpected =>
      'При чтении страниц что-то пошло не так. Попробуйте снова.';

  @override
  String get scanClose => 'Закрыть';

  @override
  String get scanDiscardedBody => 'Из этого скана ничего не сохранено.';

  @override
  String get scanGone => 'Этого скана больше нет.';

  @override
  String get scanReviewTitle => 'Проверка скана';

  @override
  String get scanReviewIntro =>
      'AI прочитал эти записи с фото. Сверьте их с оригиналом, исправьте ошибки и снимите отметку с того, что сохранять не нужно.';

  @override
  String get scanRecordsTitle => 'Записи';

  @override
  String get scanNothingFound =>
      'На этих фото AI не нашёл ничего, что можно сохранить. Можно оставить фото или удалить скан.';

  @override
  String get scanKeepPhotosPassport => 'Сохранить фото как страницы паспорта';

  @override
  String get scanKeepPhotosPassportHelper =>
      'Они добавятся после уже сохранённых страниц.';

  @override
  String get scanKeepPhotosDocument => 'Сохранить фото как документ';

  @override
  String get scanKeepPhotosDocumentHelper =>
      'Они станут новым документом на вкладке «Документы».';

  @override
  String scanSaveSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сохранить выбранное ($count)',
      zero: 'Нечего сохранять',
    );
    return '$_temp0';
  }

  @override
  String get scanSavePhotosOnly => 'Сохранить только фото';

  @override
  String get scanDiscard => 'Удалить скан';

  @override
  String get scanDiscardTitle => 'Удалить этот скан?';

  @override
  String get scanDiscardBody =>
      'Из него ничего не сохранится, а фото удалятся.';

  @override
  String get scanDiscardConfirm => 'Удалить';

  @override
  String get scanDiscarded => 'Скан удалён';

  @override
  String get scanSelectEntry => 'Сохранить эту запись';

  @override
  String get scanBadgeAlreadySaved => 'Уже сохранено';

  @override
  String get scanBadgeRepeated => 'Повтор другой записи';

  @override
  String get scanBadgeDiffers => 'Отличается от сохранённого';

  @override
  String get scanNotRead => 'Не прочитано';

  @override
  String get scanEnterDate => 'Указать дату';

  @override
  String get scanNeedsDate => 'Укажите дату, чтобы сохранить эту запись.';

  @override
  String get scanNeedsCode => 'Укажите номер, чтобы сохранить эту запись.';

  @override
  String get scanNothingToFill => 'Здесь ничего не прочитано.';

  @override
  String get scanDateInFuture => 'Дату в будущем сохранить нельзя';

  @override
  String get scanIssueUnreadable =>
      'Не удалось прочитать. Впишите по оригиналу.';

  @override
  String get scanIssueAmbiguous =>
      'День и месяц могли перепутаться. Сверьте с оригиналом.';

  @override
  String scanSwapTo(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Заменить на $dateString';
  }

  @override
  String get scanIssueInFuture => 'Эта дата в будущем. Проверьте её.';

  @override
  String get scanIssueEndsBeforeStart =>
      '«Действует до» не позже даты прививки. Проверьте.';

  @override
  String get scanIssueInvalidFormat =>
      'Похоже на ошибку. Сверьте с оригиналом.';

  @override
  String get scanIssueAlreadySaved => 'Такая запись уже есть в истории.';

  @override
  String get scanIssueAlreadySavedCode => 'У питомца уже есть этот номер.';

  @override
  String get scanIssueRepeated => 'Такая же запись есть на другом фото.';

  @override
  String get scanIssueOther => 'Проверьте это значение.';

  @override
  String scanSavedValue(String value) {
    return 'Сохранено: $value';
  }

  @override
  String scanReadOnPage(int number) {
    return 'Прочитано на странице $number';
  }

  @override
  String scanEvidence(String text) {
    return '«$text»';
  }

  @override
  String scanPlanDone(String title) {
    return 'Отметить выполнение в плане «$title»';
  }

  @override
  String get scanPlanLink => 'Отметить выполнение в плане';

  @override
  String get scanPlanHint =>
      'План сдвинется, только если эта запись новее его последней отметки «Сделано».';

  @override
  String get scanPlanChange => 'Выбрать другой план';

  @override
  String get scanPlanPickTitle => 'В каком плане отметить выполнение?';

  @override
  String get scanPlanNone => 'Без плана';

  @override
  String get scanEntryFix => 'Исправьте эту запись или снимите с неё отметку.';

  @override
  String get scanEditRecordTitle => 'Изменить запись';

  @override
  String get scanEditIdentifierTitle => 'Изменить чип или татуировку';

  @override
  String get scanEditPassportTitle => 'Изменить данные паспорта';

  @override
  String get scanEditDone => 'Готово';

  @override
  String get scanPassportKeeps =>
      'Пустое поле не меняет то, что уже сохранено, а изменённое здесь значение заменит сохранённое.';

  @override
  String scanSavedRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'сохранено $count записи',
      many: 'сохранено $count записей',
      few: 'сохранены $count записи',
      one: 'сохранена $count запись',
    );
    return '$_temp0';
  }

  @override
  String scanSavedPlans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'обновлено $count плана',
      many: 'обновлено $count планов',
      few: 'обновлены $count плана',
      one: 'обновлён $count план',
    );
    return '$_temp0';
  }

  @override
  String scanSavedIdentifiers(int count) {
    return 'чипы и татуировки: +$count';
  }

  @override
  String get scanSavedPassport => 'данные паспорта обновлены';

  @override
  String get scanSavedPhotosPassport => 'фото добавлены к страницам паспорта';

  @override
  String get scanSavedPhotosDocument => 'фото сохранены как документ';

  @override
  String get scanSavedNothing => 'Ничего не сохранено';

  @override
  String get scanPassportFillIn => 'Добавить в данные паспорта';

  @override
  String get scanSavedBeforeDrop => 'сохранено до обрыва связи';

  @override
  String get scanSavedNoDiscard => 'этот скан уже был сохранён';

  @override
  String get scanSaveUnconfirmed =>
      'Не удалось узнать, сохранилось ли. Проверьте подключение и сохраните ещё раз: дважды ничего не сохранится.';

  @override
  String get scanDateTooEarly => 'Дата — не раньше 1990 года';

  @override
  String scanTooManyIdentifiers(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'У питомца может быть не больше $max чипов и татуировок.',
      many: 'У питомца может быть не больше $max чипов и татуировок.',
      few: 'У питомца может быть не больше $max чипов и татуировок.',
      one: 'У питомца может быть не больше $max чипа или татуировки.',
    );
    return '$_temp0';
  }

  @override
  String scanSkippedIdentifiers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count номера уже были у питомца',
      many: '$count номеров уже были у питомца',
      few: '$count номера уже были у питомца',
      one: '$count номер уже был у питомца',
    );
    return '$_temp0';
  }

  @override
  String scanSavedPassportFields(String fields) {
    return 'данные паспорта обновлены: $fields';
  }

  @override
  String get scanPassportFieldNumber => 'номер';

  @override
  String get scanPassportFieldCountry => 'страна';

  @override
  String get scanPassportFieldIssuedOn => 'дата выдачи';

  @override
  String get scanPassportReplace => 'Заменить сохранённое';

  @override
  String get scanPassportSame => 'Уже есть в данных паспорта';

  @override
  String get scanPassportNothingNew =>
      'Ничего нового: в данных паспорта это уже есть.';

  @override
  String get scanDismiss => 'Убрать';

  @override
  String get aiCheckFailed => 'Не удалось проверить';

  @override
  String get scanLeaveTitle => 'Уйти без сохранения?';

  @override
  String get scanLeaveBody =>
      'Изменения на этом экране пропадут. Скан останется на вкладке «Паспорт», к нему можно вернуться.';

  @override
  String get scanLeaveConfirm => 'Уйти';

  @override
  String get scanTitleRabiesVaccination => 'Вакцинация против бешенства';

  @override
  String get scanPassportTurnOnReplace =>
      'Включите «Заменить сохранённое» у того, что нужно изменить.';

  @override
  String get petTabFeeding => 'Кормление';

  @override
  String get feedingTitle => 'Расписание кормления';

  @override
  String get feedingAdd => 'Добавить';

  @override
  String get feedingEmpty =>
      'Добавьте время кормления: в это время придёт напоминание, а на экране «Сегодня» появится кнопка «Покормили».';

  @override
  String get feedingEveryDay => 'Каждый день';

  @override
  String get feedingPaused => 'На паузе';

  @override
  String get feedingAddTitle => 'Новое расписание';

  @override
  String get feedingEditTitle => 'Изменить кормление';

  @override
  String get feedingDelete => 'Удалить расписание';

  @override
  String get feedingDeleteTitle => 'Удалить расписание кормления?';

  @override
  String get feedingDeleteBody =>
      'Напоминания по нему прекратятся, отметки «покормили» тоже удалятся.';

  @override
  String get feedingGone => 'Это расписание удалили на другом устройстве.';

  @override
  String get feedingReadOnly =>
      'Расписание создано в более новой версии приложения. Обновите приложение, чтобы изменить его.';

  @override
  String get feedingTimesLabel => 'Время';

  @override
  String get feedingTimeAdd => 'Добавить время';

  @override
  String get feedingTimeRemove => 'Убрать это время';

  @override
  String get feedingTimesRequired => 'Добавьте хотя бы одно время';

  @override
  String feedingTimesTooMany(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Не больше $max раза',
      many: 'Не больше $max раз',
      few: 'Не больше $max раз',
      one: 'Не больше $max раза',
    );
    return '$_temp0';
  }

  @override
  String get feedingDaysLabel => 'Дни';

  @override
  String get feedingDaysRequired => 'Выберите хотя бы один день';

  @override
  String get feedingFoodLabel => 'Корм';

  @override
  String get feedingFoodHint => 'Например, Royal Canin Sterilised';

  @override
  String get feedingPortionLabel => 'Порция';

  @override
  String get feedingAmountHint => '40';

  @override
  String get feedingAmountInvalid => 'Число больше 0 и до 10 000';

  @override
  String get feedingActiveLabel => 'Действует';

  @override
  String get feedingActiveHelper =>
      'Расписание на паузе не напоминает и не показывается на «Сегодня».';

  @override
  String get feedingRemindersNote =>
      'В это время на телефоны семьи придёт напоминание. Выключить напоминания о кормлении можно в «Ещё → Уведомления».';

  @override
  String portionGrams(String amount) {
    return '$amount г';
  }

  @override
  String portionMilliliters(String amount) {
    return '$amount мл';
  }

  @override
  String portionPieces(String amount) {
    return '$amount шт.';
  }

  @override
  String get portionUnitGrams => 'г';

  @override
  String get portionUnitMilliliters => 'мл';

  @override
  String get portionUnitPieces => 'шт.';

  @override
  String get todayFeedingTitle => 'Кормление';

  @override
  String get feedingFed => 'Покормили';

  @override
  String get feedingAll => 'Покормить всех';

  @override
  String feedingAlreadyMarked(String name, String time) {
    return 'Уже отмечено: $name, $time';
  }

  @override
  String feedingFedBy(String name, String time) {
    return '$name, $time';
  }

  @override
  String get feedingSomeoneElse => 'кто-то другой';

  @override
  String feedingSkippedAt(String time) {
    return 'Пропущено, $time';
  }

  @override
  String feedingUndoTitle(String pet) {
    return '$pet: снять отметку?';
  }

  @override
  String get feedingUndoBody =>
      'Кормление снова будет не отмечено, и напоминание о нём может прийти.';

  @override
  String get feedingUndo => 'Снять';

  @override
  String get todayVisitsTitle => 'Визиты';

  @override
  String get todayVisitsAll => 'Все визиты';

  @override
  String get todayVisitsEmpty => 'Визитов не запланировано.';

  @override
  String get todayVisitMarkHowItWent => 'Отметьте, как прошёл';

  @override
  String get visitsTitle => 'Визиты';

  @override
  String get visitsPlanned => 'Запланированные';

  @override
  String get visitsPast => 'Прошедшие и отменённые';

  @override
  String get visitsEmptyTitle => 'Визитов пока нет';

  @override
  String get visitsEmptyBody =>
      'Добавьте визит к ветеринару или грумеру: напомним за сутки и за 2 часа.';

  @override
  String get visitAdd => 'Записать визит';

  @override
  String get visitAddTitle => 'Новый визит';

  @override
  String get visitEditTitle => 'Изменить визит';

  @override
  String get visitReadOnly =>
      'Визит создан в более новой версии приложения. Обновите приложение, чтобы изменить его.';

  @override
  String get visitGone => 'Этот визит удалили на другом устройстве.';

  @override
  String get visitTypeLabel => 'Куда';

  @override
  String get visitTypeVet => 'Ветеринар';

  @override
  String get visitTypeGrooming => 'Грумер';

  @override
  String get visitTypeTraining => 'Дрессировка';

  @override
  String get visitTypeOther => 'Другое';

  @override
  String get visitTitleLabel => 'Зачем';

  @override
  String get visitTitleHint => 'Например, прививка от бешенства';

  @override
  String get visitDateLabel => 'Дата';

  @override
  String get visitTimeLabel => 'Время';

  @override
  String get visitTimeRequired => 'Укажите время';

  @override
  String get visitPetsLabel => 'Питомцы';

  @override
  String get visitPetsRequired => 'Выберите хотя бы одного питомца';

  @override
  String get visitLocationLabel => 'Где';

  @override
  String get visitLocationHint => 'Клиника или адрес';

  @override
  String get visitRemindersLabel => 'Напомнить';

  @override
  String get visitRemindersNone => 'Без напоминаний';

  @override
  String get visitRemindAtStart => 'В момент начала';

  @override
  String get visitRemindWeek => 'За неделю';

  @override
  String visitRemindWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count недели',
      many: 'За $count недель',
      few: 'За $count недели',
      one: 'За $count неделю',
    );
    return '$_temp0';
  }

  @override
  String get visitRemindDay => 'За сутки';

  @override
  String visitRemindDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count дня',
      many: 'За $count дней',
      few: 'За $count дня',
      one: 'За $count день',
    );
    return '$_temp0';
  }

  @override
  String get visitRemindHour => 'За час';

  @override
  String visitRemindHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count часа',
      many: 'За $count часов',
      few: 'За $count часа',
      one: 'За $count час',
    );
    return '$_temp0';
  }

  @override
  String visitRemindMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count минуты',
      many: 'За $count минут',
      few: 'За $count минуты',
      one: 'За $count минуту',
    );
    return '$_temp0';
  }

  @override
  String visitToday(String time) {
    return 'Сегодня в $time';
  }

  @override
  String visitTomorrow(String time) {
    return 'Завтра в $time';
  }

  @override
  String visitYesterday(String time) {
    return 'Вчера в $time';
  }

  @override
  String visitOnDate(DateTime date, String time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMEd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString в $time';
  }

  @override
  String get visitStatusPlanned => 'Запланирован';

  @override
  String get visitStatusDone => 'Состоялся';

  @override
  String get visitStatusCancelled => 'Отменён';

  @override
  String get visitCancel => 'Отменить визит';

  @override
  String get visitCancelTitle => 'Отменить визит?';

  @override
  String get visitCancelBody =>
      'Напоминания о нём прекратятся. Позже визит можно запланировать снова.';

  @override
  String get visitCancelledNote => 'Визит отменён.';

  @override
  String get visitPlanAgain => 'Запланировать снова';

  @override
  String get visitDelete => 'Удалить';

  @override
  String get visitDeleteTitle => 'Удалить визит?';

  @override
  String get visitDeleteBody =>
      'Записи, сделанные по визиту, останутся в истории питомцев.';

  @override
  String get visitDone => 'Визит состоялся';

  @override
  String get visitDoneTitle => 'Как прошёл визит?';

  @override
  String get visitDoneWriteRecord => 'Записать в историю ухода';

  @override
  String get visitDoneWriteRecordHelper =>
      'У каждого питомца визита появится запись этого вида.';

  @override
  String visitDonePlan(String plan) {
    return 'Отметить «$plan» выполненным';
  }

  @override
  String get visitDoneNotesLabel => 'Заметки';

  @override
  String get visitDoneNotesHint => 'Что сказал врач';

  @override
  String get visitDoneSaved => 'Сохранено: визит состоялся.';

  @override
  String visitDoneSavedPlans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сохранено. Перенесено $count плана.',
      many: 'Сохранено. Перенесено $count планов.',
      few: 'Сохранено. Перенесено $count плана.',
      one: 'Сохранено. Перенесён $count план.',
    );
    return '$_temp0';
  }

  @override
  String get visitResultTitle => 'Результат';

  @override
  String get visitNoRecords => 'Записей не сделано.';

  @override
  String get visitRecordsOfPet => 'Записи в истории ухода';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get moreNotificationsHelper => 'Напоминания, проверка, история';

  @override
  String get notificationsChannelGeneral => 'Прочее';

  @override
  String get notificationsKinds => 'Напоминания';

  @override
  String get notificationsKindFeeding => 'Кормление';

  @override
  String get notificationsKindFeedingHelper => 'В каждое время кормления';

  @override
  String get notificationsKindCare => 'Прививки и обработки';

  @override
  String get notificationsKindCareHelper =>
      'За 7 дней, за день и в день срока, в 10:00; повторно, если просрочено';

  @override
  String get notificationsKindVisits => 'Визиты';

  @override
  String get notificationsKindVisitsHelper => 'Как указано у визита';

  @override
  String get notificationsReady => 'Напоминания приходят на этот телефон.';

  @override
  String get notificationsIphoneLater =>
      'На iPhone напоминания появятся позже: для них нужен платный аккаунт разработчика Apple. Пока всё, что пора сделать, видно на экране «Сегодня».';

  @override
  String get notificationsDenied =>
      'Уведомления для Collarbell выключены в настройках телефона.';

  @override
  String get notificationsNotAsked =>
      'Уведомления пока не разрешены. Collarbell спросит, когда вы добавите первое кормление, визит или план, или разрешите сейчас.';

  @override
  String get pushAskTitle => 'Разрешить уведомления?';

  @override
  String get pushAskBody =>
      'Так Collarbell напомнит о кормлении, прививках и визитах, даже когда приложение закрыто.';

  @override
  String get pushAskLater => 'Не сейчас';

  @override
  String get pushAskAllow => 'Разрешить уведомления';

  @override
  String get pushOffNotice => 'Уведомления выключены: напоминания не придут.';

  @override
  String get notificationsOpenSettings => 'Открыть настройки';

  @override
  String get notificationsNoToken =>
      'У телефона пока нет адреса для уведомлений: нужны сервисы Google Play и интернет.';

  @override
  String get notificationsRegisterFailed =>
      'Не получилось связаться с сервером, чтобы включить напоминания на этом телефоне.';

  @override
  String get notificationsServerNotReady =>
      'Сервер пока не может отправлять уведомления: у него нет ключа Firebase.';

  @override
  String get notificationsTest => 'Прислать проверочное уведомление';

  @override
  String get notificationsTestSent =>
      'Отправлено. Уведомление придёт через несколько секунд.';

  @override
  String get notificationsTestNoDevices =>
      'Пока ни один телефон не подключён к уведомлениям.';

  @override
  String get notificationsTestFailed =>
      'Firebase не доставил уведомление. Попробуйте позже.';

  @override
  String get notificationsUpcoming => 'Ближайшие напоминания';

  @override
  String get notificationsUpcomingEmpty => 'В ближайшие 7 дней ничего.';

  @override
  String get notificationsRecent => 'Недавние напоминания';

  @override
  String get notificationsRecentEmpty => 'За последние 7 дней ничего.';

  @override
  String notificationsWhenToday(String time) {
    return 'Сегодня в $time';
  }

  @override
  String notificationsWhenTomorrow(String time) {
    return 'Завтра, $time';
  }

  @override
  String notificationsWhenYesterday(String time) {
    return 'Вчера, $time';
  }

  @override
  String get reminderSent => 'отправлено';

  @override
  String get reminderExpired => 'опоздало: сервер был выключен';

  @override
  String get reminderFailed => 'Firebase не доставил';

  @override
  String get reminderSkipped => 'не отправлено';

  @override
  String get reminderSkippedNotNeeded => 'не нужно: уже сделано';

  @override
  String get reminderSkippedNoPhones => 'некому отправить';

  @override
  String get reminderSkippedServer =>
      'не отправлено: у сервера нет ключа Firebase';

  @override
  String feedingFedAtSemantics(String time) {
    return 'Покормлено в $time';
  }

  @override
  String get feedingUndoHint => 'Нажмите, чтобы снять отметку';

  @override
  String feedingMarkedBy(String name) {
    return 'Отметка: $name';
  }

  @override
  String feedingSkipTitle(String pet) {
    return '$pet: пропустить кормление?';
  }

  @override
  String feedingSkipBody(String time) {
    return 'Кормление в $time будет отмечено как пропущенное, без напоминания.';
  }

  @override
  String get feedingSkip => 'Пропустить';

  @override
  String get notificationsUnavailable =>
      'Уведомления на этом телефоне недоступны: не запустился Firebase.';

  @override
  String get visitDoneNotPossible =>
      'Визит нельзя отметить: его отменили или он ещё не состоялся.';

  @override
  String get notificationsKindSupplies => 'Запасы';

  @override
  String get notificationsKindSuppliesHelper => 'Когда пора купить, в 10:00';

  @override
  String get barcodeCameraUnavailable =>
      'Камера недоступна. Разрешите доступ к камере в настройках или введите цифры вручную.';

  @override
  String get barcodeFind => 'Найти';

  @override
  String get barcodeScanHint => 'Наведите камеру на штрихкод на упаковке';

  @override
  String get barcodeScanTitle => 'Штрихкод';

  @override
  String get barcodeTorch => 'Фонарик';

  @override
  String get barcodeType => 'Ввести цифры';

  @override
  String get barcodeTypeHint => 'Цифры под штрихкодом';

  @override
  String get feedingSupplyHelper =>
      'Порции этого кормления будут считаться расходом корма в запасах';

  @override
  String get feedingSupplyLabel => 'Корм из запасов';

  @override
  String get feedingSupplyNone => 'Не из запасов';

  @override
  String get productScanAddPhoto => 'Добавить фото';

  @override
  String get productScanBusy =>
      'AI сейчас занят. Попробуйте через минуту или заполните вручную.';

  @override
  String get productScanByHand => 'Заполнить вручную';

  @override
  String get productScanCameraFailed => 'Не удалось открыть камеру';

  @override
  String productScanCode(String code) {
    return 'Штрихкод $code';
  }

  @override
  String get productScanExisting => 'Этот товар уже есть в запасах';

  @override
  String get productScanFreeTier =>
      'Фото уходят в бесплатный Gemini: на них не должно быть личных данных.';

  @override
  String get productScanLookingUp => 'Ищем товар…';

  @override
  String get productScanNoAi => 'AI не подключён: заполните данные вручную.';

  @override
  String get productScanNotProduct =>
      'Это не штрихкод товара. Отсканируйте штрихкод на упаковке.';

  @override
  String get productScanOpenExisting => 'Открыть товар';

  @override
  String get productScanPartly =>
      'Найдено не всё: нет размера упаковки. Сфотографируйте упаковку или заполните вручную.';

  @override
  String productScanPhoto(int number) {
    return 'Фото $number';
  }

  @override
  String get productScanPhotosHint =>
      'Сфотографируйте лицевую сторону и сторону с весом и составом — до 3 фото.';

  @override
  String get productScanRead => 'Прочитать';

  @override
  String get productScanReading =>
      'Читаем упаковку… Обычно это несколько секунд, иногда минута-две.';

  @override
  String get productScanRejected =>
      'AI отказался читать фото. Заполните данные вручную.';

  @override
  String get productScanTakePhotos => 'Сфотографировать упаковку';

  @override
  String get productScanTitle => 'Новый товар';

  @override
  String get productScanUnknown => 'Товар с этим штрихкодом не найден.';

  @override
  String get suppliesInStock => 'В запасе';

  @override
  String get suppliesNotBought => 'Больше не покупаем';

  @override
  String get suppliesSoon => 'Скоро закончится';

  @override
  String get suppliesToBuy => 'Купить';

  @override
  String get supplyActiveHelper =>
      'Выключите, если больше не покупаете: напоминаний не будет, история останется';

  @override
  String get supplyActiveLabel => 'Покупаем';

  @override
  String get supplyAdd => 'Добавить';

  @override
  String get supplyAddByBarcode => 'Сканировать штрихкод';

  @override
  String get supplyAddByBarcodeHelper => 'Найдём товар в базах';

  @override
  String get supplyAddByHand => 'Заполнить вручную';

  @override
  String get supplyAddByPhoto => 'Сфотографировать упаковку';

  @override
  String get supplyAddByPhotoHelper =>
      'AI прочитает название, вес и калорийность';

  @override
  String get supplyAddTitle => 'Новый товар';

  @override
  String get supplyBarcodeInvalid => 'Проверьте цифры штрихкода';

  @override
  String get supplyBarcodeLabel => 'Штрихкод';

  @override
  String get supplyBarcodeTaken => 'Товар с этим штрихкодом уже есть в запасах';

  @override
  String get supplyBought => 'Купили';

  @override
  String get supplyBrandLabel => 'Бренд';

  @override
  String supplyBuyBy(String date, String delivery) {
    return 'Купить до $date · доставка $delivery';
  }

  @override
  String get supplyTimeToBuy => 'Пора купить';

  @override
  String get supplyCategoryDryFood => 'Сухой корм';

  @override
  String get supplyCategoryLabel => 'Что это';

  @override
  String get supplyCategoryLitter => 'Наполнитель';

  @override
  String get supplyCategoryMedication => 'Препарат';

  @override
  String get supplyCategoryOther => 'Другое';

  @override
  String get supplyCategoryTreats => 'Лакомства';

  @override
  String get supplyCategoryWetFood => 'Влажный корм';

  @override
  String get supplyCount => 'Уточнить остаток';

  @override
  String get supplyCountSave => 'Сохранить';

  @override
  String get supplyCountSaved => 'Остаток сохранён';

  @override
  String supplyCountTitle(String name) {
    return 'Сколько осталось: $name';
  }

  @override
  String supplyCountTotal(String amount) {
    return 'Всего ≈ $amount';
  }

  @override
  String get supplyDelete => 'Удалить товар';

  @override
  String get supplyDeleteBody =>
      'Покупки и остаток удалятся. Кормления сохранят название корма.';

  @override
  String supplyDeleteTitle(String name) {
    return 'Удалить $name?';
  }

  @override
  String get supplyDetailsTitle => 'О товаре';

  @override
  String supplyDoses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дозы',
      many: '$count доз',
      few: '$count дозы',
      one: '$count доза',
    );
    return '$_temp0';
  }

  @override
  String supplyDosesFraction(String amount) {
    return '$amount дозы';
  }

  @override
  String get supplyEditTitle => 'Изменить товар';

  @override
  String supplyEnoughFor(String lasts) {
    return 'Хватит $lasts';
  }

  @override
  String get supplyEntryByMe => 'вы';

  @override
  String supplyEntryCount(String amount) {
    return 'Осталось $amount';
  }

  @override
  String supplyEntryPurchase(String amount) {
    return 'Куплено +$amount';
  }

  @override
  String get supplyEntryUndo => 'Отменить';

  @override
  String get supplyEntryUndoBody => 'Запись удалится, прогноз пересчитается.';

  @override
  String get supplyEntryUndoTitle => 'Отменить запись?';

  @override
  String get supplyFeedingNotCounted =>
      'Порция не указана или в других единицах — не учитывается';

  @override
  String supplyFeedingPortion(String portion, String times) {
    return '$portion × $times в день';
  }

  @override
  String get supplyFeedingsTitle => 'Кормления с этим кормом';

  @override
  String get supplyFromCatalog => 'Этот товар уже сохраняли. Проверьте данные.';

  @override
  String get supplyFromOpenPetFoodFacts =>
      'Данные из Open Pet Food Facts (лицензия ODbL). Проверьте их.';

  @override
  String get supplyFromPhotos => 'Прочитано с фото упаковки. Проверьте данные.';

  @override
  String get supplyFromUpcItemDb =>
      'Название из базы UPCitemdb. Добавьте размер упаковки.';

  @override
  String get supplyGone => 'Этого товара больше нет';

  @override
  String get supplyHistoryEmpty => 'Покупок и уточнений остатка пока нет';

  @override
  String get supplyHistoryTitle => 'Покупки и остатки';

  @override
  String get supplyInactive => 'Больше не покупаем';

  @override
  String get supplyInactiveNote =>
      'Вы больше не покупаете этот товар: напоминаний о нём нет.';

  @override
  String supplyKcal(int kcal) {
    return '$kcal ккал/кг';
  }

  @override
  String get supplyKcalHelper => 'С упаковки: ккал на кг (ккал на 100 г × 10)';

  @override
  String get supplyKcalHint => '3900';

  @override
  String get supplyKcalInvalid => 'Число от 1 до 10 000';

  @override
  String get supplyKcalLabel => 'Калорийность, ккал/кг';

  @override
  String supplyKg(String amount) {
    return '$amount кг';
  }

  @override
  String supplyLastsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'примерно на $count дня',
      many: 'примерно на $count дней',
      few: 'примерно на $count дня',
      one: 'примерно на $count день',
    );
    return '$_temp0';
  }

  @override
  String get supplyLastsLessThanDay => 'меньше чем на день';

  @override
  String supplyLeadTimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get supplyLeadTimeHelper =>
      'За столько дней до конца придёт напоминание купить';

  @override
  String supplyLeadTimeInvalid(int max) {
    return 'От 0 до $max дней';
  }

  @override
  String get supplyLeadTimeLabel => 'Дней на доставку';

  @override
  String supplyLeftNoUsage(String amount) {
    return 'Осталось $amount · расход не задан';
  }

  @override
  String get supplyLess => 'Меньше';

  @override
  String supplyLiters(String amount) {
    return '$amount л';
  }

  @override
  String get supplyMore => 'Больше';

  @override
  String get supplyNameHint => 'Например, Royal Canin Sterilised 37';

  @override
  String get supplyNameLabel => 'Название';

  @override
  String get supplyNameRequired => 'Введите название';

  @override
  String get supplyNoFeedings =>
      'Этот корм пока не выбран ни в одном кормлении. Откройте кормление питомца и выберите его в «Корм из запасов».';

  @override
  String get supplyNoStock => 'Остаток не указан';

  @override
  String get supplyNoStockHint =>
      'Отметьте покупку или уточните остаток — и появится прогноз.';

  @override
  String get supplyNoUsage => 'Расход не задан';

  @override
  String get supplyNoUsageFeedingHint =>
      'Выберите этот корм в кормлениях питомцев — расход посчитается из порций.';

  @override
  String get supplyNoUsageManualHint =>
      'Укажите в настройках товара, на сколько дней хватает упаковки.';

  @override
  String get supplyNotPetProduct =>
      'Похоже, на фото не товар для питомцев. Проверьте данные.';

  @override
  String get supplyNothingLeft => 'Закончился';

  @override
  String supplyOpenPackage(int percent) {
    return 'В открытой упаковке: ~$percent%';
  }

  @override
  String get supplyOpenStore => 'Открыть магазин';

  @override
  String get supplyOutOfStock => 'Закончился';

  @override
  String get supplyPackageLabel => 'Упаковка';

  @override
  String supplyPackages(String packages) {
    return '≈ $packages уп.';
  }

  @override
  String supplyPackagesBought(String package) {
    return 'Упаковок по $package';
  }

  @override
  String supplyPackagesClosed(String package) {
    return 'Закрытых упаковок по $package';
  }

  @override
  String get supplyPlanAdd => 'Добавить план';

  @override
  String get supplyPlanNo => 'Не нужно';

  @override
  String get supplyPlanOfferBody =>
      'Добавить план обработки с этим интервалом? Напоминание придёт, когда подойдёт срок.';

  @override
  String supplyPlanOfferTitle(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'Защищает $weeks недели',
      many: 'Защищает $weeks недель',
      few: 'Защищает $weeks недели',
      one: 'Защищает $weeks неделю',
    );
    return '$_temp0';
  }

  @override
  String get supplyPlanWhichPet => 'Для кого план?';

  @override
  String get supplyPurchaseSave => 'Сохранить покупку';

  @override
  String get supplyPurchaseSaved => 'Покупка сохранена';

  @override
  String supplyPurchaseTitle(String name) {
    return 'Купили: $name';
  }

  @override
  String supplyRanOutOn(String date) {
    return 'Закончился около $date';
  }

  @override
  String get supplyReadOnly =>
      'Этот товар изменён в более новой версии приложения. Обновите приложение, чтобы его редактировать.';

  @override
  String supplyRemaining(String amount, String packages) {
    return 'Осталось ≈ $amount ($packages)';
  }

  @override
  String supplyRunsOutOn(String date) {
    return 'Закончится около $date';
  }

  @override
  String get supplySizeHint => '2';

  @override
  String get supplySizeInvalid => 'Число больше 0';

  @override
  String supplySoonLeft(String date, String lasts) {
    return 'Купить до $date · хватит $lasts';
  }

  @override
  String get supplyStockNowHelper =>
      'Обычно это одна закрытая упаковка, которую только что купили';

  @override
  String get supplyStockNowLabel => 'Указать, сколько есть сейчас';

  @override
  String get supplyStoreFailed => 'Не удалось открыть ссылку';

  @override
  String get supplyStoreHelper =>
      'Ссылка на товар в магазине — чтобы быстро заказать';

  @override
  String get supplyStoreLabel => 'Где купить';

  @override
  String get supplyUnitDoses => 'доз';

  @override
  String get supplyUnitKg => 'кг';

  @override
  String get supplyUnitLiters => 'л';

  @override
  String get supplyUrlInvalid =>
      'Нужна ссылка, которая начинается с https:// или http://';

  @override
  String get supplyUsageByHand => 'Вручную';

  @override
  String get supplyUsageDaysSuffix => 'дн.';

  @override
  String get supplyUsageFeeding => 'По кормлениям';

  @override
  String get supplyUsageFeedingHelper =>
      'Расход считается из порций кормлений, где выбран этот корм.';

  @override
  String supplyUsageFromFeeding(String amount) {
    return 'Расход $amount в день — по кормлениям';
  }

  @override
  String get supplyUsageInvalid => 'Число больше 0';

  @override
  String get supplyUsageLabel => 'Расход';

  @override
  String supplyUsageManual(String amount) {
    return 'Расход $amount в день — задан вручную';
  }

  @override
  String get supplyUsagePackageLasts => 'Упаковки хватает';

  @override
  String supplyUsagePackageLastsHelper(String package) {
    return 'Сколько дней хватает одной упаковки ($package)';
  }

  @override
  String get supplyUsagePerDay => 'В день';

  @override
  String get supplyUsagePerDayHelper => 'Сколько уходит за день';

  @override
  String get todayShoppingAll => 'Все запасы';

  @override
  String get todayShoppingTitle => 'Купить';

  @override
  String get productScanFromLibrary => 'Из галереи';

  @override
  String supplyBatch(String batch) {
    return 'Серия $batch';
  }

  @override
  String supplyExpires(String date) {
    return 'годен до $date';
  }

  @override
  String get productScanExistingInactive =>
      'Вы отмечали, что больше его не покупаете: покупка вернёт его в запасы.';

  @override
  String get moreHousehold => 'Группа';

  @override
  String get householdDefaultName => 'Мой дом';

  @override
  String get householdRoleOwner => 'Владелец';

  @override
  String get householdRoleMember => 'Участник';

  @override
  String get householdRoleHelper => 'Помощник';

  @override
  String get householdRoleOwnerHelper =>
      'Всё, а также люди и настройки группы.';

  @override
  String get householdRoleMemberHelper =>
      'Всё с питомцами и записями, кроме людей группы.';

  @override
  String get householdRoleHelperHelper =>
      'Видит всё и отмечает кормления, «Сделано», визиты и покупки.';

  @override
  String householdMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count человека',
      many: '$count человек',
      few: '$count человека',
      one: '$count человек',
    );
    return '$_temp0';
  }

  @override
  String get householdSwitch => 'Сменить группу';

  @override
  String get householdPeople => 'Участники и приглашения';

  @override
  String get householdSwitchTitle => 'Ваши группы';

  @override
  String get householdCurrent => 'Текущая группа';

  @override
  String get householdCreate => 'Создать группу';

  @override
  String get householdJoin => 'Вступить по коду';

  @override
  String get householdCreateTitle => 'Новая группа';

  @override
  String get householdNameLabel => 'Название';

  @override
  String get householdNameHint => 'Например, Офис';

  @override
  String get householdNameRequired => 'Дайте группе название.';

  @override
  String get householdCreateAction => 'Создать';

  @override
  String householdSwitched(String name) {
    return 'Теперь вы в группе «$name».';
  }

  @override
  String householdLeftNotice(String name) {
    return 'Вас больше нет в группе «$name».';
  }

  @override
  String get householdLeftNoticeUnnamed => 'Вас больше нет в той группе.';

  @override
  String get householdMembers => 'Участники';

  @override
  String get householdYou => 'это вы';

  @override
  String get householdNoName => 'Без имени';

  @override
  String get householdInvite => 'Пригласить';

  @override
  String get householdInvites => 'Приглашения';

  @override
  String householdInviteUntil(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'до $dateString';
  }

  @override
  String get householdInviteRevoke => 'Отозвать';

  @override
  String get householdInviteRevoked => 'Приглашение отозвано.';

  @override
  String get householdLeave => 'Выйти из группы';

  @override
  String householdLeaveTitle(String name) {
    return 'Выйти из группы «$name»?';
  }

  @override
  String get householdLeaveBody =>
      'Питомцы и записи останутся в группе. Вернуться можно будет только по новому приглашению.';

  @override
  String get householdLeaveConfirm => 'Выйти';

  @override
  String householdLeftSelf(String name) {
    return 'Вы вышли из группы «$name».';
  }

  @override
  String get householdLastOwner => 'Сначала назначьте другого владельца.';

  @override
  String get householdRename => 'Переименовать';

  @override
  String get householdRenameTitle => 'Название группы';

  @override
  String get householdDelete => 'Удалить группу';

  @override
  String householdDeleteTitle(String name) {
    return 'Удалить группу «$name»?';
  }

  @override
  String get householdDeleteBody =>
      'В ней нет других людей, питомцев и запасов. Отменить это нельзя.';

  @override
  String householdDeleted(String name) {
    return 'Группа «$name» удалена.';
  }

  @override
  String get householdNotEmpty =>
      'Удалить можно только пустую группу, а в этой есть питомцы или запасы.';

  @override
  String get householdMemberRemove => 'Убрать из группы';

  @override
  String get householdMemberRemoveTitle => 'Убрать из группы?';

  @override
  String householdMemberRemoveBody(String name) {
    return '$name больше не увидит питомцев этой группы. Отметки останутся.';
  }

  @override
  String get householdMemberRemoveConfirm => 'Убрать';

  @override
  String get householdInviteTitle => 'Кого пригласить?';

  @override
  String get householdInviteCodeTitle => 'Код приглашения';

  @override
  String householdInviteCodeBody(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return 'Код сработает один раз и действует $_temp0.';
  }

  @override
  String get householdShare => 'Поделиться';

  @override
  String get householdCopy => 'Скопировать';

  @override
  String get householdCopied => 'Код скопирован.';

  @override
  String householdShareText(String name, String code, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return 'Присоединяйтесь к группе «$name» в Collarbell: код $code, действует $_temp0.';
  }

  @override
  String get householdInviteLimit =>
      'Открытых приглашений уже 20: отзовите ненужные.';

  @override
  String get householdLimit => 'Можно состоять не больше чем в 20 группах.';

  @override
  String get joinTitle => 'Вступить в группу';

  @override
  String get joinCodeLabel => 'Код приглашения';

  @override
  String get joinCodeHelper => '8 букв и цифр, например ABCD-2345';

  @override
  String joinPreview(String inviter, String name, String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'helper': 'как помощника',
      'other': 'как участника',
    });
    return '$inviter приглашает вас в группу «$name» $_temp0.';
  }

  @override
  String joinPreviewNoName(String name, String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'helper': 'как помощника',
      'other': 'как участника',
    });
    return 'Вас приглашают в группу «$name» $_temp0.';
  }

  @override
  String joinValidUntil(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Код действует до $dateString.';
  }

  @override
  String get joinAction => 'Вступить';

  @override
  String get joinNotFound =>
      'Код не подходит: проверьте его или попросите новый.';

  @override
  String get joinAlreadyMember => 'Вы уже в этой группе.';

  @override
  String get joinTooManyAttempts =>
      'Слишком много попыток, попробуйте через несколько минут.';

  @override
  String joinJoined(String name) {
    return 'Вы вступили в группу «$name».';
  }

  @override
  String get errorNotInHousehold => 'Вас больше нет в этой группе.';

  @override
  String get petsEmptyBodyHelper => 'Здесь появятся кошки и собаки группы.';

  @override
  String get todayStartBodyHelper =>
      'Когда в группе появятся питомцы, здесь будут их кормления, уход и покупки.';

  @override
  String get feedingEmptyHelper => 'Кормлений пока нет.';

  @override
  String get healthPlansEmptyHelper => 'Планов пока нет.';

  @override
  String get healthHistoryEmptyHelper => 'Записей пока нет.';

  @override
  String get passportEmptyHelper => 'Данных паспорта пока нет.';

  @override
  String get passportPagesEmptyHelper => 'Листов паспорта пока нет.';

  @override
  String get visitsEmptyBodyHelper =>
      'Здесь появятся визиты к ветеринару или грумеру.';

  @override
  String get suppliesEmptyBodyHelper =>
      'Здесь появятся корм, наполнитель и лекарства группы.';

  @override
  String get supplyNoFeedingsHelper =>
      'Этот корм пока не выбран ни в одном кормлении.';

  @override
  String get householdDefaultNameOther => 'Дом';

  @override
  String get householdStepDownTitle => 'Перестать быть владельцем?';

  @override
  String get householdStepDownBody =>
      'Вы больше не сможете приглашать людей и менять роли, а ваши открытые приглашения перестанут работать.';

  @override
  String get householdStepDownConfirm => 'Сменить роль';

  @override
  String get householdSwitchedUnnamed => 'Вы перешли в другую группу.';

  @override
  String get joinCodeBadCharacters =>
      'В кодах нет букв O и I и цифр 0 и 1: проверьте код.';

  @override
  String get notificationsChannelFeedingUpdates => 'Кто покормил';

  @override
  String get householdPlanTitle => 'Тариф';

  @override
  String get householdPlanFree => 'Free';

  @override
  String get householdPlanPremium => 'Premium';

  @override
  String householdPlanOf(String name) {
    return 'Тариф группы «$name»';
  }

  @override
  String householdPlanUntil(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'До $dateString';
  }

  @override
  String get householdPlanNoEnd => 'Бессрочно';

  @override
  String get householdPlanAiPhotos => 'Фото для AI в этом месяце';

  @override
  String householdPlanAiPhotosUsed(int used, int limit) {
    return '$used из $limit';
  }

  @override
  String get householdPlanAiPhotosUsedUp =>
      'Фото для AI на этот месяц закончились. Вносить данные вручную и сканировать штрихкоды можно как прежде.';

  @override
  String householdPlanResetsOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Счётчик обнулится $dateString.';
  }

  @override
  String get householdPlanAiPhotosHelp =>
      'Считается каждое фото, которое прочитал AI: страница паспорта, наклейка чипа, упаковка.';

  @override
  String get householdPlanPremiumTitle => 'Что даёт Premium';

  @override
  String householdPlanPremiumAiPhotos(int count) {
    return 'До $count фото в месяц для AI';
  }

  @override
  String get householdPlanPaymentsNote =>
      'Оплаты в приложении пока нет: Premium сейчас выдаётся вручную.';

  @override
  String get householdPlanOpen => 'Посмотреть тариф';

  @override
  String householdPlanAiPhotosLine(int used, int limit) {
    return 'Фото для AI в этом месяце: $used из $limit';
  }

  @override
  String errorAiLimitUsedUp(int used, int limit, String plan, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'В этом месяце AI прочитал $used из $limit фото — это лимит тарифа $plan. Счётчик обнулится $dateString.';
  }

  @override
  String errorAiLimitNotEnough(int left, int limit) {
    return 'Осталось $left из $limit фото в этом месяце: выберите меньше.';
  }

  @override
  String get errorAiLimit => 'Лимит AI на этот месяц исчерпан.';

  @override
  String get errorTooManyRequests =>
      'Слишком много запросов подряд. Попробуйте через минуту.';

  @override
  String errorTooManyRequestsIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds секунды',
      many: '$seconds секунд',
      few: '$seconds секунды',
      one: '$seconds секунду',
    );
    return 'Слишком много запросов подряд. Попробуйте через $_temp0.';
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

    return 'Вы уже отправили AI $used из $limit фото в этом месяце во всех своих группах на $plan. Счётчик обнулится $dateString.';
  }

  @override
  String errorAiLimitPersonNotEnough(int left, int limit, String plan) {
    return 'Вам осталось $left из $limit фото в этом месяце во всех своих группах на $plan: выберите меньше.';
  }

  @override
  String get commonClose => 'Закрыть';

  @override
  String get moreYourData => 'Ваши данные';

  @override
  String get dataExportTitle => 'Скачать мои данные';

  @override
  String get dataExportHelper =>
      'ZIP-файл с аккаунтом, группами, фото и сканами';

  @override
  String get dataExportPreparing => 'Готовим файл…';

  @override
  String dataExportProgress(String size) {
    return 'Скачано: $size';
  }

  @override
  String dataExportReady(String size) {
    return 'Готово: $size';
  }

  @override
  String fileSizeKb(int kb) {
    return '$kb КБ';
  }

  @override
  String fileSizeMb(double mb) {
    final intl.NumberFormat mbNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String mbString = mbNumberFormat.format(mb);

    return '$mbString МБ';
  }

  @override
  String get dataExportShareFailed =>
      'Не удалось поделиться файлом. Проверьте, хватает ли места на телефоне, и попробуйте снова.';

  @override
  String get dataExportKeepSafe =>
      'В нём документы ваших питомцев: храните его в надёжном месте.';

  @override
  String get dataExportShare => 'Поделиться';

  @override
  String get dataExportSaved => 'Сохранено.';

  @override
  String get dataExportSaveFailed =>
      'Не удалось сохранить файл. Попробуйте «Поделиться».';

  @override
  String get dataExportTooLarge =>
      'Файл большой: сохраните его через «Поделиться», например в «Файлы» или на Диск.';

  @override
  String get dataExportTooOften =>
      'Вы уже несколько раз скачивали данные за этот час. Попробуйте позже.';

  @override
  String dataExportTooOftenIn(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes минуты',
      many: '$minutes минут',
      few: '$minutes минуты',
      one: '$minutes минуту',
    );
    return 'Вы уже несколько раз скачивали данные за этот час. Попробуйте через $_temp0.';
  }

  @override
  String get deleteAccountTitle => 'Удалить аккаунт';

  @override
  String get deleteAccountHelper =>
      'Сначала покажем, что будет с каждой группой';

  @override
  String get deleteAccountWarning =>
      'Аккаунт удалится насовсем. Отменить это нельзя.';

  @override
  String get deleteAccountGroups => 'Что будет с группами';

  @override
  String deleteAccountFateDeleted(int pets) {
    String _temp0 = intl.Intl.pluralLogic(
      pets,
      locale: localeName,
      other:
          'Удалится вместе с $pets питомца и всеми записями, фото и документами.',
      many:
          'Удалится вместе с $pets питомцами и всеми записями, фото и документами.',
      few:
          'Удалится вместе с $pets питомцами и всеми записями, фото и документами.',
      one:
          'Удалится вместе с $pets питомцем и всеми записями, фото и документами.',
      zero: 'Удалится со всем, что в ней есть.',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountFateDeletedHelpers =>
      'Кроме вас, в ней только помощники — они потеряют к ней доступ.';

  @override
  String get deleteAccountFateKept => 'Останется у остальных как есть.';

  @override
  String deleteAccountFateHandedOver(String name) {
    return 'Останется у остальных, владельцем станет $name.';
  }

  @override
  String get deleteAccountFateHandedOverUnnamed =>
      'Останется у остальных, владельцем станет участник, который вступил раньше всех.';

  @override
  String get deleteAccountGoes => 'Что удалится';

  @override
  String get deleteAccountGoesAccount =>
      'Аккаунт: почта, имя, настройки, телефоны, на которые приходят напоминания, и журнал действий за последние 7 дней.';

  @override
  String get deleteAccountGoesGroups =>
      'Группы, где вы одни или где остались бы только помощники, — с питомцами, записями, фото и документами.';

  @override
  String get deleteAccountGoesSignIn => 'Данные для входа: почта и пароль.';

  @override
  String get deleteAccountStays => 'Что останется';

  @override
  String get deleteAccountStaysRecords =>
      'В общих группах ваши записи и отметки кормления останутся без вашего имени, а написанное в них (например, данные владельца в паспорте питомца) — как есть.';

  @override
  String get deleteAccountStaysBackups =>
      'В резервных копиях данные хранятся ещё до 14 дней, потом исчезают и оттуда.';

  @override
  String get deleteAccountStaysAiPhotos =>
      'Фото, которые уже отправлялись на чтение AI (Gemini), обработаны по правилам Google: удаление их не отзовёт.';

  @override
  String get deleteAccountExportFirst => 'Сначала скачать мои данные';

  @override
  String get deleteAccountPasswordHelper =>
      'Введите пароль, чтобы подтвердить, что это вы.';

  @override
  String get deleteAccountConfirmTitle => 'Удалить аккаунт?';

  @override
  String deleteAccountConfirmBody(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Удалятся группы $names со всем, что в них есть. Отменить это нельзя.',
      many:
          'Удалятся группы $names со всем, что в них есть. Отменить это нельзя.',
      few:
          'Удалятся группы $names со всем, что в них есть. Отменить это нельзя.',
      one:
          'Удалится группа $names со всем, что в ней есть. Отменить это нельзя.',
      zero: 'Отменить это нельзя.',
    );
    return '$_temp0';
  }

  @override
  String quotedName(String name) {
    return '«$name»';
  }

  @override
  String namesAnd(String names, String last) {
    return '$names и $last';
  }

  @override
  String get deleteAccountWrongPassword =>
      'Неверный пароль. Попробуйте ещё раз.';

  @override
  String get deleteAccountPasswordAgain =>
      'Для безопасности введите пароль ещё раз.';

  @override
  String get deleteAccountPasswordCheckFailed =>
      'Не удалось проверить пароль. Попробуйте снова.';

  @override
  String get deleteAccountSignOutFailed =>
      'Аккаунт удалён, но выйти из него на этом телефоне не получилось. Приложение выйдет при следующем запуске.';

  @override
  String get deleteAccountPlanChanged =>
      'В ваших группах что-то изменилось. Посмотрите ещё раз, что с ними будет, и удалите снова.';

  @override
  String get accountDeletedNotice => 'Ваш аккаунт удалён.';

  @override
  String get petTabWeight => 'Вес';

  @override
  String get weightLabel => 'Вес';

  @override
  String weightOnDate(String weight, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$weight, $dateString';
  }

  @override
  String get weightLatestTitle => 'Последний вес';

  @override
  String get weightTrendTitle => 'Динамика';

  @override
  String get weightHistoryTitle => 'История';

  @override
  String get weightAdd => 'Добавить';

  @override
  String get weightAddFirst => 'Добавить вес';

  @override
  String get weightEmptyTitle => 'Взвешиваний пока нет';

  @override
  String get weightEmptyBody =>
      'Взвешивайте питомца раз в месяц, а котят и щенков — раз в 1–2 недели: так вы вовремя заметите, если он начнёт худеть или набирать вес.';

  @override
  String get weightEmptyBodyHelper => 'Здесь появятся взвешивания питомца.';

  @override
  String get weightSourceWeighing => 'Взвешивание';

  @override
  String get weightSourceVet => 'Осмотр у ветеринара';

  @override
  String weightChangeSince(String change, String date) {
    return '$change с $date';
  }

  @override
  String weightNoChangeSince(String date) {
    return 'Без изменений с $date';
  }

  @override
  String get weightNoChange => 'без изменений';

  @override
  String weightBodyCondition(int score, int scale) {
    return 'Упитанность $score/$scale';
  }

  @override
  String weightBcsIdeal(String range) {
    return 'норма $range';
  }

  @override
  String get weightPeriodThreeMonths => '3 месяца';

  @override
  String get weightPeriodYear => '1 год';

  @override
  String get weightPeriodAll => 'Всё время';

  @override
  String get weightChartNeedsTwo =>
      'График появится после второго взвешивания.';

  @override
  String get weightChartTooFew => 'За этот период меньше двух взвешиваний.';

  @override
  String weightChartSummary(
    String from,
    String to,
    String first,
    String last,
    String lowest,
    String highest,
  ) {
    return 'График веса с $from по $to: в начале $first, в конце $last, минимум $lowest, максимум $highest.';
  }

  @override
  String get weightUnitKg => 'кг';

  @override
  String get weightAddTitle => 'Новое взвешивание';

  @override
  String get weightEditTitle => 'Изменить взвешивание';

  @override
  String get weightMeasuredOnLabel => 'Дата взвешивания';

  @override
  String get weightHint => 'например, 4,2';

  @override
  String get weightRequired => 'Введите вес';

  @override
  String weightTooPrecise(int decimals) {
    String _temp0 = intl.Intl.pluralLogic(
      decimals,
      locale: localeName,
      other: 'Не больше $decimals знака после запятой',
      many: 'Не больше $decimals знаков после запятой',
      few: 'Не больше $decimals знаков после запятой',
      one: 'Не больше $decimals знака после запятой',
    );
    return '$_temp0';
  }

  @override
  String get weightDateBeforeBirth => 'Не раньше даты рождения питомца';

  @override
  String get weightBcsLabel => 'Оценка упитанности';

  @override
  String get weightBcsAdd => 'Добавить оценку упитанности';

  @override
  String get weightBcsRemove => 'Убрать оценку';

  @override
  String weightBcsScale(int max) {
    return 'Шкала 1–$max';
  }

  @override
  String weightBcsHelp(String ideal, int max) {
    return 'Норма — $ideal из $max: рёбра легко прощупываются, сверху видна талия.';
  }

  @override
  String get weightNoteLabel => 'Заметка';

  @override
  String get weightNoteHint => 'например, до завтрака';

  @override
  String get weightDelete => 'Удалить взвешивание';

  @override
  String get weightDeleteTitle => 'Удалить это взвешивание?';

  @override
  String get weightDeleteBody =>
      'Оно исчезнет из истории и с графика. Отменить это нельзя.';

  @override
  String get weightGone =>
      'Это взвешивание уже удалено — вероятно, на другом устройстве.';

  @override
  String get weightReadOnly =>
      'Взвешивание сделано в более новой версии приложения. Обновите приложение, чтобы изменить его.';

  @override
  String get noteTitle => 'Записать словами';

  @override
  String get noteIntro =>
      'Напишите своими словами, что и когда было сделано: прививки, обработки, визит к ветеринару, вес. AI превратит это в записи, а вы их проверите.';

  @override
  String get noteLabel => 'Заметка';

  @override
  String get noteHint =>
      'Например: вчера прививка от бешенства, Нобивак; весит 4,2 кг';

  @override
  String get noteDictate =>
      'Чтобы надиктовать, нажмите на микрофон на клавиатуре.';

  @override
  String get noteRead => 'Прочитать';

  @override
  String get noteRequired => 'Напишите словами, что было сделано.';

  @override
  String get noteStarting => 'Отправляем заметку в AI…';

  @override
  String noteLimitReached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'AI уже прочитал $count заметки за сутки. Попробуйте завтра или добавьте запись вручную.',
      many:
          'AI уже прочитал $count заметок за сутки. Попробуйте завтра или добавьте запись вручную.',
      few:
          'AI уже прочитал $count заметки за сутки. Попробуйте завтра или добавьте запись вручную.',
      one:
          'AI уже прочитал $count заметку за сутки. Попробуйте завтра или добавьте запись вручную.',
    );
    return '$_temp0';
  }

  @override
  String get noteErrorNotConfigured =>
      'AI не подключён на сервере. Подключите модель в настройках сервера и попробуйте снова. Записи всегда можно внести вручную.';

  @override
  String get noteErrorUnexpected =>
      'При чтении заметки что-то пошло не так. Попробуйте снова.';

  @override
  String get noteStatusProcessing => 'Читаем заметку…';

  @override
  String get noteReadingBody => 'Обычно это занимает 5–30 секунд.';

  @override
  String get noteReadingLeave =>
      'С этого экрана можно уйти: заметка читается на сервере и будет ждать вас на вкладке «Здоровье».';

  @override
  String get noteGone => 'Этой заметки больше нет.';

  @override
  String get noteDiscardedBody => 'Из этой заметки ничего не сохранено.';

  @override
  String noteResumeReady(String date) {
    return 'Продолжить проверку заметки от $date';
  }

  @override
  String noteResumeOpen(String date) {
    return 'Заметка от $date';
  }

  @override
  String get noteReviewTitle => 'Проверка заметки';

  @override
  String get noteReviewIntro =>
      'AI прочитал эти записи из вашей заметки. Сверьте их с тем, что вы написали, исправьте ошибки и снимите отметку с того, что сохранять не нужно.';

  @override
  String get noteNothingFound =>
      'В этой заметке AI не нашёл ничего, что можно сохранить. Удалите её или напишите иначе.';

  @override
  String get noteFreeTierWarning =>
      'Бесплатный тариф Gemini: Google может использовать отправленные данные для улучшения своих продуктов, а читать их могут сотрудники-рецензенты. Не пишите личных данных, например телефонов и адресов.';

  @override
  String noteWrittenAt(String when) {
    return 'Написано $when';
  }

  @override
  String get noteSectionTitle => 'Ваша заметка';

  @override
  String get noteEvidence => 'Из заметки';

  @override
  String get noteDiscard => 'Удалить заметку';

  @override
  String get noteDiscardTitle => 'Удалить эту заметку?';

  @override
  String get noteDiscardBody =>
      'Из неё ничего не сохранится, а её текст удалится.';

  @override
  String get noteDiscarded => 'Заметка удалена';

  @override
  String get noteLeaveBody =>
      'Изменения на этом экране пропадут. Заметка останется на вкладке «Здоровье», к ней можно вернуться.';

  @override
  String get noteSavedNoDiscard => 'эта заметка уже была сохранена';

  @override
  String get noteIssueUnreadable => 'В заметке этого нет. Укажите сами.';

  @override
  String get noteIssueAmbiguous =>
      'День и месяц могли перепутаться. Проверьте, что вы имели в виду.';

  @override
  String get noteIssueInvalidFormat => 'Похоже на ошибку. Проверьте.';

  @override
  String get noteIssueRepeated => 'Эта запись есть в заметке дважды.';

  @override
  String get scanWeightsTitle => 'Взвешивания';

  @override
  String get scanWeightAlreadySaved => 'Этот вес уже есть на вкладке «Вес».';

  @override
  String get scanWeightRepeated => 'Такой же вес уже есть в записи выше.';

  @override
  String get scanNeedsWeight => 'Укажите вес, чтобы сохранить эту запись.';

  @override
  String scanSavedWeights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'добавлено $count взвешивания',
      many: 'добавлено $count взвешиваний',
      few: 'добавлены $count взвешивания',
      one: 'добавлено $count взвешивание',
    );
    return '$_temp0';
  }

  @override
  String get navHome => 'Главная';

  @override
  String get homeGreetingMorning => 'Доброе утро';

  @override
  String get homeGreetingAfternoon => 'Добрый день';

  @override
  String get homeGreetingEvening => 'Добрый вечер';

  @override
  String get homeGreetingNight => 'Доброй ночи';

  @override
  String get homePetsLabel => 'Питомцы';

  @override
  String get homeAddPetTitle => 'Добавьте питомца';

  @override
  String get homeAddPetHint =>
      'Кошку или собаку: с питомца начинается всё остальное';

  @override
  String get homeTourTitle => 'Пройти знакомство';

  @override
  String get homeTourHint => 'Что умеет приложение — за минуту';

  @override
  String get homeNowTitle => 'Сейчас важно';

  @override
  String homeOverdue(int count) {
    return 'Просрочено: $count';
  }

  @override
  String homeDueSoon(int count) {
    return 'Скоро: $count';
  }

  @override
  String get homeCareHint => 'Прививки и обработки';

  @override
  String homeToBuy(int count) {
    return 'Купить: $count';
  }

  @override
  String get homeToBuyHint => 'Корм, наполнитель, лекарства';

  @override
  String get homeAllDoneTitle => 'На сегодня всё сделано';

  @override
  String get homeAllDoneBody => 'Новое появится здесь в свой срок.';

  @override
  String homeNextFeeding(String time) {
    return 'Кормление в $time';
  }

  @override
  String get homeQuickTitle => 'Быстрые действия';

  @override
  String get homeQuickCare => 'Прививка или обработка';

  @override
  String get homeQuickCareHint => 'Записать, что сделали';

  @override
  String get homeQuickScan => 'Скан паспорта';

  @override
  String get homeQuickScanHint => 'AI перенесёт записи';

  @override
  String get homeQuickNote => 'Записать словами';

  @override
  String get homeQuickNoteHint => 'AI разберёт заметку';

  @override
  String get homeQuickWeigh => 'Взвесить';

  @override
  String get homeQuickWeighHint => 'Следить за весом';

  @override
  String get homeQuickPurchase => 'Сканировать покупку';

  @override
  String get homeQuickPurchaseHint => 'Корм, лекарства';

  @override
  String get homePickPet => 'Какой питомец?';

  @override
  String get visitAddCard => 'Записать визит';

  @override
  String get visitAddCardHint => 'Врач, груминг';

  @override
  String get todayAddFeedingHint => 'Напомним, когда кормить';

  @override
  String get todayAddCareHint => 'Подскажем сроки';

  @override
  String get welcomeMoreTitle => 'Знакомство с приложением';

  @override
  String get welcomeMoreHint => 'Что умеет приложение и первые шаги';

  @override
  String get welcomeIntro1Title => 'Напомним вовремя';

  @override
  String get welcomeIntro1Body =>
      'Кормления, прививки, обработки и визиты к врачу: уведомление придёт в нужную минуту.';

  @override
  String get welcomeIntro2Title => 'Паспорт за минуту';

  @override
  String get welcomeIntro2Body =>
      'Сфотографируйте страницы ветпаспорта: AI перенесёт прививки и сроки, а вы проверите перед сохранением.';

  @override
  String get welcomeIntro3Title => 'Вместе с семьёй';

  @override
  String get welcomeIntro3Body =>
      'Все видят, кто уже покормил, а запасы подскажут, когда пора купить корм.';

  @override
  String get welcomeNext => 'Дальше';

  @override
  String get welcomeStart => 'Начать';

  @override
  String get welcomeSkip => 'Пропустить';

  @override
  String get welcomeDone => 'Готово';

  @override
  String get welcomeSaveNext => 'Сохранить и дальше';

  @override
  String welcomeStep(int step, int count) {
    return 'Шаг $step из $count';
  }

  @override
  String welcomePage(int page, int count) {
    return 'Страница $page из $count';
  }

  @override
  String get welcomeClose => 'Закрыть';

  @override
  String get welcomeBack => 'Назад';

  @override
  String get welcomePetTitle => 'Кто у вас живёт?';

  @override
  String get welcomePetBody =>
      'Начните с питомца: кормление, уход и запасы настраиваются для него. Остальные данные можно добавить потом.';

  @override
  String welcomePetHere(String names) {
    return 'Уже здесь: $names';
  }

  @override
  String get welcomePetAddMore => 'Добавить ещё';

  @override
  String get welcomeInvitedTitle => 'Меня пригласили в семью';

  @override
  String get welcomeInvitedHint => 'Ввести код приглашения';

  @override
  String get welcomeFeedingTitle => 'Время кормления';

  @override
  String get welcomeFeedingBody =>
      'В это время всем придёт напоминание, каждый день. Нажмите на время, чтобы изменить его.';

  @override
  String get welcomeFeedingSet => 'Кормление уже настроено';

  @override
  String get welcomeFeedingNoPet =>
      'Кормление настраивается для питомца. Сначала добавьте его — или вернитесь сюда позже из «Ещё».';

  @override
  String get welcomePushTitle => 'Уведомления';

  @override
  String get welcomePushBody =>
      'Напоминания приходят уведомлениями: кормление, прививки, визиты, покупки. Без них приложение покажет сроки, только когда вы его откроете.';

  @override
  String get welcomePushAllow => 'Включить уведомления';

  @override
  String get welcomePushOn => 'Уведомления включены';

  @override
  String get welcomeFamilyTitle => 'Позовите семью';

  @override
  String get welcomeFamilyBody =>
      'Отправьте код тем, кто ухаживает за питомцами вместе с вами: они увидят кормления, уход и запасы.';

  @override
  String get welcomeFamilyInvited =>
      'Приглашение создано. Код действует 7 дней.';

  @override
  String get welcomeFamilyInviteMore => 'Пригласить ещё';

  @override
  String get moreHelp => 'Помощь';

  @override
  String get supplyAddByHandHelper => 'Название и размер упаковки';

  @override
  String get healthHistoryAddHint => 'Вручную, по одной';
}
