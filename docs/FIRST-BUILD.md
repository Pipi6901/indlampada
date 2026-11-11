# До первой сборки: что нужно завести и вписать

В репозитории стоят **заглушки** вместо всего, что принадлежит владельцу аккаунтов. Ключи и пароли в репозиторий не
кладутся: публичны по замыслу только ключ RevenueCat (`appl_…`) и `GoogleService-Info.plist`.

## Идентификаторы

| Что | Значение в репозитории | Что сделать |
|---|---|---|
| Bundle ID приложения | `com.astonio.deepam` | создать App ID на портале Apple (Push Notifications, App Groups) |
| Bundle ID виджета | `com.astonio.deepam.widgets` | создать App ID (App Groups) |
| Группа приложений | `group.com.astonio.deepam` | создать и подключить к обоим App ID; без неё виджет молча покажет настройки по умолчанию |
| Команда Apple | `VG9U7V4AAL` (`App/make_project.py`) | заменить, если приложение выпускается под другой командой |
| Название | Deepam | проверить на занятость в App Store, среди товарных знаков и в поиске; при смене — `PRODUCT_BUNDLE_IDENTIFIER`, `Legal.swift`, строки интерфейса (`tools/i18n/gen_strings.py`), `README` |
| Apple ID приложения в App Store Connect | `CHANGE_ME_APP_STORE_APPLE_ID` (`codemagic.yaml`) | после создания записи приложения вписать числовой Apple ID; пока там заглушка, сборка в Codemagic нарочно не стартует |

## Подписки и RevenueCat

- Три плана — неделя, месяц, год (`PaywallPlan.swift`), пробный период у каждого свой, срок берётся из магазина.
- Доступ — по `entitlement` **`deepam_pro`** (`Purchases+Deepam.swift`). Пакеты в offering: `$rc_weekly`, `$rc_monthly`,
  `$rc_annual`; приветственное предложение — пакет с идентификатором `welcome`.
- Ключ RevenueCat: `DeepamApp.swift`, константа `revenueCatKey`. **Сейчас пуста — это значит «RevenueCat в сборке нет»,
  платный экран работает как витрина.** Ключ чужого приложения вписывать нельзя: покупки уйдут не туда. В Release
  годится только боевой ключ `appl_…`; тестовый `test_…` роняет приложение при запуске (так задумано SDK).

## Firebase, рассылки и статистика

- Файл `GoogleService-Info.plist` проекта Firebase положить в `App/Deepam/`. Без него Firebase не поднимается, всё
  остальное работает.
- Для рассылок нужен ключ APNs, загруженный в проект Firebase; у `Deepam.entitlements` стоит `aps-environment =
  development`, в боевой подписи Xcode меняет его на `production` сам.
- Amplitude (`AmplitudeAPIKey`) и Meta (`FacebookAppID`, `FacebookClientToken`) — в `App/DeepamInfo.plist`, пустые. Пока
  они пусты, эти SDK не работают. **Если их подключать — сначала обновить политику конфиденциальности
  (`tools/legal/en/privacy.html`) и анкету App Privacy в App Store Connect, а для Meta вернуть текст окна отслеживания
  (`TRACKING = True` в `make_project.py`).**

## Политика конфиденциальности и поддержка

- Тексты — `tools/legal/en/`, сборка — `python tools/legal/build_legal.py` → `docs/legal/deepam/` (отдельные
  страницы) и `docs/legal/google-sites/` (для встраивания в Google Sites).
- В `DeepamCore/Legal.swift` стоит адрес `https://sites.google.com/view/deepam-app/privacy` — **это заглушка**: сайт
  нужно создать (или заменить адрес на свой). Тот же адрес нужен в App Store Connect (политика конфиденциальности).
- Почта поддержки в страницах — `help@pmoffice.space` (из шаблонов команды); замените на нужную:
  `python tools/legal/build_legal.py --email ваш@адрес`.
- Оператор данных в тексте — Astonio Ltd; если приложение выпускает другое лицо, замените в `tools/legal/en/*.html`.

## Codemagic

- Приложение добавить в Codemagic из этого репозитория; в группу переменных `app_store_vars` — `CERTIFICATE_PRIVATE_KEY`
  (приватный ключ distribution-сертификата команды) и, если нужен «пульс» виджета, `GA_MP_SECRET`. Интеграция
  `Astonio` (ключ App Store Connect) в `codemagic.yaml` названа по команде — имя должно совпадать с записью в
  Codemagic посимвольно.
- Запуск — кнопкой «Start new build» или тегом: `git tag build-1 && git push origin build-1`.

## Что стоит проверить до отправки на ревью

- Подборку стихов по состояниям должен вычитать знаток Гиты (`docs/TRANSLATIONS.md`).
- Статус текста (общественное достояние) подтвердить; при необходимости оставить только уведомление об источнике.
- Рядом с иконками и фонами нет людей, божеств и животных — это сознательное решение; если вы захотите изобразить
  божество, подумайте, как это воспримут верующие.
- Скриншоты для App Store и тексты карточки приложения ещё не сделаны.
