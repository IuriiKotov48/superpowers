# Request Template

Use this template when asking Codex to run the skill.

```text
Use skill: content-core

Goal:
Platform:
Language:
Audience:

Strategy brief seed:
- audience pain:
- one key promise:
- desired reader action:

Source files/links:
- path-or-url-1
- path-or-url-2

Canonical source of truth:
- source_of_truth_path:
- source_of_truth_type: file|db|url|mixed

Style sample (optional):
- path-or-url

Constraints:
- max length
- banned claims
- CTA style

Pipeline mode policy:
- architecture_mode: sequential|branching|iterative|auto
- allow_escalation_to_iterative: yes/no

Gate policy:
- require_formal_gate: yes/no
- require_llm_judge_gate: yes/no
- force_inline_for_medium_high_risk: yes/no

De-AI quality policy:
- apply parallel critics: yes/no
- max length ratio after rewrite: <= 1.0 (recommended)
- remove generic markers instead of paraphrase: yes/no
- require at least one personal anchor: yes/no

Hook strategy policy:
- preferred_trigger: CuriosityGap|Identity|Tension|ROMO|FOMO|SocialProof
- lead_type: Zinger|FirstPerson|Question|Scene
- formula: SPY|PAS|APP|Custom
- max_hook_words: 30 (recommended)
- block_generic_openers: yes/no

Consistency policy:
- use claim IDs across variants: yes/no
- when facts change regenerate all variants: yes/no

Output mode:
- human
- json
- atoms

Need recency verification:
- yes/no

EXA MCP fact-check:
- required (default)
- can skip only for pure creative fiction

Risk tolerance:
- low
- medium
- high
```

## Minimal Example

```text
Use skill: content-core
Goal: Create one X post and one LinkedIn post about a release milestone
Platform: X/Twitter and LinkedIn
Language: English
Strategy brief seed:
- audience pain: writing is slow when context-switching between apps
- one key promise: hotkey dictation reduces friction
- desired reader action: reply with their biggest workflow bottleneck
Source files/links:
- ./notes/feature-spec.md
- ./notes/changelog.md
Canonical source of truth:
- source_of_truth_path: ./notes/changelog.md
- source_of_truth_type: file
Constraints:
- No overclaims
- No hype
Pipeline mode policy:
- architecture_mode: auto
- allow_escalation_to_iterative: yes
Gate policy:
- require_formal_gate: yes
- require_llm_judge_gate: yes
- force_inline_for_medium_high_risk: yes
Consistency policy:
- use claim IDs across variants: yes
- when facts change regenerate all variants: yes
De-AI quality policy:
- apply parallel critics: yes
- max length ratio after rewrite: <= 1.0
- remove generic markers instead of paraphrase: yes
- require at least one personal anchor: yes
Hook strategy policy:
- preferred_trigger: Tension
- lead_type: FirstPerson
- formula: PAS
- max_hook_words: 30
- block_generic_openers: yes
Output mode: atoms
Need recency verification: yes
Risk tolerance: medium
```







