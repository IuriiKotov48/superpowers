# Critic Roles

Use one role per delegated run unless running the de-AI bundle in parallel.

## factual_critic

Goal:
- verify factual claims against provided sources
- flag overclaims and missing caveats

Output focus:
- factual risk level
- unsupported claims
- exact rewrites to reduce risk

## clarity_critic

Goal:
- improve readability, structure, and precision
- remove ambiguity and repetition

Output focus:
- confusing sentences
- rewrite suggestions with simpler wording
- stronger paragraph flow
- cross-variant consistency drift (numbers, dates, entities, and claim wording)

## voice_critic

Goal:
- preserve founder voice and human tone
- remove generic AI phrasing

Output focus:
- robotic patterns
- specific tone mismatches
- replacements that keep original meaning

## hook_critic

Goal:
- strengthen opening lines and CTA relevance
- improve first-15-seconds retention potential

Output focus:
- first-line strength score
- hook alternatives
- CTA alignment with post goal
- trigger fit (`CuriosityGap|Identity|Tension|ROMO|FOMO|SocialProof`)
- lead type fit (`Zinger|FirstPerson|Question|Scene`)
- formula fit (`SPY|PAS|APP|Custom`)
- opening word count vs target limit (recommended <= 30)
- anti-pattern flags for generic openers

## risk_critic

Goal:
- detect legal, policy, and reputation risks
- classify approval requirement

Output focus:
- risk level: low|medium|high
- required approval mode: batch|inline
- language that needs softening
- gate decision basis for approval recommendation
- requires-inline reason when uncertainty is non-trivial

## generic_detector

Goal:
- identify generic AI markers and abstract filler

Output focus:
- marker list with exact excerpts
- delete-or-rewrite recommendation per marker
- count before rewrite (`generic_marker_count_before`)

## rhythm_analyzer

Goal:
- detect monotone cadence and repetitive syntax

Output focus:
- repeated sentence openings
- sentence-length monotony observations
- rhythm variance score (`rhythm_variance_score`)

## personal_anchor_critic

Goal:
- ensure text includes grounded human anchors

Output focus:
- missing anchors list
- suggested anchor slots (experience/date/name/opinion)
- anchor count (`personal_anchor_count`)
