-- Unit test runner: discovers and runs test files with no `love` global and
-- no LÖVE mock. Only src/core, src/sim, src/game may be exercised here (see
-- docs/ARCHITECTURE.md) -- anything touching `love.*` belongs in a higher tier.
local defaultTestFiles = {
	"tests/unit/runner_smoke_test.lua",
	"tests/unit/screen_fit_test.lua",
	"tests/unit/post_mode_test.lua",
	"tests/unit/glow_math_test.lua",
	"tests/unit/camera_test.lua",
	"tests/unit/bindings_test.lua",
	"tests/unit/menu_nav_test.lua",
	"tests/unit/audio_test.lua",
	"tests/unit/roster_test.lua",
	"tests/unit/hud_layout_test.lua",
	"tests/unit/screenshot_test.lua",
	"tests/unit/settings_codec_test.lua",
	"tests/unit/line_width_test.lua",
	"tests/unit/match_test.lua",
	"tests/unit/spawn_points_test.lua",
	"tests/unit/level_gen_test.lua",
	"tests/unit/snake_shape_test.lua",
	"tests/unit/vec2_test.lua",
	"tests/unit/angle_ease_test.lua",
	"tests/unit/rng_test.lua",
	"tests/unit/poly_test.lua",
	"tests/unit/level_test.lua",
	"tests/unit/gravity_test.lua",
	"tests/unit/gravity_pairwise_test.lua",
	"tests/unit/field_test.lua",
	"tests/unit/bodies_test.lua",
	"tests/unit/integrate_test.lua",
	"tests/unit/fuel_test.lua",
	"tests/unit/thruster_test.lua",
	"tests/unit/thruster_effect_test.lua",
	"tests/unit/particle_alpha_test.lua",
	"tests/unit/collide_test.lua",
	"tests/unit/lander_test.lua",
	"tests/unit/turret_test.lua",
	"tests/unit/tank_outline_test.lua",
	"tests/unit/crash_event_test.lua",
	"tests/unit/swept_collide_test.lua",
	"tests/unit/weapon_test.lua",
	"tests/unit/boundary_render_test.lua",
	"tests/unit/starfield_test.lua",
	"tests/unit/asteroid_shape_test.lua",
	"tests/unit/asteroid_spawn_test.lua",
	"tests/unit/blast_test.lua",
	"tests/unit/asteroid_split_test.lua",
	"tests/unit/asteroid_death_test.lua",
	"tests/unit/round_system_test.lua",
	"tests/unit/score_card_test.lua",
	"tests/unit/match_over_test.lua",
	"tests/unit/ai_basic_test.lua",
	"tests/unit/ai_personality_test.lua",
	"tests/unit/ai_trajectory_test.lua",
	"tests/unit/ai_danger_test.lua",
	"tests/unit/ai_hopper_test.lua",
	"tests/unit/ai_flight_test.lua",
	"tests/unit/ai_hunter_test.lua",
	"tests/unit/ai_vantage_test.lua",
	"tests/unit/ai_sniper_test.lua",
	"tests/unit/ai_airburst_test.lua",
	"tests/unit/ai_artillery_test.lua",
	"tests/unit/ai_chaos_test.lua",
	"tests/unit/ai_schizo_test.lua",
	"tests/unit/ai_skirmisher_test.lua",
	"tests/unit/ai_ambusher_test.lua",
	"tests/unit/ai_kamikaze_test.lua",
	"tests/unit/steam_manifest_test.lua",
	"tests/unit/steam_framing_test.lua",
	"tests/unit/steam_logo_test.lua",
	"tests/unit/steam_icon_test.lua",
	"tests/unit/steam_entry_format_test.lua",
}

require("tests.support.bake_cache")

local tests = {}
local failures = {}

local function valueToString(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function fail(message)
	error(message, 2)
end

function test(name, fn)
	table.insert(tests, {
		name = name,
		fn = fn,
	})
end

function assertTrue(value, message)
	if not value then
		fail(message or "expected value to be truthy")
	end
end

function assertFalse(value, message)
	if value then
		fail(message or "expected value to be falsey")
	end
end

function assertEqual(expected, actual, message)
	if expected ~= actual then
		fail(message or string.format("expected %s, got %s", valueToString(expected), valueToString(actual)))
	end
end

function assertNear(expected, actual, tolerance, message)
	tolerance = tolerance or 0.000001
	if math.abs(expected - actual) > tolerance then
		fail(
			message
				or string.format(
					"expected %s to be within %s of %s",
					valueToString(actual),
					valueToString(tolerance),
					valueToString(expected)
				)
		)
	end
end

local function testFilesFromArgs()
	local files = {}
	for i = 1, #arg do
		table.insert(files, arg[i])
	end

	if #files == 0 then
		return defaultTestFiles
	end

	return files
end

local function loadTestFile(path)
	local chunk, err = loadfile(path)
	if not chunk then
		error(string.format("Could not load %s: %s", path, err))
	end
	chunk()
end

local function run()
	local files = testFilesFromArgs()

	for _, file in ipairs(files) do
		loadTestFile(file)
	end

	for _, case in ipairs(tests) do
		local ok, err = xpcall(case.fn, debug.traceback)
		if ok then
			print("✓ " .. case.name)
		else
			table.insert(failures, {
				name = case.name,
				error = err,
			})
			print("✗ " .. case.name)
			print(err)
		end
	end

	local passed = #tests - #failures
	print(string.format("\n%d passed, %d failed", passed, #failures))

	if #failures > 0 then
		os.exit(1)
	end
end

run()
