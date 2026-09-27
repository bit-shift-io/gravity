-- Ship pool system (docs/ARCHITECTURE.md "Systems and frame order"): the
-- only place ship records are spawned or driven each frame. Calls the
-- thruster component explicitly and in a visible order -- rotation is
-- applied directly here (it costs no fuel, so there's no component seam
-- for it yet) and thrust goes through src/game/components/thruster.lua,
-- which burns fuel via src/game/components/fuel.lua. `lander` and `weapon`
-- are left nil on the record for later slices (this slice's Gotcha: "Leave
-- a place in the ship record for lander and weapon").
local Bodies = require("src.sim.bodies")
local Thruster = require("src.game.components.thruster")

local ShipSystem = {}

-- Spawns a ship for `player` at `spawnPoint` (from the level's
-- level.spawnPoints, src/game/levels/fixture_two_worlds.lua), floating with
-- zero velocity until gravity and player input move it. Returns the new
-- ship record.
function ShipSystem.spawn(ctx, player, spawnPoint)
	local shipConfig = ctx.config.ship

	local body = {
		x = spawnPoint.x,
		y = spawnPoint.y,
		vx = 0,
		vy = 0,
		angle = 0,
		angularVelocity = 0,
		mass = shipConfig.mass,
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)

	local ship = {
		id = bodyId,
		body = bodyId,
		player = player,
		dead = false,
		fuel = {
			amount = shipConfig.fuel.capacity,
			capacity = shipConfig.fuel.capacity,
			burnRate = shipConfig.fuel.burnRate,
		},
		thruster = { accel = shipConfig.thrustAccel },
		lander = nil,
		weapon = nil,
	}

	table.insert(ctx.pools.ships, ship)
	return ship
end

-- Rotate, thrust, fire (docs/ARCHITECTURE.md "Systems and frame order",
-- step 2). Firing has no weapon component yet (Gotcha above), so an
-- intent.fire is read from ctx.intents but has nothing to act on this
-- slice -- left unhandled deliberately, not a missing feature.
function ShipSystem.update(ctx)
	local rotationSpeed = ctx.config.ship.rotationSpeed

	for _, ship in ipairs(ctx.pools.ships) do
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		if body then
			local intent = ctx.intents[ship.player]
			local rotate = intent and intent.rotate or 0
			body.angularVelocity = rotate * rotationSpeed

			Thruster.apply(ship, ctx)
		end
	end
end

return ShipSystem
