# Перенос проекта в Godot: от скачивания до APK на телефоне

Инструкция по шагам. Примеры путей — для Windows; на macOS и Linux всё так же, отличаются только пути.

## 0. Что понадобится

| Что | Зачем | Где взять |
|---|---|---|
| Godot **4.7** (стандартная версия, не .NET) | Редактор | godotengine.org → Download |
| Шаблоны экспорта 4.7 | Сборка APK/AAB и веб-версии | Скачиваются из самого Godot (шаг 6) |
| JDK **17** | Сборка под Android | adoptium.net → Temurin 17 (LTS) |
| Android SDK | Сборка под Android | Android Studio → SDK Manager (шаг 7) |
| Телефон с отладкой по USB | Проверка на устройстве | Шаг 9 |

Для того чтобы просто открыть игру и играть на компьютере, хватит пунктов 1–5. Android — с шага 6.

## 1. Сохраните старую версию

Если у вас открыт старый проект из `block-puzzle.zip`, **не копируйте новые файлы поверх него**: код переписан почти целиком, старые файлы будут мешать. Переименуйте старую папку (например, в `block-puzzle-old`) или заархивируйте её. Сохранения прогресса лежат не в папке проекта, их это не затронет.

## 2. Скачайте новую версию

**Вариант А — без git (проще):**
1. Откройте репозиторий `mortyc126-debug/puzzle` на GitHub.
2. Слева вверху переключите ветку на `ccr-124ff7a5-tiiaj8` (или на `main`, если изменения уже туда слиты).
3. **Code → Download ZIP**, распакуйте в новую пустую папку, например `C:\Games\block-puzzle`.

**Вариант Б — через git (удобно получать обновления):**
```
git clone https://github.com/mortyc126-debug/puzzle.git block-puzzle
cd block-puzzle
git checkout ccr-124ff7a5-tiiaj8
```
Потом новые правки забираются одной командой `git pull`. Если командная строка неудобна — GitHub Desktop делает то же кнопками.

В папке должны быть `project.godot`, `game.tscn`, папки `autoload`, `core`, `themes`, `assets` и другие. Если `project.godot` оказался во вложенной папке (`puzzle-ccr-.../project.godot`) — работайте с ней.

## 3. Откройте проект

1. Запустите Godot 4.7 → в менеджере проектов **Import** (Импорт).
2. Укажите `project.godot` из новой папки → **Import & Edit**.
3. Первый запуск займёт 10–30 секунд: Godot импортирует шрифты, SVG и звуки и создаст папку `.godot/` и файлы `.import`. Это нормально, их не нужно отправлять в git (они уже в `.gitignore`).
4. Если в менеджере проектов осталась запись старого проекта с тем же именем — удалите её из списка (**Remove**, без удаления файлов), чтобы не путать.

Если после первого открытия внизу во вкладке **Output** (Вывод) красные ошибки про «не найден ресурс» — выполните **Project → Reload Current Project**: часто это просто порядок импорта при первом запуске.

## 4. Запустите и проверьте

**F5** — запуск игры. Окно игры портретное, 900×1600 с уменьшением под экран.

Что пройти за 10 минут:
- [ ] Перетаскивание фигур, очистка линий, серия, всплывающие очки
- [ ] Бонусы: молоток, поворот, перемешивание, отмена — иконки и ценники на месте
- [ ] Проигрыш → «Продолжить» → итоги партии с наградами, кнопка «Надеть»
- [ ] Профиль: вкладки, смена темы, аватарки, рамки, эффекты, путь наград
- [ ] Настройки: звук, музыка, вибрация, спокойный режим
- [ ] Задания дня и ежедневная награда
- [ ] Русский текст новым шрифтом, нигде не вылезает за края

**F12** во время игры сохраняет скриншот 900×1600 для магазина.

