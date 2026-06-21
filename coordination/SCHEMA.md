# Cross-Edition Contract (SCHEMA)

Behaviors and formats that **every edition must keep identical**. Agree changes
here *before* touching code, so the Mac → Win-EN → Win-ZH ports don't drift.
When the Mac app changes one of these, update this file in the same change and
flip the PARITY rows.

## Vocabulary extraction
- Heading words (start a vocab section): key terms, key vocabulary, key words,
  keywords, spelling list, spelling words, terms to know, vocab, vocabulary,
  vocabulary list, vocabulary terms, vocabulary words, word bank, words to know.
- Stop headings (end a section): activity, answer key, comprehension, discussion,
  exercise, homework, key sentences, lesson, learning objectives, practice,
  questions, reading, review, weekly activity suggestions, worksheet, writing.
- Inline form `Heading: a, b, c` and heading-prefixed lines are supported.
- A plausible term: 1–5 words, no `.?!`, not starting with read/write/use/
  answer/define/draw. Split lists on `,` and `;`. Dedupe case-insensitively.
- Reference impl: `Sources/ClipartBrowserCore/VocabularyExtractor.swift`,
  `windows/src/lib/vocabulary.js`.

## Image search engines
- Engines (id → URL):
  - google → `https://www.google.com/search?tbm=isch&q=<term> clipart>`
  - baidu  → `https://image.baidu.com/search/index?tn=baiduimage&ie=utf-8&word=<term> clipart`
  - bing   → `https://www.bing.com/images/search?q=<term> clipart`
  - yandex → `https://yandex.com/images/search?text=<term> clipart`
- Win-ZH overrides the clipart qualifier to `剪贴画` and the engine display names
  to 谷歌/百度/必应/Yandex.
- Picker full-size extraction keys: Google `a[href*=imgurl=]` → `imgurl`/`imgrefurl`;
  Baidu `[data-objurl]`/`[data-thumburl]`; Bing `a.iusc` `m` JSON `murl`/`turl`;
  Yandex `.serp-item[data-bem]` → `serp-item.img_href`/`preview`. Always fall back
  to the visible thumbnail.

## Image pipeline
pick → **bigger-of-two download** (full vs thumbnail, keep larger decoded; desktop
UA + referer) → **white-trim** (tolerance 245, alpha ≤ 8) → **fit-to-slide** pixel
size → **upscale-only** (never shrink below source) Lanczos → embed.

## PPTX (OOXML)
- Letter slide EMU: portrait `7772400 × 10058400` (swap for landscape).
- `EMU_PER_PX = 9525`; label height `720000`; label gap `120000`.
- Fitted image frame centers the image in `slide − padding − reservedLabel`.
- Package layout: `[Content_Types].xml`, `_rels/.rels`, `docProps/{core,app}.xml`,
  `ppt/presentation.xml` (+rels), one `ppt/slides/slideN.xml` (+rels) + media per
  card, `slideMasters/`, `slideLayouts/`, `theme/`.
- Reference impl: `Sources/ClipartBrowserCore/PowerPointExporter.swift`,
  `windows/src/lib/pptx.js`.

## Word list
- `N - TitleCasedWord` per line; `.txt` (UTF-8) or minimal `.docx` (one paragraph
  per line). Reference: `WordListExporter.swift`, `windows/src/lib/wordlist.js`.

## Settings & defaults
- padding 12 px (0–72), orientation portrait/landscape, labels show/hide,
  upscaler method default = "Sharpest detail" (Lanczos), export base name default
  "Vocabulary Flashcards" (ZH: "词汇卡片").

## Localization (Windows-ZH) — interface only, NOT content
Win-ZH translates the **interface only**: labels, status messages, engine display
names (谷歌/百度/必应/Yandex), window title. It does **NOT** translate document
content. Vocabulary words are extracted and searched **as-is** — English or
Chinese, whatever the document contains — with only the search qualifier changed
from `clipart` to `剪贴画`. Dropping an English doc into the ZH app yields the
English words searched on the chosen engine; there is no auto-translation of the
word list. (Extraction logic is byte-identical to Win-EN; only UI strings + the
qualifier differ.)
