# WIM-Z Fleet Dispatch Package
Compiled from the raw issue dump + the five spec docs. Date: 2026-07-05.

## How to use this
Three surfaces, three Claude Code instances: **ROBOT** (Pi), **APP** (Flutter), **RELAY** (AWS). Each surface has its own block below that you can paste straight into that instance. Cross-surface work is broken into per-surface slices and tied together in the Dependency Map (section 6), which is the thing that stops you shipping a model or an event schema that one surface reads wrong.

**Severity legend**
- `DEALBREAKER` — fleet-killing, demo-killing, or moat-data-corrupting. Do first.
- `SCOPED` — real, bounded, do after dealbreakers.
- `VERIFY` / `NOISE` — already handled or low-signal; confirm and move on.

**Dispatch legend**
- `∥ PARALLEL` — single surface, no cross-dependency. Fire all at once.
- `→ SERIES` — part of a cross-surface chain; must run in the order given in section 6 or it ships half-wired.

---

## 0. IR through-beam dispense confirmation (X-BEAM) — full build ticket (NEW, undocumented)

**X-BEAM — Confirmed dispense via IR through-beam** · ROBOT + schema · `DEALBREAKER (data integrity)` · `→ SERIES`

Why it matters: `dispense_log` currently records that a slot *fired*, not that a treat *ejected*. Every hang-up writes a false `reward_dispensed=1` and poisons the `training_attempt` moat data. This ticket closes the loop.