**Где лежат сохранения:** **Project → Open User Data Folder** (на Windows это `%APPDATA%\Godot\app_userdata\BlockPuzzle\`). Файлы `progression.save`, `achievements.save`, `settings.save`, `missions.save`, `run.save`. Старый прогресс подхватится и обновится до нового формата сам. Чтобы начать с нуля — закройте игру и удалите эти файлы (сначала скопируйте, если жалко).

Если что-то сломалось — пришлите текст из вкладки **Output** или **Debugger → Errors** и скриншот.

## 5. Тесты логики (по желанию)

Из папки проекта в командной строке:
```
"C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path . -s tests/test_core.gd
```
(путь — к вашему файлу Godot; на Windows берите версию с `_console`, чтобы видеть вывод). В конце должна быть строка `Проверок: N, ошибок: 0` и ни одной строки `FAIL`.

## 6. Шаблоны экспорта

**Editor → Manage Export Templates → Download and Install.** Нужны и для Android, и для веб-версии. Версия шаблонов должна совпадать с версией редактора.

## 7. Подготовка к сборке под Android (один раз)

**JDK 17.** Установите Temurin 17 (на Windows — `.msi`, галочка «Set JAVA_HOME»). Более новые JDK официально поддерживаются, но 17 — самый надёжный вариант для сборки Godot.

**Android SDK через Android Studio:**
1. Установите Android Studio, на стартовом экране **More Actions → SDK Manager**.
2. Вкладка **SDK Platforms**: отметьте **Android 15 (API 35)** и **Android 16 (API 36)** — проект собирается с target SDK 36, который требует Google Play.
3. Вкладка **SDK Tools**, включите **Show Package Details** и отметьте:
   - Android SDK Build-Tools **35.0.1**
   - Android SDK Command-line Tools (latest)
   - Android SDK Platform-Tools
   - CMake **3.10.2.4988404**
   - NDK (Side by side) **28.1.13356709**
4. **Apply**. Запомните путь **Android SDK Location** вверху окна (обычно `C:\Users\<имя>\AppData\Local\Android\Sdk`).

То же без Android Studio — через command-line tools:
```
sdkmanager --sdk_root=<путь_к_sdk> "platform-tools" "build-tools;35.0.1" "platforms;android-35" "platforms;android-36" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709"
```

**Пути в Godot:** **Editor → Editor Settings → Export → Android**:
- **Java SDK Path** — папка JDK 17, например `C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot`
- **Android SDK Path** — путь из SDK Manager (в нём есть папка `platform-tools`)
- **Debug Keystore** — обычно Godot создаёт отладочный ключ сам. Если поле пустое и экспорт ругается, создайте ключ командой ниже и укажите его (пользователь `androiddebugkey`, пароль `android`):
  ```
  keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
  ```

**Шаблон сборки:** **Project → Install Android Build Template** → **Install**. Появится папка `android/` — в git её не отправляйте (она уже в `.gitignore`). После обновления Godot до новой версии шаблон нужно установить заново.

Первая сборка через Gradle идёт 5–10 минут и требует интернет — Gradle скачивает зависимости. Следующие — быстрее.

## 8. Ключ подписи для выпуска (один раз)

Для магазина нужен свой ключ. Создайте его **вне папки проекта**:
```
keytool -v -genkey -keystore blockpuzzle-release.keystore -alias blockpuzzle -keyalg RSA -validity 10000
```
Программа спросит пароль и имя — запишите пароль.

В **Project → Export → Android → Keystore**:
- **Release** — путь к `blockpuzzle-release.keystore`
- **Release User** — `blockpuzzle`
- **Release Password** — ваш пароль

Godot хранит пароли в `.godot/export_credentials.cfg`, который не попадает в git. Сам файл ключа **сохраните в двух местах** (облако + флешка): обновления в магазин подписываются им же. Если включить в Google Play подписание приложений Google (Play App Signing — по умолчанию включено), потерянный ключ загрузки можно перевыпустить через поддержку, но это долго.

## 9. Игра на своём телефоне

1. На телефоне: **Настройки → О телефоне** → 7 раз нажмите на **Номер сборки** → появятся **Для разработчиков** → включите **Отладка по USB**.
2. Подключите телефон кабелем, на телефоне разрешите отладку для этого компьютера.
3. В Godot справа вверху появится значок Android — нажмите, игра соберётся и запустится на телефоне. Это самый быстрый способ проверять правки.

**Или APK-файлом:** **Project → Export → Android** → в **Gradle Build → Export Format** выберите **APK** → **Export Project** → включите **Export With Debug** для проверки → сохраните `build/android/BlockPuzzle.apk` → перекиньте на телефон и установите (разрешите установку из неизвестных источников).

## 10. Сборка для Google Play

**Project → Export → Android**:
1. **Export Format** — **AAB**.
2. **Version → Code** — увеличивайте на 1 при каждой загрузке (1, 2, 3…), **Name** — видимая версия (`0.5.0`).
3. **Export Project** → снимите **Export With Debug** → `build/android/BlockPuzzle.aab`.

Дальше — [docs/RELEASE.md](RELEASE.md): страница в магазине, закрытый тест, анкеты.

## 11. Веб-версия (по желанию)

1. **Project → Export → Web → Export Project** → `build/web/index.html`.
2. Проверить локально: значок **Remote Deploy → Run in Browser** вверху справа (открыть `index.html` двойным щелчком не получится — браузер блокирует файлы с диска).
3. Для itch.io: заархивируйте содержимое `build/web` в ZIP и загрузите как HTML-проект.

## Если что-то не так

| Сообщение или симптом | Что сделать |
|---|---|
| «Android build template not installed» | Шаг 7 → Install Android Build Template |
| «Invalid Java SDK path» / ошибка Gradle про Java | Укажите JDK 17, не JRE и не папку `bin` |
| Gradle: не найдены build-tools, platform 36, NDK | Доустановите в SDK Manager нужные версии (шаг 7) |
| «No export template found» | Шаг 6 — шаблоны той же версии, что и редактор |
| Значка Android вверху нет | Нет пресета Android или телефон не виден: проверьте кабель (не только зарядка), разрешение отладки, команду `adb devices` |
| На телефоне «Приложение не установлено» | Стоит старая сборка с другим ключом подписи — удалите её (прогресс на телефоне сотрётся) |
| Вместо букв квадраты или старый шрифт | Выделите `assets/fonts/*.ttf` → вкладка **Import** → **Reimport**, затем перезапустите редактор |
| Иконки или аватарки мыльные | Выделите SVG → **Import** → **Scale** 2 → **Reimport** |
| Красные ошибки сразу после первого открытия | **Project → Reload Current Project** |
| Ошибки скриптов (Parse Error) | Пришлите текст ошибки целиком — поправлю |
