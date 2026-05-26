# Investigation Prompt: Sling Collision Damage/Knockback Regression (Analysis Only)

You are performing a **root-cause investigation only** (no code changes, no pseudocode patches).

## Context
The following issues are observed after a recent refactor:

1. SlingA launches and collides with SlingB, but no damage is applied.
2. Knockback duration is hardcoded to `0.12` and should scale with the velocity transferred from SlingA to SlingB.
   - Stronger hits should produce stronger knockback.
   - Weaker hits should produce weaker knockback.
3. Damage is still not applied even when Round State is `EarlyGame`.
4. It is likely a recent refactor broke timing/state logic in the damage pipeline.
5. Before refactor: damage applied correctly.
6. After knockback refactor: `ApplyDamage` started behaving incorrectly.
7. Damage model should depend on velocity and charge, not a fixed value.

## Objective
Produce a detailed analysis that explains:

1. **Root cause(s)** of why damage is not applied after valid launch/collision.
2. **Error flow** through the full pipeline: launch → collision detection → knockback application → damage gating/checks → `ApplyDamage`.
3. **Exact skip conditions** under which damage is dropped/ignored (state checks, timing windows, ownership/authority checks, cooldown/debounce logic, nil/invalid data, ordering races, or guard clauses).
4. **Why knockback duration is wrong** (hardcoded `0.12`) and where scaling from impact velocity should have been propagated but was not.
5. **How the refactor likely broke the pipeline**, especially where timing/state coupling changed and now prevents damage registration.
6. **Most likely regression points** (specific modules/functions/events/conditionals), ranked by probability.

## Required Analysis Steps

1. Build a **trace map** of the runtime path using concrete function/event names and call order.
2. Identify all **gates and preconditions** for damage application, including:
   - round state requirements,
   - authority/ownership constraints,
   - temporal sequencing requirements,
   - flags/debounces/invulnerability windows,
   - collision validity checks.
3. Compare **pre-refactor vs post-refactor behavior** and pinpoint deltas in:
   - state transitions,
   - event order,
   - data payload shape,
   - timing assumptions,
   - shared flags reused by knockback and damage.
4. Explain whether collision and knockback can succeed while damage fails, and why.
5. Determine whether `ApplyDamage` is:
   - never called,
   - called with invalid/zeroed parameters,
   - called but short-circuited by guards,
   - called too early/late relative to valid round state.
6. Analyze the **damage formula path** to confirm where fixed damage is still being used and where velocity+charge inputs are lost, clamped, or overwritten.
7. Analyze the **knockback duration computation path** to confirm where constant `0.12` overrides dynamic scaling.

## Deliverable Format
Return a structured report with these sections:

1. **Executive Summary** (1–2 paragraphs)
2. **Observed vs Expected Behavior**
3. **Pipeline Trace (Launch → Collision → Knockback → Damage)**
4. **Damage Skip Conditions Matrix** (condition, where checked, why it skips)
5. **Knockback Duration Regression Analysis**
6. **Refactor Regression Hypotheses (Ranked)**
7. **Most Likely Root Cause(s)**
8. **Validation Checklist** (what logs/traces/assertions would confirm each hypothesis, without implementing code)

## Constraints

- **Analysis only. No code changes. No code snippets for fixes.**
- Be explicit about certainty level for each conclusion: **CONFIRMED / HIGH_CONFIDENCE / PLAUSIBLE / UNKNOWN**.
- If information is missing, state exactly what artifact/log is needed.
