# Cross-Edition Coordination ("Karpathy loop")

This repo ships **three editions of ClipartBrowser**:

- **macOS** (Swift) — repo root, `main` — **the source of truth**
- **Windows EN** (Electron) — `windows/`, `main`
- **Windows ZH** (Electron, 简体中文) — `zh-CN` branch (= Win-EN + translation)

Coordination uses the **filesystem as the shared bus**. Changes flow **one way**:
**Mac → Win-EN → Win-ZH**. Windows changes are never back-ported to Mac.

```
mac (canonical) ──► win-en ──► win-zh
        │             │           │
        └──────► HANDOFF.md / PARITY.md / SCHEMA.md ◄───────┘
                          │
                      watcher  ──►  STATUS.md  (CLEAR / CONFLICT)
```

## Files
- **HANDOFF.md** — append-only log of what changed and what downstream must adapt.
- **PARITY.md** — feature × edition matrix; the actionable backlog (🔧 = needs-port).
- **SCHEMA.md** — the shared contract (formats/behaviors all editions keep identical).
- **STATUS.md** — CLEAR/CONFLICT flags from the watcher; read before each task.
- **watch.sh / monitor.py** — the continuous watcher (you start it; see below).
- **fetch-builds.sh** — download all release installers into `../builds/`.

## Protocol (also embedded in each CLAUDE.md)
1. **Before a task:** read STATUS.md (STOP if CONFLICT), HANDOFF.md (last ~20),
   PARITY.md, and the relevant SCHEMA.md sections.
2. **After a change:** append a HANDOFF.md entry; update PARITY.md cells; if a
   shared contract changed, update SCHEMA.md in the same change.
3. **Conflict?** STOP, write a `CONFLICT:` line to STATUS.md, notify the lead.

Per-edition duties:
- **mac** (canonical): build the feature, then flip the affected PARITY rows'
  `win-en`/`win-zh` cells to 🔧 and update SCHEMA.md if a contract changed.
- **win-en**: port 🔧 rows from Mac (`windows/` on `main`), set `win-en` ✅.
- **win-zh**: merge `main` into `zh-CN`, translate new strings, set `win-zh` ✅.

## Roles (if you run a Claude Code agent team)
- `mac-eng` — Swift, edits root sources only.
- `win-en-eng` — JS, edits `windows/` only.
- `win-zh-eng` — `zh-CN` branch, mirrors win-en + translates.
- `monitor` — read-only; runs the conflict check, writes STATUS.md, never edits code.

**Lead prompt:** "After each teammate finishes a task they update HANDOFF.md and
PARITY.md; all others read HANDOFF.md + STATUS.md before claiming their next task.
If anyone flags a CONFLICT in STATUS.md, pause the team and resolve before
continuing. Propagate features strictly Mac → Win-EN → Win-ZH."

## Start simple (recommended order)
1. Drive one real change **by hand**: change Mac, append HANDOFF, flip PARITY —
   feel the cadence.
2. Turn on the **watcher**: `brew install fswatch` then `coordination/watch.sh`
   (or `pip install watchdog` then `python coordination/monitor.py`).
3. Then, if you want, run the **agent team** with the lead prompt above.

The per-task hooks in `.claude/settings.json` already inject HANDOFF/STATUS context
at the start of every task and remind you to log on stop.

## Limitations (be realistic)
- Agents read these files **when triggered**, not truly continuously — the loop
  granularity equals the trigger frequency (per task is the sweet spot).
- The watcher spends one `claude -p` call per HANDOFF change.
- **Mac → Windows is a re-implementation (Swift → JS), done by an agent or you —
  not an automatic build.** This system tracks and de-conflicts that work; it does
  not write the port for you.
- `zh-CN` must periodically `git merge main` to pick up Win-EN changes.
