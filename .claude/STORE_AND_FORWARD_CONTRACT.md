# Store-and-forward / replay-buffer contract — app ↔ relay

Date: 2026-05-30. App side implemented this session (Build 114, pending).
Relay side: per-device persistent replay buffer (sibling Lightsail Claude).

Problem this solves: the relay forwarded device→app events live and dropped
them when no app was connected for that `device_id`. SG ran all morning with the
app offline → hours of bark/activity events went nowhere. Robot is fine (it
sends every event and logs locally). Fix = a per-device replay buffer on the
relay + a watermark handshake on the app.

---

## What the app now does (shipped this session)

Files: `lib/core/network/websocket_client.dart`,
`lib/domain/providers/notifications_provider.dart`,
`lib/domain/providers/guardian_events_provider.dart`.

1. **Sends `last_seen_seq` in `session_hello`.** This is the app's connect/
   identify frame (the relay's "user_connected path"). It is already the
   mandatory first frame and carries `session_id` + `user_id` + `device_id`;
   `last_seen_seq` is now a fourth field:
   ```json
   {"type":"session_hello","session_id":"…","user_id":"user_000123",
    "device_id":"wimz_robot_01","last_seen_seq":147}
   ```
   `0` means "never seen any event for this device." One `device_id` per hello;
   on robot-switch the app reconnects with a fresh hello for the new device.

2. **Consumes buffered events** with top-level `seq`, `ts_server`, `buffered`.
   Dedups by `seq` (drops anything `<= watermark`), advances + persists the
   watermark (SharedPreferences, keyed per `device_id`) on anything newer.
   Buffered and live events both advance it.

3. **Timestamps the feed from `ts_server`** so a replayed backlog lands at its
   real time, not bunched at "now."

4. **Idempotent feed by event `id`** — see contract item C below.

---

## What the relay MUST do to match (confirm each)

### A. Read `last_seen_seq` off `session_hello`
Not a separately-typed `user_connected` message — the app puts it on the
`session_hello` frame. On (re)connect, send every buffered event for that
`device_id` with `seq > last_seen_seq`, oldest→newest, then resume live.

### B. Sequencing — AGREED: option (a), persistent per-device counter
The `seq` counter is **persisted per device across relay restarts**, so the
app's stored watermark stays comparable forever. No epoch/reset field needed.
(If this ever changes to an in-memory counter, the app silently drops every
post-restart event because its watermark outranks the fresh seqs — so do not
regress this without telling the app side.)

### C. Envelope fields are TOP-LEVEL, and `id` is shared across sources
Every feed event (buffered replay AND live) must carry, as siblings of
`type`/`device_id` (NOT nested inside `data`/`payload`):
- `seq`        — int, per-device monotonic
- `ts_server`  — ISO8601, assigned by relay on ingest
- `buffered`   — bool, `true` only on replays
- `id`         — **stable event id, identical to the matching `/api/activity`
                  row's `id`.**

Why `id` matters: the app hydrates the feed from BOTH the REST `/api/activity`
log (7-day history, on auth transitions) and the WS replay buffer (24h, on
every WS connect). On app launch both run and overlap. The app dedups the feed
by `id`, so the same underlying event must carry the same `id` in the activity
table and in the buffered WS event. If the buffer can't reuse the activity
`id`, tell the app side — we'll need a different shared dedup key.

### D. Buffer scope (relay spec, restated for confirmation)
- Buffer only feed-worthy events: `bark`, `detection`, `alert`,
  `mission_progress`, `mission_complete`, `unknown_dog_detected`.
- Exclude high-rate telemetry (battery, heartbeats, WebRTC signaling). For
  battery, keep only the latest single value on resume if desired.
- Retention: cap by count (~200) and age (~24h); evict oldest past either.
- Never clear on delivery — multiple app sessions/reconnects each catch up
  independently; eviction is age/count only.

---

## Status — RESOLVED (relay commit `a597e91`, 2026-05-30)

All items confirmed/landed on both sides; feature complete.

- **A — `last_seen_seq` on `session_hello`:** ✓ relay reads it from the hello
  frame; missing → 0 (full replay). One device_id per hello.
- **B — seq survives restart:** ✓ seq persisted to SQLite (`replay_seq`),
  seeded at **`persisted + 10`** on startup so the resumed counter always
  exceeds anything an app already saw (closes the unclean-restart reuse window).
  Buffered events themselves are in-memory and lost on restart, but the app then
  just sees an empty replay (no seq > watermark) — never duplicates.
- **C — shared dedup id:** ✓ a stable UUID is assigned once at ingest
  (`maybe_buffer_event`). Emitted **top-level as `id` on replay frames** and as
  **`event_id` on live-forwarded messages**; the `/api/activity` path reuses the
  same UUID for its DB row. **App reads either key** (`json['id'] ?? json['event_id']`)
  so live, buffered, and REST-hydrated copies of one event share an id and
  collapse to a single feed entry.
- **Envelope:** ✓ `seq`, `ts_server`, `buffered`, `id`/`event_id` are top-level
  siblings of `type`/`event`/`device_id` on every sequenced event.

App side: Build 114. Guardian-events widget also updated to ingest buffered
replays (stays subscribed across the connection lifecycle; buffered events
bypass the SG-mode gate).
