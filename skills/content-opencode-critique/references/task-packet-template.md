# OpenCode Content Task Packet

## Objective
[One concrete objective]

## Workspace
- WORKDIR: [absolute Windows path like `C:\repo\project` or "auto-current-repo"]
- DETAIL_LEVEL: [compact|balanced|diagnostic; default: balanced]

## Critic Role
- MODEL_ROLE: [factual_critic|clarity_critic|voice_critic|hook_critic|risk_critic|generic_detector|rhythm_analyzer|personal_anchor_critic]

## Routing Inputs
- TASK_TYPE: [content-critique|content-polish|content-risk-check|content-research-summary|content-atomization|content-consistency-check|content-schema-check|content-generic-detection|content-rhythm-analysis|content-personal-anchor-check|content-deaify-bundle|content-hook-optimization|content-gate-review]
- INPUT_VOLUME: [small|medium|large]
- REQUIRES_STRATEGY: [yes|no]
- ROUTER_MODE: [auto|manual]
- TARGET_MODEL (optional override): [provider/model]
- CANONICAL_SOURCE_PATH (optional): [absolute path to source-of-truth facts file]
- COMPARE_ARTIFACTS (optional): [comma-separated absolute paths for variant comparison]
- OUTPUT_SCHEMA_PATH (optional): [absolute path to schema file]
- VALIDATION_MODE (optional): [strict|lenient]
- MAX_LENGTH_RATIO (optional): [numeric, e.g. 1.0]
- REQUIRE_PERSONAL_ANCHOR (optional): [yes|no]
- REMOVE_GENERIC_MARKERS (optional): [yes|no]
- HOOK_TRIGGER (optional): [CuriosityGap|Identity|Tension|ROMO|FOMO|SocialProof|none]
- HOOK_LEAD_TYPE (optional): [Zinger|FirstPerson|Question|Scene|none]
- HOOK_FORMULA (optional): [SPY|PAS|APP|Custom|none]
- HOOK_WORD_LIMIT (optional): [integer]
- GATE_STAGE (optional): [formal|llm_judge|human_recommendation]
- APPROVAL_MODE_POLICY (optional): [auto|prefer-batch|prefer-inline]

## Allowed Scope
- [allowed path/pattern; use `none` for read-only critique]

## Forbidden Scope
- No architecture or product strategy decisions
- No publishing on behalf of the user
- No edits outside allowed scope
- No dependency changes
- No git history rewrite

## Inputs
- [absolute draft path]
- [supporting links or fact sources]

## Required Actions
1. [atomic action]
2. [atomic action]
3. [atomic action]

## Completion Criteria
- [checkable criterion]
- [checkable criterion]

## Output Contract (mandatory)
Return only:

BEGIN_REPORT
STATUS: DONE|BLOCKED
SUMMARY: <one line>
WORKDIR: <absolute workspace used for execution>
MODEL: <provider/model or default>
TASK_TYPE: <task classification>
MODEL_ROLE: <factual_critic|clarity_critic|voice_critic|hook_critic|risk_critic|generic_detector|rhythm_analyzer|personal_anchor_critic>
TARGET_MODEL: <selected model>
INPUT_VOLUME: <small|medium|large>
CANONICAL_SOURCE_PATH: <absolute path or none>
COMPARE_ARTIFACTS: <comma-separated absolute paths or none>
OUTPUT_SCHEMA_PATH: <absolute path or none>
VALIDATION_MODE: <strict|lenient>
MAX_LENGTH_RATIO: <number or none>
REQUIRE_PERSONAL_ANCHOR: <yes|no>
REMOVE_GENERIC_MARKERS: <yes|no>
HOOK_TRIGGER: <CuriosityGap|Identity|Tension|ROMO|FOMO|SocialProof|none>
HOOK_LEAD_TYPE: <Zinger|FirstPerson|Question|Scene|none>
HOOK_FORMULA: <SPY|PAS|APP|Custom|none>
HOOK_WORD_LIMIT: <integer or none>
GATE_STAGE: <formal|llm_judge|human_recommendation>
GATE_DECISION_BASIS: <one line>
APPROVAL_MODE_RECOMMENDATION: <batch|inline>
REQUIRES_INLINE_REVIEW_REASON: <text or none>
REQUIRES_STRATEGY: <yes|no>
ROUTER_MODE: <auto|manual>
ROUTING_REASON: <one line>
DETAIL_LEVEL: <compact|balanced|diagnostic>
CONFIDENCE: <high|medium|low>
RISK: <low|medium|high>
NEEDS_MORE_CONTEXT: <yes|no>
CRITIQUE_SCORE: <0-100>
GENERIC_MARKER_COUNT: <integer or none>
PERSONAL_ANCHOR_COUNT: <integer or none>
LENGTH_RATIO: <number or none>
RHYTHM_VARIANCE_SCORE: <0-100 or none>
HOOK_15S_SCORE: <0-100 or none>
HOOK_WORD_COUNT: <integer or none>
HOOK_ANTIPATTERN_FLAGS: <integer or none>
TOP_ISSUES:
- <issue>
- <issue>
RECOMMENDED_EDITS:
- <edit>
- <edit>
ARTIFACTS: <comma-separated absolute paths or none>
RAW_EXCERPT: <absolute path or none>
RAW_LOG: <absolute path or none>
CHECKS:
- <check result>
- <check result>
BLOCKERS:
- <blocker or none>
END_REPORT

If blocked, set `STATUS: BLOCKED` and list exact missing inputs.










