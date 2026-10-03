-- Stack of app states. Only the top state updates and receives input; a state
-- with `overlay = true` (pause) is drawn on top of the state beneath it.
-- A state is a table with optional methods onEnter(), onLeave(), update(dt), draw(), keypressed(key),
-- gamepadpressed(joystick, button), gamepadaxis(joystick, axis, value),
-- textinput(text), joystickadded(joystick), joystickremoved(joystick). Later
-- screens (setup: Title -> Setup -> Match) just push/replace states.
local StateStack = {}
StateStack.__index = StateStack

function StateStack.new()
	return setmetatable({ states = {} }, StateStack)
end

function StateStack:top()
	return self.states[#self.states]
end

function StateStack:push(state)
	self.states[#self.states + 1] = state
	if state.onEnter then
		state:onEnter()
	end
	return state
end

function StateStack:pop()
	local state = table.remove(self.states)
	if state and state.onLeave then
		state:onLeave()
	end
	return state
end

-- Swaps the top state for `state`.
function StateStack:replace(state)
	self:pop()
	return self:push(state)
end

-- Discards every state, then makes `state` the only one.
function StateStack:reset(state)
	while #self.states > 0 do
		self:pop()
	end
	return self:push(state)
end

local function forward(name)
	StateStack[name] = function(self, ...)
		local state = self:top()
		if state and state[name] then
			return state[name](state, ...)
		end
	end
end

forward("update")
forward("keypressed")
forward("gamepadpressed")
forward("gamepadaxis")
forward("textinput")
forward("joystickadded")
forward("joystickremoved")

function StateStack:draw()
	local first = #self.states
	while first > 1 and self.states[first].overlay do
		first = first - 1
	end
	for i = first, #self.states do
		local state = self.states[i]
		if state.draw then
			state:draw()
		end
	end
end

return StateStack
