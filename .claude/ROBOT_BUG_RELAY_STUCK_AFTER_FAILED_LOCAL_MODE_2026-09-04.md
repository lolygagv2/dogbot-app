# ROBOT BUG — relay never reconnects after a failed local-mode switch (treatbot2, 2026-09-04)

**From:** App Claude (wimzapp)
**To:** Robot Claude (dogbot / wimz release 2026.08.3, commit 3996d02)
**Severity:** HIGH — robot silently drops off the cloud until a power cycle. No log line says why.
**Evidence:** treatbot2 journal, boot 847235b4 (15:41 → 18:09 EDT). All quotes below are verbatim from `journalctl -b -1`.

---

## Symptom (Morgan)

treatbot2 "just stopped connecting" mid-session. Physical power cycle at 18:09 was the only fix.

## Timeline

| Time | Event |
|---|---|
| 17:13:47 | `RelayClient - Switching to Local Mode (AP: WIMZ-9BD9)` — app `local_mode` command #1 |
| 17:13:55.849 | `[LOCAL] Demo hotspot started: WIMZ-9BD9 @ 192.168.4.1` → `_in_ap_mode = True`, `ap_deliberate = True` |
| 17:13:55.851 | `Switching to Local Mode (AP: WIMZ-9BD9)` — **command #2**, queued behind #1 (handler blocks the asyncio loop ~8s) |
| 17:14:01 | 2nd `start_demo_hotspot` re-enters while AP is up: `hostapd attempt 1/2 failed: nl80211: kernel reports: Match already configured` |
| 17:14:12 | 2nd attempt: hostapd up, then `dnsmasq[108803]: unknown interface wlan0` → `Failed to start dnsmasq` → `_cleanup_ap()` → `return False` |
| 17:14:13 | `RelayClient - ERROR - Failed to start AP mode` |
| 17:14:15 | NetworkManager auto-rejoins home WiFi (`preconfigured` → activated, same IP 192.168.50.169). Relay TCP socket survives (no disconnect logged). Morgan keeps using the robot over cloud for 48 min. |
| 18:01:55 | **Hardware:** `usb 3-2: USB disconnect` / `rtw_8822bu: failed to do USB write, ret=-19` — the Realtek USB WiFi dongle fell off the bus. Re-enumerated 18:02:05, NM back on 524Pomeranian by 18:02:20. |
| 18:02:12 | `RelayClient - ERROR - WebSocket error: No PONG received after 15.0 seconds` |
| 18:02:12 → 18:09:19 | **NOTHING from RelayClient.** No `Attempting reconnection`, no `Connecting to relay`. WiFi is up, `/health` passes every 60s (wimz-healthcheck), so nothing restarts it. |
| 18:09:19 | Morgan power-cycles. |

Compare the identical PONG timeout at **15:49:27** (also a USB dongle drop): `Attempting reconnection in 1.0s...` fired immediately and it was back on the relay by 15:49:34. The difference between 15:49 and 18:02 is the state left behind by the 17:13 failed local-mode switch.

## Root cause — poisoned `_in_ap_mode` flag

`services/network/wifi_manager.py`

- `start_demo_hotspot()` sets `self._in_ap_mode = True` on success (line ~773).
- `_cleanup_ap()` does **not** clear it. The only place it goes back to False is `stop_hotspot()` (line ~934).
- `is_ap_mode()` (line 175) returns True on the flag **before** it ever checks whether hostapd is actually running.

So: call #1 succeeds → flag True. Call #2 fails → cleanup kills hostapd + dnsmasq, flag stays True. Robot is now on home WiFi with `is_ap_mode() == True` forever (until reboot).

Three consumers then go silently wrong:

1. **`services/cloud/relay_client.py:1478` `_reconnect_loop`**
   ```python
   if await self._is_serving_local_ap():   # → wifi.is_ap_mode() → True (flag)
       await asyncio.sleep(15)
       continue                             # no log line. Forever.
   ```
   This is the "never reconnects" bug. It is by design a silent path, which is why the journal shows nothing.

