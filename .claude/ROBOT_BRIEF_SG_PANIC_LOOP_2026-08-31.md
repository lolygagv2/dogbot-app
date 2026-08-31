# Robot Brief — OTA confirmations + SG analytics / Panic / Loop contract (2026-08-31)

**From:** Robot Claude (relayed via Morgan). **App slices shipped:** Build 155.

## Part 1 — OTA robot slice (robot commit c28ed1f)

- Implemented, bootstrapping tb5 first. Event shape + states confirmed
  EXACTLY as the app parses them (see ROBOT_OTA_INSTRUCTIONS_2026-08-30.md).
- Refusal examples arrive as `state:"failed"` + `error`: "robot is not idle
  (mode: manual)", "battery too low (24% < 30%)", "live video session
  active — close it and retry", "an update is already in progress",
  "robot updater not installed yet (OTA bootstrap pending)".
- Terminal events emitted exactly once by whichever process survives the
  restart; **success/rolled_back can arrive up to ~60–90s after
  `restarting`** (post relay-reconnect) — app must not timeout early
  (encoded in ota_update_provider).
- Robot events go out with `event` field; relay maps it to `type`.
- Data layout: `/home/morgan/wimz/releases/<version>/` (code) +
  `/home/morgan/wimz/shared/` (per-unit data + venv) symlinked in;
  `/home/morgan/dogbot` → symlink to `wimz/current`. Service:
  `treatbot.service`; health = GET localhost:8000/health, updater polls up
  to 150s (>150s silence after `restarting` = rollback path running).
- `sw_version` ships NOW pre-freeze-lift (VERSION file at release root);
  tb5 reports `2026.08.1`. Fleet units report it once Morgan pulls+restarts.

## Part 2 — contract 137a5e8: SG analytics, Panic, Loop

### Robot→app events (id + ISO8601 timestamp; dog_id canonical UUID or null)

**`sg_summary`** — sent (a) auto ONCE per session on first Level-4
escalation, `action: "level4_escalation"` → push + summary card; (b) reply
to `sg_status_pull` command, `action: "status_pull"` → card only, no push.
Payload: session_id, session_duration_sec, total_barks, bark_types,
bark_type_percentages, bark_timeline ([{offset_min, counts}]),
treats_dispensed, interventions_triggered, current_escalation_level,
fsm_state, trend (improving|worsening|flat), trend_detail
({recent_rate_per_min, session_rate_per_min, window_minutes}),
current_action, headline, aggressive_tag, panic_active, panic_episodes.
Bark-type keys: distress, demand, alarm, aggressive, play, unclassified.
`headline`/`current_action` are pre-phrased — display VERBATIM.
Pull while SG idle → `running: false` + `error` instead.

**`panic_alert`** — `action: "started"` (severity "warning", or "high"
after >2 episodes/session) / `action: "ended"` (severity "info"). Carries
trigger (burst|sustained_rate|futility), dog_id/dog_name, pre-phrased
`message`, episode_num, loud_noise_prior, bark_type_mix; ended adds
duration_sec. High-priority push; "Live view available" invites tap-through
to the live stream.

**`guardian` action:"stopped"** now also carries bark_types, headline,
aggressive_tag ("Your dog was aggressive today" tag), panic_episodes.

**`audio_state`** now includes `loop_mode: "off"|"one"|"all"` — drives the
Loop button.

### App→robot commands (relay command channel)
- `{"command": "sg_status_pull"}` → sg_summary (action: status_pull),
  computed live, any time SG runs.
- `{"command": "audio_loop", "mode": "off"|"one"|"all"}` — one repeats
  current song, all auto-advances playlist, off restores play-once. Echoed
  via audio_state.

### Local mode REST equivalents (relay down)
GET `/sg/summary`, POST `/audio/loop {"mode": ...}` on the robot's local
API. (App v1 sends the WS commands over whichever socket is active; REST
fallback not wired — verify WS commands work on /ws/local during AP test.)

### Scratched
"Capture video clip on panic" — use existing record button / live view.

## App slices shipped (Build 155)
- WS: sg_summary/panic_alert routed (device-filtered); status_pull replies
  join the transient watermark carve-out (level4 + panic_alert take the
  normal feed path); sendSgStatusPull(), sendAudioLoop().
- Notification types panicAlert + sgSummary (both default In-app + Push,
  togglable in preferences; names flow to relay enabled_types — RELAY must
  add panic_alert/sg_summary to its FCM event-type mapping for real pushes).
- panic_alert → high-signal notification using robot's pre-phrased message;
  sg_summary level4 → notification with headline; guardian stopped with
  payload → "Guardian Session Ended" summary entry (+aggressive/panic tags).
- SG feed: live SgSummaryCard (headline, current_action, stats, stacked
  bark-type % bar, trend, panic/aggressive tags, refresh = sg_status_pull
  with 10s timeout for pre-137a5e8 robots).
- Music controls: Loop button cycling off→all→one, rendered ONLY from the
  audio_state loop_mode echo (no optimistic flip).
- bark_timeline + trend_detail are received but not yet charted (future).
