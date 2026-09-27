Status: pending
Complexity: high

# Ship flight under gravity with fuel

## What to build
- Two ships spawn floating at fixture spawn points. P1 (WASD) and P2 (arrows) rotate and thrust.
- Ships fall along the static field and trace curved paths. Thrust burns fuel; an empty tank leaves the ship drifting.
- A fuel bar per player in the HUD. This slice establishes the body store, pools, components, and `Match.step` frame order.

## Files to create/modify
- src/sim/bodies.lua — body store; generation-checked ids; `Bodies.add/get/markDead/sweep`
- src/sim/integrate.lua — semi-implicit Euler
- src/sim/step.lua — `Sim.step(sim, dt)`: sample field → integrate
- src/game/pools.lua — pool arrays, `Pools.sweep` (runs with body sweep)
- src/game/components/fuel.lua — `consume`, `add`, `isEmpty`
- src/game/components/thruster.lua — `apply(ship, ctx)` uses intent + Fuel
- src/game/systems/ship_system.lua — `spawn`, `update(ctx)`
- src/game/match.lua — full frame order skeleton from `docs/ARCHITECTURE.md`
- src/game/config.lua — ship rotation speed, thrust accel, fuel capacity, burn rate
- src/app/input.lua — keyboard → `ctx.intents[player] = {rotate, thrust, fire}`
- src/app/render/ships.lua, src/app/render/hud.lua
- tests/unit/{bodies,integrate,fuel,thruster}_test.lua
- tests/integration/ship_flight_test.lua

## Test approach
- Unit: stale body id returns nil after sweep and slot reuse; Euler step with constant accel matches closed form within tolerance; `Fuel.consume` never goes below 0; thrust does nothing when empty; rotation needs no fuel.
- Integration: a ship released above a world accelerates toward it; holding thrust for N s drains fuel by N × burnRate then stops accelerating.

## Acceptance criteria
- [ ] Both ships fly independently on one keyboard.
- [ ] Ships curve toward worlds with no input.
- [ ] Empty fuel disables thrust but not rotation.
- [ ] `Match.step` shows the full frame order, with empty stubs for later steps.
- [ ] No `love.*` in `src/sim` or `src/game`.

## Blocked by
03

## Gotchas
- Ships pass through worlds in this slice. Collision arrives in 05.
- Leave a place in the ship record for `lander` and `weapon`; nil for now.
- Records carry `dead = true`; only `Pools.sweep` and `Bodies.sweep` remove. Sweep bodies after pools so no record points at a missing body mid-frame.
