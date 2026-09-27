-- Weapon component (docs/ARCHITECTURE.md "Component"): plain-data sub-table
-- `{ kind = "cannon", cooldown = 0 }` plus these pure functions, called
-- explicitly by src/game/systems/ship_system.lua. Dispatches firing on
-- `weapon.kind` (docs/ARCHITECTURE.md "Adding things": "A new weapon -> a
-- new weapon.kind handler") -- only "cannon" exists this slice; an unknown
-- kind is a programmer error (a record built with a typo, or a future kind
-- wired into a ship spawn before its handler exists), so Weapon.tryFire
-- errors loudly rather than silently doing nothing.
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")
local ProjectileSystem = require("src.game.systems.projectile_system")

local Weapon = {}

-- The ship's un-rotated nose vector, matching src/game/components/
-- thruster.lua's NOSE and src/game/components/lander.lua's NOSE -- straight
-- up the screen at angle 0.
local NOSE = { x = 0, y = -1 }

local function fireCannon(ship, ctx)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return
	end

	local direction = Vec2.rotate(NOSE, body.angle or 0)
	ProjectileSystem.spawn(ctx, ship, body, direction)
	ship.weapon.cooldown = ctx.config.projectile.cooldown
end

local HANDLERS = {
	cannon = fireCannon,
}

-- Counts a weapon's cooldown down toward zero (docs/ARCHITECTURE.md's
-- Systems and frame order example calls this every frame, alongside
-- Thruster.apply and Lander.tick, for every ship that has one). Does
-- nothing once cooldown reaches 0 -- never goes negative, matching
-- src/game/components/fuel.lua's Fuel.consume clamping discipline.
function Weapon.tick(ship, ctx)
	local weapon = ship.weapon
	if not weapon then
		return
	end

	if weapon.cooldown > 0 then
		weapon.cooldown = math.max(0, weapon.cooldown - ctx.dt)
	end
end

-- Fires if `ctx.intents[ship.player].fire` is held and the weapon isn't on
-- cooldown, dispatching to the handler for `weapon.kind`. No-op (not an
-- error) when there's no fire intent or the weapon is still cooling down --
-- those are normal, expected frames, not a caller mistake. Landed-ship
-- gating is the caller's job (src/game/systems/ship_system.lua only calls
-- this from the not-landed branch of ShipSystem.update, the same way it
-- already gates rotate/thrust), not this function's -- Weapon has no
-- opinion about lander state.
function Weapon.tryFire(ship, ctx)
	local weapon = ship.weapon
	if not weapon then
		return
	end

	local intent = ctx.intents[ship.player]
	if not intent or not intent.fire then
		return
	end

	if weapon.cooldown > 0 then
		return
	end

	local handler = HANDLERS[weapon.kind]
	if not handler then
		error("Weapon.tryFire: unknown weapon kind '" .. tostring(weapon.kind) .. "'")
	end

	handler(ship, ctx)
end

return Weapon
