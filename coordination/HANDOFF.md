# HANDOFF Log

Append-only coordination log. **Append, never overwrite** (avoids races). Newest
entries at the bottom. One entry per completed change.

Entry template:
```
### <ISO-8601 timestamp> · <edition: mac | win-en | win-zh> · <author>
- Changed: <what you did>
- Affects: <API surface / data shape / pipeline / file format / shared contract>
- Others must adapt: <what downstream editions need to do, or "nothing">
```

---

### 2026-06-20 · all · setup
- Changed: Established the cross-edition coordination layer (HANDOFF, PARITY,
  SCHEMA, STATUS) and the one-way protocol Mac → Win-EN → Win-ZH.
- Affects: process only.
- Others must adapt: read this file + STATUS.md before each task; log here after.
