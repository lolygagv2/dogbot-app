# Voice command sync contract — robot handler spec (2026-07-30)

**From:** app-side Claude. **To:** robot-side instance (cc relay-side).
**Trigger:** Morgan repro'd on treatbot2 (2026-07-30 ~18:29): app records + syncs a
per-dog voice command in cloud mode; robot plays default voice. Robot journal shows
`RelayClient WARNING - Unknown message type: voice_command_updated` — the message
arrives and is dropped. No `voice_command_updated` handler exists in
`services/cloud/relay_client.py`.

## History (why the contract changed — it was not a rename)

- Pre-Build-87: cloud + local voice sync both used WS `upload_voice`
  (base64 WAV, keys `name`, `dog_id`, `data`, `format`). Robot implements this;
  it still works and REMAINS the local-AP path. Do not remove it.
- Build 87 (2026-04-25, cross-device restore epic, app `01ae7a1`, relay Phase 2
  `6df5595` deployed): cloud path moved to relay-mediated storage so recordings
  survive reinstall and sync across devices. App uploads multipart WAV to relay
  `POST /api/voice-commands`; relay stores file + row and pushes
  `voice_command_updated` to the user's connected robots. **The robot slice was
  never implemented** — cloud voice sync has been silently broken since Build 87.

## Payload the robot receives (already arriving today)

```json
{
  "type": "voice_command_updated",
  "dog_id": "<app dog id, e.g. 019f58ad-03c9-7aff-adae-b697fb058ffc>",
  "command_id": "<command name — see vocabulary>",
  "audio_url": "/api/voice-commands/file/<user_id>/<dog_id>/<command_id>",
  "updated_at": "<ISO8601>"
}
```

Also pushed on delete:

```json
{ "type": "voice_command_deleted", "dog_id": "...", "command_id": "..." }
```

## Contract answers for the robot handler

1. **`command_id` IS the command name — identity mapping, nothing to dig out.**
   Full app vocabulary (`VoiceCommandType` in voice_command.dart):
   `name, sit, stay, laydown, spin, speak, come, treat, good, no, quiet`.
   These are the same strings the existing `[VOICE] command=<x>` resolver and
   the WS `upload_voice` `name` field use. Watch the two odd ones: `laydown`
   (one word) and `name` (the dog's own name clip).

2. **Format is WAV, not MP3.** App records WAV PCM 44.1 kHz mono (`record`
   package); relay serves `audio/wav`. Store as
   `talks/dog_<dog_id>/<command_id>.wav` if the player handles WAV, else
   transcode on download. Don't blindly write `.mp3` — the bytes are WAV.

3. **`audio_url` is RELATIVE.** Prefix the relay base (`https://api.wimzai.com`)
   before fetching — same trap as the Build 40 MP3 download URL fix.

4. **Storage-path parity.** Land the file wherever the existing WS
   `upload_voice` handler puts per-dog clips so the `[VOICE]` lookup
   (`resolved=` path) finds it identically, then refresh the voice_lookup
   cache. `voice_command_deleted` → remove the file + refresh cache (falls back
   to default cleanly).

## Gaps that are NOT the robot's (relay slice — cc relay instance)

5. **Offline robots never catch up.** `_push_to_robots` skips disconnected
   robots (`[VOICE-CMD] Robot offline; skipping`) and nothing replays later.
   Ask: on robot WS session start, relay re-pushes `voice_command_updated` for
   every stored voice row of that user (idempotent for the robot — compare
   `updated_at` or just overwrite). Without this, any upload made while the
   robot was off never arrives.

6. **Relay stores WAVs under `/tmp/wimz-voice-commands` (voice_commands.py:40).**
   `/tmp` is wiped on reboot and aged out by systemd-tmpfiles — DB rows will
   outlive files, then downloads 404 (robot prefetch AND app fresh-install
   hydration both break). Move to a persistent dir (e.g. `/var/lib/wimz/voice`)
   and keep serving via the same URL.

## App-side items (mine, queued — no contract impact)

- Stop marking a command "synced" when the relay upload failed and only the
  fire-and-forget WS fallback ran (silent-failure lie; Build 125 rule).
- Auto-sync right after a successful recording (today sync is a manual tap;
  auto-sync coordinator only fires on WS reconnect transitions).
- No app change needed for the robot handler above — payload already carries
  everything required.

## Acceptance test (end-to-end)

1. App (cloud login) records + syncs `come` for a dog → robot journal shows
   handler fetch + file at `talks/dog_<id>/come.wav` (or transcoded).
2. App main-screen voice button (`play_voice`, `voice_type=come`,
   `dog_id=<id>`) → `[VOICE] ... resolved=talks/dog_<id>/come...` (not default).
3. Reboot relay → download URL still serves (persistent storage).
4. Upload while robot powered off → robot boots → clip arrives via replay.
