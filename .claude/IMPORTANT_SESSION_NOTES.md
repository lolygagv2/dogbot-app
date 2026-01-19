# CRITICAL SESSION NOTES FOR AI ASSISTANTS

## ⚠️ VISUAL FEEDBACK LIMITATION

**PROBLEM:** When AI assistants modify detection/vision systems, humans cannot visually verify if changes are improvements or regressions through chat logs alone.

**IMPACT:**
- Humans lose confidence when AI "improves" systems they can't see
- Log analysis doesn't show if detection quality actually improved
- No way to verify if pose detection, behavior classification, or visual accuracy got better/worse

**SOLUTION:**
- ALWAYS use existing working scripts as base - copy/paste and make minimal changes
- NEVER rewrite working vision systems from scratch
- When improving thresholds, change ONLY the specific values, not the entire architecture
- Acknowledge that humans need visual tools (GUI scripts) to verify detection quality


## KEY REMINDER:
Trust working code. Make minimal changes. Humans need visual confirmation of "improvements."