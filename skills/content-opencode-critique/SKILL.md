---
name: content-opencode-critique
description: Delegate bounded content-generation and content-critique tasks to OpenCode CLI (`opencode run`) using role-based multi-model routing. Use when the caller/orchestrator needs a second opinion for factual accuracy, clarity, voice, hooks, or risk checks while keeping final publishing decisions in the caller/orchestrator environment.
---

# OpenCode Content
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

## Workflow

1. Classify candidate subtask before delegation.
- Delegate only bounded content tasks: critique, polishing, scoring, extraction, formatting.
- Keep strategy, narrative direction, and final publish decision in the caller/orchestrator environment.

2. Build a strict content task packet.
- Define one concrete objective.
- Define critic role (`factual_critic`, `clarity_critic`, `voice_critic`, `hook_critic`, `risk_critic`, `generic_detector`, `rhythm_analyzer`, `personal_anchor_critic`).
- Define explicit output schema.
- Define validation method and failure behavior (regenerate, block, or escalate).
- Define completion criteria and BLOCKED rules.
- Define routing metadata (`TASK_TYPE`, `INPUT_VOLUME`, `REQUIRES_STRATEGY`).

3. Run OpenCode in headless mode.
- Single critic run: use `scripts/delegate_task.ps1`.
- Multi-critic sweep: use `scripts/run_content_critique.ps1`.
- Do not hardcode workspace path. Let scripts resolve from current repo.

4. Validate reports before using output.
- Require `STATUS: DONE` or `STATUS: BLOCKED`.
- If report format is broken, treat as BLOCKED.
- If confidence is low or risk is high, escalate to inline human review.
- If structured output fails schema validation, treat as BLOCKED for production use.
- Require gate decision fields for approval-sensitive tasks (`GATE_STAGE`, `GATE_DECISION_BASIS`, `APPROVAL_MODE_RECOMMENDATION`).

5. Integrate and continue orchestration.
- Accept only verifiable critique.
- Apply edits in the caller/orchestrator environment.
- Keep final decisions in the caller/orchestrator environment.

## Delegation Rubric

Delegate to OpenCode Content:
- factual claim check against provided links
- cliche detection and style cleanup
- hook strength review
- CTA clarity review
- first-15-seconds hook effectiveness review
- structure/flow diagnostics
- reusable atom extraction
- cross-variant consistency check (same facts, numbers, entities, and dates across X/LinkedIn drafts)
- schema compliance review for automation payloads
- deterministic render-rule extraction (what must move from prompt to code)
- de-AI diagnosis with parallel critics and measurable rewrite constraints

Do not delegate to OpenCode Content:
- brand strategy decisions
- product positioning decisions
- legal sign-off decisions
- controversial messaging approval

## Critic Roles

Use one role per run unless using the multi-critic script.

- `factual_critic`: verify claims, flag overclaims, rate factual risk.
- `clarity_critic`: simplify wording, remove ambiguity, improve flow, detect cross-variant drift, and flag schema-unfriendly phrasing.
- `voice_critic`: preserve founder tone, remove generic AI phrasing.
- `hook_critic`: strengthen first line and CTA relevance; enforce trigger/lead/formula clarity, 30-word opening discipline, and anti-pattern avoidance.
- `risk_critic`: flag legal/policy/reputation risks and required approvals.
- `generic_detector`: identify generic markers and abstract filler that should be removed.
- `rhythm_analyzer`: detect monotone cadence, repeated sentence openings, and flat pacing.
- `personal_anchor_critic`: require concrete human anchors (experience/date/name/opinion).

Detailed prompts live in `references/critic-roles.md`.

## De-AI Bundle (Recommended for "humanize" requests)

When user intent includes "humanize", "de-AI", or "remove AI-ness":
- Run `generic_detector`, `rhythm_analyzer`, and `personal_anchor_critic` in parallel.
- Aggregate issues into one rewrite checklist.
- Apply hard rules in rewrite:
  - rewritten length <= original
  - marked generic phrases removed (not cosmetic paraphrase)
  - at least one personal anchor
  - sentence-length variation present
- If any hard rule fails, return `BLOCKED` for publish-ready status.

## Conditional Gate Outputs

When task touches approval or publishing readiness, report must include:
- `GATE_STAGE`: `formal|llm_judge|human_recommendation`
- `GATE_DECISION_BASIS`: one-line reason tied to checks/evidence
- `APPROVAL_MODE_RECOMMENDATION`: `batch|inline`
- `REQUIRES_INLINE_REVIEW_REASON`: explicit reason or `none`

Policy:
- Unknown gate state => `BLOCKED`
- Borderline LLM-judge output => recommend `inline`
- `MEDIUM|HIGH` risk with uncertainty => recommend `inline`

## Task Packet Contract

