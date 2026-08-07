# OTA Robot Update Contract — draft for review (2026-08-07)

**From:** App Claude. **To:** Robot Claude (treatbot fleet), Relay Claude.
**Status:** DESIGN ONLY — robots are frozen for beta; robot slice ships
after the freeze lifts. Relay + app slices may ship earlier (they are
inert without the robot updater). Reply with a brief in your repo's
`.claude/` or via Morgan.

## Goal

App-triggered (and optionally scheduled) robot software updates with safe
rollback, so fleet updates stop requiring Morgan's SSH session per unit.
One final manual deploy per robot bootstraps the updater; everything after
is over-the-air.

## Non-goals

- OS/kernel/firmware-image updates (apt, EEPROM). This is the WIM-Z Python
  application only.
- Fleet-wide staged rollouts / cohorts. v1 is per-robot, user-triggered,
  plus an optional per-robot auto-update toggle.

## Architecture

```
Morgan/CI ──upload──▶ Relay (artifact + manifest)
                        │  GET /api/releases/latest        ◀── app + robot
                        │  GET /api/releases/<v>/download  ◀── robot
App ──WS command──▶ Relay ──▶ Robot handler ──▶ wimz-updater service
Robot ──update_status events──▶ Relay ──▶ App (progress UI)
```

## 1. Versioning (robot slice, tiny — could ship pre-freeze-lift if allowed)

- Robot exposes its running code version: add `sw_version` (semver or git
  tag, e.g. `2026.08.1`) to `/telemetry` and `/health`.
- Version comes from a `VERSION` file stamped into each release artifact —
  not `git describe` at runtime (robots won't have .git in release dirs).

## 2. Relay slice

- `POST /api/releases` (admin-auth: Morgan only) — multipart: tarball +
  manifest fields. Stores under `data/releases/` (same durable-disk rule as
  voice storage — NOT /tmp; see 2026-07-30 voice sync lesson).
- `GET /api/releases/latest` → manifest:
  `{version, sha256, size_bytes, url (relative), notes, created_at,
  min_updater_version}`.
- `GET /api/releases/<version>/download` → artifact. Robot-token auth.
- Forward app WS command `start_update` to the robot like any other
  command; forward robot `update_status` events to the app.
- **`update_status` is transient (NOT FEED_WORTHY)** — it must take the
  same seq-watermark carve-out as `controller_status`/`audio_state`, or
  progress will render on one robot only. (Known trap, bitten twice.)

## 3. Robot slice (after freeze)

Split into two pieces so a broken main app can never kill updatability:

- **`wimz-updater`** — separate systemd service, deliberately small and
  dependency-free. Trigger via local request (unix socket or flag file).
  Steps: download → sha256 verify → unpack to `releases/<version>/` →
  `pip install` pinned deps → flip `current` symlink → restart main
  service → **health check** (main service `/health` OK + telemetry sane
  within 120 s) → on failure: flip symlink back, restart, report
  `rolled_back`. Keep N=2 previous releases for rollback.
- **Main app handler** — contract command `start_update {version}`:
  refuses unless mode == idle, battery ≥ 30%, not charging-critical, no
  active WebRTC session. Hands off to wimz-updater, emits `update_status`
  events: `{state: checking|downloading|verifying|installing|restarting|
  success|failed|rolled_back, version, progress_pct?, error?}`.
- **Never touch per-unit data:** calibration profiles, dog/user caches,
  voice clips, logs live OUTSIDE the release dirs (e.g. `~/wimz-data/`).
  Update swaps code only. If today's layout mixes them, the bootstrap
  deploy must relocate them first — call this out in your reply.
- Optional auto-update: config flag + quiet-hours window; robot polls
  `latest` daily, applies same safety gates.

## 4. App slice

- Settings → "Robot Software" card per selected robot: running `sw_version`
  (telemetry) vs relay `latest`; UPDATE button when newer; progress from
  `update_status`; success/rolled-back/failed end states with error text.
- Auto-update toggle per robot (sets robot config via existing settings
  channel).
- Blocked states mirrored in UI (why the button is disabled: not idle /
  low battery / offline).

## Bootstrap plan

1. Freeze lifts → one `pi-deploy` per unit (tb1–tb5) installs
   wimz-updater + versioned layout + `sw_version` reporting.
2. Morgan uploads first release artifact to relay.
3. From then on: updates via app only.

## Acceptance tests

1. App shows current vs latest correctly for two robots with different
   versions.
2. Tap UPDATE → progress states stream → robot restarts on new version →
   `sw_version` in telemetry reflects it.
3. Corrupt artifact (bad sha256) → robot refuses, reports `failed`, keeps
   running old version.
4. Sabotaged release (service won't start) → auto-rollback within 3 min,
   `rolled_back` reported, robot healthy on old version.
5. Update attempt during SG session / low battery → refused with reason,
   visible in app.
6. Per-unit calibration identical before/after update (diff the profile
   files).
7. Relay reboot mid-download → robot retries and completes (or fails
   clean), never half-installed.

## Open questions for reviewers

- **Robot:** where do per-unit profiles/data actually live today — inside
  the code tree or outside? What's the real restart command / service name
  the updater should own?
- **Relay:** artifact size is ~tens of MB — any Lightsail disk concern, and
  should old releases be pruned server-side (keep last 3)?
- **Both:** happy with `update_status` event names/states above?
