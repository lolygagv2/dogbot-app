# WIM-Z app — brand re-theme report (Build 182, 2026-11-09)

Scope was colour only: no layout, copy, navigation or logic changes. The app now
ships two brand themes — **"White / Black / Gold"** (light, primary) and
**"Stealth Black"** (dark) — following the device setting (`ThemeMode.system`;
the app had no theme setting of its own).

## 1. What was built

| File | Purpose |
|---|---|
| `lib/theme/wimz_colors.dart` | `WimzColors` ThemeExtension with every brand token for light and dark, `copyWith`/`lerp`, `context.wimz` accessor. Derived (no new hues): `inkDisabled` (ink @38%), `scrim(alpha)` (ink over video), `onVideo` (white), `lineOnVideo`. |
| `lib/theme/wimz_theme.dart` | `WimzTheme.light` / `.dark` ThemeData (M3, explicit ColorScheme, not fromSeed) + component themes; `goldButtonStyle` (the one hero CTA), `cardDecoration` (flat), `statusChipDecoration` (signal-glow chip), `raisedDecoration` (sheets only), `focusRing`; `WimzStatus` maps (behavior / dogPalette / barkType / battery / connection) with `onVideo:` variants. |
| `lib/presentation/theme/app_theme.dart` | Stripped to radius constants, `getBehaviorDisplayName`, and the four helper widgets (GlassContainer → flat card, GlowText → plain, PulseIndicator → no glow, HudLabel → scrim + white). Every colour constant removed. Re-exports `wimz_theme.dart`. |
| `lib/app.dart` | `theme: WimzTheme.light, darkTheme: WimzTheme.dark, themeMode: ThemeMode.system`. Night-vision chrome shift removed (signal blue is status-only, never a brand colour; the mode badge still shows the word). |
| `test/widget_test.dart` | Replaced the broken counter boilerplate (referenced a `MyApp` that never existed) with a theme test: tokens installed, explicit scheme, WCAG contrast of the pairs the brand rules depend on. |
| `test/screenshots/theme_screenshots_test.dart` | Opt-in harness (`flutter test test/screenshots --dart-define=WIMZ_SCREENSHOTS=true`) renders 17 routes in demo mode in both themes to `build/screenshots/{light,dark}/`. |
| `assets/images/wimz_figurehead.jpg` | 1024 px product photo used as the login hero. The uploaded 8192 px / 99 MB PNG was moved out of the bundled `assets/images/` folder to `archive/MEDIA_WIMZ_BLACK_8192_source.png` (untracked). |

ColorScheme slots (both themes): primary = ink (light) / white (dark), onPrimary inverse;
secondary = brand-gold / onSecondary ink-on-gold; tertiary = signal / onTertiary ink-on-signal;
surface / onSurface = ground / ink; onSurfaceVariant = ink-muted; surfaceContainerLow+Container =
surface-raised; surfaceContainerHigh+Highest = surface-sunken; outline = line-strong;
outlineVariant = line; surfaceTint transparent. `error`/`onError` kept at the pre-rebrand
`#FF5252` / white in both themes (see §6).

Component themes: Filled/Elevated = primary, flat; Outlined = line-strong border; Card =
surface-raised, 1 px line, elevation 0; inputs = surface-raised fill, line-strong border, focus
border = signal 2 px; dividers = line; chips = surface-raised + line (status chips use
`statusChipDecoration`); AppBar / NavigationBar = surface ground, ink foreground, indicator =
surface-sunken (not gold); switches/checkboxes/radios active = primary; dialogs / sheets /
popups carry shadow-raised; FAB = primary, stadium shape (the old circle shape clipped the
extended "Add Schedule" FAB, pre-existing). Text styles derive from platform typography so
the platform font family is kept.

## 2. Verification

- `flutter analyze`: **0 errors, 0 warnings**, 81 infos (389 before). The infos are
  pre-existing lint hints (`use_build_context_synchronously` ×36, `prefer_const_*` ×17,
  `deprecated_member_use` ×6 on untouched Radio/Dropdown APIs, …). None are colour related.
- `flutter test`: 116 passed (+ 2 opt-in screenshot tests, skipped by default).
- Literal grep outside `lib/theme/`: `grep -rnE "Color\(0x|Colors\.[a-zA-Z]" lib` returns only
  `Colors.transparent`. No `.withOpacity` left in `lib/`.
- Screenshots: 17 routes × 2 themes captured (`build/screenshots/`). Checked: no white on gold,
  no brand-gold text on light grounds, signal only on status/links/focus, cards flat with line
  edges. The 49 px row overflow the harness reports on Home's media bar at 390 px width is
  identical on the pre-rebrand code (captured to `build/screenshots_baseline/`).
