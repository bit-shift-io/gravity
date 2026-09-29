-- Weapon component (docs/ARCHITECTURE.md "Component"): plain-data sub-table
-- `{ kind = "shell", charging = false, charge = 0, prevFire = false }` plus
-- these pure functions, called explicitly by src/game/systems/ship_system.lua.
-- Charge builds linearly when fire is held, from minSpeed to maxSpeed over
-- chargeTime seconds. Release spawns a projectile at the charged speed. No
-- cooldown -- fire as frequently as desired once released.
local ProjectileSystem = require("src.game.systems.projectile_system")

local Weapon = {}

-- Updates weapon charge state and fires on release. Called every frame for
-- both flying and tank modes. The caller passes `origin` (nose position for
-- flying, turret muzzle for tank) and `direction` (the fire direction).
-- Derives press/release edges from `ctx.intents[ship.player].fire` by
-- comparing against `weapon.prevFire` each frame, updated unconditionally.
-- Does not fire if the ship is dead (checked before spawning projectile).
function Weapon.update(ship, ctx, origin, direction)
	local weapon = ship.weapon
	if not weapon then
		return
	end

	local intent = ctx.intents[ship.player]
	local fireHeld = intent and intent.fire or false

	-- Detect press/release edges
	local wasHeld = weapon.prevFire or false
	local justPressed = fireHeld and not wasHeld
	local justReleased = not fireHeld and wasHeld

	-- On press, start charging from scratch
	if justPressed then
		weapon.charging = true
		weapon.charge = 0
	end

	-- While charging, accumulate charge over chargeTime
	if weapon.charging and fireHeld then
		weapon.charge = weapon.charge + ctx.dt
		local chargeTime = ctx.config.weapon.chargeTime
		if weapon.charge > chargeTime then
			weapon.charge = chargeTime
		end
	end

	-- On release, fire at the charged speed and stop charging (only if ship is alive)
	if justReleased and weapon.charging and not ship.dead then
		weapon.charging = false
		local config = ctx.config.weapon
		local chargeTime = config.chargeTime
		local t = math.min(1, weapon.charge / chargeTime)
		local speed = config.minSpeed + (config.maxSpeed - config.minSpeed) * t

		ProjectileSystem.spawn(ctx, ship, origin, direction, speed)
		weapon.charge = 0
	end

	-- Stop charging if the ship dies, even mid-hold
	if ship.dead then
		weapon.charging = false
	end

	-- Update prevFire for next frame (even if ship dies mid-charge,
	-- this updates so next frame's release edge doesn't fire)
	weapon.prevFire = fireHeld
end

return Weapon
