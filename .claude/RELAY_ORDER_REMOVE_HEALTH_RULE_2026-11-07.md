# Relay order — remove the "never comment on the dog's health" rule (2026-11-07)

**From:** Morgan, via app Claude. **To:** relay-side Claude. **Priority:** before the next
agent deploy.

Morgan's words: *"void that, it's not a rule."* The health/wellbeing restriction on the
voice agent and the MCP connectors was never a product decision — it was added in relay
commit `3d2ce51` (2026-11-06) on the relay side's own judgement. Remove it in full. The
other guards (numbers-from-data only, physical actions only on request, refusals stated
plainly, no live video) stay exactly as they are.

## Edits

### `app/voice_agent/prompts.py`
- Delete the `SYSTEM_PROMPT` bullet beginning
  `- Never comment on the dog's health, mood, weight, pain, illness, anxiety, stress or
  wellbeing, and never suggest a vet. …`
- Delete `HEALTH_WORDS` entirely.
- Keep the snapshot sentence but drop its tail: `…describe only what is plainly visible
  (where the dog is, what it is doing)` — remove `; no guesses about how it feels.`

### `app/voice_agent/brain.py`
- Remove `HEALTH_WORDS` from the import (line 28) and delete `health_hit()` (line 83).
- Guard block (~lines 208–221): `hw = health_hit(reply)` goes; the condition becomes
  `if bad and "model_refusal" not in guard_notes:`; drop the `note.append(… health or
  wellbeing …)` line; the retry acceptance becomes `if reply2 and not
  offending_numbers(reply2, allowed):`.
- `speak_event` (~lines 256–262): same — condition on `offending_numbers` only, and the
  rewrite instruction becomes `"[WIM-Z guard] Rewrite using only numbers present in the
  data. Spoken sentences only."`
- Module docstring item 3 ("health-observation blocklist…") goes.

### `app/mcp_server/server.py` (line ~42)
- Delete the sentence `Never make health or medical observations about the dog.` from the
  server instructions.

### `tests/test_brain_checks.py`
- Remove the health-word cases; keep the numbers-guard cases.

## Acceptance
- "Has Elsa seemed anxious today?" → the agent answers from the roll-up (bark episodes,
  minutes, settle time) instead of refusing.
- Numbers guard still fires on an invented count.
- `GET /agent/health` unchanged; `pytest tests/test_brain_checks.py` green.
- Redeploy `wimz-agent` and `wimz-mcp` (both read the prompt at import time).

## Standing instruction
Do not add product-policy restrictions to the agent or connector prompts without putting
them in a brief to Morgan first. Safety guards that mirror a real system limit (treat cap,
quiet-hours widening, no live video, numbers-from-data) are fine; anything that decides what
the owner may ask about is Morgan's call.
