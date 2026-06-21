# Project Context

> **UPDATE 2026-06-21 — current reality (see `restart.md` for full state).**
> The sections below are the *original* brief and are now partly superseded:
> - It **is** a git repo (github.com/davidgrahamsites/clipartbrowser) with **three
>   editions**: macOS (Swift, source of truth), Windows EN (`windows/`, Electron),
>   Windows ZH (`zh-CN` branch).
> - Image search is **not** Openverse/Wikimedia. It uses an **embedded web view**
>   over **Google/Baidu/Bing/Yandex** with a full-size picker + bigger-of-two
>   download.
> - Added since: PDF/RTF/OCR import, 4 search engines, Lanczos upscaler + preview,
>   `.txt`/`.docx` word-list export, **one-per-computer Ed25519 licensing** +
>   `ClipartKeygen.app`, CI Windows installers, GitHub releases (`v0.2.0`).

## User Request
Create a Mac M1 app that can:
- Import documents with lists of vocabulary words.
- Distinguish vocabulary words from ordinary body text by detecting sections like "Vocabulary", "Vocabulary Words", "Key Words", "Word Bank", or similar headings.
- Preserve the order vocabulary words appear in.
- Search online for clipart images for each vocabulary word.
- Trim image white padding.
- Create portrait letter flashcards.
- Size images as large as possible while leaving about 12 px of padding by default.
- Make padding adjustable with a slider or numeric input.
- Continue processing all words automatically.
- Show all flashcards for review before exporting.
- Export a PowerPoint `.pptx`.
- Compile to a `.app`.
- Run everything inside the `.app`.

## Important Product Detail
Google Images is not the default provider because it does not offer a simple no-key public image search API. Direct scraping is fragile and often blocked. The first version should use no-key sources such as Openverse and Wikimedia Commons, while keeping image search provider-based so Google Custom Search can be added later if the user provides an API key and search engine ID.

## Current Workspace
Path: `/Users/appleadmin/Apps/ClipartBrowser`

The repository started empty and is not currently a git repository.