Use this output contract in every prompt:
- `BEGIN_REPORT`
- `STATUS: DONE|BLOCKED`
- `SUMMARY:` one short line
- `WORKDIR:` absolute workspace path used for execution
- `MODEL:` actual model used for the delegated task
- `TASK_TYPE:` delegated task classification
- `MODEL_ROLE:` role for this run (`factual_critic|clarity_critic|voice_critic|hook_critic|risk_critic|generic_detector|rhythm_analyzer|personal_anchor_critic`)
- `TARGET_MODEL:` model selected by router or manual override
- `INPUT_VOLUME:` `small|medium|large`
- `CANONICAL_SOURCE_PATH:` absolute path to source-of-truth facts file, or `none`
- `COMPARE_ARTIFACTS:` comma-separated absolute paths for variant comparison, or `none`
- `REQUIRES_STRATEGY:` `yes|no`
- `ROUTER_MODE:` `auto|manual`
- `ROUTING_REASON:` one short line
- `DETAIL_LEVEL:` `compact|balanced|diagnostic`
- `OUTPUT_SCHEMA_PATH:` absolute path to schema file, or `none`
- `VALIDATION_MODE:` `strict|lenient`
- `MAX_LENGTH_RATIO:` numeric threshold (for de-AI rewrites), or `none`
- `REQUIRE_PERSONAL_ANCHOR:` `yes|no`
- `REMOVE_GENERIC_MARKERS:` `yes|no`
- `HOOK_TRIGGER:` `CuriosityGap|Identity|Tension|ROMO|FOMO|SocialProof|none`
- `HOOK_LEAD_TYPE:` `Zinger|FirstPerson|Question|Scene|none`
- `HOOK_FORMULA:` `SPY|PAS|APP|Custom|none`
- `HOOK_WORD_LIMIT:` integer or `none`
- `GATE_STAGE:` `formal|llm_judge|human_recommendation`
- `GATE_DECISION_BASIS:` one short line
- `APPROVAL_MODE_RECOMMENDATION:` `batch|inline`
- `REQUIRES_INLINE_REVIEW_REASON:` one short line or `none`
- `CONFIDENCE:` `high|medium|low`
- `RISK:` `low|medium|high`
- `NEEDS_MORE_CONTEXT:` `yes|no`
- `HOOK_15S_SCORE:` `0-100` or `none`
- `HOOK_WORD_COUNT:` integer or `none`
- `HOOK_ANTIPATTERN_FLAGS:` integer or `none`
- `ARTIFACTS:` absolute paths or `none`
- `RAW_EXCERPT:` absolute path or `none`
- `RAW_LOG:` absolute path or `none`
- `CHECKS:` flat bullet list
- `BLOCKERS:` flat bullet list or `none`
- `END_REPORT`

Require OpenCode to avoid extra prose outside the contract.

## Script Usage

Windows (PowerShell), single critic:
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\superpowers\skills\content-opencode-critique\scripts\delegate_task.ps1" `
  --task-file "C:\abs\path\task_packet.md" `
  --report-file "C:\abs\path\report.md" `
  --router manual `
  --task-type content-critique `
  --model "provider/model"
```

Windows (PowerShell), multi-critic sweep:
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\superpowers\skills\content-opencode-critique\scripts\run_content_critique.ps1" `
  --draft-file "C:\abs\path\draft.md" `
  --output-dir "C:\abs\path\reports" `
  --models-file "C:\abs\path\model-map.json"
```

Optional flags (`delegate_task.ps1`):
```powershell
--workdir "C:\abs\path\to\repo"
--router auto
--task-type content-critique
--input-volume medium
--requires-strategy no
--model provider/model
--detail-level balanced
--timeout-sec 600
--retries 1
--raw-policy on-blocked
--excerpt-lines 80
--allow-non-git
```

## Routing Matrix (Content)

- `content-research-summary` -> `context-synthesizer` model profile
- `content-critique` -> role-specific critic model from model map
- `content-polish` -> `clarity_critic` profile
- `content-risk-check` -> `risk_critic` profile
- `content-atomization` -> `structure-extractor` profile
- `content-consistency-check` -> `clarity_critic` profile
- `content-schema-check` -> `clarity_critic` profile
- `content-generic-detection` -> `generic_detector` profile
- `content-rhythm-analysis` -> `rhythm_analyzer` profile
- `content-personal-anchor-check` -> `personal_anchor_critic` profile
- `content-deaify-bundle` -> parallel bundle (`generic_detector` + `rhythm_analyzer` + `personal_anchor_critic`)
- `content-hook-optimization` -> `hook_critic` profile
- `content-gate-review` -> gate decision reporter (`risk_critic` + `clarity_critic`)
- `requires-strategy=yes` -> `BLOCKED` and route back to the caller/orchestrator environment

Default policy:
- Router mode: `manual` for critique runs to keep model choice explicit.
- Router mode: `auto` allowed for low-risk extraction/summarization.

## Safety

- Never treat critique as final truth without caller/orchestrator review.
- Never publish directly from delegated output.
- Never skip human approval for high-risk content.
- Never resolve factual conflicts by editing only one platform variant; recommend canonical update + regeneration.
- Never approve automation payloads as DONE if schema validation status is unknown.
- Never approve "humanized" output without hard-rule metrics (length ratio, generic markers, personal anchors).
- Never return publish-ready recommendation without explicit gate decision basis.
- Never approve hooks that rely on banned generic openers instead of a concrete trigger/lead pattern.

## Exit codes

- `0`: DONE
- `10`: BLOCKED
- `11`: invalid report format

## References

- Task packet template: `references/task-packet-template.md`
- Critic role prompts: `references/critic-roles.md`
- Model map template (now set to your agreed defaults): `references/model-map.template.json`
- Recommended model map (same defaults, stable filename): `references/model-map.recommended.json`





















