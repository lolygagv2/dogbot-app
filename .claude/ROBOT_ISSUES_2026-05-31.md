# Robot-side issues — 2026-05-31 (local-AP video + AP self-teardown)

From an app-side debugging session on the Phone→Robot local-AP path. Build 115
ships the app-side video fixes (see bottom). The items below are **robot-side**
and the AP teardown is the show-stopper.

---

## R-AP-1 — CRITICAL: robot kills its own AP ~1s after the phone associates

**This is why "the connection feels shaky" and "WIMZ-Demo never came back."**
It is not an app problem — the app cannot keep an AP alive that the robot tears
down.

**User's timelog (annotated):**
```
17:29:34  AP "WIMZ-Demo-5220" up @ 192.168.4.1
17:31:43  Phone (STA 6e:cd:15:2e:f8:d6) authenticates + associates
17:31:43  ← SAME SECOND: "WiFi monitor: Attempting to reconnect to known networks"
17:31:43  ← "Stopping hotspot..." (kills hostapd + dnsmasq)
17:32:08  AP fully down. "NM not ready after 20s"
17:32:08  Tries to rejoin home wifi → FAILS ("A 'wireless' setting is required")
17:32:21  Restarts AP (after ~38s of NO network at all)
17:33:13  User power-cycled it
```

**Diagnosis:** a background "WiFi monitor" / connectivity watchdog on the Pi
treats "no internet / not on a known network" as a fault and tries to reconnect
to known wifi — which requires **tearing down the hotspot** (single radio can't
host an AP and be a station on another network at once). It fires the instant a
client associates, so every successful phone connection immediately triggers an
AP teardown. The ~38s outage + failed home-wifi rejoin then leaves the robot
with no network until it flaps the AP back up.

**Required fixes (robot-side):**
1. **Suppress the wifi-monitor / known-network auto-reconnect while the hotspot
   is intentionally up.** AP mode is a deliberate state, not a failure to be
   "recovered" from. Gate the monitor on `hotspot_active == False`.
2. **Never tear down the AP while a STA is associated** (`iw dev <ap> station
   dump` non-empty) unless explicitly commanded.
3. The "reconnect to known networks" path must not run on the AP interface, and
   must not assume internet == health while serving an AP.
4. Fix the "A 'wireless' setting is required" NM error on the home-wifi rejoin
   (separate latent bug — the saved connection profile is incomplete).

**Acceptance:** phone joins WIMZ-Demo, drives/streams for >5 min, AP stays up
the whole time; no "Stopping hotspot" in the log while a client is connected.

---

## R-AP-2 — Confirm MJPEG endpoint path is `/video/feed`

App now loads `http://192.168.4.1:8000/video/feed` as the local video stream
(multipart/x-mixed-replace MJPEG). Build 115 **probes** `/video/feed` first then
falls back to the legacy `/camera/stream`, so either works — but please confirm
`/video/feed` is the canonical one and is served as `multipart/x-mixed-replace;
boundary=...` with `Content-Type` set correctly, 200 on GET, no auth in local
mode. (Robot Claude already said it serves this correctly — this is just the
written contract so it doesn't drift again.)

---

## R-AP-3 — (context) WebRTC unusable on the AP — expected, app handles it

On the robot's own AP there's no STUN/TURN reachable, so WebRTC ICE never
reaches `connected`. The app no longer waits on it in local mode: it defaults
straight to MJPEG and only attempts WebRTC if the user taps "Try WebRTC" (now
with a 6s give-up → MJPEG). No robot action needed; noted so the WebRTC-drop
logs on the AP are understood as expected, not a new regression.

---

## App-side changes shipped (Build 115) — for your context

- **MJPEG endpoint corrected + probed:** local video was pointed at the old
  `/camera/stream`; now probes `/video/feed` then `/camera/stream` at connect
  and uses whichever returns 200 (`local_connection_service._resolveMjpegUrl`,
  surfaced as `LocalConnectionData.mjpegUrl`, consumed by `smart_video_view`).
- **Cleartext HTTP allowed for LAN (both platforms):** Android
  `network_security_config.xml` (scoped to 192.168.4.1 + private subnets) +
  manifest reference; iOS `NSAllowsLocalNetworking` + `NSLocalNetworkUsageDescription`.
  Without these, plain http to the robot is blocked and looks like "connecting
  forever".
- **WebRTC give-up shortened to 6s** in local mode so a never-connecting attempt
  flips to MJPEG fast.
