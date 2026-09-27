Status: pending
Complexity: medium

# Menus, settings, pause, gamepads

## What to build
- Title → match setup (hardcore toggle, optional seed) → match. Esc pauses with resume or quit to menu.
- Hardcore makes rotation burn fuel.
- Gamepads: left stick or d-pad rotates, trigger or A thrusts, a face button fires. Keyboard keeps working.

## Files to create/modify
- src/app/states/{title,setup,pause}_state.lua
- src/app/input.lua — gamepad mapping, player assignment
- src/game/components/thruster.lua — hardcore rotation burn via Fuel
- src/game/config.lua — hardcore rotation burn rate
- res/gamecontrollerdb.txt (copy from fido-and-kitch)
- tests/unit/hardcore_rotation_test.lua
- tests/integration/menu_flow_test.lua

## Test approach
- Unit: hardcore on — rotating drains fuel and is blocked when empty; off — free.
- Integration: FakeInput walks title → setup → match → pause → quit; a FakeInput joystick flies a ship.

## Acceptance criteria
- [ ] Full menu flow works by keyboard and gamepad.
- [ ] Hardcore setting reaches the match and changes rotation cost.
- [ ] Pause freezes the simulation.

## Blocked by
10, 11
