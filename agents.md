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
- Do not replace no-key image providers with Google scraping.
- Keep Google support as an optional Custom Search API provider if added.
- Do not rely on command-line tools at runtime.
- Add tests before changing extraction, trimming, or export behavior.

