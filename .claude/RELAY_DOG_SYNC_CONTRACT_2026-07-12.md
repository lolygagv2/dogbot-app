# Relay contract fix request — dog id integrity + voice manifest filtering (2026-07-12)

**From:** app-side Claude instance. **To:** relay-side instance (Lightsail).
**User-visible bugs:** (1) every logout/login adds a replicated copy of each dog
profile in the app; (2) a freshly added dog shows/plays the previous dog's
custom voice recordings instead of defaults.

## Diagnosis (app-side evidence)

The app merges relay dogs by `id` and backfills "local-only" dogs via
`POST /dogs`. The duplication pattern (exactly one new replica per
logout/login cycle) implies the relay is **not honoring the client-supplied
dog id** on `POST /dogs` — it mints its own row id and echoes that from
`GET /dogs`. Cycle: app POSTs dog A → relay stores as X1 → next login GET
returns X1 (unknown id) → app adopts it → app sees A "missing" on relay →
POSTs again → relay mints X2 → and so on.

The voice bug: `GET /voice_commands?dog_id=<uuid-of-new-dog>` for a dog with
zero uploads must return `[]`. The app receiving another dog's manifest for
an unknown dog_id implies the filter falls through (unknown id → unfiltered /
last-dog results).

## Required relay behavior

1. **`POST /dogs` must upsert by the client-supplied id** (`id` field in the
   JSON body today; spec name `dog_id`, UUIDv7 or legacy `dog_<epochms>`,
   opaque TEXT, never recycled — see WIMZ_Data_Architecture_Spec §4 and
   APP_DOG_SCHEMA_ALIGNMENT_2026-07-05). Never mint server-side dog ids.
   Same id + same user → UPDATE, not INSERT.
2. **`GET /dogs` must echo that same id** in the `id` field of each record.
3. **`DELETE /dogs/<id>` must resolve by the same client id** — today a
   deleted dog can resurrect on next login because the app deletes by its id
   while the relay row lives under a minted one.
4. **`GET /voice_commands?dog_id=X` must filter strictly** — unknown or
   empty-result dog_id returns `[]`, never all/latest rows. Please also
   include `dog_id` in each manifest entry; the app now drops entries whose
   `dog_id` doesn't match the requested dog (defense shipped app-side).
5. **One-time cleanup:** dedupe existing `dogs` rows per user by name — keep
   the row whose id the app references if identifiable (the one voice_commands
   rows point at), else the oldest — and delete the rest. Also re-key or
   delete orphaned voice_commands rows attached to removed duplicate rows.

## What the app now does (shipped, Build 138+ working tree)

- Merge matches unknown relay ids **by name** (names are unique per user) and
  keeps the local id, so replicas no longer appear even before the relay fix.
- Backfill skips dogs the relay already has under any id — stops the POST
  storm that grew the relay table each login.
- Persisted duplicate lists self-heal on load (same-name collapse, keeping
  the earliest-created id).
- Voice hydration drops manifest entries stamped with a foreign `dog_id`.

App-side matching by name is a stopgap: renaming a dog on one device while
the relay id is unhonored can still fork a profile. Items 1–3 are the real
fix.
