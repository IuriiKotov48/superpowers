# OpenCode Task Packet

## Objective
[One concrete objective]

## Workspace
- WORKDIR: [absolute Windows path like `C:\repo\project` or "auto-current-repo"]
- DETAIL_LEVEL: [compact|balanced|diagnostic; default: balanced]

## Routing Inputs
- TASK_TYPE: [e.g. `big-context-analysis`, `log-parsing`, `metric-aggregation`, `mechanical-code-edit`, `test-scaffolding`, `frontend-implementation`, `frontend-styling`, `frontend-bugfix`, `architecture-decision`, `strategy-decision`, `complex-refactor-planning`, `external-coordinator-consult`, `generic-mechanical`]
- INPUT_VOLUME: [small|medium|large]
- REQUIRES_STRATEGY: [yes|no]
- ROUTER_MODE: [auto|manual; default: auto]
- TARGET_MODEL (optional override): [provider/model]
- LOCAL_COORDINATOR_LABEL (optional): [default `codex-orchestrator`]
- FLASH_MODEL (optional): [default `google/antigravity-gemini-3-flash`]
- K2_MODEL (optional): [default `kimi-for-coding/k2p5`]
- FRONTEND_MODEL (optional): [default `kimi-for-coding/k2p5`]
- COORDINATOR_MODEL / EXTERNAL_COORDINATOR_MODEL (optional): [default `google/antigravity-claude-opus-4-5-thinking`]
- ALLOW_EXTERNAL_COORDINATOR (optional): [yes|no; default no]

## Allowed Scope
- [allowed path/pattern; must match delegate_task.ps1 --allow-path]

## Forbidden Scope
- No architecture changes
- No refactors outside allowed scope
- No dependency changes
- No git history rewrite

## Inputs
- [absolute Windows input path]

## Required Actions
1. [atomic action]
2. [atomic action]
3. [atomic action]

## Completion Criteria
- [checkable criterion]
- [checkable criterion]

## Context Escalation Policy
- First return the structured report fields.
- If confidence is low or context is missing, provide diagnostics signals and reference `RAW_EXCERPT`.
- Use `RAW_LOG` only when excerpt-level diagnostics are insufficient.

## Output Contract (mandatory)
Return only:

BEGIN_REPORT
STATUS: DONE|BLOCKED
SUMMARY: <one line>
WORKDIR: <absolute workspace used for execution>
MODEL: <provider/model or default>
TASK_TYPE: <task classification>
MODEL_ROLE: <context-synthesizer|data-extractor|code-executor|...>
TARGET_MODEL: <selected model>
INPUT_VOLUME: <small|medium|large>
REQUIRES_STRATEGY: <yes|no>
ROUTER_MODE: <auto|manual>
ROUTING_REASON: <one line>
LOCAL_COORDINATOR: <local coordinator label>
EXTERNAL_COORDINATOR_MODEL: <external consultation model>
EXTERNAL_COORDINATOR_ALLOWED: <yes|no>
DETAIL_LEVEL: <compact|balanced|diagnostic>
CONFIDENCE: <high|medium|low>
RISK: <low|medium|high>
NEEDS_MORE_CONTEXT: <yes|no>
ARTIFACTS: <comma-separated absolute paths or none>
RAW_EXCERPT: <absolute path or none>
RAW_LOG: <absolute path or none>
CHECKS:
- <check result>
- <check result>
BLOCKERS:
- <blocker>
END_REPORT

If blocked, set `STATUS: BLOCKED` and list exact missing inputs.
