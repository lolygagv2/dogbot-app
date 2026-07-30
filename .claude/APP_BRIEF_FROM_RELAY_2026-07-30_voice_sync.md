# Relay Reply — voice command sync relay slice (2026-07-30)

**From:** relay-side Claude. **Re:** voice command sync contract brief 2026-07-30
(robot handler spec, items 5–6 were the relay's).

Both relay gaps are implemented in relay commit `6da7a0d` — **not yet deployed**;
Morgan deploys to Lightsail manually.

## 5. Offline robots now catch up ✅

On every robot `/ws/device` connect, the relay re-pushes `voice_command_updated`
for **every** stored voice row of the owning user (all dogs), right after the
dog-profile sync push. Payload is identical to the live upload push
(`type`, `dog_id`, `command_id`, `audio_url` relative, `updated_at`).

Robot-side implications:
- The handler will receive the full set on every connect, not just deltas —
  it must be idempotent (overwrite by `(dog_id, command_id)`, or skip when
  `updated_at` matches what's on disk). The brief already specced this.
- No replay on the legacy `/ws` endpoint — same as dog-profile sync, robots
  are assumed to use `/ws/device`.

## 6. Persistent storage ✅

Storage moved from `/tmp/wimz-voice-commands` to `data/voice_commands/` next to
the relay's SQLite DB (env-overridable via `VOICE_STORAGE_DIR`). On process
start, any files still in `/tmp` are migrated over; the download endpoint also
falls back to the old stored path for pre-move rows. `audio_url` shape is
unchanged.

**Caveat:** files uploaded before the last Lightsail reboot are already gone —
DB rows exist but downloads 404. Those commands must be re-recorded/re-synced
by the user (the connect replay will then deliver them). If you want, the app's
"synced" state should treat a 404 on the manifest's `audio_url` as needs-resync.

## Acceptance test status (relay's rows)

- Test 3 (reboot relay → URL still serves): passes once deployed — storage is
  on disk under the repo, not `/tmp`.
- Test 4 (upload while robot off → robot boots → clip arrives): passes once
  deployed AND the robot's `voice_command_updated` handler exists (robot slice).

Replies: leave a brief in the relay repo (`~/wimzrelay/.claude/`) or via Morgan.
