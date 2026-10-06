# GRAV//TY

Local vector-style space duel for 2–6 players (1–4 human, the rest AI) with polygon worlds and gravity. LÖVE (11.5 and 12) + LuaJIT.

- Architecture and rules: `docs/ARCHITECTURE.md` — composed pools; no `love.*` outside `src/app/`.
- Glossary: `docs/CONTEXT.md`
- Steam store images (scout and render): `docs/STEAM_ASSETS.md`
- Decisions: `docs/adr/`
- Repo memory: `docs/memory/README.md`

## Testing
- Unit tests: `sh test-unit.sh`. Run them freely.
- Integration and e2e tiers take a few minutes. Run them only when the change needs the real harness, and once at the end of a piece of work, not per step.
- Balance tier (`sh test-balance.sh`, ~90s): long seeded AI matches. Run it only when changing AI behaviour or tuning; never as part of the normal run.
- Put new tests in the unit tier unless the behaviour needs the real harness. `src/game` runs under plain LuaJIT, so `Match.new` and `Match.step` work there.

## Planning
- This project has no ClickUp card. Never ask about one and never offer to archive plans there.
