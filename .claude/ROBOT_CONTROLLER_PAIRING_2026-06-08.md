# Robot Brief — In-App Game Controller Pairing (2026-06-08)

> Scope note (updated 2026-06-09): the app is **controller-agnostic** — Xbox is
> just the first family. Pairing/trust/reconnect are universal; only input
> *mapping* is per-brand. See "Generic controllers" below.

**For:** the WIM-Z robot (Raspberry Pi 5) Claude instance.
**From:** the app Claude instance. App side is built and shipped behind a capability gate (Build 127) — it is **inert and harmless** on robots that don't implement this yet, so there's no rush and no risk to current beta units.

## Why
Xbox controllers drop their bond randomly, and re-pairing a deployed robot today means SSH + `bluetoothctl` — impossible for non-tech owners. The app now exposes a **Settings → Controller → Game Controller** screen that drives the robot's Bluetooth stack remotely: scan, pair, **trust/persist**, forget, reconnect. The robot owns Bluetooth; the phone never pairs over its own BT.

## Transport
Same WebSocket channel as motor/servo/treat commands. Works identically in cloud-relay and local-AP mode. **No new REST endpoints.**

- App → robot: `{type:'command', command:'<name>', data:{...}, device_id, timestamp}` (relay/local already deliver these; you parse `command` + `data` exactly like `motor`, `servo`, `set_mode`).
- Robot → app: push events. Robot fields may be top-level or nested under `data` — the app's `WsEvent.fromJson` accepts both. You are **authoritative** for all controller state.

## Commands you must handle (app → robot)

| `command` | `data` | Action |
|---|---|---|
| `controller_status` | `{}` | Reply with a full `controller_status` event (snapshot). Sent on screen open + refresh. |
| `controller_scan` | `{enable: bool}` | Start/stop BlueZ discovery. While on, emit `controller_scan_result` per device and keep `scanning:true` in status. |
| `controller_pair` | `{address}` | `pair` + `connect` the device. Emit `controller_pair_progress` stages, then a fresh `controller_status`. |
| `controller_trust` | `{address, trusted: bool}` | **The user's sign-off.** `bluetoothctl trust`/`untrust` **and** add/remove from the persistent auto-reconnect allowlist (survives reboot). Emit updated `controller_status`. |
| `controller_forget` | `{address}` | `disconnect` + `remove` (unpair) + drop from allowlist. Emit updated `controller_status`. |
| `controller_reconnect` | `{address}` | Force `connect` a known-but-dropped controller. Emit progress + status. |

## Events you must emit (robot → app)