- Builds: **not verifiable on this machine** — no Android SDK or Xcode (Codemagic builds iOS
  and Android). A Linux desktop build was attempted to compile the full app natively; CMake
  stops in the `flutter_secure_storage_linux` plugin because `libsecret-1-dev` is not
  installed (needs sudo). Dart compilation of the whole app succeeded through the test runs.

## 3. Gold audit — one gold element per screen

| Screen | Gold element |
|---|---|
| Login | Sign-in hero CTA (first-step "Login" and the form's submit are never shown together) |
| Home | Treat quick action (brand-gold disc, ink-on-gold icon) |
| Drive | Treat overlay button |
| Coach | Reward flash pill (brand-gold fill, ink-on-gold text) |
| Missions list / Programs list | none |
| Mission detail | Start Mission |
| Program detail | Start |
| Dogs list / Dog profile | none |
| Add dog | final-step "Save Dog" |
| Edit dog | AppBar "Save" (gold-deep text) |
| Activity (Dashboard tab) | the Alerts chart series mark (gold-deep) |
| Activity (Events tab) / Notifications | none |
| History / Gallery / Forgot password | none |
| Scheduler list | none |
| Schedule edit | AppBar "Save" (gold-deep text) |
| Settings / Connected AI / Sounds / Notification prefs / Diagnostics / Controller pairing / Voice setup | none |
| Device pairing (My Robots) | Pair |
| Song upload | Choose song / Upload |
| Demo view | header paw icon (gold-deep) |

Demotions made to keep the budget: battery indicator 21–50 % is ink-muted (not gold-deep),
gauge mid-range arc is ink-muted, per-dog detection palette has no gold
(`WimzStatus.dogPalette` = ink / ink-muted / signal / line-strong / error, on-video tokens).

## 4. Hardcoded colours replaced (by file group)

Legend: `cs` = ColorScheme slot, `w` = WimzColors token. Counts are approximate groupings.

**Old AppTheme constants, everywhere (~900 refs):** `textPrimary` → `cs.onSurface`;
`textSecondary`/`textTertiary` → `w.inkMuted`; `textDisabled` → `w.inkDisabled`;
`background`/`surface` → `cs.surface`; `surfaceLight`/`glassWhite` → `w.surfaceRaised`;
`surfaceLighter` → `w.surfaceSunken`; `glassBorder` → `w.line`; `primary` (cyan) →
`cs.primary` for selected/active/CTA, `w.signal` only for live/online/link;
`secondary` (purple, AI) → `w.ink`; `accent` (green) → `w.ink` (+ icon where colour alone meant
success), `w.signal` where it meant online; `warning` (yellow) → `w.inkMuted` + warning icon;
`error` → `cs.error`; `connected` → `w.signal`; `connecting`/`disconnected`/`offline` →
`w.inkMuted`; `getBehaviorColor` → `WimzStatus.behavior`; `barkTypeColors` →
`WimzStatus.barkType`; `getBatteryColor` → `WimzStatus.battery`; `glowShadow`/`cardShadow`/
`glassCardWithGlow`/gradients → removed (flat) or solid primary; `darkNight` → removed.

**Settings / scheduler / audio / voice** (settings_screen, connected_ai_screen,
controller_pairing_screen, device_pairing_screen, sounds_screen, notification_preferences_screen,
connection_diagnostics_screen, scheduler_screen, schedule_edit_screen, song_upload_screen,
voice_setup_screen): `Colors.red` ×~15 (destructive dialog actions, wifi errors) → `cs.error`
with icons added; `Colors.green` (OTA success, synced voices) → `w.ink`; `Colors.orange` banner
→ `surfaceRaised`/`inkMuted`; `Colors.grey` → `inkMuted`; `Colors.white` on primary → `cs.onPrimary`;
LED guide dots cyan/blue/green/red → signal/signal/ink/error (labels name the colour); vendor
colours ChatGPT `#10A37F`, Claude `#D97757`, Grok `#E0E0E0`, Perplexity `#20B8CD` → `w.ink`
(the vendor name carries identity); diagnostics console black/greenAccent → brandInk/brandWhite;
green/red/orange snackbar backgrounds → theme inverse-surface with check/warning/error icons;
online avatar fill → `signalGlow`.

**Dog profile / summaries / Silent Guardian / gauge** (dog_profile_screen, edit_dog_screen,
add_dog_screen, weekly_summary_card, robot_status_card, talk_to_wimz_card, today_card,
sg_summary_card, intervention_level_section, wimz_gauge, dog_profiles_provider): dog-coat
swatches `#333333`/`#D4A574`/`#8B4513`/`#F5F5F5`/`#888888` → brandInk/goldDeep/inkMuted/
brandWhite/lineStrong (`displayColor` now takes `WimzColors`; the enum label is always shown);
stat icons green/teal/deepPurple/orange → `w.ink`; `Colors.purple` SG header → onSurface;
bark-type map (deepOrange/amber/redAccent/red/lightGreen/blueGrey) → `WimzStatus.barkType`
(aggressive = error, alarm = goldDeep, distress = ink, demand = signal, play = inkMuted,
unclassified = lineStrong; legend labels present); episode severity high → error + warning icon;
trend tints dropped (sign in text carries direction); gauge accent/warning/error arcs →
ink/inkMuted/error.

**Notifications / demo / home / history / coach / gallery / auth** (activity_dashboard,
notifications_screen, draft_action_row, attachment_thumb, demo_view_screen, demo_controls_panel,
home_screen, history_screen, coach_screen, photo_gallery_screen, login_screen,
forgot_password_screen, guardian_event.dart): `GuardianEventType` enum lost its `Colors.*`
field → `colorOf(context)` (barking/alert = error, treat/quiet reward = ink, dog detected =
signal, rest = inkMuted); chart series → ink / error / inkMuted / signal / goldDeep with legend
chips; `_getEventColor`/`_getColor`/`_getModeColor` maps (red/blue/amber/orange/purple/grey) →
error/ink/inkMuted/signal per state; swipe-delete red/white → error/onError + "Delete" word;
unread badge red → `cs.primary` (a count, not an error); EXIT mode red → `cs.error` (stop icon +
text); video grounds `Colors.black` → `brandInk`, overlays `Colors.white*` → `onVideo`;
per-dog palette (cyan/amber/pink/lime/purple/orange) → `WimzStatus.dogPalette(onVideo)`;
reward flash green → brand-gold pill; login notice primary tints → surfaceRaised/line; login
CTAs → gold / primary; `_ErrorBox` → `cs.error` + icon.

**Video / controls / status / night-mode / guardian / app.dart** (video_hud_overlay,
webrtc_video_view, video_saved_sheet, mjpeg_viewer, audio_mute_toggle, smart_video_view,
ask_wimz, push_to_talk, quick_actions, treat_counter_indicator, connection_badge,
detection_overlay, battery_indicator, local_ap_banner, mode_badge,
night_vision_settings_section, event_feed, loading_overlay, aruco_marker_view, app.dart):
HUD brackets/FPS/timestamps → onVideo variants, REC red → onVideo (recording is status, with
stop icon); `#00E5FF` auto-listen → `w.signal`; record button red → onVideo pulsing; quick
actions green/deepOrange/amber/red/purpleAccent/lightBlue → `w.ink`, BluLight blue → signal +
signalGlow (the LED-ring chip), Lighting orange → ink; PTT/Ask mic red/green/grey/cyan →
primary / inkDisabled / surfaceSunken, glows removed; treat counter error (0 left) → `cs.error`,
low (<5) red dot → warning icon in ink; connection badge → signal (live) / inkMuted / error with
signalGlow pill only when live; battery green/orange/red → `WimzStatus.battery`; ArUco marker
stays literal black/white via `brandInk`/`brandWhite` (camera-read); orange snackbars/
reconnecting banner → inverse-surface + warning icon; nav bar selected ink, unselected
ink-muted.

**Drive / missions / programs / dev** (drive_screen, missions_screen, mission_detail_screen,
mission_progress_overlay, program_detail_screen, ui_previews): all drive overlays → `scrim`/
`onVideo`/`lineOnVideo`; orange D-pad/coach panel → onVideo alphas; speed bars green/red/grey →
onVideo / onVideo@.7 / lineOnVideo; joystick (package default grey/blue) → translucent white
rings, white stick; mission status maps (green/orange/red/grey) → ink / signal (watching) /
inkMuted / error (failed, with X icon); active-mission green gradient + shadow → flat card,
ACTIVE badge → signal chip; program purple gradients → primary / surface-sunken; Start buttons
green/purple → gold; Stop red → `cs.error`; SampleData banner amber → inverse-surface.

## 5. Every `colorScheme.error` usage (each has icon + text unless noted)

Settings: sign-out dialog action + tile (logout icon); OTA failed (error_outline); treats empty
(error_outline); reset-sounds dialog (restore icon); wifi connect/scan errors (error_outline);
LED guide "Pulsing red = Error" — 12 px dot with the label text (dot, not an Icon).
Connected AI: Revoke / Disconnect-all actions and tile (link_off / block). Controller pairing:
Forget (delete_outline). Device pairing: Unpair / Hide (link_off / visibility_off), error banner
(error_outline). Scheduler: error banner (error_outline), swipe-to-delete background (delete
icon, no word on the swipe surface; confirm dialog follows), delete confirm (delete). Schedule
edit: delete confirm + Delete schedule button (delete). Song upload: failed box (error_outline).
Voice setup: delete/reset dialogs (delete_outline / restore), recording dialog error (error).
Edit dog: Delete dog + confirm (delete_forever), three failure snackbars (error_outline).
Add dog: Remove photo (delete), duplicate-name snackbar (error_outline). Intervention level:
ack-error snackbar (error_outline). SG summary: panic edge/tag (warning_amber), aggressive tag
(report), worsening trend (trending_up). Today card: high-severity episode (warning_amber).
Gauge: arc below 30 % — value text, no icon in the gauge itself. Activity: barks series
(legend label), bark row (volume_up), mission failed row (cancel). Guardian events: barking /
alert types (enum icon + label). Notifications: Clear all (delete_outline), swipe delete
(delete + "Delete"), bark / missionFailed / lowBattery / panicAlert tiles (icons + title).
Draft row: decide failed (error_outline). Demo view: SG level ≥4 (warning_amber), panic
(crisis_alert), worsening trend (trending_up); demo controls replay error (error_outline).
Login / Forgot password: error boxes (error_outline). History: load error (error_outline +
Retry). Gallery: Delete photo (delete_outline). Home: mode-change failed snackbar
(error_outline), EXIT mode (stop_circle + "EXIT"). Coach: Exit Coach Mode (stop_circle + label).
Video: WebRTC error, record/photo failures, PTT errors, Ask WIM-Z error (error_outline + text);
HUD battery ≤20 % (battery icon + %). Connection badge: error state (error_outline + "Error").
Treat counter: 0 left (cookie icon + "0/44"). Quick actions: `_errorSnack` helper
(error_outline), Delete song dialog (delete_outline). Drive: AppBar emergency stop — icon with
tooltip only, no visible label (pre-existing layout); dog paw tinted error when barking — icon
only. Mission detail: start-failed snackbar (error_outline), Stop Mission (stop). Mission
overlay: failed border + `_FailureIndicator` (close icon + status label). UI previews: event
type "error" (error_outline + title).

## 6. Not mapped cleanly / judgement calls

- **Error slot on light grounds**: kept at `#FF5252` as instructed; on white it is 3.1:1, so
  error *text* in the light theme is below AA. Material's light default (`#B3261E`) would fix
  it if the brand team agrees.
- **Light signal contrast**: `#3D67A9` on white and on its own chip fill are both 4.43:1 —
  just under the 4.5:1 text bar. Fine for icons / chips / large text; the theme test holds
  signal to the 3:1 component bar.
- **On-video marks**: ink / ink-muted / line-strong are dark in the light theme and would
  vanish on the camera feed, so everything drawn over video uses the dark token set
  (`WimzStatus … onVideo: true`, `w.onVideo`, `w.scrim`). The coach "COACHING" chip and trick
  chips use the dark signal for the same reason.
- **Colour-only remnants that need a string to fix** (no ARB edits were made): Today card
  episode severity med vs low (ink vs ink-muted dot); drive emergency-stop button (icon +
  tooltip); drive dog paw behaviour tint; scheduler swipe-delete surface; settings LED guide
  error dot. Snackbars that lost their red/green backgrounds now rely on the message text (an
  icon was added where the content was already a Row).
- **Night mode** no longer shifts the app chrome colour; the mode badge still carries the word.
- **Recording states** (HUD REC, record button, PTT) are no longer red — white/primary with
  stop/countdown icons and words.
- **Vendor colours** on Connected AI badges were removed (vendor name text carries identity).
- **Figurehead photo** has its own black ground, so on the light login screen it appears as a
  rounded black product shot above the wordmark.
- **Unused BLACK_WZ / WHITE_WZ** wordmark assets remain in the bundle (not referenced now).

## 7. How to work with it

- Widgets: `final w = context.wimz;` then `w.goldDeep`, `w.line`, …; or `Theme.of(context).colorScheme.*`.
- Status: `WimzStatus.behavior(context, b, onVideo: true)`, `WimzStatus.barkType(context, t)`,
  `WimzStatus.battery(context, pct)`, `WimzStatus.connection(context, isConnected:, isConnecting:)`.
- The one gold CTA: `FilledButton(style: WimzTheme.goldButtonStyle(context), …)`.
- Screenshot audit: `flutter test test/screenshots --dart-define=WIMZ_SCREENSHOTS=true`
  → `build/screenshots/{light,dark}/*.png`.
- Rule of thumb: no `Color(0x…)` / `Colors.*` outside `lib/theme/` (grep enforces it).
