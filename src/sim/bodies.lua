-- Shared sim body store (docs/ARCHITECTURE.md "Body (sim)"): every dynamic
-- object (ship, projectile, asteroid) has exactly one body record here.
-- Pools reference a body by id, never by table reference, and ids are
-- generation-checked -- Bodies.get returns nil for a stale id, never a
-- reused slot's body, even though the slot itself is recycled (docs/
-- ARCHITECTURE.md "Nothing is removed from a pool or the body store outside
-- the despawn sweep"). Pure data -- no `love.*` (docs/ARCHITECTURE.md
-- "Layers").
local Bodies = {}

-- Encodes (slot, generation) into a single number id. Generations per slot
-- stay well under this multiplier for the life of a match, so no two live
-- slots ever produce the same id.
local GENERATION_MULTIPLIER = 1000000

local function encode(slot, generation)
	return slot * GENERATION_MULTIPLIER + generation
end

local function decode(id)
	local slot = math.floor(id / GENERATION_MULTIPLIER)
	local generation = id - slot * GENERATION_MULTIPLIER
	return slot, generation
end

function Bodies.new()
	return {
		slots = {}, -- slot index -> body record, or nil if free
		generations = {}, -- slot index -> the generation currently occupying it
		freeSlots = {}, -- stack of slot indices freed by the last sweep
		slotCount = 0,
	}
end

-- Adds `body` to the store and returns its id. Reuses a freed slot when one
-- exists, bumping that slot's generation so any id still held from before
-- the slot was freed no longer resolves (the "stale id" gotcha).
function Bodies.add(store, body)
	local slot
	if #store.freeSlots > 0 then
		slot = table.remove(store.freeSlots)
	else
		store.slotCount = store.slotCount + 1
		slot = store.slotCount
	end

	local generation = (store.generations[slot] or 0) + 1
	store.generations[slot] = generation
	body.dead = false
	store.slots[slot] = body

	return encode(slot, generation)
end

-- Returns the body for `id`, or nil if the id is stale (its slot has since
-- been reused by a different generation) or the body has been marked dead
-- (docs/ARCHITECTURE.md "Records carry dead = true").
function Bodies.get(store, id)
	local slot, generation = decode(id)
	if store.generations[slot] ~= generation then
		return nil
	end

	local body = store.slots[slot]
	if not body or body.dead then
		return nil
	end

	return body
end

-- Marks the body dead without removing it -- only Bodies.sweep removes
-- records, so nothing mid-frame ever sees a body vanish out from under it.
function Bodies.markDead(store, id)
	local body = Bodies.get(store, id)
	if body then
		body.dead = true
	end
end

-- Removes every body marked dead and frees its slot for reuse. The only
-- place bodies are actually removed (docs/ARCHITECTURE.md "Despawn sweep").
function Bodies.sweep(store)
	for slot, body in pairs(store.slots) do
		if body.dead then
			store.slots[slot] = nil
			table.insert(store.freeSlots, slot)
		end
	end
end

return Bodies
