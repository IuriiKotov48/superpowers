---
name: content-core
description: Use when the user asks to generate or plan text content from provided source data (notes, docs, links, transcripts), especially when they need orchestrated multi-step generation, mandatory EXA MCP fact-checking, iterative quality scoring, risk-based human approval, and platform adaptation from one canonical source.
---

# Universal Content Generator

## Overview

Generate publish-ready content from user-provided materials without inventing facts.
Work as a repeatable orchestrator pipeline: strategy gate, source setup, parallel research, drafting, fact-check, iterative refinement, risk gating, and COPE packaging.
Use schema-first generation for production: model outputs structured content, code applies deterministic final formatting.

Use progressive disclosure:
- Keep this file procedural.
- Load detailed examples from `references/patterns.md` only when needed.
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

## Input Contract

At the start, collect missing inputs and confirm assumptions before drafting.

Required:
- Goal: what this piece must achieve
- Platform: X/Twitter, Telegram, LinkedIn, blog, script, other
- Source data: exact files, links, or pasted text
- Strategy brief seed:
  - audience pain
  - one key promise
  - desired reader action
- Delivery mode: human-readable or structured; if structured, include schema name/version (or schema path)
- Deterministic formatting policy: what must be enforced in code (hashtags, wrappers, section labels)

Optional (but strongly recommended):
- Audience
- Voice style (or sample text to imitate)
- Language
- Constraints: length, banned claims, CTA, emojis policy
- Freshness window (if needed): last 24h/7d/30d
- Risk tolerance: low/medium/high

If key fields are missing, ask concise follow-up questions before drafting.

## Core Workflow

### Pipeline Architecture Router

Choose execution architecture before running phases:
- `SEQUENTIAL`: use for narrow, low-risk requests with one clear source path and simple deliverable.
- `BRANCHING`: use for research-heavy or time-sensitive requests where independent tracks can run in parallel.
- `ITERATIVE`: use when quality/risk bar is high and draft quality must be improved via critique-refine loops.

Router rules:
- Start with the minimal architecture that can meet quality requirements.
- Escalate from `SEQUENTIAL` to `BRANCHING` if evidence coverage is weak.
- Escalate to `ITERATIVE` when gates fail or output quality is below threshold.

### Phase 0: Strategy Gate (Human Required)

Before any draft, define and confirm:
- `OBJECTIVE`
- `AUDIENCE`
- `CORE_MESSAGE`
- `PROOF_BOUNDARIES` (what can and cannot be claimed)
- `SUCCESS_SIGNAL` (what user wants from this post: click, reply, demo request, etc.)

Do not draft until strategy is confirmed.

Output of phase:
- `STRATEGY_BRIEF`

### Phase 1: Source-of-Truth Setup

Build one factual base from provided materials.

Rules:
- Treat provided sources as primary truth.
- Do not duplicate facts in multiple places; keep one canonical fact list.
- Assign stable `claim_id` to each non-trivial fact and store it in `FACT_REGISTRY`.
- Keep facts editable only in canonical source (`FACTS` + `FACT_REGISTRY`); channel drafts must derive from it, not fork it.
- Tag uncertain claims as `UNVERIFIED`.
- If the user requests "latest/today/recent", verify externally before final text.

Output of phase:
- `FACTS`
- `FACT_REGISTRY`
- `CONSTRAINTS`
- `VOICE_NOTES`

### Phase 2: Branching Research (Parallel)

Run parallel research tracks, then synthesize:
- Track A: latest factual updates and primary sources
- Track B: concrete examples/case studies
- Track C: counterpoints, risks, and caveats

Rules:
- Use EXA MCP in each track.
- Prefer source diversity over repeating similar articles.
- Preserve source links for every important claim.

Output of phase:
- `RESEARCH_SYNTHESIS`
- `CLAIM_CANDIDATES`

### Phase 3: Angle and Hook Design

Create 3 angle options and rank them.

For each option provide:
- Hook (first 1-2 lines)
- Hook trigger (`CuriosityGap|Identity|Tension|ROMO|FOMO|SocialProof`)
- Lead type (`Zinger|FirstPerson|Question|Scene`)
- Hook formula (`SPY|PAS|APP|Custom`)
- Promise/value for reader
- Best-fit structure (thread, short post, long post, article)
- Risk note (overclaim, weak novelty, too technical)

Recommend one option and explain why in 1-2 lines.

Hook engineering constraints:
- First 30 words should create clear continuation pressure in the first ~15 seconds.
- Hook must avoid generic openers ("In today's world...", "Many developers...", "Today we will discuss...").
- Hook-body alignment is mandatory: the body must fulfill the tension/promise created by the hook.

### Phase 3.5: Schema-First Contract (Production)

Before drafting for automated pipelines, lock contract:
- Define or reference schema (JSON Schema/Pydantic) for the response.
- Keep structure constraints in schema, not in prompt prose.
- Mark deterministic output parts for code-level rendering (for example hashtags, fixed labels, wrappers).
- If schema cannot represent a required field, revise schema before generation.

