-- Sim.step(sim, dt): the sim-layer half of Match.step's frame order (docs/
-- ARCHITECTURE.md "Systems and frame order", step 4) -- sample the baked
-- static field at each live body's position, then integrate. Collision
-- detection and the resulting contact list arrive in slice 05; this slice's
-- ships pass through worlds (Gotcha: "Ships pass through worlds this
-- slice"). Pure -- no `love.*` (docs/ARCHITECTURE.md "Layers").
local Field = require("src.sim.field")
local Integrate = require("src.sim.integrate")

local Sim = {}

function Sim.step(sim, dt)
	for _, body in pairs(sim.bodies.slots) do
		if not body.dead then
			local accel = Field.sample(sim.field, body.x, body.y)
			Integrate.step(body, accel.x, accel.y, dt)
		end
	end
end

return Sim
