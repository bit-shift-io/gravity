local ThrusterEffect = require("src.game.components.thruster_effect")
local Config = require("src.game.config")

test("particle alpha is 1 from age 0 to hold time", function()
	local holdTime = Config.thrusterEffect.holdTime
	assertNear(1, ThrusterEffect.alpha(0, holdTime), 1e-6)
	assertNear(1, ThrusterEffect.alpha(holdTime, holdTime), 1e-6)
end)

test("particle alpha fades linearly from 1 to 0 during fade time", function()
	local holdTime = Config.thrusterEffect.holdTime
	local fadeTime = Config.thrusterEffect.fadeTime
	-- Middle of fade period should be 0.5
	assertNear(0.5, ThrusterEffect.alpha(holdTime + fadeTime / 2, holdTime, fadeTime), 1e-6)
end)

test("particle alpha is 0 after hold time plus fade time", function()
	local holdTime = Config.thrusterEffect.holdTime
	local fadeTime = Config.thrusterEffect.fadeTime
	assertNear(0, ThrusterEffect.alpha(holdTime + fadeTime, holdTime, fadeTime), 1e-6)
end)

test("particle alpha is 0 beyond hold time plus fade time", function()
	local holdTime = Config.thrusterEffect.holdTime
	local fadeTime = Config.thrusterEffect.fadeTime
	assertNear(0, ThrusterEffect.alpha(holdTime + fadeTime + 1, holdTime, fadeTime), 1e-6)
end)
