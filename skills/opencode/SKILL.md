---
name: opencode
description: Delegate bounded, low-complexity mechanical tasks to OpenCode CLI (`opencode run`) and return structured DONE/BLOCKED reports for coordinator review. Use when user requests hybrid execution with a cheaper model, or when tasks are repetitive (log extraction, metrics aggregation, checklist execution, formatting) and must be done with strict constraints and no architectural autonomy. Resolve workspace from the current repository by default to avoid running in the wrong project.
---

# OpenCode

## Workflow

1. Classify candidate subtask before delegation.
- Delegate only low-risk mechanical work.
- Keep architecture, bug root-cause decisions, refactors, and quality tradeoffs in Codex.

2. Build a strict task packet.
- Define one concrete objective.
- Define explicit allowed files/paths.
- Define explicit forbidden actions.
- Define exact output schema.
- Define completion criteria and BLOCKED rules.
- Define routing metadata (`TASK_TYPE`, `INPUT_VOLUME`, `REQUIRES_STRATEGY`) so model selection is deterministic.

3. Run OpenCode in headless mode.
- Use `scripts/delegate_task.ps1`.
- Pass task packet file and report file path.
- Do not hardcode workspace path. Let the script resolve it from current repo.
- Use `--allow-path` for tasks that may edit files.
- Default to `--detail-level balanced` unless the task explicitly needs compact or deep diagnostics.
- Default to `--router auto` unless you need manual model override.

4. Validate report before using output.
- Require `STATUS: DONE` or `STATUS: BLOCKED`.
- If report format is broken, treat as BLOCKED.
- Re-run once with clarified constraints if needed.
- Use progressive disclosure to balance cost and quality:
  1) read structured report fields first,
  2) if still unclear read excerpt diagnostics,
  3) open full raw log only when excerpt is insufficient.

5. Integrate and continue orchestration.
- Accept only verifiable results.
- Keep final technical decisions in Codex.

## Delegation Rubric

Delegate to OpenCode:
- log parsing
- metric aggregation (median/p90/max)
- checklist execution
- repetitive file edits with exact instructions
- report formatting

Do not delegate to OpenCode:
- architecture decisions
- ambiguous bug diagnosis with competing hypotheses
- concurrency design
- reliability/safety tradeoffs
- cross-module refactor planning

## Task Packet Contract

Use this output contract in every prompt:
- `BEGIN_REPORT`
- `STATUS: DONE|BLOCKED`
- `SUMMARY:` one short line
- `WORKDIR:` absolute workspace path used for execution
- `MODEL:` actual model used for the delegated task
- `TASK_TYPE:` delegated task classification
- `MODEL_ROLE:` role for this run (`context-synthesizer|data-extractor|code-executor|...`)
- `TARGET_MODEL:` model selected by router or manual override
- `INPUT_VOLUME:` `small|medium|large`
- `REQUIRES_STRATEGY:` `yes|no`
- `ROUTER_MODE:` `auto|manual`
- `ROUTING_REASON:` one short line
- `LOCAL_COORDINATOR:` label used for local strategy owner
- `EXTERNAL_COORDINATOR_MODEL:` consultation model id
- `EXTERNAL_COORDINATOR_ALLOWED:` `yes|no`
- `DETAIL_LEVEL:` `compact|balanced|diagnostic`
- `CONFIDENCE:` `high|medium|low`
- `RISK:` `low|medium|high`
- `NEEDS_MORE_CONTEXT:` `yes|no`
- `ARTIFACTS:` absolute paths or `none`
- `RAW_EXCERPT:` absolute path or `none`
- `RAW_LOG:` absolute path or `none`
- `CHECKS:` flat bullet list
- `BLOCKERS:` flat bullet list or `none`
- `END_REPORT`

Require OpenCode to avoid extra prose outside the contract. If optional fields are missing, scripts should backfill safe defaults.

## Script Usage

