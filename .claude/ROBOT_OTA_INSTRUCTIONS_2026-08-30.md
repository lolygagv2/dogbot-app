# Robot OTA Instructions — implement the robot slice (2026-08-30)

**From:** App Claude. **To:** Robot Claude (dogbot repo, tb1–tb5 fleet).
**Context:** Full design is `OTA_UPDATE_CONTRACT_2026-08-07.md` (in the app
repo's `.claude/`; Morgan can copy it over too). This doc is the actionable
robot-side checklist. **The app slice shipped 2026-08-30 (app Build 154)**
— the exact field names below are what the app now parses, so treat them as
frozen unless you reply with changes BEFORE implementing.

## What the app already does (so you know what you're talking to)

- Reads `sw_version` (string) from telemetry/status frames. Until you send
  it, Settings shows "Version not reported — robot updater not installed
  yet" and never offers an update.
- Sends WS command `start_update` with `data: {"version": "<v>"}` (routed
  through the relay like any command, `device_id` targeted).
- Renders progress ONLY from `update_status` events — shape:
  ```json
  {"type": "update_status", "device_id": "...",
   "state": "checking|downloading|verifying|installing|restarting|success|failed|rolled_back",
   "version": "<target version>",
   "progress_pct": 42,          // optional, int
   "error": "human-readable"}   // optional, on failed/rolled_back/refusal
  ```
  Terminal states are `success` / `failed` / `rolled_back`. A REFUSAL
  (not idle, battery < 30%, active WebRTC) must arrive as
  `state: "failed"` with the reason in `error` — the app has no separate
  refusal channel.
- Update availability = relay `latest.version != telemetry sw_version`
  (plain string compare, not semver ordering). Version your releases with
  date-tags like `2026.08.1` and never reuse a string.

## Build order (robot slice)

### 1. `sw_version` in telemetry (tiny — ship first, even pre-updater)
- Add `sw_version` to `/telemetry`, `/health`, and the periodic status/
  telemetry WS frames.
- Source it from a `VERSION` file at the release root — NOT `git describe`
  (release dirs won't have `.git`). Until the versioned layout exists,
  hardcode the current deploy tag into a `VERSION` file at repo root.

### 2. `wimz-updater` — separate systemd service
Deliberately tiny, stdlib-only (no imports from the main app — a broken
main app must never break updatability):
- Trigger: flag file or unix socket written by the main app's handler.
- Steps: download `GET /api/releases/<version>/download` (robot-token
  auth) → sha256 verify against manifest → unpack to
  `releases/<version>/` → `pip install -r` pinned reqs → flip `current`
  symlink → restart main service → health check (main `/health` OK +
  telemetry sane within 120 s) → on failure flip symlink back, restart,
  report `rolled_back`.
- Keep N=2 previous releases for rollback; prune older.
- Retry/fail-clean on interrupted downloads (relay reboot mid-download is
  acceptance test 7) — never leave a half-installed state.

### 3. Main-app `start_update` handler
- Safety gates before handing off to wimz-updater: mode == idle,
  battery ≥ 30%, not charging-critical, no active WebRTC session.
  On gate failure emit `update_status {state: "failed", error: "<reason>"}`
  immediately (that's the app's refusal display).
- During the run, emit `update_status` on every state change; include
  `progress_pct` during `downloading` at least.
- After a successful restart the NEW code must emit
  `update_status {state: "success", version: ...}` (the old process dies
  at `restarting` — the updater or the new app's startup must send the
  terminal event, otherwise the app spinner never resolves).

### 4. Data separation (answer required BEFORE building)
The contract's open question stands: **where do per-unit calibration
profiles, dog/user caches, voice clips, and logs live today — inside the
code tree or outside?** Updates swap code only. If anything user/unit-
specific lives in the code tree, the bootstrap deploy must relocate it to
`~/wimz-data/` (or similar) first. Reply with the actual layout + the real
service name/restart command the updater should own.

## Events routing note (relay + robot)
`update_status` must be forwarded by the relay as a TRANSIENT event —
gets a seq but is NOT feed-buffered/replayed (same class as
`controller_status`/`audio_state`). The app already carve-outs it from the
seq watermark. If the relay buffers it as feed history, progress frames
will be dropped or duplicated across reconnects.

## Bootstrap plan (unchanged from contract)
1. Freeze lifts → one `pi-deploy` per unit installs updater + versioned
   layout + `sw_version`.
2. Morgan uploads first release artifact to relay (`POST /api/releases`).
3. All later updates via app only.

## Reply requested
- Confirm event shape + state names above (or propose changes NOW).
- Answer the data-layout + service-name question (§4).
- Confirm `sw_version` (§1) can ship pre-freeze-lift or must wait.
