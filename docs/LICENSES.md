# Сторонние компоненты и тексты

Сведения о лицензиях даны по информации самих проектов на момент создания репозитория; перед выпуском их стоит
сверить с актуальными текстами лицензий.

## Тексты

| Что | Источник | Лицензия |
|---|---|---|
| Санскритский текст и английский перевод Бхагавад-гиты | Annie Besant, *The Bhagavad-Gita*, 4-е изд., 1922 (оцифровка — английская Викитека) | общественное достояние; подробности — `docs/TRANSLATIONS.md` |
| Сверочная запись санскрита | проект [gita/gita](https://github.com/gita/gita) | Unlicense; используется только для сверки, в приложение и в репозиторий кода не входит (в `corpus-src/gita.crosscheck.json` лежит копия для воспроизводимой сверки) |

## Шрифты

Все шрифты — SIL Open Font License 1.1: их можно встраивать в приложение; продавать шрифты отдельно нельзя.

| Шрифт | Где | Заметка |
|---|---|---|
| Tiro Devanagari Sanskrit | санскритский текст | © 2020 The Indigo Project Authors (Tiro Typeworks); текст лицензии — `docs/licenses/OFL-TiroDevanagariSanskrit.txt` |
| Literata, Lora, Bitter, Vollkorn, Alegreya, Cormorant Garamond, Manrope, Onest | выбор шрифта в «Виде» | OFL; файлы — `DeepamCore/Sources/DeepamUI/Resources/Fonts/` |

## Библиотеки (подключаются в `App/make_project.py` и `DeepamCore/Package.swift`)

| Библиотека | Для чего | Лицензия |
|---|---|---|
| purchases-ios-spm (RevenueCat) | подписки | MIT |
| firebase-ios-sdk (Analytics Core, Messaging) | статистика и рассылки; без `GoogleService-Info.plist` не запускается | Apache 2.0 |
| Amplitude-Swift | удержание и когорты; без ключа не запускается | MIT |
| facebook-ios-sdk (FacebookCore) | реклама приложения; без ключей и согласия не запускается | лицензия проекта Meta |

## Графика

Весь рисунок (фоны, иконки приложения, арт онбординга) создан кодом из `tools/art/` без нейросетей и без чужих картинок.
Изображений людей, божеств и животных нет.
