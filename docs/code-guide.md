# Как читать код Collarbell

> Для тех, кому читать чужой код пока трудно. Идём от общей картины к отдельным строкам.
> Держите этот файл открытым рядом с кодом: пути вида `файл:строка` кликабельны в IDE.
> Номера строк — на момент общего доступа (группы и роли, 2026-10-05).

## 0. Как пользоваться гайдом

1. Прочитайте **карту** (раздел 1). Цель — знать, где что лежит. Понимать каждую строку пока не нужно.
2. Пройдите **шесть историй целиком** (раздел 2): что происходит, когда открываешь вкладку «Pets», когда добавляешь лист паспорта, когда отмечаешь «Сделано», когда сканируешь паспорт, когда приходит напоминание покормить и когда пора купить корм. Так связи между частями становятся видны лучше, чем при чтении файлов по одному.
3. Читайте **файлы по маршруту** (раздел 3) вместе с **разбором строк** (разделы 4 и 5).
4. Незнакомый значок или слово ищите в **шпаргалке** (раздел 6) и **словаре** (раздел 9).
5. Сделайте одно-два **упражнения** (раздел 8). Код запоминается, когда что-то в нём меняешь.

**Как прочитать любой файл за 5 минут:**

1. **Путь и имя.** `Modules/Pets/PetsEndpoints.cs`: модуль Pets, адреса API.
2. **Импорты** (`using …` в C#, `import …` в Dart): с чем файл работает.
3. **Публичное** — всё, что не `private` и не начинается с `_`. Это то, что файл умеет «наружу».
4. **Один метод целиком**, сверху вниз, со шпаргалкой под рукой.
5. **Тест к файлу.** Тест — это пример использования с ожидаемым результатом, часто понятнее самого кода.

Не пытайтесь понять всё за один проход. Второй проход по тому же файлу через день даёт в разы больше.

## 1. Карта проекта

```text
backend/                               .NET 10 — сервер
  global.json                          версия SDK и новый запуск тестов
  Directory.Packages.props             версии всех NuGet-пакетов в одном месте
  Dockerfile                           как собрать образ API для сервера (4.20)
  src/
    Collarbell.AppHost/AppHost.cs      «пульт»: поднимает Postgres в Docker и API одной командой
    Collarbell.ServiceDefaults/        общие настройки Aspire (логи, метрики, health-checks) — шаблонный код
    Collarbell.Api/                    сам API
      Program.cs                       ОГЛАВЛЕНИЕ: что подключено и в каком порядке
      Infrastructure/
        Auth/                          вход: Firebase-токены и dev-вход по заголовку; удаление входа в Firebase (4.25)
        Persistence/                   база: AppDbContext и миграции
        Storage/                       хранилище файлов (S3): загрузка, подписанные ссылки
        Validation/                    сбор ошибок полей для ответа 400
        Time/                          часовые пояса и летнее время (NodaTime)
      Modules/                         бизнес-логика по модулям
        Identity/                      пользователь, группы, роли и приглашения, «кто я», /api/v1/me (4.4, 4.21);
                                       удаление аккаунта и выгрузка данных (4.25)
        Pets/                          питомец, чипы, шапка паспорта, /api/v1/pets
        Documents/                     файлы, документы и их страницы, уборка хранилища
        Care/                          уход: планы, «Сделано», записи, пресеты, разделы паспорта V–X
        Today/                         экран «Сегодня»: кормления, визиты, что просрочено и что скоро, что купить
        Ai/                            AI-скан: модели, очередь, черновик, сохранение; экран «AI» (4.16); номер чипа с фото (4.10)
        Notifications/                 напоминания: телефоны, планирование, отправка через Firebase (4.17)
        Routines/                      кормление: расписания и отметки «покормили» (4.18)
        Appointments/                  визиты к ветеринару, грумеру и т. п. (4.18)
        Supplies/                      запасы: товары, покупки, прогноз, штрихкоды, фото упаковки (4.19)
        Observe/                       визор: журнал запросов, события приложения, оповещения в Telegram (4.22)
        Admin/                         адреса админки /api/admin, только для админов (4.22)
        Billing/                       тарифы Free и Premium, лимит ИИ-фото в месяц, /api/v1/plan (4.23)
        Live/                          обновление экранов у всей группы: хаб SignalR /hubs/household (4.24)
  tests/Collarbell.Api.Tests/          тесты API на настоящих Postgres и SeaweedFS в Docker
  tests/ai-samples/                    фото настоящих паспортов для проверки AI (не в git, см. README там)

mobile/                                Flutter — приложение для телефона
  lib/
    main.dart                          ЗАПУСК: настройки сборки, Firebase, старт приложения
    app/                               каркас: тема, язык, навигация (router.dart), пять вкладок (home_shell.dart);
                                       живые обновления: когда подключаться и что перечитать (live_updates.dart, 5.22)
    features/                          экраны и логика по фичам
      auth/                            вход (Firebase или dev)
      me/                              синхронизация профиля (часовой пояс, язык) и /me со списком групп
      household/                       группы и роли: какая группа на экране, что можно роли, экран группы,
                                       приглашения, вступить по коду (5.19)
      account/                         «Скачать мои данные» и «Удалить аккаунт»; выход, если аккаунт удалён (5.23)
      pets/                            список, карточка с вкладками, форма питомца, чипы и их скан (5.7)
      passport/                        вкладка «Паспорт»: шапка паспорта и листы-сканы
      documents/                       вкладка «Документы»: список, форма, просмотр
      files/                           выбор фото и PDF, загрузка, картинки, просмотр страниц
      care/                            вкладка «Здоровье»: планы, «Сделано», история, пресеты
      home/                            «Главная», первая вкладка: приветствие, питомцы, «Сейчас важно», быстрые действия (5.27)
      onboarding/                      знакомство: три страницы и первые шаги; когда оно открывается само (5.27)
      today/                           вкладка «Сегодня»: весь день — кормления, визиты, что просрочено и что скоро, что купить
      ai/                              AI-скан паспорта: съёмка, ожидание, проверка черновика; экран «AI» (5.15)
      feeding/                         вкладка «Кормление» и кормления на «Сегодня» (5.16)
      weight/                          вкладка «Вес»: журнал, график, окно взвешивания (5.24)
      visits/                          визиты: список, форма, «визит состоялся» (5.16)
      notifications/                   пуши: Firebase, регистрация телефона, экран «Уведомления» (5.16)
      supplies/                        вкладка «Запасы»: товары, прогноз, «Купили», сканер штрихкодов (5.17)
      more/                            вкладка «Ещё»: аккаунт, язык, тема, уведомления, AI, знакомство заново
    data/api/                          связь с API: обёртка api_client.dart, группа в каждом запросе
                                       (household_header.dart), копии ответов на случай без связи
      generated/                       клиент, СГЕНЕРИРОВАННЫЙ из contracts/openapi.json — руками не править
    data/live/                         соединение живых обновлений: интерфейс RealtimeClient и его реализация
                                       на пакете signalr_netcore (5.22)
    theme/                             тема из токенов дизайн-системы
    l10n/                              тексты на английском и русском
    shared/                            общие виджеты (поля, карточки, карточки действий, ошибки форм, камера-сканер) и сообщения об ошибках
  tool/generate_api.sh                 перегенерировать клиент после изменения контракта
  tool/install_phone.sh                собрать приложение и поставить на свой телефон по кабелю (5.3)
  tool/icon/                           рисунки иконки и make_icons.sh (5.3)
  test/                                быстрые тесты (без телефона)
  integration_test/                    сквозные тесты в симуляторе против настоящего API:
                                       smoke_test (dev-вход), pets_passport_test (питомец, лист паспорта,
                                       документы), care_test (план → «Сегодня» → «Сделано» → паспорт),
                                       care_ru_test (то же по-русски), ai_scan_test (AI-скан с настоящим AI),
                                       firebase_smoke_test (настоящий Firebase)

landing/                               лендинг (Astro): главная, политика, условия, удаление аккаунта, поддержка; EN и RU
admin/                                 админка (React) по адресу /admin/: обзор, люди, группы, визор, проблемы (4.22)
web/                                   веб-приложение для владельцев (React) по адресу /app/: всё, что в телефоне, кроме пушей и камеры (5.26)
deploy/                                выкладка на сервер: контейнеры, маршруты, деплой с откатом, бэкапы; см. README там (4.20)
contracts/openapi.json                 КОНТРАКТ API: описание всех адресов; пишется при сборке бэкенда
design/tokens.json                     токены дизайн-системы (цвета, шрифты, отступы)
design/figma-plugin/                   плагин Figma: собирает макет для дизайнера (компоненты и все экраны) скриптами; см. его README
tools/gen_flutter_tokens.py            превращает tokens.json в Dart-код темы
docs/                                  исследование, спецификация, архитектура, этот гайд
.github/workflows/ci.yml               автопроверки на GitHub при каждом push
.github/workflows/deploy.yml           после зелёных проверок на main — выкладка на сервер (4.20)
```

**Главная идея, которая объясняет половину кода:** все данные принадлежат **семье** (household).
- Любой запрос к API сначала выясняет, кто пользователь и в какой он семье.
- Дальше всё фильтруется по этой семье: так чужие питомцы никогда не попадают в ответ.
- Семей (в приложении — «групп») у человека может быть несколько: «Мой дом», «Офис». Телефон называет нужную в каждом запросе (заголовок `X-Household`), а роль в ней решает, что можно делать (5.19).

## 2. Одна история целиком: «открыл вкладку Pets»

```text
ТЕЛЕФОН (Flutter)                                     СЕРВЕР (.NET)                         БАЗА
PetsScreen ──watch──▶ petsProvider
   │                     │ ждёт синхронизацию профиля
   │                     ▼
   │               PetsRepository ──▶ api.pets.listPets() ──GET /api/v1/pets──▶ конвейер ASP.NET Core
   │                                   + заголовок входа               │ 1. кто ты? (вход)
   │                                                                   │ 2. можно ли? (авторизация)
   │                                                                   ▼
   │                                                          PetsEndpoints.ListPets
   │                                                                   │
   │                                                          CurrentUserAccessor ──▶ users, household_members
   │                                                                   │
   │                                                          SELECT pets WHERE household_id = … ──▶ pets
   │                                      ◀── JSON [ {...}, … ] ───────┘
   ▼
Pet-модели ──▶ 4 состояния экрана: загрузка / ошибка / пусто / список
```

По шагам, с файлами:

1. **Экран просит данные.**
   - `PetsScreen` в методе `build` пишет `ref.watch(petsProvider)` (`mobile/lib/features/pets/pets_screen.dart:25`).
   - Это значит «дай мне питомцев и перерисуй меня, когда они изменятся».
2. **Провайдер достаёт данные** (`mobile/lib/features/pets/pets_repository.dart:292-296`). Он сначала ждёт синхронизацию профиля (строка 294), потом вызывает репозиторий (строка 295).
3. **Репозиторий зовёт сгенерированный клиент** (`pets_repository.dart:72`): `_client.send((api) => api.pets.listPets())`. Метод `listPets` никто не писал руками: он сгенерирован из операции `ListPets` в `contracts/openapi.json` (см. 5.6).
4. **Перехватчик добавляет заголовки входа** (`api_client.dart`, класс `AuthHeadersInterceptor`):
   - в dev-режиме `X-Dev-User: dev-…`;
   - с Firebase — `Authorization: Bearer <токен>`.
5. **Запрос приходит на сервер** и проходит «конвейер» (`backend/src/Collarbell.Api/Program.cs:199-202`): обработка ошибок, затем вход (*кто ты?*), затем авторизация (*можно ли?*).
6. **Вход.** Селектор выбирает способ проверки (`Infrastructure/Auth/AuthSetup.cs:26`): есть заголовок `X-Dev-User` и dev-режим включён — dev-вход, иначе Firebase. Dev-обработчик превращает заголовок в «пользователя» с идентификатором `dev:…` (`DevUserAuthenticationHandler.cs:36`).
7. **Авторизация.** Группа `/api/v1` открыта только вошедшим (`Program.cs:214`). Иначе ответ 401.
8. **Обработчик адреса** `ListPets` (`Modules/Pets/PetsEndpoints.cs:113`) спрашивает «кто я» у `CurrentUserAccessor` (`Modules/Identity/CurrentUserAccessor.cs:21`). Тот находит пользователя в базе, а при первом запросе создаёт его вместе с семьёй (строки 64-74). Потом узнаёт id семьи (строки 84-100).
9. **Запрос в базу** только по своей семье (`PetsEndpoints.cs:119`): `.Where(p => p.HouseholdId == me.HouseholdId)`. EF Core превращает его в SQL.
10. **Ответ — JSON.** Перечисления пишутся словами (`"species": "Cat"`), а не числами (`Program.cs:43-45`).
11. **Телефон превращает ответ в модель приложения** (`petFromDto`, `pets_repository.dart:162`). Сгенерированная модель `PetResponse` повторяет JSON один в один, а экраны работают с `Pet` — моделью приложения.
12. **Экран показывает одно из 4 состояний** (`pets_screen.dart:30-67`): загрузка, ошибка с кнопкой «Try again», пусто («No pets yet») или список. Если сервер не отвечает, а копия прошлого ответа есть, перехватчик копий (`OfflineCacheInterceptor`, `api_client.dart:91`) отдаёт её как обычный ответ. Тогда экран покажет список, а не ошибку, а над меню появится полоска «Нет связи с сервером» (5.18).

Если эта цепочка понятна, понятны и остальные «читающие» экраны: `/me`, карточка питомца, документы устроены так же.

### 2.2. Вторая история: «добавил лист паспорта»

Здесь участвуют уже три системы: телефон, наш сервер и хранилище файлов.

```text
ТЕЛЕФОН                                       СЕРВЕР (.NET)                         ХРАНИЛИЩЕ И БАЗА
вкладка «Паспорт» → «Add pages»
   │ MediaPicker: камера или галерея (фото сжато до 2048 px)
   │ FilesRepository.upload ──POST /api/v1/files──▶ FilesEndpoints.Upload
   │                                                 FilePreparation: тип, поворот, без EXIF
   │                                                 ObjectStorage.PutAsync ─────────▶ S3: фото + миниатюра
   │                                                 строка StoredFile ──────────────▶ stored_files
   │ ◀── FileLink { id, url, thumbnailUrl } ─────────┘
   │ addPassportPages: свежий список документов питомца
   │   есть документ «листы паспорта» ──POST /documents/{id}/pages──▶ AddPages ─▶ document_pages
   │   нет — создать ──POST /pets/{id}/documents─────────────────────▶ Create
   │ обновить список документов → сетка перерисуется
   ▼
StoredFileImage: миниатюра по подписанной ссылке, напрямую из S3; в кэше — по id файла
```

По шагам:

1. **Нажатие «Add pages»** (`mobile/lib/features/passport/passport_tab.dart:306`). До первого `await` код берёт «контейнер» провайдеров (строка 325, в `_upload`) — дальше объясним зачем (5.10).
2. **Выбор фото** (`features/files/media_picker.dart`). Камера или галерея; телефон сразу уменьшает фото до 2048 px и сохраняет в JPEG 85 % (строки 76-79). Так быстрее загрузка.
3. **Загрузка** (`features/files/files_repository.dart:29-34`): файл уходит как `multipart` — «форма с файлом». Тип файла сервер определит сам, по содержимому.
4. **Сервер** проверяет файл, перекодирует фото, кладёт его и миниатюру в хранилище и записывает строку в базу (раздел 4.8). В ответ — `FileLink` с id и ссылками.
5. **Прикрепление как страниц** (`features/passport/passport_pages.dart:37-58`). Телефон **сначала спрашивает у сервера актуальный список документов** (строка 42), а не верит списку на экране — тот мог устареть. Затем добавляет страницы в существующий документ «листы паспорта» или создаёт новый.
6. **Сервер** (`DocumentsEndpoints.AddPages`) проверяет, что файлы свои и ещё нигде не использованы, и дописывает страницы **в конец**. Ничего не удаляет (раздел 4.9).
7. **Обновление экрана** (`passport_tab.dart:365`): `container.invalidate(petDocumentsProvider(petId))` — «список документов устарел». Сетка перезагрузится и покажет новую миниатюру.
8. **Картинка** (`features/files/widgets/stored_file_image.dart`) качается по подписанной ссылке прямо из хранилища и запоминается в кэше **по id файла** (`stored_file.dart:41-42`). Ссылка через 15 минут перестанет работать, но картинка уже в кэше.
9. **Нажатие на лист** открывает просмотр (`files/page_viewer_screen.dart`). Для полного размера телефон каждый раз берёт свежую ссылку (`fileLinkProvider`, `files_repository.dart:62`).

### 2.3. Третья история: «отметил «Сделано»»

Главная операция ухода. Например, вы дали кошке таблетку от глистов и отмечаете это на экране «Сегодня».

```text
ТЕЛЕФОН                                            СЕРВЕР (.NET)                           БАЗА
«Сегодня» → ✓ у «Обработка от глистов»
   │ DoneScreen: дата, препарат, «Следующий раз: 1 янв.» (посчитано на телефоне)
   │ «Сохранить»
   │   1. фото наклейки → POST /files (если есть)
   │   2. POST /care-plans/{id}/complete ─────────▶ Complete
   │      { performedOn, product, requestId }        тот же requestId или тот же день? → вернуть прежнее
   │                                                 новая запись истории ─────────────────▶ care_records
   │                                                 план сдвинут: дата + 3 месяца ───────▶ care_plans
   │ ◀── { plan, record } ───────────────────────────┘
   │   3. фото → POST /care-records/{id}/files (по одному)
   │   4. refreshCare: «Здоровье», «Сегодня», паспорт перезагрузятся
   ▼
«Сегодня»: пункт ушёл из «Скоро»; «Здоровье»: план «по плану» до января; паспорт: запись в разделе VIII
```

По шагам:

1. **Кнопка ✓** на экране «Сегодня» (`mobile/lib/features/today/today_screen.dart:251`) открывает `DoneScreen` поверх «Сегодня». Вкладка «Питомцы» при этом не трогается: открытая там форма не пропадёт.
2. **Экран заранее показывает следующую дату**, посчитанную по тем же правилам, что на сервере (`features/care/care_rules.dart:47`, `nextDueAfterDone`). «31 января + 1 месяц» тоже совпадает: `addInterval` (строка 23) повторяет серверный `Intervals.Add`.
3. **У экрана свой `requestId`** (`done_screen.dart:84`), один на все попытки. Если ответ потеряется и человек нажмёт «Сохранить» ещё раз, сервер узнает повтор и не отметит план дважды (4.12).
4. **Сохранение по шагам** (`done_screen.dart:246` и дальше):
   - сначала загружаются фото: если какое-то не подошло, ничего ещё не сохранено;
   - потом сам «Сделано» (строка 293);
   - потом фото прикрепляются к новой записи по одному (строка 300).
5. **Сервер** (`CarePlansEndpoints.Complete`, раздел 4.12) создаёт запись истории и сдвигает план в одной транзакции.
6. **Обновление** (`features/care/care_refresh.dart:14`, `refreshCare`) перезагружает план, историю, разделы паспорта и «Сегодня». Оно идёт через контейнер, поэтому сработает и после закрытия экрана, и **после ошибки**: если ответ потерялся, а «Сделано» на сервере прошло, списки покажут правду, как только сервер ответит. Пока он молчит, на экранах может остаться копия прошлого ответа с полоской «Нет связи с сервером» (5.18).

### 2.4. Четвёртая история: «отсканировал паспорт»

Вы фотографируете страницу паспорта с прививкой от бешенства, и через полминуты она превращается в запись, которую остаётся проверить.

```text
ТЕЛЕФОН                                  СЕРВЕР (.NET)                                 GEMINI
«Паспорт» → «Сканировать»
   │ сканер находит края листа, телефон уменьшает фото
   │ 1. фото → POST /files ──────────▶ перекодировать, положить в хранилище
   │ 2. POST /ai-imports ────────────▶ импорт «в очереди», ответ 202 сразу
   │                                   фоновая служба забирает импорт:
   │                                   фото + промпт + JSON-схема ─────────────────▶ модель 1: «занята» (503)
   │                                                               ─────────────────▶ модель 2: ответ JSON
   │                                   ответ модели сохранён, статус «готов»
   │ 3. раз в 2 с GET /ai-imports/{id} ▶ черновик = ответ модели + то, что уже есть
   │ ◀── черновик с подсказками ───────┘ («проверь день и месяц», «уже есть», план)
   │ проверить, поправить, снять лишние галочки
   │ 4. POST /ai-imports/{id}/apply ───▶ одна транзакция: записи, «Сделано» по плану,
   │                                   чип, номер паспорта, фото в скан паспорта
   │ 5. обновить «Здоровье», «Сегодня», паспорт, документы
   ▼
«Здоровье»: прививка в истории, план «Бешенство» — до марта 2028
```

Главное в этой истории:
1. **Модель только читает.** В базу её ответ попадает как черновик, а записи сохраняет человек кнопкой «Сохранить». Проверки при этом те же, что при ручном вводе.
2. **Долгую работу делает фоновая служба**, а телефон опрашивает сервер. Можно уйти с экрана: скан дочитается, а на вкладке «Паспорт» появится «Продолжить проверку» (или «Не удалось прочитать» с кнопкой «Повторить»).
3. **Модели — цепочкой.** Бесплатная модель бывает занята, тогда отвечает следующая. Человек этого не замечает.
4. **Черновик собирается при каждом открытии**: если запись уже сохранили из другого скана, она будет помечена «уже есть».

Подробности: телефон — 5.15, сервер — 4.16.

### 2.5. Пятая история: «пришло напоминание покормить»

Вы задали кормление Мурки в 08:00. В 08:00 телефон звенит: «Кормление в 08:00 — Мурка: Royal Canin, 40 г». Вы кормите и нажимаете «Покормили».

```text
ТЕЛЕФОН                               СЕРВЕР (.NET)                                FIREBASE
вкладка «Кормление» → 08:00
   │ POST /pets/{id}/routines ───────▶ расписание сохранено
   │                                   планирование: «кормление семьи 08:00» на 48 ч вперёд ─▶ notifications.reminders
   │                                   (раз в 10 минут фоновая служба добавляет следующие)
   ⋮
   │                       08:00:00    диспетчер (раз в 15 с): что пора отправить?
   │                                   модуль кормления: кто ещё не покормлен? — Мурка
   │                                   текст на языке человека ───────────────────────▶ пуш на телефоны семьи
   │ ◀── «Кормление в 08:00» ────────────────────────────────────────────────────────────┘
   │ нажать на пуш → «Сегодня» (перечитано с сервера)
   │ «Покормили» → POST /routines/{id}/completions ─▶ отметка (одна на кормление)
   ▼
«Сегодня»: ✓ 08:02 у Мурки; если бы отметили до 08:00, пуш бы не пришёл
```

Главное в этой истории:
1. **Напоминание существует заранее.** Это строка в базе, а не будильник в телефоне. Его видно в «Ещё → Уведомления → Ближайшие», а после отправки там же видно, что с ним стало.
2. **Перед отправкой сервер ещё раз спрашивает модуль**, нужно ли оно. Мурку уже покормили — пуш не уйдёт.
3. **Телефон регистрируется сам.** Разрешение на уведомления приложение спрашивает один раз: когда сохранено первое кормление, визит или план (5.18). Если разрешено, после входа и при каждом запуске оно сообщает серверу адрес телефона в Firebase (токен).
4. **Две отметки одного кормления невозможны.** Второй телефон получит «Уже отмечено: Аня, 08:02».
5. **Пуши пока только на Android.** Для iPhone нужен платный аккаунт Apple (спецификация, решения M4).

Подробности: сервер — 4.17 и 4.18, телефон — 5.16.

### 2.6. Шестая история: «пора купить корм»

Вы отсканировали пачку корма 2 кг. Мурка ест его два раза в день по 40 г. Через три недели приходит пуш «Пора купить: Royal Canin — хватит примерно на 5 дней». Вы заказываете корм, а когда пачку привезут, нажимаете «Купили».

```text
ТЕЛЕФОН                               СЕРВЕР (.NET)                              ВНЕШНИЕ БАЗЫ
«Запасы» → «Сканировать штрихкод»
   │ GET /products/lookup?code=… ────▶ товар семьи? свой каталог? ─────────────▶ Open Pet Food Facts, UPCitemdb
   │ ◀── «Kitten, Royal Canin, 2 кг», источник — Open Pet Food Facts
форма, «сейчас есть 1 пачка» → «Сохранить»
   │ POST /supplies ─────────────────▶ товар + запись «осталось 2000 г»
кормление Мурки → «Корм из запасов»
   │ PUT /routines/{id} ─────────────▶ кормление ссылается на товар: расход 80 г в день
   │                                   прогноз: 2000 / 80 = 25 дней → закончится 27-го, купить до 22-го
   │                                   напоминания на 22-е и 27-е, в 10:00 по времени семьи
   ⋮
   │                       22-е 10:00  диспетчер: ещё нужно? (прогноз не изменился) → пуш
   │ ◀── «Пора купить: Kitten» ─────────────────────────────── Firebase
«Купили» → 1 пачка
   │ POST /supplies/{id}/stock-events ▶ +2000 г; прогноз сдвинулся → старые напоминания убраны, новые на новые даты
```

Главное в этой истории:
1. **Остаток не записывают, его считают.** Сервер берёт последнюю поправку («осталось полпачки») или первую покупку и вычитает расход за прошедшие дни.
2. **Расход корма берётся из кормлений.** Это порция того кормления, где выбран этот корм, умноженная на число кормлений в день. Для наполнителя и лекарств расход задают вручную: «упаковки хватает на 30 дней».
3. **«Купить до» = «закончится» минус дни на доставку.** Пока доставка едет, корм ещё есть.
4. **Перед отправкой напоминание сверяется с прогнозом.** Если корм уже купили, прогноз сдвинулся, и старое напоминание не уйдёт.
5. **Данные Open Pet Food Facts приложение показывает с указанием источника и не копирует в наш каталог.** Так требует их лицензия ODbL.

Подробности: сервер — 4.19, телефон — 5.17.

## 3. Маршрут чтения: 53 файла по порядку

Не обязательно за один раз: удобно по этапам. Первые 10 строк — M0, дальше M1, M2, M3, M4, M5, скан номера чипа, группы, «Главная» и знакомство.

| # | Файл | Зачем | Время |
|---|---|---|---|
| 1 | `backend/src/Collarbell.Api/Program.cs` | Оглавление сервера | 10 мин |
| 2 | `backend/src/Collarbell.AppHost/AppHost.cs` | Как всё запускается локально | 5 мин |
| 3 | `backend/src/Collarbell.Api/Modules/Identity/Entities.cs` | Пользователь, семья, участник семьи | 10 мин |
| 4 | `backend/src/Collarbell.Api/Modules/Identity/CurrentUserAccessor.cs` | «Кто я» — самый важный класс | 15 мин |
| 5 | `backend/src/Collarbell.Api/Modules/Pets/Pet.cs` и `PetIdentifier.cs` | Питомец, чипы и их правила | 10 мин |
| 6 | `backend/src/Collarbell.Api/Modules/Pets/PetsEndpoints.cs` | Все действия с питомцем: проверить, найти, сохранить | 20 мин |
| 7 | `mobile/lib/main.dart` | Запуск приложения | 5 мин |
| 8 | `mobile/lib/app/router.dart` | Экраны и «не пускать без входа» | 10 мин |
| 9 | `mobile/lib/data/api/api_client.dart` | Как телефон ходит в API | 10 мин |
| 10 | `mobile/lib/features/pets/pets_repository.dart` и `pets_screen.dart` | Данные питомцев и экран-список | 20 мин |
| 11 | `backend/src/Collarbell.Api/Modules/Documents/FilesEndpoints.cs` и `FilePreparation.cs` | Загрузка файла | 15 мин |
| 12 | `backend/src/Collarbell.Api/Modules/Documents/Files.cs` и `StorageCleanup.cs` | Прикрепить, удалить, убрать за собой | 15 мин |
| 13 | `backend/src/Collarbell.Api/Modules/Documents/DocumentsEndpoints.cs` | Документы и страницы | 15 мин |
| 14 | `mobile/lib/features/pets/pet_form_screen.dart` | Форма: проверка и сохранение | 20 мин |
| 15 | `mobile/lib/features/passport/passport_tab.dart` и `passport_pages.dart` | Листы паспорта | 15 мин |
| 16 | `mobile/lib/features/files/files_repository.dart` и `widgets/stored_file_image.dart` | Загрузка и картинки | 10 мин |
| 17 | `backend/src/Collarbell.Api/Modules/Care/CarePlan.cs` | План: статус и «Сделано» | 10 мин |
| 18 | `backend/src/Collarbell.Api/Modules/Care/CarePresets.cs` | Готовые планы и правило «только для собак» | 10 мин |
| 19 | `backend/src/Collarbell.Api/Modules/Care/CarePlansEndpoints.cs` | Планы и «Сделано» на сервере, защита от повторов | 20 мин |
| 20 | `backend/src/Collarbell.Api/Modules/Today/TodayEndpoints.cs` | «Сегодня» на сервере (его же данные показывает «Главная») | 10 мин |
| 21 | `mobile/lib/features/care/care_rules.dart` | Следующая дата на телефоне — как на сервере | 10 мин |
| 22 | `mobile/lib/features/care/done_screen.dart` | Экран «Сделано» | 20 мин |
| 23 | `mobile/lib/features/today/today_screen.dart` | Вкладка «Сегодня»: весь день | 10 мин |
| 24 | `backend/tests/Collarbell.Api.Tests/CarePlanRulesTests.cs` и `CareTests.cs` | Как проверяется уход | 15 мин |
| 25 | `backend/src/Collarbell.Api/Modules/Ai/AiRunner.cs` | Цепочка моделей: кто ответит и что делать с ошибкой | 15 мин |
| 26 | `backend/src/Collarbell.Api/Modules/Ai/PassportScan.cs` | Что модель должна вернуть, и текст запроса к ней | 10 мин |
| 27 | `backend/src/Collarbell.Api/Modules/Ai/AiImportWorker.cs` | Очередь и фоновое чтение | 15 мин |
| 28 | `backend/src/Collarbell.Api/Modules/Ai/ImportDraft.cs` | Черновик: проверки, «уже есть», подсказка плана | 20 мин |
| 29 | `backend/src/Collarbell.Api/Modules/Ai/AiImportsEndpoints.cs` | Адреса скана и сохранение черновика | 20 мин |
| 30 | `mobile/lib/features/ai/scan_screen.dart` и `scan_review_screen.dart` | Скан и проверка на телефоне | 25 мин |
| 31 | `backend/tests/Collarbell.Api.Tests/AiImportsTests.cs` и `ImportDraftTests.cs` | Как проверяется скан | 15 мин |
| 32 | `backend/src/Collarbell.Api/Modules/Notifications/Reminder.cs` и `ReminderSchedule.cs` | Напоминание и его планирование | 15 мин |
| 33 | `backend/src/Collarbell.Api/Modules/Notifications/ReminderDispatcher.cs` | Отправка в срок, повторы, окна досылки | 20 мин |
| 34 | `backend/src/Collarbell.Api/Modules/Notifications/PushSender.cs` и `ReminderTexts.cs` | Firebase и тексты пушей | 15 мин |
| 35 | `backend/src/Collarbell.Api/Modules/Routines/FeedingReminders.cs` и `RoutinesEndpoints.cs` | Кормление и отметки «покормили» | 15 мин |
| 36 | `backend/src/Collarbell.Api/Modules/Appointments/AppointmentsEndpoints.cs` | Визиты и «визит состоялся» | 15 мин |
| 37 | `mobile/lib/features/notifications/push_registration.dart` и `push_platform.dart` | Пуши на телефоне | 15 мин |
| 38 | `mobile/lib/features/feeding/widgets/today_feeding.dart` | «Покормили» на «Сегодня» | 10 мин |
| 39 | `backend/tests/Collarbell.Api.Tests/RemindersTests.cs` и `FeedingTests.cs` | Как проверяются напоминания | 15 мин |
| 40 | `backend/src/Collarbell.Api/Modules/Supplies/SupplyForecast.cs` | Прогноз запаса: от поправки, расход до нуля, даты | 15 мин |
| 41 | `backend/src/Collarbell.Api/Modules/Supplies/SuppliesEndpoints.cs` | Адреса запасов, покупки, поиск по штрихкоду, фото упаковки | 20 мин |
| 42 | `backend/src/Collarbell.Api/Modules/Supplies/ProductLookup.cs` | Штрихкоды (GTIN, GS1) и внешние базы товаров | 15 мин |
| 43 | `backend/src/Collarbell.Api/Modules/Supplies/SupplyReminders.cs` | «Пора купить» | 10 мин |
| 44 | `mobile/lib/features/supplies/supply_detail_screen.dart` и `stock_sheets.dart` | Страница товара, «Купили» и «Уточнить остаток» | 15 мин |
| 45 | `mobile/lib/features/supplies/product_scan_screen.dart` и `barcode_reader.dart` | Сканер штрихкода и фото упаковки | 15 мин |
| 46 | `backend/tests/Collarbell.Api.Tests/SupplyForecastTests.cs` и `SuppliesTests.cs` | Как проверяются запасы | 15 мин |
| 47 | `mobile/lib/data/api/offline_cache.dart` и `app/offline_banner.dart` | Без связи с Mac: копии ответов, полоска, изменения не поверх копий | 15 мин |
| 48 | `mobile/lib/shared/widgets/leave_guard.dart` и `_values()` в `features/pets/pet_form_screen.dart` | «Уйти без сохранения?» | 5 мин |
| 49 | `backend/src/Collarbell.Api/Modules/Ai/IdentifierScan.cs`, `mobile/lib/features/pets/chip_reader.dart` и `mobile/lib/shared/widgets/barcode_scanner_page.dart` | Скан номера чипа: штрихкод, фото, AI | 15 мин |
| 50 | `mobile/lib/features/household/current_household.dart` и `household_screen.dart` | Группы и роли на телефоне: группа на экране, права роли, люди и приглашения | 15 мин |
| 51 | `mobile/lib/shared/widgets/cb_action_card.dart` и `features/today/first_steps.dart` | Карточка действия и правило кнопок; первые шаги карточками | 10 мин |
| 52 | `mobile/lib/features/home/home_screen.dart` и `pet_picker.dart` | «Главная»: что важно сейчас, быстрые действия, выбор питомца | 15 мин |
| 53 | `mobile/lib/features/onboarding/onboarding.dart` и `welcome_screen.dart` | Знакомство: когда открывается само, страницы и шаги | 15 мин |

Остальное читайте по необходимости: тема, переводы, настройки, сгенерированный код.

## 4. Разбор важных строк: сервер (C#)

### 4.1. `Program.cs` — оглавление

Файл делится на две части.
- **До `builder.Build()`** регистрируется, *какие* службы есть: база, вход, документация.
- **После** настраивается, *в каком порядке* обрабатывается запрос.

```csharp
var builder = WebApplication.CreateBuilder(args);   // :26 «строитель»: читает настройки, готовит логи и контейнер служб
builder.AddServiceDefaults();                       // :31 общие настройки Aspire: телеметрия, health-checks

builder.AddNpgsqlDbContext<AppDbContext>("collarbelldb", // :39 подключить Postgres. Имя "collarbelldb" совпадает
    ...);                                           //     с именем базы в AppHost.cs — по нему приходит строка подключения

builder.Services.ConfigureHttpJsonOptions(o =>      // :43 в JSON перечисления пишутся словами ("Cat"), а числа — только числами
builder.Services.AddProblemDetails();               // :49 ошибки отдаются в стандартном формате RFC 7807
builder.Services.Configure<ExceptionHandlerOptions>(o => // :52 запрос, который нельзя прочитать (битый JSON) → 400, а не 500
builder.Services.AddCollarbellAuth(builder.Configuration, builder.Environment); // :57 вход: Firebase + dev-режим (см. 4.3)
builder.Services.AddScoped<CurrentUserAccessor>();  // :58 «кто я»: Scoped — один экземпляр на один запрос
builder.Services.AddScoped<HouseholdCalendar>();    // :59 «какое сегодня число» в поясе семьи (4.14)
builder.Services.AddScoped<AccountDeletion>();      // :95 удаление аккаунта и выгрузка данных; модули подключают своё (4.25)

builder.Services.AddObjectStorage(builder.Configuration); // :129 хранилище файлов (S3), см. 4.8
builder.Services.AddScoped<Files>();                // :130 публичные службы модулей: файлы,
builder.Services.AddScoped<PetDocuments>();         // :131 документы,
builder.Services.AddScoped<IPetDeletionHandler>(sp => sp.GetRequiredService<PetDocuments>()); // :132 «перед удалением питомца» (4.15)
builder.Services.AddScoped<IPetDeletionHandler, CareRecordFiles>(); // :133 то же для ухода
builder.Services.AddScoped<PetDirectory>();         // :134 «есть ли такой питомец в семье»
builder.Services.AddScoped<CarePlanDirectory>();    // :136 планы для экрана «Сегодня» и AI-скана
builder.Services.Configure<AiOptions>(builder.Configuration.GetSection("Ai")); // :140 AI: какие модели спрашивать (4.16)
builder.Services.AddSingleton<IAiChatClientFactory, AiChatClientFactory>(); // :141 одна фабрика клиентов на всё приложение
builder.Services.AddHostedService<AiImportWorker>(); // :153 фоновое чтение сканов
builder.Services.AddHostedService<StorageCleanupWorker>(); // :158 фоновая уборка хранилища (раз в минуту)
builder.Services.Configure<NotificationsOptions>(builder.Configuration.GetSection("Notifications")); // :162 напоминания (4.17)
builder.Services.AddSingleton<IPushSender, FcmPushSender>(); // :163 отправка пушей через Firebase
builder.Services.AddScoped<IHouseholdChangeHandler>(sp => sp.GetRequiredService<ReminderSchedule>()); // :165 «в семье что-то изменилось» (4.15)
builder.Services.AddScoped<IReminderSource, CarePlanReminders>(); // :167 источники напоминаний: уход,
builder.Services.AddScoped<IReminderSource, FeedingReminders>(); // :168 кормление,
builder.Services.AddScoped<IReminderSource, AppointmentReminders>(); // :169 визиты,
builder.Services.AddScoped<IReminderSource, SupplyReminders>(); // :170 запасы («пора купить»)
builder.Services.AddScoped<SupplyStock>();          // :177 запасы: прогноз для всех, кому он нужен (4.19)
builder.Services.AddProductDatabases(builder.Configuration); // :180 базы товаров по штрихкоду
builder.Services.AddHostedService<ReminderPlanner>(); // :184 раз в 10 минут планировать напоминания всех семей
builder.Services.AddHostedService<ReminderDispatcherWorker>(); // :185 раз в 15 секунд отправлять наступившие

var app = builder.Build();                          // :192 службы собраны, дальше — конвейер запроса

app.UseMiddleware<RequestLogMiddleware>();          // :195 журнал запросов для визора — первым, чтобы видеть все ответы (4.22)
app.UseExceptionHandler();                          // :196 любое исключение → аккуратный ответ 500
app.UseStatusCodePages();                           // :197 пустые 401/404 → тоже в формате ProblemDetails
app.UseAuthentication();                            // :198 КТО ты? (читает токен или заголовок)
app.UseAuthorization();                             // :199 МОЖНО ли тебе сюда?
app.UseRateLimiter();                               // :200 лимиты: коды приглашений, события приложения, AI-фото, выгрузка

var api = app.MapGroup("/api/v1")                   // :211 все адреса /api/v1/...
    .RequireAuthorization()                          //     — только для вошедших,
    .AddEndpointFilter<HouseholdAccessFilter>()      //     каждый — в одной из групп человека, с его ролью там (4.21),
    .AddEndpointFilter<LiveChangesFilter>();         //     и об изменениях слышит вся группа (4.24)
api.MapMeEndpoints();                               // :215 подключить адреса модулей: «кто я»,
api.MapHouseholdsEndpoints();                       // :216   группы, люди и приглашения (4.21),
api.MapPetsEndpoints();                             // :217   питомцы,
api.MapPassportEndpoints();                         // :218   шапка паспорта,
api.MapFilesEndpoints();                            // :219   загрузка файлов,
api.MapDocumentsEndpoints();                        // :220   документы,
api.MapCarePlansEndpoints();                        // :221   планы ухода,
api.MapCareRecordsEndpoints();                      // :222   записи ухода,
api.MapTodayEndpoints();                            // :223   экран «Сегодня»,
api.MapAiEndpoints();                               // :224   экран «AI»,
api.MapAiImportsEndpoints();                        // :225   AI-скан,
api.MapRoutinesEndpoints();                         // :226   кормление,
api.MapAppointmentsEndpoints();                     // :227   визиты,
api.MapNotificationsEndpoints();                    // :228   телефоны и уведомления,
api.MapSuppliesEndpoints();                         // :229   запасы и штрихкоды,
api.MapIdentifierScanEndpoints();                   // :230   номер чипа с фото (4.10)

var migrateOnly = args.Contains("migrate");         // :241 на сервере: запуск с командой migrate только обновляет базу (4.20)
await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.MigrateAsync(); // :245 локально и в тестах база обновляется сама
await scope.ServiceProvider.GetRequiredService<ObjectStorage>().EnsureBucketAsync(CancellationToken.None); // :250 и создаётся «корзина» для файлов
if (args is ["delete-account", ..])                 // :291 удаление аккаунта по письму, командой на сервере (4.25)
if (migrateOnly) { return; }                        // :338 после migrate приложение не запускается, а выходит
```

Порядок в конвейере важен. Запрос проходит строки 195→200 сверху вниз. Если поменять местами 198 и 199, проверка «можно ли» сработает раньше, чем станет известно «кто ты».

Строки 28-41: при сборке приложение запускается один раз, чтобы записать `contracts/openapi.json`. В этом запуске базы нет, поэтому подставляется заглушка. По той же причине в этом запуске не стартуют фоновые службы (строки 151, 156 и 182).

### 4.2. Сущности и база

**Сущность — это класс, который хранится в таблице** (`Modules/Identity/Entities.cs`, `Modules/Pets/Pet.cs`).

```csharp
public sealed class User                     // sealed: от класса нельзя наследоваться
{
    private User() { }                       // пустой конструктор нужен EF Core, снаружи не виден

    public User(string authSubject, ...)     // «правильный» способ создать пользователя
    {
        Id = Guid.CreateVersion7();          // UUID v7: уникален и упорядочен по времени (хорош для индексов)
        ...
    }

    public Guid Id { get; private set; }     // читать можно всем, менять — только самому классу
    public string? Email { get; set; }       // string? — значение может отсутствовать (null)
    public string TimeZone { get; set; } = "UTC";  // значение по умолчанию
}
```

**Как класс ложится в таблицу**, описано рядом (`Modules/Identity/IdentityConfiguration.cs`):

```csharp
b.ToTable("users", IdentitySchema.Name);     // таблица identity.users (у каждого модуля своя схема)
b.HasIndex(x => x.AuthSubject).IsUnique();   // один и тот же Firebase-uid не может встретиться дважды
b.Property(x => x.Email).HasMaxLength(320);  // ограничение длины в базе
```

- **`AppDbContext`** (`Infrastructure/Persistence/AppDbContext.cs`) — «окно в базу». У него по свойству на каждую таблицу: `Users`, `Pets`, `Documents`, `CarePlans`, `Reminders`, `SupplyItems` и другие (`AppDbContext.cs:17-39`). Через них пишутся запросы.
- **Миграции** (`Infrastructure/Persistence/Migrations/`) — записанные изменения схемы базы. Их генерирует команда `dotnet ef migrations add <Имя>`, руками их не пишут. Файлы `*_Initial.cs` (M0) и `*_PetsFilesDocuments.cs` (M1) можно открыть и увидеть, какие таблицы создаются.
- **Имена в базе** — в snake_case (`household_id`), в коде — в PascalCase (`HouseholdId`). Переводит пакет `UseSnakeCaseNamingConvention()`.

### 4.3. Вход: `Infrastructure/Auth/`

Два способа входа:

| Способ | Когда | Как сервер узнаёт пользователя |
|---|---|---|
| Firebase | Всегда | Заголовок `Authorization: Bearer <ID-токен>`. Токен проверяется по ключам Google (`AuthSetup.cs:30-46`) |
| Dev | Только в Development и Testing, если включено в настройках | Заголовок `X-Dev-User: anna` |

```csharp
var devUsersEnabled = config.GetValue<bool>("Auth:DevUsers:Enabled")   // :20 флаг из appsettings
    && (env.IsDevelopment() || env.IsEnvironment("Testing"));           //     И только эти окружения

o.ForwardDefaultSelector = ctx =>                                       // :26 для каждого запроса:
    devUsersEnabled && ctx.Request.Headers.ContainsKey("X-Dev-User")    //     есть dev-заголовок и можно?
        ? DevUserScheme                                                 //     → dev-вход
        : FirebaseScheme;                                               //     → проверка Firebase-токена
```

В dev-обработчике (`DevUserAuthenticationHandler.cs`):

```csharp
if (string.IsNullOrWhiteSpace(uid)) return ...NoResult();   // :21 заголовка нет — «не моё дело», дальше решит другой
if (!ValidUid().IsMatch(uid)) return ...Fail(...);          // :26 странные символы — отказ
new Claim("sub", $"dev:{uid}")                              // :32 приставка dev: — чтобы dev-пользователь
                                                            //     никогда не совпал с настоящим из Firebase
```

**Claim** — «утверждение о пользователе», например `sub` (идентификатор) или `email`. Дальше код читает их через `GetSubject()` и `GetEmail()` (`CollarbellClaims.cs`).

### 4.4. `CurrentUserAccessor.cs` — «кто я, в какой группе и с какой ролью» (главный класс)

Его вызывает каждый адрес API. Он отвечает на вопрос «какой пользователь у этого запроса, в какой он группе и какая у него там роль». Человек может состоять в нескольких группах («Мой дом», «Офис»), а приложение называет ту, что сейчас на экране, заголовком `X-Household` (подробно о группах — 4.21).

```csharp
public async Task<CurrentUser> GetAsync(CancellationToken ct)        // :52
{
    if (_current is not null) return _current;                       // уже вычисляли в этом запросе — вернуть сразу

    var user = await db.Users.SingleOrDefaultAsync(                  // :64 найти пользователя в базе...
                   u => u.AuthSubject == subject, ct);
    if (user is null)
    {
        if (await db.DeletedAccounts.AnyAsync(...))                  // :68 ...аккаунт только что удалён — 401, а не новый (4.25)
            throw new AccountDeletedException();
        user = await CreateAsync(subject, email, ct);                // :73 ...а если нет — создать (первый вход)
    }

    var memberships = await db.HouseholdMembers ...                  // :84 все его группы и роль в каждой
    memberships = [new { HouseholdId = await OwnHouseholdAsync(...   // :94 ни одной не осталось — новая своя
    var requested = context.Request.Headers[HouseholdHeader]...      // :97 какую группу назвало приложение
    return _current = new CurrentUser(user.Id, memberships[0]...     // :100 никакую — первую, в которую он вступил
    if (membership is null && AnyHouseholdWillDo)                    // :106 чужую — для «личных» адресов первую,
        ? throw new NotAHouseholdMemberException()                   // :112 а для остальных 403
        : _current = new CurrentUser(user.Id, membership.HouseholdId, membership.Role); // :113 свою — её
}
```

**Первый вход** (`CreateAsync`): пользователь, группа «Home» и членство «Owner» создаются **одним** `SaveChangesAsync`, то есть одной транзакцией. Либо всё сразу, либо ничего.

**Гонка.** Телефон после входа шлёт несколько запросов почти одновременно, и два из них могут попытаться создать одного и того же пользователя. База не даст: на `AuthSubject` стоит уникальный индекс. Проигравший запрос ловит ошибку уникальности (строка 130), забывает свои несохранённые изменения (строка 133) и просто читает уже созданного пользователя. Это проверяет тест `Parallel_first_calls_create_a_single_user` (`MeTests.cs`). Так же, под блокировкой строки пользователя, создаётся новая своя группа тому, кто остался без групп (`OwnHouseholdAsync`, строка 142): несколько одновременных запросов не наделают ему несколько «Home».

### 4.5. Адреса API: `PetsEndpoints.cs` и `MeEndpoints.cs`

```csharp
var pets = api.MapGroup("/pets").WithTags("Pets").ReportsChanges(LiveTopics.Pets); // PetsEndpoints.cs:80 адреса под /api/v1/pets; изменения слышит вся группа (4.24)
pets.MapGet("", ListPets)                                          // :82 GET /api/v1/pets → метод ListPets
    .WithName("ListPets")                                          //     имя операции в контракте
    .WithSummary("Pets of the signed-in user's household...");     //     описание для документации

private static async Task<Ok<List<PetResponse>>> ListPets(         // :113 что вернёт: 200 OK со списком
    CurrentUserAccessor current,                                   //     ← эти параметры ASP.NET подставляет сам
    AppDbContext db,                                               //       из контейнера служб (DI)
    Files files,
    CancellationToken ct)                                          //     ← отмена, если клиент ушёл
{
    var me = await current.GetAsync(ct);                           //     кто я
    var pets = await db.Pets.AsNoTracking()                        //     AsNoTracking: только читаем, не меняем
        .Include(p => p.Identifiers)                               //     вместе с чипами (отдельная таблица)
        .Where(p => p.HouseholdId == me.HouseholdId)               // :119 ТОЛЬКО своя семья
        .OrderBy(p => p.Status != PetStatus.Active)                //     сначала активные,
        .ThenBy(p => p.CreatedAt)                                  //     потом по дате добавления
        .ToListAsync(ct);                                          //     здесь запрос реально уходит в базу

    var photos = await files.LinksAsync(...);                      //     ссылки на фото — у модуля Documents (4.8)
    return TypedResults.Ok(pets.Select(p => ToResponse(p, photos)).ToList());  // сущность → DTO
}
```

В `MeEndpoints.cs` добавляется изменение данных.

- **Тело запроса.** `UpdateMeRequest request` (строка 120) — параметр, который ASP.NET читает из JSON в теле запроса. Остальные параметры приходят из DI.
- **Проверка** (строки 128-132): неверный язык или часовой пояс → ответ 400 со списком ошибок по полям.
- **Тип ответа.** `Results<Ok<MeResponse>, ValidationProblem>` описывает, что метод может вернуть *или* 200, *или* 400. Это попадает в контракт OpenAPI.
- **Пояс группы** (строка 160): за поясом телефона владельца следует только группа из одного человека, пояс которой не задавали вручную. Общая группа и группа с заданным поясом остаются на месте, когда кто-то уезжает.
- **Сохранение.** `SaveChangesAsync` (строка 168): изменения сохраняются только здесь. До этого объекты менялись лишь в памяти.

**DTO** (`MeResponse`, `PetResponse`) — «форма ответа». Это не то же самое, что сущность: в ответ попадают только нужные поля.

### 4.6. `AppHost.cs` — локальный запуск

```csharp
var postgres = builder.AddPostgres("postgres")           // контейнер Postgres в Docker
    .WithDataVolume("collarbell-postgres-data")          // данные переживают перезапуск
    .WithLifetime(ContainerLifetime.Persistent);         // контейнер не пересоздаётся каждый раз
var database = postgres.AddDatabase("collarbelldb");     // база внутри него

var storage = builder.AddSeaweedFS("storage")            // :15 хранилище файлов SeaweedFS в Docker
    .WithS3(s3Port: 8333)                                //     с S3-интерфейсом на постоянном порту 8333
    .WithDataVolume("collarbell-storage-data")           //     файлы переживают перезапуск
    .WithLifetime(ContainerLifetime.Persistent);

var api = builder.AddProject<Projects.Collarbell_Api>("api") // :21 наш API
    .WithReference(database)                             // передать строку подключения к базе
    .WithReference(storage)                              // и к хранилищу ("Endpoint=…;AccessKey=…;SecretKey=…")
    .WaitFor(database)                                   // стартовать после базы
    .WaitFor(storage)                                    // и после хранилища
    .WithExternalHttpEndpoints();                        // при деплое API будет доступен снаружи

var geminiKey = builder.AddParameter("gemini-api-key", secret: true); // :32 ключ Gemini — секретный параметр
api.WithEnvironment("Ai__Gemini__ApiKey", geminiKey);    // :33 API получит его как настройку Ai:Gemini:ApiKey
```

**Ключ Gemini** лежит не в репозитории, а в секретах этого проекта на Mac: `dotnet user-secrets set "Parameters:gemini-api-key" "<ключ>"` в папке `Collarbell.AppHost`. Если ключа нет (строка 30), приложение всё равно запускается, просто AI-скан выключен, а приложение прячет его кнопки. Как ключ используется — 4.16.

**Ключ Firebase для пушей** устроен так же: секретный параметр `firebase-service-account` (`AppHost.cs:39-43`) с ключом сервисного аккаунта проекта (JSON из консоли Firebase), API получает его как `Notifications:FirebaseCredentials`. Без него напоминания планируются и видны в приложении, только не отправляются (4.17).

**Режим телефона.** Обычно телефон ходит к серверу в интернете (4.20). Этот режим нужен, чтобы попробовать изменения на телефоне до выкладки. Обычно API слушает только `localhost`: к нему ходят симулятор и эмулятор на этом же Mac. Настоящему телефону нужен адрес Mac в домашней сети. Его включает профиль `phone` в `Properties/launchSettings.json`: `dotnet run --project src/Collarbell.AppHost --launch-profile phone` задаёт настройку `Phone:Enabled` (строка 48), и тогда:

```csharp
api.WithEndpoint("http", e => e.TargetHost = "0.0.0.0")          // :52 API слушает все адреса Mac, не только localhost
    .WithEnvironment("Auth__DevUsers__Enabled", "false")         // :53 вход без пароля выключен: в сети им мог бы войти кто угодно
    .WithEnvironment("Storage__PublicEndpoint", $"http://{address}:8333"); // :54 ссылки на фото — с адресом Mac в Wi-Fi
storage.WithEndpoint("s3", e => e.TargetHost = "0.0.0.0");       // :55 хранилище файлов тоже видно из сети
```

Адрес Mac находит `LanAddress` (строка 61): первый адрес IPv4 на Wi-Fi или Ethernet. Телефон входит через Firebase по e-mail и паролю, а в базу и дашборд из сети не попасть: они по-прежнему только на `localhost`. Как приложение попадает на телефон — 5.3.

**Где Project ID Firebase.** `collarbell-3e2b9` записан не здесь, а в `Collarbell.Api/appsettings.json` (ключ `Firebase:ProjectId`). Это не секрет: по нему API понимает, токены какого проекта принимать (`AuthSetup.cs:39-45`).

### 4.7. Тесты: `backend/tests/Collarbell.Api.Tests/`

- `ApiFactory.cs` поднимает API на временных Postgres и SeaweedFS в Docker (Testcontainers). Тесты работают с настоящей базой и настоящим хранилищем, без подделок.
  - `ClientFor("anna")` даёт HTTP-клиент, вошедший как Аня.
  - `api.Storage` скачивает файлы по подписанным ссылкам, как это делает телефон.
  - `RunStorageCleanupAsync()` запускает уборку хранилища (4.8) прямо из теста.
- `TestData.cs` — общие заготовки: питомец, загрузка файла, картинки (с EXIF и без), PDF.
- Каждый тест устроен по схеме **подготовка → действие → проверка**. Имя теста — это требование, например `Pets_are_visible_only_inside_their_household`.

```csharp
var anna = api.ClientFor($"anna-{Guid.NewGuid():N}");          // подготовка: два разных человека
var oleg = api.ClientFor($"oleg-{Guid.NewGuid():N}");
var murka = await anna.CreatePetAsync("Murka");                //   у Ани есть кошка
var response = await oleg.GetAsync($"/api/v1/pets/{murka.Id}");  // действие: Олег пробует открыть её карточку
Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);    // проверка: для него этой кошки «нет»
```

Такая проверка «чужой не видит» есть для **каждого** адреса с `{id}`: питомцы, фото, паспорт, документы, файлы. Это защита от IDOR — ошибки, когда достаточно подставить чужой id. Чужое отвечает **404, а не 403**: так нельзя даже узнать, что такой id существует.

### 4.8. Файлы: от телефона до хранилища и обратно (`Modules/Documents/`, `Infrastructure/Storage/`)

Фото и сканы лежат не в базе, а в **хранилище объектов** — S3. Локально это SeaweedFS из AppHost, в продакшене будет Cloudflare R2. В базе хранится только запись о файле (`StoredFile`): чей он, какого типа и под каким ключом лежит.

```text
телефон ──POST /api/v1/files (multipart)──▶ FilesEndpoints.Upload
                                              │ 1. проверка размера (≤ 15 МБ)
                                              │ 2. FilePreparation: тип по первым байтам → фото перекодируется
                                              │ 3. ObjectStorage.PutAsync: фото + миниатюра в S3
                                              │ 4. строка StoredFile в базе
телефон ◀── 201 FileLink { id, url, thumbnailUrl, expiresAt } ──┘

телефон ──PUT /pets/{id}/photo { fileId } или POST /pets/{id}/documents { fileIds }──▶ файл «прикреплён»
телефон ──GET url (подписанная ссылка)──▶ S3 напрямую, без нашего API
```

**Загрузка** (`FilesEndpoints.cs`):

```csharp
files.MapPost("", Upload)                                   // :16 POST /api/v1/files
    .DisableAntiforgery()                                   // :22 защита от CSRF нужна сайтам с cookie, у нас токены
    .WithMetadata(new RequestSizeLimitAttribute(...));      // :23 сервер не примет тело больше ~16 МБ

if (file.Length > FilePreparation.MaxUploadBytes) ...       // :51 больше 15 МБ → 413
var prepared = FilePreparation.Prepare(upload);             // :65 разобрать и перекодировать
if (prepared is null) ...                                   // :66 не фото и не PDF → 415
await storage.PutAsync(stored.StorageKey, ...);             // :80 сначала байты в хранилище,
db.StoredFiles.Add(stored); await db.SaveChangesAsync(ct);  // :87 потом строка в базе
```

**Перекодирование** (`FilePreparation.cs`). Тип файла определяется по первым байтам, а не по имени: `cat.jpg` с HTML внутри получит 415. Фото декодируется и кодируется заново, поэтому:
- исчезает **EXIF** — в нём бывает геолокация дома;
- исчезает всё, что могли спрятать в файл;
- фото **поворачивается как надо** по метке ориентации камеры (`UprightMatrix`, строка 98);
- длинная сторона — не больше 2048 px. Ещё делается миниатюра 480 px для списков (строки 66-67).

**Подписанные ссылки** (`ObjectStorage.cs:108-120`). Хранилище закрыто: файл скачать нельзя без подписи. API выдаёт ссылку с подписью, которая живёт 15 минут (`LinkLifetime`, строка 29). Телефон качает по ней файл прямо из хранилища — наш сервер не гоняет через себя мегабайты. Ссылка меняется при каждом ответе, поэтому приложение кэширует картинки **по id файла**, а не по ссылке.

**Прикрепление и удаление** (`Files.cs`) — единственный «вход» в файлы для других модулей:

```csharp
public async Task<string?> AttachAsync(Guid householdId, IReadOnlyCollection<Guid> fileIds, bool photosOnly, CancellationToken ct)  // Files.cs:92 файл должен быть:
    // своей семьи, ещё нигде не использован, а для фото питомца — картинкой.
    // Иначе возвращается текст ошибки для 400.
    file.AttachedAt = now;                                  // :119 отметка «используется»

internal void Remove(IEnumerable<StoredFile> files)         // :140 удаление файла:
    db.StoredFiles.Remove(file);                            //     строка уходит из базы,
    db.StorageDeletions.Add(new StorageDeletion(file.StorageKey, now)); // :146 а объект ставится в очередь на удаление
```

**Почему удаление через очередь.** Строка в базе и объект в хранилище — две разные системы. Если удалять объект сразу, а база потом откатится (или наоборот), получится рассинхрон. Поэтому в одной транзакции с удалением строки пишется «задание» в таблицу `storage_deletions`. Фоновая уборка (`StorageCleanup.cs`) раз в минуту:
1. удаляет загрузки, которые за сутки так никуда и не прикрепили (строки 43-44). Кроме тех, что ещё нужны другим модулям, например фото скана, который ждёт проверки (строки 37-41, подробнее в 4.16);
2. удаляет объекты из очереди; при сбое запись остаётся и попробует снова (строки 56-67).

Этот приём называется **outbox** («исходящие»): внешние действия — только через таблицу-очередь. Так же устроены пуши (M4): напоминание сначала записывается строкой в таблицу, а отправляет его фоновая служба (4.17).

### 4.9. Документы и страницы (`DocumentsEndpoints.cs`)

Документ — это тип (`PassportPage`, `LabResult`…), необязательные название, дата и заметка, плюс **страницы**. Страница — это файл и его номер. Сканы паспорта — обычный документ типа `PassportPage`.

**Главное правило: страницы меняются по одной, список целиком никогда не присылается.**

```csharp
documents.MapPut("/{id:guid}", Update)                         // меняет только описание документа
documents.MapPost("/{id:guid}/pages", AddPages)                // :73 добавить страницы в конец
documents.MapDelete("/{id:guid}/pages/{fileId:guid}", RemovePage) // :77 удалить одну страницу

var lastPage = document.Pages.Count == 0 ? 0 : document.Pages.Max(p => p.PageNo); // :231 новые страницы — после последней
document.Pages.Remove(page);                                   // :253 убрать страницу (и её файл)
db.Documents.Remove(document);                                 // :257 удалили последнюю — удаляем и документ
```

**Почему так.** Сначала было `PUT` «вот новый полный список страниц». Ревью нашло, как это теряет данные даже на одном телефоне:
1. Телефон показывает список `[a]` и добавляет лист `b`. На сервере теперь `[a, b]`.
2. Обновить список на экране не удалось: пропала сеть, или вы ушли с экрана.
3. Вы добавляете лист `c`. Телефон, глядя на старый список, отправляет `[a, c]`, и сервер честно удаляет `b`.

С операциями «добавить» и «удалить одну» старый список ничего не испортит: добавление только добавляет, удаление трогает одну названную страницу.

Удаление питомца (`PetsEndpoints.cs:198-234`) удаляет его документы каскадом в базе. Файлы документов, записей ухода и фото удаляются явно (строки 212-222), чтобы их объекты попали в очередь уборки (как модули узнают об удалении — 4.15).

### 4.10. Питомец целиком: создание, проверка, чипы (`PetsEndpoints.cs`, `PetIdentifier.cs`)

Создание и изменение устроены одинаково:
1. **Проверить** запрос: `Validate` (строка 330) собирает все ошибки сразу в `ValidationErrors`. Клиент получает 400 со списком по полям, например `identifiers[0].code`, и может подсветить каждое поле.
2. **Найти** питомца только своей семьи: `FindAsync` (строки 288-291). Чужой id → 404.
3. **Перенести поля** из запроса в сущность: `Apply` (строка 294), одна функция и для создания, и для изменения.
4. **Сохранить**: `SaveChangesAsync`.

**Чипы и татуировки** (`IdentifierRules` в `PetIdentifier.cs`):

```csharp
Normalize(" 276 0981-0012 3456 ")      // :59 → "276098100123456": без пробелов, дефисов, точек, звёздочек
Validate(IsoChip, code)                 // :63 ISO: ровно 15 цифр, и не 999… (это тестовые чипы)
                                        //     старый формат США: 10 символов 0-9A-F или 9 цифр (AVID)
                                        //     татуировка: 1-20 букв и цифр
```

Исходный ввод тоже сохраняется (`RawCode`), чтобы показать «как в паспорте».

**Скан номера чипа** (`Modules/Ai/IdentifierScan.cs` и `IdentifierScanEndpoints.cs`, адрес `POST /pets/identifiers/scan`). У чипа в форме питомца есть кнопка «Сканировать номер» (5.7). Штрихкод с наклейки в паспорте телефон читает сам, без сервера. Сюда приходит только фото, на котором телефон штрихкода не нашёл: страница паспорта из мессенджера, номер, написанный от руки. Сервер отдаёт фото модели и возвращает прочитанные номера. Сам он ничего не сохраняет: номер попадает в форму, и сохраняет его человек кнопкой «Save», с обычными проверками.

```csharp
api.MapPost("/pets/identifiers/scan", Scan)                     // IdentifierScanEndpoints.cs:26 адрес среди питомцев, а код — в модуле Ai
var scan = await runner.RunAsync<IdentifierScan>(..., "identifier-scan", ...);  // :99 сразу, без очереди, как фото упаковки (4.19)
IdentifierReadings.From(scan.Value, Input.LatestToday(clock))    // :102 ответ модели → номера для формы
PetsEndpoints.ValidateIdentifiers(...)                           // IdentifierScan.cs:62 те же проверки, что у формы питомца
var same = readings.FindIndex(r => r.Code == reading.Code);      // :74 номер на наклейке и он же от руки — одна строка
```

- **Почему в модуле Ai.** Ai и так знает про Pets: скан паспорта читает чипы. А Pets про AI не знает ничего (4.15). Ответ модели — список тех же `ScannedIdentifier`, что в скане паспорта (`PassportScan.cs:61`). Промпт свой (`IdentifierScanPrompt`, `IdentifierScan.cs:96`): прочитать каждый номер чипа и татуировки, цифры — ровно как написано, ничего не «исправлять»; нет номера — пустой список.
- **Что возвращается** (`IdentifierReading`, строка 21): тип, номер без пробелов (`Code`) и как написан (`RawCode`), место и дата, если они написаны, и `Problem` — что сохранение не примет, например «An ISO microchip number has 15 digits.». Номер с ошибкой не выбрасывается: человек увидит его и поправит цифру. А вот дата в будущем и место длиннее 60 символов отбрасываются (строки 71-72): форма их всё равно не примет. Не заполняется и дата, где день и месяц можно перепутать (03.04.2021, строка 52): то же правило, что подсвечивает такие даты в скане паспорта (`ImportDrafts.IsAmbiguous`, 4.16). Если номер прочитан дважды и один раз с ошибкой (15 цифр как «чип не ISO»), остаётся тот, что сохранение примет (строка 82).
- **Ошибки — как у фото упаковки:** 409 — AI не настроен, 503 — модели заняты, 502 — провайдер отказал (строки 89-102). Текст провайдера остаётся в логе. Фото не хранятся: неприкреплённые загрузки удаляются через сутки (4.8).

**Цвет питомца** (`Coat`) — пережиток: с 2026-10-14 приложения его не показывают и не выбирают, всегда шлют `null` (у аватара нет своего цвета, решение владельца по правкам дизайнера). Поле осталось в API и базе: при создании без выбора сервер всё так же берёт цвет, которого ещё нет у питомцев семьи (`LeastUsedCoatAsync`, строка 322), а при правке без цвета оставляет прежний.

### 4.11. Шапка паспорта (`PassportEndpoints.cs`, `PetPassport.cs`)

Цифровая копия паспорта ничего не дублирует:
- **описание и чипы** (разделы II–III) берутся из питомца;
- **прививки и обработки** (разделы V–X) берутся из записей ухода (4.13);
- **в самой шапке** — только то, чего больше нигде нет: модель паспорта, номер, страна, дата выдачи, ветеринар, до двух владельцев.

Ветеринар и владельцы хранятся как **JSON внутри строки** паспорта (`PetConfiguration.cs:91-92`, `OwnsOne(...).ToJson()`). Это маленькие данные, которые всегда читаются вместе с паспортом, и отдельная таблица для них — лишняя сложность.

### 4.12. Уход: план, статус и «Сделано» (`Modules/Care/CarePlan.cs`)

**План** — «что и когда сделать»: прививка от бешенства раз в год, глистогонка раз в 3 месяца. Главное поле — `NextDueOn`, дата следующего раза. Разовый план (обработка перед поездкой) — это план без интервала.

**Статус** считается каждый раз заново, в базе его нет:

```csharp
public CareStatus StatusOn(DateOnly today) =>              // :70
    !Active ? CareStatus.Inactive                           // :71 выполнен (разовый) или на паузе
    : NextDueOn < today ? CareStatus.Overdue                // :72 срок прошёл — просрочено
    : NextDueOn <= today.AddDays(DueSoonDays) ? CareStatus.DueSoon  // :73 до 14 дней — скоро
    : CareStatus.Upcoming;                                  //     иначе — по плану
```

**«Сделано»** (`MarkDone`, строка 81) выбирает следующую дату в таком порядке:
1. дату, которую выбрал человек (строка 83) — ветеринар мог назначить иначе;
2. «действует до» препарата (строка 87) — у вакцины от бешенства это 1 или 3 года;
3. иначе — один интервал вперёд (строка 91).

Разовый план после «Сделано» выключается (строки 96-99).

**Интервал** прибавляется по-календарному (`Intervals.Add` в `CareTypes.cs:106`): 31 января + 1 месяц = 28 (или 29) февраля, а не 3 марта.

**Эндпоинт «Сделано»** (`CarePlansEndpoints.cs:271`) в одной транзакции создаёт запись истории (строка 320) и сдвигает план (строка 337).

**Повтор не отмечает дважды.** Представьте: телефон отправил «Сделано», сервер всё сохранил, а ответ потерялся в сети. Человек жмёт ещё раз. Без защиты получились бы две записи и срок, сдвинутый на два интервала. Защиты две:
1. приложение даёт каждому «Сделано» свой `requestId` и повторяет его при повторе. Сервер, увидев знакомый id (строка 294), возвращает первый результат;
2. **один план отмечается не чаще раза в день** (строка 308). Даже второе нажатие с нового экрана с новым id вернёт уже сделанную запись.

Так же устроено создание плана и записи (по `requestId`), а повторное прикрепление того же файла просто проходит.

**Пресеты** (`CarePresets.cs`) — готовые планы из приложения A спецификации: 36 штук для кошек и собак. Они живут в коде, а не в базе: меняются вместе с приложением, и тест проверяет их целиком. Главное правило безопасности — препарат «только для собак» нельзя назначить кошке:

```csharp
new("dog-advantix", Species.Dog, ..., DogOnly: true,       // CarePresets.cs:102 перметрин смертелен для кошек
...
else if (preset.DogOnly && species != Species.Dog)          // CarePlansEndpoints.cs:454 сервер отказывает: 400
```

**Быстрые тесты правил** (`tests/.../CarePlanRulesTests.cs`) проверяют `StatusOn`, `MarkDone` и пресеты без API и базы — за миллисекунды. Так удобно тестировать чистую логику: на вход данные, на выход ответ.

### 4.13. История и разделы паспорта (`Modules/Care/CareRecordsEndpoints.cs`)

**Запись** — «что сделано»: дата, препарат, серия, «действует с/до», клиника, ветеринар, фото наклейки. Записи вносятся тремя путями: «Сделано» на плане, вручную (например, из бумажного паспорта) и из AI-скана. Ручная запись план не сдвигает. Запись из скана, которую человек привязал к плану, сдвигает его как «Сделано», но по более осторожному правилу (4.16).

**Цифровой паспорт ничего не хранит отдельно.** Разделы V–X — это просто выборки из записей (`PassportRecords`, строка 154):

```csharp
Rabies: Section(PassportSections.IsRabies),                 // :174 V. прививки, где есть бешенство
...
Treatments: Section(r => r.Kind is Deworming or FleaTick or Heartworm),  // :177 VIII. обработки
OtherVaccinations: Section(r => r.Kind == Vaccination && !IsRabies(r)),  // :178 IX. остальные прививки
```

Комбинированная прививка «бешенство + чума» попадает в раздел V, как в бумажном паспорте.

**Фото записи** добавляются и удаляются по одному (`/care-records/{id}/files`), как страницы документов (4.9), и по той же причине.

### 4.14. Экран «Сегодня» и часовой пояс семьи (`Modules/Today/`, `Identity/HouseholdCalendar.cs`)

**«Сегодня» зависит от часового пояса.** В 23:30 в Берлине в Тбилиси уже завтра, и прививка «на завтра» там уже «сегодня». Поэтому дата берётся в поясе семьи (`HouseholdCalendar.cs:27`), а не по часам сервера.

`TodayEndpoints.GetToday` (`TodayEndpoints.cs:99`) собирает экран:
1. «сегодня» семьи, если клиент не передал дату сам (строка 122);
2. только активные питомцы, без архивных (строка 125);
3. планы, просроченные или со сроком в ближайшие 30 дней (`WindowDays`, строки 85 и 127);
4. имя, цвет и фото питомца — к каждой строке.

С M4 на экране ещё кормления этого дня с отметками (`FeedingDirectory`) и запланированные визиты: прошедшие за 7 дней, которые ещё не отмечены, и будущие на 30 дней (`AppointmentDirectory`). С M5 — что пора купить (`SupplyStock`, строка 192): закончилось или закончится за время доставки.

Модуль «Сегодня» сам ничего не хранит, он только читает чужие модули через их публичные службы: `CarePlanDirectory`, `FeedingDirectory`, `AppointmentDirectory`, `SupplyStock`, `PetDirectory`, `Files`.

**Местное время и летнее время** (`Infrastructure/Time/LocalTimes.cs`). Кормление «в 08:00» — это 08:00 по часам семьи, а напоминание отправляется в момент UTC. Перевод делает библиотека NodaTime со своей базой часовых поясов:

```csharp
Zone(zoneId).AtLeniently(LocalDate.FromDateOnly(date).At(LocalTime.FromTimeOnly(time)))  // LocalTimes.cs:35 дата и время семьи → момент
```

`AtLeniently` решает два неудобных случая. Весной время 02:30 пропускается (часы прыгают с 02:00 на 03:00), и оно наступает на час позже, в 03:30. Осенью 02:30 бывает дважды, и считается первое. Тест `Local_times_survive_daylight_saving_changes` в `RemindersTests.cs` проверяет оба случая на датах Берлина.

### 4.15. Как модули не знают друг о друге (`IPetDeletionHandler`)

При удалении питомца надо убрать его файлы во всех модулях: документы, записи ухода. Если бы модуль Pets сам вызывал каждый, он зависел бы от всех них, а они — от него: получился бы клубок.

Поэтому Pets объявляет только интерфейс «перед удалением питомца» (`PetsEndpoints.cs:573`), а модули его реализуют:

```csharp
builder.Services.AddScoped<IPetDeletionHandler>(sp => sp.GetRequiredService<PetDocuments>()); // Program.cs:132 документы
builder.Services.AddScoped<IPetDeletionHandler, CareRecordFiles>();  // :133 уход

IEnumerable<IPetDeletionHandler> otherModules,                       // PetsEndpoints.cs:203 DI подаёт всех сразу
foreach (var module in otherModules)                                 // :216 каждый убирает своё
```

Появится новый модуль с файлами — он просто зарегистрирует ещё одну реализацию. Код Pets менять не придётся.

Строка 59 записана иначе, чем 60: `PetDocuments` нужен не только при удалении питомца. AI-скан сохраняет через него фото страниц (4.16). Поэтому он зарегистрирован сам по себе (строка 58), а строка 59 говорит: «как обработчик удаления используй тот же экземпляр».

Тем же приёмом уборщик хранилища узнаёт, какие неприкреплённые файлы ещё нужны другим модулям (`IUploadKeeper`, 4.16). Сам модуль документов про AI-скан ничего не знает.

И тем же приёмом напоминания узнают об изменениях в базовых модулях. Питомца убрали в архив или сменился часовой пояс семьи — напоминания надо перепланировать. Но Pets и Identity не должны знать про модуль уведомлений, поэтому Identity объявляет интерфейс `IHouseholdChangeHandler` (`Identity/HouseholdChanges.cs`), а модуль уведомлений его реализует (4.17):

```csharp
await listener.HouseholdChangedAsync(me.HouseholdId, ct);   // PetsEndpoints.cs:192 после сохранения питомца
```

### 4.16. AI-скан на сервере (`Modules/Ai/`)

**Что делает скан.** Человек фотографирует страницы паспорта. Сервер отдаёт фото модели (сейчас Gemini) и получает список записей. Из него сервер собирает **черновик**, человек проверяет его на экране и сохраняет нужное. Сам AI в данные ничего не пишет: сохраняет всегда человек, теми же проверками, что и ручной ввод.

**Одна розетка для любых моделей.** У Google, OpenAI и локальной Ollama разные библиотеки. Библиотека Microsoft.Extensions.AI сводит их к одному интерфейсу `IChatClient`: «отправь сообщения, получи ответ». Фабрика (`AiClients.cs`) делает такой клиент для нужного провайдера:

```csharp
AiProvider.Gemini =>                                      // AiClients.cs:41 Google, ключ из настроек
AiProvider.OpenAICompatible =>                            // :46 Groq, OpenRouter и все с API «как у OpenAI»
AiProvider.Ollama =>                                      // :56 модель на своём компьютере
```

Какие модели спрашивать и в каком порядке, записано в `appsettings.json` (секция `Ai`, строки 21–34). Ключ Gemini в репозиторий не попадает: AppHost берёт его из секретов Mac и передаёт серверу переменной окружения (`AppHost.cs:30-33`).

**Цепочка моделей** (`AiRunner.RunAsync`). Бесплатные модели бывают заняты («high demand»), упираются в лимит запросов или просто молчат. Поэтому сервер спрашивает их по очереди, пока одна не ответит:

```csharp
foreach (var model in Models(profile).Where(clients.IsConfigured))   // AiRunner.cs:119 модели по порядку из настроек
db.AiUsage.Add(usage);                                               // :122 каждая попытка идёт в расход за месяц
attempt.CancelAfter(timeout);                                        // :125 ждём 40 с + 10 с на фото, не дольше
var response = await clients.Create(model).GetResponseAsync<T>(      // :128 запрос с JSON-схемой ответа
usage.Count(response.Usage);                                         // :130 сколько токенов ушло (ниже)
catch (OperationCanceledException e) when (!ct.IsCancellationRequested)  // :139 не успела — спросим следующую
catch (Exception e) when (!ct.IsCancellationRequested && WorthTryingTheNextModel(e))  // :143 занята — следующая
throw new AiRejectedException($"{model} refused the request: {e.Message}", e);  // :149 неверный ключ — стоп
```

**Сколько стоил запрос** (`AiUsage.Count`, `AiRunner.cs:71`). Модель сначала «размышляет», потом отвечает. Google берёт деньги за размышления как за ответ. Но библиотека Gemini отдаёт их отдельным полем, а библиотеки «как у OpenAI» — уже внутри ответа. Поэтому:

```csharp
OutputTokens = Provider == AiProvider.Gemini && usage?.ReasoningTokenCount is { } thinking  // :75 у Gemini размышления
    ? usage.OutputTokenCount.GetValueOrDefault() + thinking                                  //     прибавляем к ответу
    : usage?.OutputTokenCount;                                                               //     у остальных они уже там
```

В `OutputTokens` — всё, за что платим как за ответ, а в `ReasoningTokens` — сколько из этого заняли размышления. До 2026-10-14 размышления Gemini не записывались, поэтому старый расход занижен.

**Сколько модели думать** (`AiRunner.ChatOptionsFor`, строка 103). Настройка `Ai:Thinking` (`AiOptions.cs:56`): `Low`, `Medium` или `High`. Не задана — каждая модель решает сама; так сейчас и работает. Задать её можно без новой версии приложения. Модель, которая не умеет думать, на неё откажет, поэтому все модели цепочки должны её понимать.

`WorthTryingTheNextModel` (строка 173) и решает, что делать с ошибкой. «Занято» (503), «лимит» (429), «нет такой модели» (404), обрыв связи, таймаут или битый ответ — дело в этой модели, следующая может справиться. «Неверный ключ» (401, 403) или «плохой запрос» (400) у всех моделей будет тот же: цепочка останавливается.

**Что модель должна вернуть** (`PassportScan.cs`). Ответ описан C#-записями: `ScannedRecord`, `ScannedDate` и другие. Тексты `[Description(...)]` уходят модели вместе с JSON-схемой ответа: это инструкции для неё, а не комментарии для нас. Например:

```csharp
[property: Description("When it was done.")]               // PassportScan.cs:35 подсказка модели к полю даты
```

Дата приходит тремя частями: текст как на странице, ISO-дата и порядок, который модель предположила (`ScannedDate`, строки 20–26). Что не читается, модель возвращает как `null`: угадывать запрещено (`PassportScan.cs:117`, текст запроса к модели).

**Очередь и фоновая работа** (`AiImportWorker.cs`). Модель думает от нескольких секунд до минуты, держать запрос телефона открытым столько нельзя. Поэтому:
1. `POST /ai-imports` сохраняет импорт со статусом `Queued` и будит фоновую службу. Телефону сразу отвечает «202, принято».
2. Обработчик **забирает** импорт одной командой SQL (строки 31–35): «поставь `Processing`, только если он ещё `Queued`». Даже два обработчика не возьмут один импорт дважды.
3. Читает фото. Если какого-то нет, это ошибка `PhotosMissing` (строка 50): тогда номера страниц в ответе не совпали бы с фото.
4. Спрашивает цепочку моделей (промпт — строка 57) и сохраняет **ответ модели как есть** (`scan_json`).
5. Записывает результат только если импорт всё ещё `Processing` (строка 90 и ниже). Если человек за это время выбросил скан, тот так и останется выброшенным.

Если сервер останавливается посреди чтения, импорт возвращается в очередь (строки 76–81). После запуска служба первым делом дочитывает такие импорты (`RequeueAsync`, строка 171).

**Черновик** (`ImportDraft.cs`) собирается **заново при каждом чтении** импорта (`AiImportsEndpoints.cs:609`). Ответ модели сверяется с тем, что сохранено у питомца *сейчас*. Сохранили запись из другого скана — в этом черновике она уже помечена «уже есть». Проверки:

```csharp
Flag(warnings, CareRecordsEndpoints.Validate(request, latestToday), prefix: "");  // ImportDraft.cs:199 то же, что при сохранении
warnings.Add(new("issuingCountry", DraftIssue.DiffersFromSaved));               // :403 страну не перезапишем молча
SuggestPlans(records, saved.Plans);                                             // :223 к какому плану это «Сделано»
private static bool OnlyNotes(List<DraftWarning> warnings) => warnings.All(w => w.Issue == DraftIssue.Ambiguous);  // :433
```

Последняя строка — правило отметки по умолчанию. Запись отмечена, если в ней нечего исправлять. «Проверь день и месяц» — только подсказка, отметку она не снимает.

**Спорные даты** (`IsAmbiguous`, строка 359). В «03/04/2025» день и месяц могут стоять в любом порядке: это 3 апреля или 4 марта. Такая дата подсвечивается. «13/04/2025» не подсвечивается (тринадцатого месяца нет), «3 Apr 2025» тоже (месяц словом).

**Запись из скана сдвигает план — но не всякая** (`PlanSummary.MovedBy`, `CarePlansEndpoints.cs:532`):

```csharp
if (LastDoneOn is { } last && performedOn <= last)       // CarePlansEndpoints.cs:534 не новее последнего «Сделано» — нет
if (performedOn >= CreatedOn)                            // :539 сделано после создания плана — как «Сделано»
&& (validUntil ?? Intervals.Add(performedOn, every, unit)) > NextDueOn;  // :545 старая запись — только позже
```

Два примера:
- План «Бешенство» создан сегодня «на сегодня», в паспорте прививка 2025 года до 2028-го. Запись старше плана, но сдвигает срок позже: план переезжает на 2028 год.
- Разовая «обработка перед поездкой» через 20 дней, в паспорте обработка 2025 года. Запись старше плана и разовый план не закроет: поездка не пропадёт из «Сегодня».

**Сохранение черновика** (`Apply`). Двойное нажатие «Сохранить» не должно сохранить записи дважды. Поэтому всё сохранение идёт в одной транзакции, которая сначала **блокирует строку** импорта:

```csharp
.FromSql($"SELECT * FROM ai.imports WHERE id = {id} AND household_id = {me.HouseholdId} FOR UPDATE")  // AiImportsEndpoints.cs:406
// Applied already (a retry after a lost response): answer as the first time, save nothing.          // :369
await care.ValidatePlanLinksAsync(import.PetId, links, errors, ct);   // :466 план того же вида и тех же болезней
var plansMoved = (await care.MovePlansAsync(created, ct)).Count;      // :487 сдвинуть планы по правилу выше
var answer = await db.Database.CreateExecutionStrategy().ExecuteAsync(ApplyOnce);  // :514 при обрыве связи — всё заново
```

Второй запрос ждёт, пока первый закончит, и видит «уже сохранено». Тогда он возвращает тот же ответ (строка 228), ничего не записывая.

**Выбросить и повторить.** Сохранённый скан выбросить нельзя: `DELETE` ответит 409 «уже сохранено» (строка 330). Иначе после потерянного ответа на «Сохранить» приложение сказало бы «скан удалён», хотя записи уже в базе. А «Повторить» после неудачи — это новый скан тех же фото; неудачный при этом уступает ему место и пропадает из списка (строки 161-166).

**Фото ждут проверки.** Неприкреплённые загрузки уборщик удаляет через сутки (4.8). Но черновик может пролежать и неделю, а неудачный скан — дождаться «Повторить». Поэтому модули говорят уборщику, какие файлы им ещё нужны — тем же приёмом, что и в 4.15:

```csharp
public interface IUploadKeeper                                         // StorageCleanup.cs:12 «мне это ещё нужно»
needed.AddRange(await keeper.NeededUploadsAsync(ct));                  // :40 спросить все модули
.Where(f => f.AttachedAt == null && f.CreatedAt < cutoff && !needed.Contains(f.Id))  // :44 нужные не трогать
public sealed class AiImportUploads(AppDbContext db, TimeProvider clock) : IUploadKeeper  // AiImport.cs:163 фото сканов — до 30 дней
```

**Тесты без Google.** В тестах вместо настоящих моделей подставлен `FakeAi` (`tests/.../FakeAi.cs`). Тест сам говорит, что «модель» ответит (`Answer`, строка 17) или что она зависнет (`Hangs`, строка 20). Так проверяются цепочка, таймаут и ошибки, без интернета и без расхода квоты. Настоящий Gemini проверяют `RealAiTests.cs`: нарисованные страницы и фото настоящих паспортов из папки `backend/tests/ai-samples` (её нет в git, инструкция — в её README). Там же, в `ai-samples/chips`, фото наклеек с чипом для скана номера (4.10): имя фото — номер на нём. Эти тесты запускаются только с `COLLARBELL_REAL_AI=1`.

### 4.17. Напоминания на сервере (`Modules/Notifications/`)

**Что такое напоминание.** Это строка таблицы `notifications.reminders` (класс `Reminder`, `Reminder.cs:77`): «семье X в момент Y напомнить о Z». Строки появляются заранее, а фоновая служба отправляет их, когда момент наступил. Так напоминание видно ещё до отправки: на телефоне в «Ещё → Уведомления» есть список ближайших.

**Одно событие — одно напоминание.** У каждой строки есть «адрес события»: источник, его id и ключ (`Key`, строка 108), например «план X, срок 10 октября, за 7 дней» — `2026-10-10/-7`. Эта тройка уникальна в базе:

```csharp
b.HasIndex(x => new { x.Source, x.SourceId, x.Key }).IsUnique();   // NotificationsConfiguration.cs:20 одно событие — одна строка
b.HasIndex(x => x.DueAt).HasFilter("status = 'Pending'");          // :22 быстрый ответ на «что пора отправить»
b.Property(x => x.Status)...IsConcurrencyToken();                   // :31 два процесса не перепишут статус друг другу
```

Поэтому сколько раз ни планируй заново, одно событие не напомнится дважды.

**Кто решает, о чём напоминать.** Модуль уведомлений ничего не знает о планах, визитах и кормлении. Он спрашивает модули через интерфейс — тот же приём, что `IPetDeletionHandler` (4.15):

```csharp
public interface IReminderSource                                        // ReminderSchedule.cs:17
Task<IReadOnlyList<PlannedReminder>> PlanAsync(Guid householdId, ...)   // :28 «какие напоминания мне нужны»
Task<IReadOnlyDictionary<Guid, ReminderContent>> ComposeAsync(...)      // :34 «что сказать; нужно ли ещё»
```

Реализаций четыре: `CarePlanReminders` (уход), `AppointmentReminders` (визиты), `FeedingReminders` (кормление) и `SupplyReminders` (запасы, 4.19). Они зарегистрированы в `Program.cs` (4.1), и DI подаёт их все сразу.

**Планирование** (`ReminderSchedule.PlanAsync`, строка 82). Сравнивает «что нужно» с тем, что уже лежит в таблице:

```csharp
plans = await source.PlanAsync(householdId, timeZone, now, ct);      // ReminderSchedule.cs:97 спросить модуль
catch (Exception e) when (e is not OperationCanceledException)       // :99 модуль упал — остальные всё равно планируются
if (reminder.Status == ReminderStatus.Pending && reminder.FireAt > now && !wanted.ContainsKey(key)  // :136 больше не нужно — удалить
if (plan.FireAt > now)                                               // :147 новое — только если ещё впереди
if (reminder.Status != ReminderStatus.Pending)                       // :155 отправленное не трогаем: дважды не напомним
if (reminder.FireAt != plan.FireAt)                                  // :160 время сдвинулось (новый пояс) — сдвинуть
```

Кто вызывает планирование:
- модули после каждого изменения: `reminders.RefreshAsync(me.HouseholdId, ct)` (строка 52). Например, после «Сделано», после сохранения расписания кормления или визита;
- модули Pets и Identity — через интерфейс `IHouseholdChangeHandler` (4.15): питомца убрали в архив, сменился часовой пояс;
- фоновая служба `ReminderPlanner` раз в 10 минут планирует все семьи (`PlanAllAsync`, строка 178). Так кормления всегда расписаны на 48 часов вперёд, а если обновление после изменения почему-то не прошло, через 10 минут всё исправится само.

Повод, о котором напомнили давно, тоже не добавляется второй раз (строка 122). Такое бывает, когда его время снова оказалось впереди: например, у товара поменялись дни на доставку. Без этой проверки база отказала бы из-за повтора уникального ключа, и вся семья осталась бы без новых напоминаний.

`RefreshAsync` не падает, даже если планирование не удалось (строка 58). Изменение человека к этому моменту уже сохранено, и ответ «ошибка» его бы только запутал. Ошибка пишется в лог, а фоновая служба исправит.

**Отправка** (`ReminderDispatcher.cs`). Фоновая служба раз в 15 секунд вызывает `RunOnceAsync` (строка 34):

```csharp
WHERE status = 'Pending' AND due_at <= {now}                // ReminderDispatcher.cs:61 что пора отправить
FOR UPDATE SKIP LOCKED                                      // :64 строки заперты: второй сервер возьмёт другие
if (!contents.TryGetValue(reminder.Id, out var content))    // :91 модуль сказал «уже не нужно» — пропустить
else if (now - reminder.FireAt > CatchUpWindow(reminder.Category))  // :95 слишком поздно — не будить зря
else if (!push.IsConfigured)                                // :99 у сервера нет ключа Firebase
```

**Окна досылки** (`CatchUpWindow`, строка 27). Если сервер был выключен, напоминание опаздывает. «Пора кормить» через час бесполезно, поэтому кормление досылается только в пределах 30 минут, остальное — в пределах суток. Что опоздало сильнее, получает статус «опоздало» и не отправляется.

**Один пуш на несколько напоминаний** (строка 118). Если в один момент у семьи несколько напоминаний одного вида, приходит один пуш: «Кормление в 08:00: Мурка, Барсик» или «Уход: 3 напоминания». Визиты не склеиваются (строка 122): у каждого своё время и место. Текст пуша собирается для каждого человека на его языке (`ReminderTexts.Compose`, строка 137; все тексты пушей — в `ReminderTexts.cs`).

**Что бывает с отправкой:**

```csharp
if (results.Contains(PushResult.Delivered))                 // ReminderDispatcher.cs:149 хоть один телефон получил — «отправлено»
else if (results.All(r => r == PushResult.InvalidToken))    // :153 все телефоны «удалены» — некому отправить
TryLater(reminder, canRetry: results.Contains(PushResult.TryAgain), now);  // :159 Firebase занят — ещё раз позже
var gone = await db.Devices.Where(d => invalidTokens.Contains(d.Token)).ExecuteDeleteAsync(ct);  // :168 забыть удалённые телефоны
```

Повторы — через 1, 5 и 15 минут (`RetryDelays`, строка 21), потом «не доставлено». Всё это видно на телефоне в журнале напоминаний.

**Firebase** (`PushSender.cs`). Пуш на телефон отправляет Firebase Cloud Messaging. Сервер передаёт ему адрес телефона (токен), текст, канал и срок жизни:

```csharp
Priority = Priority.High,                                    // PushSender.cs:129 будить спящий телефон: напоминание не ждёт
TimeToLive = message.TimeToLive,                             // :130 кормление живёт час, потом бесполезно
Notification = new AndroidNotification { ChannelId = ..., Tag = ... },  // :131 канал вида и «замени прежний такой же»
if (... account.ProjectId != projectId)                      // :89 ключ чужого проекта — пуши выключены
MessagingErrorCode.Unregistered => PushResult.InvalidToken,  // :166 только «не зарегистрирован» значит «телефона больше нет»
```

Ключ Firebase — секрет. Он лежит в секретах AppHost, как ключ Gemini (4.6). Без ключа напоминания планируются и видны в журнале, только не отправляются.

**Тесты без Firebase.** В тестах вместо Firebase подставлен `FakePush` (`tests/.../FakePush.cs`): он запоминает каждый «доставленный» пуш, а тест может сделать телефон «удалённым» или Firebase «занятым». Время тесты не ждут: они вызывают диспетчер с нужным моментом сами (`api.SendRemindersAsync(момент)`). Так проверяются окна досылки, повторы и переход на летнее время (`RemindersTests.cs`).

### 4.18. Кормление и визиты на сервере (`Modules/Routines/`, `Modules/Appointments/`)

**Расписание кормления** (`Routine.cs`) — это времена суток, дни недели, корм и порция. Отметка «покормили» — отдельная строка `RoutineCompletion`, и база не даст отметить одно кормление дважды:

```csharp
b.HasIndex(x => new { x.RoutineId, x.Date, x.Time }).IsUnique();   // RoutinesConfiguration.cs:48 одно кормление — одна отметка
public bool OccursAt(DateOnly date, TimeOnly time) => ...          // Routine.cs:89 есть ли такое кормление в этот день
```

**Отметка с двух телефонов** (`RoutinesEndpoints.Complete`, строка 244). Аня и Борис нажали «Покормили» одновременно. Первая вставка проходит, вторая упирается в уникальный индекс:

```csharp
catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: ... UniqueViolation })  // RoutinesEndpoints.cs:305
return first.DoneBy == me.UserId ? TypedResults.Ok(response) : TypedResults.Conflict(response);  // :312 свой повтор — ок, чужой — 409
```

Ответ 409 несёт, кто и когда отметил, и приложение пишет «Уже отмечено: Аня, 08:02».

**Напоминания о кормлении** (`FeedingReminders.cs`) — одно на время кормления семьи, сразу для всех питомцев. Они расписаны на 48 часов вперёд (`Horizon`, строка 17). Перед отправкой модуль смотрит отметки: уже покормленных из текста убирает, а если покормлены все, пуш не нужен (строки 68–69).

**Напоминания об уходе** (`CarePlanReminders.cs`) — за 7, 1 и 0 дней до срока в 10:00 по времени семьи (`At`, строка 19), и пока план не сделан, ещё раз каждые 3 дня, не больше 5 раз. Перед отправкой проверка (строка 70): план всё ещё ждёт того же срока? После «Сделано» срок другой, и старое напоминание уже не нужно.

**Визиты** (`AppointmentsEndpoints.cs`) задаются датой и временем семьи. Сервер переводит их в момент UTC с учётом летнего времени (`LocalTimes.Moment`, 4.14). Напоминания по умолчанию за сутки и за 2 часа (`AppointmentReminders.cs`). Напоминание «в момент начала» может прийти до 15 минут после начала (`Grace`, строка 17). Визит, все питомцы которого в архиве, не напоминает (строка 39).

**«Визит состоялся»** (`Complete`) за одно сохранение:
- ставит визиту статус «состоялся»;
- создаёт каждому питомцу запись выбранного вида (осмотр после ветеринара, груминг после грумера);
- отмечает выбранные человеком планы «Сделано».

Повтор ничего не меняет. Чтобы двойное нажатие не создало записи дважды, статус визита защищён так же, как статус напоминания: второй запрос видит «уже состоялся».

### 4.19. Запасы на сервере (`Modules/Supplies/`)

**Что хранится** (`SupplyItem.cs`).
- `SupplyItem` — товар: название, бренд, штрихкод, вид (сухой корм, влажный, лакомства, наполнитель, препарат, другое), единица (граммы, миллилитры, штуки, дозы), размер упаковки, калорийность, откуда брать расход (из кормлений или вручную), дни на доставку и ссылка на магазин.
- `StockEvent` — одна запись остатка. «Покупка» прибавляет количество. «Поправка» говорит, сколько осталось сейчас, и с неё начинается новый отсчёт.
- `Product` — общий каталог товаров, которые подтвердили пользователи. В следующий раз штрихкод находится там без AI.

Все количества хранятся в единице товара. Пачка 2 кг — это `PackageSize = 2000` граммов, две такие пачки — покупка на 4000.

**Прогноз** (`SupplyForecasts.Compute`, `SupplyForecast.cs:58`) — главная функция модуля:

```csharp
var start = ordered.FindLastIndex(e => e.Kind == StockEventKind.Adjustment);  // SupplyForecast.cs:63 отсчёт — от последней поправки
start = ordered.FindIndex(e => e.Kind == StockEventKind.Purchase);  // :66 поправок не было — от первой покупки
level = Math.Max(0, level - Used(usage, since, purchase.At)) + purchase.Quantity;  // :79 расход до нуля, потом покупка
var remaining = Math.Max(0, level - Used(usage, since, now));  // :83 сколько осталось сейчас
var runsOutAt = since.AddDays((double)(level / perDay));  // :97 момент «закончится» не зависит от «сейчас»
var buyBy = runsOutOn.AddDays(-leadTimeDays);  // :99 купить до = закончится − дни на доставку
```

Почему «до нуля»: пачка, купленная через неделю после того, как старая кончилась, должна начинаться полной. Если бы расход вычитался просто за всё время, неделя без корма «съела» бы новую пачку.

Почему момент «закончится» считается от последней записи, а не от «сейчас»: тогда даты не скачут, пока идёт время. Напоминания на эти даты остаются на своих местах.

Статус товара (строка 101):
- «Закончился»;
- «Купить» — день покупки наступил;
- «Скоро» — купить в ближайшие 7 дней;
- «Хватает»;
- «Остаток не указан» — ещё не было ни покупки, ни поправки;
- «Расход не задан».

**Расход** (`UsagePerDay`, строка 109). Если расход задан вручную, он и берётся. Иначе складываются порции кормлений, где выбран этот корм. Кормления отдаёт модуль Routines (`FeedingSupplies`, `Routines/FeedingSupplies.cs`): только действующие кормления и только питомцев не в архиве. «Сколько раз в день» — это число кормлений × число дней недели / 7 (строка 37). Два раза в день, но только по выходным, — это 4/7 раза в день.

Порция считается, только если она в единицах товара: граммы к граммам, штуки к штукам (`SameUnit`, строка 128). Сервер и не даст сохранить кормление с порцией в других единицах.

Всё вместе собирает `SupplyStock.StatesAsync` (строка 151): товары семьи, их записи, кормления и прогноз. Им пользуются адреса запасов, экран «Сегодня» и напоминания.

**Адреса** (`SuppliesEndpoints.cs`):
- список сначала показывает то, что кончается раньше (строка 187);
- новый товар сразу получает поправку «сейчас есть» (строка 248);
- переименованный товар переименовывает корм в своих кормлениях (строка 326);
- покупка товара из «Больше не покупаем» снова делает его активным (строка 416).

Покупка и новый товар, как «Сделано», принимают `requestId`: повтор после потерянного ответа не посчитает покупку дважды.

**Напоминания «Пора купить»** (`SupplyReminders.cs`) встроены в общий механизм напоминаний (4.17). Модуль говорит, когда напомнить (`Moments`, строка 79):

```csharp
if (buyAt <= now && status == SupplyStatus.BuyNow)  // SupplyReminders.cs:85 день покупки уже прошёл — напомнить в ближайшие 10:00
if (buyAt < outAt)  // :93 «купить» — только если раньше, чем «заканчивается»
```

Ключ напоминания — `2026-10-14/buy/2026-10-09`: «закончится 14-го, купить до 9-го». Покупка сдвигает дату «закончится», а с ней и ключ. Поэтому старое напоминание больше не нужно, и планировщик его убирает. Перед отправкой модуль ещё раз сверяет дату (строка 62).

**Штрихкод** (`ProductLookup.cs`):
- `Gtin.Normalize` приводит код к одному виду: UPC-A из 12 цифр и GTIN-14 с нулём впереди становятся EAN-13, а EAN-8, дополненный нулями, снова становится EAN-8 (строка 41). Последняя цифра — контрольная: опечатка в цифрах почти всегда ловится.
- `ProductCodes.Parse` (строка 79) читает и GS1 DataMatrix — квадратный код с упаковок лекарств. В нём поля идут подряд: `01` — номер товара, `17` — срок годности, `10` — серия.
- `ProductLookup.FindAsync` ищет по порядку: свой каталог (строка 261), потом внешние базы. На каждую базу даётся 6 секунд (строка 271). Медленная или недоступная база просто пропускается.
- Open Pet Food Facts — открытая база кормов. Из её ответа берутся название на языке пользователя, бренд, размер (`product_quantity`, строка 406), вид по категориям и калорийность на 100 г × 10 (строка 431).
- UPCitemdb — общая база товаров. Бесплатно — 100 запросов в день, и она знает только название и бренд.
- В каталог товар попадает, когда человек сохраняет его в запасы (`ConfirmAsync`, строка 293). Первая подтверждённая версия остаётся: чужое название её не перезапишет. Подтверждения считаются одной командой базы (строка 337), чтобы два одновременных сохранения не потеряли счёт. Товары из Open Pet Food Facts в каталог не копируются.

**Фото упаковки** (`ProductScan.cs`, адрес `POST /products/scan`, строка 486 в `SuppliesEndpoints.cs`) читаются сразу, без очереди. Скан паспорта идёт через очередь (4.16): там много страниц и долгий ответ. Здесь одна упаковка — это несколько секунд, а при сбое человек просто переснимет. Модель отвечает по схеме `ProductScan`. `ProductDraft.From` (строка 98) приводит ответ к виду формы:

```csharp
( > 0, EnergyUnit.KcalPer100g) => value * 10,  // ProductScan.cs:160 «386 ккал/100 г» — это 3860 ккал/кг
(unit, size) = (SupplyUnit.Dose, count);  // :114 у лекарства размер — число доз
Gtin.Normalize(barcode) ?? Gtin.Normalize(scan.Barcode?.Replace(" ", "", StringComparison.Ordinal)),  // :126 отсканированный код важнее цифр с фото
```

Килограммы становятся граммами, литры — миллилитрами. Неправдоподобное (размер 0) отбрасывается: такое поле человек заполнит сам. Ошибки AI приходят кодами (409 — AI не настроен, 503 — модели заняты, 502 — провайдер отказал), а не текстом провайдера (строка 539). Так же устроено чтение номера чипа с фото (4.10).

### 4.20. Сервер в интернете (`deploy/`, `backend/Dockerfile`)

С 2026-10-05 приложение ходит не к Mac, а к серверу в интернете: **<https://collarbell.example.com>**. Это бесплатное имя от sslip.io, оно просто указывает на IP сервера. Сервер общий: на нём работают и другие проекты. Поэтому всё наше лежит в одной папке `/opt/collarbell`, а общего тронуто только три вещи: файл сайта в nginx, сертификат и одна строка с ключом деплоя. Подробно, с командами — `deploy/README.md`.

**Что там работает** (`deploy/compose.yml`, пять контейнеров одного проекта Docker):

| Контейнер | Что делает | Строка |
|---|---|---|
| `web` | nginx: страницы лендинга и «развилка» адресов | `compose.yml:14` |
| `api` | наш API, образ из `backend/Dockerfile` | `:29` |
| `postgres` | база | `:53` |
| `storage` | файлы (SeaweedFS, как локально в AppHost) | `:71` |
| `backup` | каждую ночь копия базы и файлов, хранится 14 дней | `:90` |

Снаружи виден только `web`, и только на самом сервере (`127.0.0.1:5180`, строка 22). Базу и файлы из интернета не достать.

**Путь запроса.** Телефон → `https://…` → nginx сервера (`deploy/host-nginx.conf`: HTTPS и «всё на 127.0.0.1:5180») → контейнер `web`, который по адресу решает, куда дальше (`deploy/nginx.conf`):

```nginx
location /api/ {          # nginx.conf:25 запросы приложения → контейнер api
location = /health {      # :51 «сервер жив?» — спрашивают приложение и скрипт деплоя
location /collarbell/ {   # :57 ссылки на фото и документы → хранилище, только скачивание
location / {              # :70 всё остальное — страницы лендинга
```

Ссылка на файл подписана для адреса сервера, поэтому хранилище должно увидеть тот же адрес и путь, что и телефон. Отсюда `proxy_set_header Host $host`.

**Как новая версия попадает на сервер.** После `git push` в `main` на GitHub идут проверки (`ci.yml`). Если они зелёные, запускается `deploy.yml`: он заходит на сервер по SSH особым ключом. Этот ключ умеет только одно — запустить `/opt/collarbell/deploy` (копия `deploy/deploy.sh`) и передать ему номер коммита:

```bash
sha="${SSH_ORIGINAL_COMMAND:-${1:-}}"                      # deploy.sh:8 номер коммита — единственное, что можно передать
if ! git merge-base --is-ancestor "$sha" origin/main; then  # :23 только коммиты из main
git checkout --quiet --force --detach "$sha"                # :35 взять этот коммит
  bash deploy/release.sh                                    # :38 и выложить
```

`deploy/release.sh` выкладывает так, чтобы ошибка не уронила работающую версию:

```bash
docker tag "$image:current" "$image:previous"   # release.sh:33 запомнить работающую версию
if ! compose build; then                        # :38 собрать новую, пока старая работает
if ! compose run --rm api migrate; then         # :44 новая версия обновляет базу (4.1, строка 241); ошибка → ничего не меняем
compose up -d --remove-orphans                  # :51 заменить контейнеры
if ! healthy; then                              # :52 две минуты ждём ответа /health; нет ответа →
  restore_previous                              # :55 вернуть прежнюю версию
```

Поэтому миграции базы должны быть «обратно совместимыми»: сначала добавляем новое, старое удаляем позже. Тогда и прежняя версия работает с обновлённой базой.

**Секреты** — в файле `/opt/collarbell/.env` на сервере (что в нём — `deploy/env.example`). В git их нет.

**Где смотреть, что происходит:** GitHub → Actions → Deploy (вывод каждой выкладки); на сервере `/opt/collarbell/deploy.log` и логи контейнеров (команды — в `deploy/README.md`).

**Лендинг** (`landing/`) — сайт на Astro: из файлов `.astro` при сборке получаются обычные HTML-страницы. Их собирает и кладёт в nginx `deploy/web.Dockerfile`, так что лендинг выкладывается вместе с API, той же кнопкой.

**Как лендинг выглядит.** Цвета, размеры и шрифты не записаны в стилях числами: их даёт `landing/src/styles/tokens.css`, который `npm run tokens` строит из общего `design/tokens.json` (тот же источник, что у приложения, веба и админки; CI проверяет его командой `npm run check-tokens`). Остальные стили — в `src/styles/global.css`. Правила палитры: белые страницы и сине-серый интерфейс; зелёный — действия, двух оттенков: яркий `primary` (#00B53F) — только заливка (главная кнопка, на ней белый жирный текст), а зелёный текст, ссылки, маленькие иконки и рамка фокуса — темнее, `primary-text` (#007F2B), иначе на белом не читаются; жёлтый — «скоро», но только заливкой под тёмным текстом (метка «Раннее тестирование», жёлтые кружки под иконками «Скоро», кремовое предупреждение с жёлтой рамкой), потому что жёлтый текст на белом не читается; красный — только «просрочено». Все кнопки высотой 44 px, контур у кнопок с обводкой — 1,5 px. Жирность букв только 400, 500 и 700.

**Шрифт** — Helvetica Neue там, где она есть (Mac, iPhone), иначе Arimo: бесплатный двойник Arial с теми же ширинами букв. Файлы Arimo лежат в `src/fonts/` (переменные шрифты: все жирности от 400 до 700 в одном файле, отдельно латиница и кириллица), правила — в `src/styles/fonts.css`. Заранее шрифт не загружается (`preload` нет): на Mac и iPhone Arimo вообще не скачивается, а в других системах, пока он грузится, текст показан в Arial и не сдвигается.

**Иконки сайта.** `public/favicon.svg` нарисован вручную по иконке приложения (`mobile/tool/icon`) в тех же цветах. Из него и иконки приложения скрипт `sh landing/tool/make-assets.sh` делает `apple-touch-icon.png`, `favicon.ico` и картинку для превью ссылок `og-image.png` (иконка и слово Collarbell шрифтом Arimo Bold на мятном фоне). Если дать скрипту ещё две папки со скриншотами, он заодно обновит скриншоты приложения на главной (`src/assets/screens`).

**Иконки на страницах** — Material Symbols Rounded толщины 400 в рисунке для крупного размера (оптический размер 48): на 20–24 px он чуть тоньше обычного, как просил дизайнер; толщина 300 оказалась вдвое тоньше, те же у веба и админки. Это контуры SVG: список «имя → путь» лежит в `landing/src/icons.ts`, `web/src/components/icons.ts` и `admin/src/components/icons.ts`. Руками пути не пишутся: `node tools/icons.mjs` (из корня репозитория) берёт их из пакета Google `@material-symbols/svg-400`, версия закреплена — 0.47.5, и переписывает во всех трёх списках, а заодно в стрелке выпадающего списка веба (`web/src/styles/app.css`, картинка с `id='expand_more'`). Пакет — 20 МБ картинок, поэтому в проекты он не ставится: скрипт сам один раз скачивает его во временную папку системы. Новая иконка — строка `имя: '',` в списке и тот же запуск; если такого имени в пакете нет, скрипт останавливается с ошибкой, так что пустой иконки не будет. `--check` только сверяет списки с пакетом. Четыре имени Google с тех пор переименовал (`expand_more`, `expand_less`, `smartphone`, `phone_iphone`): у нас остались старые, а скрипт знает новые (`RENAMED`). Рисунки в пакете сделаны для крупного размера (оптический размер 48), поэтому на 20–24 px линии заметно тоньше прежних.

### 4.21. Группы и роли на сервере (`Modules/Identity/HouseholdsEndpoints.cs`, `HouseholdAccess.cs`)

С M6 питомцами можно делиться: семья, коллеги, ситтер. Данные по-прежнему принадлежат группе (`Household`), просто в группе теперь может быть несколько людей, а у человека — несколько групп. Какая группа у запроса, решает `CurrentUserAccessor` (4.4) по заголовку `X-Household`.

**Роли** (`HouseholdRole`, `Entities.cs`): владелец — всё и люди; участник — всё с питомцами, но не люди; помощник (ситтер, коллега) — видит всё и только отмечает. Проверяет их одно место — фильтр перед каждым адресом `/api/v1` (`HouseholdAccess.cs`):

```csharp
public enum HouseholdAccessRule                                     // HouseholdAccess.cs:7 особые отметки адресов:
//  Helpers  — помощнику тоже можно (его отметки),
//  Owners   — только владельцам (люди и настройки группы),
//  Personal — свои вещи человека: профиль, телефон, группы, приглашения
_ => HttpMethods.IsGet(method) || ... || role != HouseholdRole.Helper, // :30 без отметки: читать — всем, менять — не помощнику
accessor.AnyHouseholdWillDo = access?.Rule == HouseholdAccessRule.Personal; // :92 «личным» адресам чужая группа не мешает
return HouseholdAccess.Allows(access, me.Role, http.Request.Method)  // :109 можно — дальше, нельзя — 403 role-forbidden
```

Главная идея: **новый адрес по умолчанию закрыт для помощника**. Чтобы открыть, нужно явно написать `.AllowHelpers()`, а тест `The_endpoints_open_to_helpers_and_owners_only_are_the_approved_ones` (`HouseholdsTests.cs`) сравнивает все такие отметки со списком одобренных: случайно открытый адрес провалит проверки.

**Приглашения.** Владелец создаёт одноразовый код из 8 символов без похожих букв и цифр (`InviteCodes.New`, строка 636), он живёт 7 дней. Код отправляется в теле запроса, а не в адресе: адреса попадают в журналы серверов.

```csharp
invites.MapPost("/accept", Accept)                                  // HouseholdsEndpoints.cs:135 вступить по коду
.FromSql($"SELECT * ... WHERE code = {normalized} FOR UPDATE")       // :499 строка кода заблокирована: двое одновременно не вступят
if (invite?.AcceptedBy == me.UserId)                                // :503 повторное нажатие — тот же ответ, а не ошибка
```

Подбирать коды бессмысленно: не больше 10 попыток за 10 минут на человека (`app.UseRateLimiter()`, 4.1), а вариантов кода больше триллиона.

**В группе всегда есть владелец.** Последний владелец не может уйти или стать участником (409 `last-owner`). Чтобы два владельца не сложили роль одновременно, изменения людей идут под блокировкой строки группы:

```csharp
private static Task LockAsync(...) => ... FOR NO KEY UPDATE         // :565 одна смена людей группы за раз
if (!await IsOwnerAsync(db, me, ct))                                // :293 роль вызывающего — ещё раз, уже под блокировкой
await RevokeInvitesOfAsync(db, me.HouseholdId, userId, ...)         // :314 бывший владелец: его коды больше не работают
```

**Ответы-отказы** несут тип (`HouseholdProblems`, `HouseholdAccess.cs`): `not-a-household-member`, `role-forbidden`, `last-owner`, `already-a-member` и другие. Приложение по типу показывает свой текст на языке пользователя (5.19).

**Пуши** уходят всем участникам группы, и в каждом указана группа (`ReminderTexts.InHousehold`): нажатие открывает её, а кормление в 08:00 в двух группах не заменяет одно уведомление другим.

### 4.22. Админка, визор и оповещения (`Modules/Observe/`, `Modules/Admin/`, `admin/`)

**Админка** — сайт по адресу `/admin/` (папка `admin/`, React). Туда входят той же почтой и паролем, что и в приложение, но пускают только админов: флаг `IsAdmin` у пользователя. Ставят его на сервере командой `make-admin <почта>` (`Program.cs:264`), поэтому почта админа не лежит в репозитории.

```csharp
public static RouteGroupBuilder MapAdminEndpoints(...)              // AdminEndpoints.cs:118 адреса /api/admin/...
    .AddEndpointFilter<AdminOnlyFilter>()                           // :122 перед каждым — «админ ли это?»
    .ExcludeFromDescription();                                      // :123 их нет в контракте приложения
var isAdmin = await db.Users.Where(u => u.Id == me.UserId)...       // :459 проверка в базе на каждом запросе: снять флаг — и доступа нет сразу
```

Страницы: обзор (люди, напоминания, телефоны, AI, ошибки, диск, бэкап, последние оповещения), люди и их группы, группа, проблемы за сутки и визор.

**Визор** — лента одного человека за неделю: что делало его приложение и что ответил сервер. Две половины:

- **Журнал запросов.** Каждый запрос к `/api/v1` записывается: кто, в какой группе, адрес без параметров, ответ, время, запуск приложения (`X-App-Session`) и версия (`X-App-Version`). Запрос не ждёт базы: записи копятся в очереди и раз в пару секунд уходят пачкой.

```csharp
app.UseMiddleware<RequestLogMiddleware>();                           // Program.cs:198 первым: видит ответ таким, каким он ушёл
if (context.GetEndpoint() is not null || accessor?.KnownUserId ...) // RequestLog.cs:152 только настоящие адреса API: чужой мусор не пишется
catch (DbUpdateException)                                            // :83 база отказала пачке — пишем по одной, плохую выбрасываем
```

- **События приложения** (`POST /api/v1/events`, `AppEventsEndpoints.cs`): какой экран открыт, несколько действий («Покормили»), какие ошибки увидел человек, падения. Никогда не то, что он ввёл. Не больше 2000 в день на человека (строка 98), управляющие символы вырезаются (строка 123), а если часы телефона спешат, вся пачка сдвигается назад целиком (строка 103).

Всё это хранится 7 дней, потом удаляется (`ObserveRetention`). Об этом сказано в политике конфиденциальности.

**Оповещения** (`Alerts.cs`). Раз в 5 минут сервер смотрит на себя: задерживаются ли напоминания, много ли ошибок, отвечает ли AI, свежий ли бэкап, хватает ли места, удаляется ли вход удалённых аккаунтов (4.25). Найденное уходит в Telegram боту @collarbell_alerts_bot (токен и чат — в `.env` на сервере):

```csharp
public async Task<List<(string Kind, string Text)>> RunOnceAsync(...) // Alerts.cs:65 все проверки разом
if (known.TryGetValue(kind, out var last) && now - last.SentAt < ...) // :125 одна и та же беда — не чаще раза в 6 часов
throw new InvalidOperationException($"Telegram refused ...")           // :50 Telegram отказал — не считается отправленным
```

Адрес запроса к Telegram содержит токен, поэтому у этого HTTP-клиента журнал выключен (`RemoveAllLoggers` в `Program.cs`).

**Сайт админки** (`admin/src/`): вход через Firebase (`session.tsx:39`), потом `GET /api/admin/me` — 403 значит «не админ». Все запросы идут с токеном Firebase (`api/client.ts:44`). Для разработки есть режим с выдуманными данными: `npm run dev:mock` в папке `admin/`.

**Как админка выглядит** (`admin/src/styles/app.css` поверх `src/styles/tokens.css`). Токены, шрифт и его файлы — те же, что у лендинга (4.20): `npm run tokens` в `admin/` строит `tokens.css` из `design/tokens.json`, шрифт описан в `src/styles/fonts.css`. Цвет значит одно и то же на всех страницах: зелёный — «в порядке», жёлтый — «стоит посмотреть», красный — «беда», и рядом с цветом всегда иконка и слово. Зелёный двух оттенков, как в вебе (5.26): яркий `primary` — заливки (кнопка «Войти», полоски на обзоре), на главной кнопке белый жирный текст; `primary-text` — зелёный текст, ссылки, выбранный пункт меню и чип, иконки у заголовков, рамка поля в фокусе. Жёлтый никогда не бывает цветом текста. «Стоит посмотреть» — это жёлтая таблетка с тёмным текстом (`Badge tone="warning"`, медленный ответ в визоре, «Premium закончился», «лимит почти исчерпан») или кремовая плашка с жёлтой рамкой 1,5 px (`Notice tone="warning"`, жёлтые плитки и список «Требует внимания» на обзоре). Красное — красная таблетка с белым текстом или красный текст с иконкой. Все кнопки одной высоты, 44 px (маленьких кнопок больше нет); между кнопками 8 px в ряд и 12 px, когда они переносятся на новую строку. Иконка вкладки — `public/favicon.svg`, такая же, как у лендинга. Иконки на страницах — `src/components/icons.ts`, толщина 300, пути пишет `tools/icons.mjs` (4.20).

Русские тексты админки, как и всех остальных частей, держат короткие слова при следующем слове неразрывным пробелом (`tools/typograph.py`). Там, где код сам склеивает число и слово («3 события», «ещё 30 дней», «12 сент.»), он тоже ставит неразрывный пробел (`lib/format.ts`). Тесты сравнивают тексты, считая такие пробелы обычными: в `app.test.tsx` это делает обёртка `plainQueries` над поиском по тексту.

### 4.23. Тарифы: Free и Premium (`Modules/Billing/`)

Тариф принадлежит **группе**: в одной группе он общий для всех участников. Строка в `billing.plans` хранит последнее изменение тарифа. Нет строки — группа на Free. Оплаты пока нет: Premium выдаётся вручную в админке (карточка «Тариф» на странице группы → `PUT /api/admin/households/{id}/plan`).

```csharp
public bool IsPremiumAt(DateTimeOffset now) => ...                  // Plans.cs:81 Premium действует, пока не прошла дата окончания
public PlanLimits Free { get; set; } = new() { AiPhotosPerMonth = 20 }; // :165 лимиты по умолчанию; Premium — 300 (настройка Plans)
public PlanState Effective(HouseholdPlan? row) => ...                // :194 что действует сейчас: просроченный Premium = Free
```

**Лимит — ИИ-фото в календарный месяц (UTC).** Считается каждая картинка, которую читает ИИ: страница паспорта, наклейка чипа, упаковка, картинка проверки связи.

**Фото считаются как бронь в гостинице** (таблица `billing.ai_charges`, строка `AiPhotoCharge`, `Plans.cs:102`). Перед чтением фото бронируются. Если ИИ ответил, бронь списывается, если нет — снимается, и фото возвращаются в лимит.

```csharp
public enum AiChargeState                                           // Plans.cs:85 Held — бронь, Charged — списано, Released — возвращено
public async Task<(...)> TryHoldAsync(...)                           // :245 влезут ли фото; если да — бронь
var personUsed = await Counted().Where(c => c.UserId == userId ...)  // :258 на Free ещё и личный предел человека во всех его группах на Free
private const long CountingLock = 0x436F6C6C_41490001;               // :187 замок: брони считаются по одной
public Task SettleAsync(Guid holdId, bool answered, ...)             // :306 списать (ответил) или вернуть (не ответил)
public static readonly TimeSpan HoldLifetime = TimeSpan.FromHours(1); // :184 бронь, которую никто не закрыл (сервер перезапустился), через час не считается
```

Почему так:
- **Замок.** Без него десять запросов, отправленных одновременно, увидели бы одинаковый счётчик и прошли бы все. Замок `pg_advisory_xact_lock` заставляет их считать по одному. Это несколько миллисекунд, сам ИИ ждёт уже без замка.
- **Каждый тариф считает свои фото.** Фото, потраченные на Free, не съедают Premium, выданный в середине месяца, и наоборот.
- **Личный предел на Free.** Без него человек создавал бы новые группы и получал бы по 20 фото в каждой. Брони не удаляются вместе с группой (`SET NULL`), поэтому удалить группу и создать новую тоже не поможет.

Бронируют все четыре места, где ИИ читает фото:
- проверка связи — `AiEndpoints.cs:108`;
- скан чипа — `IdentifierScanEndpoints.cs:78`;
- скан упаковки — `SuppliesEndpoints.cs:537`.

Каждое из них в `finally` закрывает бронь (`:139`, `:121`, `:580`), даже если чтение сорвалось.

Скан паспорта идёт в фоне, поэтому он бронирует фото в той же транзакции, где создаётся (`AiImportsEndpoints.cs:207`). Бронь закрывает фоновый обработчик, когда чтение кончилось (`AiImportWorker.cs:113`). Если скан убрали из очереди до начала чтения, бронь сразу снимается (`AiImportsEndpoints.cs:540`).

Если фото не влезают, ответ — 409 с типом `urn:collarbell:problem:ai-limit` (`Plans.cs:178`, `:331`). В нём есть тариф, лимит, сколько использовано, сколько просили, когда счётчик обнулится и чей предел кончился (`scope`: группы или человека). Приложение объясняет это своими словами.

Ещё у этих четырёх адресов ограничение частоты: не больше 10 запросов в минуту на человека (`Program.cs:82`). Оно бережёт общий ключ ИИ от потока запросов.

**Что видит приложение:** `GET /api/v1/plan` (`PlanEndpoints.cs:29`) — тариф, до какого числа он действует, сколько фото группы использовано из скольких, когда счётчик обнулится и сколько даёт Premium.

**Что будет потом** (спецификация, 8.7). Premium покупают на сайте через Paddle или в App Store. RevenueCat сообщает серверу о покупке, и сервер пишет ту же строку `billing.plans` с источником `Paddle` или `AppStore`. Остальной код при этом не меняется.

### 4.24. Обновление экранов у всей группы: SignalR (`Modules/Live/`)

Задача: Боря отметил кормление, и у Ани на открытом экране «Сегодня» отметка появляется сразу, без «потянуть вниз». Для этого открытое приложение держит с сервером постоянное соединение (WebSocket), а сервер шлёт по нему короткий сигнал «вот это изменилось, перечитай».

**Хаб — точка, к которой подключается приложение** (`HouseholdHub.cs:70`, адрес `/hubs/household`):

```csharp
public override async Task OnConnectedAsync()                         // HouseholdHub.cs:77 приложение подключилось
if (householdId is not { } id || !await IsMemberAsync(id, userId, ct)) // :95 сначала проверить, что человек в этой группе
await live.JoinAsync(Context.ConnectionId, userId, id, ct);           // :105 потом записать соединение в группу «household:{id}»
if (!await IsMemberAsync(id, userId, CancellationToken.None))         // :108 и проверить ещё раз
await live.LeaveAsync(Context.ConnectionId, id);                      // :115 что-то пошло не так после записи — выписать обратно
public Task Ready() => Task.CompletedTask;                            // :128 «я уже слышу группу»: приложение спрашивает это сразу после подключения
```

- Вход тот же, что у обычных запросов: токен Firebase в заголовке `Authorization`, группа — в заголовке `X-Household`.
- Человек не в этой группе — сервер закрывает соединение с ошибкой и запрещает переподключаться (`HouseholdHub.NotAMember`).
- **Почему проверка два раза.**
  - Первая — до записи: посторонний не попадает в группу даже на миг и ничего не услышит, пока его проверяют.
  - Вторая — после записи: если Аня удалит Борю ровно в эту секунду, удаление всё равно найдёт его соединение и выведет из группы (`LiveChanges.LeftAsync`).
- **Почему «выписать обратно».** Если после записи что-то сорвалось (телефон ушёл в фон, база не ответила), сам SignalR про это соединение забудет, а наш учёт — нет. Без выписки место в лимите осталось бы занятым навсегда.
- **Зачем `Ready`.** Приложение считает соединение открытым чуть раньше, чем сервер запишет его в группу. `Ready` отвечает только после записи. Поэтому приложение перечитывает экраны после ответа и ничего не пропускает.

**Сигнал** — `Changed { topics, origin }` (`HouseholdHub.cs:13`, `:25`). Данных в нём нет, только тема: `pets`, `care`, `feeding`, `visits`, `supplies`, `documents`, `passport`, `imports`, `household`, `plan` (`:31` и ниже). Из сигнала нельзя узнать больше, чем покажет следующий обычный запрос, а его сервер проверяет как всегда.

**Кто шлёт сигналы.** Почти всё — одна строка в каждом модуле:

```csharp
api.MapGroup("/routines").WithTags("Feeding").ReportsChanges(LiveTopics.Feeding);  // RoutinesEndpoints.cs:81 метка на группе адресов
.AddEndpointFilter<LiveChangesFilter>();                                           // Program.cs:217 общий фильтр всех /api/v1
http.Response.OnCompleted(() => http.Response.StatusCode is >= 200 and < 300       // LiveChanges.cs:178 сигнал — когда ответ ушёл и он успешный
```

- Фильтр срабатывает на изменения (не GET) с меткой. Сигнал уходит, только когда ответ уже отправлен и он успешный (2xx). К этому моменту изменение точно сохранено в базе, поэтому никто не услышит о том, чего нет.
- Ошибочный запрос (400, 403, 409…) никому ничего не шлёт.
- Метки стоят на питомцах, паспорте, уходе, кормлении, визитах, запасах, документах и AI-сканах.
- У некоторых адресов метка шире, чем у их группы:
  - правка расписания кормления меняет и прогноз запасов: `feeding` + `supplies` (`RoutinesEndpoints.cs:77`);
  - «визит состоялся» пишет записи ухода: `visits` + `care` (`AppointmentsEndpoints.cs:102`);
  - сохранение AI-скана — сразу несколько тем (`AiImportsEndpoints.cs:96`);
  - сканы чипа и упаковки и проверка связи ничего не сохраняют, но тратят AI-фото месяца: `plan` (`AiEndpoints.cs:65`, `IdentifierScanEndpoints.cs:28`, `SuppliesEndpoints.cs:175`).
- Сигналят и сами, потому что их группа — не группа запроса или сигнал нужен не всегда:
  - вход по приглашению — `HouseholdsEndpoints.cs:551`;
  - удаление участника или уход — `:385`;
  - новое имя человека — во все его группы (`MeEndpoints.cs:191`). Приложение присылает профиль при каждом запуске, поэтому сигнал уходит, только если имя правда поменялось;
  - смена тарифа в админке — `AdminEndpoints.cs:400`;
  - законченный AI-скан в фоне — `AiImportWorker.cs:116`.
- Тест `Every_change_is_heard_or_left_out_on_purpose` (`LiveTests.cs:441`) проверяет все изменяющие адреса `/api/v1`. У каждого должна быть метка, иначе он должен стоять в списке исключений с причиной. Новый адрес без метки уронит этот тест.

**Своё не перечитываем дважды.** Приложение шлёт со всеми запросами заголовок `X-Client` — случайный id своего запуска (`LiveChanges.cs:18`). Сервер возвращает его как `origin` только на соединения того же человека, остальным — `null` (`:101`, `:112`). Телефон, сделавший изменение, сигнал пропускает: свой экран он уже обновил. Чужие id телефонов никто не узнаёт, поэтому выдать своё изменение за чужое нельзя. Принимаются только буквы, цифры и дефис, до 64 символов (`:36`).

**Защита:**
- одному человеку — не больше 10 соединений сразу (`LiveChanges.cs:21`). Подсчёт и запись идут одним шагом под замком (`:45`), так что одновременные подключения не проскочат вместе. Соединения, которые уже закрылись, не считаются (`:49`);
- удалённый из группы сразу выводится из неё: он слышит один сигнал `household` и больше ничего (`:126`). Ушедший сам не слышит свой уход на том телефоне, где ушёл;
- сигнал не дошёл — не беда: после переподключения приложение перечитывает данные группы.

**Подключение в `Program.cs`:**
- `AddSignalR` (`Program.cs:124`): приложение шлёт только `Ready` и пинги, поэтому размер сообщений ограничен 4 КБ;
- `MapHub` (`Program.cs:241`): только WebSockets, вход обязателен.

На сервере WebSocket пропускают оба nginx: на хосте (`deploy/host-nginx.conf`) и в контейнере `web` (`deploy/nginx.conf`), раздел `location /hubs/`.

**Тесты** — `LiveTests.cs`:
- отметка доходит до всех в группе и ни до кого вне её;
- чтение и ошибки сигналов не шлют;
- вход по приглашению слышит группа, в которую вошли;
- удалённый слышит один раз и больше ничего;
- посторонний не слышит группу даже во время проверки (тест держит таблицу участников под замком, чтобы проверка ждала);
- оборвавшиеся во время проверки соединения не занимают мест;
- больше 10 соединений нельзя;
- новое имя, фоновые сигналы (AI-скан, тариф) и полный список изменяющих адресов.

### 4.25. Удаление аккаунта и выгрузка данных на сервере (`Identity/AccountDeletion.cs`, `AccountExport.cs`)

Задача: человек нажимает «Удалить аккаунт», и сервер стирает всё, что принадлежит только ему, не ломая жизнь тем, с кем он делил группу. Рядом «Скачать мои данные»: всё то же самое, но не стереть, а отдать одним ZIP-файлом. Этого требуют Google Play, App Store и GDPR (право на удаление и на копию своих данных).

**Три адреса** (`MeEndpoints.cs:47`, `:53`, `:58`):
- `GET /me/deletion` — что удаление сделает с каждой группой, ничего не меняя, и «отпечаток» этого плана. Приложение показывает это до кнопки;
- `DELETE /me?plan=…` — удалить, если план всё ещё тот, что показан;
- `GET /me/export` — ZIP со всеми данными.

**Сначала решается судьба каждой группы** (`AccountDeletion.cs:278-284`):

```csharp
var heir = theirs.FirstOrDefault(o => o.Role == HouseholdRole.Member);   // AccountDeletion.cs:278 участник, вступивший раньше всех
theirs.Count == 0 ? (HouseholdFate.Deleted, null)                        // :280 кроме меня никого — удалить
: h.Role != HouseholdRole.Owner || theirs.Any(...Owner) ? (Kept, null)   //      есть другой владелец или я не владелец — остаётся как есть
: heir is not null ? (HouseholdFate.HandedOver, heir)                    // :284 я последний владелец — группа переходит участнику
: (HouseholdFate.Deleted, null);                                         //      остались одни помощники — удалить
```

Помощник (ситтер, коллега) группу не получает: его пустили помогать, а не хранить записи о чужих питомцах.

**Удаляется то, что человек видел.** Вместе с судьбами сервер отдаёт их отпечаток: короткую строку из id групп, судеб и новых владельцев (`Fingerprint`, `AccountDeletion.cs:232`). Приложение присылает её обратно в `DELETE /me?plan=…`. Пока человек вводил пароль, кто-то мог вступить в его группу по старому коду. Тогда группа, которая на экране «удалится», на деле перешла бы новичку вместе с паспортом, где адрес хозяйки. Поэтому сервер сравнивает отпечаток под замками (`:165`). Не совпал — ничего не удаляется, ответ 409 `deletion-plan-changed` (`MeEndpoints.cs:105`), и приложение показывает новую картину.

**Пароль ещё раз** (`MeEndpoints.cs:98`). В токене Firebase есть `auth_time` — когда человек последний раз вводил пароль (`CollarbellClaims.cs:19`). Если это было больше 5 минут назад (`AccountDeletion.cs:114`), сервер отвечает 403 `recent-sign-in-required`, и приложение просит пароль. Так одного разблокированного телефона на столе мало. Dev-пользователь «ввёл пароль только что», а тест может сказать иначе заголовком `X-Dev-Auth-Time` (`DevUserAuthenticationHandler.cs:44`).

**Само удаление — одна транзакция** (`DeleteAsync`, `AccountDeletion.cs:129`). Сломается что угодно — не удалится ничего:

```csharp
.SqlQuery<string>($"SELECT auth_subject ... FOR UPDATE")             // AccountDeletion.cs:146 замок на строку человека
if (subject is null)                                                  // :148 его уже нет — удалил запрос, который мы ждали
$"SELECT id FROM identity.households WHERE id = {householdId} FOR UPDATE", ct);  // :161 замки на его группы
plans = await PlanAsync(userId, ct);                                  // :164 судьбы — уже под замками
if (confirmedPlan is not null && confirmedPlan != Fingerprint(plans)) // :165 не тот план, что показан, — ничего не делать
await module.BeforeHouseholdDeletedAsync(plan.Outcome.Id, ct);       // :181 модули ставят файлы группы в очередь удаления
await db.Households.Where(h => h.Id == plan.Outcome.Id).ExecuteDeleteAsync(ct);  // :185 группа и всё в ней (каскад)
await module.BeforeAccountDeletedAsync(userId, ct);                   // :198 модули стирают своё о человеке (журнал визора)
await db.Users.Where(u => u.Id == userId).ExecuteDeleteAsync(ct);     // :203 сам человек
db.DeletedAccounts.Add(new DeletedAccount(subject, clock.GetUtcNow())); // :205 «надгробие»
```

- **Замки `FOR UPDATE`** держат строку человека и строки его групп до конца транзакции. Кто в эту секунду вступает по приглашению, загружает фото или добавляет питомца в эти группы, ждёт и потом находит группу удалённой. Поэтому судьбы не устаревают, пока идёт удаление, и в группе не появляется ничего, что не удалится. Вступление тоже берёт сначала группу, потом код (`HouseholdsEndpoints.cs:497`), в том же порядке, что и удаление. Так два запроса не ждут друг друга по кругу, и вступивший не услышит «вы вступили» про группу, которая через миг исчезнет.
- **Второе удаление в ту же секунду** (двойное нажатие, повтор после потерянного ответа) ждёт первое, видит, что человека уже нет (`:148`), и отвечает 204, а не ошибкой.
- **Файлы.** База удаляет строки файлов вместе с группой сама, а объекты в хранилище — нет. Поэтому модуль документов ставит каждый файл группы в очередь `storage_deletions` одним запросом (`Files.cs:161`, `:167`). Уборка хранилища (4.8) удалит их за минуту. Фото, которое долетело до хранилища, пока группу удаляли, сохранить уже некуда. Тогда загрузка сама удаляет его объекты (`FilesEndpoints.cs:95`) и отвечает «вы не в этой группе» (`:98`).
- **Модули не знают друг о друге** — тот же приём, что с удалением питомца (4.15). Identity объявляет `IHouseholdDeletionHandler` и `IAccountDeletionHandler`, модули Documents и Observe их реализуют (`Files.cs:161`, `RequestLog.cs:231`).
- **Журнал визора не помнит удалённого.** Записи о нём стираются в той же транзакции. Сам запрос удаления записывается уже без человека (`current.Forget()`, `MeEndpoints.cs:111`). Журнал пишется пачками раз в 2 секунды. Перед записью пачка держит строки своих людей (`RequestLog.cs:70`), а у кого строки уже нет, записи остаются без него (`:74`). События приложения с другого телефона ждут удаление так же и не записываются (`AppEventsEndpoints.cs:89`).
- **Что остаётся в общих группах.** Строка человека удаляется, а его отметки кормления, покупки и записи остаются. Ссылка на него в них становится пустой: внешний ключ с `SET NULL` (`RoutinesConfiguration.cs:54`). Раньше отметки кормления удалялись вместе с человеком. Для группы на двоих это плохо: у второго кормление снова «не покормлено», и кошку покормили бы дважды. Написанное в записях (например, данные владельца в паспорте) остаётся как есть: это данные группы.

**«Надгробие» — удалённый вход** (`Entities.cs:171`). Токен Firebase живёт до часа, и на втором телефоне человека он ещё работает. Без надгробия первый же запрос с ним молча завёл бы новый пустой аккаунт. Теперь `CurrentUserAccessor.cs:68` видит, что такой вход удалён, и отвечает 401 `account-deleted` (`HouseholdAccess.cs:104`, в админке — `AdminEndpoints.cs:453`). Приложение по этому ответу выходит из аккаунта. Кроме идентификатора входа, в надгробии ничего нет.

**После транзакции:**
- остальные в группах слышат «группа изменилась» и перечитывают список людей, а телефоны удалённого слышат это последний раз (`AccountDeletion.cs:223`, см. 4.24);
- сервер удаляет вход в Firebase (`AccountDeletion.cs:227`). Это делает `FirebaseSignInAccounts` (`SignInAccounts.cs:79`) тем же ключом Firebase, что и пуши. «Такого пользователя нет» — тоже успех (`SignInAccounts.cs:82`);
- если Firebase не ответил, `AccountCleanup` повторяет раз в 10 минут (`AccountDeletion.cs:314`). Не вышло и через час — оповещение в Telegram (`Alerts.cs:101`): возможно, у ключа Firebase отобрали права;
- через сутки после удаления входа надгробие стирается (`AccountDeletion.cs:310`, `:328`): токенов, которые могли бы с ним прийти, к этому времени уже нет.

**Выгрузка — ZIP, который пишется прямо в ответ** (`AccountExport.cs:112`):
- `README.txt` (`AccountExport.cs:139`) — что где лежит, на языке человека;
- `account.json` (`AccountExport.cs:152`) — аккаунт и то, что модули добавили о человеке: уведомления, телефоны, потраченные AI-фото, журнал за неделю;
- на каждую группу `households/N-имя/household.json` (`AccountExport.cs:176`), а рядом все её файлы (`AccountExport.cs:200`). Владельцу ещё и приглашения, но без кодов (`AccountExport.cs:165`): открытый код пускает любого, а выгруженный файл легко переслать.

Каждый модуль сам говорит, что у него есть. Для этого он реализует `IPersonalExportSource` или `IHouseholdExportSource` (`AccountExport.cs:55`, `:61`). Например, модуль документов отдаёт документы и все файлы группы (`DocumentsEndpoints.cs:416`), в том числе ещё нигде не использованные (`:429`): фото несохранённого скана — тоже данные, которые хранит сервер. AI-сканы отдаёт модуль AI (`AiImportsEndpoints.cs:640`), потраченные AI-фото — модуль тарифов (`PlanEndpoints.cs:63`). Порядок разделов в household.json — порядок регистрации в `Program.cs:104` и ниже.

- **Сущности уходят как есть**, кроме полей, которые вне сервера ничего не значат: путь в хранилище, адрес телефона для пушей, ключ повтора запроса, id группы в каждой строке (`AccountExport.cs:95`, вычёркивает их `AccountExport.cs:244`). Новое поле в сущности само попадёт в выгрузку. Если оно секретное, его надо добавить в этот список.
- **Помощник видит только свою почту**, как и в приложении (`AccountExport.cs:223`).
- **Файл, который хранилище сейчас не отдаёт, не обрывает архив.** Остальные идут дальше, а `files-missing.txt` называет пропущенный (`AccountExport.cs:196`, `:203`).
- **Почему через память по одной записи** (`PassOnStream`, `AccountExport.cs:281`). Классы ZIP в .NET 10 дописывают конец каждой записи синхронно, а сервер запрещает блокирующую запись в ответ. Поэтому каждая запись (один файл) сначала собирается в памяти, а потом асинхронно уходит в ответ (`AccountExport.cs:136`). В памяти одновременно не больше одного файла, а скачивание начинается сразу, даже если архив большой.
- **Не больше 5 выгрузок в час** на человека (`Program.cs:86`): каждая читает все файлы его групп.

**Удаление по письму** (для тех, у кого нет приложения). На сервере есть команда `delete-account <почта>` (`Program.cs:295`). Без `--yes` она только показывает, что будет с группами, с `--yes` — удаляет тем же кодом, что и кнопка в приложении (`deploy/README.md`). Команда работает отдельным процессом, поэтому живые сигналы до телефонов не доходят: они узнают об удалении при следующем запросе (401).

**Тесты** — `AccountTests.cs`, `AccountDeletionRaceTests.cs` и `LiveTests.cs`:
- одинокий аккаунт: группа, питомцы, файлы, отметки и запасы удалены, в хранилище ничего не осталось, вход удалён в Firebase;
- токен удалённого аккаунта получает 401 и не заводит нового, в том числе в админке;
- без свежего пароля — 403, ничего не удалено;
- план изменился (кто-то вступил по старому коду) — 409, ничего не удалено; новый план — удаление;
- общая группа остаётся, отметка остаётся без имени, повторно отметить то же кормление нельзя;
- последний владелец передаёт группу первому участнику, а не помощнику;
- если остались одни помощники, группа удаляется, и помощник получает свою;
- при другом владельце группа остаётся как есть;
- Firebase отказал — вход удаляется позже, через сутки надгробие стирается; застрял дольше часа — оповещение;
- в журнале не остаётся ничего с id удалённого;
- другой телефон в ту же секунду (`AccountDeletionRaceTests.cs`): вступление по приглашению получает «не найдено», загруженное фото не остаётся в хранилище, удалённое фото не мешает удалению, события приложения не записываются, второе удаление отвечает 204. Тест запускает такой запрос изнутри удаления, пока оно держит замки, и смотрит на оба ответа;
- выгрузка: состав архива, все виды записей, файлы байт в байт, ничего лишнего, почта у помощника, пропавший файл, лимит;
- живые сигналы при удалении.

### 4.26. Вес питомца на сервере (`Modules/Pets/WeightsEndpoints.cs`)

Задача: человек раз в месяц взвешивает кошку дома и хочет видеть журнал и график. На осмотре кошку взвешивает и ветеринар, и этот вес уже есть в записи осмотра (4.13). Хранить его второй раз нельзя: поправят в одном месте, а в другом останется старое число. Поэтому у журнала веса **два источника**, и сервер собирает их в один список.

**Взвешивания лежат в своей таблице** `pets.weight_entries` (`WeightEntry.cs`, настройка — `PetConfiguration.cs:63-72`):

```csharp
b.HasOne<User>().WithMany().HasForeignKey(x => x.CreatedBy).OnDelete(DeleteBehavior.SetNull); // PetConfiguration.cs:68 удалённый аккаунт оставляет взвешивания питомцу
b.HasIndex(x => new { x.HouseholdId, x.ClientRequestId }).IsUnique();  // :70 повтор запроса не создаст второе взвешивание
b.Property(x => x.WeightKg).HasPrecision(6, 3);                        // :72 до грамма: котёнок прибавляет граммы в день
```

Когда удаляют питомца или группу, база удаляет и их взвешивания (каскад по `pet_id` и `household_id`). Файлов у взвешиваний нет, поэтому `IPetDeletionHandler` (4.15) модулю не нужен.

**Пять адресов** (`WeightsEndpoints.cs:64`, `:74`):
- `GET` и `POST /pets/{petId}/weights` — журнал питомца и новое взвешивание;
- `GET`, `PUT`, `DELETE /weights/{id}` — одно взвешивание.

Обе группы адресов помечены `.ReportsChanges(LiveTopics.Weight)`: после изменения телефоны группы слышат тему `weight` (4.24). Помощник журнал видит, но менять не может. Своей пометки у адресов нет, а без неё помощникам разрешено только чтение (4.21).

**Журнал собирается из двух источников** в публичном классе модуля питомцев `PetWeights` (`LogAsync`). Им пользуются и адрес журнала, и AI-скан (4.27):

```csharp
public sealed class PetWeights(AppDbContext db, IEnumerable<IPetWeightSource> otherModules, TimeProvider clock)  // WeightsEndpoints.cs:347 DI подаёт все «источники веса»
foreach (var module in otherModules)                            // :357
    weights.AddRange(await module.WeightsAsync(householdId, petId, ct));  // :359 вес из записей осмотра
.OrderByDescending(w => w.MeasuredOn)                           // :363 новые сверху
.ThenByDescending(w => w.CreatedAt)                             // :364 в один день выше то, что добавили позже
```

Это тот же приём, что с удалением питомца (4.15). Модуль питомцев объявляет интерфейс `IPetWeightSource` (`WeightsEndpoints.cs:395`), модуль ухода его реализует (`CareRecordsEndpoints.cs:658`), а `Program.cs:135` их связывает. Про записи осмотра модуль питомцев ничего не знает.

```csharp
.Where(r => ... && r.Kind == CareKind.VetExam && r.WeightKg != null)                  // CareRecordsEndpoints.cs:662 только осмотры с весом
r.Id, petId, WeightSource.CareRecord, r.PerformedOn, r.WeightKg, ..., Note: r.Title,  // :666 id — это id записи, заметка — её название
```

В ответе у каждой строки есть `source`: `Weighing` (взвешивание, его правят здесь) или `CareRecord` (вес из осмотра). По нему приложение решает, что открыть по нажатию: окно взвешивания или саму запись.

**Вес бывает только у осмотра** и хранится до 10 г (`CareRecordsEndpoints.cs:361`, `:437`):

```csharp
record.WeightKg = request.Kind == CareKind.VetExam && request.WeightKg is { } kg ? RoundedWeight(kg) : null;
```

Приложение присылает вес только для осмотра. Если бы сервер сохранил вес у прививки, тот попал бы в журнал, а поправить его было бы негде. Проверка тоже смотрит на округлённое число: иначе 0,004 кг прошло бы проверку и легло бы в базу как 0.

**Проверки взвешивания** (`Validate`, `WeightsEndpoints.cs:292-321`):
- дата не раньше 1990 года и не в будущем. Если дата рождения точная, взвешивание не может быть раньше неё (`:296`). Приблизительная дата («около двух лет») ничего не запрещает: по ней нельзя сказать наверняка (`:268`);
- вес больше 0 и не больше 200 кг (`:303`), уже округлённый до грамма (`Rounded`, `:283`);
- оценка упитанности (BCS) приходит вместе со шкалой или не приходит совсем (`:310-321`). Шкала 9 или 5, оценка от 1 до шкалы;
- заметка до 500 символов. Символ NUL из текста убирается: база не принимает такой текст (`Input.Clean`, `ValidationErrors.cs:57`).

При правке дата рождения проверяет только новую дату (`:196`). Питомцу могли позже указать дату рождения, и тогда старое взвешивание окажется «раньше рождения». Если бы проверка его не пускала, в нём нельзя было бы даже исправить заметку.

**Повтор и одновременные действия** (`Create`, `Update`, `Delete`):
- Повтор безопасен, как у записей ухода (4.12). Приложение присылает `requestId`, одинаковый у всех повторов одного взвешивания. Если взвешивание с таким `requestId` уже есть, сервер отвечает им же, ещё до проверок (`:131`). Тот же `requestId` у другого питомца — ошибка приложения, ответ 400.
- Если два одинаковых запроса пришли одновременно, второй упрётся в уникальный индекс, и сервер вернёт то, что сохранил первый (`:151`).
- Пока взвешивание было в пути, на другом телефоне могли удалить аккаунт, группу или питомца. Тогда база отказывает по внешнему ключу. Сервер переводит отказ в понятный ответ (`:159-174`): аккаунт удалён — 401, группы нет — 403 «вы не в этой группе», питомца нет — 404. Без этого вышла бы ошибка 500, и в Telegram пришло бы ложное оповещение.
- Взвешивание удалили на другом телефоне, пока его правили или удаляли здесь. База не нашла строку, и EF бросает `DbUpdateConcurrencyException`. Правка отвечает 404 (`:211`), удаление — 204: что просили, уже сделано (`:235`).

**AI читает вес** (`Modules/Ai/`, 4.16):
- В ответе модели у записи есть поле `weightKg` (`PassportScan.cs:55`), а в подсказке правило (`:120`): вес, записанный на осмотре, идёт в этот осмотр, любой другой — в список `weights` (он станет взвешиванием, 4.27). Отдельную запись ради одного веса добавлять нельзя.
- Почему нельзя. Первая версия правила просила добавить осмотр, если его нет. Проверка нашла, что такой придуманный «осмотр» засчитывался как «Сделано» плана «ежегодный осмотр»: план сдвигался на год, и осмотр попадал в паспорт. Теперь версия подсказки `scan-5` (`:106`), и тест на настоящей модели проверяет, что за счёт с прививкой и весом осмотр не появляется, а вес становится взвешиванием.
- В черновик вес попадает только у осмотра, округлённым до 10 г, как его хранит запись (`ImportDraft.cs:184`).
- Вес вне 0–200 кг черновик подсвечивает тем же правилом, что и сохранение (`:198`). Если дата не прочиталась, правило проверяет вес отдельно (`:201`).

**Выгрузка данных** (4.25): взвешивания лежат в `household.json`, раздел `weights` (`PetsEndpoints.cs:592`). Вес из осмотров остаётся в самих записях (`careRecords`).

### 4.27. Быстрый ввод текстом на сервере (`Modules/Ai/`)

Задача: человек пишет или надиктовывает «вчера прививка от бешенства, нобивак, весит 4,2», а AI превращает это в черновик записей и веса. Проверка и сохранение такие же, как у AI-скана (4.16), поэтому заметка — это **ещё один вид скана**, только вместо фото у неё текст:

```csharp
Text,                                    // AiImport.cs:21 новый вид импорта: заметка, без фото
public string? Text { get; set; }        // :93 сама заметка; уходит вместе с черновиком, когда его выбрасывают
```

Так заметке достались готовые черновик, экран проверки, связь с планами («Сделано» плана) и сохранение одной транзакцией. Своего кода у неё немного.

**Запуск** (`AiImportsEndpoints.cs`):
- проверка (`:158`): в заметке должна быть хоть одна буква или цифра. Невидимые символы потратили бы запрос впустую;
- заметка идёт своей дорогой (`StartNoteAsync`, `:258`): фото у неё нет, поэтому месячные AI-фото тарифа она не тратит;
- **лимит — 30 заметок в сутки на человека** (`AiOptions.TextEntriesPerDay`, `AiOptions.cs:54`). Ключ AI у сервера общий, без лимита один человек мог бы отправить тысячи заметок. Считается «бронь без фото» в той же таблице, что и AI-фото (`Plans.TryHoldNoteAsync`, `Plans.cs:279`, вид `text-entry`, `:271`). Бронь переживает удаление питомца, поэтому удаление не возвращает заметки. Если AI заметку не прочитал (сбой, выбросили в очереди), бронь снимается, и место возвращается;
- подсчёт и сама заметка — одна транзакция под общим замком подсчёта (`:276`, `:296`). Заметки, отправленные одновременно, считаются по очереди, и 31-я не проскочит;
- тот же `requestId` у повтора возвращает ту же заметку. Если он пришёл для другого питомца или вида — это ошибка приложения, ответ 400 (`SameRequest`, `:323`);
- «Повторить» после сбоя — новая заметка с тем же текстом и с `retryOf`, id неудачной. Новая заметка берёт день, когда написали неудачную (`:283`): «вчера» не съедет, даже если повторили назавтра. Неудачная уступает место и забывает свой текст, кто бы её ни написал (`:350`).

**Чтение** (`AiImportWorker.cs`). Фоновая служба та же, что у скана. Для заметки она собирает другой текст для модели (`NoteAsync`, `:57`):
- в нём имя и вид питомца и **дата того дня, когда заметку написали**, по часовому поясу группы (`:145`). От неё модель считает «вчера» и «в понедельник». Если заметку прочитали после полуночи или повторили назавтра, «вчера» всё равно значит день перед заметкой;
- заметку, которую выбросили, пока её читали, модель не получает (`:139`).

**Подсказка для модели** (`TextEntryPrompt`, `PassportScan.cs:140`): что сделано — в записи, вес — во взвешивания (или в вес осмотра, если взвешивали на нём), номер чипа — в номера. Только то, что уже было: планы и вопросы записями не становятся. Без даты — сегодня. Только про этого питомца. Сама заметка вставлена между `<<<` и `>>>` (`:162`). Даже если в ней написано «забудь правила», это влияет только на черновик самого человека, который он проверяет перед сохранением.

**Вес в черновике** (`ImportDraft.cs:277`). У ответа модели теперь есть список `weights`: вес без осмотра, из заметки или со скана (например, счёт за прививку с весом). В черновике он становится взвешиванием и проверяется так же, как введённое руками (4.26). Галочка снимается, если:
- такой вес уже есть в журнале. Вес осмотра хранится до 10 г, поэтому «835 г» сравнивается с осмотром как 0,84 кг (`:318`);
- он повторяет вес осмотра из этого же черновика (`:323`);
- сохранение его отклонит.

**Сохранение** (`Apply`). Отмеченные веса проверяются правилами взвешивания (`:447`) и сохраняются через публичный `PetWeights` модуля питомцев (`:484`; `WeightsEndpoints.cs:347`). Модуль AI не трогает таблицы питомцев напрямую. Галочка «сохранить фото» у заметки ничего не делает: фото нет (`:494`).

**Выбросить** (`Discard`). Любой путь выбрасывания стирает текст заметки (`:537`, `:551`): в очереди, после чтения, при «Повторить». В выгрузке данных у выброшенной заметки текста уже нет.

## 5. Разбор важных строк: телефон (Dart / Flutter)

### 5.1. Flutter за минуту

- **Всё на экране — виджеты.** Виджет — класс с методом `build`, который *описывает* интерфейс.
- **Описание, а не рисование.** Flutter сам сравнивает новое описание со старым и перерисовывает только изменившееся.
- **Как перечитывать экран:** «`build` — это функция: данные → картинка».

### 5.2. Riverpod за пять минут (как данные попадают на экран)

**Провайдер** — именованный источник данных или службы. Он создаётся лениво, при первом обращении, и кэшируется.

| Вид | Пример | Что хранит |
|---|---|---|
| `Provider` | `apiClientProvider` | Готовый объект (клиент, репозиторий) |
| `NotifierProvider` | `authUserProvider` | Значение, которое меняется (кто вошёл) |
| `FutureProvider` | `petsProvider` | Результат асинхронной операции (загрузка) |

**Три глагола:**
- `ref.watch(x)` — «дай значение и обнови меня, когда оно изменится». В `build` и внутри провайдеров.
- `ref.read(x)` — «дай значение один раз». В обработчиках нажатий.
- `ref.listen(x, …)` — «сообщи, когда изменится». Для побочных действий.

**Подмена (override).** `main.dart` и тесты подменяют провайдеры: например, настоящий API заменяется фейковым. Поэтому тесты не ходят в сеть.

### 5.3. `main.dart` — запуск

```dart
Future<void> main() => runCollarbell();               // :16 обычный запуск

Future<void> runCollarbell({List<Override> overrides = const []}) async {  // :20 запуск с подменами —
                                                      //     сквозные тесты подставляют фальшивую камеру
  WidgetsFlutterBinding.ensureInitialized();          // подготовить Flutter до любых плагинов
  LicenseRegistry.addLicense(_fontLicenses);          // лицензии встроенных шрифтов — на экран «Лицензии»
  final config = AppConfig.fromEnvironment();         // адрес API и режим входа из --dart-define
  if (config.authMode == AuthMode.firebase || android) {  // :32 Firebase нужен для входа, а на Android — и для пушей
    await Firebase.initializeApp(...);
  }
  runApp(ProviderScope(                               // «корень» Riverpod: здесь живут все провайдеры
    overrides: [appConfigProvider.overrideWithValue(config), ..., ...overrides],  // прочитанные значения и подмены
    child: const CollarbellApp(),                     // само приложение (app/app.dart)
  ));
}
```

Настройки сборки (`mobile/lib/app/app_config.dart:24-30`):
- `CB_API_BASE_URL`, по умолчанию `http://localhost:5080`;
- `CB_AUTH_MODE`: в отладочной сборке по умолчанию `dev`, в релизе — `firebase` (строка 55).

**Сборка для своего телефона** — `mobile/tool/install_phone.sh`. Скрипт собирает release-версию с адресом сервера (`CB_API_BASE_URL=https://collarbell.example.com`, 4.20) и входом через Firebase, ставит её по кабелю (`adb install -r`: данные приложения сохраняются) и останавливает Gradle, чтобы тот не держал память. Чтобы попробовать приложение с API на Mac, скрипту передают адрес Mac: `sh mobile/tool/install_phone.sh http://192.168.0.166:5080`, а API запускают в режиме телефона (4.6).

Release-сборки Android по умолчанию не ходят по обычному HTTP, только по HTTPS. Поэтому `android/app/build.gradle.kts` разрешает HTTP только сборке, у которой адрес API начинается с `http://`:

```kotlin
val dartDefines: Map<String, String> = ...            // build.gradle.kts:14 значения --dart-define этой сборки
manifestPlaceholders["usesCleartextTraffic"] =        // :51 HTTP разрешён, только если адрес API — http://
    (dartDefines["CB_API_BASE_URL"]?.startsWith("http://") ?: false).toString()
```

Отладочным сборкам HTTP разрешён всегда (строка 58): им нужен локальный API. Сборка с адресом сервера (`https://…`, 4.20) ходит только по HTTPS.

**Иконка** нарисована в `mobile/tool/icon/`: ошейник с колокольчиком в цветах дизайн-системы. `make_icons.sh` делает из рисунков все размеры для Android и iPhone. Тот же колокольчик — в строке уведомлений (`res/drawable/ic_notification.xml`).

### 5.4. `app/router.dart` — экраны и «не пускать без входа»

```dart
String? authRedirect({required bool signedIn, required String location}) {   // :190
  final onSignIn = location == AppRoutes.signIn;
  if (!signedIn) return onSignIn ? null : AppRoutes.signIn;   // не вошёл → на экран входа
  if (onSignIn) return AppRoutes.home;                        // вошёл, но на экране входа → на «Главную»
  return null;                                                // иначе никуда не перенаправлять
}
```

- **Перепроверка при входе и выходе.** `refreshListenable: signedIn` (строка 231): при каждом входе или выходе роутер заново прогоняет это правило.
- **Вкладки.** `StatefulShellRoute.indexedStack` (строка 251) — пять вкладок: «Главная», «Сегодня», «Питомцы», «Запасы», «Ещё»; у каждой своя история переходов. Приложение открывается на «Главной» (`initialLocation`, строка 230); туда же ведут `/` и неизвестные ссылки. Номера вкладок, которые нужны коду, — `AppRoutes.todayBranch` и `suppliesBranch` (строки 56-58), а переключить вкладку «как нажатием на панель» помогает `openTab` (строка 216). Какая вкладка сейчас на экране, говорит `shownTab` (строка 201): по ней пуш решает, открыт ли «Сегодня» (5.16). Нижняя панель описана в `app/home_shell.dart`. Там же полоска «Нет связи с сервером» над панелью и вопрос «Уйти без сохранения?» при повторном нажатии на текущую вкладку (5.18).
- **Экраны внутри вкладки «Pets»** вложены друг в друга, как папки (строки 310-468):

```text
/pets                                   список
/pets/new                               новый питомец
/pets/{petId}?tab=health                карточка: вкладки Overview / Health / Passport / Documents / Feeding / Weight
/pets/{petId}/edit                      изменить питомца
/pets/{petId}/passport/edit             изменить шапку паспорта
/pets/{petId}/documents/new             новый документ; …/documents/{documentId}(/edit)
/pets/{petId}/plans/presets             выбрать пресет → plans/new — новый план
/pets/{petId}/plans/{planId}/edit       изменить план; …/plans/{planId}/done — «Сделано»
/pets/{petId}/records/new               запись вручную; …/records/{recordId}(/edit)
/pets/{petId}/scan                      новый AI-скан; …/scans/{scanId} — начатый раньше (5.15)
/today/plans/{planId}/done              «Сделано» с экрана «Сегодня» (строки 268-272)
/welcome                                знакомство поверх вкладок; /welcome/pet и /welcome/join — форма питомца и вход по коду поверх него (5.27)
/more/ai                                «Ещё → Распознавание фото» (5.15)
/more/household                         «Ещё → Участники и приглашения»; /more/join — вступить по коду (5.19)
```

  Адреса собираются функциями `AppRoutes.pet(id, tab: ...)`, `AppRoutes.editPet(id)` и т. д. (строки 75-110), чтобы не склеивать строки руками.

### 5.5. Вход: `features/auth/`

- **`auth_repository.dart` — контракт** (`abstract interface class`): что должен уметь любой «вход». `signIn`, `signUp`, `signOut`, `sendPasswordReset` («Забыли пароль?», 5.18) и главное — `authHeaders()`, то есть «какие заголовки поставить в запрос к API».
- **Две реализации:**
  - `firebase_auth_repository.dart` ставит `Authorization: Bearer <токен>`;
  - `dev_auth_repository.dart` ставит `X-Dev-User` и `X-Dev-Email`. Идентификатор вычисляется из email, поэтому один и тот же email на любом устройстве — один и тот же пользователь.
- **`auth_providers.dart` выбирает реализацию** по режиму сборки (строки 12-23). `authUserProvider` хранит «кто сейчас вошёл» (строки 27-41), и на него подписан роутер.

Зачем интерфейс: экранам всё равно, какой вход используется. Так и вышло: при подключении Firebase ни один экран не изменился, добавились только файлы настроек (`lib/firebase_options.dart` и два нативных файла).

### 5.6. API: сгенерированный клиент и `data/api/api_client.dart`

**Откуда берутся методы `api.pets.listPets()`, `api.files.uploadFile(...)`.** Их пишет программа, а не человек:

```text
сервер (C#) ──сборка──▶ contracts/openapi.json ──tool/generate_api.sh──▶ mobile/lib/data/api/generated/
                        описание всех адресов,     swagger_parser + build_runner     модели (PetResponse…) и
                        полей и типов                                                 клиенты (PetsClient…)
```

- **Сервер поменялся — перегенерируйте:** `sh mobile/tool/generate_api.sh`. Новые поля и адреса появятся в Dart сами, а опечатку в имени поля поймает компилятор, а не пользователь.
- **CI проверяет**, что сгенерированный код совпадает с контрактом: забыть перегенерировать нельзя.
- **Руками в `generated/` ничего не правят** — следующая генерация затрёт.

**Обёртка** (`api_client.dart`):

```dart
late final api = CollarbellApi(dio);                       // :127 все сгенерированные клиенты: api.pets, api.files…

Future<T> send<T>(request, {CancelToken? cancelToken}) async {  // :139 каждый запрос идёт через send:
  try { return await request(api); }
  on DioException catch (error) { throw ApiException.fromDioException(error); }  // :154 ошибка сети или ответ 4xx/5xx
  ...                                                       //     → одна понятная ошибка ApiException
}
```

- **`CancelTokenInterceptor`** (строка 220) — первый в цепочке. Сгенерированные методы не принимают `CancelToken`, поэтому `send` передаёт его через зону, в которой идёт запрос, а этот перехватчик отдаёт его запросу. Так «Отмена» обрывает чтение номера чипа (5.7), а сервер прекращает работу над ним.
- **`AccountDeletedInterceptor`** (в цепочке — строка 75, класс в `account_deleted.dart`) — запоминает, чей это запрос, ещё до заголовков входа, и замечает ответ «аккаунт удалён» (401 `account-deleted`): тогда телефон выходит из аккаунта (5.23).
- **`AuthHeadersInterceptor`** (строка 231) — перед *каждым* запросом добавляет заголовки входа.
- **`HouseholdHeaderInterceptor`** (класс в `household_header.dart`, в цепочке — `api_client.dart:79`) — сразу за ним называет группу на экране (`X-Household`) и замечает ответ «вас нет в этой группе». Подробно — 5.19.
- **`UploadTimeoutInterceptor`** (строка 265) — загрузке файла даёт 3 минуты вместо 20 секунд: 15 МБ по мобильной сети — это долго.
- **`AiTestTimeoutInterceptor`** (строка 279) — то же для проверки подключения AI (`/ai/test`), чтения фото упаковки (`/products/scan`) и номера чипа с фото (`/pets/identifiers/scan`): сервер спрашивает модели по очереди, и ответ может идти дольше минуты.
- **`OfflineCacheInterceptor`** (строка 90) — последний в цепочке. Хранит копии ответов на `GET` и отдаёт копию, когда сервер не отвечает. Изменение без связи он не отправляет, а сначала проверяет сервер (`checkServer`, строка 105, `GET /health`). Подробно — 5.18.
- **Даты.** В контракте дата без времени (`format: date`), а Dart знает только `DateTime`. `date_only_converter.dart` отправляет такие поля как `2021-04-03`, без времени.

### 5.7. Питомцы: `features/pets/`

- **`pets_repository.dart`** — «достать и сохранить питомцев»:
  - строки 35-62 — контракт (`abstract interface class PetsRepository`): список, один питомец, создать, изменить, удалить, фото, номер чипа с фото (`scanIdentifiers`);
  - строки 65-152 — реализация через сгенерированный клиент; почти каждый метод — одна строка `_client.send(...)`. `scanIdentifiers` (строка 115) ещё превращает ответы 409, 503 и 502 в `IdentifierScanFailed` с причиной, как скан упаковки в запасах (5.17), и принимает `CancelToken` для «Отмены»;
  - строка 162 — `petFromDto`: ответ API → модель приложения `Pet`;
  - строки 292-306 — провайдеры `petsProvider` (список) и `petProvider` (один питомец по id).
- **Экраны:**
  - `pets_screen.dart` — список (раздел 2);
  - `pet_detail_screen.dart` — карточка с шестью вкладками (строки 108-147): обзор, «Здоровье» (`HealthTab`, 5.13), паспорт, документы, кормление (5.16), вес (5.24). Вкладки не перезагружаются при переключении (`KeepTabAlive`, строка 135), а страница открывается сразу с данными из списка (строки 44-49; 5.18);
  - `pet_form_screen.dart` — форма создания и изменения (5.10);
  - `widgets/identifier_editor.dart` и `identifier_rules.dart` — чипы и татуировки с теми же правилами, что на сервере (4.10). Телефон проверяет сразу, сервер — ещё раз. Номер чипа можно отсканировать (ниже).

```dart
final pets = ref.watch(petsProvider);                   // pets_screen.dart:25 состояние загрузки

if (pets.isLoading && !pets.hasValue) { ... }          // :30 загрузка (скелетон, 5.18)
else if (pets.hasError && !pets.hasValue) { ...        // :35 ошибка
    onRetry: () => ref.invalidate(petsProvider),        // :43 «Try again» = забыть значение провайдера и загрузить заново (копии ответов остаются)
} else {
  list.isEmpty ? CbEmptyState(...) : _PetList(...)     // :49 пусто или список
}
```

- **Перерисовка.** `ref.invalidate(petsProvider)` — «данные устарели». Экран сам перезагрузит их, потому что подписан через `watch`.
- **Pull-to-refresh** (строки 84-86) делает то же самое. Так же список перечитывается, когда приложение возвращается на экран (`ReloadOnResume`, строки 71-73).

**Скан номера чипа.** В карточке чипа у поля номера есть кнопка «Сканировать номер» (`widgets/identifier_editor.dart:169`). Она открывает камеру поверх всего приложения. Телефон не может прочитать сам чип под кожей: чипы питомцев работают на 134,2 кГц, а NFC телефона — на 13,56 МГц. Поэтому читается номер с наклейки в паспорте: под штрихкодом напечатаны те же 15 цифр.

```text
ТЕЛЕФОН                                                         СЕРВЕР
форма питомца → у чипа «Сканировать номер»
   │ камера видит штрихкод наклейки → номер в поле, сразу
   │ «С фото» (камера или галерея) → телефон сам ищет штрихкод на фото
   │    нашёл → номер в поле
   │    не нашёл → фото → POST /files → POST /pets/identifiers/scan ──▶ AI читает номера (4.10)
   │               «Читаем фото…», можно отменить ◀──────────────────── номера, место, дата, ошибка
   │               один номер → в поле; несколько → выбрать; ни одного → «введите вручную»
   ▼
карточка: тип и номер; место и дата — только в пустые поля; «Save» проверяет, как обычно
```

- **`chip_reader.dart`** — `ChipReader` (строка 51): «прочитай номер чипа», в тестах его подменяет `FakeChipReader`. Ответ — `ChipBarcode` (номер со штрихкода) или `ChipPhoto` (фото без штрихкода, его прочитает AI). `CameraChipReader` (строка 65) настраивает общую камеру: только коды, которые бывают на наклейках (Code 128, Code 39, ITF, DataMatrix, QR и др., строка 74), без товарных EAN и UPC. Если в кадре два разных номера, человек выбирает (`_pick`, строка 115).
- **«С фото»** (`_fromPhoto` в `chip_reader.dart`, строка 137). Камера сканера отдыхает (`session.pause`), человек выбирает камеру или галерею, и телефон ищет штрихкод на фото сам (`session.readPhoto`, строка 163: `analyzeImage` пакета `mobile_scanner`). Нашёл — фото удаляется (это страница паспорта), номер уходит в форму. Не нашёл — фото уходит в форму для AI (строка 167). Если человек ушёл со сканера, пока телефон смотрел фото, оно тоже удаляется. Под кнопкой — предупреждение, если AI работает на бесплатном Gemini (строка 184).
- **`identifier_rules.dart`** — `chipFromBarcode` (строка 80): какой номер в штрихкоде. 15 цифр подряд где угодно — чип ISO, поэтому подходят и `ISO 643094100000001`, и `643 094 100 000 001`. Иначе весь код целиком должен быть старым чипом: 10 символов 0–9 и A–F или 9 цифр. Всё остальное (штрихкод корма, ссылка на сайт) — не номер чипа: сканер на 3 секунды пишет «Это не номер чипа» и ищет дальше.
- **`shared/widgets/barcode_scanner_page.dart`** — общая камера для запасов и чипов (`BarcodeScannerPage`, строка 49). Кто её открывает, тот и задаёт, какие коды искать, заголовок, подсказку, что сделать с прочитанным кодом (`decode`), как выбрать из нескольких (`choose`, строка 82; у запасов его нет, берётся первый код) и кнопки под подсказкой. Кнопкам доступен `ScannerSession` (строка 12): остановить камеру, запустить снова, закрыть сканер с результатом, найти коды на фото, выбрать один.
- **Закрывать — только свой экран.** `Navigator.pop` закрывает верхний экран. Пока сканер или окно «Читаем фото…» уходят с экрана (человек нажал «Назад» или «Отмена»), верхний уже не он, а экран под ним, а под формой питомца — вся оболочка с вкладками. Поэтому код закрывает свой экран, только пока тот наверху (`_current`, `barcode_scanner_page.dart:119`; `_close`, `identifier_editor.dart:244`), а любой уход со сканера сразу останавливает чтение кодов (`PopScope`, `barcode_scanner_page.dart:226`).
- **Форма** (`pet_form_screen.dart`):
  - `_scanChip` (строка 302) — номер со штрихкода сразу в поле. Пока идёт скан, второе нажатие ничего не открывает (`_scanning`, строка 303);
  - `_readChipPhoto` (строка 329) — фото загружается, с телефона удаляется (строка 356) и уходит на чтение. Пока AI читает, видно окно «Читаем фото…» с кнопкой «Отмена» (`ChipReadingDialog`, `widgets/identifier_editor.dart:223`). «Отмена» во время загрузки — фото не уходит в AI (строка 358); во время чтения — запрос обрывается (`cancel.cancel()`, строка 376). Если известно, что AI на сервере нет, фото никуда не уходит (строка 335);
  - `_useReadings` (строка 397) — один номер сразу в поле, из нескольких человек выбирает (`pickIdentifierReading`, `identifier_editor.dart:276`; номер с ошибкой помечен красным), ни одного — подсказка на карточке;
  - `_fillIdentifier` (строка 431) — тип и номер. Место и дату — в пустые поля, а если скан заменил другой номер, то и поверх старых: они были того номера (строки 440-448). Набранное руками для этого номера не пропадёт.
- **Подсказки скана — на самой карточке**, под номером (`scanNote`, `identifier_editor.dart:49`): «Прочитано с фото: сверьте с паспортом», «На фото не нашлось номера чипа — введите его вручную», «AI сейчас занят…». Не во всплывающей полоске снизу: та легла бы поверх кнопки «Save». Подсказка исчезает, как только человек правит номер (строка 177).

### 5.8. Тема: `theme/`

- **`tokens.g.dart` — сгенерированный файл, руками не править.** Его создаёт `python3 tools/gen_flutter_tokens.py` из `design/tokens.json`.
- **`collarbell_theme.dart`** собирает из токенов тему Material: цвета, кнопки-«таблетки», поля ввода, нижнюю панель.
- **Свайп «назад» на Android закрывает только то, что сверху** (`pageTransitions`, `collarbell_theme.dart:74`). Предпросмотр жеста (экран уменьшается под пальцем) выключен. Он отдавал свайп верхнему экрану *каждого* навигатора, а у вкладки свой навигатор под общим. Когда поверх экрана вкладки были открыты сканер, диалог или выбор даты, свайп закрывал и спрятанный под ними экран. Следующее «Закрыть» оставляло приложение без экранов: чёрный экран (2026-10-14: «Запасы → Добавить → Сканировать → свайп → крестик»). Теперь свайп — обычное «Назад»: go_router отдаёт его самому верхнему. Переходы между экранами прежние. Тест — `test/app/back_gesture_test.dart`: сканер, диалог и первый экран вкладки.
- **Доступ в коде:**
  - цвета — `context.cb.inkMuted`, `context.cb.primaryText`;
  - стили текста — `context.cbText.body` (пример в `pet_form_screen.dart:765`);
  - отступы — `CbSpace.s4`, размеры — `CbSize.avatarMd`.

Правило: в экранах не бывает «просто чисел» и «просто цветов», только токены.

**Палитра дизайнера (октябрь 2026).** Экраны белые, интерфейс сине-серый (`line`, `line-strong`, `ink-muted`), жёлтый `accent` (#FFDC5F) — только заливка, красный `danger` — только «просрочено», ошибки и удаление. Ярко-зелёный `success` — только мелкая графика «готово» (галочка в списке, полная полоска запаса), не текст.

**Зелёный — двух оттенков (вторая правка дизайнера, 2026-10-14: прежний #066849 выглядел «болотным»).** Правило простое: если это **заливка**, на которой лежит текст, — `primary`, яркий #00B53F; если это **текст, маленький значок или тонкая линия** на белом или мятном — `primary-text`, тот же зелёный темнее, #007F2B (яркий на белом читается плохо, 2,7:1, тёмный — 5,2:1). Заливки: залитые кнопки (и `FilledButton.tonal` — у нас он такой же), кнопка «+ Добавить» (FAB), выбранный день в календаре, переключатель, кружок выбора, полоски прогресса, линия и точки графика веса (это графика, как на вебе). Текст и линии: текстовые кнопки («Покормить всех», «Все», «Добавить фото»), выбранная вкладка и линия под ней, выбранный пункт нижней панели (слово и значок; подложка — мятная `primary-soft`), слова и значок выбранного чипа и сегмента, рамка поля в фокусе, курсор, галочка в кружке «Готово», значки визитов и запасов, сегодняшний день в календаре, выбранная строка списка (`listTileTheme.selectedColor`). Всё это задано в теме (`collarbell_theme.dart`), в экранах — `context.cb.primaryText`. **Слова на залитой кнопке и на FAB — белые и жирные (700)**: решение владельца, жирное начертание смягчает слабый контраст белого на ярком зелёном; у остальных кнопок вес прежний, 500. У чипов со значком (вид визита, вид товара) выбранный отмечен заливкой и зелёными словами без галочки (`showCheckmark: false`): Flutter рисовал её поверх значка на тёмном кружке. Значок приложения остался тёмно-зелёным #066849.

**Значки — Material Symbols Rounded** (пакет `material_symbols_icons`, версия закреплена в `pubspec.yaml`), те же, что рисует веб. Пишутся как `Symbols.home_rounded`; `collarbell_theme.dart` их экспортирует, поэтому экрану, который импортирует тему, отдельный импорт не нужен. Толщину задаёт тема один раз (`CbIcons`, `collarbell_theme.dart:24`): вес 400 при оптическом размере 48. На значке 20–24 px это чуть тоньше прежних значков Material, как и просил дизайнер, и так же, как на вебе (вес 300 оказался слишком тонким). Залитый значок — тот же значок с `fill: 1` (выбранная вкладка нижней панели, кружок «Готово» в кормлении, «Премиум» на тарифе). Свои темы значков у нижней панели, шапки и чипов строятся из той же темы, поэтому толщина везде одна. Стрелка «Назад» в шапке и «⋮» меню — тоже из Material Symbols (`actionIconTheme` в теме и `icon:` у `PopupMenuButton`). Остались значками Flutter только внутренние значки его окон выбора даты и времени (стрелки месяцев, карандаш). В релизной сборке остаются только используемые значки: значки в коде — `const`.

**Шрифты (`theme/cb_fonts.dart`).** На iPhone и Mac — системный Helvetica Neue, на Android — Arimo (бесплатный двойник Arial: те же формы и ширины), номера чипов и коды — JetBrains Mono. Какой выбрать, решает `fontFamilyFor` (строка 37) по платформе (`defaultTargetPlatform`). Arimo и JetBrains Mono лежат в `assets/google_fonts/` и объявлены в `pubspec.yaml` в разделе `fonts:` с весами 400, 500 и 700. Других весов нет, поэтому `FontWeight.w600` в коде не бывает. Лицензии шрифтов (OFL) видны на экране «Лицензии» (`main.dart`, `_fontLicenses`). Пакет `google_fonts` больше не нужен и убран.

**Иерархия текста — размером и цветом.** Заголовки — жирные (700) в `ink`; имя в строке (`subtitle`, 17) — обычное (400) в `ink`; вторая строка и подписи — `ink-muted`. Приглушённый текст не делают жирным, чтобы «выделить».

**Кнопки и поля.** Все кнопки — залитые, контурные, текстовые, в строках и внизу экрана, и кнопка «+ Добавить» (FAB) — высотой 44 (`CbSize.controlMd`); отдельного «большого» размера больше нет. Контур кнопок, полей, чипов и сегментов — 1,5 px (`CbSize.borderWidth`) цвета `line-strong`; поле в фокусе — 2 px `primary-text`. Чипы — 36 (`controlSm`); выбранный чип залит `primary-soft`, слова и значок на нём — `primary-text`, контур той же толщины. Сегменты («Кошка / Собака / Другое») Flutter сам делает высотой 40 и `minimumSize` не слушает, поэтому тема добавляет им шаг плотности (`VisualDensity(vertical: 1)`, +4 px) — выходит 44. Кнопки рядом — через 8 (`SizedBox(width: CbSpace.s2)`), друг под другом — через 12 на глаз: в коде это тоже `SizedBox(height: CbSpace.s2)`, потому что у каждой кнопки высотой 44 есть ещё по 2 px сверху и снизу — зона касания 48 (пример с комментарием — `cb_save_bar.dart`). Размеры «как видно» проверяет тест `test/theme/tokens_test.dart` («as drawn»).

**Ровные края и отступы.** Глаз замечает, когда что-то «выпирает» или «въезжает» на пару пикселей, поэтому:
- **поля ввода — тоже 44**: строка текста 24 и по 10 сверху и снизу (`contentPadding` в теме), слова — в 16 от левого края. Без `isDense: true` Flutter держит поле не ниже 48, поэтому оно включено;
- **значок в конце поля** (календарь, часы, «глаз» пароля) — в 16 от правого края, как слова от левого: тема ставит его в коробку шириной 56 (`suffixIconConstraints`). У выпадающих списков стрелка — `expand_more` (`cbDropdownIcon` в `shared/widgets/cb_text_field.dart`): Flutter ставит её в 12 от края, ещё 4 добавляет отступ;
- **текстовая кнопка в строку с текстом** — без боковых отступов (`cbInlineTextButtonStyle` в `collarbell_theme.dart`): «Изменить» под датой, «Открыть магазин» под заметками начинаются ровно там же, где текст над ними. Текстом теперь остаются только такие правки и ссылки, выходы («Пропустить», «Закрыть») и ответы в диалогах (правило кнопок — 5.27).
- **действие в заголовке раздела** (`CbSection`) — компактная контурная кнопка с иконкой и словом (`cbCompactOutlinedButtonStyle`: тоже 44, но с отступами 12 по бокам): рядом с заголовком её контур кончается у правого края карточек, а если она ушла под заголовок — начинается у его левого края. Где места нет даже для неё («+» рядом с длинными заголовками V–X паспорта, «+» у «Визитов»), — круглая контурная кнопка с подсказкой (`cbOutlinedIconButtonStyle`), а длинный заголовок переносится рядом с ней (`titleWraps`). Так же устроены «Все запасы» и «Покормить всех».
- **строки с кнопкой справа** («Покормили», «Купили», галочка «Готово») — по 16 слева и справа, как у обычных строк списка (раньше справа было 8, и кнопки почти касались края карточки);
- **переключатели-кружки** (язык и тема в «Ещё», роль в группе) стоят по центру там же, где значки в соседних строках, а слова начинаются там же, где у них (`CbRadioTile`);
- **сегменты** без тени, выбранный — плоская заливка `primary-soft`; лишней зоны касания над и под ними нет (`tapTargetSize: shrinkWrap`), поэтому подпись над сегментами стоит так же близко, как над полем.

**Статус — тегом, а не цветным текстом (`shared/widgets/cb_status_tag.dart`).** Жёлтый текст на белом не читается, поэтому «скоро», «пора купить», «проверьте» — это `CbStatusTag.soon`: жёлтая «таблетка» с тёмным текстом и значком. «Просрочено» и «закончился» — `CbStatusTag.overdue`, красная с белым текстом. Спокойные состояния — просто текст `ink-muted`. Где теги:
- срок дела (`care/widgets/due_line.dart`): тег «Через 2 дня» / «Просрочено на 3 дня», за ним дата;
- запасы (`supplies/widgets/supply_status_line.dart`): «Пора купить» и сколько хватит, «Закончился»; на экране товара так же, а кормление, которое не учитывается, — жёлтый тег;
- «Отметьте, как прошёл» у прошедшего визита на «Сегодня» (`today_visits.dart`), «Готов к проверке» у скана, сомнения AI в карточках записей (`draft_cards.dart`), «Не ISO: в поездку берите свой сканер» у старого чипа на вкладке «Паспорт».

**Уведомления (`shared/widgets/cb_notice.dart`).** Подсказка — на светло-голубом `sunken`; предупреждение (`CbNotice.warning`) — кремовый фон `accent-soft` с жёлтой рамкой 1,5 px, значок и текст тёмные; ошибка — `danger-soft` с красным значком.

**Аватар питомца (`pets/widgets/pet_avatar.dart`).** Фото в круге, а без фото — первая буква имени жирным, цвета `on-avatar` на круге `avatar`, одинаково у всех питомцев. Своих цветов у питомцев больше нет: выбор «Цвет питомца в приложении» убран из формы, строка — из карточки. В API поле `coat` осталось (его не трогали); приложение его не читает и при сохранении отправляет `null`: сервер оставляет прежний цвет, а новому питомцу подбирает сам (`pets_repository.dart`, `petRequestFromInput`).

### 5.9. Тексты: `l10n/`

- **Где лежат.** Все надписи — в `app_en.arb` (английский) и `app_ru.arb` (русский), ключ → текст.
- **Как читаются в коде.** `context.l10n.petsEmptyTitle`.
- **Как найти, где выводится надпись:** найдите текст в `.arb` → возьмите ключ → поиск по ключу в `lib/`.

### 5.10. Формы: проверка и сохранение (`pet_form_screen.dart`)

Форма — самое «хрупкое» место приложения: пользователь может уйти посреди сохранения, связь может пропасть на полпути. Ревью M1 нашло здесь несколько ошибок, и код устроен так, чтобы их не было.

**1. Проверяются все поля, даже те, что за экраном.** Форма — это `SingleChildScrollView` + `Column`: все поля построены сразу. Перед сохранением:

```dart
final invalid = invalidFields(_formKey.currentState!);   // :492 все поля с ошибками
if (invalid.isNotEmpty) {
  revealTopmost(invalid);                                // :494 прокрутить к самому верхнему
  setState(() => _failure = l10n.formCheckFields);       //      и показать «Проверьте выделенные поля»
  return;
}
```

(`shared/widgets/form_errors.dart`). Ошибки сервера (400 с `errors: { "identifiers[0].code": [...] }`) показываются под своими полями так же.

**2. Всё нужное берётся до первого `await`:**

```dart
final navigator = Navigator.of(context);                            // pet_form_screen.dart:503
final container = ProviderScope.containerOf(context, listen: false); // :504 «контейнер» провайдеров
```

Зачем: пока идёт сохранение, экран может закрыться. После этого `ref` и `context` экрана использовать нельзя: Riverpod бросит ошибку, и обновление списка не случится. Контейнер живёт столько же, сколько приложение, поэтому `container.invalidate(petsProvider)` (строка 906, в `refreshPet`; её же вызывает знакомство, 5.27) сработает всегда.

**3. Уйти во время сохранения нельзя, а с изменениями — только после вопроса.** Форма обёрнута в `LeaveGuard` (строка 574, `shared/widgets/leave_guard.dart`). Пока идёт сохранение (`busy: _busy`), «Назад» ничего не делает. Если в форме что-то изменили, «Назад» спрашивает «Уйти без сохранения?». Как форма замечает изменения и почему форма, открытая без связи, не сохраняет, — в 5.18.

**4. Порядок шагов** (строки 511-534):
1. загрузить фото, если выбрано новое. Если сервер его не примет, ничего ещё не сохранено, можно выбрать другое;
2. создать или изменить питомца;
3. прикрепить фото.

Загруженное фото запоминается (`_uploadedPhoto`). Если не удался шаг 2 и пользователь жмёт «Save» снова, фото не грузится второй раз. Если не удался шаг 3, питомец уже сохранён: форма закрывается и пишет, что фото загрузить не удалось (строки 537-546). Так второе «Save» не создаст второго питомца.

**5. У каждого поля свой ключ** (`ValueKey('name')`, `ValueKey('markings')`…, строки 606-806). Без ключей Flutter сопоставляет поля по порядку. Тогда после переключателя «Стерилизация», который добавляет строку с датой, текст начинал попадать в соседнее поле.

### 5.11. Файлы и картинки (`features/files/`)

- **`media_picker.dart`** — интерфейс «дай фото, несколько фото, PDF». Настоящая реализация зовёт камеру и галерею, в тестах её подменяет фальшивая (`FakeMediaPicker`), поэтому тесты проходят без камеры.
- **`files_repository.dart`** — загрузка (`upload`) и свежая ссылка (`getLink`).
- **`widgets/stored_file_image.dart`** — картинка по подписанной ссылке, в кэше по id файла (`cacheKey`). Ссылки меняются при каждом ответе сервера, а id файла — никогда.
- **`page_viewer_screen.dart`** — просмотр страниц на весь экран: листание, увеличение пальцами, «Удалить страницу».
- **`open_pdf.dart`** — PDF открывается во внешнем просмотрщике по свежей ссылке.

### 5.12. Паспорт и документы (`features/passport/`, `features/documents/`)

- **`passport_tab.dart`** — вкладка «Паспорт»:
  - пояснение, что копия не заменяет бумажный паспорт;
  - карточка шапки паспорта (изменяется в `passport_form_screen.dart`);
  - чипы питомца;
  - сетка листов.
- **`passport_pages.dart`** — листы паспорта — это страницы документов типа «листы паспорта». Добавление (строки 37-58) всегда **спрашивает у сервера свежий список** и **только добавляет**; удаление удаляет одну страницу. Почему так важно, рассказано в 4.9. Если загрузка или добавление не удались, вкладка помнит листы и показывает «Загрузить ещё раз» (`_uploadAgain`, `passport_tab.dart:312`): выбирать фото снова не нужно. Листы, которые уже есть в документе, добавление пропускает (строки 43-48), поэтому повтор после потерянного ответа ничего не добавит дважды.
- **`documents/document_form_screen.dart`** — форма документа. Сохранение изменённого документа идёт тремя шагами:
  1. описание (`updateDetails`);
  2. новые страницы (`addPages`);
  3. удалённые страницы (`removePage`).

  Сначала добавление, потом удаление. Если заменить все страницы, удаление «последней» страницы не удалит документ целиком.

### 5.13. Уход на телефоне (`features/care/`)

- **`care_repository.dart`** — всё про уход через API: планы, «Сделано», записи, фото записей, пресеты. Провайдеры внизу файла: `carePlansProvider(petId)`, `careRecordsProvider(petId)`, `passportRecordsProvider(petId)` и другие (строки 549-601).
- **`care_rules.dart`** — правила, которые нужны до ответа сервера:
  - следующая дата (`addInterval`, `nextDueAfterDone`);
  - какие поля у какого вида ухода: время — только у эхинококка, «действует с/до» — у прививок;
  - какие вакцины предлагать кошке, а какие собаке.

  Правила обязаны совпадать с серверными, и тесты в `test/features/care/` это проверяют.
- **`health_tab.dart`** — вкладка «Здоровье»: планы, разложенные по статусам (`groupPlans`, строка 186), и история. Выполненные и приостановленные планы свёрнуты внизу.
- **`preset_picker_screen.dart` → `plan_form_screen.dart`** — выбор пресета по виду питомца и форма плана. Поле «Последний раз» сразу считает следующую дату.
- **`done_screen.dart`** — «Сделано» (история 2.3). Пока экран сохраняет, все поля выключены (`IgnorePointer`, строка 414). Так нельзя открыть список или календарь посреди сохранения.
- **`record_form_screen.dart`** — запись вручную, например из бумажного паспорта. Фото меняются по одному: **сначала удаляются, потом добавляются**. Тогда в полной записи (10 фото) можно заменить одно.
- **`care_refresh.dart`** — одна функция `refreshCare`: после любого изменения ухода обновить всё, что его показывает (история 2.3, шаг 6).

### 5.14. Вкладка «Сегодня» (`features/today/`)

С 2026-10-14 «Сегодня» — уже не главный экран, а вторая вкладка: полный список дня. Приложение открывается на «Главной» (5.27), которая показывает самое срочное из тех же данных.

- **`today_repository.dart`** — `GET /today` и провайдер `todayProvider`. Его смотрят два экрана: «Сегодня» и «Главная».
- **`today_screen.dart`** — три группы: «Просрочено», «Скоро», «Позже».
  - Нажатие на пункт **кладёт страницу питомца поверх «Сегодня»** (`context.push`, строка 208) и сразу открывает вкладку «Здоровье». «Назад» вернёт на «Сегодня».
  - Раньше переход заменял всю историю вкладки «Питомцы» (`context.go`) и мог выбросить открытую там форму с несохранённым текстом. Это нашло ревью M2.
  - Кнопка ✓ открывает «Сделано» прямо отсюда (строка 251).
- С M4 сверху кормления этого дня (`features/feeding/widgets/today_feeding.dart`), под ними визиты (`features/visits/widgets/today_visits.dart`: контурные «Все визиты» и круглый «+»), потом «Купить» (`features/supplies/widgets/today_shopping.dart`, 5.17), дальше уход. Подробнее — 5.16. Если уведомления запрещены, выше всего — предупреждение с контурной кнопкой «Открыть настройки». Пустой «Сегодня» подсказывает первые шаги карточками (`TodayFirstSteps`, `first_steps.dart`, 5.27), а пока экран перечитывается, список не отвечает на нажатия (5.18).
- Экран перечитывает данные, когда приложение возвращается на экран, после полуночи (`TodayReload`, `today_reload.dart`) и когда приходит или нажат пуш: за это время другой телефон мог отметить кормление.

### 5.15. AI-скан на телефоне (`features/ai/`)

Скан — это «сфотографировал страницы паспорта → AI прочитал → я проверил → сохранил». **AI ничего не сохраняет сам:** он готовит черновик, а сохраняет человек. Если на сервере AI не настроен, кнопок скана нет совсем, а вносить записи вручную можно всегда.

```text
ТЕЛЕФОН                                                   СЕРВЕР
«Паспорт» → «Сканировать» (или значок на «Здоровье»)
   │ ScanScreen: сканер документов или фото из галереи, до 10 страниц
   │   страницы сканера уменьшаются до 2048 px (JPEG 85 %)
   │   1. страницы → POST /files, по одной (повтор не грузит заново)
   │   2. POST /ai-imports { petId, source, fileIds, requestId } ─▶ скан в очереди
   │      копии страниц на телефоне удаляются
   │   3. раз в 2 секунды GET /ai-imports/{id} ◀─────────────────── «читаем» … «готов» + черновик
   │      (пока приложение свёрнуто — не спрашиваем; вернулись — спросим сразу)
   │ ScanReviewScreen: свежие планы и паспорт, галочки, правки, «Сохранить выбранное»
   │   4. POST /ai-imports/{id}/apply ─────────────────────────────▶ записи, план сдвинут, фото в паспорт
   │      ответ потерялся? → GET /ai-imports/{id}: сохранено или нет
   │   5. refreshAfterScan: «Здоровье», «Сегодня», паспорт, документы перезагрузятся
   ▼
«Паспорт»: «Сохранена 1 запись · обновлён 1 план · фото добавлены к страницам паспорта»
```

- **`ai.dart`** — модели: `AiStatus` (подключён ли AI, модели, бесплатный тариф, расход за месяц), `AiScan` (скан: статус, фото, черновик, ошибка; `canReadAgain` — можно ли прочитать те же фото ещё раз), `DraftRecord`, `DraftIdentifier`, `DraftPassport` (что прочитал AI) и `DraftWarning` — сомнение AI в значении: «не прочитано», «день и месяц могли перепутаться», «уже сохранено». Название записи AI больше не выдумывает: если на странице его нет, `title` пустой, и экран проверки подставляет название на языке пользователя (`scanDefaultTitle`, `ai_labels.dart:187`): «Вакцинация против бешенства» для прививки от бешенства, иначе название вида — «Обработка от глистов». Такое название не хранится, а вычисляется при показе и сохранении (`titleOr`), поэтому оно меняется вместе с видом записи и языком, пока человек не напишет своё.
- **`ai_repository.dart`** — всё про AI через API. Провайдеры внизу:
  - `aiStatusProvider` (строка 341) — есть ли AI на сервере. От него зависят кнопки скана. Удачный ответ хранится до конца сеанса (`ref.keepAlive`), неудачный — нет;
  - `petScansProvider` (строка 355) — сканы, которые ждут человека: читаются, готовы к проверке или не прочитались. Сервер отдаёт до 20 штук, новые сверху;
  - `scanReviewDataProvider` (строка 369) — питомец, его планы и шапка паспорта, **заново с сервера** для каждого экрана проверки. Если план создали на другом телефоне минуту назад, проверка о нём знает.
  - `discardScan` (строка 157): скан, которого уже нет, — не ошибка; а сохранённый скан выбросить нельзя, сервер ответит 409.
- **`widgets/ai_status_refresher.dart`** — `AiStatusRefresher` (строка 15). Если узнать, есть ли AI, не удалось (не было сети при запуске), он спрашивает снова (`_retryIfFailed`, строка 67), когда приложение вернулось из фона или экран снова показан. Стоит на «Паспорте», «Здоровье», «Запасах» и «Ещё». На «Ещё» вместо вечного «Проверяем…» видно «Не удалось проверить» и контурную кнопку «Повторить» (`more_screen.dart:44`).
- **`widgets/scan_entry.dart`** — где скан начинается: карточки на вкладке «Паспорт» и `openScan` (строка 19). Карточки бывают трёх видов: скан готов к проверке («Продолжить проверку скана от …»), скан ещё читается и **скан не прочитался** («Не удалось прочитать», `_FailedCard`, строка 196). У неудачного скана видна причина и две кнопки: «Повторить» (те же фото, новый скан с новым `requestId`; сервер сам убирает старый неудачный) и «Убрать» (`_dismiss`, строка 208). На вкладке «Здоровье» — круглая контурная кнопка рядом с «Добавить запись» (`health_tab.dart:115`), а пока история пуста — карточка «Сканировать паспорт» в ней (строка 257). На узком телефоне с крупным шрифтом кнопки уходят под заголовок (`OverflowBar` в `shared/widgets/cb_section.dart:59`), а надпись кнопки переносится — ничего не вылезает за край.
- **`files/media_picker.dart`** — откуда берутся страницы:
  - `scanPages` (строка 129): сканер документов (VisionKit на iPhone, ML Kit на Android) сам находит края листа и выравнивает его. Где сканера нет (симулятор), экран скана сам открывает фото из галереи (`scan_screen.dart:322`);
  - `prepareScans` (строка 171) уменьшает страницы сканера до 2048 px по длинной стороне и сохраняет в JPEG 85 % (`_shrink`, строка 187). Поворот страницы «впекается» в картинку, служебные данные (EXIF) не сохраняются, файл сканера удаляется. Фото из галереи и так приходят уменьшенными;
  - `deletePicked` (строка 176) удаляет копии страниц с телефона: это личные документы, им незачем лежать в памяти.
- **`scan_screen.dart`** — экран скана: выбор страниц, загрузка, ожидание, ошибки.
  - `_Start` (строка 67) — «скан, который запускаем»: страницы и **один `requestId` на скан** (строка 80). Если ответ сервера потерялся, «Повторить» отправит тот же id, и сервер вернёт уже начатый скан, а не запустит второй.
  - `_scanPages` (строка 274) просит у сканера **на одну страницу больше**, чем берёт скан (строка 284): сканер iPhone молча выбрасывает лишние страницы, а так приложение замечает «больше десяти», берёт первые 10 и говорит об этом. Пока страницы уменьшаются (строка 296), кнопки ждут.
  - `_run` (строка 407) — сначала загрузка страниц (строка 426), потом запуск (строка 434). Загруженные страницы помнятся (`DraftPhoto.file`), повтор их не грузит. Когда скан запущен, копии страниц на телефоне удаляются (строка 441); так же при «Сканировать заново» (`_startOver`, строка 387) и при уходе с экрана (`dispose`, строка 164).
  - Пока страницы загружаются, уйти с экрана нельзя (`PopScope`, строка 519). Пока AI читает — можно: сервер продолжит, а скан будет ждать на вкладке «Паспорт».
  - `_show` и `_check` (строки 219 и 231) — опрос раз в 2 секунды, пока AI читает. Приложение свернули (`_onHide`, строка 174) — опрос стоит; вернулись (`_onResume`, строка 179) — сразу один вопрос. Там же: если сканер так и не ответил (система его закрыла), через 2 секунды после возвращения кнопки снова работают.
  - «Повторить» у неудачного скана — это **новый** скан тех же фото с новым id (`_readAgain`, строка 376). С карточки на «Паспорте» экран открывается с `?again=1` и сразу запускает повтор (строка 207).
- **`scan_review.dart`** — черновик «как его оставил человек» (`ReviewRecord` и соседи, строка 47):
  - правила проверки (`recordProblems`, строка 655) — те же, что у сервера и у формы записи, включая «не раньше 1990 года» (строка 675);
  - **данные паспорта — по полям** (`ReviewPassport`, строка 274). Пустое сохранённое поле заполняется, если карточка отмечена. Поле, где сохранено другое значение, меняется, только если включить его переключатель «Заменить сохранённое» или исправить значение руками. Уходит только то, что меняется (`changes`, строка 346);
  - чипов и татуировок у питомца не больше 5 (`overLimit`, строка 462). Номер, который у питомца уже есть, места не занимает: сервер его просто пропустит, а сводка скажет «1 номер уже был у питомца»;
  - что уходит при сохранении (`sending`, строка 501) — только отмеченное;
  - `placeServerErrors` (строка 553): сервер называет ошибку по месту в запросе (`records[2].record.performedOn`, `passport.issuingCountry`), а функция находит, какая это запись черновика, и показывает ошибку на ней. Ошибка, которая не называет ни одной записи, показывается общим текстом внизу.
- **`scan_review_screen.dart`** — экран проверки. Данные для него берутся свежими (строка 55). Сохранение (`_save`, строка 263) устроено как в других формах:
  1. каждая карточка — поле формы (`_EntryField`, `widgets/draft_cards.dart:818`), поэтому проверяются все отмеченные записи, и экран прокручивается к первой с ошибкой (строка 272);
  2. всё нужное берётся до первого `await`, потом `applyScan` (строка 313);
  3. ответ 400 раскладывается по записям (строка 377); 409 («скан уже не ждёт проверки») — экран заново спрашивает скан и показывает, что с ним (строка 339);
  4. **ответ потерялся** (нет сети, таймаут, ошибка сервера — `_mayHaveGoneThrough`, строка 251): сохранение могло пройти. Экран спрашивает скан у сервера (строка 345). Сохранён — экран закрывается со сводкой и пометкой «сохранено до обрыва связи» (`_closeAsSaved`, строка 389). Не сохранён — можно поправить и сохранить снова. Спросить не удалось — следующее «Сохранить» сначала спросит (строка 305). Иначе второе сохранение получило бы ответ первого и молча потеряло бы новые правки.
  - «Удалить скан» (`_discard`, строка 419): если сервер отказал (409) или ответ потерялся, экран спрашивает скан. Если он уже сохранён, пишет «этот скан уже был сохранён», а не «скан удалён».
  - Уйти назад с правками нельзя молча: экран спросит «Уйти без сохранения?» (`_leave`, строка 480; `PopScope`, строка 506). Скан останется на вкладке «Паспорт».
- **`widgets/draft_cards.dart`** — карточки записей: галочка, значения, сомнения AI (жёлтым тегом со значком), «Прочитано на странице 1» с текстом как на странице (нажатие открывает фото), переключатель «Отметить выполнение в плане «Бешенство»». Предлагаются только планы того же вида и, для прививок, от тех же болезней (`planChoices`, строка 637); если в редакторе поменять вид или болезни, неподходящий план отвязывается. Карточка паспорта (`PassportDraftCard`, строка 328) под каждым значением пишет «Уже есть в данных паспорта» или «Сохранено: …» с переключателем «Заменить сохранённое» (строка 370). Кнопка «Заменить на 3 апр. 2020 г.» (`swapDateButton`, строка 472) есть у всех дат, где день и месяц могли перепутаться: у записей, чипов и даты выдачи паспорта.
- **`scan_editors.dart`** — редакторы одной записи. Они меняют копию и возвращают её по «Готово»; на сервер ничего не уходит.
- **`ai_labels.dart`** — тексты: статусы, причины ошибок и сводка после сохранения (`scanResultSummary`, строка 90): что сохранено, какие поля паспорта обновлены, какие номера уже были у питомца.
- **`ai_screen.dart`** — «Ещё → Распознавание фото»: подключено ли, модели, предупреждение о бесплатном тарифе Gemini, расход за месяц и «Проверить подключение». Проверка может идти до минуты: сервер спрашивает модели по очереди. Поэтому у этого запроса свой срок ожидания, 3 минуты (`AiTestTimeoutInterceptor`, `data/api/api_client.dart:279`), а у остальных запросов — 20 секунд.
- **`scan_refresh.dart`** — `refreshAfterScan`: после сохранения перезагрузить уход (как `refreshCare`), **все открытые планы** (строка 21: «Сделано» сдвигает план, и он мог быть открыт), питомца (чипы), шапку паспорта, документы (сохранённые фото), сканы питомца и данные экрана проверки.

### 5.16. Пуши, кормление и визиты на телефоне (`features/notifications/`, `features/feeding/`, `features/visits/`)

**Firebase и уведомления.** Пуш доставляет Firebase. Если приложение закрыто или свёрнуто, Android сам показывает уведомление. Если приложение открыто, Android ничего не показывает, и приложение показывает его само. Всё это спрятано за интерфейсом `PushPlatform` (`push_platform.dart`), а в тестах его заменяет подделка.

```dart
defaultTargetPlatform == TargetPlatform.android &&   // push_platform.dart:172 пуши — только Android (iPhone позже)
FirebaseMessaging.onMessage.listen(_showWhileOpen);   // :189 пуш пришёл, а приложение открыто — показать самим
await android?.createNotificationChannel(channel);   // :198 каналы из pushChannels (строка 39): кормление, «кто покормил», уход, визиты, запасы, прочее
id: 0,                                                // :215 как у Firebase: новый пуш с тем же тегом
tag: android?.tag,                                    // :222 заменяет прежний, а не копится рядом
```

Для интеграционных тестов на эмуляторе есть `DisabledPushPlatform` (строка 118): пушей нет, разрешение не спрашивается, и системный диалог не останавливает тест.

Каналы — это настройка Android: у каждого свой звук и свой переключатель в системных настройках. Их id совпадают с теми, что присылает сервер (`feeding`, `feeding-updates`, `care`, `appointments`, `supplies`, `general`), а названия создаются на языке приложения (`pushStartProvider`, `push_registration.dart:70`). «Кто покормил» (`feeding-updates`) — тихий канал: без звука и всплывающего окна. Когда кого-то покормил другой человек, такой пуш заменяет напоминание покормить на телефонах остальных (тот же тег). Если приложение открыто, оно показывает его так же тихо (`_showWhileOpen`, `push_platform.dart:212`). Нажатие ведёт на «Сегодня», как у кормления.

**Регистрация телефона** (`pushRegistrationProvider`, `push_registration.dart:104`) запускается после входа и при каждом старте приложения:

```dart
if (!await platform.permissionGranted()) {                          // push_registration.dart:120 не разрешено — сама не спрашивает:
                                                                    //     «ещё не спрашивали» или «отказали»
token = await platform.token().timeout(const Duration(seconds: 20));  // :125 адрес телефона в Firebase, не ждать вечно
if (!ref.mounted) return PushState.noToken;                         // :132 пока ждали, вышли из аккаунта — дальше не идти
final refreshes = platform.tokenRefreshes.listen((fresh) async {    // :134 Firebase сменил адрес — сообщить снова
await repository.registerDevice(deviceId, token);                   // :144 PUT /devices/{id}
```

Разрешение спрашивается не здесь и не сразу после входа: вопрос из ниоткуда, ещё до питомцев, пугает. Его задаёт `askForPushesOnce` (5.18), когда сохранено первое кормление, визит или план, и только один раз: если человек отказал, приложение больше не пристаёт. «Сегодня», форма кормления и экран «Ещё → Уведомления» покажут, что уведомления выключены, и кнопку «Открыть настройки».

`deviceId` (строка 58) — случайный id установки, хранится на телефоне. Он не меняется, когда Firebase выдаёт новый адрес, поэтому на сервере одна запись на телефон. Поэтому же Android не сохраняет данные приложения в резервную копию (`android:allowBackup="false"` в `AndroidManifest.xml`): иначе новый телефон, восстановленный из копии, получил бы тот же id, и два телефона делили бы одну запись.

При выходе из аккаунта (`signOutOfThisPhone`, строка 155) телефон сначала просит сервер забыть его, а потом сам выбрасывает адрес Firebase (`localSignOutProvider`, строка 189). Второе срабатывает и без связи с сервером. Следующий человек на этом телефоне не должен получать чужие напоминания. Сама кнопка «Выйти» сначала спрашивает подтверждение (`_SignOutButton`, `more_screen.dart:365`). После выхода телефон стирает и копии ответов (`push_registration.dart:203`): следующий человек не увидит чужих данных без связи (5.18). Та же местная часть выхода срабатывает после удаления аккаунта, только без просьбы к серверу (5.23).

**Нажатие на пуш** (`pushTapsProvider`, строка 242). В пуше лежат данные: вид и id. По ним `routeForPush` (строка 220) выбирает экран: кормление → «Сегодня», уход → вкладка «Здоровье» питомца, визит → визит, «пора купить» → товар. Перед переходом нужные экраны перечитываются (`refresh`, строка 246): пока телефон спал, данные могли измениться. То же — когда пуш пришёл при открытом приложении (строка 312). Если внутри «Сегодня» открыта форма, экран пуша открывается поверх неё (строка 270), и набранное не теряется. Пуш другой группы сначала переводит приложение в неё (5.19).

«Сегодня» перечитывается ещё в двух случаях (`TodayReload` в `features/today/today_reload.dart`, его подключают и «Сегодня», и «Главная»): когда приложение возвращается на экран (строка 23) и сразу после полуночи (`_reloadAfterMidnight`, строка 37), чтобы вчерашние кормления не выглядели сегодняшними.

**Кормление на «Сегодня»** (`widgets/today_feeding.dart`). Кормления сгруппированы по времени. У каждого питомца кнопка «Покормили», а если непокормленных двое и больше — контурная кнопка «Покормить всех» (строка 263). На узком телефоне с крупным шрифтом она уходит под время. Тот же виджет показывает ближайшее кормление на «Главной» (`next: true`, строка 41; какое время ближайшее, решает `nextFeeding` в `feeding.dart:178`, по отметкам, которые пришли с сервера: пока «Сегодня» перечитывается, отмеченное здесь не пропадает): заголовок «Кормление в 08:00», без своего раздела.

```dart
} on FeedingAlreadyMarked catch (conflict) {        // today_feeding.dart:98 кто-то успел раньше — показать, кто
setState(() => _local[_key(item)] = mark);          // :97 отметка видна сразу, до перезагрузки экрана
if (!identical(oldWidget.items, widget.items)) _local.clear();  // :62 пришли свежие данные — верить серверу
onLongPress: mark == null && !busy ? () => _skip(item) : null,  // :369 «пропустить» — долгое нажатие и вопрос (:137)
```

Кто отметил кормление, если не вы, написано под именем питомца (строка 364), а на кнопке — только время: длинное имя не выталкивает строку за край экрана.

Ответ 409 разбирает репозиторий (`feeding_repository.dart:122`): в теле ответа сервер прислал чужую отметку, из неё получается `FeedingAlreadyMarked` с именем и временем (строка 135). Если в теле не отметка, остаётся обычная ошибка «конфликт».

Количество корма проверяется по тексту (`feeding_form_screen.dart:175`): до 5 цифр и до 2 знаков после точки или запятой. Числом проверять нельзя: 2,2 × 100 в компьютере — не ровно 220, и правильное «2,2» отклонялось.

**Визиты** (`features/visits/`). Дата и время визита задаются по времени семьи. Форма отправляет их отдельно (`date` и `time`), а не одним моментом: сгенерированный клиент умеет отправлять даты только без времени (5.6). «Визит состоялся» (`visit_done_sheet.dart`) сам предлагает план, который этот визит закрывает (строка 95): единственный план того же вида у питомца, если он повторяется. Разовый план («осмотр перед поездкой») не отмечается сам: его закрывает не любой визит. Если сервер отказал (визит отменили или он ещё не наступил по времени семьи), лист так и пишет (строка 148).

«Отменить» и «Запланировать снова» (`visit_detail_screen.dart:256`) сначала перечитывают визит с сервера и отправляют его целиком с новым статусом: с другого телефона его могли изменить, пока страница была открыта. Форма визита не пропадает, если сохранение не удалось без связи (`visit_form_screen.dart:43`): набранное остаётся, можно нажать «Сохранить» ещё раз.

«Сегодня», «завтра», «вчера» считаются по календарным датам (`calendarDaysBetween`, `feeding_labels.dart:63`), а не по часам: в день перевода часов в сутках 23 или 25 часов.

**Экран «Ещё → Уведомления»** (`notifications_screen.dart`) отвечает на вопрос «почему не пришло». Он показывает, доходят ли пуши на телефон (и как включить, если выключены), позволяет прислать проверочное уведомление, включить и выключить виды напоминаний. Переключатель сразу показывает новое положение, пока сервер сохраняет. Ниже — журнал ближайших и недавних напоминаний с тем, что с каждым стало: «отправлено», «не нужно: уже сделано», «некому отправить», «опоздало: сервер был выключен».

### 5.17. Запасы на телефоне (`features/supplies/`)

**Вкладка «Запасы»** (`supplies_screen.dart`) делит товары на группы (строка 56): «Купить» (закончился или пора), «Скоро закончится», «В запасе», «Больше не покупаем». У строк из «Купить» сразу есть кнопка «Купили». Кнопка «Добавить» открывает выбор (`showAddSupplySheet`, строка 145): сканировать штрихкод, сфотографировать упаковку (только если AI подключён) или заполнить вручную.

**Страница товара** (`supply_detail_screen.dart`). Сверху карточка прогноза (`_ForecastCard`, строка 198): на сколько хватит, сколько осталось, когда закончится и когда купить. Ниже — кнопки «Купили» и «Уточнить остаток», кормления с этим кормом, данные товара и история покупок (`_History`, строка 446). Любую запись истории можно отменить (помощник — только свою, 5.19).

**«Купили» и «Уточнить остаток»** (`stock_sheets.dart`). Покупка вводится упаковками («2 пачки по 2 кг»), поправка — закрытыми упаковками и тем, насколько полна открытая (шаг 10 %). Телефон сам переводит это в граммы:

```dart
double get _quantity =>  // stock_sheets.dart:110 упаковки × размер (+ доля открытой)
int _estimateTenths() {  // :105 поправка начинается с прогноза, в десятых упаковки
final _requestId = const Uuid().v4();  // :84 один id на запись: повтор не посчитает покупку дважды
```

`StockTarget` (строка 17) — то немногое, что нужно этим окнам. Поэтому «Купили» работает и со страницы товара, и с «Сегодня».

**Форма товара** (`supply_form_screen.dart`):
- Размер вводится в привычных единицах: килограммы и литры (`SupplyInputUnit`, `supply_labels.dart:30`). Сервер хранит граммы и миллилитры, пересчёт — `inputFactor` (строка 40).
- Пока человек не выбрал единицу сам, она следует за видом товара (`_defaultUnit`, строка 180): сухой корм — в килограммах, влажный — в штуках, препарат — в дозах.
- Расход вручную вводится как «упаковки хватает на N дней» или как «столько-то в день». Сервер хранит расход в день с 6 знаками. Поэтому при правке форма сравнивает дни с допуском (`_initialManualUsage`, строка 197), иначе ошейник на 240 дней превратился бы в «0 в день».
- Поле «Указать, сколько есть сейчас» есть только у нового товара (строки 398 и 760). Потом остаток меняют покупки и уточнения остатка.
- Штрихкод проверяется по контрольной цифре прямо на телефоне (`isValidGtin`, `supply_labels.dart:103`).
- После сохранения открывается страница нового товара (строка 448). Препарат, который говорит, на сколько недель защищает, передаёт туда предложение плана обработки (`SupplyPlanOffer`, `supply_plan_offer.dart`).

**Скан** (`product_scan_screen.dart`). Экран ведёт по шагам: сканер → поиск (`_find`, строка 125) → либо «уже есть в запасах», либо форма, либо «не хватает данных — сфотографируйте». Фото (до 3, с камеры или из галереи, `_pickPhotos`, строка 186) загружаются и уходят на чтение (`_read`, строка 208). Результат открывает форму вместо экрана скана (`_openForm`, строка 165): «Назад» из формы ведёт к списку, а не к законченному скану. Пока AI читает, ждать не обязательно: «Назад» уводит с экрана (ответ AI тогда не нужен), а «Заполнить вручную» сразу открывает форму с тем, что уже известно (строка 293). Двойное нажатие «Повторить» открывает один сканер (`_scanning`, строка 107).

Что найдено, собирает `SupplyPrefill.from` (`supply.dart:337`). Данные из базы важнее фото: название в базе написано как на полке. Если что-то пришло из Open Pet Food Facts, источник остаётся их (строка 354), даже когда размер дочитали с фото. Так форма показывает их лицензию, а сервер не кладёт их данные в каталог.

**Сканер** (`barcode_reader.dart`) — пакет `mobile_scanner` и общая с чипами камера `shared/widgets/barcode_scanner_page.dart` (5.7). Запасы ищут только товарные коды (строка 28), а не QR-коды магазинов. Сканер открывается поверх всего приложения и закрывает даже панель вкладок (`showBarcodeScanner`, `barcode_scanner_page.dart:38`): так камера не останется работать на другой вкладке. Пока человек вводит цифры вручную, камера отдыхает (`_type`, строка 62). Короткие коды UPC-E с американских упаковок телефон разворачивает в полный UPC-A (`expandUpcE`, строка 82).

**Связи с другими экранами:**
- В форме кормления есть «Корм из запасов» (`feeding_form_screen.dart`, `_choosableSupplies`, строка 196). Выбранный корм задаёт название и единицу порции.
- На «Сегодня» есть раздел «Купить» (`widgets/today_shopping.dart`). Контурная кнопка «Все запасы» переключает вкладку, как нажатие на панель (`openTab`, `today_shopping.dart:31`), и не сбрасывает то, что там открыто.
- После изменения кормления или архивации питомца прогнозы перечитываются (`refreshSupplyEstimates`, `supply_refresh.dart:28`).

### 5.18. Полировка: без связи, формы, первый запуск

Связь с сервером иногда пропадает: в метро, за городом, при слабом мобильном интернете. Эта глава о том, как приложение это переживает, и о мелочах, без которых им неудобно пользоваться каждый день.

**Копия последних ответов** (`data/api/offline_cache.dart`) — «кэш на чтение» из спецификации (раздел 3). Каждый ответ на `GET`, из которого строятся экраны, телефон кладёт в свою папку отдельным файлом. Когда сервер не отвечает, экран получает эту копию вместо ошибки:

```dart
String? keyFor(RequestOptions options) {                          // offline_cache.dart:248 у каждого ответа свой ключ: пользователь, группа, адрес, запрос
final query = path == '/api/v1/today' ? '' : uri.query;           // :265 дата «Сегодня» каждый день новая: годится и вчерашняя копия
onReachability(ServerReachability.unreachable(dataAt: copy.at));  // :367 приложению сказали: на экране копия от такого-то времени
```

- Живой ответ всегда важнее: копия нужна только после ошибки сети или таймаута. Ответ с ошибкой (500, 404) — это тоже ответ, копию вместо него не дают.
- У каждого аккаунта свои копии: в ключе id пользователя, взятый в момент запроса, и группа, которую назвал запрос (5.19). При выходе из аккаунта папка стирается (`localSignOutProvider`, `push_registration.dart:203`).
- AI-сканы, файлы, поиск товаров и настройки уведомлений не копируются: без связи они бесполезны.
- Минуту после любого изменения копии старше него не показываются (`changeShowsFor`, `offline_cache.dart:215`): экраны как раз перечитываются, чтобы показать изменение. Старая копия выглядела бы так, будто изменения не было, и подтолкнула бы сделать его ещё раз.

**Изменения поверх копий не делаются.** Пока сервер не отвечает, на экранах могут быть копии: вчерашний «Сегодня» или план, который уже отметили на другом телефоне. «Покормили» на такой копии ушло бы на вчерашний день. Поэтому изменение не отправляется, а приложение сначала спрашивает, не вернулся ли сервер:

```dart
if (isReachable() || _passesBy(options)) {                // offline_cache.dart:281 сервер отвечал (или это отчёт визора, 5.20): уходит как обычно
final back = await (probe?.call() ?? Future.value(false)); // :285 нет — спросить его (GET /health)
```

Если сервер вернулся, все экраны перечитываются, а человек видит «Связь с сервером восстановилась, данные обновились. Проверьте их и повторите». Если нет — «Не удаётся связаться с сервером. Проверьте подключение и попробуйте снова».

**Связь вернулась — обновились все экраны.** После входа телефон сообщает серверу свой часовой пояс и язык (`profileSyncProvider`, `features/me/profile_sync.dart`), и все провайдеры данных ждут этого шага. Поэтому, как только сервер снова отвечает, этот шаг перезапускается, а за ним перечитывается всё:

```dart
if (next.reachable && previous != null && !previous.reachable) {  // profile_sync.dart:32 был недоступен, теперь отвечает
```

Пока «Сегодня» перечитывается, старый список виден, но на нажатия не отвечает (`today_screen.dart:75`; на «Главной» так же, `home_screen.dart:448`).

**Полоска «Нет связи с сервером · данные на 14:05»** (`app/offline_banner.dart`) стоит над нижним меню на всех вкладках. Время — самой старой копии на экранах. Пока полоска видна, она спрашивает сервер каждые 20 секунд и при каждом возвращении в приложение (`checkEvery`, строка 21). «Повторить» спрашивает сразу.

**Быстрая ошибка.** Сервер в интернете получает 10 секунд на подключение. API на компьютере разработчика в той же сети отвечает за миллисекунды, поэтому ему даётся 3 секунды (`ApiClient.connectTimeoutFor`, `api_client.dart:119`; какие адреса считаются локальными — `local_network.dart`). «Покормить всех» останавливается на первом питомце без ответа (`today_feeding.dart:105`).

**Формы, открытые без связи** (`shared/offline_copy.dart`). Форма изменения, открытая по копии, могла бы сохранить старые значения поверх новых. Такая форма не сохраняет и говорит открыть её снова, когда связь появится. Это проверяется один раз, при открытии.

**«Уйти без сохранения?»** (`shared/widgets/leave_guard.dart`). Форма помнит, с чем открылась, и при «Назад» сравнивает это с тем, что в ней сейчас:

```dart
List<Object?> _values() => [  // pet_form_screen.dart:129 всё, что держит форма: тексты, даты, переключатели, фото
_opened = _values();            // :159 то, с чем она открылась
```

Спрашивает только при настоящих изменениях: набрали и стёрли — вопроса нет. Сохранение закрывает экран само (`Navigator.pop`), страж ему не мешает. Так устроены 9 форм и лист «Как прошёл визит?». Повторное нажатие на текущую вкладку тоже спрашивает (`home_shell.dart:144`): оно убирает экраны поверх первого без «Назад». А экран, который сейчас сохраняет (или удаляет аккаунт, 5.23), оно не убирает вовсе (`LeaveGuard.busyInView`, строка 142).

**Вход** (`features/auth/sign_in_screen.dart`). «Забыли пароль?» просит Firebase прислать письмо со ссылкой (`sendPasswordReset`). Ответ одинаковый, есть такой аккаунт или нет: посторонний не узнает, кто пользуется приложением. Выход из аккаунта спрашивает подтверждение (`_SignOutButton`, `more_screen.dart:365`).

**Первый запуск.**
- После первого входа приложение открывается на «Главной», и поверх неё само открывается знакомство: три страницы о приложении и первые шаги (5.27). Один раз на аккаунт на этом телефоне и только тому, кто начинает с нуля: одна группа, в ней ни одного питомца.
- Пустой «Сегодня» подсказывает первый шаг (`TodayFirstSteps`, `features/today/first_steps.dart:21`): без питомцев — залитая кнопка «Добавить питомца», с одним питомцем — карточки его кормления и прививок, с несколькими — карточки ведут в список, чтобы выбрать. Те же карточки показывает «Главная», когда у питомцев ничего не настроено.
- Разрешение на уведомления спрашивается не сразу после входа, а когда сохранено первое кормление, визит или план, и с одной строкой «зачем» (`askForPushesOnce`, `push_registration.dart:330`). Отказ виден на «Сегодня» и в форме кормления, с кнопкой «Открыть настройки» (`widgets/push_off_notice.dart`).

**Загрузка — скелетоном** (`CbLoadingState`, `shared/widgets/state_views.dart`). Пока данные идут, на месте списка видны серые строки, а на месте формы — серые поля, по ним бежит мягкий перелив. Экран не прыгает, когда данные приходят. Обычный крутящийся индикатор остался там, где ждут не содержимое: камера запускается, AI читает (`CbLoadingState.spinner()`). Если телефон просит меньше движения, перелив стоит на месте.

**Свежие данные.** «Питомцы» и «Запасы» перечитываются, когда приложение возвращается на экран (`shared/widgets/reload_on_resume.dart`): другой телефон мог отметить покупку. Вкладки питомца не загружаются заново при каждом переключении (`KeepTabAlive`). Страница питомца открывается сразу с данными из списка, пока сервер присылает свежие (`pet_detail_screen.dart:49`).

### 5.19. Группы и роли на телефоне (`features/household/`)

Человек может состоять в нескольких группах («Мой дом», «Офис»), и в каждой у него своя роль: владелец, участник или помощник. Телефон в каждый момент показывает одну группу и называет её в каждом запросе.

**Какая группа на экране** (`features/household/current_household.dart`). `currentHouseholdProvider` (строка 74) хранит id группы, её название и вашу роль в ней. Хранит на телефоне, отдельно для каждого аккаунта (ключ `household.<uid>`, строка 81). Поэтому приложение открывается в той же группе, и роль известна ещё до первого ответа сервера, даже без связи.

```dart
CurrentHousehold? build() {                       // current_household.dart:86 прочитать сохранённое для этого аккаунта
void switchTo(CurrentHousehold household)         // :95 выбрали в списке, вступили по коду, нажали пуш другой группы
void remember(Household answer, {required String? asked})  // :102 что ответил /me
void lost(String householdId)                     // :119 сервер сказал «вас нет в этой группе»
void forget(String householdId)                   // :129 вышли из группы или удалили её
```

Пока группа не выбрана (первый запуск), запросы идут без неё, и сервер отвечает про первую группу человека. Синхронизация профиля запоминает эту группу (`remember`) ещё до загрузки экранов. До этого ответа копии без связи не хранятся (ниже).

**Заголовок `X-Household`** (`data/api/household_header.dart`). Перехватчик стоит в цепочке сразу после заголовков входа (`api_client.dart:79`) и берёт группу у `currentHouseholdProvider` (`api_providers.dart:24`):

```dart
final pinned = Zone.current[pinKey];                     // household_header.dart:52 запрос привязан к своей группе?
if (id != null) options.headers.putIfAbsent(householdHeader, () => id);  // :54 иначе — группа на экране
case ProblemTypes.notAHouseholdMember when named is String:  // :64 «вас нет в этой группе»: какую группу назвал запрос
case ProblemTypes.roleForbidden:                         // :66 «роль не позволяет»: спросить роль заново
```

**Изменение идёт в свою группу, а не в ту, что на экране в момент отправки.** Экран или форма одной группы могли остаться открытыми, пока приложение перешло в другую (нажали пуш). Поэтому изменение называет группу, в которой его начали:
- `inHousehold(id, …)` (`household_header.dart:17`) запускает действие так, что все его запросы называют эту группу. То же делает `send(…, household: id)` (`api_client.dart:145`).
- Экран группы передаёт id своей группы в каждое изменение (`HouseholdRepository`, например `household_screen.dart:78`; в репозитории — `household: householdId`).
- Формы (питомец, план, запись, документ, паспорт, кормление, визит, товар, «Сделано») запоминают группу при открытии (`OpenedInHousehold`, `current_household.dart:245`) и сохраняют в неё (`inOpenedHousehold`, строка 256; в форме — `onSave: () => inOpenedHousehold(_save)`, `pet_form_screen.dart:585`).

Если пользователя в той группе уже нет, сервер откажет (403), а не сохранит в другую.

**Сменили группу — всё начинается заново** (`app/home_shell.dart`). На смену группы оболочка вкладок отвечает так:

```dart
if (previous == null || previous == next) return;   // home_shell.dart:85 узнали выбор сервера — это не переход
_closeDialogs();                                    // :86 закрыть окна («Выйти из группы?»): они были про старую группу
setState(() => _remounting = true);                 // :87 на один кадр убрать вкладки из дерева
body: _remounting ? const SizedBox.shrink() : shell,  // :118 и вернуть их кадром позже (строка 114)
```

Зачем убирать вкладки: Riverpod, перезагружая провайдер, держит его прошлое значение, пока не придёт новое. Без этого вкладка «Питомцы» показала бы питомцев прежней группы, а без связи — оставила бы их насовсем. Когда экраны уходят из дерева, их провайдеры удаляются (`autoDispose`), и новые экраны создают их с нуля: сначала загрузка, потом данные новой группы или ошибка. Заодно все вкладки открываются с первого экрана, а нижние листы пропадают вместе со своей вкладкой.

Данные загружаются заново потому же, что и после возвращения связи (5.18): все провайдеры данных ждут синхронизацию профиля, а синхронизация следит за группой на экране:

```dart
final asked = ref.read(currentHouseholdProvider)?.id;  // profile_sync.dart:39 какую группу называют запросы (или никакую)
if (next != shown) ref.invalidateSelf();               // :47 другая группа: синхронизация заново, за ней все данные
shown = profile.household.id;                          // :70 ответ /me назвал группу на экране
    .remember(profile.household, asked: asked);        // :73 запомнить её и вашу роль до загрузки экранов
```

`shown` нужен, чтобы `remember` не считался сменой группы: первый ответ сервера только называет группу, которая и так на экране.

**Копии без связи — свои у каждой группы.** В ключе копии есть группа, которую назвал запрос (`offline_cache.dart:255`). Запрос без группы копию не хранит (строка 253): какую группу выберет для него сервер, может измениться. Копии, сохранённые до групп, один раз удаляются при первом запуске новой версии (`_cleanFolder`, строка 104): их больше никто не прочтёт. Копии группы, из которой вышли или убрали, удаляются (`forgetOfflineCopies`, `api_providers.dart:44`).

**Вас убрали из группы.** Это можно узнать двумя путями:
- Обычный запрос получает 403 с типом `not-a-household-member`. Перехватчик зовёт `lost` (`current_household.dart:119`).
- `/me` про устаревшую группу не отвечает ошибкой, а отвечает про первую группу человека. `remember` видит, что ответ не про ту группу, о которой спрашивали (строка 106).

Итог один: приложение переходит в первую группу и сообщает об этом оболочке (`HouseholdLeft`, `current_household.dart:155`). Оболочка возвращает текущую вкладку на первый экран (там могла быть форма той группы, `home_shell.dart:93`), удаляет копии группы (строка 93) и пишет «Вас больше нет в группе «Офис»». Ответы других экранов группу не меняют: `refresh` (`current_household.dart:112`) только обновляет название и роль.

**Роли: правила в одном месте** (`HouseholdPermissions`, `current_household.dart:207`):

```dart
bool get canEdit => role != HouseholdRole.helper;          // current_household.dart:217 добавлять, менять, удалять, сканировать
bool get canManagePeople => role == HouseholdRole.owner;   // :220 люди группы и её название
bool canTakeBack({required bool byMe}) => canEdit || byMe; // :224 помощник отменяет только свои отметки
```

Экраны спрашивают `ref.watch(householdPermissionsProvider).canEdit` (например, `pets_screen.dart:27`) и прячут кнопки: «Добавить», карандаш, меню с «Удалить», AI-скан, фото, листы паспорта, «Проверить подключение» AI.
- Помощнику остаются отметки: «Покормили», «Сделано», «Визит состоялся», «Купили» и «Уточнить остаток».
- На экране «Сделано» у помощника нет фото, и следующую дату выбрать нельзя: сервер всё равно возьмёт рассчитанную (`done_screen.dart:577-583`).
- Свои отметки кормления и покупки помощник может отменить, чужие — нет (`today_feeding.dart:331`, `supply_detail_screen.dart:489`).
- Пока роль неизвестна, кнопки видны. Сервер всё равно проверит роль и откажет, а телефон напишет «Ваша роль в группе не позволяет это сделать» (`shared/error_messages.dart:30`).

Роль может поменять владелец на другом телефоне. Телефон узнаёт её заново (`roleCheckProvider`, `current_household.dart:191`; от него зависит `meProvider`, `profile_sync.dart:88`):
- при каждой синхронизации (запуск, связь вернулась, другая группа);
- когда приложение вернулось на экран (`home_shell.dart:49`);
- когда сервер отказал из-за роли (`api_providers.dart:27`).

Оболочка держит `meProvider` загруженным, пока вы вошли (`home_shell.dart:79`).

**Ещё → Группа** (`_HouseholdCard`, `more_screen.dart:260`): название группы, ваша роль и сколько в группе человек. «Сменить группу» открывает список групп (`household_sheets.dart:63`), а в нём «Создать группу» и «Вступить по коду». Сервер называет первую группу человека «Home»: её владелец видит «Мой дом», остальные — «Дом» (`householdName`, `household_labels.dart:18`). У кого групп больше одной, видит группу и на «Сегодня» и «Главной», рядом с датой (`todayGroupShown`, `today_screen.dart:263`).

**Экран группы** (`household_screen.dart`). Права здесь берутся из свежего ответа сервера (строка 218): владелец мог только что поменять вам роль. Люди группы, которая уже не на экране, не показываются, как будто ещё грузятся (строки 210-213).
- «Пригласить» — контурная кнопка в заголовке «Участники» (`_invite`, строка 83). Сам порядок живёт в `inviteToHousehold` (`household_sheets.dart:331`): его же зовёт шаг «Семья» знакомства (5.27). Сначала роль — участник или помощник, с одной строкой о том, что он может (`showInviteRoleSheet`, строка 358). Потом код крупным моноширинным шрифтом, «Поделиться» и «Скопировать» (`_share`, строка 429; `_copy`, строка 446). В тексте для отправки группа названа так, как её увидит приглашённый: «Дом», а не «Мой дом» (строка 435). «Отозвать» у приглашения — компактная контурная кнопка. «Поделиться» — пакет `share_plus` через `shareTextProvider` (`shared/share_text.dart`); тесты его подменяют.
- Нажатие на человека (только у владельца) — роль и «Убрать из группы» (`_memberActions`, `household_screen.dart:106`). Сменить роль себе — значит перестать быть владельцем: экран сначала спрашивает (строка 124).
- «Выйти из группы» (`_leave`, `household_screen.dart:156`) спрашивает подтверждение. Если вы последний владелец, сервер отвечает 409, и экран пишет «Сначала назначьте другого владельца». После выхода приложение забывает группу, если она ещё на экране, удаляет её копии (`_gone`, строки 193-196) и возвращается в «Ещё».
- Владелец, который один в группе, видит «Удалить группу» вместо «Выйти» (`household_screen.dart:336-343`). Сервер удалит только пустую группу: без питомцев, запасов и файлов.

Отказы сервера приходят с типом (`last-owner`, `already-a-member`, …). Свои тексты для них — в `householdErrorMessage` (`household_labels.dart:57`).

**Вступить по коду** (`join_screen.dart`).
- Поле само делает буквы заглавными и ставит дефис после четвёртого знака. Из вставленного сообщения берётся только код (`InviteCodeFormatter`, `household_labels.dart:79`).
- В кодах нет букв O и I и цифр 0 и 1: такой знак телефон замечает сам и не тратит попытку (`impossible`, `household_labels.dart:90`; `join_screen.dart:60`).
- Код проверяется один раз, когда введены все 8 знаков (`_changed`, `join_screen.dart:55`): сервер даёт немного попыток за 10 минут. Ответ на код, который уже стёрли, не показывается (строка 66).
- Код уходит в теле запроса, а не в адресе: адреса попадают в журналы сервера (`household_repository.dart:138`).
- «Вступить» (`_join`, `join_screen.dart:100`) переводит приложение в новую группу (строка 115).

**Пуш другой группы** (`push_registration.dart:272-293`). В пуше есть `householdId`. Если это не группа на экране, приложение сначала переходит в неё и коротко пишет «Теперь вы в группе «Офис»» (`HouseholdOpened`, строка 292), а потом открывает экран пуша. Форма, открытая внутри «Сегодня», не остаётся под ним: она про другую группу (строки 303-306). «Внутри Сегодня» — это вкладка «Сегодня» на экране (`shownTab`, `router.dart:201`): «Главная» тоже кладёт поверх себя экраны «Сегодня» (визит, форму визита), и пуш с такой «Главной» открывает свой экран на вкладке «Сегодня».

### 5.20. Визор: что приложение сообщает серверу (`data/api/app_events.dart`)

Чтобы помочь человеку, когда «что-то не работает», админу нужно видеть, что делало его приложение (визор, 4.22). Приложение сообщает серверу: какие экраны открывались, несколько действий, какие ошибки человек увидел и падения. Сервер хранит это 7 дней. **Никогда не уходит то, что человек ввёл**, имена питомцев и id: экран — это шаблон адреса, действие — заранее заданное имя, ошибка — её вид и коды, падение — тип и строки нашего кода.

**Каждый запрос называет запуск и версию** (`data/api/app_session.dart`). По ним журнал запросов на сервере собирает визит в одну ленту:

```dart
const appSessionHeader = 'X-App-Session';  // app_session.dart:7 какой это запуск приложения
const appVersionHeader = 'X-App-Version';  // :8 какая версия
const appVersion = '0.1.0';                // :12 как в pubspec.yaml: тест следит, чтобы совпадало
final appSession = const Uuid().v4();      // :16 случайный id: новый при каждом запуске, нигде не хранится
```

Перехватчик `AppSessionInterceptor` стоит в цепочке сразу после заголовка группы (`api_client.dart:86`).

**Четыре вида сообщений** (`AppEventKind`):
- **Экран.** Роутер сообщает о каждом новом экране, переключение вкладок тоже (`router.dart:544`). Уходит шаблон адреса верхнего экрана (`screenPattern`, строка 567): `/pets/:petId/edit`, без id и без `?tab=…`. Экран, открытый через `push`, лежит последним в списке и знает свой шаблон сам.
- **Действие** — одно из одиннадцати имён (`AppAction`, `app_events.dart:27`): `fed`, `fed-all`, `done`, `visit-took-place`, `bought`, `pet-saved`, `scan-started`, `note-started`, `invite-created`, `joined-group`, `group-switched`. Экран сообщает о нём, когда сервер ответил «готово»: например, «Покормили» (`today_feeding.dart:113`) или «Сделано» (`done_screen.dart:295`). Скан и заметка — когда человек их запустил (`scan_screen.dart:548`).
- **Ошибка** — когда экран показывает сообщение о неудачном запросе. Об этом сообщают сами `errorMessageFor` и `fieldErrorsOf` (`shared/error_messages.dart:11` и `:57`), поэтому экраны ничего для этого не делают. Имя — вид ошибки (`network`, `server`, `forbidden`…), подробности — код ответа, тип проблемы и trace id сервера (`errorDetail`, `app_events.dart:371`). Текст ответа сервера не уходит. Экран перестраивается много раз, а ошибка уходит один раз (`_firstTime`, строка 340).
- **Падение** — тип исключения и до пяти строк нашего кода, через которые оно прошло (`appFrames`, `app_events.dart:385`), например `features/pets/pets_screen.dart:42`. Сообщение исключения не уходит: в нём бывают данные человека. Сломанный виджет падает на каждом кадре, поэтому одно и то же падение уходит не чаще раза в минуту (`app_events.dart:232`).

**Как сообщения уходят** (`AppEventReporter`, `app_events.dart:135`). Они копятся в памяти и уходят пачками, а не отдельным запросом на каждый экран:

```dart
static const keep = 200;                         // app_events.dart:143 ждут не больше 200: новое вытесняет самое старое
static const sendAt = 20;                        // :146 набралось 20 — отправить сразу
static const sendAfter = Duration(seconds: 30);  // :149 иначе через 30 секунд после первого
static const perRequest = 50;                    // :152 в одном запросе не больше 50
static const requestsPerMinute = 5;              // :156 и не больше 5 запросов в минуту: сервер принимает 6
```

- Приложение ушло в фон — всё, что ждёт, уходит сразу (`onPause`, строка 502).
- Пачка не ушла — она пробует ещё раз со следующей, потом выбрасывается (строка 261). Визор нужен, чтобы оглянуться назад, копить его на телефоне незачем.
- Только пока человек вошёл (`_signedIn`, строка 284): до входа ничего не копится, а выход выбрасывает то, что ждало, не отправляя (строка 499).
- Уходят они через сгенерированный клиент, `POST /api/v1/events` (`sendAppEventsProvider`, строка 458). Время — числом миллисекунд (`atUnixMs`, строка 472), поэтому часовой пояс телефона не важен.
- Копия ответов без связи эти запросы пропускает мимо (`_passesBy`, `offline_cache.dart:240`): они идут в фоне и ничего не меняют на экранах. Поэтому из-за них не появляется полоска «Нет связи» и не прячутся копии (5.18).

**Падения** ловит `watchCrashes` (`app_events.dart:417`). `main.dart:46` включает его перед запуском приложения. Он подключается к `FlutterError.onError` (ошибки Flutter, например виджет не построился) и к `PlatformDispatcher.instance.onError` (ошибки, которые никто не поймал). Прежние обработчики работают как раньше: консоль и тесты видят все ошибки.

**Где визор молчит.** В отладочной сборке и в тестах вместо него `NoAppEvents`, который ничего не делает (`appEventsOnProvider`, `app_events.dart:455`). В отладке его включает `--dart-define=CB_APP_EVENTS=true`, тесты визора — подмена провайдера. Тесты: `test/data/api/app_events_test.dart` (очередь на поддельных часах `fake_async`), `test/app/visor_test.dart` (экраны, действия, ошибка, выход из аккаунта), `test/data/api/app_session_test.dart` (заголовки и версия).

### 5.21. Тариф и лимит AI на телефоне (`features/billing/`)

Тариф принадлежит группе: Free или Premium (4.23). Оплаты пока нет, Premium выдаётся вручную в админке. Телефон только показывает тариф и объясняет, почему AI отказался читать фото.

**Экран «Тариф»** (`billing/household_plan_screen.dart`). Его открывают «Ещё → Тариф» в карточке группы (`more_screen.dart:315`), строка тарифа на экране группы (`_PlanRow`, `household_screen.dart:352`) и кнопка «Посмотреть тариф» под ошибкой лимита. Экран лежит поверх вкладок (`AppRoutes.householdPlan`, `router.dart:175`; маршрут — строка 240): его можно открыть с любой вкладки, а «Назад» возвращает туда, откуда пришли.

```dart
final householdPlanProvider = FutureProvider.autoDispose<HouseholdPlan>(  // billing_repository.dart:44 тариф группы на экране
  await ref.watch(profileSyncProvider.future);                          // :48 другая группа или связь вернулась — загружается заново
expiresAt: plan.expiresAt?.toLocal(),                                   // :30 конец Premium — момент: день по часам телефона
resetsAt: plan.resetsAt.toLocal(),                                      // :33 когда счётчик обнулится — тоже момент, показываем его день
```

На экране (`HouseholdPlanScreen`, `household_plan_screen.dart:21`):
- тариф и группа; у Premium — «До 31 декабря 2026 г.» или «Бессрочно» (`_PlanCard`, строка 108);
- «7 из 20» фото для AI в этом месяце, полоска и «Счётчик обнулится 1 ноября» (`_AiPhotos`, строка 160). Это фото группы по её тарифу. Когда они закончились, экран так и пишет и добавляет, что вводить данные вручную и сканировать штрихкоды можно как прежде;
- на Free — что даёт Premium (строка 79);
- честная строка, что оплаты в приложении пока нет (строка 102). Кнопок покупки и ссылок нет: этого не разрешают правила Google Play.

**Лимит AI.** Четыре запроса, где AI читает фото, сервер сначала сверяет с лимитами (4.23): проверка связи, скан паспорта, скан чипа и скан упаковки. Лимитов два: фото группы по её тарифу и, на Free, фото одного человека во всех его группах на Free вместе. Если фото не влезают, сервер отвечает 409 с типом `urn:collarbell:problem:ai-limit` и полями `scope` (`household` или `person`), `plan`, `limit`, `used`, `requested` и `resetsAt`:

```dart
final Map<String, Object?> extensions;            // api_exception.dart:73 все поля ответа, кроме стандартных
static AiLimit? of(Object error) {                 // :181 лимит из этих полей; какого-то нет — null
resetsAt: resets.toLocal(),                        // :204 момент обнуления — по часам телефона
int get left => used >= limit ? 0 : limit - used;  // :226 сколько фото ещё осталось
```

**Сначала тип, потом код ответа.** Те же запросы отвечают 409 без типа, когда AI на сервере не подключён. Поэтому лимит узнают по типу (`isAiLimit`), и проверяют его раньше, чем код 409:
- `errorMessageFor` — первой строкой, до разбора кодов (`shared/error_messages.dart:15`);
- скан упаковки и скан чипа: репозитории пропускают лимит дальше как есть и только потом превращают 409 в «AI не подключён» (`supplies_repository.dart:216`, `pets_repository.dart:130`);
- скан паспорта: лимит не прячет кнопки AI, как «AI выключили» (`scan_screen.dart:588`).

Текст ошибки собирает `aiLimitMessage` (`error_messages.dart:72`; выбор — строка 77):
- фото группы закончились — «В этом месяце AI прочитал 20 из 20 фото — это лимит тарифа Free. Счётчик обнулится 1 ноября.»;
- остались, но меньше, чем отправлено, — «Осталось 2 из 20 фото в этом месяце: выберите меньше.»;
- закончились фото человека — «Вы уже отправили AI 20 из 20 фото в этом месяце во всех своих группах на Free. Счётчик обнулится 1 ноября.» (и похожий текст, если осталось меньше, чем отправлено);
- сервер не прислал числа — «Лимит AI на этот месяц исчерпан.»

Все экраны, которые читают фото, показывают ошибки через `errorMessageFor`, поэтому текст везде правильный. Дальше они помогают по-разному:
- проверка связи (`ai_screen.dart:353`): текст без «Не работает.» (связь, может быть, в порядке) и кнопка «Посмотреть тариф» (`OpenPlanButton`, `billing/open_plan_button.dart:11`, компактная контурная кнопка);
- скан паспорта: «Повторить» не предлагается, потому что те же страницы опять не влезут (`scan_screen.dart:602`). Остаются «Сканировать заново» и кнопка тарифа (строка 1023);
- скан упаковки: тоже без «Повторить», с кнопкой тарифа и «Заполнить вручную» (`product_scan_screen.dart:244`);
- скан чипа: текст ложится на карточку номера, кнопке там места нет.

Лимит одного человека на экране «Тариф» не показывается: там только фото группы. Он виден лишь в ошибке.

**Слишком часто (429).** Те же четыре запроса принимаются не чаще 10 раз в минуту на человека. Ответ 429 — отдельный вид ошибки (`ApiErrorKind.tooManyRequests`, `api_exception.dart:259`), а `Retry-After` читается как число секунд (строка 351). Текст: «Слишком много запросов подряд. Попробуйте через 42 секунды.» или «…через минуту» (`error_messages.dart:35`).

**Визор** (5.20) получает ошибку лимита с её типом (`status=409 type=urn:collarbell:problem:ai-limit …`), а 429 — с именем `tooManyRequests`.

**Тесты:** `test/features/billing/household_plan_test.dart` (экран, «Ещё», экран группы, у другой группы свой тариф) и `test/features/billing/ai_limit_test.dart` (тексты лимита группы и человека и 429, лимит против «AI не подключён», кнопки на экранах).

### 5.22. Живые обновления: что изменили другие, видно сразу (`app/live_updates.dart`, `data/live/`)

Аня нажала «Покормили» на своём телефоне. У Бори открыт «Сегодня», и отметка появляется у него сразу, без «потянуть вниз». Для этого открытое приложение держит соединение с сервером (хаб `/hubs/household`, system-design 3.4). Данных сервер не присылает. Он только говорит: «в группе изменилось кормление». Телефон сам перечитывает экраны, которые это показывают.

**Три части:**
- `data/live/realtime_client.dart` — интерфейс `RealtimeClient`: «подключись», «что изменилось», «состояние», «закрой». Остальное приложение знает только его.
- `data/live/signalr_realtime_client.dart` — `SignalRRealtimeClient`, тот же интерфейс на пакете `signalr_netcore`.
- `app/live_updates.dart` — `LiveUpdates` решает, когда подключаться и что перечитывать. Провайдер `liveUpdatesProvider` связывает его с приложением.

**Пакет можно заменить.** Официального клиента SignalR для Dart нет. `signalr_netcore` 1.4.4 — самый распространённый, но обновляется редко. Поэтому он спрятан за интерфейсом:

```dart
abstract interface class RealtimeClient {                     // realtime_client.dart:101
  Future<void> connect(Uri url, Map<String, String> headers);  // :107 открыть; готово, когда сервер услышал группу
  Stream<LiveChange> get changes;                             // :112 что изменилось; поток кончается вместе с соединением
  RealtimeState get state;                                    // :115 закрыто, открывается или открыто
  Future<void> close();                                       // :119 закрыть
}
```

Если пакет подведёт, пишут другой класс с тем же интерфейсом (форк пакета или Server-Sent Events). Меняют одну строку: `realtimeClientFactoryProvider` (`live_updates.dart:499`). Экраны и `LiveUpdates` не меняются. Тесты подставляют туда подделку `FakeLiveServer` (`test/helpers/fakes.dart`).

**Один клиент — одно соединение.** Для каждого подключения создаётся новый клиент со свежими заголовками. Токен Firebase живёт час: со старыми заголовками через час сервер уже не пустит.

**Как открывается соединение** (`signalr_realtime_client.dart`):

```dart
transport: HttpTransportType.WebSockets,                     // signalr_realtime_client.dart:51 только WebSocket, как принимает сервер
skipNegotiation: true,                                       // :52 без предварительного запроса negotiate
headers: opening,                                            // :53 заголовки — на запросе, который открывает сокет
.withAutomaticReconnect(reconnectPolicy: _NeverReconnect())  // :61 самому пакету переподключаться нельзя
await hub.start();                                           // :67 открыть сокет
await hub.invoke(readyMethod);                               // :71 спросить Ready
```

- **Токен — в заголовке, а не в адресе.** На iOS и Android пакет передаёт заголовки в `WebSocket.connect` из dart:io. Адрес — `<apiBaseUrl>/hubs/household`, без параметров, поэтому токен не попадает в журналы сервера. Заголовки те же, что у запросов: вход (`Authorization: Bearer …` или dev-заголовки), `X-Household` и `X-Client`.
- **`_NeverReconnect` — строка неочевидная, но важная.** Пакет переподключается сам, даже когда его об этом не просили: ещё 4 попытки за 42 секунды, со старыми заголовками. И всё это время никто не узнаёт, что связь пропала. Политика «никогда» (`:126`) это выключает. О разрыве сразу узнаёт `LiveUpdates` и переподключается сам, со свежим токеном. Тест на настоящем WebSocket это проверяет: без этой строки он падает.
- **Ready.** Сервер проверяет, ваша ли это группа, уже после того как сокет открылся. Ответ на Ready приходит, когда соединение добавлено в группу. Только после него телефон считает себя на связи.
- **Отказ — не обычная ошибка.** Сервер закрывает соединение со словами «You aren't in this household.» (группа не ваша) или «Too many open connections.» (у человека уже 10 соединений) и просит не переподключаться. Обычно приложение к этому моменту уже спросило Ready: вместо ответа приходит закрытие, и вызов Ready падает. Пакет просьбу «не переподключаться» не передаёт. Поэтому отказ узнаётся по словам (`refusalReasons`, `:134`; `refusalIn`, `:143`) и становится `RealtimeRefused`.
- **Сообщение `Changed`** читает `liveChangeFrom` (`:156`): темы и `origin`. `origin` — это `X-Client` запроса, который сделал изменение. Сервер присылает его только соединениям того, кто сделал изменение, а остальным — `null`. Непонятное сообщение соединение не ломает: оно считается изменением «чего угодно».

**Когда телефон на связи** (`liveUpdatesProvider`, `live_updates.dart:507`). Провайдер держит запущенным приложение (`app.dart:53`), как и пуши. Он следит за четырьмя вещами и передаёт их в `LiveUpdates.update` (`live_updates.dart:181`):

```dart
user: user != null && user == synced ? user : null,  // live_updates.dart:536 вошёл, и синхронизация профиля закончилась
ref.listen(profileSyncProvider, …)                    // :552 первый запрос создаёт пользователя и группу на сервере
currentHouseholdProvider.select((h) => h?.id)          // :558 какая группа на экране
onHide: () => front(false),                           // :564 ушли с экрана: через 30 с отключиться
onShow: () => front(true),                            // :566 вернулись: подключиться, если уже отключились
```

- Соединение нужно, пока человек вошёл, синхронизация профиля закончилась и приложение на экране. Ушли с экрана ненадолго (камера, выбор фото, «Поделиться», окно разрешения) — соединение остаётся. После 30 секунд в фоне оно закрывается, дальше работают пуши.
- Другая группа на экране — старое соединение закрывается, новое открывается с её `X-Household`.
- Выход из аккаунта — соединение закрывается.

**Что делает `LiveUpdates`** (`live_updates.dart:70`). Это обычный класс, без экранов и без Riverpod. Чем перечитывать, ему даёт провайдер.

```dart
static const retryDelays = [Duration(seconds: 1), … 30];  // :81 паузы 1, 2, 5, 10, 30 с; последняя повторяется
static const connectTimeout = Duration(seconds: 15);      // :91 дольше подключения не ждём
static const steadyAfter = Duration(seconds: 30);         // :97 продержалось 30 с — паузы снова с одной секунды
static const collectFor = Duration(milliseconds: 300);    // :100 события за 300 мс — одним перечитыванием
static const pollEvery = Duration(seconds: 30);           // :103 без связи «Сегодня» — раз в 30 с
static const awayGrace = Duration(seconds: 30);           // :109 столько соединение ждёт, пока приложения нет на экране
```

- **Подключение** (`_connect`, `:247`). Новый клиент, заголовки входа спрашиваются заново (`:260`), к ним `X-Household` и `X-Client` (строки 261-262). Не открылось за 15 секунд — значит, не удалось (`:266`).
- **Не удалось или оборвалось** (`_failed`, `:300`). Новая попытка через 1, 2, 5, 10 и 30 секунд, дальше каждые 30 (`:306`). Паузы начинаются сначала, только если соединение продержалось 30 секунд (`:282`). Иначе соединение, которое всё время рвётся, перечитывало бы все экраны каждую секунду.
- **Отказ** (`_refused`, `:319`). Больше не пробует, пока на экране не окажется другая группа или приложение не вернётся после 30 секунд в фоне (короткая отлучка ничего не меняет). Сервер сказал «нет» — незачем стучать снова.
- **Свои изменения пропускаются** (`:352`). Каждый запрос приложения несёт `X-Client` — случайный id этого запуска (`liveClientId`, `app_session.dart:29`). Его добавляет перехватчик `LiveClientInterceptor` (`api_client.dart:295`; в цепочке — строка 74, перед копиями без связи). Сервер возвращает этот id в событии как `origin`, и только соединениям того, кто сделал изменение. Остальные телефоны получают `origin: null`, и приложение ничего не строит на чужих id. Свой экран после сохранения и так уже перечитан.
- **Чужие изменения копятся 300 мс** (`live_updates.dart:356`) и перечитываются за один раз. «Покормить всех» — это несколько событий подряд, а перечитывание одно.
- **После переподключения перечитываются экраны группы** (`:286`). Сервер событий не хранит: без этого всё, что изменилось без связи, пропало бы. Первое подключение после входа или смены группы ничего не перечитывает: экраны и так только что загрузились.
- **Без связи «Сегодня» перечитывается раз в 30 секунд** (`_schedulePoll`, `:366`). Так бывает, пока соединение нужно, но его нет: подключается, оборвалось или сервер отказал.
- **Ненадолго с экрана — соединение остаётся** (`update`, `:179`). Камера, выбор фото, «Поделиться» и окно разрешения уводят приложение с экрана на несколько секунд, а снимков в этом приложении много. Поэтому соединение закрывается не сразу, а через 30 секунд (`awayGrace`; таймер — строка 205). Вернулись раньше — ничего не переподключается и не перечитывается (`stayed`, строка 189). Отсутствовали дольше — соединение закрывается (`_gone`, `:229`), а после возвращения экраны перечитываются один раз. Пока таймер идёт, всё работает как на экране: изменения слышны и перечитываются.

**Не перечитывать дважды.** «Сегодня» (`TodayReload`, `today_reload.dart:23`, у «Сегодня» и «Главной») и роль (`home_shell.dart:49`) перечитываются сами, когда приложение возвращается из фона. Вернулись в пределах 30 секунд — `LiveUpdates` не перечитывает ничего: соединение не закрывалось. Вернулись позже — после переподключения `LiveUpdates` перечитывает всё, кроме этих двух (`backInApp`, `live_updates.dart:486`). Если же первая попытка не удалась и связь появилась позже, перечитывается всё: «Сегодня» могло отстать.

**Что перечитывает каждая тема** (`liveTopicProviders`, `live_updates.dart:406`; `readLiveTopics`, `:478`). Событие говорит, *что* изменилось, но не *у какого* питомца. Поэтому провайдер с параметром (`petProvider`, `carePlansProvider`…) сбрасывается целиком, у всех питомцев сразу.

| Тема | Что перечитывается |
|---|---|
| `pets` | список и карточка питомца, «Сегодня», визиты, запасы (корм считается по кормлениям питомцев), напоминания, проверка скана |
| `passport` | шапка паспорта, проверка скана |
| `care` | планы, записи, разделы паспорта V–X, «Сегодня», напоминания, проверка скана |
| `feeding` | расписания кормления, «Сегодня», напоминания. Запасы — нет: прогноз считается только по расписаниям, а изменённое расписание присылает ещё и `supplies` |
| `visits` | визиты, «Сегодня», напоминания и уход: визит состоялся — добавились записи, сдвинулись планы |
| `supplies` | запасы и история покупок, «Сегодня» («Купить»), напоминания, расписания кормления (там название корма) |
| `documents` | документы питомца |
| `imports` | сканы питомца, тариф и «Ещё → AI»: скан тратит фото месяца |
| `household` | экран группы, `/me` (роль, название, список групп), «Сегодня» и напоминания (часовой пояс группы) |
| `plan` | тариф и «Ещё → AI»: фото месяца, которые потратили скан чипа, скан упаковки или проверка связи AI |
| незнакомая | всё |

- `household` перечитывает `/me`. Это и есть проверка роли, как через `roleCheckProvider` (5.19). Если человека убрали из группы, его следующий запрос получит 403, и `HouseholdHeaderInterceptor` переведёт приложение в другую группу.
- **Сбросить провайдер почти ничего не стоит.** Riverpod сразу загружает заново только то, что смотрит экран на виду. go_router прячет невидимые вкладки под `TickerMode(enabled: false)`, а flutter_riverpod на это время ставит их подписки на паузу: сброшенное загрузится, когда вкладку откроют. «Сегодня» смотрят только `HomeScreen` и `TodayScreen`, поэтому на скрытой вкладке оно не ходит на сервер каждые 30 секунд (комментарий у `pollToday`, `live_updates.dart:520`).

**Журнал.** `debugPrint` пишет «Live updates: connected», «… no connection (…), again in 2 s», «… refused (…)». Заголовки и токены не пишутся никогда.

**Тесты:**
- `test/app/live_updates_test.dart` — `LiveUpdates` на поддельных часах (`fake_async`): свои изменения пропускаются, 300 мс, паузы 1-2-5-10-30 со свежим токеном, 15 секунд на подключение, разрыв, другая группа, выход, ненадолго с экрана и 30 секунд в фоне, скрыли во время подключения, отказ, «Сегодня» раз в 30 секунд. И то же в целом приложении (`pumpApp` с `FakeLiveServer`): подключение после синхронизации профиля, «Сегодня», новый питомец, роль, незнакомая тема, возврат из камеры, 30 секунд в фоне, другая группа, отказ.
- `test/data/live/signalr_realtime_client_test.dart` — чтение `Changed`, отказ по словам и настоящий WebSocket к маленькому поддельному хабу на этом же компьютере (в сеть ничего не уходит): заголовки и адрес, Ready, изменение, разрыв без самопереподключения, отказ после Ready (как его шлёт сервер) и сразу после рукопожатия, `LiveUpdates` после отказа больше не пробует, `close()`.
- `test/data/api/api_client_test.dart` — `X-Client` в каждом запросе.

### 5.23. Удаление аккаунта и выгрузка данных на телефоне

Аня больше не пользуется Collarbell и хочет удалить аккаунт. Google Play и App Store (у Apple это правило 5.1.1(v)) требуют, чтобы это можно было сделать прямо в приложении, а не только письмом. Перед удалением можно скачать всё своё одним ZIP-файлом. Обе кнопки — в «Ещё», в разделе «Ваши данные» (`more_screen.dart:192`): «Скачать мои данные» (строка 181) и красная «Удалить аккаунт» (строка 196). Что при этом делает сервер — в спецификации (`docs/mvp-spec.md`, «Удаление аккаунта и выгрузка данных»).

**Файлы** (`features/account/`):
- `account.dart` — что будет с группой (`HouseholdFate`: удалится, останется, перейдёт к новому владельцу), группа с её судьбой (`HouseholdOutcome`), всё вместе с «планом» (`DeletionPreview`, ниже) и скачанный файл (`ExportFile`).
- `account_repository.dart` — три запроса: что будет с группами (`GET /me/deletion`), удалить (`DELETE /me?plan=…`), скачать (`GET /me/export`).
- `delete_account_screen.dart` — экран «Удалить аккаунт»: что показать и когда спросить.
- `account_deletion.dart` — само удаление: идёт ли оно, чем кончилось. Живёт вне экрана (ниже — зачем).
- `data_export_sheet.dart` — лист «Скачать мои данные».
- `export_files.dart` — где лежит скачанный файл, как он уходит с телефона («Сохранить» или «Поделиться») и как удаляются его копии.
- `account_labels.dart` — тексты: что будет с группой, последний вопрос, ошибки, размер файла.
- `deleted_account.dart` — «аккаунта больше нет — выйти на этом телефоне». Одно место для двух случаев: удалили здесь и удалили на другом телефоне.
- `data/api/account_deleted.dart` — перехватчик, который слышит «аккаунт удалён».

#### «Удалить аккаунт»: по шагам

```text
ТЕЛЕФОН                                                         СЕРВЕР
«Ещё» → «Удалить аккаунт»
   │ экран открывается: GET /me/deletion ─────────────────────▶ что будет с каждой группой
   │ ◀──── «Мой дом»: удалится, 2 питомца · «Офис»: останется у остальных · … · план «a1b2c3»
   │ пароль (только Firebase) → «Удалить аккаунт»
   │ → «Удалить аккаунт? Удалится группа «Мой дом» со всем, что в ней есть…» → «Удалить аккаунт»
   │ 1. пароль ещё раз в Firebase → новый токен с новым временем входа
   │ 2. DELETE /me?plan=a1b2c3 ───────────────────────────────▶ пароль вводили не раньше 5 минут назад?
   │                                                             с группами всё ещё так, как в плане?
   │                                                             удаляет аккаунт, группы, вход Firebase
   │ ◀──── 204  (или 409 «группы изменились» — ничего не удалено)
   │ 3. выход на этом телефоне; сервер больше ни о чём не спрашиваем
   ▼
экран входа: «Ваш аккаунт удалён»
```

**1. Что будет с группами.** Экран спрашивает это у сервера (`deletionPreviewProvider`, `account_repository.dart:133`). Провайдер `autoDispose`: каждый раз экран открывается со свежим ответом. Пока он открыт, ответ перечитывается, когда в группе меняются люди или питомцы (живые обновления, 5.22: темы `pets` и `household`, `live_updates.dart:410` и `:458`). Копию без связи для него не хранят (`offline_cache.dart:228`): судьбу групп называет сервер сейчас, а не вчерашняя копия.

**2. Каждая группа — одной строкой** (`_OutcomeRow`, `delete_account_screen.dart:359`; тексты — `householdFateLines`, `account_labels.dart:14`):
- удалится — «Удалится вместе с 2 питомцами и всеми записями, фото и документами.» Если кроме вас там только помощники — ещё «Кроме вас, в ней только помощники — они потеряют к ней доступ.» Значок — красная корзина;
- останется — «Останется у остальных как есть.»;
- перейдёт — «Останется у остальных, владельцем станет Борис.»

Название — через `householdName` (5.19): первая группа, которую сервер назвал «Home», видна как «Мой дом». Ниже экран перечисляет, что удалится (аккаунт, телефоны, журнал действий за 7 дней, группы, где вы одни, вход) и что останется (в общих группах ваши записи без имени, а написанное в них — как есть; резервные копии ещё до 14 дней; фото, которые уже читал AI, обработаны по правилам Google). И предлагает «Сначала скачать мои данные».

Судьбу, которой приложение не знает (её добавит новая версия сервера), экран показывает как «удалится» (`account_repository.dart:100-103`): лучше предупредить об удалении, которого не будет, чем промолчать о настоящем.

**3. Пароль ещё раз — только с Firebase** (`delete_account_screen.dart:71`). Сервер удаляет аккаунт, только если пароль вводили не больше 5 минут назад: одного разблокированного телефона мало. Со входом разработчика поля нет: такой вход сервер всегда считает «только что».

**4. Последний вопрос** (`confirmDestructive`, `delete_account_screen.dart:89`) называет группы, которые удалятся, и говорит, что отменить это нельзя: «Удалятся группы «Мой дом» и «Дача» со всем, что в них есть. Отменить это нельзя.» Текст собирает `deleteAccountConfirmMessage` (`account_labels.dart:35`). Одно число («удалится 1 группа») не говорит, какая: Аня могла не долистать до строки, которая только что поменялась.

**5. Удаление** (`AccountDeletionNotifier.delete`, `account_deletion.dart:85`):

```dart
if (password != null) await auth.reauthenticate(password);  // account_deletion.dart:99 пароль ещё раз
await repository.deleteAccount(plan);                        // :100 DELETE /me?plan=…
if (await deleted.signOut(uid) || await deleted.signOut(uid)) return;  // :123 удалено: выйти (второй раз — если первый не вышел)
```

**Пароль в Firebase** (`reauthenticate`, `firebase_auth_repository.dart:57`):

```dart
await user.reauthenticateWithCredential(                         // firebase_auth_repository.dart:64 Firebase проверяет пароль
  EmailAuthProvider.credential(email: email, password: password),
);
await user.getIdToken(true);                                     // :69 новый токен, а не старый из кэша
```

Время ввода пароля сервер берёт из токена (`auth_time`). Firebase держит токен в кэше до часа, и в старом записано время входа. `getIdToken(true)` берёт новый — с только что введённым паролем. Ошибки становятся теми же `AuthFailure`, что и при входе (`failureForCode`, 5.5). У входа разработчика `reauthenticate` ничего не делает (`dev_auth_repository.dart:79`).

#### План: удаляется то, что Аня видела

Пока Аня вводит пароль, кто-то может вступить в «Мой дом» по старому приглашению. Тогда группа уже не удалится, а перейдёт к новичку — не то, на что Аня соглашалась. Поэтому вместе с судьбами сервер присылает их «отпечаток» — план (`DeletionPreview`, `account.dart:56`). Удаление отправляет план обратно (`deleteMe(plan: plan)`, `account_repository.dart:65`), и сервер удаляет, только если с группами всё ещё так, как в плане. Иначе отвечает 409 `deletion-plan-changed` и не удаляет ничего.

Но и на телефоне план может смениться сам: живое обновление перечитало группы, пока Аня вводила пароль внизу экрана. Строка, которая поменялась, может быть не видна, а последний вопрос — про новые судьбы. Поэтому экран помнит план, который Аня **видела** (`_seen`, `delete_account_screen.dart:50`):
- первые группы, которые показал экран (строка 160);
- группы, которые она сама перечитала, потянув вниз (строка 182);
- группы, показанные вместе с «В ваших группах что-то изменилось…» (строка 160).

При нажатии «Удалить аккаунт» план на экране сравнивается с увиденным (`delete_account_screen.dart:88`). Не совпал — ничего не спрашивается и не отправляется. Наверху, под предупреждением, появляется «В ваших группах что-то изменилось. Посмотрите ещё раз, что с ними будет, и удалите снова.» (строка 233), экран прокручивается к группам (`_showChanged`, строка 108). Теперь они увидены, и следующее нажатие идёт дальше.

То же — если группы изменились, пока был открыт последний вопрос (`delete_account_screen.dart:99`): ответ «Удалить аккаунт» был про старые.

Если сервер всё же ответил 409, экран пишет то же самое наверху, перечитывает группы (`account_deletion.dart:110`) и прокручивает к ним (`_heard`, `delete_account_screen.dart:142`). Аня остаётся на экране и в аккаунте. Пароль остаётся в поле: следующее нажатие само проверит его снова.

Пока группы перечитываются, кнопка ждёт (`reloading`, `delete_account_screen.dart:193` и `:345`; кнопка «Готово» на клавиатуре — строка 67).

#### Если не получилось

| Что случилось | Что видит Аня | Удалено? |
|---|---|---|
| Неверный пароль | «Неверный пароль. Попробуйте ещё раз.», поле пустое | Нет: до сервера дело не дошло |
| Сервер просит пароль ещё раз (403 `recent-sign-in-required`) | «Для безопасности введите пароль ещё раз.», поле пустое | Нет |
| Группы изменились (409) | «В ваших группах что-то изменилось…» наверху, группы новые | Нет |
| Нет связи, сервер не ответил | «Не удаётся связаться с сервером…» | Неизвестно — см. ниже |

Тексты собирает `deleteAccountErrorMessage` (`account_labels.dart:58`). При неверном пароле и «пароль ещё раз» поле очищается (`delete_account_screen.dart:137`), а «Введите пароль» под ним не появляется до следующего нажатия: иначе под пустым полем сразу стояли бы две ошибки.

**Ответ потерялся.** Бывает так: сервер удалил аккаунт, а ответ до телефона не дошёл — связь оборвалась. Вместе с аккаунтом сервер удалил и вход в Firebase, поэтому повторная проверка пароля сказала бы «Неверный пароль», хотя пароль верный. Поэтому после ошибки, при которой запрос мог дойти (нет связи, нет ответа, ошибка сервера, `_mayHaveGoneThrough`, `account_deletion.dart:133`), следующее нажатие **сначала** спрашивает сервер, что будет с группами (`delete_account_screen.dart:81`; `recheck`, `account_deletion.dart:61`):
- аккаунта уже нет — сервер отвечает «аккаунт удалён», и приложение выходит (`account_deletion.dart:72`);
- аккаунт цел — ничего не удалялось, удаление идёт как обычно;
- связи всё ещё нет — так и пишется.

Повтор безопасен и на сервере: два `DELETE` в один и тот же момент (двойное нажатие) удаляют один раз, оба получают 204. А запрос после уже законченного удаления получает «аккаунт удалён» — и приложение тоже выходит.

#### Удаление живёт вне экрана

Экран можно покинуть, пока идёт удаление:
- **«Назад» и повторное нажатие на вкладку «Ещё»** — нет. Экран обёрнут в `LeaveGuard` с `busy` (`delete_account_screen.dart:162`, `:166`), как формы во время сохранения (5.10). Повторное нажатие на вкладку теперь тоже спрашивает «стражей» (`LeaveGuard.busyInView`, `leave_guard.dart:54`; `home_shell.dart:142`) — это защищает и формы.
- **Переход в другую группу** (нажали пуш другой группы) — может. Тогда оболочка строит все вкладки заново (5.19), и экран создаётся новым.

Поэтому идёт ли удаление и чем оно кончилось, хранит не экран, а `accountDeletionProvider` (`account_deletion.dart:41`; состояние — `AccountDeletionState`, строка 21). Пока попытка идёт, провайдер держится сам (`ref.keepAlive()`, строки 64 и 94), даже если экрана нет. Новый экран видит, что удаление ещё идёт (кнопка крутится), и покажет, чем оно кончилось. Закрыли экран, и удаление закончилось — провайдер забывается: в следующий раз экран открывается чистым.

#### Выход после удаления

Обычный «Выйти» (`signOutOfThisPhone`, `push_registration.dart:155`) сначала просит сервер забыть телефон (строка 162), потом делает то, что нужно на самом телефоне, — `localSignOutProvider` (строка 179):

```dart
await platform.forgetToken()...;   // push_registration.dart:189 телефон забывает адрес для пушей
await auth.signOut();              // :195 выход из Firebase (или из входа разработчика)
await offlineCopies.clear()...;    // :203 копии без связи стираются (5.18)
await exports.clearAll()...;       // :209 и копии выгрузки (ниже)
```

Каждый шаг в своём `try`: если один не удался (на iPhone `signOut` может упасть, пока заблокирована связка ключей), остальные всё равно делаются, и функция никогда не падает.

После удаления её вызывает `DeletedAccountNotifier.signOut` — без первой части: сервер уже забыл аккаунт и его телефоны и ответил бы отказом.

```dart
if (uid == _uid) return _signingOut ?? Future.value(true);          // deleted_account.dart:49 уже выходим: этот ответ присоединяется
if (current != null && current != uid) return Future.value(false);  // :51 вошёл кто-то другой: не трогать
state = true;                                                       // :53 экран входа скажет «Ваш аккаунт удалён»
await signOut();                                                    // :61 то же, что при обычном выходе
if (auth.currentUser?.uid == uid) {                                 // :62 не вышли — попытка забывается,
await preferences.remove(CurrentHouseholdNotifier.keyFor(uid));     // :71 вышли — забыть и группу этого аккаунта (5.19)
```

- **Не вышло с первого раза.** Попытка забывается (`deleted_account.dart:62`): следующий ответ «аккаунт удалён» попробует снова. Экран удаления сам пробует второй раз сразу (`account_deletion.dart:123`). Не вышло и со второго — на экране «Аккаунт удалён, но выйти из него на этом телефоне не получилось. Приложение выйдет при следующем запуске.» (строка 125). Кнопка больше не крутится, «Назад» работает. При следующем запуске сервер ответит «аккаунт удалён», и приложение выйдет.
- **Не вошёл никто** (`deleted_account.dart:51`) — выход всё равно делается. Так бывает, когда Firebase сам вышел из удалённого аккаунта (ниже): уборка и сообщение нужны и тогда.

Остальное останавливается само, как при обычном выходе: живые обновления закрывают соединение (5.22), визор выбрасывает неотправленное (5.20). Следующий человек на этом телефоне начинает с чистого листа. Экран входа пишет «Ваш аккаунт удалён» (`sign_in_screen.dart:200` и `:226`), пока кто-нибудь не войдёт (`deleted_account.dart:29`).

#### Аккаунт удалили на другом телефоне

Токен Firebase живёт до часа. Поэтому второй телефон того же человека ещё какое-то время шлёт запросы со старым токеном, и сервер отвечает на каждый `401` с типом `account-deleted`. Слушает это один перехватчик (`data/api/account_deleted.dart`):

```dart
options.extra[_userKey] = user();      // account_deleted.dart:31 чей это запрос: запоминается при отправке
error.error is SignInAccountGone ||    // :47 Firebase не знает аккаунт (ниже)
        ProblemTypes.accountDeleted);  // :50 или сервер: 401 account-deleted; обычный 401 — не повод выходить
if (uid is String) onAccountDeleted(uid);  // :53 сказать, чей аккаунт удалён
```

В цепочке он стоит перед заголовками входа (`api_client.dart:75`; заголовки — строка 76). С выходом его связывает `api_providers.dart:28-30`.

**Через час.** Когда старый токен кончается, Firebase пробует его обновить и отвечает `user-not-found`: такого аккаунта нет. Раньше экраны писали «что-то пошло не так», а Firebase выходил сам — без уборки и без сообщения. Теперь `authHeaders` превращает это в `SignInAccountGone` (`firebase_auth_repository.dart:91`; класс — `api_exception.dart:292`), а для приложения это то же, что ответ сервера «аккаунт удалён» (`api_exception.dart:351`). Только этот код: `user-token-expired` значит, что пароль сменили на другом устройстве, а не что аккаунта нет.

**Почему выход один и не выкидывает другого человека.** На экране сразу много запросов: «Сегодня», питомцы, `/me`, тариф. Все получат 401, но выход будет один:
- пока выход идёт, следующие ответы присоединяются к нему (`deleted_account.dart:49`);
- каждый запрос помнит, чей он (`account_deleted.dart:31`). Поздний ответ на запрос Ани не выкинет Борю, если тот уже вошёл на этом телефоне (`deleted_account.dart:51`). Потому перехватчик и стоит перед заголовками входа: если аккаунт сменился, пока готовился запрос, запрос сочтут запросом прежнего аккаунта, но никогда — нового.

Если на экране успела появиться ошибка такого запроса, она тоже говорит «Ваш аккаунт удалён», а не «Сеанс истёк» (`error_messages.dart:21-23`).

#### «Скачать мои данные»: по шагам

```text
ТЕЛЕФОН                                                         СЕРВЕР
«Ещё» → «Скачать мои данные» (или «Сначала скачать мои данные» на экране удаления)
   │ лист снизу; старые копии выгрузки удаляются, папка во временных файлах пустая
   │ GET /me/export ─────────────────────────────────────────▶ собирает ZIP и сразу отдаёт кусками
   │ ◀──── кусок, кусок, кусок… (размер заранее не знает никто)
   │ «Скачано: 12,3 МБ», полоска бежит, «Отмена»
   ▼
«Готово: 24,5 МБ» → «Сохранить» (человек выбирает место) или «Поделиться»
лист закрыли — как угодно — загрузка останавливается, скачанный файл удаляется
```

**Не через сгенерированный клиент.** Сгенерированный `exportMe` читает ответ как текст, а ZIP — не текст. Поэтому файл скачивает `ApiClient.download` (`api_client.dart:174`) через `dio.download`. Это тот же `Dio` с теми же перехватчиками (вход, группа, визор), но ответ пишется в файл по кусочкам и целиком в памяти не лежит. Между кусками разрешено ждать минуту (`downloadReceiveTimeout`, строка 166): сервер упаковывает очередное фото прямо во время отправки.

**Имя файла** — то, что предложил сервер (`Content-Disposition`: `collarbell-export-2026-10-06.zip`), если в нём только буквы, цифры, точки и дефисы (`exportFileName`, `account_repository.dart:114`; проверка — строка 119). Иначе — такое же имя с сегодняшней датой. Так чужое имя не выведет файл из его папки.

**Сколько скачано.** Сервер заранее не знает размер архива, поэтому процентов нет: полоска просто бежит, а текст говорит, сколько уже пришло (`data_export_sheet.dart:184`). Меньше мегабайта — в килобайтах («Готово: 5 КБ», а не «0,0 МБ»), больше — в мегабайтах с одним знаком (`fileSizeLabel`, `account_labels.dart:95`).

**Отмена и уборка.** Как бы лист ни закрылся — «Отмена», «Закрыть», «Назад» или смахиванием вниз, — Flutter вызывает `dispose` (`data_export_sheet.dart:58`):

```dart
_cancel.cancel();      // data_export_sheet.dart:60 загрузка останавливается, dio стирает недокачанный файл
_files.clear()...      // :62 папка со скачанным файлом удаляется
```

Но копию, которую сделал «Поделиться», при закрытии листа не трогают: другое приложение может ещё её читать.

**Сохранить или поделиться** (`export_files.dart`):
- «Сохранить» — системное окно «Сохранить как» (Загрузки, Файлы, Диск) из пакета `file_picker` (`export_files.dart:64`). Ему нужен весь файл в памяти: на Android он целиком уходит одним массивом в Java, и телефону с малой памятью его может не хватить. Поэтому кнопка есть, только если файл не больше 25 МБ (`exportSaveLimit`, `export_files.dart:15`). Больше — только «Поделиться» и подсказка «сохраните его через „Поделиться“» (`data_export_sheet.dart:206`).
- «Поделиться» — пакет `share_plus` (`export_files.dart:83`), как код приглашения в группу (5.19). На Android он сначала копирует весь ZIP в свою папку в кэше — нужно свободное место. Не получилось — лист пишет «Не удалось поделиться файлом. Проверьте, хватает ли места на телефоне, и попробуйте снова.» (`data_export_sheet.dart:267`): для большого файла это единственный выход, молчать нельзя.

**Копии выгрузки.** Скачанный ZIP — это все данные Ани, поэтому его копии не оставляются надолго. `clearAll` (`export_files.dart:94`) удаляет нашу папку и копии с именем `collarbell-export-*.zip`, которые оставили «Поделиться» (Android: `<кэш>/share_plus/`) и «Сохранить» (iPhone: `file_picker` пишет копию во временную папку, строка 100; на iPhone это ещё не проверено — приложение для iOS пока не собирается). Это делается, когда начинается новая выгрузка (`freshFolder`, строка 57) и при любом выходе из аккаунта (`push_registration.dart:209`).

Тесты подменяют `ExportFiles` (`exportFilesProvider`) и не трогают ни файлы, ни системные окна. Уборку копий проверяет отдельный тест на настоящих файлах.

**Ошибки** (`_failed`, `data_export_sheet.dart:274`; тексты — `dataExportErrorMessage`, `account_labels.dart:101`):
- **Слишком часто.** Сервер даёт 5 выгрузок в час на человека, дальше отвечает 429 с `Retry-After` в секундах. Телефон переводит секунды в минуты с округлением вверх (`account_labels.dart:109`): «Вы уже несколько раз скачивали данные за этот час. Попробуйте через 12 минут.» Кнопки «Повторить» нет (`data_export_sheet.dart:282`): сейчас сервер откажет снова.
- **Нет связи** — обычный текст и «Повторить». Связь, оборвавшаяся посреди загрузки, — тоже «нет связи», а не «что-то пошло не так» (`api_client.dart:196`).
- **Аккаунт удалён** — выход, как выше. Ответ загрузки перехватчик видит ещё непрочитанным (он должен был стать файлом), поэтому `ApiClient.download` проверяет его ещё раз, когда dio его прочитал (`api_client.dart:193`).

Копию без связи для выгрузки не хранят (`offline_cache.dart:227`): это файл, и каждый раз новый.

**Тесты:**
- `test/features/account/delete_account_test.dart` — экран: что будет с каждой группой, по-русски на маленьком телефоне; с Firebase без пароля ничего не происходит; пароль → вопрос с названиями групп → удалено с планом показанного → экран входа «Ваш аккаунт удалён», адрес пушей забыт, сервер не спрашивали, группа на телефоне забыта; 409 — ничего не удалено, группы новые, сообщение, пароль остался; группы сменились сами до нажатия (внизу маленького экрана) — первое нажатие ничего не отправляет и показывает их, второе удаляет; группы сменились, пока был открыт вопрос; ответ потерялся — следующее нажатие спрашивает сервер и выходит, а не пишет «Неверный пароль»; ответа нет, но ничего не удалено — следующее нажатие проверяет и удаляет; пока идёт удаление, «Назад» и вкладка «Ещё» не уводят с экрана, а переход в другую группу строит его заново — он всё равно ждёт и показывает ответ; выход после удаления не вышел один раз — пробует снова, два раза — сообщение и работающий «Назад»; неверный пароль, «пароль ещё раз», нет связи; вход разработчика; «Ещё» → экран и обратно; текст вопроса для одной, двух и трёх групп.
- `test/features/account/data_export_test.dart` — лист: «Скачано: 2.5 MB», «Сохранить» и «Поделиться», файл удаляется при закрытии; «Отмена»; 429; нет связи и «Повторить»; файл больше 25 МБ — только «Поделиться»; «Поделиться» не получилось — сообщение; маленький файл в килобайтах; «Сохранить» отменили или не получилось; по-русски; лист с экрана удаления; минуты из `Retry-After`; копии выгрузки на настоящих файлах (закрытие листа не трогает копию «Поделиться», новая выгрузка и выход удаляют все копии и ничего больше).
- `test/features/account/account_repository_test.dart` — запросы к поддельному серверу: группы и план, `DELETE /me?plan=…`, отказы «пароль ещё раз» и «группы изменились», выгрузка кусками с именем от сервера, 429, «аккаунт удалён» во время выгрузки, оборванная связь, имя файла.
- `test/features/account/deleted_account_test.dart` — «аккаунт удалён» сразу на нескольких запросах: выход один, всё убрано (и копии выгрузки); выход не удался — следующий ответ пробует снова; Firebase не может обновить вход (`user-not-found`) — то же, что ответ сервера; Firebase вышел сам раньше ответа — уборка и сообщение всё равно; поздний ответ не выкидывает следующего человека; обычный 401 никого не выкидывает; после входа сообщение пропадает; обычный «Выйти» тоже удаляет копии выгрузки; экран входа в целом приложении.
- `test/data/api/offline_cache_test.dart` — выгрузку и «что будет с группами» не копируют, `/me` копируют.

Тестами не проверить, только на телефоне: системные окна «Сохранить» и «Поделиться», удаление с настоящим паролем Firebase и уборку копии `file_picker` на iPhone.

### 5.24. Вес на телефоне (`features/weight/`)

**Откуда данные.** Один запрос `GET /pets/{id}/weights` отдаёт весь журнал питомца: взвешивания и вес из осмотров (4.26). Его держит один провайдер:

```dart
final weightLogProvider = FutureProvider.autoDispose   // weight_repository.dart:131 журнал одного питомца
    .family<List<WeightEntry>, String>((ref, petId) async {
return [for (final weight in weights) weightEntryFromDto(weight)]  // :43
  ..sort(newestFirst);                                  // :44 новые сверху, даже если сервер пришлёт иначе
```

Этот же провайдер показывает последний вес в «Обзоре» (`pet_overview_tab.dart:216`). Пока журнал не пришёл или если последнее чтение не удалось, строки «Вес» в «Обзоре» просто нет: почему, скажет вкладка «Вес». После неудачи у провайдера остаётся старый ответ, но показывать его нельзя (`:217`): там не хватало бы только что добавленного взвешивания, и «последним» оказался бы старый вес.

**Модель** (`weight.dart`). `WeightEntry` — одна строка журнала с источником `source`: взвешивание, осмотр или неизвестный (от сервера новее приложения, `:24`). Неизвестное приложение показывает, но не открывает. Взвешивание с незнакомой шкалой упитанности открывается только для просмотра (`hasUnknownValues`, `:98`): сохранение затёрло бы то, чего приложение не понимает.

Разница между весами считается в целых граммах (`grams`, `:102`, и `changeAt`, `:166`). В дробных числах компьютера 4,3 − 4,1 — это 0,19999… кг, и на экране вышло бы «+0,199».

**Вкладка «Вес»** (`weight_tab.dart`) сверху вниз:
- **«Последний вес»** (`_Latest`, `:205`): число крупно, дата, «+0,2 кг с 12 сент.» и оценка упитанности, если её ставили. Стрелка изменения серая: рост сам по себе ни хорош, ни плох, котёнок должен набирать.
- **«Динамика»** (`_trend`, `:160`): кнопки периода и график. Кнопки появляются, только когда журнал длиннее трёх месяцев. Если журнал длиннее года и за последний год есть хотя бы два веса, график открывается на последнем годе, иначе на всём журнале (`weightPeriodsFor` и `defaultWeightPeriod`, `weight.dart:191`, `:202`). Когда в периоде меньше двух весов, вместо графика одна строка-подсказка.
- **«История»**: все веса, новые сверху. У каждой строки значок источника, изменение от предыдущего веса, оценка и заметка. Нажатие (`_onTap`, `:46`) открывает окно взвешивания (только тем, кто может менять, 5.19) или запись осмотра, откуда пришёл вес ветеринара.

Пустой журнал объясняет, зачем взвешивать (раз в месяц, котят и щенков — раз в 1–2 недели) и даёт кнопку «Добавить вес».

**График** (`widgets/weight_chart.dart`) нарисован своим `CustomPainter`, без пакета. По горизонтали дни, по вертикали граммы, линия идёт через все веса:
- взвешивание — точка, вес ветеринара — пустой ромб. Их различает форма, а не цвет, поэтому разница видна и тем, кто плохо различает цвета;
- если точки сливаются (меньше 16 px друг от друга), точку оставляет только последнее взвешивание, а ромбы ветеринара видны всегда (`dense`, `:277`);
- все веса одинаковые — линия посередине (`flat`, `:212`), без деления на ноль;
- слева самый лёгкий и самый тяжёлый вес, внизу первая и последняя дата. Полоса дат растёт вместе с размером шрифта телефона, и подписи не обрезаются (`:59-65`). Подпись «точка — взвешивание, ромб — осмотр» на узком телефоне с крупным шрифтом переносится на новую строку, а не вылезает за край;
- экранный диктор вместо рисунка слышит одну фразу (`Semantics`, `:70`): «График веса с 5 мая по 12 сент.: в начале 4,1 кг, в конце 4,4 кг, минимум 4,1 кг, максимум 4,4 кг». Каждое значение он прочитает в истории ниже.

**Окно взвешивания** (`weighing_sheet.dart`) — нижняя панель, как «Купили» в запасах (5.17):
- дата (сегодня), вес в килограммах с запятой или точкой, до грамма. Проверка смотрит на сам текст (`weightTextProblem`, `weight_labels.dart:85`): «1e2» и «NaN» не вес, хотя `double.tryParse` их понимает, а «4,» и «4,250» — вес (запятая в конце и нули в конце ничего не добавляют);
- оценка упитанности спрятана под кнопкой «Добавить оценку упитанности». Шкала 1–9 или 1–5, рядом подсказка, какая оценка идеальна. Смена шкалы стирает оценку: 4 из 5 и 4 из 9 — разные вещи;
- **повтор безопасен:** `_requestId` (`:59`) один на всё окно, поэтому повторная попытка после потерянного ответа не добавит второе взвешивание (4.26). Но сервер на повтор отвечает тем взвешиванием, которое сохранила первая попытка. Если человек между попытками исправил вес или дату, окно сравнивает ответ с тем, что отправило (`_holds`, `:247`), и при разнице тут же меняет взвешивание (`:205`). Иначе исправление тихо пропало бы;
- после сохранения или удаления журнал перечитывается (`refreshWeight`, `:211`), и после ошибки тоже: сохранение могло дойти, а ответ потеряться;
- взвешивание или питомца удалили на другом телефоне — окно говорит об этом и закрывается (`:217`);
- дата рождения проверяет только новую дату (`:143`), как и сервер. Иначе в старом взвешивании, сделанном до того, как питомцу указали дату рождения, нельзя было бы даже поправить заметку;
- ошибки показываются в самом окне, а не всплывающей строкой внизу: та закрыла бы кнопку «Сохранить»;
- если что-то введено, закрытие спрашивает «Уйти без сохранения?» (`LeaveGuard`, 5.18), а смахнуть окно вниз нельзя.

**Чтобы журнал не устаревал:**
- запись осмотра поменялась (форма записи, «Сделано», скан, визит состоялся) — `refreshCare` перечитывает и журнал (`care_refresh.dart:26`): вес ветеринара живёт в записи;
- живые обновления (5.22): тема `weight` перечитывает журнал (`live_updates.dart:430`). Он же стоит в списке ухода (`:387`), поэтому изменения `care` и `visits` с других телефонов тоже обновляют вкладку.

**AI-скан** (5.15). У черновика осмотра есть поле «Вес, кг» (`scan_editors.dart:375`), до 10 г, как его хранит запись. Под полем — сомнение AI, если вес вне 0–200 кг. При сохранении вес уходит только у осмотра (`scan_review.dart:756`): поменяли вид записи на прививку — вес не сохранится.

### 5.25. Быстрый ввод текстом на телефоне (`features/ai/`)

Заметка — это скан без фото (4.27), поэтому на телефоне у неё нет отдельных экранов. Тот же экран скана (`scan_screen.dart`) открывается в режиме заметки, а дальше всё общее: ожидание, проверка черновика, сохранение, «Повторить».

**Где начинается.** На вкладке «Здоровье» рядом с кнопкой скана есть «Записать словами» (`openNote`, `widgets/scan_entry.dart:36`). Как и скан, она видна только тем, кто может менять (5.19), и только когда AI подключён. Ждущие и неудачные заметки — тоже на «Здоровье» (`NoteEntry`, `:116`), сканы — на «Паспорте». У каждого списка свой запрос: `?notes=true` и `?notes=false` (`ai_repository.dart:406`, `:415`). Двадцать новых заметок не спрячут ждущий скан.

**Экран заметки** (`scan_screen.dart`):
- поле до 1000 символов. Счётчик считает так же, как проверка и сервер: эмодзи — за два (`CbTextField.countedLength`);
- проверка до отправки (`_noteProblem`, `:496`): нужна хоть одна буква или цифра (`noteHasWords`, `ai.dart:530`, то же правило, что на сервере);
- **тот же текст — тот же `requestId`** (`_readNote`, `:511`). Каждый отправленный текст запоминается вместе со своим запросом (`_noteStarts.putIfAbsent`, `:522`). Если ответ потерялся, человек попробовал другой текст и вернулся к первому, сервер узнает первый запрос и не прочитает заметку дважды;
- **«Повторить»** у неудачной заметки (своей или чужой) отправляет `retryOf` с её id (`:433`). Сервер убирает неудачную и сохраняет день, когда её написали: «вчера» не съедет, даже если повторили назавтра (4.27);
- **уйти** можно сразу, кроме двух случаев (`LeaveGuard`, `:666`): идёт отправка или введённый текст ещё не на сервере (`_noteAtRisk`, `:487`). Тогда — «Уйти без сохранения?». Поэтому на iPhone «назад» жестом работает, когда терять нечего;
- лимит 30 заметок в сутки: сервер говорит число в ответе 429, приложение показывает его в своём сообщении (30 — только запасное).

**Проверка черновика** (`scan_review_screen.dart`). Вместо фото — сама заметка в кавычках и когда её написали. Галочки «сохранить фото» нет. Новый раздел «Взвешивания» (`:622`) — для заметок и для сканов: вес без осмотра (например, из счёта за прививку) станет взвешиванием журнала (5.24). У каждого веса есть галочка, предупреждения и редактор с правилами взвешивания: до грамма, не в будущем, не раньше точной даты рождения. Ошибки сервера `weights[i].*` возвращаются к своему весу.

**Уйти с проверки** — тоже с вопросом, если что-то поменяли, в том числе повторным нажатием на вкладку. Это общее изменение `shared/widgets/leave_guard.dart`: форма, закрытая другим экраном той же вкладки, тоже больше не пропадает молча.

**«Убрать»** неудачную заметку — с вопросом: её текст удаляется навсегда (`scan_entry.dart:278`).

### 5.26. Веб-приложение для владельцев (`web/`, React)

Это то же приложение, что на телефоне, только для большого экрана: те же аккаунты, группы и API. Адрес — `/app/` (`https://collarbell.example.com/app/`), лендинг ссылается на него. Что умеет — подробно в `web/README.md`. Здесь — как оно устроено, в сравнении с телефоном.

**Набор инструментов** — тот же, что у админки (4.22): React 19, Vite, TypeScript, Vitest. Своего добавлено три пакета:
- **React Query** держит ответы сервера в памяти, перечитывает их после изменений и когда вкладка снова на экране. Это делает то же, что провайдеры Riverpod на телефоне (5.2);
- **openapi-fetch** с типами, которые `npm run generate-api` строит из `contracts/openapi.json`. Как и с клиентом для телефона (5.6), CI проверяет, что типы не отстали от контракта: поменяли сервер — запустите генерацию;
- **@microsoft/signalr** — живые обновления (ниже). Он загружается отдельным файлом, только когда нужен.

**Запросы** (`src/api/client.ts`). Каждый запрос несёт три заголовка (`client.ts:144` и рядом):
- `Authorization` — токен Firebase, как у телефона;
- `X-Household` — группа на экране. Формы «привязаны» к группе, в которой открылись: если человек переключил группу, пока форма сохранялась, сохранение уйдёт в прежнюю группу, а не в новую;
- `X-Client` — случайный id этой вкладки браузера. По нему вкладка узнаёт в живых обновлениях своё же изменение и не перечитывает его.

Ответы хранятся под ключами с аккаунтом и группой (`src/api/keys.ts`). Поэтому другой человек, вошедший в этом браузере, никогда не увидит чужие данные из памяти.

**Вход** (`src/session.tsx`, `src/auth/`). Почта и пароль через Firebase, как на телефоне. Регистрации в вебе нет: аккаунт заводят в приложении, страница входа так и говорит. У каждого входа свой номер (`epoch`, `session.tsx:115`): ответ 401 на запрос, начатый ещё при прошлом входе, не выкидывает из нового. Язык и часовой пояс веб на сервер не отправляет, чтобы не спорить с телефоном.

**Живые обновления** (`src/live/`, как на телефоне — 5.22). Отличие одно: WebSocket в браузере не умеет передавать заголовки. Поэтому перед каждой попыткой подключения веб обычным запросом берёт одноразовый билет (`live.ts:180`; на сервере — `Infrastructure/Auth/LiveTickets.cs`, system-design 3.4) и подключается с ним в адресе. Билет работает один раз и одну минуту, поэтому в журнале сервера от него нет вреда. Темы перечитывают свои ответы (`topicKeys`, `topics.ts:27`). В боковом меню видно, на связи ли страница. Пока связи нет, «Сегодня» перечитывается раз в 30 секунд.

**«Уйти без сохранения?»** (`src/components/LeaveGuard.tsx`). Одна защита на всё приложение (`LeaveGuardProvider`, `:52`). Формы, окна и загрузки файлов регистрируются в ней (`useLeaveGuard`, `:107`). Она же спрашивает при закрытии вкладки (`beforeunload`, `:125`). Пока что-то сохраняется или загружается, переход ждёт, а не теряет данные.

**Повторы после потерянного ответа** — как на телефоне: у каждой новой записи свой `requestId`, одинаковый у всех повторов. Если человек между попытками что-то исправил, после ответа сервера веб досылает исправление (`PUT`). Новый документ `requestId` не имеет, поэтому перед повтором веб ищет документ, в котором уже есть загруженные файлы.

**Адреса** (`src/routes.tsx:98`). С 2026-10-14 веб, как телефон, открывается на «Главной»: `/app/` — «Главная», «Сегодня» переехало на `/app/today`, знакомство с приложением — `/app/welcome`. В боковом меню «Главная» первая (`components/Layout.tsx:161`). У её пункта стоит `end`: все адреса начинаются с `/`, и без него «Главная» светилась бы на любой странице. Логотип, страница «Такой страницы нет» и «Ваша роль не позволяет» ведут на «Главную», а после входа по коду приглашения открывается «Главная» новой группы.

**«Главная»** (`src/pages/home/HomePage.tsx`). Своего запроса у неё нет: она берёт те же `useToday` и `usePets`, что «Сегодня» и «Питомцы». Поэтому и обновляется так же: живые обновления, раз в 30 секунд без связи, при возвращении во вкладку.
- Сверху дата и приветствие по часам компьютера (`greeting`, строка 35), дальше питомцы в ряд (`PetsRow`, строка 115).
- «Сейчас важно» (`RightNow`, строка 175). Ближайшее кормление рисует тот же `FeedingSection`, что «Сегодня», только с одним временем (`only`, строка 215; в самом `FeedingSection.tsx:126`). Когда последнего питомца этого времени отметили, его строка исчезает; чтобы фокус клавиатуры не упал в начало страницы, он переходит на «Покормили» следующего времени (`FeedingSection.tsx:134`). Поэтому «Покормили», «Покормить всех» и «кто-то успел раньше» — один и тот же код. Какое время ближайшее, решает `nextFeedingTime`:

```ts
export function nextFeedingTime(feedings) {            // lib/feeding.ts:78
  for (const [time, items] of feedingSlots(feedings)) { // времена дня по порядку: 08:00, 13:00, 19:00
    if (items.some((item) => !item.mark)) return time;  // первое, где кто-то ещё без отметки
  }
  return null;                                          // всё отмечено — кормления на «Главной» нет
}
```

- Просроченное и скорое — одна строка с красной и жёлтой метками, она ведёт на «Сегодня». Визит — сначала прошедший, который ждёт «Визит состоялся», иначе ближайший (`nextVisit`, строка 43). «Купить: N» ведёт в «Запасы». Если ничего нет — «На сегодня всё сделано», если у питомцев ничего не настроено — карточки первых шагов.
- «Быстрые действия» (`QuickActions`, строка 296) — не для помощников. Действию нужен питомец: один — карточка сразу ведёт к его форме, несколько — окно «Какой питомец?» (`usePetChoice`, `pages/home/PetPicker.tsx:23`). «Взвесить» открывает окно взвешивания прямо на «Главной». Телефонное «Сканировать покупку» здесь называется «Добавить в запасы»: камеры у веба нет, штрихкод вводят цифрами в форме товара.

**Когда знакомство открывается само** (`src/household/remembered.ts:49`). Один раз на аккаунт, и только для совсем нового: человек может добавлять, он в одной группе (её сервер создал при первом входе) и в ней нет ни одного питомца, даже в архиве. Всем остальным очередь отмечается молча. Важный случай — член семьи: он вступил в чужую группу, но своя пустая у него тоже есть, и новый браузер может открыть именно её; «Кто у вас живёт?» там завело бы кошку второй раз и не в той группе. Флаг лежит в браузере (`localStorage`, ключ `collarbell.onboarding.<uid>`):

```ts
export function takeOnboardingTurn(uid, { canEdit, hasPets, households }) { // remembered.ts:49
  try {
    const key = onboardingKeyOf(uid);                      // 'collarbell.onboarding.<uid>'
    if (window.localStorage.getItem(key)) return false;    // уже было — больше никогда
    window.localStorage.setItem(key, '1');                 // очередь занята сразу: второй раз само не откроется
    return canEdit && !hasPets && households === 1;        // открыть только новому: может добавлять, одна группа, пусто
  } catch {
    return false;                                          // хранилище браузера выключено: само не открываем
  }
}
```

Спрашивает «Главная» (`HomePage.tsx:60`):

```ts
const asked = useRef(false);                               // один раз за жизнь страницы
useEffect(() => {
  if (asked.current || !pets.data || pets.isFetching) return; // ждём питомцев, и не во время перечитывания
  asked.current = true;
  const turn = { canEdit: permissions.canEdit, hasPets: pets.data.length > 0, households: households.length }; // любой питомец считается; группы пришли с /me
  if (takeOnboardingTurn(user.uid, turn)) void navigate('/welcome', { replace: true }); // вместо «Главной»: «Назад» не вернёт вопрос
}, [pets.data, pets.isFetching, user.uid, permissions.canEdit, households.length, navigate]);
```

Открытое любым путём (например, из «Настройки → Помощь») знакомство само ставит флаг (`markOnboardingSeen`, `remembered.ts:64`, зовёт `WelcomePage.tsx:102`), поэтому «Готово» не приведёт на «Главную», которая откроет его ещё раз. При выходе из аккаунта браузер забывает флаги других аккаунтов, как и их группы (`forgetOtherAccounts`, там же); при удалении аккаунта — и его собственный.

**Экран знакомства** (`src/pages/welcome/WelcomePage.tsx`). Он внутри обычной рамки с боковым меню, колонкой не шире 560 px. Страница и шаг записаны в адресе (`?page=2`, `?step=feeding`), поэтому «Назад» браузера ведёт на шаг раньше, а стрелка на экране делает то же самое (`back`, строка 173). Шагов три: питомец, кормление и семья — только владельцу (`steps`, строка 106). Шага уведомлений нет: напоминания приходят в приложение на телефоне, и первая страница так и говорит. Помощник видит только страницы.
- **Питомец**: кличка и «Кошка / Собака», тот же `POST /pets`, что у полной формы. У этого запроса нет `requestId`, поэтому потерянный ответ разобран отдельно (строка 233):

```ts
if (unsure.current) {                                      // прошлая попытка кончилась без ответа
  const fresh = await pets.refetch({ throwOnError: true }); // сначала перечитать питомцев
  unsure.current = false;
  if (fresh.data?.some((pet) => pet.status === 'Active')) return; // питомец уже есть: шаг покажет «Уже здесь: …», второго не будет
}
```

- **Кормление**: время чипами, по умолчанию 08:00 и 19:00, каждый день, не больше 8. Свой `requestId` на каждого питомца (строка 300), а время, исправленное между попытками, досылается `PUT`, как в форме кормления (`routineHolds`, строка 322).
- **Семья**: «Пригласить» открывает то же окно, что в «Настройках» (`InviteDialog`, у него появился `onCreated`).
- Защиты: пока идёт сохранение, кнопки ждут. У всех кнопок знакомства — главной, «Назад», «Закрыть», «Пропустить» — второй щелчок двойного щелчка ничего не делает (обёртка `once`, строка 70), иначе он нажал бы то же место на следующем шаге. Набранная и не сохранённая кличка спрашивает «Уйти без сохранения?» (`useLeaveGuard`, строка 149). Другая группа в меню начинает знакомство заново (`<Welcome key={current.id} />`, строка 86): сохранения идут в группу, где оно открылось, а сохранение, закончившееся после такой смены, никуда не переводит (`useStillHere`, строки 247 и 329). «Готово» и «Закрыть» ставят «Главную» на место знакомства (`replace`, строка 165): «Назад» с «Главной» его не вернёт.
- Повторить — «Настройки → Помощь → Знакомство с приложением» (`pages/settings/SettingsPage.tsx:51`).

**Кнопки и карточки действий** (`src/components/ActionCard.tsx`). Правило то же, что на телефоне (5.27). Главное действие страницы или раздела — `button--primary`, остальные — контурные `button--secondary`. Где можно начать несколько дел — карточка: иконка в мятном круге, заголовок, строка «зачем», стрелка, и вся карточка — одна ссылка или кнопка. Текстом (`button--ghost`) остались только выходы и ответы: «Отмена», «Пропустить», «Закрыть», удаление и «Убрать» одной вещи.

```tsx
const named = {                                            // ActionCard.tsx:50
  'aria-labelledby': `${id}-title`,                        // диктор называет карточку её заголовком
  'aria-describedby': hint ? `${id}-hint` : undefined,     // а строку «зачем» читает следом, как пояснение
};
```

Где теперь карточки и кнопки: пустое «Сегодня» и «Главная» без настроек — карточки первых шагов (`pages/today/FirstSteps.tsx:17`); пустые «Запасы» — карточки «Найти по штрихкоду», «Заполнить по фото упаковки», «Заполнить вручную» (форма товара открывается сразу на штрихкоде или с окном фото, `?start=`); пустая история ухода — карточки скана, заметки, ввода из паспорта и записи вручную. Пустые «Визиты», «Кормление» и план ухода — залитая кнопка прямо в пустом месте, а кнопка над списком появляется с первой записью. Кнопки в заголовках разделов («Все визиты», «Добавить план», «Пригласить», «Вступить по коду») и «Покормить всех» — контурные с иконкой.

**Чего в вебе нет**: напоминаний-пушей (они приходят на телефон), работы без интернета и камеры (фото выбирают с компьютера или перетаскивают).

**Как веб выглядит** (`src/styles/`). Цвета, размеры и шрифты — токены из `design/tokens.json`: `npm run tokens` строит `tokens.css` (светлая тема и тёмная по настройке системы) и `theme.css` (тема, выбранная в «Настройках»). Все правила — в `app.css`, и в нём нет ни одного цвета «от руки», только токены; тень под окном — самый тёмный цвет палитры `#191E28` наполовину прозрачный (`.dialog::backdrop`).
- **Шрифт** — Helvetica Neue там, где он есть (Mac, iPhone), иначе Arimo — бесплатный двойник Arial (`fonts.css`, файлы `src/fonts/arimo-*.woff2`, лицензия `OFL-arimo.txt`). В каждом файле все толщины от 400 до 700, поэтому на часть алфавита одно правило `@font-face`. Толщин в интерфейсе три: 400, 500, 700; 600 больше нигде нет. Заголовки жирные (700), названия в строках — обычные (`subtitle`, `.row-title`, `app.css:749`), вторые строки — бледные (`ink-muted`).
- **Зелёный — двух оттенков** (вторая правка дизайнера: прежний #066849 выглядел болотным). Яркий `primary` (#00B53F) — только заливки: главная кнопка, полоска лимита фото, галочки и ползунки браузера (`accent-color`), линия и точки графика веса. Всё зелёное, что нужно прочитать или разглядеть тонкой линией, — `primary-text` (#007F2B, тот же оттенок темнее; в тёмной теме — яркий #00B53F): ссылки, выбранный пункт меню и вкладка, текст и рамка выбранного чипа, «Покормили» и «Купили» на мятном фоне, маленькие зелёные иконки, рамка фокуса. Правило одно: текст или тонкая линия — `primary-text`, заливка с текстом поверх — `primary` (`app.css:56`).
- **Кнопки** все одной высоты, 44 px (`.button`, `app.css:445`); маленьких кнопок (`button--sm`) больше нет. Главная кнопка (`.button--primary`, `app.css:475`) — яркий зелёный с белым жирным (700) текстом: белый на ярком зелёном читается хуже нормы, жирные буквы это смягчают (решение владельца). У остальных кнопок текст обычной толщины подписей, 500. Между кнопками в ряд 8 px, друг под другом 12 px. Обводка полей, чипов и контурных кнопок — 1,5 px мягкого цвета `line-strong`; поле в фокусе обведено тёмно-зелёным `primary-text` в 2 px (`.input`, `app.css:1289`).
- **Иконки** — Material Symbols Rounded толщины 400 в рисунке размера 48 (чуть тоньше обычного): контуры SVG в `src/components/icons.ts`, рисует их `components/Icon.tsx`. Пути пишет скрипт `node tools/icons.mjs` из пакета Google (4.20); стрелку выпадающего списка, вшитую в `app.css` картинкой, он обновляет тоже.
- **Статусы** — «таблетки» `StatusTag` (`components/ui.tsx:92`, стили `.tag`, `app.css:930`): «скоро», «пора купить», «проверьте» — жёлтая с тёмным текстом и иконкой, «просрочено», «закончился» — красная с белым. Жёлтого текста нет нигде: на белом он не читается. Спокойные состояния — обычный бледный текст. Срок ухода рисует `DueLine` (просрочено и скоро — таблетка, остальное — текст). Предупреждение (`Notice tone="warning"`) — кремовая плашка с жёлтой рамкой 1,5 px, иконка и текст тёмные.
- **Аватар питомца** (`PetAvatar`, `.avatar`, `app.css:857`) — фото в круге, а без фото первая буква на светло-голубом круге, одинаково у всех. Своего цвета у питомца больше нет: выбор цвета убран из формы, строка — из карточки. В API поле `coat` осталось, форма отправляет `coat: null` (`PetFormPage.tsx:195`): новому питомцу сервер подбирает цвет сам, у старого оставляет прежний.
- **Неразрывные пробелы в русском.** Короткие слова и числа держатся за следующее слово неразрывным пробелом, который ставит `python3 tools/typograph.py` в `ru.ts` (CI проверяет `--check`). То, что склеивается на ходу, делает так же: дата («7 окт. 2026 г.») — в `i18n/format.ts:57`, «Раз в 21 день» — в самом `ru.ts`. Тесты пишут такой пробел как «~»: `nb('Через~2~дня')` (`src/test/nb.ts`), а надписи на экране берут прямо из словаря.

**Демо-режим** (`npm run dev:mock`, `src/mock/`). Приложение без сервера и аккаунта, с примером данных на двух языках: кошка и собака, планы, документы, вес, запасы, ждущий скан. Это тот же «сервер понарошку», что и в тестах (`src/test/server.ts`). Удобно, чтобы посмотреть любой экран. В сборку для сервера демо не попадает. Переключатели в адресе показывают другие дни: `?mockWorld=new` — новый аккаунт с пустой группой (знакомство откроется само), `?mockWorld=pets` — питомцы без настроек (первые шаги), `?mockWorld=done` — «На сегодня всё сделано» (`shapeDemoWorld`, `src/mock/world.ts:1169`).

**Тесты** — `npm test` (Vitest и Testing Library, около 500). Каждая ошибка, найденная проверками, закреплена тестом с её сценарием. «Главная» — `pages/home/home.test.tsx`, знакомство — `pages/welcome/welcome.test.tsx` (когда открывается само, флаг на аккаунт, выключенное хранилище, шаги, потерянный ответ, двойной щелчок), карточки и кнопки вместо текста — `pages/actions.test.tsx`.

**Как выкладывается.** `deploy/web.Dockerfile` собирает веб вместе с лендингом и админкой в один образ nginx, `deploy/nginx.conf` отдаёт его под `/app/` (страница не кэшируется, файлы с хэшами кэшируются на год).

### 5.27. «Главная», знакомство и кнопки (`features/home/`, `features/onboarding/`, `shared/widgets/cb_action_card.dart`)

С 2026-10-14 у приложения пять вкладок: «Главная» · «Сегодня» · «Питомцы» · «Запасы» · «Ещё». Решения владельца — в спецификации (`docs/mvp-spec.md`, раздел 10, «Главная, знакомство, кнопки»). Здесь — как это устроено в коде.

**Маршруты** (`app/router.dart`). «Главная» — первая ветка вкладок (`path: AppRoutes.home`, строка 257). Приложение открывается на ней (`initialLocation`, строка 230), туда же ведут `/`, вход и неизвестные ссылки (`authRedirect`, строка 190). Знакомство — маршрут `/welcome` вне вкладок (строка 244), поэтому он ложится поверх всего, а «Назад» возвращает на экран под ним. У него два «ребёнка»: `/welcome/pet` (полная форма питомца) и `/welcome/join` (вход по коду). Они тоже поверх вкладок, иначе открылись бы внутри вкладки, спрятанной под знакомством. Нижняя панель (`app/home_shell.dart`) получила пятую кнопку «Главная» (строка 154). На узком телефоне с крупным шрифтом подписи вкладок чуть меньше остального текста (`MediaQuery.withClampedTextScaling`, строка 130), иначе «Питомцы» ломались на две строки.

**«Главная»** (`features/home/home_screen.dart`). Отдельного адреса на сервере нет: экран смотрит те же `todayProvider` и `petsProvider`, что «Сегодня» и «Питомцы».
- Сверху дата и приветствие по часам телефона (`homeGreeting`, строка 196).
- Питомцы в ряд (`_PetsRow`, строка 207). Касание кладёт страницу питомца поверх «Главной» (строка 230), как на «Сегодня», и не трогает вкладку «Питомцы».
- «Сейчас важно» (`_RightNow`, строка 357). Ближайшее кормление показывает тот же виджет, что на «Сегодня», `TodayFeedingSection` (строка 456): ему отдаётся весь список кормлений дня, а ближайшее время он выбирает сам (`next: true`). Список тот же объект, пока «Сегодня» не перечитано, поэтому отметка, сделанная на «Главной», не пропадает, пока экран ждёт ответа. Поэтому «Покормили», «Покормить всех», «кто-то успел раньше» и работа без связи — одни и те же, код не повторяется:

```dart
List<TodayFeeding>? nextFeeding(List<TodayFeeding> feedings) {  // feeding.dart:178
  for (final items in feedingsByTime(feedings).values) {        // времена дня по порядку: 08:00, 13:00, 19:00
    if (items.any((item) => item.mark == null)) return items;    // первое, где кто-то ещё не накормлен, — целиком
  }
  return null;                                                   // всё отмечено — кормления на «Главной» нет
}
```

- Просроченное и скорое — одна строка с красной и жёлтой метками. Она переключает на «Сегодня» так же, как нажатие на панель (`openTab`, строка 416): открытое там не сбрасывается. «Купить: N» так же открывает «Запасы». Визит берётся прошедший, который ждёт «Как прошёл визит?», иначе ближайший (`nextVisit`, `home_screen.dart:483`); у его строки, как у остальных, стрелка в конце (`TodayVisitRow(chevron: true)`).
- Пока данные перечитываются, старые видны, но на нажатия не отвечают (`IgnorePointer`, строка 448), как на «Сегодня».
- «Быстрые действия» (`_QuickActions`, строка 592) — только для тех, кто может редактировать. Скан и «Записать словами» — только если на сервере есть AI. Действию нужен питомец: один — сразу к нему, несколько — нижняя панель «Какой питомец?» (`forPet`, `pet_picker.dart:13`). «Взвесить» открывает окно взвешивания прямо поверх «Главной».
- «Главная» перечитывает «Сегодня» так же, как вкладка «Сегодня»: при возвращении в приложение и после полуночи. Это общий кусок `TodayReload` (`features/today/today_reload.dart:13`). Он нужен обоим экранам: приложение открывается на «Главной», и «Сегодня» может ещё ни разу не строиться.

**Когда знакомство открывается само** (`features/onboarding/onboarding.dart`). Раз на аккаунт на этом телефоне и только тому, кто начинает с нуля. В настройках телефона лежит флаг `onboarding.seen.<uid>` (`keyFor`, строка 22):

```dart
static bool takeTurn(                                // onboarding.dart:28 «чья очередь смотреть знакомство»
  SharedPreferences preferences,                     // настройки телефона
  String uid, {                                      // какой аккаунт вошёл
  required int households,                           // в скольких группах человек (из /me)
  required bool canEdit,                             // может ли он добавлять (помощник — нет)
  required bool hasPets,                             // есть ли в группе питомцы — любые, и умершие, и в архиве
}) {
  if (preferences.getBool(keyFor(uid)) ?? false) return false; // уже было — больше никогда
  markSeen(preferences, uid);                        // флаг ставится сразу, что бы ни решили: второй раз не откроется
  return households == 1 && canEdit && !hasPets;     // одна группа, можно добавлять, питомцев нет — открыть
}
```

Почему так строго. Член семьи, который вступил по коду, остаётся и в своей группе — пустой, её сервер создал при первом входе. На новом телефоне сервер может показать именно её, и «Кто у вас живёт?» добавил бы кошку семьи второй раз, в чужую группу. Поэтому две группы и больше — флаг молча, без показа. Питомец в архиве или умерший тоже значит, что человек не начинает с нуля (при этом карточки «Добавьте питомца» на «Главной» смотрят на живых питомцев, как раньше).

Спрашивает «Главная» (`home_screen.dart:98`):

```dart
if (!_onboardingAsked &&                            // один раз за жизнь экрана: пересборки не считаются
    petList != null &&                              // питомцы загружены (копия без связи — тоже настоящие данные)
    !pets.isLoading &&                              // и не перечитываются прямо сейчас
    households != null &&                           // группы человека известны (meProvider, /me)
    !me.isLoading &&                                // и тоже не перечитываются: по неполным данным не решаем
    TickerMode.of(context)) {                       // «Главная» на виду, а не под другой вкладкой
  _onboardingAsked = true;
  WidgetsBinding.instance.addPostFrameCallback(     // после кадра: во время сборки страницу открывать нельзя
    (_) => _askAboutOnboarding(petList, households.length), // :66 takeTurn и, если пора, context.push(AppRoutes.welcome)
  );
}
```

Новый аккаунт после входа сразу видит знакомство. Старые пользователи после обновления его не увидят: у них есть питомцы, и флаг ставится молча. Смена группы, живые обновления и перечитывание его тоже не откроют: флаг уже стоит. Повторить — «Ещё → Помощь → Знакомство с приложением» (`more_screen.dart:178`). Экран знакомства сам ставит флаг, как только открылся (`markSeen`, `welcome_screen.dart:126`): открытое из «Ещё» само потом не появится.

**Экран знакомства** (`features/onboarding/welcome_screen.dart`). Три страницы в `PageView` с точками, потом шаги. «Шаг N из M» считается по роли (`_steps`, строка 138): помощник шагов не видит, «Семья» — только владельцу.
- **Питомец**: кличка и «Кошка / Собака» (`_savePet`, строка 242). Проверка и обновление экранов — как у полной формы: `createPet`, потом тот же `refreshPet` (строка 263, сама функция — `pet_form_screen.dart:905`). Если ответ не пришёл (нет связи), питомцы перечитываются (строка 277): если сервер всё же добавил питомца, шаг покажет «Уже здесь: …», и второй раз его не добавить. Если питомцы уже есть — «Уже здесь: …» и «Добавить ещё» (полная форма на `/welcome/pet`). Карточка «Меня пригласили в семью» открывает вход по коду; если группа сменилась, знакомство закрывается (строка 298): шаги были про прежнюю группу.
- **Кормление**: время чипами, по умолчанию 08:00 и 19:00, каждый день (`FeedingInput(times: _times, days: everyDay)`, строка 337), не больше 8 времён, как в форме кормления. Свой `requestId` на каждого питомца (строка 338): повтор после потерянного ответа не создаст второе расписание, а сервер не вернёт расписание одного питомца в ответ на сохранение другого. Если расписание уже есть — «Кормление уже настроено».
- **Уведомления**: «Включить уведомления» (`_allowPushes`, строка 365) зовёт тот же `askForPushesOnce`, что формы, но с `explained: true`: экран уже объяснил зачем, поэтому второй вопрос «Разрешить уведомления?» не показывается (`push_registration.dart:353`). Пока телефон спрашивает, кнопка занята: второе нажатие ничего не делает. Запрещены — «Открыть настройки», как на «Сегодня».
- **Семья**: «Пригласить» — тот же порядок, что на экране группы (`inviteToHousehold`, `household_sheets.dart:331`), в ту группу, где знакомство открылось (`_invite`, строка 401).
- Сохранения идут в группу, где знакомство открылось (`OpenedInHousehold`, 5.19). Ошибка показывается над главной кнопкой (`CbSaveBar`), шаг остаётся на месте.

«Назад» на знакомстве сначала идёт по шагам и страницам, и только с первой страницы закрывает его:

```dart
PopScope<Object?>(                                  // welcome_screen.dart:445
  canPop: false,                                    // сами решаем, что делает «Назад»
  onPopInvokedWithResult: (didPop, _) {
    if (didPop || _busy) return;                    // пока сохраняется — ничего
    _atStart ? _close() : _back();                  // первая страница — закрыть, иначе — шаг или страница назад
  },
```

Закрыть, когда в поле клички что-то набрано, — тот же вопрос «Уйти без сохранения?», что у форм (`confirmLeave`, строка 224). Две защиты от лишних нажатий: после смены страницы или шага главная кнопка 0,3 секунды не нажимается (`WelcomeScreen.settleAfterMove`, строка 55), чтобы двойное «Дальше» не нажало кнопку следующего шага («Включить уведомления», «Сохранить и дальше» с временем по умолчанию); а знакомство, открытое не поверх другого экрана, закрывается переходом на «Главную» (`_finish`, строка 219), а не в пустоту. Готовый `LeaveGuard` здесь не подошёл: он закрывал бы экран на любое «Назад», а не шагал назад.

**Правило кнопок** (решение владельца). Призыв к действию — то, что начинает задачу или создаёт: «Добавить…», «Записать…», «Покормить всех», «Все визиты», «Сканировать», «Пригласить», «Открыть настройки», «Повторить». Он всегда настоящая кнопка:
- главное действие экрана или пустого раздела — залитая (`FilledButton`), остальные — контурные (`OutlinedButton`), обе высотой 44 из темы;
- в заголовке раздела — компактная контурная с иконкой и словом (`cbCompactOutlinedButtonStyle`, `collarbell_theme.dart:612`; `CbSection` даёт её сам), а где места нет — круглая контурная с подсказкой (`cbOutlinedIconButtonStyle`, строка 582);
- где можно начать несколько дел — **карточки действий**;
- текстом остаются ответы в диалогах, действие в тосте, выходы («Пропустить», «Не сейчас», «Закрыть») и ссылки или правки внутри текста («Забыли пароль?», «Изменить» под датой). Строки списков, которые открывают подробности, — не призывы.

**Карточка действия** (`CbActionCard`, `shared/widgets/cb_action_card.dart:14`): иконка в мятном круге (`primary-soft`, значок `primary-text`), заголовок, строка «зачем» и стрелка. Нажимается вся карточка, и для экранного диктора это одна кнопка:

```dart
child: MergeSemantics(                              // cb_action_card.dart:113 заголовок и строка «зачем» читаются вместе
  child: Semantics(
    button: true,                                   // «кнопка», а не просто текст
    child: InkWell(
      onTap: onTap,                                 // нажатие в любом месте карточки
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight), // не ниже 64: в палец попасть легко
```

`primary: true` — главное дело на экране («Добавьте питомца»): карточка мятная, круг ярко-зелёный. `CbActionCard.compact` — маленькая, для сетки в два столбца на «Главной»: значок сверху, без стрелки. Сетка (`CbActionGrid`, строка 143) ровняет высоту карточек в ряду по самой высокой. Если два столбца не помещаются (узкий телефон с крупным шрифтом, длинное слово порвалось бы посередине), карточки встают по одной в обычном виде (строка 156).

**Где карточки и кнопки теперь** (полный список — в отчёте к изменению):
- пустой «Сегодня» и «Главная» без настроек — карточки первых шагов (`TodayFirstSteps`, `features/today/first_steps.dart:21`; переход во вкладку «Питомцы» спрашивает «Уйти без сохранения?», если где-то открыта форма с текстом, строка 131);
- пустые «Запасы» — карточки «Сканировать штрихкод», «Сфотографировать упаковку», «Заполнить вручную» (`_FirstSupply`, `supplies_screen.dart:208`); плавающая кнопка «Добавить» появляется с первым товаром (строка 118, `showsAddOverList` в `shared/widgets/state_views.dart:17`: её нет и пока список грузится впервые, чтобы она не мелькнула); так же «Визиты» (`visits_screen.dart:97`). Если перечитать пустой список не удалось, видна ошибка, а кнопки «Добавить» над списком остаются (`showsEmptyList`, строка 11);
- вкладки питомца: пустой план ухода, «Кормление» и «Документы» — залитая кнопка прямо в пустом месте, пустая история ухода — карточки скана, заметки и записи вручную (`health_tab.dart:257`);
- «Все визиты», «Все запасы», «Покормить всех», «Добавить…» в заголовках, «Открыть настройки», «Повторить», «Посмотреть тариф», «Отозвать», «Закончился», «Заполнить вручную», «Сканировать заново» — контурные кнопки.

**Тесты**: `test/features/home/home_screen_test.dart` (экран, «Покормили», переходы, помощник, выбор питомца, узкий телефон), `test/features/onboarding/welcome_test.dart` (когда открывается, флаг на аккаунт, шаги через подделки, «Пропустить», «Назад», помощник, владелец), `test/app/home_routes_test.dart` (`/`, пять вкладок, пуши), `test/shared/widgets/cb_action_card_test.dart` и `calls_to_action_test.dart` (кнопки вместо текста). Помощник `pumpApp` по умолчанию считает знакомство уже показанным (`onboardingSeen`), чтобы оно не закрывало экраны в остальных тестах.

## 6. Шпаргалка по синтаксису

### C# (сервер)

| Запись | Как читать |
|---|---|
| `var x = …` | «Переменная x»; тип компилятор выведет сам |
| `string?` | Строка, которая может быть null («нет значения») |
| `a ?? b` | «a, а если a — null, то b» |
| `x?.Name` | «Name, если x не null; иначе null» |
| `=> выражение` | Короткая запись метода: «возвращает выражение» |
| `u => u.Email == e` | Лямбда — маленькая функция: «для каждого u: проверить …» |
| `async` / `await` / `Task<T>` | Асинхронность: `await` — «дождаться результата, не блокируя сервер» |
| `.Where(…).Select(…).ToListAsync()` | LINQ: «отфильтровать → преобразовать → выполнить» (в EF это SQL) |
| `public sealed record X(int A, string B)` | Неизменяемый «пакет данных» с полями A и B (так сделаны DTO) |
| `class X(AppDbContext db)` | Primary constructor: параметры класса прямо в заголовке (так получают службы из DI) |
| `List<PetResponse>` | Обобщение (generic): «список элементов типа PetResponse» |
| `this IServiceCollection services` | Метод-расширение: вызывается как `services.AddCollarbellAuth(...)` |
| `[JsonConverter(...)]`, `[Fact]` | Атрибуты — пометки для фреймворков (JSON, тестов) |
| `e is PostgresException { SqlState: … }` | Проверка типа и полей одновременно (pattern matching) |
| `catch (…) when (условие)` | Поймать исключение, только если выполнено условие |
| `$"dev:{uid}"` | Строка с подстановкой значения |
| `[ "a", "b" ]` | Литерал коллекции |

### Dart (телефон)

| Запись | Как читать |
|---|---|
| `final x = …` | Значение, которое после присвоения не меняется |
| `const` | Значение, известное при сборке (Flutter переиспользует такие виджеты) |
| `String?` / `x!` | «Может быть null» / «я уверен, что тут не null» (при ошибке — падение) |
| `a ?? b`, `x?.y` | Как в C# |
| `=> выражение` | Короткая функция |
| `Future<T>` / `await` | Будущий результат / дождаться его |
| `Stream<T>` | Поток значений во времени (например, «кто вошёл») |
| `{required this.name}` | Именованный обязательный параметр: `Pet(name: 'Murka')` |
| `_name` | Подчёркивание = приватное (видно только в этом файле) |
| `abstract interface class` | Контракт без реализации |
| `implements X` / `extends Y` | «Выполняет контракт X» / «наследует от Y» |
| `@override` | «Переопределяю метод родителя» |
| `[for (final d in list) f(d)]` | Список, собранный циклом |
| `switch (x) { A => …, B => … }` | switch-выражение: выбрать значение по варианту |
| `({ThemeData light, ThemeData dark})` | Record — безымянный «пакет» из двух именованных значений |
| `...[a, b]` | Развернуть список внутрь другого |
| `late final x = …` | Значение создаётся при первом обращении, потом не меняется |
| `(int, int)` / `(i + 1, total)` | Record: пара значений без отдельного класса, например «загружено 2 из 3» |
| `key: const ValueKey('name')` | Постоянное имя виджета: Flutter не перепутает его с соседним, когда список полей меняется |
| `if (!mounted) return;` | «Экран уже закрыт — дальше ничего не трогать». Нужен после каждого `await` в экране |

## 7. Как найти, «где это делается»

| Вопрос | Как искать |
|---|---|
| Какой код отвечает на `GET /api/v1/pets`? | Поиск по проекту `MapGet` или `"/pets"` → `PetsEndpoints.cs` |
| Где на экране надпись «No pets yet»? | Поиск текста в `mobile/lib/l10n/app_en.arb` → ключ `petsEmptyTitle` → поиск ключа в `lib/` |
| Откуда берётся этот цвет? | Имя токена (`inkMuted`) → `design/tokens.json` → описание `usage` |
| Где это используется? | В IDE: «Find Usages» / «Go to References» (правый клик) |
| Куда ведёт этот вызов? | Cmd+клик по имени — переход к определению |
| Почему так сделано? | `git log -p <файл>` — история изменений с сообщениями коммитов |
| Как это должно работать? | Найдите тест: имена тестов описывают поведение |
| Какой метод телефона зовёт этот адрес? | В `contracts/openapi.json` у адреса есть `operationId`, например `ListPets`. В сгенерированном клиенте метод называется так же: `api.pets.listPets()` |
| Поменял сервер — что сделать на телефоне? | `sh mobile/tool/generate_api.sh`, потом `flutter analyze`: компилятор покажет все места, которые нужно поправить |
| Куда сервер положил мой файл? | Дашборд Aspire → ресурс `storage`; или ссылка `url` из ответа `POST /api/v1/files` |
| Почему скан не прочитал страницу? | В приложении «Ещё → AI» → «Проверить подключение». Подробная причина — в логе сервера: дашборд Aspire → ресурс `api` → Logs |
| Хорошо ли AI читает мой паспорт? | Положить фото в `backend/tests/ai-samples/<папка>/` и запустить тест, как написано в README этой папки |
| Сколько AI-запросов потрачено? | «Ещё → AI» → «В этом месяце». В базе — таблица `ai.usage`, по строке на каждую попытку |
| Почему не пришло напоминание? | «Ещё → Уведомления» → «Недавние напоминания»: что с ним стало. На сервере — таблица `notifications.reminders`, колонки `status` и `reason` |
| Доходят ли пуши до телефона? | «Ещё → Уведомления» → «Прислать проверочное уведомление» |
| Где текст пуша? | `Modules/Notifications/ReminderTexts.cs` — все тексты пушей на двух языках |
| Почему «хватит на 20 дней», а не на 25? | На странице товара строка «Расход … в день». Расход корма — это порции кормлений, где выбран этот корм. Расчёт — `SupplyForecasts.Compute` в `SupplyForecast.cs` |
| Почему на экране старые данные? | Над меню полоска «Нет связи с сервером · данные на …»: телефон показывает копии последних ответов (5.18). Нет интернета или сервер недоступен. Как только сервер ответит, все экраны обновятся сами |
| Почему «Покормили» не сработало без связи? | Изменения поверх копий не делаются (5.18): дождитесь, пока пропадёт полоска «Нет связи», и повторите |
| Почему форма спрашивает «Уйти без сохранения?» | Метод `_values()` формы — что она сравнивает с тем, с чем открылась; `shared/widgets/leave_guard.dart` (5.18) |
| Почему у человека нет кнопки «Добавить»? | У него роль «Помощник»: правила ролей — `HouseholdPermissions` в `features/household/current_household.dart` (5.19). Роль видна в «Ещё → Группа» |
| Про какую группу этот запрос? | Заголовок `X-Household` (`data/api/household_header.dart`); группа на экране — `currentHouseholdProvider` (5.19) |
| Откуда в журнале веса вес, которого никто не вводил? | Это вес из записи осмотра у ветеринара (значок осмотра, нажатие открывает запись): `CareRecordWeights` в `CareRecordsEndpoints.cs` (4.26). Правится в самой записи |
| Почему у прививки пропал вес? | Вес хранится только у осмотра: `CareRecordsEndpoints.Apply` (4.26) |
| Почему штрихкод не нашёлся? | `ProductLookup.FindAsync` в `ProductLookup.cs`: свой каталог, Open Pet Food Facts, UPCitemdb. Ошибки баз — в логе сервера (дашборд Aspire → `api` → Logs) |

## 8. Упражнения

1. **Пощупать API руками.**
   - Запустите бэкенд (`cd backend && dotnet run --project src/Collarbell.AppHost`) и откройте <http://localhost:5080/scalar/v1>.
   - Вызовите `GET /api/v1/me` с заголовком `X-Dev-User: me`.
   - Сравните поля ответа с `MeResponse` в `MeEndpoints.cs`.
2. **Сломать тест и починить.**
   - В `PetsTests.cs` поменяйте `"Murka"` в `Assert.Equal` на другое имя и запустите `dotnet test`. Прочитайте, как выглядит падение.
   - Верните как было.
3. **Поменять текст.**
   - В `app_en.arb` и `app_ru.arb` измените `petsEmptyBody`.
   - Запустите приложение и нажмите `r` (hot reload) — текст обновится без перезапуска.
4. **Проследить заголовок.** Найдите, где на телефоне добавляется `X-Dev-User` и где сервер его читает. Подсказка: `dev_auth_repository.dart` и `DevUserAuthenticationHandler.cs`.
5. **Найти защиту чужих данных.** В каком месте сервера гарантируется, что Олег не увидит кошку Ани? Есть ли на это тест? Ответ — в разделах 2 и 4.7.
6. **Загрузить фото руками.**
   - В Scalar (<http://localhost:5080/scalar/v1>) вызовите `POST /api/v1/files` с заголовком `X-Dev-User: me` и любым фото.
   - Откройте `url` из ответа в браузере. Уберите из ссылки всё после `?` — хранилище ответит «доступ запрещён». Так работает подпись.
7. **Найти защиту листов паспорта.** Почему телефон никогда не отправляет серверу полный список страниц? Найдите это место в `passport_pages.dart` и на сервере — в `DocumentsEndpoints.cs`. Ответ — в разделах 4.9 и 2.2.

## 9. Словарь

| Термин | Простыми словами |
|---|---|
| **API, эндпоинт** | Адрес на сервере, который принимает запрос и отвечает (`GET /api/v1/pets`) |
| **DI (внедрение зависимостей)** | Объекты не создают нужные службы сами: их «подаёт» контейнер (`builder.Services.Add…`) |
| **Middleware / конвейер** | Цепочка шагов, через которую проходит каждый запрос (`app.Use…`) |
| **Сущность (entity)** | Класс, который хранится в таблице базы |
| **DTO** | «Форма» данных для передачи по сети, без лишних полей |
| **Миграция** | Записанное изменение структуры базы; применяется по порядку |
| **EF Core** | Библиотека, которая превращает C#-запросы в SQL |
| **Кэш на чтение (копия ответов)** | Последние ответы сервера, сохранённые на телефоне: их показывают, когда сервер недоступен, но изменения поверх них не делаются (5.18) |
| **JWT / ID-токен** | Подписанная «справка» от Firebase: кто ты и до какого времени справка действует |
| **Claim** | Строчка в справке: `sub` — идентификатор, `email` — почта |
| **ProblemDetails (RFC 7807)** | Стандартный формат ошибки: `title`, `status`, `detail`, `traceId` |
| **OpenAPI-контракт** | Описание всех адресов API в одном JSON-файле; по нему генерируются клиенты |
| **Household (семья)** | Граница доступа: все данные принадлежат семье |
| **Aspire / AppHost** | Инструмент, который запускает базу и API вместе и показывает дашборд |
| **Testcontainers** | Библиотека, которая поднимает настоящий Postgres в Docker на время тестов |
| **Виджет** | Кирпичик интерфейса во Flutter |
| **Провайдер (Riverpod)** | Именованный источник данных или службы с кэшем и подписками |
| **Репозиторий** | Класс «достань или сохрани данные», который прячет, откуда они берутся |
| **Токены дизайна** | Именованные цвета, размеры и шрифты из дизайн-системы |
| **Hot reload** | Обновление запущенного приложения без перезапуска после правки кода |
| **S3, объектное хранилище** | «Склад файлов» с ключами вместо папок. Локально — SeaweedFS, в продакшене — Cloudflare R2 |
| **Подписанная ссылка** | Ссылка на файл с «пропуском» внутри, который действует 15 минут. Без подписи хранилище файл не отдаст |
| **Миниатюра (thumbnail)** | Маленькая копия фото (480 px) для списков, чтобы не качать большое фото ради кружка |
| **EXIF** | Служебные данные внутри фото: модель камеры, поворот, иногда координаты места съёмки |
| **Multipart** | Способ отправить файл в HTTP-запросе — как форма с вложением |
| **Outbox («исходящие»)** | Внешнее действие (удалить файл, отправить пуш) сначала записывается в таблицу-очередь в той же транзакции, а выполняется потом фоновой задачей |
| **IDOR** | Ошибка доступа, когда достаточно подставить чужой id в адрес. У нас на чужое — всегда 404 |
| **Кодогенерация** | Код, который пишет программа по описанию (здесь — клиент API по `openapi.json`). Руками его не правят |
| **ProviderContainer** | «Хранилище» всех провайдеров Riverpod. Живёт, пока живёт приложение, в отличие от `ref` экрана |
| **PopScope** | Обёртка экрана, которая может запретить «назад» — например, пока идёт сохранение |
| **Идемпотентность** | Повтор того же запроса ничего не портит: второй раз сервер вернёт тот же результат, а не сделает дело дважды |
| **requestId** | Случайный id, который приложение даёт одному действию («Сделано», новая запись) и повторяет при повторе. По нему сервер узнаёт повтор |
| **UUID** | Длинный случайный id вида `3f2a…`. Совпасть случайно два UUID практически не могут |
| **Пресет** | Готовый шаблон плана: «Бешенство раз в год», «Глистогонка раз в 3 месяца». Все значения можно поменять |
| **LLM, модель** | Программа, которая читает текст и картинки и отвечает текстом. У нас — Gemini от Google |
| **Промпт** | Текст-инструкция для модели: что прочитать и как ответить (`PassportScanPrompt`) |
| **JSON-схема** | Описание формы ответа: какие поля и какого типа. Модель обязана ответить строго по нему |
| **Токен (у модели)** | Кусочек текста, примерно 3–4 буквы, или часть картинки. В токенах считают лимиты и цену |
| **Бесплатный тариф** | Gemini бесплатно, но с лимитом запросов. Google может использовать отправленное для улучшения своих продуктов |
| **Фоновая служба** | Код, который работает на сервере сам, без запроса от телефона: уборка хранилища, чтение сканов (`BackgroundService`) |
| **Транзакция** | Несколько изменений базы как одно целое: сохранятся либо все, либо ни одно |
| **Блокировка строки** | `FOR UPDATE`: «эта строка занята, пока я не закончу». Второй запрос к ней ждёт первого |
| **Пуш (push-уведомление)** | Сообщение, которое сервер отправляет на телефон, даже когда приложение закрыто |
| **FCM, токен телефона** | Firebase Cloud Messaging — служба Google, которая доставляет пуши. Токен — «адрес» конкретного телефона в ней; Firebase иногда его меняет |
| **Канал уведомлений** | Настройка Android: у каждого вида уведомлений свой звук и свой переключатель в системных настройках |
| **Диспетчер** | Фоновая служба, которая раз в 15 секунд отправляет наступившие напоминания |
| **Окно досылки** | Насколько напоминание может опоздать и всё ещё уйти: кормление — 30 минут, остальное — сутки |
| **Летнее время** | Перевод часов весной и осенью. Из-за него «08:00 по Берлину» — это то 06:00, то 07:00 по UTC; считает библиотека NodaTime |
| **Прогноз запаса** | Оценка «на сколько хватит»: последняя поправка остатка, минус расход за прошедшие дни, плюс покупки |
| **Дни на доставку** | За сколько дней до конца запаса напомнить купить: столько обычно едет заказ |
| **GTIN, EAN, UPC** | Номер товара под штрихкодом: 8, 12, 13 или 14 цифр. Последняя — контрольная, по ней ловятся опечатки |
| **GS1 DataMatrix** | Квадратный код на упаковках лекарств. В нём номер товара, серия и срок годности |
| **Open Pet Food Facts** | Открытая бесплатная база кормов для животных. Её данные под лицензией ODbL: показываем, откуда они, и не копируем к себе |
| **Чип ISO 11784/11785** | Номер питомца в капсуле под кожей: 15 цифр, первые три — код страны (643 — Россия, 276 — Германия) или производителя. Его читает сканер ветеринара на 134,2 кГц. NFC телефона работает на 13,56 МГц и чип не прочитает, поэтому приложение читает номер с наклейки в паспорте (5.7) |
