local ScoreCard = require("src.app.render.score_card")

test("result text names the winner or a draw", function()
	assertEqual("P1 WINS", ScoreCard.resultText({ winner = 1 }))
	assertEqual("P2 WINS", ScoreCard.resultText({ winner = 2 }))
	assertEqual("DRAW", ScoreCard.resultText({ draw = true }))
end)

test("pips are filled for each win and empty for the rest", function()
	local pips = ScoreCard.pips(1, 3)
	assertEqual(3, #pips)
	assertTrue(pips[1])
	assertFalse(pips[2])
	assertFalse(pips[3])
end)

test("six slot groups still fit the screen width", function()
	local span = 70 + 64
	local gap = ScoreCard.groupGap(6, span)
	assertTrue(gap > 0)
	assertTrue(6 * span + 5 * gap <= 1280 - 80 + 0.001)
	assertEqual(80, ScoreCard.groupGap(2, span))
end)
