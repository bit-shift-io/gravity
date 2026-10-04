-- The stuck rule (docs/CONTEXT.md "Stuck"): an AI that has not fired for
-- config.ai.stuckDelay seconds relaxes its standards so it fires. A
-- personality calls Stuck.fired(ctx, state) on the think its intent starts
-- a shot, and asks Stuck.cycles(ctx, state) for how many full stuckDelay
-- periods have passed since (0 = not stuck). The clock lives on
-- state.firedAt (per-slot memory, ctx.ai[slot]) and starts at the first
-- call, so a fresh ship gets one full delay. Airburst detonation presses
-- are not shots and never reset it.
local Stuck = {}

local function started(ctx, state)
	state.firedAt = state.firedAt or ctx.time
	return state.firedAt
end

function Stuck.fired(ctx, state)
	state.firedAt = ctx.time
end

function Stuck.cycles(ctx, state)
	return math.floor((ctx.time - started(ctx, state)) / ctx.config.ai.stuckDelay)
end

return Stuck
