local MatchOver = require("src.app.render.match_over")

test("match-over title names the winner and the prompt names the rematch keys", function()
	assertEqual("P1 WINS THE MATCH", MatchOver.title(1))
	assertEqual("P2 WINS THE MATCH", MatchOver.title(2))
	assertEqual("PRESS ENTER FOR A REMATCH", MatchOver.prompt())
end)
