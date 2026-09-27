Status: pending
Complexity: medium

# Rounds, scoring, and match flow

## What to build
- A round ends when at most one ship remains. Both dying in the same step is a draw with no point.
- A score card shows round result and score (`P1 ●●○  P2 ●○○`), then all ships respawn with full fuel, and projectiles and asteroids are cleared.
- First to 3 round wins ends the match on a match-over screen with rematch.

## Files to create/modify
- src/game/systems/round_system.lua — round state machine: playing → roundOver → (respawn | matchOver)
- src/game/match.lua — round rules step; reset between rounds keeps the level and field
- src/app/states/score_card_state.lua, src/app/states/match_over_state.lua
- src/app/render/hud.lua — score pips
- src/game/config.lua — rounds to win, score card duration
- tests/unit/round_system_test.lua
- tests/integration/match_flow_test.lua

## Test approach
- Unit: one survivor scores; simultaneous deaths draw; 3 wins ends the match; draws never end it.
- Integration: scripted kills play a full match to a winner; respawned ships have full fuel and the same level.

## Acceptance criteria
- [ ] A full match plays to a winner.
- [ ] Draws are handled.
- [ ] Respawn resets fuel, clears projectiles and asteroids, and keeps the level.
- [ ] Rematch restarts with the same level.

## Blocked by
07, 08

## Gotchas
- Ships start floating at spawn points here. Starting landed arrives with level generation (11).
- Round reset must go through the despawn sweep, not direct pool clears.
