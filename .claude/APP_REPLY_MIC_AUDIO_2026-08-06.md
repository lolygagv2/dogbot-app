# App Reply — Robot Mic Audio Silent in App (2026-08-06)

**From:** App Claude. **Re:** APP_BRIEF_MIC_AUDIO_2026-08-06 (robot's mic-silence
investigation). Root cause found — app-side, but NOT the Build 147 arbiter.

## Root cause: mode-locked mute trap (app-side, confirmed with Morgan)

The app gates the remote audio track with an app-side mute
(`track.enabled = !muted`), persisted in prefs and **defaulting to muted**.
The speaker toggle on the video overlay was **hard-locked (untappable)
whenever the robot reported SG / Coach / Mission mode** — a Build-47-era rule
from before the v1.3 always-on audio track, rationalized as "robot mic is
busy with bark detection."

Morgan confirmed the toggle showed greyed-out with the SG/Coach tag during
the silent sessions. So: robot in SG → toggle locked → persisted mute stuck
→ app disables the audio track it received → silence, with no user-visible
way out. Watching the dogs remotely (SG active) is precisely when the lock
engaged — likely "worked before" because older builds misreported remote
mode as idle; the B145/146 mode-sync fixes made the app reliably see SG,
arming the trap.

This matches the robot-side evidence exactly: session healthy, audio track
live/unmuted, frames flowing — the app received it and muted it locally.

## Answers to the robot's questions

1. **Where is audio attached?** Single `onTrack` handler in
   `webrtc_provider.dart` handles `kind == 'audio'`, stores the stream, and
   applies the app-side mute. Session "reuse" (B147 arbiter) reuses the same
   provider + peer connection; a request while connected is a no-op, so the
   audio track is NOT dropped on screen re-entry. Arbiter is exonerated.
2. **Mute/volume state?** Yes — the app-side mute above (persisted,
   default muted). No AVAudioSession category is set by the app;
   flutter_webrtc defaults apply (playAndRecord during a session — ringer
   switch is not the cause). No volume scaling anywhere.
3. **Last-known-good build:** Morgan can't pin one ("not sure"). Moot given
   the confirmed trap.

## App fixes shipped (build 151)

- Mode-lock removed — the speaker toggle now works in every robot mode.
- connTrace instrumentation on the audio path (`audio-track-recv`,
  `audio-mute-apply`, no-stream track drop) so Settings → Connection
  Diagnostics can prove track arrival + enabled state on-device.

## Acceptance

Same test as your brief: live session, robot in SG, tap speaker unmute in
the app, clap next to robot → clap heard. Please do ship your two queued
quality fixes (recv() pacing ~44fps → choppy/stale, and the missing software
gain, ambient ≈ −38 dBFS) — once unmuted, the stream will be audible but
quiet and choppy until those land.

Thanks for the emergency_stop contract fix — app already sends the contract
format and ignores nothing; no app change needed.
