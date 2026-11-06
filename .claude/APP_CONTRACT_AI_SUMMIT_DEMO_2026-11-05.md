# App → Relay / Robot — AI Summit demo slice (Dec 9), app Build 165

**From:** App Claude (via Morgan), 2026-11-05. The app slice is SHIPPED in
Build 165 and parses every payload below leniently (missing fields render
as empty, 404 = "not available"). Nothing here blocks the app from building;
each endpoint lights up its screen the moment it exists. All REST calls carry
the user's JWT (`Authorization: Bearer`) in cloud mode; in local-AP mode the
app hits the same paths on the robot without a token.

## 1. Today card — `GET /summary/{dog_id}/{YYYY-MM-DD}`  (relay; robot locally)

Served for the owner's local-day date. The app renders fully with `stats`
alone; `headline`, `highlights` and `plan` are optional. "Works with no AI
plan" = `plan` absent/null → the card simply has no plan block.

```json
{
  "dog_id": "uuid", "dog_name": "Elsa", "date": "2026-12-09",
  "headline": "Quiet morning, two good sits.",        // optional, pre-phrased, shown verbatim
  "stats": {
    "barks": 3, "treats": 4, "sits": 2,
    "coaching_attempts": 6, "coaching_completed": 5,
    "quiet_minutes": 410, "guardian_interventions": 1
  },
  "highlights": [ {"time": "09:14", "text": "Sat on first cue", "image_url": "/media/x.jpg"} ],   // optional
  "plan": { "source": "claude", "title": "Tonight", "items": ["Two sit reps after dinner"] }    // optional / null
}
```
- `404` → no rows for that day; the app shows counts derived from its own
  activity feed and a "counts from this phone" caption. Any other error →
  same fallback with a warning caption.
- An envelope `{ "summary": {...} }` is also accepted.

## 2. Connected AI (relay)

| Call | Purpose | Response |
|---|---|---|
| `GET /api/ai/connections` | connector URL, kill-switch state, connected assistants | `{connector_url, enabled, assistants:[{id, name, provider, scopes:[..], connected_at, last_used_at}]}` |
| `DELETE /api/ai/connections/{id}` | revoke one assistant (immediate) | 204 (404 = already gone, treated as success) |
| `POST /api/ai/kill-switch` `{enabled: bool}` | `enabled=false` refuses EVERY assistant at the relay | `{enabled}` |
| `GET /api/ai/audit?limit=30` | audit log, newest first | `{entries:[{id, ts, assistant, provider, action, scope, result: ok\|denied\|error, detail}]}` |
| `POST /api/ai/drafts/{draft_id}/decision` `{decision: approve\|decline}` | owner's verdict on a drafted mission | 200/204 |

- `provider` ∈ `chatgpt | claude | grok | perplexity` (vendor spellings such
  as `openai`, `anthropic`, `xai` are also mapped).
- `GET /api/ai/connections` → **404** = slice not deployed; the screen shows
  "not available on this server yet" instead of an error.
- Optional WS broadcast `{"type":"ai_connection_changed"}` to the owner's app
  sessions makes the screen reload without a pull-to-refresh.

### WS events the app consumes (relay → app, user-scoped, same envelope as today)
- `mission_draft` — an assistant drafted a mission and wants approval. Push
  it (FCM) like `treat_dispensed`; title "<assistant> proposed a mission".
  ```json
  {"type":"mission_draft","draft_id":"uuid","title":"Evening sit drill",
   "summary":"Three short sits before dinner","steps":["Call","Sit 3s","Reward"],
   "proposed_by":"Claude","provider":"claude","dog_id":"uuid","dog_name":"Elsa",
   "expires_at":"2026-12-09T20:00:00Z","image_url":"/media/optional.jpg"}
  ```
  A nested `{"type":"mission_draft","draft":{...}}` form is accepted too.
  Persist it in `activity_events` (type `mission_draft`, payload as above, plus
  `status` once decided) so the feed tile survives an app restart.
- `mission_draft_status` `{draft_id, status: approved|declined|expired}` —
  echo after a decision made on another device / expiry. Transient.
- `agent_transcript` `{assistant, provider, role: user|assistant|tool, text, ts}`
  — one line per turn of an assistant session, shown live on the Demo view.
  Transient (no replay buffer, no push).
- WS command fallback (local mode / REST missing):
  `{"command":"mission_draft_decision","data":{"draft_id":"…","decision":"approve|decline"}}`.

### Attachments on ANY event
If an event (live WS or `activity_events` row payload) carries
`image_url` / `snapshot_url` / `still_url` / `thumbnail_url` or
`clip_url` / `video_url` (top level, or under `data` / `payload` / `media`),
the app shows a thumbnail in the feed, a full-screen viewer on tap, and
attaches the still to the lock-screen notification. Relative paths resolve
against the API host (`https://api.wimzai.com/…`). Clips: MP4/H.264 please.

## 3. Sounds (relay forwards to the selected robot by `device_id`; robot serves the same paths locally)

| Call | Purpose |
|---|---|
| `GET /api/sounds?device_id=…` | `{sounds:[{id, group, label?, custom: bool}]}` — optional; the app has a default catalog (ids below) and lists any extra ids the robot reports |
| `POST /api/sounds/{sound_id}` multipart `file` + `device_id` + `sound_id` | replace one sound (mp3/wav/ogg/m4a ≤ 10 MB) |
| `POST /api/sounds/reset` `{device_id, sound_id?}` | factory-restore all sounds (or one) |

Default catalog ids (rename freely — the robot's `GET /api/sounds` wins):
`greeting` · `treat`, `good` · `cue_sit`, `cue_down`, `cue_come`, `cue_stay`,
`cue_quiet`, `cue_no` · `alert`, `low_battery` · `sg_level_1..4` ·
`music_calm`, `music_play`, `music_sleep`, `music_focus`.
`group` ∈ `greeting | treat | cue | alert | sg_level | music`.

Song upload is unchanged: `POST /api/music/upload` (file, dog_id, device_id);
local mode uses the existing WS `upload_song` base64 path.

## 4. Nothing else changed on the wire
No new push event-type mapping besides `mission_draft`. No change to the
watermark/replay rules: `agent_transcript`, `mission_draft_status` and
`ai_connection_changed` are transient (never buffered, never pushed).
