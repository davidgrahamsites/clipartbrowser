# Claude Project Notes

## Role
Act as a senior macOS SwiftUI engineering partner for this project. Prefer native Apple APIs, keep the app self-contained at runtime, and preserve a simple path to a compiled `.app`.

## Product Goal
Build a Mac Apple Silicon app that imports documents containing vocabulary sections, finds the vocabulary words in order, searches online for clipart-style images, trims white image padding, creates portrait letter flashcards, previews every card, and exports a PowerPoint `.pptx`.

## Working Style
- Read local context before making assumptions.
- Keep implementation scoped to the native Mac app.
- Use tests for parsing, image processing, and PPTX generation.
- Avoid runtime shell tools. Runtime behavior should live inside the app.
- Keep UI practical for teachers: import, review words, fetch images, review cards, export.

## Current Architecture
- Swift Package project.
- `ClipartBrowser` executable target for the SwiftUI app.
- `ClipartBrowserCore` library target for testable logic.
- Unit tests in `ClipartBrowserTests`.
- ZIPFoundation is used for `.docx` reading and `.pptx` writing.

## Cross-edition coordination (one-way: Mac → Win-EN → Win-ZH)
This repo ships three editions: macOS (this Swift app, **the source of truth**),
Windows EN (`windows/`, `main`), and Windows ZH (`zh-CN` branch). Full protocol in
`coordination/README.md`.
- **Before any task:** read `coordination/STATUS.md` (STOP if it says CONFLICT),
  `coordination/HANDOFF.md` (last ~20 entries), and `coordination/PARITY.md`.
- **After any change:** append a `coordination/HANDOFF.md` entry; update
  `coordination/PARITY.md` cells; update `coordination/SCHEMA.md` if a shared
  contract changed.
- When you change a Mac feature, set the affected Windows cells in `PARITY.md` to
  🔧 (needs-port) so the downstream Windows editions know to follow. Never
  back-port Windows changes into the Mac app.

## Engineering Principles
- **Think Before Coding:** Stop, state your assumptions explicitly, and name what you don't understand before writing a single line.
- **Simplicity First:** Write the minimal code required to solve the problem — nothing more.
- **Surgical Changes:** Touch only what is necessary and match existing style. Do not refactor speculative areas.
- **Goal-Driven Execution:** Transform vague tasks into verifiable goals with strict testing criteria.

codex is going to check your work

