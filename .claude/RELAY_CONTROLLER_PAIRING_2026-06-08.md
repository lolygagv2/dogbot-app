# Relay Brief — In-App Xbox Controller Pairing (2026-06-08)

**For:** the WIM-Z Lightsail relay Claude instance.
**TL;DR:** You almost certainly need **no code change**. This note is to *confirm* two things and flag one thing to avoid.

## What's happening
App Build 127 adds a screen that drives the robot's Bluetooth stack remotely (pair an Xbox controller to the robot). It rides the **existing WebSocket command/event channel** — the same path as `motor`, `servo`, `set_mode`, `dispense_treat`. No new REST routes, no auth changes.

## New message names crossing the relay
- **Commands (app → robot):** `controller_status`, `controller_scan`, `controller_pair`, `controller_trust`, `controller_forget`, `controller_reconnect` — all wrapped in the standard `{type:'command', device_id, command, data, timestamp}` envelope.
- **Events (robot → app):** `controller_status`, `controller_scan_result`, `controller_pair_progress`, `controller_error`.

## Please confirm (1): transparent forwarding
You already forward arbitrary `{type:'command', command:X}` envelopes to the target robot and relay arbitrary robot events back to the user's socket (that's how every existing command works). **Confirm there is no per-command allowlist** that would silently drop the `controller_*` commands or events. If there is one, add the six command names + four event names above. If forwarding is generic (expected), nothing to do.

## Please confirm (2): timestamp staleness window
Commands carry `timestamp` (ms). If you reject commands older than ~2s, that's fine — these are user-initiated and fresh. Just confirm a `controller_scan`/`controller_pair` won't be dropped as stale on a slow link.

## Please AVOID (1): do not persist these to the activity feed
`controller_*` events are **transient live state**, not user-facing history. Do **not** write them into the durable activity store / `GET /api/activity`, and don't assign them store-and-forward `seq`/replay. If a controller flapping connected/disconnected got logged as activity events, it would spam the Activity + Silent Guardian feeds (which are now a single unified history source on the app side — see Builds 125/126). Treat them as pass-through only.

## No change expected to
- REST endpoints, auth/JWT, dog/voice/activity APIs, store-and-forward buffer.

That's it — this is intentionally additive and should be invisible to current beta testers. Ping back if your forwarding is *not* generic and you had to allowlist the new names.
