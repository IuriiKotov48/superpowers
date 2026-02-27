# Role -> Model (Agreed Defaults)

These are the agreed role assignments for the overall content pipeline.

Important:
- `openai/gpt-5.2` is the Codex orchestrator (this session). Do not delegate it via OpenCode.
- OpenCode is used only for second-opinion critic runs when desired.

## content-core (core pipeline roles)

- Orchestrator (strategy gate, synthesis, final decisions): `openai/gpt-5.2` (Codex)
- Critic A (De-AI / anti-bullshit): `openai/gpt-5.2` (Codex)
- Critic B (Rhythm / flow): `google/antigravity-gemini-3-pro`
- Critic C (Voice): `google/antigravity-gemini-3-pro`
- Risk Gate second opinion: `kimi-for-coding/kimi-k2-thinking`
- COPE Adapter (X/LinkedIn repack): `google/antigravity-gemini-3-flash`

## content-opencode-critique (delegated critic roles)

See: `C:\Users\ik\.codex\superpowers\skills\content-opencode-critique\references\model-map.recommended.json`

