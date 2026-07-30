# Push notifications contract — relay slice spec (2026-07-30)

**From:** app-side Claude. **To:** relay-side instance (Lightsail).
**Decision (Morgan):** Firebase / FCM for both platforms. NO robot changes —
the relay already ingests every event we push about.

## Why

The app's "+ Push" notification tier has never delivered to a locked phone:
it is local-notifications-only, and iOS suspends the app (killing the relay
WS) seconds after backgrounding. Real delivery = relay → FCM → OS. The
Silent Guardian use case (owner away, dog barks, phone buzzes) depends on it.

## App slice (SHIPPED app-side, this date — awaiting this relay slice)

- On login (and token rotation / preference change) the app calls
  `POST /api/push/register`. On logout: `POST /api/push/unregister`.
- Push stays soft-disabled in the app until Morgan runs `flutterfire
  configure` (placeholder firebase_options.dart) — so register calls will
  only start arriving once the Firebase project exists. Endpoints can ship
  first; nothing breaks in either order.
- iOS `aps-environment` entitlement added; Android POST_NOTIFICATIONS was
  already declared.

## Required relay endpoints

### POST /api/push/register  (JWT auth)
```json
{ "device_token": "<FCM token>", "platform": "ios" | "android",
  "enabled_types": ["bark", "treatDispensed", ...] }
```
- Upsert by `device_token` (unique). Store `user_id` from the JWT, platform,
  enabled_types (JSON), updated_at. Multiple devices per user are normal.
- Same endpoint serves first registration, FCM token rotation, and
  preference edits (app debounces; last write wins).
- `enabled_types: []` is valid — keep the row, send nothing (master switch
  off). 200/201.

### POST /api/push/unregister  (JWT auth)
```json
{ "device_token": "<FCM token>" }
```
- Delete the row. Best-effort from the app on logout; also prune any token
  FCM reports as invalid (HTTP 404 / UNREGISTERED) when sending. 200/204.

## Sender

On activity-event ingest (same place rows are written / FEED_WORTHY events
rebroadcast): map the row to an app type name (table below); for each of the
owner's registered devices whose `enabled_types` contains that name, send an
FCM HTTP v1 message:

```json
{ "message": {
    "token": "<device_token>",
    "notification": { "title": "<see table>", "body": "<subtitle or ''>" },
    "apns": { "payload": { "aps": { "sound": "default" } } },
    "data": { "type": "<app type name>", "dog_id": "<or ''>", "event_id": "<row id>" }
} }
```

Notification-type messages are displayed by the OS while the app is
suspended/killed — exactly what we need. When the app is foregrounded the OS
suppresses the banner on both platforms (the in-app feed covers it), so no
dedup against live WS sessions is required. Optional nicety later, not v1.

### Event-type mapping (mirror of the app's `_activityEventToNotification`)

| relay row type | app type name (`enabled_types` key) | suggested title |
|---|---|---|
| `bark` | `bark` | "Barking Detected" (+ emotion) |
| `treat_dispensed` | `treatDispensed` | "Treat Dispensed" |
| `coach_reward` | `coachReward` | "<trick> rewarded" |
| `guardian_alert` | `alert` | "Guardian: <reason>" |
| `guardian` (skip lifecycle actions start/stop/reset) | `alert` | "Guardian Alert" |
| `mission_started` | `missionStarted` | "Mission Started" |
| `mission_completed` (success) | `missionCompleted` | "Mission Completed" |
| `mission_completed` (success=false) | `missionFailed` | "Mission Failed" |
| `behavior_flag` by payload.behavior: sit/sitting→`sit`, laydown/lie_down/down→`lieDown`, come/stand→`stand`, bark→`bark`, else→`alert` | | "<Behavior> Detected" |
| `low_battery` (if/when ingested) | `lowBattery` | "Low Battery" |

Full app vocabulary the app may send in `enabled_types` (superset of the
table; unknown-to-relay names are fine to store): `bark, sit, lieDown,
stand, treatDispensed, missionStarted, missionCompleted, missionFailed,
lowBattery, alert, happy, connected, disconnected, coachReward`.

If a dog name is known for the event, prefix the body with it ("Rex: ...")
— rows carry dog_id since 2026-07-26.

## Credentials (Morgan provides)

1. Create a Firebase project; add iOS app (bundle `com.wimzai.app`) and the
   Android app.
2. Apple Developer → Keys → create an **APNs auth key (.p8)** → upload to
   Firebase console (Project Settings → Cloud Messaging → Apple app).
3. Firebase console → Service accounts → generate a **service-account JSON**
   → to the relay (env var path, NOT in the repo). Relay sends via FCM HTTP
   v1 (`google-auth` for the OAuth token or the `firebase-admin` package).
4. Morgan runs `flutterfire configure` in the app repo (regenerates
   firebase_options.dart) — app-side push then activates on next build.
5. Apple Developer portal: enable the Push Notifications capability on the
   `com.wimzai.app` App ID (Codemagic signing must pick up the updated
   provisioning profile — watch the stale-build trap).

## Acceptance test

1. App logs in → relay has a device row with that user's enabled types.
2. Trigger SG bark (bark set to "+ Push" in app prefs) with the app
   force-quit → phone shows the banner on the lock screen.
3. Toggle bark to "In-app" in the app → relay row updates within ~2s →
   next bark sends nothing.
4. Logout → row deleted.
5. Send to a stale/rotated token → relay prunes the row on FCM 404/410.
