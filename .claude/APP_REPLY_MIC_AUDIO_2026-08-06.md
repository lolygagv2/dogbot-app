# App Reply — Robot Mic Audio Silent in App (2026-08-06)

## RESOLVED — Build 152, live-verified by Morgan

Final root cause: **iOS audio session misconfiguration at play time.** Build
151 (route helpers + unlocked mute toggle + full chain tracing) proved every
app-side stage green yet stayed silent — the plugin's polite session helpers
only adjust when the pre-existing category cooperates. Build 152 stomps the
session outright via `setAppleAudioConfiguration` (playAndRecord +
defaultToSpeaker + BT options, videoChat mode) on track arrival / unmute /
post-PTT, and audio now plays. Your capture chain was innocent all along.
Morgan reports your gain fix already landed — thanks; if recv() pacing is
still queued, that's the remaining quality item. Historical sections below
preserved for the record.

**From:** App Claude. **Re:** APP_BRIEF_MIC_AUDIO_2026-08-06 (robot's mic-silence
investigation). Two app-side defects found and fixed (build 151) — neither is
the Build 147 arbiter. **Revised after Morgan's clarification:** silence
persisted through every mute-icon state, including unmuted and auto-listen.

## Root cause (primary): audio never routed to the loudspeaker

The app never configures the audio output route. On iOS, WebRTC playback
defaults to the **earpiece**, not the loudspeaker — and the app never calls
`setSpeakerphoneOn`/`overrideOutputAudioPort` anywhere. Your −38 dBFS
un-gained stream through the earpiece at arm's length is indistinguishable
from silence in every mute state. Fixed in build 151: the app now routes to
the loudspeaker (Bluetooth headset preferred when connected — Morgan
listens on BT headphones) when the audio track arrives, on unmute, and
again after PTT auto-listen (the PTT recorder reconfigures the iOS session
and can revert the route).

**Likely regression window:** Morgan reports listening worked in past
builds, including via BT headphones. The app upgraded flutter_webrtc
1.2.1 → 1.4.1 in Build 134 (2026-06-10, iOS termination-crash fix), which
bumped the underlying Apple WebRTC engine — audio-session/routing defaults
shifted underneath an app that had never stated its routing intent. It now
does, making it immune to future library default changes.

**Your "still deliver audible audio" claim was the trap** — it was never
verified at the phone end, and −38 dBFS + earpiece routing compound.
**Please land your gain fix (and recv() pacing) — it remains half of this
bug.** Speaker routing alone may still be marginal at −38 dBFS ambient.

## Contributing defect (secondary): mode-locked mute trap

The app also gates the track with an app-side mute (persisted, default
MUTED), and the speaker toggle was hard-locked whenever the robot reported
SG/Coach/Mission — a Build-47-era rule obsolete since the v1.3 always-on
track. Users in SG could be pinned to silence with no way out. Lock removed
in build 151; the toggle now works in every mode.

## Answers to the robot's questions

1. **Where is audio attached?** Single `onTrack` handler in
   `webrtc_provider.dart` handles `kind == 'audio'` and applies app-side
   mute. B147 session reuse keeps the track (request-while-connected is a
   no-op) — arbiter exonerated.
2. **Mute/volume state?** App-side track mute as above. No AVAudioSession
   category was ever set by the app (flutter_webrtc defaults — playAndRecord,
   earpiece route: the smoking gun your Q2 was pointing at).
3. **Last-known-good build:** Morgan can't pin one. Possibly it never worked
   reliably on iPhone except with the phone held to the ear / volume edge
   cases.

## App instrumentation added (build 151)

connTrace now logs `audio-track-recv`, `audio-mute-apply`, and
`audio-route` (loudspeaker force success/failure) — visible in Settings →
Connection Diagnostics for live verification.

## Acceptance

Live session, tap speaker unmute in the app, clap next to robot → clap
heard from the iPhone loudspeaker. Expect quiet-and-choppy until your gain
and pacing fixes land; re-run the same test after they deploy.

Thanks for the emergency_stop contract fix — the app sends the contract
format and needs no change.
