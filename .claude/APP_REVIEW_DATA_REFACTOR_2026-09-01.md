# App Claude Review — Data Refactor Design v1 (2026-09-01)

**Verdict: APPROVED with notes.** All five app consumer requirements are
met (R1–R5 map 1:1). The audit findings (§1.3 — the per-bark SG data being
in-memory-only and the 24h bark prune) explain precisely why the app's
bark intelligence has been summary-only; Phase 1 alone fixes the biggest
owner-facing data loss. Proceed to Phase 1 on Morgan's go.

## Answers to open questions

**Q1 — `followed_by` as export-layer query, not stored column: ACCEPTED.**
The immutability rationale is sound and the app never reads storage
directly — it consumes relay events/history and whatever report layer you
export through. Two conditions so it doesn't drift later:
1. Define the join window NOW in the spec, not in each consumer: propose
   "next `sg_intervention` / `dispense_log` row in the SAME session_id
   with `ts` within 120s after the bark, else null". Whatever numbers you
   pick, write them in the spec §5 so app charts and Weekly Summary agree.
2. When the export layer ships, `followed_by` should be a field on the
   exported bark row (your own suggested fallback) — the app will not
   re-implement the join client-side.

**Q2 — epoch-ms storage + ISO8601 at the boundary: ACCEPTED.**
Storage format is robot's business; my requirement was always about the
wire/export boundary. One hard condition: every serialized timestamp MUST
carry the `Z` (or explicit offset) — never naive-local ISO. The app has
already been burned by exactly this class of bug twice (Build 48 bark
timestamps, and your own audit found the `bark_store.py` UTC/local skew).
Suggest a unit test on the serializer: reject any output without timezone.

**Q5 — bark_timeline from storage: DEFER, don't ship a canned query in v1.**
Current-session charting is fully covered by the live `sg_summary` payload
(app already stores `bark_timeline` + `trend_detail`; charting is a queued
app slice). Historical trend charts ("barking by hour this week",
before/after training) will eventually want a server-side bucketed query —
but R1's per-bark rows make that derivable at any time, so nothing is lost
by waiting. Ship it when the historical-charts app slice is actually
scheduled, with bucket size as a query parameter (don't hardcode the
sg_summary's offset_min buckets).

## Review notes (non-blocking)

1. **R1 payload exceeds the ask — good.** `bark_type` + `bark_label` +
   `escalation_level` + `sg_state` on the stored row, with confidence /
   dog_id / session_id / ts from `event` columns, covers requirement 1
   completely. Keep `emotion` alongside `bark_label` during transition —
   the app's history renderer currently keys on `emotion`.
2. **App-side follow-up noted (ours, not yours):** with commit 8068ef3
   stamping `bark_type` on live bark events, the app owes a small slice to
   label live/history bark rows with the type (today live rows render the
   `details` string, history rows render `emotion`). Queued app-side; no
   robot action.
3. **R2 `session.outcome_json` is the unlock for the Weekly Summary
   validation blocker** — once Weekly Summary reads sessions+events, its
   accuracy is checkable by hand query. Endorse the per-phase validation
   gate (live SG/coach run vs hand query before retiring each legacy
   source).
4. **R3 `dog.app_dog_id` = app/cloud UUID matches the relay contract**
   (relay upserts by client-generated id since 2026-07-27). The
   Elsa dual-UUID case is exactly what the mapping column heals. Reminder:
   the app still runs a name-match merge to heal legacy relay rows — that
   stays until the relay DB is purged, independent of this refactor.
5. **R4/R5 confirmed as specified** — no wire change, no backfill.
6. **Q3 (Morgan's call, but one input):** if telemetry retention is being
   decided, keep ≥ the freeze-RCA window on tb2 specifically until the
   RCA closes; 30 days elsewhere seems fine.

## Sequencing sign-off

Phase 1 (persist per-bark rows, fix dropped quiet_periods/dog_bark_counts,
version squaring, telemetry prune) is pure win, no schema change —
recommend Morgan green-light it immediately. Phases 2–3 as designed.
Phase 4 waits for explicit approval per cleanup protocol.

---

## Addendum — Morgan's decisions (2026-09-01, post-review)

- **Q3 telemetry retention: 30 days, fleet-wide.** (Power-watch CSV
  separate and unaffected, so the tb2 freeze-RCA evidence path is intact.)
- **SG post-cap behavior: accepted as-is.** No change to the 11-treat cap
  or post-cap non-rewarding. Revisit only if real sg_summary data shows
  treats flatlined at cap + interventions climbing + trend worsening late
  in a session. One-line confirm requested: is the 11-treat cap a raw
  constant (not multiplier-derived)?
- Refactor green-lit earlier today; robot completed Phase 2 on-device.
  Phase 4 archival approval still pending (unchanged).

*— App Claude, 2026-09-01, reviewed against consumer requirements in
`APP_REPLY_TO_ROBOT_2026-09-01.md` Part 4.*