Output of phase:
- `RESPONSE_SCHEMA`
- `RENDER_RULES`

### Phase 4: Drafting

Draft from chosen angle.

Defaults by platform:
- X/Twitter: strong first line, short paragraphs, explicit takeaway, optional thread numbering
- Telegram: conversational voice, clearer transitions, one main CTA
- LinkedIn: authority + practical insight, cleaner structure, no hype
- Blog/article: intro, body sections, practical examples, conclusion

Never add facts that are not in verified sources.
For structured pipelines, output semantic fields only; apply strict formatting in renderer/post-processing code.

### Phase 5: Mandatory EXA MCP Fact-Check

Run EXA MCP verification before finalizing any factual content.

Rules:
- Treat EXA MCP as required final verification, even if user provided sources.
- Verify all factual claims that can become outdated or controversial.
- For each verified claim, keep at least one source link.
- If EXA conflicts with source data, prefer the most recent reliable evidence and mark the conflict.
- If EXA MCP is unavailable, do not present content as fully verified; either:
  - ask user to retry when EXA is available, or
  - deliver draft with explicit `UNVERIFIED` label for all unchecked claims.

Output of phase:
- `VERIFIED_FACTS`
- `SOURCE_LINKS`
- `OPEN_ISSUES`

### Phase 6: Iterative De-AI and Refine Loop

Run specialized critics in parallel, aggregate findings, then refine iteratively with hard rewrite rules.

Critic A (`generic_detector`):
- Find generic AI markers and template phrasing.
- Flag abstract claims without concrete examples.

Critic B (`rhythm_analyzer`):
- Detect sentence-length monotony and repetitive openings.
- Mark sections that read with flat cadence.

Critic C (`personal_anchor_critic`):
- Find places lacking personal evidence (experience, date, name, opinion).
- Require at least one grounded human anchor per piece.

Aggregate all critic outputs into one `DEAIFY_CHANGESET`, then run rewriter using hard rules:
- Keep rewritten length <= original length (`length_ratio <= 1.0`).
- Remove every marked generic phrase (delete/replace with concrete detail; do not just paraphrase pattern noise).
- Add at least one personal anchor (`personal_anchor_count >= 1`).
- Enforce sentence-length variation and varied openings.

Score after each iteration:
- `ai_ness_score` (0-100, lower is better, target <= 20)
- `clarity_score` (0-100, higher is better, target >= 75)
- `specificity_score` (0-100, higher is better, target >= 70)
- `factual_risk_score` (0-100, lower is better, target <= 20)
- `generic_marker_count` (integer, lower is better, target = 0)
- `personal_anchor_count` (integer, higher is better, target >= 1)
- `length_ratio` (rewritten/original, target <= 1.0)
- `rhythm_variance_score` (0-100, higher is better, target >= 60)

Stop condition:
- all score targets and hard rules passed, OR
- 3 iterations reached

If stop condition ends with failed targets:
- mark output as `NEEDS_HUMAN_REWRITE`
- include failed score fields and `failed_hard_rules`.

### Phase 7: Risk-Based Quality Gate (HITL)

Classify risk level before final output:
- `LOW`: routine content, no sensitive claims
- `MEDIUM`: competitive comparisons, numbers, external claims
- `HIGH`: legal/regulatory/financial/medical claims, or strong public statements

Approval policy:
- `LOW` -> batch review allowed
- `MEDIUM` -> inline human review when uncertainty exists
- `HIGH` -> inline human review mandatory before publish

Tiered gate stack (run in order):
- `FORMAL_GATE`: schema validity, required fields present, claim-link mapping complete, deterministic constraints pass.
- `LLM_JUDGE_GATE`: structured rubric scoring for clarity, specificity, coherence, and factual risk.
- `HUMAN_GATE`: required for strategy ambiguity, unresolved source conflicts, or high-risk claims.

Conditional gate policy:
- If `FORMAL_GATE` fails -> block and revise (no publish path).
- If `LLM_JUDGE_GATE` is borderline or inconsistent -> escalate to inline human review.
- If risk is `LOW` and all gates pass -> batch approval lane is allowed.
- If risk is `MEDIUM|HIGH` -> inline approval lane is required.

Before final output, run checklist:
- Factual consistency with `VERIFIED_FACTS`
- No fabricated links/numbers/quotes
- Hook clarity in first lines
- Hook passes first-15-seconds check (trigger + lead + formula + anti-pattern scan)
- Platform fit and length fit
- Tone consistency with `VOICE_NOTES`
- Actionability (reader knows what to do next)
- Every factual claim mapped to at least one link in `SOURCE_LINKS`
- Cross-variant consistency for shared claims (same numbers, entities, and dates across X/LinkedIn unless scope differs intentionally)

If any critical check fails, revise once and re-check.

### Phase 8: COPE Packaging

Create Once, Publish Everywhere from one canonical narrative:
- keep factual core identical
- adapt hook, structure, and CTA per platform
- never copy-paste the same text across platforms without adaptation
- when factual inputs change, update canonical source first and regenerate platform variants instead of patching each variant manually

