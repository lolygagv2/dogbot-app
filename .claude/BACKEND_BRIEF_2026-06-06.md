# Backend Brief — Silent Guardian Event History (2026-06-06, app Build 125)

**From:** App Claude · **To:** Relay Claude + Robot Claude
**Why:** The app now correctly fetches and displays the full activity/SG event
history whenever the user opens OR resumes the app (the "open the app hours
later, review the whole day" use case). The app side is fixed and shipped in
Build 125. **But the history can only show what the backend actually stored.**
This brief defines the contract the app depends on, and asks you to confirm (or
fix) each item. Items marked **VERIFY** are likely already true; **CONFIRM/FIX**
need a definite answer.

---

## The core requirement

When a user starts Silent Guardian, closes/backgrounds the app for hours, then
reopens it, the app calls `GET /api/activity?since=<7d ago>&limit=200` and
renders whatever comes back. For that to contain the missed events:

1. The **robot must keep sending SG/detection/bark events to the relay the whole
   time SG runs — even when NO phone app is connected.** If events are only
   emitted to a live app WS, the backlog never exists and no app fix can show it.
2. The **relay must persist those events durably** (survives relay restart) and
   serve them via `GET /api/activity`, scoped to the authenticated user.

These two are the make-or-break. Everything else is detail.

---

## Relay — `GET /api/activity`

**CONFIRM/FIX:**
- Events are persisted **durably in sqlite** (the `activity_events` table or
  equivalent), NOT only in the ~24h in-memory WS store-and-forward buffer. The
  app pulls `since` up to **7 days** back.
- Query params honored: `since` (ISO-8601 UTC), `limit` (app sends 200),
  `dog_id` (optional filter), `cursor` (pagination). Response shape:
  `{ "events": [ ... ], "next_cursor": "<str|null>" }`.
- **Robot→relay ingestion is independent of app presence.** Confirm the relay
  writes robot events to `activity_events` whenever the robot is connected,
  regardless of whether any phone WS is attached to that user/device.

**Per-event schema the app parses** (see `_activityEventToNotification` in
`lib/domain/providers/notifications_provider.dart`). Each row must provide:
| field | notes |
|-------|-------|
| `id` | **stable, unique** — the app de-dups by id across the REST hydrate and the WS replay. A regenerated id per delivery breaks dedup. |
| `type` | one of: `bark`, `behavior_flag`, `treat_dispensed`, `coach_reward`, `guardian_alert`, `mission_started`, `mission_completed` |
| `timestamp` | ISO-8601, **server authoritative time** (when it happened), not delivery time |
| `dog_id` | the dog the event is attributed to (nullable) |
| `payload` | type-specific map: e.g. `behavior_flag` → `{behavior: "sit"|"bark"|...}`, `bark` → `{emotion?}`, `treat_dispensed` → `{treats_remaining_after?}`, `coach_reward` → `{trick, success}`, `guardian_alert` → `{reason, severity}`, `mission_*` → `{mission_id, success?}` |

**VERIFY:**
- WS store-and-forward: on `session_hello` the app sends `last_seen_seq`; relay
  replays buffered events tagged `buffered:true` with the same stable `id` and
  `ts_server`. Confirm retention window (app assumes ~24h) and that replayed ids
  match the REST ids (so the two sources dedupe cleanly).

## Robot — event emission (robots FROZEN in beta; likely VERIFY-only)

**CONFIRM (no code change expected — just confirm current behavior):**
- While Silent Guardian mode is active, the robot emits detection / bark /
  guardian events to the relay **continuously**, independent of whether a phone
  app is connected. (This is the data that makes the "2 hours of backlog" exist.)
- Each emitted event carries: `dog_id` (resolved from the ArUco→profile match),
  a `type` from the list above, a **stable `id`**, and a real `timestamp`.

If the robot today only emits events when an app is subscribed, that is the root
data gap — flag it. Given the beta freeze, if it can't be changed robot-side,
note it so we set tester expectations (cloud history will be limited to
app-connected windows until the freeze lifts).

---

## Explicitly NOT in scope this pass
- **True background push (FCM/APNs).** The app has only `flutter_local_notifications`,
  which fires while the app process is alive — there is no server push that wakes
  a killed app. Real "ping my phone while the app is closed" needs: an app FCM/APNs
  integration + a device-token registration endpoint on the relay + the relay (or
  robot) triggering pushes on events. That's a separate, larger track — not now.

## What the app already does (Build 125), for context
- Removed all fake/mock event + stat data (was masking this very bug).
- Unified the SG feed and Activity list into one history source.
- Hydrates `GET /api/activity` on login AND on app resume (was login-only).
- So: the moment the relay serves real history, the app will display it in both
  the Activity tab and the SG feed with no further app change.
