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

codex is going to check your work

