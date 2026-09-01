# Bug report → Robot — SG treat dispensed mid-barking, no praise announcement (2026-09-01)

**From:** App Claude (relayed via Morgan). **Observed live by Morgan** on an
SG test session ~17:14–17:18 local, 2026-09-01. App feed (B157) rendered
the event stream faithfully; all three questions below are robot-side.

## Observed sequence (app Activity feed + dashboard recent-events, local time)

- 5:13 PM — Guardian Alert (intervention), plus ~4 barks
- 5:14 PM — Guardian Alert (second intervention), ~8 barks around it
- 5:15 PM — ~3 more barks
- **5:15 PM — "Treat Dispensed"** — mid-bark-stream, dog audibly still
  barking (Morgan present), **no "good dog"/praise audio played**
- 5:18 PM — Guardian Session Ended: "Mostly barking, holding steady —
  Your dog was aggressive today"

~12 detected barks over ~2.5 min = average spacing ~10–12s, and the treat
landed within ~60–90s of the second intervention. For a quiet-window
reward to fire through THAT stream, either the quiet threshold is tiny
(≲15s), or the check isn't actually looking at the bark stream — e.g. a
barks-since-intervention counter that missed these barks (per-dog
attribution mismatch?), or a timer measured from intervention start
rather than from the last bark.

## Q1 — What dispensed the 5:15 treat?

Check the session logs: was it SG's quiet-reward path, or another dispense
path entirely (manual/ghost/scheduler — note the Mission Scheduler is
implemented-but-unvalidated on the blocking list, so rule it out
explicitly)?

If SG: **what quiet duration did it measure, against what threshold?**
Hypothesis: the quiet window is measured as time-since-last *detected*
bark event. Detected barks in this session arrived ~15–25s apart (discrete
gated detections under-report a continuous bout, and dogs pause to
breathe), so a threshold at or below ~20–30s scores a mid-tirade dog as
"quiet". If confirmed, consider (a) raising the quiet threshold and/or
(b) gating "quiet achieved" on raw audio energy over the window, not just
absence of classified bark events.

## Q2 — Should a SG reward announce praise?

No audio preceded the dispense. If the reward path is supposed to play a
praise cue first, that's a second bug (audio-path regressions have
history); if it's not supposed to, flag for Morgan whether it should —
a silent treat mid-barking reads as a malfunction to an owner, and
rewarding without a marker cue is also weaker training signal.

## Q3 — Live bark events carried no bark_type this session

Every bark row rendered unlabeled. The app (B156+) labels any bark event
carrying `bark_type`/`emotion` (and suppresses `unclassified`); labels
were confirmed working on-device earlier today. Yet this session's
summary clearly had type data ("Mostly barking", aggressive tag). So
either the SG-mode live bark path skips the 8068ef3 stamp that another
path applies, or every bark in this session classified `unclassified`
(which would itself be worth a look given the aggressive tag). Which?

## Repro context

Single session, ~4 min, real dog, aggressive-tagged. Logs at 17:14–17:18
local 2026-09-01 should answer all three; nothing here blocks Phase 3.
