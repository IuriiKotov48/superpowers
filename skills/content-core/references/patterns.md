# Patterns

## Hook Formulas

Use these for the first line, then adapt to voice.

- Problem Shock:
  - "Most people lose [result] because they ignore [cause]."
- Build in Public:
  - "Today I broke [thing], fixed it, and learned [insight]."
- Before/After:
  - "Before: [pain]. After: [specific gain]."
- Contrarian:
  - "Popular advice says [X]. In practice, [Y] works better for [context]."

Prefer concrete nouns and measurable outcomes.

## First 15 Seconds Hook Rules

- Reader decision window is short; optimize first 30 words for continuation pressure.
- Hook should create a clear reason to read the next line.
- Avoid generic setup lines that can fit any topic.

## Psychological Triggers (Hook Selection)

- `CuriosityGap`: controlled incompleteness that demands closure.
- `Identity`: reader recognizes self ("if this sounds like you...").
- `Tension`: contradiction that demands explanation.
- `ROMO`: relief from hype pressure ("you can skip X and still win").
- `FOMO`: concrete opportunity-loss framing.
- `SocialProof`: trusted authority, adoption numbers, or benchmark evidence.

## Lead Types (Opening Shape)

- `Zinger`: provocative statement.
- `FirstPerson`: direct lived experience.
- `Question`: diagnostic question.
- `Scene`: concrete moment-in-time setup.

## Hook Formula Cards

- `SPY` (Short -> Pain -> Yay)
- `PAS` (Problem -> Agitate -> Solution)
- `APP` (Agree -> Promise -> Preview)

Pick one formula per draft; avoid blending multiple formulas in the opening.

## De-AI Anti-Patterns

Use multi-critic diagnosis before any rewrite pass in production.
A single "make this more human" rewrite often inflates length and preserves pattern noise.

Avoid:
- "In today's rapidly evolving landscape..."
- "Let's dive in"
- Empty intensifiers: "very", "super", "incredibly" without specifics
- Repeated sentence openings
- Over-polite filler paragraphs

Replace with:
- Observed facts
- Clear tradeoffs
- Direct claims with evidence from source data

## Voice Stabilization

When user provides style samples:
- Extract 5-8 stable traits (sentence length, humor level, directness, emoji policy).
- Keep those traits constant across outputs.
- Mirror structure, not exact phrases.

If no style sample:
- Use neutral expert voice.
- Keep confidence proportional to evidence.

## Platform Adaptation Quick Notes

- X/Twitter:
  - Strong first line in <= 120 chars.
  - One idea per tweet block.
  - Add clear close (question or CTA).
- Telegram:
  - 3-6 short paragraphs.
  - Warm conversational tone.
  - One practical takeaway.
- LinkedIn:
  - Hook + context + lesson + framework + CTA.
  - Avoid slang overload.
- Blog:
  - Section headers with clear progression.
  - Examples and edge cases.
  - Summary with next step.

## Quality Red Flags

## Parallel De-AI Critique Playbook

Run three critics in parallel and aggregate issues:
- `generic_detector`: generic markers, abstract claims, slogan-like phrasing.
- `rhythm_analyzer`: repetitive sentence lengths, repeated openings, flat cadence.
- `personal_anchor_critic`: missing names, dates, first-hand experience, or explicit opinion.

Hard rewrite rules:
- Keep rewritten length <= original length.
- Remove marked generic phrases instead of cosmetic paraphrase.
- Add at least one personal anchor.
- Enforce sentence-length variation and varied openings.

Common generic markers to kill:
- "it is important to understand"
- "this is not X, this is Y" (when used as empty rhetoric)
- abstract claims without concrete evidence or examples
- "in today's world..."
- "many developers face..."
- "today we will discuss..."

If any appears, revise:
- Claim exists but no source fact supports it
- Generic motivational text dominates practical value
- Hook and body promise different outcomes
- CTA asks for action unrelated to main value


