---
name: content-x-linkedin-build-in-public
description: Use when the user is building an audience from zero on X/Twitter and LinkedIn with Build in Public content, needs a minimal sustainable cadence, and wants a weekly orchestrated workflow (plan, generate, approve, publish, retro) powered by content-core.
---

# X + LinkedIn Build in Public
## Model and CLI Routing (Universal)

This skill is designed to be runnable from any environment (any terminal, any calling model). It assumes 3 CLI tools exist, each with an explicit allowlist of models:

- `codex` CLI: `gpt-5.3-codex`, `gpt-5.2-codex`
- `gemini` CLI (Gemini): `gemini-3-flash-preview`, `gemini-3.1-pro-preview`
- `opencode` CLI:
  - providers: `openrouter`, `kimi-for-coding`
  - model ids: `openrouter/...` and `kimi-for-coding/...` (as pinned in the repo's `docs/final models.md` when present)

Routing rule (by model id format):
- `gpt-*-codex` -> run via `codex`
- `gemini-*` -> run via `gemini`
- `openrouter/...` or `kimi-for-coding/...` -> run via `opencode`

If a repo contains `docs/final models.md`, treat it as the source-of-truth for the pinned allowlist. Otherwise, fall back to the defaults listed above.

## Required Sub-Skills

- `content-core` for post generation and EXA fact-check.
- `content-opencode-critique` for parallel de-AI critics and rewrite constraints.

## Goal

Help beginners start from zero without over-production.
Prefer consistency over volume.
Prefer schema-first repeatability over ad-hoc formatting instructions.

## Minimal Default Cadence

- X/Twitter: 2 posts per week
- LinkedIn: 1 post per week
- Total: 3 posts per week

Do not increase cadence until user sustains 3 weeks without burnout.

## Workflow

### Phase 0: Zero-History Bootstrap (one-time setup)

If user has no past posts, build a starter voice profile from founder inputs.

Collect and save:
- Product one-liner
- Who it helps
- Problem it solves
- Why founder builds it now
- 5 mistakes already made
- 5 lessons already learned
- Current milestone (for example: release week)
- Voice seed:
  - 3 tone rules
  - 3 anti-rules (what to avoid)
  - 3 signature phrasing patterns

Output of phase:
- `FOUNDER_STORY_PACK`
- `VOICE_SEED_V1`

### Phase 1: Weekly Orchestrator (Plan)

Build one-week plan:
- select one core weekly narrative from real work artifacts
- map it to 3 posts:
  - Post A (X): mistake + lesson
  - Post B (X): build update + decision
  - Post C (LinkedIn): structured weekly reflection

Each planned post must map to a real event and evidence source.

### Phase 2: Generate Canonical Source (Create Once)

Run `content-core` first in `Mode C: Atomized Output` to build reusable atoms.
Use this as canonical source for all channel variants.
Keep shared claims traceable with `claim_id` so factual updates propagate from one place.
For production workflows, keep canonical atoms in structured JSON with stable keys and schema version.

### Phase 3: COPE Adaptation (Publish Everywhere)

From the same canonical atoms:
- produce X version (short, fast hook, one insight, one CTA)
- produce LinkedIn version (context, decision logic, lesson, CTA)
- validate both variants against structured contract before rendering final text
- define hook strategy per draft (`trigger`, `lead_type`, `formula`) before rendering
- enforce hook opening budget (recommended <= 30 words)
- reject generic opener anti-patterns ("In today's world...", "Many developers...", "Today we will discuss...")
- ensure hook-body alignment: first paragraph must cash out the same tension/promise

Never copy-paste identical text between platforms.
Never patch factual claims in only one platform variant; update canonical atoms/claims and regenerate both.
Apply deterministic formatting (for example mandatory tags/labels) in rendering layer, not in prompt-only instructions.
Require provenance in adapted drafts:
- keep `atom_id` and `claim_id` trace for each non-trivial claim.
- avoid single-use plastic content; each variant must add platform-native value, not only shorten/expand.

### Phase 3.5: De-AI Reliability Lane

Before approval/publish, run a parallel critic bundle:
- `generic_detector`
- `rhythm_analyzer`
- `personal_anchor_critic`
- `hook_critic` (or dedicated `content-hook-optimization` pass)

Aggregate findings into one change list and rewrite with hard rules:
- rewritten length <= original
- marked generic phrases removed (not cosmetic paraphrase)
- at least one personal anchor added
- sentence-length variation introduced
- hook opening respects word limit and anti-pattern blocklist

If any hard rule fails, return to rewrite step before approval.

### Phase 4: Approval Lane (Risk-Based HITL)

Classify each draft:
- `LOW` risk -> batch review queue
- `MEDIUM` or `HIGH` risk -> inline review before publish

Inline review is mandatory for:
- strong external claims
- legal/policy-sensitive topics
- controversial comparisons

Conditional gate stack before approval:
- `FORMAL_GATE` must pass (schema/constraints/required fields).
- `LLM_JUDGE_GATE` must pass target rubric thresholds.
- If either gate is borderline/uncertain -> force inline review.

### Phase 5: Publish Sequence

Default order:
- Day 1: X (mistake + lesson)
- Day 3: LinkedIn (structured reflection)
- Day 5: X (build update + decision)

Adjust only if milestone timing requires it.

### Phase 6: Weekly Retro and Learning Loop

After publishing, capture:
- impressions
- engagement (replies/comments/saves)
- qualitative signal (DMs, useful comments)

Update:
- `VOICE_SEED_DELTA`
- winning hooks
- weak hooks
- consistency drift incidents (if X and LinkedIn diverged on shared facts)
- publish_on_time_rate
- schema_validation_failure_count
- generic_marker_removal_rate
- hook_hold_signal_rate
- hook_variant_win_rate
- posts violating max length ratio
- personal_anchor_coverage_rate
- next-week adjustments

## Output Contract

Return:
- weekly mini-plan (3 posts)
- canonical atom set (schema-tagged)
- claim trace map (`claim_id` -> where used in X/LinkedIn drafts)
- structured payloads for X and LinkedIn variants
- de-AI critic bundle report (`generic_detector`, `rhythm_analyzer`, `personal_anchor_critic`)
- hook optimization report per post (`trigger`, `lead_type`, `formula`, `hook_15s_score`, `hook_word_count`, `hook_antipattern_flags`)
- rendered drafts for X and LinkedIn derived from the same atoms
- risk table with approval mode per post
- gate decision log (`formal_gate`, `llm_judge_gate`, `approval_mode_recommendation`, `requires_inline_review_reason`)
- source links used in fact-check
- publish order list
- weekly retro template

## Reference

Load `references/request-template.md` when user wants a ready command template.














