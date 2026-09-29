-- Weapon component (docs/ARCHITECTURE.md "Component"): plain-data sub-table
-- `{ kind = "shell", charging = false, charge = 0, prevFire = false, shell = nil, consumed = false }` plus
-- these pure functions, called explicitly by src/game/systems/ship_system.lua.
-- Charge builds linearly when fire is held, from minSpeed to maxSpeed over
-- chargeTime seconds. Release spawns a projectile at the charged speed. No
-- cooldown -- fire as frequently as desired once released.
-- Each player has at most one live projectile (identified by `shell` body id).
-- A fire press detonates the projectile if armed, is ignored if unarmed,
-- and never starts a charge while a projectile lives (slice 06).
local ProjectileSystem = require("src.game.systems.projectile_system")
local Bodies = require("src.sim.bodies")
local Blast = require("src.game.blast")

local Weapon = {}

-- Updates weapon charge state and fires on release. Called every frame for
-- both flying and tank modes. The caller passes `origin` (nose position for
-- flying, turret muzzle for tank) and `direction` (the fire direction).
-- Derives press/release edges from `ctx.intents[ship.player].fire` by
-- comparing against `weapon.prevFire` each frame, updated unconditionally.
-- Does not fire if the ship is dead (checked before spawning projectile).
-- Remote detonation (fire press when shell is armed) is routed here instead
-- of charging (slice 06).
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

	-- Check if there's a live shell (bodies.get returns nil for stale ids)
	local liveShell = nil
	if weapon.shell then
		liveShell = Bodies.get(ctx.sim.bodies, weapon.shell)
	end

	-- Remote detonation: fire press with an armed live shell detonates it
	if justPressed and liveShell and liveShell.armed then
		-- Find the projectile record and detonate it
		for _, projectile in ipairs(ctx.pools.projectiles) do
			if projectile.body == weapon.shell and not projectile.dead then
				Blast.detonate(ctx, projectile, liveShell)
				weapon.shell = nil
				weapon.consumed = true
				break
			end
		end
	elseif justPressed and liveShell then
		-- Fire press with an unarmed shell: do nothing, mark as consumed so
		-- we don't start charging while holding
		weapon.consumed = true
	elseif justPressed and not liveShell then
		-- Fire press with no live shell: start charging from scratch
		weapon.charging = true
		weapon.charge = 0
		weapon.consumed = false
	end

	-- While charging, accumulate charge over chargeTime
	if weapon.charging and fireHeld and not weapon.consumed then
		weapon.charge = weapon.charge + ctx.dt
		local chargeTime = ctx.config.weapon.chargeTime
		if weapon.charge > chargeTime then
			weapon.charge = chargeTime
		end
	end

	-- On release, fire at the charged speed and stop charging (only if ship is alive)
	if justReleased and weapon.charging and not weapon.consumed and not ship.dead then
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

	-- Clear consumed flag on release
	if justReleased then
		weapon.consumed = false
	end

	-- Update prevFire for next frame (even if ship dies mid-charge,
	-- this updates so next frame's release edge doesn't fire)
	weapon.prevFire = fireHeld
end

return Weapon
