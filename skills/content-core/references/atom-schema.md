# Atom Schema

Use this schema when `Mode C: Atomized Output` is requested.

## Required fields per atom

- `atom_id`: stable unique id
- `type`: `claim|example|lesson|cta|hook`
- `title`: short label
- `core_text`: reusable text unit
- `evidence_links`: one or more source links if factual
- `risk_level`: `LOW|MEDIUM|HIGH`
- `reuse_targets`: one or more platforms
- `evergreen_score`: `0.0..1.0`

## Good atom rules

- Keep one atom = one idea.
- Avoid platform-specific slang in atoms.
- Keep factual and opinion atoms separate.
- Add evidence links for factual atoms only.

## Example

```json
{
  "atom_id": "release-hotkey-dictation-benefit",
  "type": "claim",
  "title": "Hotkey removes context switching",
  "core_text": "Press one shortcut, dictate, and keep typing in the same app.",
  "evidence_links": [
    "https://example.com/changelog"
  ],
  "risk_level": "LOW",
  "reuse_targets": ["x", "linkedin"],
  "evergreen_score": 0.8
}
```
