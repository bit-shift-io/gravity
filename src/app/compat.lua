-- Every LÖVE-11-vs-12 version-sensitive call goes through here (see
-- docs/memory/love-11-and-12-compat.md). Empty wrappers to start -- filled in
-- as later slices hit a real difference (stencils, canvas/mesh formats).
local Compat = {}

function Compat.getVersion()
	return love.getVersion()
end

function Compat.isLove12()
	local major = Compat.getVersion()
	return major >= 12
end

return Compat
