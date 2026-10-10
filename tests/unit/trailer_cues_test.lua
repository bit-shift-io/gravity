local Cues = require("tools.trailer.cues")

-- A match context with just what Cues reads: the event list and the ships'
-- thrust intents.
local function newCtx()
	return { events = {}, pools = { ships = {} }, intents = {} }
end

local function addShip(ctx, player)
	local ship = { player = player, fuel = { amount = 1 } }
	table.insert(ctx.pools.ships, ship)
	ctx.intents[player] = { thrust = false }
	return ship
end

local function raise(ctx, kind)
	table.insert(ctx.events, { kind = kind, x = 0, y = 0, time = 0 })
end

-- Steps 1..to, calling eventsAt(ctx, step) before each observe.
local function record(shot, to, eventsAt)
	local ctx = newCtx()
	local recorder = Cues.new(shot)
	for step = 1, to do
		if eventsAt then
			eventsAt(ctx, step)
		end
		recorder:observe(ctx, step)
	end
	return recorder:result()
end

local function kinds(cues)
	local list = {}
	for i, cue in ipairs(cues) do
		list[i] = cue.kind
	end
	return table.concat(list, ",")
end

test("Trailer Cues cues an event once while it stays in ctx.events", function()
	local result = record({ from = 0, to = 10 }, 10, function(ctx, step)
		if step == 3 then
			raise(ctx, "fire")
		end
	end)
	assertEqual("fire", kinds(result.cues))
end)

test("Trailer Cues gives one blast cue for a blast and a crash in one step", function()
	local result = record({ from = 0, to = 5 }, 5, function(ctx, step)
		if step == 2 then
			raise(ctx, "blast")
			raise(ctx, "crash")
		end
	end)
	assertEqual("blast", kinds(result.cues))
end)

test("Trailer Cues maps an asteroid split to the asteroidDeath sound", function()
	local result = record({ from = 0, to = 5 }, 5, function(ctx, step)
		if step == 2 then
			raise(ctx, "asteroidSplit")
		end
	end)
	assertEqual("asteroidDeath", kinds(result.cues))
end)

test("Trailer Cues never cues events raised before from", function()
	local result = record({ from = 100, to = 160 }, 160, function(ctx, step)
		if step == 90 then
			raise(ctx, "blast")
		end
	end)
	assertEqual("", kinds(result.cues))
end)

test("Trailer Cues times a cue from the first frame that shows its step", function()
	-- Frame k shows the state after step from + k; it plays at (k - 1) / 60.
	local result = record({ from = 100, to = 160 }, 160, function(ctx, step)
		if step == 131 then
			raise(ctx, "fire")
		end
	end)
	assertNear(30 / 60, result.cues[1].time)
end)

test("Trailer Cues divides time by speed", function()
	-- speed 2: the event at step 131 first shows on frame 16 (step 132).
	local result = record({ from = 100, to = 160, speed = 2 }, 160, function(ctx, step)
		if step == 131 then
			raise(ctx, "fire")
		end
	end)
	assertNear(15 / 60, result.cues[1].time)
end)

test("Trailer Cues plays at most one one-shot per frame when speed is above 1", function()
	local result = record({ from = 0, to = 4, speed = 2 }, 4, function(ctx, step)
		if step == 1 then
			raise(ctx, "fire")
			raise(ctx, "asteroidDeath")
		end
	end)
	assertEqual("fire", kinds(result.cues))
end)

test("Trailer Cues reports the clip duration in seconds", function()
	local result = record({ from = 100, to = 160, speed = 2 }, 160)
	assertNear(30 / 60, result.duration)
end)

test("Trailer Cues runs the thrust bed only over frames where a ship thrusts", function()
	local ctx = newCtx()
	addShip(ctx, 1)
	local recorder = Cues.new({ from = 0, to = 10 })
	for step = 1, 10 do
		ctx.intents[1].thrust = (step >= 3 and step <= 5)
		recorder:observe(ctx, step)
	end
	local thrust = recorder:result().thrust
	assertEqual(1, #thrust)
	assertNear(2 / 60, thrust[1].start)
	assertNear(5 / 60, thrust[1].stop)
end)

test("Trailer Cues ignores thrust from a dead ship", function()
	local ctx = newCtx()
	local ship = addShip(ctx, 1)
	ship.dead = true
	ctx.intents[1].thrust = true
	local recorder = Cues.new({ from = 0, to = 4 })
	for step = 1, 4 do
		recorder:observe(ctx, step)
	end
	assertEqual(0, #recorder:result().thrust)
end)

test("Trailer Cues cues events in the extra frames before frame 1 at negative times", function()
	local shot = { from = 60, to = 66, speed = 2 }
	-- pre = 3: frames k = -2..0 show steps 56, 58, 60; frame 1 shows 62.
	local result
	do
		local ctx = newCtx()
		local recorder = Cues.new(shot, 3)
		for step = 1, 66 do
			if step == 50 then
				raise(ctx, "fire") -- before the first extra frame (step 56): pre-roll
			elseif step == 57 then
				raise(ctx, "blast") -- first shown by frame k = -1 (step 58)
			end
			recorder:observe(ctx, step)
		end
		result = recorder:result()
	end
	assertEqual("blast", kinds(result.cues))
	assertNear(-2 / 60, result.cues[1].time, 1e-9) -- frame k = -1 plays at (k - 1) / 60
end)

test("Trailer Cues extra frames land at their trailer times once the item start is added", function()
	local Timeline = require("tools.trailer.timeline")
	local timeline = {
		items = { { start = 600 } },
		frames = 600,
	}
	local sound = Timeline.sound(timeline, { { cues = { { time = -15 / 60, kind = "blast" } }, thrust = {}, duration = 1 } })
	assertNear(9.75, sound.cues[1].time, 1e-9)
end)
