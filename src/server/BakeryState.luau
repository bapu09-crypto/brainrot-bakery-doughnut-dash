-- BakeryState: per-player state and the global brainrot instance registry.
-- No Roblox logic here beyond holding references: cash, rebirths, upgrades,
-- quests, owned brainrots and the plot each player stands on.

local State = {}

State.players = {} -- [Player] = state
State.instances = {} -- [uid] = brainrot instance
State.nextUid = 1
State.plotPlayers = { {}, {}, {}, {} } -- [plotIndex] = {Player, ...}

function State.newUid()
	local uid = State.nextUid
	State.nextUid = State.nextUid + 1
	return uid
end

-- A joining player takes the emptiest plot; a 5th+ player shares one.
function State.assignPlot(player)
	local best = 1
	for i = 1, 4 do
		if #State.plotPlayers[i] < #State.plotPlayers[best] then
			best = i
		end
	end
	table.insert(State.plotPlayers[best], player)
	return best
end

function State.unassignPlot(player)
	for i = 1, 4 do
		for j, p in ipairs(State.plotPlayers[i]) do
			if p == player then
				table.remove(State.plotPlayers[i], j)
				return
			end
		end
	end
end

function State.new(player, plotIndex)
	local state = {
		player = player,
		plotIndex = plotIndex,
		cash = 100,
		totalEarned = 0,
		rebirths = 0,
		lockUntil = 0,
		upgrades = { ovens = 0, income = 0, pedestals = 0, feet = 0 },
		quests = {},
		owned = {}, -- [uid] = instance
		pedestalMap = {}, -- [pedestalIndex] = uid
		indexOwned = {}, -- [catalogId] = true
		carriedUid = nil,
	}
	State.players[player] = state
	return state
end

function State.get(player)
	return State.players[player]
end

function State.remove(player)
	State.players[player] = nil
	State.unassignPlot(player)
end

function State.isLocked(state)
	return os.time() < state.lockUntil
end

function State.lockRemaining(state)
	local left = state.lockUntil - os.time()
	if left < 0 then
		return 0
	end
	return left
end

function State.rebirthCost(state)
	return 100000 * (2 ^ state.rebirths)
end

function State.rebirthMult(state)
	return 2 ^ state.rebirths
end

-- Pedestals start at 6; the Extra Pedestal track adds up to 2 more.
function State.pedestalCap(state)
	local cap = 6 + state.upgrades.pedestals
	if cap > 8 then
		cap = 8
	end
	return cap
end

function State.freePedestalIndex(state)
	local cap = State.pedestalCap(state)
	for i = 1, cap do
		if state.pedestalMap[i] == nil then
			return i
		end
	end
	return nil
end

-- Income per second across everything the player owns.
function State.incomePerSecond(state, goldenHour)
	local Catalog = require(script.Parent.BakeryCatalog)
	local total = 0
	for _, inst in pairs(state.owned) do
		local entry = Catalog.getById(inst.catalogId)
		local mutation = Catalog.MUTATIONS[inst.mutation]
		total = total + entry.income * mutation.mult
	end
	total = total * State.rebirthMult(state)
	total = total * (1 + 0.1 * state.upgrades.income)
	if goldenHour then
		total = total * 2
	end
	return total
end

function State.indexCount(state)
	local n = 0
	for _ in pairs(state.indexOwned) do
		n = n + 1
	end
	return n
end

-- Registers a brainrot instance the world just created (conveyor or pedestal).
function State.registerInstance(uid, catalogId, mutation, model, labelRefs)
	local inst = {
		uid = uid,
		catalogId = catalogId,
		mutation = mutation,
		model = model,
		labelRefs = labelRefs,
		owner = nil,
		location = "conveyor",
		pedestalIndex = nil,
		plotIndex = nil,
	}
	State.instances[uid] = inst
	return inst
end

function State.unregisterInstance(uid)
	State.instances[uid] = nil
end

return State
