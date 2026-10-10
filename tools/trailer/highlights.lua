-- Highlight scoring for the trailer (no `love.*`). Pure: it turns a match's
-- per-step feature rows into ranked sliding windows per category; running the
-- matches lives in find_highlights.lua.
--
-- A window `{from, to}` covers steps from + 1 .. to, exactly the steps a clip
-- with that from/to shows. Its score is the weighted sum of the features in
-- those steps (see CATEGORIES); the best windows are picked greedily, never
-- overlapping each other.
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local Thruster = require("src.game.components.thruster")

local Config = require("src.game.config")
local ShotFormat = require("tools.trailer.shot_format")

local Highlights = {}

-- Weights by feature (see Recorder). Ship-step features count one per ship per
-- step, so they are divided by 60 to read as ship-seconds. Features:
--   crash (a ship died), blast (shell detonation), split (asteroid split),
--   rock (asteroid destroyed), fire (shot fired), thrust (flying ship burning),
--   landing (flying ship turned tank), tankFire (tank charging a shot),
--   detonation (armed shell fired off by its owner's fire press).
-- gravity is a proxy: lots of burning ships, few deaths, so ships are flying
-- and slinging round the worlds rather than blowing up.
Highlights.CATEGORIES = {
	multikill = { crash = 4, blast = 1 },
	gravity = { thrust = 1 / 60, crash = -3 },
	asteroids = { split = 3, rock = 1 },
	tank = { landing = 3, tankFire = 1 / 30 },
	detonation = { detonation = 4, blast = 0.5 },
	brawl = { crash = 3, blast = 1, split = 1, fire = 0.5 },
	roundwin = { crash = 4, blast = 1 },
}

-- Category names in the order they are reported.
Highlights.ORDER = { "multikill", "gravity", "asteroids", "tank", "detonation", "brawl", "roundwin" }

-- Steps after a round locks at which a roundwin window ends by default: the
-- live scene runs config.round.endDelay (3 s) and then the score card shows.
Highlights.AFTER_LOCK = 210

local function weightedSteps(steps, weights)
	local sums = { [0] = 0 }
	for i = 1, #steps do
		local row, total = steps[i], 0
		for feature, weight in pairs(weights) do
			total = total + (row[feature] or 0) * weight
		end
		sums[i] = sums[i - 1] + total
	end
	return sums
end

-- opts: window (steps), count (how many windows), afterLock (roundwin only).
-- Returns best-first list of { from, to, score }, windows disjoint, score > 0
-- only. A window that spans a round reset is skipped: the scene it shows
-- jumps. A roundwin candidate is a window ending afterLock steps after each
-- round lock, so every pick shows a round ending and its aftermath.
function Highlights.top(steps, category, opts)
	local weights = assert(Highlights.CATEGORIES[category], "unknown category " .. tostring(category))
	local sums = weightedSteps(steps, weights)
	local resets = weightedSteps(steps, { reset = 1 })
	local candidates = {}
	local function consider(to)
		local from = to - opts.window
		if from >= 0 and to <= #steps and resets[to] - resets[from] == 0 then
			candidates[#candidates + 1] = { from = from, to = to, score = sums[to] - sums[from] }
		end
	end
	if category == "roundwin" then
		for step = 1, #steps do
			if steps[step].roundEnd then
				consider(step + (opts.afterLock or Highlights.AFTER_LOCK))
			end
		end
	else
		for to = opts.window, #steps do
			consider(to)
		end
	end
	table.sort(candidates, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.from < b.from
	end)
	local picked = {}
	for _, candidate in ipairs(candidates) do
		local worthless = candidate.score <= 0 and category ~= "roundwin"
		if #picked >= opts.count or worthless then
			break
		end
		local clear = true
		for _, other in ipairs(picked) do
			if candidate.from < other.to and other.from < candidate.to then
				clear = false
				break
			end
		end
		if clear then
			picked[#picked + 1] = candidate
		end
	end
	return picked
end

-- Event kind -> feature. Events stay in ctx.events for a retention window
-- (docs/memory/match-events-stay-in-ctx.md), so each is counted once, by identity.
local EVENT_FEATURE = {
	crash = "crash",
	blast = "blast",
	asteroidSplit = "split",
	asteroidDeath = "rock",
	fire = "fire",
}

-- A ship hopping on and off a surface lands once per this many steps.
local LANDING_COOLDOWN = 60

local Recorder = {}
Recorder.__index = Recorder

function Highlights.recorder()
	-- `ships` remembers, per ship record, what it did last step.
	return setmetatable({ seen = {}, rows = {}, ships = setmetatable({}, { __mode = "k" }) }, Recorder)
end

-- Call after every Match.step with that step's number (from 1, no gaps).
function Recorder:observe(ctx, step)
	local row = {}
	for _, event in ipairs(ctx.events) do
		if not self.seen[event] then
			self.seen[event] = true
			local feature = EVENT_FEATURE[event.kind]
			if feature then
				row[feature] = (row[feature] or 0) + 1
			end
		end
	end
	-- A lock is playing -> roundOver or matchOver; a reset is roundOver -> playing.
	local phase, previous = ctx.round.phase, self.phase or "playing"
	if previous == "playing" and phase ~= "playing" then
		row.roundEnd = 1
	elseif previous == "roundOver" and phase == "playing" then
		row.reset = 1
	end
	self.phase = phase
	self:observeShips(ctx, row, step)
	self.rows[step] = row
end

local function bump(row, feature)
	row[feature] = (row[feature] or 0) + 1
end

-- Tank mode, landing and remote detonation raise no events, so they are read
-- from ship state: a landing is a flying ship now in tank mode (ships spawn as
-- tanks, so a first sighting is no landing); a remote detonation is an armed
-- shell last step that this step's fire press consumed (`consumed` newly true; a
-- shell that merely hit something clears weapon.shell without it, and a held
-- press keeps it true).
function Recorder:observeShips(ctx, row, step)
	for _, ship in ipairs(ctx.pools.ships) do
		local memory = self.ships[ship] or {}
		self.ships[ship] = memory
		if not ship.dead then
			local tank = Lander.isGrounded(ship)
			if memory.tank == false and tank and (not memory.landedAt or step - memory.landedAt >= LANDING_COOLDOWN) then
				memory.landedAt = step
				bump(row, "landing")
			end
			memory.tank = tank
			if tank then
				if ship.weapon and ship.weapon.charging then
					bump(row, "tankFire")
				end
			elseif Thruster.isThrusting(ship, ctx) then
				bump(row, "thrust")
			end
			local weapon = ship.weapon
			if weapon then
				if memory.armedShell and weapon.shell == nil and weapon.consumed and not memory.consumed then
					bump(row, "detonation")
				end
				local body = weapon.shell and Bodies.get(ctx.sim.bodies, weapon.shell)
				memory.consumed = weapon.consumed
				memory.armedShell = body ~= nil and body.armed == true
			end
		end
	end
end

-- Per-step feature rows; steps()[i] is step i.
function Recorder:steps()
	return self.rows
end

-- `players` AI slots, colours 1..players, all at `level` (default "hard").
function Highlights.roster(players, level)
	local roster = {}
	for slot = 1, players do
		roster[slot] = { color = slot, binding = { kind = "ai", level = level or "hard" } }
	end
	return roster
end

-- A pasteable manifest entry for a window: { name, seed, roster, hit = {from, to} }.
-- Returns true, text or false, message. Frame 1 of the clip shows step from + 1.
function Highlights.entry(args)
	local ok, text = ShotFormat.entry({
		seed = args.seed,
		roster = args.roster,
		markIn = { step = args.hit.from + 1, view = false, sim = { x = 0, y = 0, zoom = 1 } },
		markOut = { step = args.hit.to, view = false, sim = { x = 0, y = 0, zoom = 1 } },
	})
	if not ok then
		return false, text
	end
	return true, (text:gsub('name = "scout"', string.format("name = %q", args.name), 1))
end

-- A blob has at least levelGen.vertexCount.min vertices (a notch only adds);
-- a snake (2-4 segments) has 6-10. Perimeter^2/area overlaps between the two.
local function isSnake(vertices)
	return #vertices < Config.levelGen.vertexCount.min
end

-- "blob", "snake" or "mixed" (both in one level).
function Highlights.worldKind(level)
	local blobs, snakes = 0, 0
	for _, world in ipairs(level.worlds) do
		if isSnake(world.vertices) then
			snakes = snakes + 1
		else
			blobs = blobs + 1
		end
	end
	if blobs > 0 and snakes > 0 then
		return "mixed"
	end
	return snakes > 0 and "snake" or "blob"
end

return Highlights