Windows (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\superpowers\skills\opencode\scripts\delegate_task.ps1" `
  --task-file "C:\abs\path\task_packet.md" `
  --report-file "C:\abs\path\report.md" `
  --allow-path "docs/**"
```

Optional:
```powershell
--workdir "C:\abs\path\to\repo"
--router auto
--task-type mechanical-code-edit
--input-volume medium
--requires-strategy no
--model provider/model
--flash-model google/antigravity-gemini-3-flash
--k2-model kimi-for-coding/k2p5
--frontend-model kimi-for-coding/k2p5
--coordinator-model google/antigravity-claude-opus-4-5-thinking
--local-coordinator-label codex-orchestrator
--allow-external-coordinator no
--detail-level balanced
--timeout-sec 600
--retries 1
--raw-policy on-blocked
--excerpt-lines 60
--allow-path "apps/desktop/src/**"   # repeatable
--allow-non-git                      # disables strict git guard
```

Platform scope:
- This skill is Windows-only and uses `scripts/delegate_task.ps1` as the execution entrypoint.

Model routing:
- `router=auto` chooses model by task metadata.
- `router=manual` keeps model selection explicit (use `--model`).
- explicit `--model` always overrides router.
- Local coordinator (`codex-orchestrator`) is the primary strategist/orchestrator.
- Local coordinator label is metadata only; OpenCode does not invoke it as an external model.
- External coordinator model is consultation-only and disabled by default.

## Routing Matrix

- `big-context-analysis`, `log-parsing`, `metric-aggregation`, `checklist-execution`, `report-formatting` -> `flash-model` (`google/antigravity-gemini-3-flash`) as `context-synthesizer` / `data-extractor`.
- `mechanical-code-edit`, `test-scaffolding` -> `k2-model` (`kimi-for-coding/k2p5`) as `code-executor`.
- `frontend-implementation`, `frontend-styling`, `frontend-bugfix` -> `frontend-model` (`kimi-for-coding/k2p5`) as `frontend-specialist`.
- `architecture-decision`, `strategy-decision`, `complex-refactor-planning` -> local coordinator (`codex-orchestrator`) with `BLOCKED` for manual coordinator decision.
- `external-coordinator-consult` -> external coordinator model only when `--allow-external-coordinator yes`; otherwise stays with local coordinator.
- unknown task type -> `flash-model` when `input-volume=large`, otherwise `k2-model`.
- `requires-strategy=yes` -> `BLOCKED` and route to local coordinator.

Recommended chain for large ambiguous work:
1. `Flash` summarizes large inputs.
2. `K2` performs deterministic code edits from that summary.
3. local coordinator validates tradeoffs and final decision.
4. external coordinator consult is optional and rare, only for unresolved hard problems.

Default workspace behavior:
- if `--workdir` is omitted, use current git repository root
- strict git mode is ON by default; non-git workspace is blocked
- pass `--allow-non-git` only when non-git execution is intentional
- relative `--task-file` and `--report-file` are resolved from `WORKDIR`
- always run the command from the same project directory where the task is requested
- default router mode is `auto`
- default task metadata: `task-type=generic-mechanical`, `input-volume=medium`, `requires-strategy=no`
- default model profiles:
  `flash-model=google/antigravity-gemini-3-flash`,
  `k2-model=kimi-for-coding/k2p5`,
  `frontend-model=kimi-for-coding/k2p5`,
  `coordinator-model=google/antigravity-claude-opus-4-5-thinking` (external consult),
  `local-coordinator-label=codex-orchestrator`,
  `allow-external-coordinator=no`
- default detail mode is `balanced`
- default raw policy is `on-blocked` (`always|on-blocked|never`)
- `--excerpt-lines` controls excerpt size used for diagnostics escalation

Post-run safety behavior:
- if files changed and no `--allow-path` provided, execution is blocked
- if changed files are outside `--allow-path` patterns, execution is blocked
- use `--allow-path` to define exact write boundaries for delegated edits

Context and quality behavior:
- Start with report fields (`SUMMARY`, `CHECKS`, `BLOCKERS`, confidence/risk fields).
- Escalate to `RAW_EXCERPT` when confidence is low, risk is high, or context is missing.
- Escalate to `RAW_LOG` only when excerpt is not enough for a technical decision.

Exit codes:
- `0`: DONE
- `10`: BLOCKED
- `11`: invalid report format

## References

- Task packet template: `references/task-packet-template.md`
