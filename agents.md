# Agent Guide

## Useful Agent Roles

### Core Logic Agent
Owns:
- Vocabulary extraction heuristics.
- Image trimming.
- Document text extraction.
- PPTX generation.

Verification:
- `swift test`

### SwiftUI App Agent
Owns:
- Import flow.
- Word review.
- Image fetch progress.
- Flashcard review.
- Export UI.

Verification:
- `swift build`
- Manual launch of packaged `.app`

### QA Agent
Owns:
- Test documents.
- End-to-end smoke test.
- Checking generated PPTX opens in PowerPoint or Keynote.
- Checking card padding and image trimming visually.

Verification:
- Open sample input.
- Fetch images for a small word list.
- Export and inspect the `.pptx`.

## Coordination Rules
- Add tests before changing extraction, trimming, or export behavior.
- Keep shared formats byte-compatible across editions (`coordination/SCHEMA.md`).

> **UPDATE 2026-06-21:** Image search now uses an **embedded web view** over
> Google/Baidu/Bing/Yandex (the old "no Google scraping" rule no longer applies).
> The project is **three editions** (macOS canonical → Windows EN → Windows ZH).
> Follow the cross-edition protocol in `coordination/README.md`: read
> `STATUS.md`/`HANDOFF.md`/`PARITY.md` before a task, log after, and never
> back-port Windows changes to Mac. Edition agent roles (mac-eng / win-en-eng /
> win-zh-eng / monitor) are described there. Licensing internals (private key,
> keygen) stay Mac-only and are never shipped.

