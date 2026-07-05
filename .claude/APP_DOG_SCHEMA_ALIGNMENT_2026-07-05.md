# App ↔ WIMZ_Data_Architecture_Spec alignment — dog profile layer

Date: 2026-07-05, updated same day for spec **v0.3**. Source of truth: `WIMZ_Data_Architecture_Spec.md`. Per its rule 0: fields not in the spec get added to the spec first — nothing below invents schema.

**v0.3 resolved both open questions from the first pass:** ArUco markers ride the existing `qr_code_id` / `id_method='qr'` (no new identity fields), and `color` + `treats_per_reward` are now real `dog` columns (app-authoritative, robot-consumed). App payload updated to match.

## Mapping: app `DogProfile` → spec `dog` table (§4, v0.3)

| Spec field | App field | Status |
|---|---|---|
| `dog_id` (UUIDv7, never recycled) | `id` | ✅ New dogs mint UUIDv7 (Build 135). Legacy ids (`dog_<epochms>`) remain valid opaque TEXT. |
| `user_id` | — (storage scope: email / `'local'`) | Relay owns the mapping on sync; app never fabricates one. |
| `name` | `name` | ✅ |
| `qr_code_id` (TEXT; ArUco ids, called "QR") | `arucoMarkerId` (int 0–999) | ✅ Sent as `qr_code_id` string when a marker is assigned; omitted (nullable) otherwise. |
| `id_method` (`'qr'` covers ArUco) | derived | ✅ Sent as `'qr'` when a marker is assigned; omitted otherwise ('direct_trained' is robot-side signature territory). |
| `breed` | `breed` | ✅ |
| `birthdate` (epoch ms) | `birthDate` | ✅ Sent epoch ms. |
| `weight_g` (INTEGER) | `weight` (double, **no UI captures it**) | Not sent — nothing to populate; add when a weight UI exists. |
| `color` (TEXT, v0.3) | `color` (`DogColor.value` string) | ✅ Already sent as the string value (`black`/`yellow`/…). |
| `treats_per_reward` (INTEGER, v0.3; null → robot defaults 1) | `treatsPerReward` (1–5, default 1) | ✅ Now sent. |
| `signature` | — | Robot-produced; app never writes it. |
| `created_at` / `updated_at` (epoch ms) | `createdAt` / `updatedAt` | ✅ `updated_at` sent epoch ms; drives §2 last-write-wins. |

## App-local fields NOT in the spec (stay out of the shared schema)

`photoUrl` / `localPhotoPath` / `photoVersion` (device photo cache), `notes`, `goals`, `lastMissionId`. UI-local; none cross a surface today. If any ever needs to sync, it goes into the spec first.

## Wire contract (unchanged + additive)

`reload_dogs` keeps its legacy keys (`name`, `aruco_id`, `color`, `id`, `breed`) so current robot handlers don't break, and ALSO carries the spec-named v0.3 set: `dog_id`, `birthdate`, `updated_at`, `qr_code_id`, `id_method`, `treats_per_reward`. Robot side can reconcile into its `dog` table reading only the spec-named keys; once it does, the legacy keys can be retired in a coordinated pass.

## Open items

- `weight_g`: blocked on the app growing a weight input (spec field exists; app has a never-populated `weight` double).
- Legacy-key retirement in `reload_dogs` after the robot reads the spec-named keys.
