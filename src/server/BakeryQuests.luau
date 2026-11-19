-- BakeryQuests: the contracts board and the goals ladder.
-- Quests pay cash when claimed; goals are the long ladder the HUD shows with
-- progress. Both are pure tables over the player's state.

local Quests = {}

Quests.DEFINITIONS = {
	{ id = "buy3", text = "Buy 3 brainrots", kind = "buy", target = 3, reward = 150 },
	{ id = "lock1", text = "Lock your gate", kind = "lock", target = 1, reward = 100 },
	{ id = "rare1", text = "Pen a RARE or better", kind = "rare", target = 1, reward = 400 },
	{ id = "steal1", text = "Steal a brainrot", kind = "steal", target = 1, reward = 500 },
	{ id = "rebirth1", text = "Rebirth once", kind = "rebirth", target = 1, reward = 1000 },
	{ id = "own6", text = "Own 6 brainrots", kind = "own", target = 6, reward = 750 },
}

function Quests.initState(state)
	for _, def in ipairs(Quests.DEFINITIONS) do
		state.quests[def.id] = { progress = 0, claimed = false }
	end
end

-- Advances every quest of this kind; returns the quests that just completed.
function Quests.bump(state, kind, amount)
	amount = amount or 1
	local completed = {}
	for _, def in ipairs(Quests.DEFINITIONS) do
		if def.kind == kind then
			local q = state.quests[def.id]
			if q and not q.claimed then
				local before = q.progress
				q.progress = math.min(def.target, q.progress + amount)
				if before < def.target and q.progress >= def.target then
					table.insert(completed, def)
				end
			end
		end
	end
	return completed
end

function Quests.claim(state, questId)
	local def = nil
	for _, d in ipairs(Quests.DEFINITIONS) do
		if d.id == questId then
			def = d
			break
		end
	end
	if not def then
		return false, "No such quest."
	end
	local q = state.quests[questId]
	if not q then
		return false, "No such quest."
	end
	if q.claimed then
		return false, "Already claimed."
	end
	if q.progress < def.target then
		return false, "Not finished yet."
	end
	q.claimed = true
	state.cash = state.cash + def.reward
	return true, def.reward
end

-- The goals ladder, computed fresh from the player's state for the HUD.
function Quests.goals(state)
	local Catalog = require(script.Parent.BakeryCatalog)
	local State = require(script.Parent.BakeryState)
	local hasMythic = false
	local hasSecret = false
	for id in pairs(state.indexOwned) do
		local entry = Catalog.getById(id)
		if entry and entry.rarity == "Mythic" then
			hasMythic = true
		end
		if entry and (entry.rarity == "Secret" or entry.rarity == "Boss") then
			hasSecret = true
		end
	end
	local ownedCount = 0
	for _ in pairs(state.owned) do
		ownedCount = ownedCount + 1
	end
	return {
		{ text = "Own a MYTHIC", progress = hasMythic and 1 or 0, target = 1 },
		{ text = "Own a SECRET or BOSS", progress = hasSecret and 1 or 0, target = 1 },
		{ text = "Collect 12 brainrots", progress = math.min(State.indexCount(state), 12), target = 12 },
		{ text = "Earn $1,000,000 total", progress = math.min(math.floor(state.totalEarned), 1000000), target = 1000000 },
		{ text = "Rebirth 3 times", progress = math.min(state.rebirths, 3), target = 3 },
		{ text = "Own 8 brainrots at once", progress = math.min(ownedCount, 8), target = 8 },
	}
end

return Quests