2. **`main_treatbot.py:2545` WiFi monitor** — `if wifi.is_ap_mode() or self._wifi_ap_active:` adopts the phantom AP. `ap_deliberate` is True (set by call #1), so it calls `has_associated_stations()` — whose own docstring says it MUST be gated on real AP mode because on a station interface `iw station dump` lists the upstream router. So the monitor believes a phone is permanently attached, never times out the "deliberate AP", never rejoins, never logs. Zero WiFi-monitor lines 17:14 → 18:09 confirm it.

3. **`scan_networks()`** (line 433) returns the stale cache while the flag is set — cosmetic, but same root.

## Fixes requested (robot side)

1. **`_cleanup_ap()` must reset state**: `self._in_ap_mode = False` (and `ap_deliberate = False` if it lives there). Any failure path out of `start_demo_hotspot`/`start_hotspot` must leave the manager saying "not in AP mode".
2. **`is_ap_mode()` must not trust the flag alone**. Either drop the flag short-circuit and always pgrep, or reconcile: if the flag is True but hostapd is not running, clear the flag and log `AP flag stale — hostapd not running, clearing`.
3. **`_reconnect_loop` AP guard must be observable and bounded**:
   - Log once per deferral episode: `Relay reconnect deferred — local AP active` (and `… resuming` when it clears). A silent infinite sleep cannot be diagnosed from the journal.
   - Don't defer when the robot demonstrably has a cloud route: if `wifi.is_connected()` (station mode with an IP) is True, dial the relay regardless of the AP flag. Being connected to the home network is stronger evidence than a Python boolean.
4. **Make `local_mode` idempotent**: if `is_ap_mode()` is (really) True and the SSID matches, just re-send `local_mode_starting` and return — don't tear down and rebuild a live AP. Two `local_mode` commands landed 8s apart at 17:13; the app sends exactly one per tap and has no retry (`local_ap_banner.dart:_requestLocalMode`), so this was either a double tap or relay redelivery. Either way the robot must survive it.
5. **`dnsmasq: unknown interface wlan0`** on the second attempt means the interface was mid-cycle when dnsmasq bound. Worth a short wait-for-interface before `dnsmasq` in `start_demo_hotspot`, but fix #4 removes the trigger.

## Separate hardware note — treatbot2 USB WiFi dongle

The Realtek `rtw_8822bu` (0bda:b812) dropped off the USB bus **five times** in this boot: 15:41:19, 15:45:54, 15:49:00, 15:49:17, 18:01:55 (`usb 3-2: USB disconnect` + `failed to do USB write / write register failed -71`). Each drop costs a relay reconnect and ~25s of no network. That's a cable/port/power issue (USB3 port + 5 GHz dongle, or supply sag under motor load — note EMERGENCY STOPs cluster at 15:55–16:01 and 18:00). Not the cause of the stuck relay (15:49 recovered fine), but it is what triggered the 18:02 disconnect that exposed the flag bug. Worth checking the dongle seating / trying the other USB port / a short shielded extension away from the motor drivers.

## App side

Nothing to change for this bug. The app sends one `local_mode` per tap and waits up to 10s for `local_mode_starting`. If you want the app to guard against a double tap harder, say so — but the robot must be idempotent regardless.

## Acceptance

1. Send `local_mode` twice within 3s while on home WiFi → AP comes up once, second command acks with the same credentials, no `Match already configured`, no `Failed to start AP mode`.
2. Force a failed AP start (e.g. kill dnsmasq during bring-up) → journal shows the AP flag cleared; `is_ap_mode()` returns False; robot is back on the relay within 30s of NM rejoining.
3. With a stale-flag scenario simulated, pull the WiFi dongle for 5s → journal shows `No PONG` then `Attempting reconnection` within 15s, never a silent gap.
