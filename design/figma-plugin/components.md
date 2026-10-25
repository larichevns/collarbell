- **Button** (108×44) · variants Style: Primary | Secondary | Text; State: Default | Disabled · props Label (TEXT = "Отметить") · text layers: label
  Кнопка-«таблетка» высотой 44: Primary — главное действие (одна на экран), Secondary — действия в строках, Text — действие-ссылка.
- **Card** (343×82) · props Title (TEXT = "Кормление"), Text (TEXT = "Завтрак — Мурка · 08:00 · 40 g") · text layers: title, text
  Белая карточка: фон surface, рамка line, тень shadow-card, радиус 20, поля 16 — контейнер для строк на экранах.
- **Text field** (343×94) · variants State: Default | Focused | Error · props Label (TEXT = "Кличка"), Value (TEXT = "Например, Мурка"), Show hint (BOOLEAN = true) · text layers: label, value, hint
  Поле ввода с подписью сверху: рамка line-strong, радиус 14; в фокусе рамка primary 2px, при ошибке — danger и текст ошибки под полем.
- **Chip** (78×36) · variants Selected: Off | On · props Label (TEXT = "Мурка") · text layers: label
  Чип-фильтр высотой 36: выбранный — подложка primary-soft, галочка и текст primary; обычный — фон surface и рамка line-strong.
- **Notice** (343×72) · variants Kind: Info | Warning | Error · text layers: message
  Уведомление с иконкой и словами: Info на sunken, Warning на warning-soft, Error на danger-soft; радиус 14, поля 12.
- **Pet avatar** (28×28) · variants Size: 28 | 40 | 64; Coat: Ginger | Fawn | Cocoa | Smoke | Lilac | Ink · props Initial (TEXT = "М") · text layers: initial
  Аватар питомца без фото: круг цвета шерсти и первая буква клички (numeral, 45% размера).
- **Status line** (280×20) · variants Status: Overdue | Soon | Planned · text layers: icon/error, text
  Срок плана ухода: иконка и слова, цвет никогда не один. Просрочено — danger, скоро — warning, по плану — ink-muted.
- **Switch** (52×32) · variants Value: On | Off · text layers: 
  Переключатель Material 3 в цветах Collarbell.
- **App bar** (390×56) · variants Actions: None | Menu | Edit + Menu · props Title (TEXT = "Мурка") · text layers: icon/arrow_back, title
  Верхняя панель вложенных экранов: «назад», заголовок (title), действия.
- **Screen header** (390×102) · props Title (TEXT = "Сегодня"), Caption (TEXT = "Пятница, 2 октября"), Show caption (BOOLEAN = true) · text layers: caption, title
  Заголовок вкладок нижнего меню: подпись (дата) и большой заголовок display-lg.
- **Bottom navigation** (390×80) · variants Tab: Today | Pets | Supplies | More · text layers: icon/today, label, icon/pets, label, icon/inventory_2, label, icon/more_horiz, label
  Нижнее меню: четыре вкладки. Выбранная — заливка primary-soft и закрашенная иконка primary.
- **Tab bar** (390×48) · variants Tab: Overview | Health | Passport | Documents | Feeding · text layers: label, label, label, label, label
  Вкладки страницы питомца. Прокручиваются, если не помещаются; выбранная — primary с полоской снизу.
- **List row** (358×68) · variants Leading: Avatar | Icon | None; Trailing: None | Chevron | Done | Button · props Title (TEXT = "Мурка"), Subtitle (TEXT = "Royal Canin Sterilised 37, 40 г"), Show subtitle (BOOLEAN = true) · text layers: initial, title, subtitle
  Строка списка внутри карточки: слева аватар или иконка, справа стрелка, кнопка «Готово» или кнопка действия.
- **Section header** (358×44) · variants Style: Title | Subtitle · props Title (TEXT = "Визиты"), Show action (BOOLEAN = true) · text layers: title, label
  Заголовок раздела с необязательной текстовой кнопкой справа.
- **Empty state** (390×258) · props Title (TEXT = "Пока нет питомцев"), Message (TEXT = "Добавьте первого — с него начнутся напоминания."), Show button (BOOLEAN = false) · text layers: icon/pets, title, message, label
  Пустой экран: иконка на сером круге, заголовок, строка пояснения, необязательная кнопка.
- **Select field** (358×76) · props Label (TEXT = "Тип"), Value (TEXT = "Прививка"), Show icon (BOOLEAN = true) · text layers: label, icon, value, icon/arrow_drop_down
  Поле выбора из списка (тип записи, питомец, единица).
- **Switch row** (358×68) · variants Value: On | Off · props Title (TEXT = "Действует"), Subtitle (TEXT = "Напоминать о кормлении в это время"), Show subtitle (BOOLEAN = true) · text layers: title, subtitle
  Строка с переключателем в формах и настройках.
- **FAB** (204×56) · props Label (TEXT = "Добавить питомца") · text layers: icon, label
  Плавающая кнопка списка: «Добавить питомца», «Добавить товар», «Новый визит».
- **Save bar** (390×85) · props Show error (BOOLEAN = false) · text layers: message, label
  Низ формы: кнопка «Сохранить» на всю ширину; над ней ошибка, если форма не прошла проверку.
- **Offline strip** (390×48) · props Message (TEXT = "Нет связи с сервером · данные на 14:05") · text layers: icon/cloud_off, message, label
  Полоска над нижним меню, когда сервер не отвечает: время самой старой копии на экране.
- **Skeleton** (390×288) · variants Shape: List | Form · text layers: 
  Пока данные грузятся: серые блоки line на месте будущего содержимого, по ним бежит мягкий блик (sunken).
- **Dialog** (310×256) · props Title (TEXT = "Удалить питомца по кличке Мурка?"), Message (TEXT = "Вместе с ним удалятся данные паспорта, документы и фото. Отменить это нельзя.") · text layers: title, message, label, label
  Диалог подтверждения. Опасное действие — текстовая кнопка цвета danger.
- **Bottom sheet** (390×226) · props Title (TEXT = "Купили: Royal Canin Sterilised 37"), Content (INSTANCE_SWAP) · text layers: title, Содержимое
  Нижний лист: ручка, заголовок и содержимое (свойство Content).
- **.Slot** (358×120) · text layers: Содержимое
  Заглушка содержимого нижнего листа: замените через свойство Content.
