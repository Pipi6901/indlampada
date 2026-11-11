# -*- coding: utf-8 -*-
"""Строки контекста к стихам: глава, кто говорит и кому, при каких обстоятельствах.

Правила: только то, что общеизвестно и надёжно передаётся, без толкования и оценок; не длиннее 34 слов.
Для большинства стихов — справка по главе и говорящему, собранная из `gita.speakers.json`
(метки «उवाच» в оцифровке Безант). Для нескольких известных мест — особая строка.

Ключ строки в корпусе (`Card.passage`):
    a{глава}-{стих}  — особая справка о стихе (отрывок начинается с него)
    c{глава}{К}      — справка по умолчанию: глава и говорящий (K — Кришна, A — Арджуна, S — Санджая, D — Дхритараштра)

Названия глав — общепринятые санскритские с английским пояснением. Особые строки вычитывает человек,
знающий Гиту (см. docs/TRANSLATIONS.md).
"""

CHAPTERS = {
    1: ("Arjuna Vishada Yoga", "Arjuna’s dejection"),
    2: ("Sankhya Yoga", "the yoga of knowledge"),
    3: ("Karma Yoga", "the yoga of action"),
    4: ("Jnana-Karma-Sannyasa Yoga", "knowledge and the renunciation of action"),
    5: ("Karma-Sannyasa Yoga", "renunciation of action"),
    6: ("Dhyana Yoga", "the yoga of meditation"),
    7: ("Jnana-Vijnana Yoga", "knowledge and its realisation"),
    8: ("Aksara-Brahma Yoga", "the imperishable Brahman"),
    9: ("Raja-Vidya-Raja-Guhya Yoga", "royal knowledge, royal secret"),
    10: ("Vibhuti Yoga", "divine manifestations"),
    11: ("Vishvarupa-Darshana Yoga", "the vision of the universal form"),
    12: ("Bhakti Yoga", "the yoga of devotion"),
    13: ("Kshetra-Kshetrajna-Vibhaga Yoga", "the field and its knower"),
    14: ("Gunatraya-Vibhaga Yoga", "the three gunas"),
    15: ("Purushottama Yoga", "the supreme person"),
    16: ("Daivasura-Sampad-Vibhaga Yoga", "divine and demonic natures"),
    17: ("Shraddhatraya-Vibhaga Yoga", "threefold faith"),
    18: ("Moksha-Sannyasa Yoga", "liberation through renunciation"),
}

SPEAKER_KEY = {"Krishna": "K", "Arjuna": "A", "Sanjaya": "S", "Dhritarashtra": "D"}
SPEAKER_LINE = {
    "Krishna": "Krishna speaks to Arjuna on the battlefield of Kurukshetra.",
    "Arjuna": "Arjuna speaks to Krishna on the battlefield of Kurukshetra.",
    "Sanjaya": "Sanjaya, the narrator, describes the scene to King Dhritarashtra.",
    "Dhritarashtra": "The blind king Dhritarashtra asks his minister Sanjaya what is happening on the battlefield.",
}

# (глава, первый стих) -> особая справка
SPECIAL = {
    (1, 28): "Arjuna, seeing his kinsmen drawn up on both sides, loses heart. The Gita begins here.",
    (1, 47): "The end of the first chapter: Arjuna lays down his bow, overwhelmed by grief.",
    (2, 2): "Krishna’s first words to the despondent Arjuna.",
    (2, 3): "Krishna’s first call to Arjuna to rise from despair.",
    (2, 7): "Arjuna, confused about his duty, asks Krishna to be his teacher.",
    (2, 11): "Krishna begins his teaching: the wise do not grieve for the living or the dead.",
    (2, 47): "One of the best-known verses of the Gita, on acting without clinging to the fruits of action.",
    (4, 7): "Krishna’s promise to appear whenever righteousness declines.",
    (6, 5): "On the Self as friend and as enemy of the self; from the chapter on meditation.",
    (6, 19): "The image of a lamp in a windless place: a mind that does not waver.",
    (9, 26): "A simple offering: a leaf, a flower, a fruit or water given with devotion.",
    (10, 11): "Krishna says why he gives this wisdom: out of compassion, as a shining lamp that destroys darkness.",
    (11, 49): "From the vision of the universal form: Krishna calms the frightened Arjuna.",
    (11, 50): "From the vision of the universal form: the narrator Sanjaya tells how Krishna calmed Arjuna.",
    (18, 66): "In tradition called the ‘charama shloka’, the closing verse of surrender.",
    (18, 78): "The last verse of the Gita, spoken by the narrator Sanjaya.",
}


def passage_key(ch, a, b, speaker):
    if (ch, a) in SPECIAL:
        return f"a{ch}-{a}"
    return f"c{ch}{SPEAKER_KEY[speaker]}"


def context(key, passage):
    ch, a, b, speaker = passage
    if key.startswith("a"):
        return SPECIAL[(ch, a)]
    title, gloss = CHAPTERS[ch]
    return f"Chapter {ch}, {title} ({gloss}). {SPEAKER_LINE[speaker]}"
