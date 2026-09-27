-- Draws each world in the level as a closed white outline. Reads level data
-- only, never mutates it (docs/ARCHITECTURE.md "Rendering"). Worlds can be
-- concave (docs/CONTEXT.md "World"), so this draws an explicit closed
-- polyline via love.graphics.line rather than love.graphics.polygon, which
-- would need triangulation it doesn't need for an outline.
local WorldsRender = {}

function WorldsRender.draw(level)
	love.graphics.setColor(1, 1, 1, 1)

	for _, world in ipairs(level.worlds) do
		local vertices = world.vertices
		local points = {}

		for _, v in ipairs(vertices) do
			table.insert(points, v.x)
			table.insert(points, v.y)
		end

		-- Close the loop back to the first vertex so the outline reads as a
		-- closed shape rather than an open polyline.
		table.insert(points, vertices[1].x)
		table.insert(points, vertices[1].y)

		love.graphics.line(points)
	end
end

return WorldsRender
