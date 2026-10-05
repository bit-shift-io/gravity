-- Shell helpers shared by the release scripts. Plain LuaJIT only; no love.*.
local Util = {}

function Util.quote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function succeeded(ok, _, code)
	-- LuaJIT (5.1) returns the exit status as a number; 5.2+ returns true/nil, "exit", code.
	if type(ok) == "number" then return ok == 0 end
	return ok == true and (code == nil or code == 0)
end

-- Runs a shell command, echoing it first. Aborts the script on failure.
function Util.run(cmd)
	print("$ " .. cmd)
	if not succeeded(os.execute(cmd)) then
		io.stderr:write("release failed: command exited non-zero\n")
		os.exit(1)
	end
end

function Util.try(cmd)
	return succeeded(os.execute(cmd))
end

function Util.capture(cmd)
	local pipe = assert(io.popen(cmd))
	local out = pipe:read("*a")
	pipe:close()
	return (out:gsub("%s+$", ""))
end

function Util.exists(path)
	return Util.try("test -e " .. Util.quote(path))
end

-- SHA-256 of a file as lower-case hex; shasum on macOS, sha256sum on Linux.
function Util.sha256(path)
	local tool = Util.try("command -v sha256sum >/dev/null 2>&1") and "sha256sum" or "shasum -a 256"
	return (Util.capture(tool .. " " .. Util.quote(path)):match("^(%x+)"))
end

function Util.fail(message)
	io.stderr:write("release failed: " .. message .. "\n")
	os.exit(1)
end

-- Repo root, taken from the working directory; release.sh cd's there first.
function Util.root()
	return Util.capture("pwd")
end

return Util
