# Robot-side issues — 2026-05-30 (from app-side debugging, Build 112)

Hand this to the WIM-Z robot/Pi Claude session. Diagnosed from app device logs +
a safety incident during local-AP (WiFi hotspot) testing. The app side has shipped
mitigations in Build 112 (see bottom), but the items below are **robot-side** and
some are mandatory for safety.

---

## R-SAFETY-1 — CRITICAL: motor command-timeout watchdog (deadman)

**Incident:** With the phone joined to the robot's AP, the user held "forward" on
the app joystick. The link dropped mid-drive and **the robot kept driving forward
indefinitely** — the user had to physically chase it down and lift it off the
ground. This is a serious safety failure.

**Why it happens:** The app sends drive commands as a continuous ~10–20 Hz
heartbeat while the stick is held. On any link loss the app necessarily STOPS
sending (it can't reach a robot it's disconnected from). The robot was executing
the last received command forever because **there is no command-timeout watchdog
on the motors.**

**Required fix (robot-side, non-negotiable):** Treat the ABSENCE of drive commands
as STOP. If no `motor` command (nor `emergency_stop`) has been received within
~**300–500 ms**, ramp the motors to zero. This is the only reliable safeguard —
the app cannot guarantee stopping a robot it can't reach.

- Apply to BOTH command transports: the WebSocket `/ws/local` path AND the WebRTC
  data-channel path.
- The Xbox/gamepad controller reportedly has a 2 s watchdog — **2 s is far too
  long** for a moving robot under app teleop. Use ≤500 ms for the app drive path.
- The command payload already carries a `timestamp` (ms since epoch) — the robot
  can use it to detect staleness, but a pure "no command in 500 ms → stop" timer
  is simpler and sufficient.

**Acceptance:** Hold forward in the app, then kill the phone's WiFi. Robot must
stop within ~0.5 s.

---

## R-2 — Confirm `/ws/local` handles `command:'motor'` and `command:'emergency_stop'`

Build 112 moves drive control onto the **WebSocket** in local AP mode (the WS is
rock-solid; the WebRTC data channel is not — see R-3). The app now sends, over
`ws://192.168.4.1:8000/ws/local`:

```json
{"type":"command","device_id":"local_robot","command":"motor",
 "data":{"left":0.5,"right":0.5},"timestamp":1730000000000}
{"type":"command","device_id":"local_robot","command":"emergency_stop","data":{}}
```

This is the same dispatch shape the robot already handles for `servo`, `treat`,
`set_mode`, `led`, `audio` over `/ws/local` (all confirmed working in the app), so
`motor` + `emergency_stop` are very likely already wired — **please confirm.** If
the local WS handler does NOT dispatch `motor`/`emergency_stop` to the motor
controller, drive will silently no-op in local mode and a Pi-side handler is
needed. This is the load-bearing assumption for the Build 112 safety changes.

---

## R-3 — WebRTC peer connection drops at ~100 s in local AP mode and never recovers

**Observed (app logs):** WebRTC connects cleanly (host-only LAN candidates,
`pc-state Connected`), runs stable for ~100 s, then `pc-state Disconnected →
Closed`. After that the robot **never sends another SDP offer** — every app
`webrtc_request` times out (15 s) with no offer. The WebSocket heartbeats never
miss during all of this, so the network/AP is fine.

**Likely causes (need robot journald to confirm):**
1. **ICE consent-freshness timeout (RFC 7675).** aiortc/aioice periodically sends
   STUN keepalives on the active pair; if the Pi's event loop is starved (Hailo
   pipeline + encode + control all competing), it misses the window and tears down
   a perfectly healthy LAN connection. The ~100 s-then-drop pattern fits a periodic
   load spike.
2. **2-connection cap leak.** The robot caps at 2 concurrent WebRTC sessions. If a
   dropped session's slot isn't freed, reconnects can't get an offer. (Build 112
   now sends `webrtc_close` + disposes before every reconnect to help free the
   slot — please verify the robot actually releases the slot on `webrtc_close`.)
3. DTLS/SRTP timeout (less likely).

**Asks:**
- Capture journald/aiortc logs around a ~100 s drop and identify which of the above.
- Confirm `webrtc_close` frees the session slot immediately on the robot.
- If consent-freshness under Pi load is the cause, consider lowering encode load
  or giving the WebRTC/aiortc loop priority. **Note:** the app no longer relies on
  WebRTC for local-mode video by default (it uses MJPEG `/camera/stream`), so this
  is now lower urgency — but the WebRTC path is still offered via a "Try WebRTC"
  button and used in cloud/relay mode.

---

## R-4 — (nice-to-have) Expose a robot identity on `GET /health`

In local AP mode the app has no trustworthy way to name the robot, so it currently
shows a neutral "Local Robot" label (Build 112 stopped it from showing the stale
saved relay id — it was displaying "Robot 02" while physically on Robot 05). If
`GET /health` (or `/telemetry`) returned a stable `robot_id` / `name` / `serial`,
the app could display the real identity in local mode. Low priority.

---

## App-side changes already shipped (Build 112) — for your context

- **Drive + e-stop now ride the WebSocket in local AP mode** (was WebRTC data
  channel). Relay mode still uses the data channel with a WS fallback. (R-2)
- **App-side deadman:** when the active motor transport drops while moving, the app
  zeros its command and fires `emergency_stop` over the surviving transport (in
  local mode the WS is usually still up, so it reaches you). This does NOT replace
  R-SAFETY-1 — when both transports are down the app can't reach you at all.
- **WebRTC reconnect hygiene:** `webrtc_close` + full PC dispose before every
  reconnect; fixed an infinite instant-reconnect loop that hammered your 2-session
  cap. (R-3)
- **Local video defaults to MJPEG** (`/camera/stream`) for reliability; WebRTC is
  opt-in via a button.