**Hardware (per Morgan's spec):**
- Discrete IR emitter + phototransistor pair. NOT a slotted module (size the gap to the chute); NOT reflective / TCRT5000 (fights ambient light, false-reads off the carousel surface); NOT load cell or ToF (slower, overkill for a falling object).
- Through-beam across the drop path at the chute exit: emitter one side, phototransistor the other, aimed across the exit.
- Wiring: one spare GPIO, 3.3V, GND, 220Ω on the emitter, pull-up on the receiver line. Falling-edge interrupt / GPIO event-wait.
- Mount both optics behind the optical barrier so slobber and treat dust can't blind them.
- Aim the beam below the carousel plane so only a falling treat crosses it, never the rotating carousel itself (kills false-confirms).
- Verify: if this IR band overlaps the night-vision illuminator, confirm the two don't cross-trigger.

**Schema (additive; bump `WIMZ_Data_Architecture_Spec.md` per its rule 9), add to `dispense_log`:**
- `dispensed_confirmed INTEGER DEFAULT 0`
- `confirm_latency_ms INTEGER` (fire → beam-break; doubles as a jam-trend signal over time)

**Control loop:**
```
dispense():
  rotate 32.7deg (one slot)
  # StallGuard is a DURING-rotation signal; don't burn the full window on a jam
  if StallGuard trips mid-rotate:
      -> mechanical jam: run anti-jam (reverse+forward), retry
  else (rotate completed):
      watch beam for break, timeout ~800ms
      if beam broke AND restored:
          -> confirmed: dispensed_confirmed=1, set confirm_latency_ms,
             increment dispensed_count, done
      if beam broke but stayed broken:
          -> chute blocked: error{"code":"chute_blocked"}, stop
      if no beam:
          -> empty/stuck slot: nudge forward a small step, recheck
  after N total attempts (shared budget across jam + nudge) fail:
      -> dispensed_confirmed=0, error{"code":"dispense_failed"}, flag app, stop
```

**Refinements over the base loop:**
- **Stall is during rotation; beam is after it.** Check StallGuard as the rotate executes so a jam bails immediately instead of waiting out the 800ms beam window.
- **One shared retry budget** (2–3 total) across the jam and nudge branches, or a slot that alternates jam/stuck ping-pongs forever without ever hitting N.
- **Break-and-restore = clean pass; break-and-stays-broken = obstruction.** That extra state separates "chute blocked" from "empty slot" — different faults, different app messages.
- Connect StallGuard here: today it's on a manual Xbox trigger, so autonomous jams go uncaught.

Downstream: `training_attempt.reward_dispensed` reads from `dispensed_confirmed`, not from "fire command sent." App surfaces terminal `dispense_failed` as "treat didn't dispense — check carousel."

---

## 1. DEALBREAKERS (priority order, all surfaces)

1. **R-CRASH** — 24h crash, no recovery · ROBOT · `∥`
2. **X-SG** — Silent Guardian events don't persist / cleared events reappear · ROBOT+RELAY+APP · `→`
3. **A-DISCOVER** — "Find your robot" / can't connect to wimz_robot_01 · ROBOT+APP · `→` (spec exists)
4. **X-REC** — Record button doesn't save video · ROBOT+APP · `→`
5. **A-PROFILE** — Dog profiles lost on Local-mode exit · APP · `∥`
6. **X-BEAM** — Dispense confirmation (section 0) · ROBOT+schema · `→`

---

## 2. ROBOT (Pi) — paste into the robot Claude Code instance

**R-CRASH — Daily crash with no recovery** · `DEALBREAKER` · `∥ PARALLEL`
Recover first, diagnose second — don't wait to find the leak before the fleet stops dying.
- Immediate mitigation: systemd `Restart=always`, `RestartSec`, `WatchdogSec` with a heartbeat ping from the main loop, and `MemoryMax=` so a leak triggers an OOM restart instead of a silent hang. This alone converts "dead until I drive over" into "self-heals in seconds."
- Then diagnose: `journalctl -u treatbot --since "24 hours ago"`, `systemd-analyze`, and log RSS over a session to confirm leak vs. random exception. Prime suspects: unbounded frame/event buffers, camera handles not released, an ever-growing in-memory list.

**R-STREAM — FPS + stream decouple** · `SCOPED` · `∥` · *(subsumes raw "H.264 encode delay on tb3")*
- Already specced in full: `WIMZ_Technical_Work_Order_Diagnostics_and_UX.md` §1 (FPS diagnostic) and §2 (Picamera2 dual-stream: `main` encode, `lores` inference; MJPEG vs H.264 test). Execute those sections as written; don't redesign.
- Context you already have: Pi 5 has no hardware H.264 encoder, so this is a CPU-encode tax, not a Hailo TOPS ceiling.

**R-BOOT — 90s boot → sign-of-life <5s, camera <30s** · `SCOPED` · `∥`
- Execute `WIMZ_Technical_Work_Order` §3A as written (early `wimz-alive` systemd unit for LED/chime, camera-before-AI staging, defer non-critical services).

**R-MUSIC — Audio dies when joystick throttles** · `SCOPED` · `∥`
- Same class of bug as the stream tax: the motor-control loop is starving audio. Decouple playback into its own thread/process with its own buffer so motor command bursts can't underrun it (mirror the capture/inference decoupling pattern). Confirm it isn't one Python process serializing motor PWM and audio under the GIL.

**R-LED — LEDs illuminate on motor movement (confirmed electrical)** · `SCOPED` · `∥` · *(consolidates the LED gripes)*
Root cause confirmed as motor noise coupling, not code. WS2812 data is timing-sensitive and ground-referenced; the Pi drives it at a marginal 3.3V, and motor current causes ground bounce + rail sag that the weak data signal can't ride out, so the strip latches to a spurious "on." Fixes, highest-leverage first:
1. **Suppress at the source:** 0.1µF ceramic cap across each motor's terminals (terminal-to-terminal, and terminal-to-case if brushed). Kills brush EMI where it's generated. Biggest single win.
2. **Star-ground:** motor return current must not share the LED/logic ground path. Run motor grounds and LED/logic grounds as separate legs to one star point so motor current can't modulate the LED ground reference. Classic cause of "on when motors move."
3. **Harden the data line:** 74AHCT125 (or similar) level shifter to drive WS2812 data at a clean 5V, plus a 330–470Ω series resistor at the first pixel; route the data wire away from motor leads, keep it short.
4. **Decouple the LED rail:** 1000µF electrolytic across the strip's power input, close to the strip.
Do 1 + 2 first (root cause); 3 + 4 are hardening.
The separate "sometimes won't turn on" complaint is NOT this — it's most likely the app→robot LED command not arriving on some modes (see A-LED), not an electrical fault.

**R-FLIP — Camera 180 flip** · `VERIFY` · `∥`
- Already set in YAML on Robots 1 and 3. Just propagate the YAML to all units and confirm. No code.

**R-BLUE — Motors + intermittent blue-light failure** · `NOISE / diagnostic` · `∥`
- You flagged this as likely your own issue. Low priority: capture the blue-light state in logs when it happens and check the connector/seating. Don't spend a session on it until logs show a real pattern.

---

## 3. APP (Flutter) — paste into the app Claude Code instance

**A-DISCOVER — "Find your robot" / no robot on select** · `DEALBREAKER` · `→ SERIES` *(spec exists)*
- Solution is specced: `WIMZ_Technical_Work_Order` §3B/§3C — app tries both endpoints (WiFi IP + AP `192.168.4.1`) and uses whichever answers; unique mDNS names `WIMZ-XXXX`. Robot side must advertise correctly first (see Dependency Map). Verify the current bug against that design rather than patching blind.

**A-PROFILE — Dog profiles lost when Local mode closes** · `DEALBREAKER` · `∥ PARALLEL`
- App is the authority for human-entered dog fields (`WIMZ_Data_Architecture_Spec.md` §2). Persist profiles to local device storage so they survive Local-mode teardown, and reconcile to the `dog` table on next sync. Local mode must never be a volatile scratchpad for the one thing that's the per-dog moat.

**A-PORTRAIT — Camera tracking buttons hidden in portrait** · `SCOPED` · `∥`
- Real usage pattern (phones mounted fixed-portrait). Either reflow the controls so every button is reachable in portrait on both iOS and Android, or gate the mode behind an unmissable "Rotate to Landscape" prompt. Don't leave buttons off-screen.

**A-WORDING — "Punishment" → "Intervention"** · `SCOPED (fast, on-brand)` · `∥`
- Global copy replace. Matches positioning (this is intervention/wellbeing, never punishment). Quick win.

**A-BANNER — Retry banner + "tap to connect" redundant** · `SCOPED` · `∥`
- Collapse to one connection-state affordance. Fold into the A-DISCOVER pass since both are connection UI.

**A-LED — LEDs don't fire from app across modes (esp. Local)** · `SCOPED` · `→` (pairs with R-LED)
- Confirm the app is actually sending the LED command on the Local-mode path (endpoint parity with cloud mode). If the command sends but nothing lights, it's R-LED (robot/electrical). Add a diagnostics action that pings the LED and reports round-trip so you can tell app-fault from robot-fault.

---

## 4. RELAY (AWS) — paste into the relay Claude Code instance

**L-SYNC — Event + clear-state sync for Silent Guardian** · `DEALBREAKER` · `→ SERIES`
- Core of X-SG. Relay must sync robot `event` rows up (respecting the `synced` flag) and, critically, round-trip the *cleared* state back so a clear is durable. "Cleared events reappear" = clear state isn't persisting through the relay. See Dependency Map.

**L-REPORT — Session-report LLM layer** · `SCOPED` · `→` *(spec exists)*
- Execute `WIMZ_Implementation_Proposal_Queryable_Store_and_LLM_Reports.md` Workstream B as written: schema bump for `session_report`, deterministic `stats_json` assembly, one `claude-haiku-4-5` call per session with idempotency via `input_hash`. Gated behind the Edge producing real `training_attempt` rows (Workstream A) first.

*(Relay stays thin. No always-on model, per that proposal's cost rules.)*

---

## 5. Cross-surface / already-specced workstreams (dispatch, don't rewrite)

**Queryable Store + Session Reports** — `WIMZ_Implementation_Proposal_Queryable_Store_and_LLM_Reports.md`
Subsumes raw items "Add Summary tracking (SG/Coach/idle)" and "finalize database + Summary report for moat flooding." Internal order is fixed by the doc: schema v0.2 → Edge `training_attempt` assembly + backfill (Workstream A, robot) → Relay report (B) → App display + human-review queue (C). This is the moat-flooding work; A is the priority because nothing downstream exists without linked attempts.
- Open design question you raised — "what do we log in idle?": idle should log passive, non-rivalrous observation events only (presence, zone, notable behaviors), zero dispense. That's the same event stream as Observation Mode below, minus any treat path.

**Mode architecture: Observation vs Coach** — `PARKED (backlog, not this pass)`
Stays in the overall TODO; do not dispatch until an investor objection actually calls for it (don't-build-ahead-of-saturation). Design recorded here so it can be pulled in one pass later:
- **Observation Mode** (multi-dog, ArUco + recognition, **no treats**): the no-treat guarantee must be **firmware-enforced** (absolute dispense lockout), not just a UI state, because multiple dogs + a single rivalrous treat source breaks reward attribution.
- **Coach/Mission Mode** (single dog): hard-lock to one `dog_id` for cue, analysis, and dispensing.
- Both stamp events with `tracker_id`/`zone` per `WIMZ_Implementation_Proposal_Supervision_VLM_Highlights.md`; the exception-VLM review layer stays deferred (cost, post-raise).

**ArUco → dog name** — raw item "call dog's name from profile DB"
- ROBOT resolves ArUco/recognition → `dog_id` → name; APP owns the name database. **Depends on A-PROFILE landing first** (no durable profile, nothing to name). Series after A-PROFILE.

**Setup / idiot-proofing audit** — `WIMZ_Technical_Work_Order` §4
- The FANG-engineer-couldn't-set-it-up problem. High strategic value (setup friction is the top adoption threat). Run §4 as a review pass that produces a punch list; it's not one ticket, it's a gate.

---

## 6. Dependency Map (the series chains — read before dispatching)

Anything below MUST run left-to-right. Everything not in a chain is `∥ PARALLEL` and can fire simultaneously across the three instances.

**Chain SG (Silent Guardian events)** — DEALBREAKER
`ROBOT: write events to spec `event` table, synced=0` → `RELAY (L-SYNC): sync up + persist clear-state round-trip` → `APP: display persisted events; clear writes back durably`
Why series: a clear that doesn't round-trip through the relay is exactly the "cleared events reappear" bug. Ship the display before the clear-state sync and you reproduce the bug.

**Chain REC (record video saves)**
`ROBOT: persist media file to disk + write media_asset row, in BOTH local and cloud modes` → `APP: confirm save, show location, offer iPhone save/download`
Why series: the app can't confirm or offer a save of a file the robot never wrote.

**Chain DISCOVER (connectivity)** — DEALBREAKER
`ROBOT: advertise unique mDNS name + keep AP fallback up (Work Order §3B/§3C)` → `APP: try both endpoints, use whichever answers (A-DISCOVER/A-BANNER)`
Why series: the app can only find a robot that's advertising correctly.

**Chain BEAM (dispense confirmation)** — DEALBREAKER (data integrity)
`SCHEMA: add dispensed_confirmed + confirm_latency_ms` → `ROBOT: read beam in dispense routine, connect StallGuard, write fields, read reward_dispensed from confirmation` → `APP (optional): "treat didn't dispense" nudge`

**Chain STORE (moat data)**
`SCHEMA v0.2: session_report` → `ROBOT: training_attempt assembly + backfill (Workstream A)` → `RELAY: session report (Workstream B / L-REPORT)` → `APP: display + review queue (Workstream C)`

**Chain NAME (ArUco → name)**
`APP: A-PROFILE (durable profiles)` → `ROBOT: ArUco→dog_id resolution` + `APP: name lookup`

**Chain MODES (observation/coach)** — `PARKED`
(Not this pass. Order when pulled: `ROBOT: firmware treat-lockout (observation) + single-dog lock (coach)` → `APP: mode UI + dog picker`.)

---

## 7. Separate track (not a Claude Code dispatch)

**Audio negative-class retrain** — raw item "retrain non-bark classifier on TV/drama/movies/YouTube/myself"
This is model-pipeline work on the desktop (bark classifier = CPU/TFLite, separate from the Hailo vision path), not a robot/app/relay code task. It runs in parallel with everything above and only touches the fleet when a new TFLite model is staged. The ingestion/balancing script for this is the next thing to build on the pipeline side.
