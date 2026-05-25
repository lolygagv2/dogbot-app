Night Mode Implementation Brief — Flutter App
Context
The robot now has IR night vision hardware (NoIR camera + 940nm IR illuminator with built-in auto-on sensor). The robot detects ambient light via its camera and switches into a "night mode" automatically. The app needs to:

Display the current mode (day or night) to the user
Display the current lux reading for transparency
Let the user override automatic detection with a three-state setting (Auto / Force Day / Force Night)
Visually adapt the video feed view to indicate night mode is active

The mode is purely a camera/visual state on the robot side. The video stream itself does not change format — same WebRTC connection, same resolution. What changes is the image content (monochrome IR-lit) and the app's display chrome around it.
Codebase orientation
This is the existing Flutter companion app, currently at Build 80+. Find the existing live video / robot control screen — that's where night mode UI belongs. Match the existing state management pattern (likely Provider, Riverpod, or Bloc — use whatever the rest of the app uses, don't introduce a new one).
The app already has a messaging layer that talks to the robot via the AWS Lightsail relay (api.wimzai.com). Find that layer; we'll add two new message types to it.
Implementation tasks
1. New message types in the messaging layer
Add handling for two new inbound/outbound messages:
Inbound from robot: night_mode_state
{
  "type": "night_mode_state",
  "mode": "day" | "night",
  "override": "auto" | "force_day" | "force_night",
  "lux": <float or null>,
  "last_changed_at": "<ISO8601 timestamp>"
}
Pushed by the robot on every transition and as a 60-second heartbeat.
Outbound to robot: set_night_mode_override
{
  "type": "set_night_mode_override",
  "override": "auto" | "force_day" | "force_night"
}
2. State management
Create a NightModeState model and a corresponding controller/notifier (whatever pattern the app uses).
State fields:

currentMode: DayNight.day or DayNight.night
override: Override.auto, Override.forceDay, or Override.forceNight
currentLux: double?
lastChangedAt: DateTime?
isConnected: bool (true if we've received a state message in the last 90 seconds — gives some buffer over the 60s heartbeat)

The state should:

Update from incoming night_mode_state messages
Send set_night_mode_override when the user changes the override
Optimistically update the local override state immediately on user action, then reconcile with the next inbound message from the robot

3. UI components
A. Mode indicator badge on the live video screen.
Small badge overlaid on the video feed, top-right corner. Two visual states:

Day: subtle, low-emphasis — sun icon, light gray or white with low opacity. Doesn't draw attention.
Night: prominent — moon icon, dark background with light text, slightly glowing or with a thin border to signal "different mode active"

The badge should also subtly tint the surrounding chrome (e.g., the video container border) cool/dark in night mode so the user feels the state shift, not just reads it.
B. Mode detail panel.
Either a tap-to-expand panel on the badge, or a section in the robot's settings/info area. Shows:

Current mode (Day / Night) with the icon
Current lux reading (e.g., "2.1 lux — dark" or "47.3 lux — well lit")
Last transition time as a relative timestamp ("Switched to night mode 3 minutes ago")
The override control (next item)

For the lux reading, format thresholds intuitively:

< 5 lux: "dark"
5–15 lux: "dim"
15–100 lux: "indoor lighting"
100–1000 lux: "well lit"
> 1000 lux: "bright"

If lux is null (sensor didn't return it), show "lighting: detecting…" or hide the value gracefully.
C. Override control.
A segmented control or three-button toggle with clear labels:

Auto (default, recommended) — "Switches automatically based on lighting"
Day mode — "Stay in daytime camera mode"
Night mode — "Stay in night vision mode"

Include a small helper text below explaining what auto does. When user selects Force Day or Force Night, show a small notice: "Manual override active. Tap Auto to resume automatic detection."
The control should reflect the robot's reported override state, not just the local UI state, so that if two devices change the setting they stay in sync.
4. Video feed adaptation in night mode
When currentMode == night:

Apply a very subtle cool-tone overlay or color filter to the video container's background (NOT the video itself — leave the actual stream untouched, just the chrome around it)
Slightly dim any non-essential UI elements over the video so the user's eyes adjust
Show a small "IR night view" label near the badge

When currentMode == day: standard appearance.
Do NOT apply any filter that modifies the actual video pixels — the IR feed should be shown as-is. Any visual treatment is purely on surrounding UI, not the stream itself.
5. Transition handling
Mode transitions on the robot side take ~3 seconds (AE settling). During a transition the video feed may briefly look odd. To handle gracefully:

When the app detects a mode change (incoming state message with new mode value different from prior), show a brief, non-blocking toast or banner: "Switching to night mode…" / "Switching to day mode…"
Auto-dismiss the banner after 4 seconds
Don't block any controls during this — the user should still be able to drive the robot, etc.

6. Connection edge cases
If isConnected == false (no state message in 90+ seconds):

Show the mode indicator in a "stale" appearance (greyed out, or with a small warning icon)
The override control should still work (the message will be queued and delivered when the robot reconnects), but warn the user: "Robot offline — change will apply when reconnected"

7. Settings persistence
The user's override preference is the source of truth on the robot side (the robot persists it in its own state file). The app should NOT independently persist this setting. On app startup, it just waits for the first night_mode_state message from the robot to know the current override. This avoids drift between devices.
What the app CAN persist locally is purely UI preferences — for example, "always show the mode badge" vs "hide the badge in day mode," if you want to add that as a UI preference. But the mode state itself comes from the robot.
8. What NOT to build right now

Do NOT add scheduled mode changes (e.g., "switch to night mode at sunset"). Auto detection handles this.
Do NOT expose lux thresholds for tuning in the UI. They're robot-side constants for now.
Do NOT add a "night mode history" view. The robot logs transitions, but surfacing them in the app is a later analytics feature.
Do NOT change how treat dispensing or other controls behave in night mode. Same controls available in both modes.

Acceptance criteria

User can see at a glance whether the robot is in day or night mode
User can override the mode and the change reflects on the robot within 2 seconds
App stays in sync with the robot's actual state (not just the user's last action) via the heartbeat
Mode transitions feel intentional and informed, not jarring
Override preference survives app restart (because it's stored robot-side)
Video stream is not visually modified by the app — only the chrome around it adapts

Files likely to create or modify

NEW: lib/features/night_mode/night_mode_state.dart
NEW: lib/features/night_mode/night_mode_controller.dart (or notifier/bloc per app convention)
NEW: lib/features/night_mode/widgets/mode_badge.dart
NEW: lib/features/night_mode/widgets/mode_detail_panel.dart
NEW: lib/features/night_mode/widgets/override_selector.dart
MODIFY: live video screen to embed the badge and detail panel
MODIFY: messaging layer to register the two new message types
MODIFY: localization files if the app is localized (probably not needed yet but worth checking)

Visual style notes
The existing app aesthetic should drive specifics, but in general:

Night mode UI uses cool blues and dark greys, not warm tones
Day mode UI uses the app's normal palette
Icons: wb_sunny / nights_stay from Material, or equivalent in whatever icon set the app uses
The badge should feel like part of the existing UI, not bolted on — match existing border radii, shadow style, typography

Build target
Increment build number when this ships. Bezik and Elsa's owner Morgan will validate against a live robot before this goes to any beta tester.