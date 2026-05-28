# Robot-Side Issues — Captured 2026-05-27 (Build 104 testing)

These two issues were reported during app testing today. Both are robot-side
(detection / classification pipeline) and cannot be fixed from the Flutter
app. Captured here so the robot team has full repro context.

---

## Issue R1 — Coach mode rewarded "spin" while dog ran into the wall

**When:** ~18:09:30 local (America/New_York), 2026-05-27 — about 50 minutes
before this note was written.

**Symptom:** App received a `coach_reward` event from the robot tagged as a
"spin" success. Operator observed the dog physically running into the wall
at that moment, NOT spinning. The reward triggered a "good" callback + treat
dispense.

**Suspect surface:** the trick / behavior classifier in
`core/ai_controller_3stage_fixed.py` (or whichever stage owns trick
classification). The pose-estimation stage may be misreading a forward-lunge
+ wall-collision pose sequence as the spin signature.

**App can't fix this:** the app trusts the classifier's verdict; it has no
ground-truth signal to second-guess what the robot reports.

**Suggested investigation:**
1. Pull the saved frame buffer / pose timeline for the 18:09:25–18:09:35
   window from the robot.
2. Check whether `confidence` was reported and how high it was — if `>0.8`
   the classifier is overconfident on a false positive.
3. Tighten the spin classifier — require rotational continuity over ≥N
   frames before firing the reward.
4. Consider gating coach rewards on a sanity check: dog should not be
   accelerating into a fixed obstacle (use depth/ToF or recent path).

**App-side instrumentation already available:** `notifications_provider`
keeps an in-app feed of all `coach_reward` events with timestamps. Cross-
reference against the robot's classifier log for the same window.

---

## Issue R2 — "Barking detected" events flooding the dog feed

**Symptom:** The dog activity feed is being spammed with `bark` events.
Operator suspects either (a) audio feedback from coach-mode TTS being
re-detected as barks, or (b) the YAMNet (or whichever audio classifier the
robot uses) misclassifying ambient sound.

**Suspect surfaces:**
- Speaker→mic feedback path. When coach mode plays its prompt/reward
  sounds, the audio bleeds into the mic and the bark classifier fires.
  This was a known risk in earlier sessions but apparently not gated.
- YAMNet confidence threshold too low. Many household sounds (door slam,
  chair scrape, TV) score moderately on the "Bark" class.
- No "self-audio mute" window around robot speaker output.

**App can't fix the underlying classification.** But the app-side
notification routing is already user-configurable — `settings_provider`
defaults `NotificationEventType.bark` to `NotificationChannel.inApp`
(in-app feed only, no OS push). The user can further mute it via
Settings → Notifications. Verified in this build: bark notifications are
NOT pushed to the lock screen by default; they only flood the in-app
feed because the robot is emitting too many of them.

**Suggested investigation:**
1. Gate the bark classifier off whenever the robot's own speaker is
   playing. Should be a simple boolean flag from the TTS/audio module.
2. Raise YAMNet `bark` confidence threshold to ≥0.7 (or whatever the
   measured false-positive rate suggests).
3. Add a debounce: at most one bark event per N seconds, unless a
   distinct silence window separates them. Avoids storm-firing on a
   single continuous bark.
4. Consider adding a "bark intensity" envelope (peak dB + duration) so
   the app can filter quiet/short clicks at the receive end without
   suppressing real barks.

**Coordinates for the robot team:** the relay-side event shape is
unchanged — the app handles whatever the robot emits; just emit less.

---

## Carried forward

If/when fixes ship, the next app session can verify by:
- R1: triggering coach mode and watching for spurious rewards.
- R2: monitoring the in-app activity feed during 5-minute coach session
  in a quiet room and counting bark events.