## Structured Output Reliability Rules

Use these rules when content enters an automated pipeline:
- Put content meaning in model output, deterministic formatting in code.
- Never rely on prompt wording alone for must-have tokens (for example required hashtags).
- Validate generated JSON against schema; fail closed on validation error and regenerate.
- Keep rendering functions deterministic and versioned.
- Record schema version in artifacts for reproducibility.

## Pipeline Observability (Recurring Workflows)

Track these KPIs for operational control:
- `gate_pass_rate`
- `iterations_to_done`
- `human_override_rate`
- `reuse_rate`
- `time_to_publish`
- `hook_hold_signal_rate`
- `hook_variant_win_rate`
- `scroll_depth_50_rate` (for long-form pages)
- `time_on_page_gt2m_rate` (for long-form pages)
- `bounce_lt60_rate` (for long-form pages)

Recommended cadence:
- Snapshot per post at completion
- Weekly rollup for workflow tuning

## Output Formats

Use one of three modes.

Mode A: Human-first (default)
- Final content
- 3-5 bullet rationale
- "Needs verification" section if applicable

Mode B: Structured (for automations)
- Return JSON with fixed keys:
```json
{
  "platform": "",
  "language": "",
  "goal": "",
  "strategy_brief": {},
  "chosen_angle": "",
  "content": "",
  "hook": "",
  "hook_spec": {
    "trigger": "CuriosityGap|Identity|Tension|ROMO|FOMO|SocialProof",
    "lead_type": "Zinger|FirstPerson|Question|Scene",
    "formula": "SPY|PAS|APP|Custom",
    "word_count": 0
  },
  "cta": "",
  "facts_used": [],
  "canonical_source_path": "",
  "claim_trace": [{"claim_id": "", "used_in": ["x", "linkedin"]}],
  "response_schema": {"name": "", "version": ""},
  "render_plan": {"owner": "code", "steps": []},
  "unverified_items": [],
  "scores": {
    "ai_ness_score": 0,
    "clarity_score": 0,
    "specificity_score": 0,
    "factual_risk_score": 0,
    "generic_marker_count": 0,
    "personal_anchor_count": 0,
    "length_ratio": 0.0,
    "rhythm_variance_score": 0,
    "hook_15s_score": 0
  },
  "risk_level": "LOW|MEDIUM|HIGH",
  "approval_mode": "batch|inline",
  "gate_results": {
    "formal_gate": "pass|fail",
    "llm_judge_gate": "pass|borderline|fail",
    "human_gate_required": true
  },
  "pipeline_metrics": {
    "gate_pass_rate": 0.0,
    "iterations_to_done": 0,
    "human_override_rate": 0.0,
    "reuse_rate": 0.0,
    "time_to_publish": 0,
    "hook_hold_signal_rate": 0.0,
    "hook_variant_win_rate": 0.0,
    "scroll_depth_50_rate": 0.0,
    "time_on_page_gt2m_rate": 0.0,
    "bounce_lt60_rate": 0.0
  },
  "quality_checks": {
    "factual_consistency": true,
    "tone_match": true,
    "platform_fit": true
  }
}
```

Mode C: Atomized Output (for repurposing/COPE)
- Return content atoms with metadata:
```json
{
  "canonical_topic": "",
  "atoms": [
    {
      "atom_id": "",
      "type": "claim|example|lesson|cta|hook",
      "title": "",
      "core_text": "",
      "evidence_links": [],
      "claim_ids": [],
      "risk_level": "LOW|MEDIUM|HIGH",
      "reuse_targets": ["x", "linkedin"],
      "evergreen_score": 0.0
    }
  ]
}
```

## Multi-Post Planning Mode

If user asks for a plan/series:
- Propose 3-7 items with different angles.
- Keep one theme, avoid repetitive hooks.
- Ensure each item maps to at least one verified source fact.
- Reuse `claim_id` values from `FACT_REGISTRY` across items to prevent factual drift.
- Reuse atoms where appropriate instead of rewriting from scratch.
- Mark publish cadence suggestion.

## Guardrails

- Never expose secrets from source data (keys, tokens, credentials).
- Never output uncertain claims as facts.
- Never maintain multiple conflicting factual copies across platform variants; update canonical source and regenerate.
- Never skip EXA MCP verification before final output.
- Never publish `HIGH` risk content without inline human approval.
- Never ship automation content to publish step without schema validation.
- Never run one-pass "humanize/de-AI" rewriting without parallel critics and hard rules.
- Prefer concise, concrete language over abstract hype.

## Reference

Load `references/request-template.md` when the user needs a ready input form.
Load `references/atom-schema.md` when atomized output is requested.
Load `references/risk-gate.md` when risk-classification decisions are unclear.
Load `references/role-models.md` when choosing or updating model assignments per role.

Load `references/patterns.md` when the task needs:
- Hook formulas
- De-AI anti-pattern examples
- Quick platform adaptation patterns





