### `controller_status` — the authoritative snapshot (emit on every state change)
```json
{
  "type": "controller_status",
  "scanning": false,
  "active_address": "DC:26:39:AA:BB:CC",
  "controllers": [
    {
      "address": "DC:26:39:AA:BB:CC",
      "name": "Xbox Wireless Controller",
      "kind": "xbox",        // optional — see "Generic controllers" below
      "paired": true,
      "trusted": true,
      "connected": true,
      "battery": 80          // optional, omit if unknown
    }
  ]
}
```
- `paired` = BlueZ bonded. `trusted` = persisted/auto-reconnect. `connected` = usable now.
- Emit on: reply to `controller_status`, after any pair/trust/forget/reconnect, **and spontaneously** when a controller connects/drops on its own (this is what keeps the app's status card live).

### `controller_scan_result` — discovery trickle (one per device found while scanning)
```json
{"type":"controller_scan_result","address":"DC:26:...","name":"Xbox Wireless Controller","kind":"xbox","rssi":-52}
```
**Filter by Bluetooth device class, not by the Xbox name** (see below), so any
gamepad shows up and the list isn't noise.

### `controller_pair_progress` — optional UX feedback during pair/reconnect
```json
{"type":"controller_pair_progress","address":"DC:26:...","stage":"pairing","message":"Pairing…"}
```
`stage` ∈ `pairing | connecting | done`. `message` optional (app falls back to a stage label).

### `controller_error` — non-fatal failure
```json
{"type":"controller_error","code":"PAIR_FAILED","message":"Controller not in pairing mode"}
```
App shows `message` (or `code`) as a snackbar and clears any row spinner.

## Generic controllers (not just Xbox) — pairing is already universal
The app UI is controller-agnostic: it keys on `address`/`name` and treats any
unknown type as "generic" with a neutral glyph + generic pairing instructions.
So you get broad support cheaply if you do two things:

1. **Scan-filter by BT device class, not name.** Match the *gamepad/joystick*
   minor device class (peripheral major class `0x05`, e.g. CoD `0x002508` for a
   gamepad, `0x000508`/`0x000540` variants for joysticks/keyboards-with-pad)
   instead of `name contains "Xbox"`. This makes discovery work for DualShock/
   DualSense, 8BitDo, and generic HID pads with no per-brand code.
2. **Send an optional `kind` field** on `controller_status` + `controller_scan_result`
   so the app can show the right glyph + the right pairing hint. Accepted values
   (anything else → the app shows "generic"):
   `xbox` | `playstation` | `8bitdo` | `generic`.
   Derive it from the name / vendor-product id if convenient; **omit it if you
   don't know — the app defaults to generic and still works.**

**Pair / trust / forget / reconnect are already brand-agnostic** — BlueZ does
the same thing for any controller, so those handlers need no per-brand logic.

### The one brand-specific part: *driving* the robot
Pairing ≠ usable input. Reading `/dev/input/jsX` and mapping buttons/axes to
robot control differs per family (Xbox vs PlayStation vs 8BitDo vs generic HID),
and driver quirks differ too:
- **Xbox:** `xpadneo` / `disable_ertm=1` (covered below).
- **PlayStation:** `hid-playstation` (DualSense) / `hid-sony` (DualShock 4) —
  **no ERTM workaround needed**, different reconnect behavior.
- **8BitDo:** depends on the controller's mode switch (X-input vs D-input vs
  Switch); X-input mode behaves Xbox-like.

Recommendation: **ship Xbox input mapping now** (done), keep scan/pair universal
from day one, and add input-mapping profiles for other families incrementally as
demand appears. Consider the SDL game-controller mapping DB to avoid hand-rolling
each profile. None of this is gated by the app or the contract — it's purely the
robot's input layer.

## The actual fix for "random unpairing" (please implement, not just the API)
The API above lets a user re-pair from the couch, but the root cause needs robot-side persistence:

1. **Trust + persist.** On `controller_trust`, run `bluetoothctl trust <addr>` AND record the address in a durable allowlist file (e.g. `~/.wimz/trusted_controllers.json`). The BlueZ bond under `/var/lib/bluetooth/<adapter>/<addr>/` already survives reboot — make sure you're not wiping `/var/lib/bluetooth` on boot.
2. **Auto-reconnect daemon.** A small loop / systemd service that, for every trusted address not currently connected, periodically issues `bluetoothctl connect <addr>` (back off to ~10–30s). Xbox pads advertise on wake; this re-grabs them without user action. Emit a spontaneous `controller_status` when one comes back.
3. **ERTM workaround.** Xbox controllers misbehave with BlueZ ERTM. Set `options bluetooth disable_ertm=1` (`/etc/modprobe.d/bluetooth.conf`) and reload, or use the `xpadneo` driver. This is the single most common cause of "connects then drops."
4. **Agent / auto-accept.** Run a non-interactive BT agent (`NoInputNoOutput`) so pairing during a `controller_scan` window doesn't block on a PIN prompt.
5. **Idempotency.** `controller_pair` on an already-bonded device should just connect; `controller_trust` twice is a no-op. The app may resend on flaky links.

## Notes / contract stability
- Keep `address` as the stable identity everywhere (the app keys rows + commands on it).
- Don't rename event `type`s — they're constants in the app (`ControllerCommands` / `ControllerEvents` in `controller_pairing_provider.dart`).
- If you can't fully implement yet, even just answering `controller_status` flips the app from "Update needed" to a live (if empty) screen — partial is fine and additive.

## Verification (when a robot is powered on)
Local-AP is the easiest path. App side will exercise: open screen → `controller_status` reply → toggle Scan → `controller_scan_result` appears → Pair → progress → connected in snapshot → flip Trust → reboot/drop pad → auto-reconnect daemon brings it back (or Reconnect works).

**Please capture and send back the exact JSON of a real `controller_status` after a successful pair+trust**, so any field-name drift is a one-line app fix.
