# Windows Edition — Claude Notes

This folder is the **Windows EN** edition (Electron). The `zh-CN` branch is the
**Windows ZH** edition (this app + Simplified-Chinese strings).

## Role
Mirror the macOS app's behavior in JavaScript. macOS (repo root, Swift) is the
**source of truth** — features flow Mac → Win-EN → Win-ZH and are never
back-ported. Keep pure-JS/WASM deps only (no native modules) so CI stays simple.

## Layout
- `src/main.js` — Electron main: window, `download-bigger`, `pick-save-path` /
  `write-file`.
- `src/renderer.js`, `src/index.html` — the UI.
- `src/lib/*` — ported logic: `engines`, `vocabulary`, `extract`, `imageproc`,
  `pptx`, `wordlist`. `src/webview-preload.js` — the universal picker.
- `test-logic.js` — `node test-logic.js` checks the pure-logic ports.

## Cross-edition coordination (one-way: Mac → Win-EN → Win-ZH)
Follow `../coordination/README.md`:
- **Before a task:** read `../coordination/STATUS.md` (STOP if CONFLICT),
  `../coordination/HANDOFF.md` (last ~20), `../coordination/PARITY.md`, and the
  relevant `../coordination/SCHEMA.md` sections.
- **Win-EN:** port the 🔧 rows from Mac, append a HANDOFF entry, set `win-en` ✅.
- **Win-ZH** (`zh-CN`): merge `main`, translate new strings, set `win-zh` ✅.
- Keep shared formats (PPTX OOXML, vocabulary rules, engine list, pipeline)
  byte-compatible with `SCHEMA.md`.

## Engineering Principles
- **Think Before Coding:** Stop, state your assumptions explicitly, and name what you don't understand before writing a single line.
- **Simplicity First:** Write the minimal code required to solve the problem — nothing more.
- **Surgical Changes:** Touch only what is necessary and match existing style. Do not refactor speculative areas.
- **Goal-Driven Execution:** Transform vague tasks into verifiable goals with strict testing criteria.

codex is going to check your work
