# App ↔ WIMZ_Data_Architecture_Spec alignment — dog profile layer

Date: 2026-07-05 (Build 135 follow-up). Source of truth: `WIMZ_Data_Architecture_Spec.md` v0.1 (+v0.2 dispense fields). Per its rule 0: fields not in the spec get added to the spec first — nothing below invents schema; divergences are flagged as spec-change proposals for Morgan to rule on.

## Mapping: app `DogProfile` → spec `dog` table (§4)

| Spec field | App field | Status |
|---|---|---|
| `dog_id` (UUIDv7, never recycled) | `id` | **Fixed Build 135**: new dogs mint UUIDv7 (`Uuid().v7()`). Legacy ids (`dog_<epochms>`) remain valid opaque TEXT. |
| `user_id` | — (storage scope: email / `'local'`) | Relay owns the mapping on sync; app never fabricates one. |
| `name` | `name` | ✅ |
| `qr_code_id` | `arucoMarkerId` (int 0–999) | **Spec question 1** below. |
| `id_method` (`'qr'\|'direct_trained'\|'manual'`) | — | Not sent; enum has no ArUco value. **Spec question 1.** |
| `breed` | `breed` | ✅ |
| `birthdate` (epoch ms) | `birthDate` (DateTime) | Now sent as `birthdate` epoch ms in `reload_dogs` (additive). |
| `weight_g` (INTEGER) | `weight` (double, **no UI captures it**) | Not sent — nothing to populate; unit conversion deferred until the UI exists. |
| `signature` | — | Robot-produced; app never writes it. |
| `created_at` / `updated_at` (epoch ms) | `createdAt` / `updatedAt` | `updated_at` now sent epoch-ms in `reload_dogs`; drives §2 last-write-wins. |

## App-local fields NOT in the spec (stay out of the shared schema until added there)

`color`, `photoUrl`/`localPhotoPath`/`photoVersion`, `notes`, `goals`, `lastMissionId`, `treatsPerReward`. Of these, `color` and `treatsPerReward` already ride existing wire contracts (`reload_dogs` color; dispense logic) — **spec question 2**.

## Wire contract (unchanged + additive)

`reload_dogs` keeps its existing keys (`name`, `aruco_id`, `color`, `id`, `breed`) so current robot handlers don't break, and now ALSO carries spec-named `dog_id`, `birthdate`, `updated_at`. Robot side can reconcile into its `dog` table reading only the spec-named keys.

## Spec-change proposals (need owner ruling + spec version bump; do not build ahead)

1. **ArUco identity**: spec models visual identity as `qr_code_id` + `id_method ∈ {qr, direct_trained, manual}`; the fleet actually uses ArUco DICT_4X4_1000 markers. Either rename `qr_code_id` → `marker_id` with `id_method` gaining `'aruco'`, or declare ArUco ids ARE `qr_code_id` values. App sends `aruco_id` until ruled.
2. **`color` and `treats_per_reward`**: both are app-authoritative, human-entered, already used by the robot (LED/tracker hints, dispense count). Propose adding to the `dog` table so they survive edge-side and aggregate.
