# GRAV//TY

Two-player local vector-style space duel with polygon worlds and gravity. LÖVE (11.5 and 12) + LuaJIT.

- Architecture and rules: `docs/ARCHITECTURE.md` — composed pools; no `love.*` outside `src/app/`.
- Glossary: `docs/CONTEXT.md`
- Decisions: `docs/adr/`
- Repo memory: `docs/memory/README.md`

## Testing
- Unit tests: `sh test-unit.sh`. Run them freely.
- Integration and e2e tiers take a few minutes. Run them only when the change needs the real harness, and once at the end of a piece of work, not per step.
- Put new tests in the unit tier unless the behaviour needs the real harness. `src/game` runs under plain LuaJIT, so `Match.new` and `Match.step` work there.
