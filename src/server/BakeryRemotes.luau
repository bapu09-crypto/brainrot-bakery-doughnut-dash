-- BakeryRemotes: every wire between the game and the player's screen.
-- RemoteFunctions the client calls (catalog, upgrades, quests, lock, rebirth),
-- RemoteEvents the server pushes (state sync, toasts, threat + golden hour),
-- the buy flow off the conveyor, pedestal clicks (steal / place), and the
-- one-second money tick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local worldRef = nil
local folder = nil
local events = {}

local LOCK_COST = 250
local LOCK_SECONDS = 60

local function syncOwnQuest(state)
	local q = state.quests.own6
	if q then
		local ownedCount = 0
		for _ in pairs(state.owned) do
			ownedCount = ownedCount + 1
		end
		if ownedCount > q.progress then
			q.progress = math.min(6, ownedCount)
		end
	end
end

local function toastCompletions(player, state, completed)
	for _, def in ipairs(completed) do
		Remotes.toast(player, "QUEST COMPLETE: " .. def.text .. " - claim it in Quests!")
	end
end

function Remotes.toast(player, text)
	if events.Toast then
		events.Toast:FireClient(player, text)
	end
end

function Remotes.pushState(player)
	local State = require(script.Parent.BakeryState)
	local Catalog = require(script.Parent.BakeryCatalog)
	local Shop = require(script.Parent.BakeryShop)
	local Quests = require(script.Parent.BakeryQuests)
	local Threat = require(script.Parent.BakeryThreat)
	local state = State.get(player)
	if not state or not events.StateSync then
		return
	end
	syncOwnQuest(state)
	local income = State.incomePerSecond(state, Threat.isGoldenHour())
	local carried = nil
	if state.carriedUid then
		local inst = State.instances[state.carriedUid]
		if inst then
			local entry = Catalog.getById(inst.catalogId)
			carried = { uid = inst.uid, name = entry.name, income = entry.income }
		end
	end
	events.StateSync:FireClient(player, {
		cash = math.floor(state.cash),
		income = math.floor(income),
		rebirths = state.rebirths,
		rebirthCost = State.rebirthCost(state),
		indexCount = State.indexCount(state),
		indexTotal = Catalog.COUNT,
		indexOwned = state.indexOwned,
		lockLeft = State.lockRemaining(state),
		lockCost = LOCK_COST,
		upgrades = state.upgrades,
		upgradeCosts = {
			ovens = Shop.costOf("ovens", state.upgrades.ovens),
			income = Shop.costOf("income", state.upgrades.income),
			pedestals = Shop.costOf("pedestals", state.upgrades.pedestals),
			feet = Shop.costOf("feet", state.upgrades.feet),
		},
		quests = state.quests,
		goals = Quests.goals(state),
		carried = carried,
		walkSpeed = Shop.walkSpeed(state),
		goldenActive = Threat.isGoldenHour(),
		goldenLeft = Threat.goldenLeft,
		threatPhase = Threat.phase,
		threatLeft = Threat.phaseLeft,
		plotIndex = state.plotIndex,
	})
end

function Remotes.pushAll()
	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.pushState(player)
	end
end

-- The buy flow: a click on a belt brainrot lands here.
function Remotes.buyBrainrot(player, uid)
	local State = require(script.Parent.BakeryState)
	local Catalog = require(script.Parent.BakeryCatalog)
	local Conveyor = require(script.Parent.BakeryConveyor)
	local Quests = require(script.Parent.BakeryQuests)
	local state = State.get(player)
	if not state then
		return
	end
	local inst = State.instances[uid]
	if not inst or inst.location ~= "conveyor" then
		return
	end
	local entry = Catalog.getById(inst.catalogId)
	if state.cash < entry.price then
		Remotes.toast(player, "Not enough cash! Need " .. Catalog.formatMoney(entry.price) .. ".")
		return
	end
	local freeIndex = State.freePedestalIndex(state)
	if not freeIndex then
		Remotes.toast(player, "No free pedestal! Buy an Extra Pedestal in Upgrades.")
		return
	end
	state.cash = state.cash - entry.price
	local mutation = Catalog.rollMutation()
	local mut = Catalog.MUTATIONS[mutation]
	inst.mutation = mutation
	Conveyor.take(uid)
	local plot = worldRef.plots[state.plotIndex]
	local ped = plot.pedestals[freeIndex]
	inst.location = "pedestal"
	inst.owner = player
	inst.pedestalIndex = freeIndex
	inst.plotIndex = state.plotIndex
	inst.model:PivotTo(CFrame.new(ped.position + Vector3.new(0, 1.7, 0)))
	if mut.tint then
		inst.model.PrimaryPart.Color = mut.tint
	end
	if mutation == "Diamond" then
		inst.model.PrimaryPart.Material = Enum.Material.Neon
	end
	inst.labelRefs.nameLabel.Text = mut.prefix .. entry.name
	inst.labelRefs.priceLabel.Text = Catalog.formatMoney(entry.income * mut.mult) .. "/s"
	state.owned[uid] = inst
	state.pedestalMap[freeIndex] = uid
	state.indexOwned[entry.id] = true
	local completed = Quests.bump(state, "buy", 1)
	if Catalog.RARITIES[entry.rarity].order >= 2 then
		local more = Quests.bump(state, "rare", 1)
		for _, def in ipairs(more) do
			table.insert(completed, def)
		end
	end
	toastCompletions(player, state, completed)
	Remotes.toast(player, "Bought " .. mut.prefix .. entry.name .. " for " .. Catalog.formatMoney(entry.price) .. "!")
	Remotes.pushState(player)
end

local function doLock(player)
	local State = require(script.Parent.BakeryState)
	local Quests = require(script.Parent.BakeryQuests)
	local state = State.get(player)
	if not state then
		return false, "No state yet."
	end
	if State.isLocked(state) then
		return false, "Already locked for " .. State.lockRemaining(state) .. "s more."
	end
	if state.cash < LOCK_COST then
		return false, "Lock costs $250."
	end
	state.cash = state.cash - LOCK_COST
	state.lockUntil = os.time() + LOCK_SECONDS
	local completed = Quests.bump(state, "lock", 1)
	toastCompletions(player, state, completed)
	Remotes.pushState(player)
	return true, "Stall locked for 60s! Nobody can steal from you."
end

local function doRebirth(player)
	local State = require(script.Parent.BakeryState)
	local Quests = require(script.Parent.BakeryQuests)
	local Steal = require(script.Parent.BakerySteal)
	local state = State.get(player)
	if not state then
		return false, "No state yet."
	end
	local cost = State.rebirthCost(state)
	if state.cash < cost then
		local Catalog = require(script.Parent.BakeryCatalog)
		return false, "Need " .. Catalog.formatMoney(cost) .. " to rebirth!"
	end
	if state.carriedUid then
		Steal.dropCarried(player, "You dropped your catch to rebirth.")
	end
	for uid, inst in pairs(state.owned) do
		if inst.model then
			inst.model:Destroy()
		end
		State.unregisterInstance(uid)
	end
	state.owned = {}
	state.pedestalMap = {}
	state.cash = 0
	state.rebirths = state.rebirths + 1
	local completed = Quests.bump(state, "rebirth", 1)
	toastCompletions(player, state, completed)
	syncOwnQuest(state)
	Remotes.toast(player, "REBIRTH " .. state.rebirths .. "! Earnings x" .. (2 ^ state.rebirths) .. " forever!")
	Remotes.pushState(player)
	return true, "Reborn!"
end

function Remotes.setup(world)
	worldRef = world
	local Catalog = require(script.Parent.BakeryCatalog)
	local State = require(script.Parent.BakeryState)
	local Quests = require(script.Parent.BakeryQuests)
	local Shop = require(script.Parent.BakeryShop)
	local Steal = require(script.Parent.BakerySteal)
	local Threat = require(script.Parent.BakeryThreat)
	local Conveyor = require(script.Parent.BakeryConveyor)

	folder = Instance.new("Folder")
	folder.Name = "BakeryRemotes"
	folder.Parent = ReplicatedStorage

	local function remoteFunction(name, handler)
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.OnServerInvoke = handler
		rf.Parent = folder
		events[name] = rf
		return rf
	end

	local function remoteEvent(name)
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = folder
		events[name] = re
		return re
	end

	remoteEvent("StateSync")
	remoteEvent("Toast")
	remoteEvent("ThreatUpdate")
	remoteEvent("GoldenUpdate")
	remoteEvent("Slap")

	remoteFunction("GetCatalog", function(_player)
		return {
			brainrots = Catalog.BRAINROTS,
			rarities = Catalog.RARITIES,
			mutations = Catalog.MUTATIONS,
		}
	end)
	remoteFunction("BuyUpgrade", function(player, upgradeId)
		local state = State.get(player)
		if not state then
			return false, "No state yet."
		end
		local ok, msg = Shop.buy(state, upgradeId)
		if ok then
			Remotes.pushState(player)
		end
		return ok, msg
	end)
	remoteFunction("ClaimQuest", function(player, questId)
		local state = State.get(player)
		if not state then
			return false, "No state yet."
		end
		local ok, reward = Quests.claim(state, questId)
		if ok then
			Remotes.toast(player, "Quest claimed! +" .. Catalog.formatMoney(reward) .. "!")
			Remotes.pushState(player)
			return true, "Claimed!"
		end
		return false, reward
	end)
	remoteFunction("LockBase", function(player)
		return doLock(player)
	end)
	remoteFunction("Rebirth", function(player)
		return doRebirth(player)
	end)

	events.Slap.OnServerEvent:Connect(function(player)
		Steal.slap(player)
	end)

	-- Conveyor clicks come here.
	Conveyor.buyHandler = Remotes.buyBrainrot

	-- Pedestal clicks: place a carried brainrot, or steal someone else's.
	for _, plot in ipairs(world.plots) do
		for _, ped in ipairs(plot.pedestals) do
			ped.click.MouseClick:Connect(function(player)
				local state = State.get(player)
				if not state then
					return
				end
				if state.carriedUid then
					local ok, msg = Steal.tryPlace(player)
					Remotes.toast(player, msg)
					if ok then
						local completed = {}
						local inst = nil
						for _, owned in pairs(state.owned) do
							if owned.pedestalIndex == ped.index then
								inst = owned
							end
						end
						if inst then
							local entry = Catalog.getById(inst.catalogId)
							if Catalog.RARITIES[entry.rarity].order >= 2 then
								completed = Quests.bump(state, "rare", 1)
							end
						end
						local more = Quests.bump(state, "steal", 1)
						for _, def in ipairs(more) do
							table.insert(completed, def)
						end
						toastCompletions(player, state, completed)
					end
					Remotes.pushState(player)
					return
				end
				-- Whose brainrot sits on this pedestal?
				for _, otherState in pairs(State.players) do
					if otherState.plotIndex == plot.index then
						local uid = otherState.pedestalMap[ped.index]
						if uid then
							local ok, msg = Steal.trySteal(player, uid)
							Remotes.toast(player, msg)
							if ok then
								Remotes.pushState(player)
								Remotes.pushState(otherState.player)
							end
							return
						end
					end
				end
			end)
		end
	end

	-- Threat + Golden Hour announcements for the HUD banner.
	Threat.onThreat = function(phase, secondsLeft)
		if events.ThreatUpdate then
			events.ThreatUpdate:FireAllClients(phase, secondsLeft)
		end
	end
	Threat.onGolden = function(active, secondsLeft)
		if events.GoldenUpdate then
			events.GoldenUpdate:FireAllClients(active, secondsLeft)
		end
	end
end

-- One-second money tick for every player online.
function Remotes.startTicker()
	task.spawn(function()
		local State = require(script.Parent.BakeryState)
		local Threat = require(script.Parent.BakeryThreat)
		while true do
			task.wait(1)
			local golden = Threat.isGoldenHour()
			for _, state in pairs(State.players) do
				local income = State.incomePerSecond(state, golden)
				if income > 0 then
					state.cash = state.cash + income
					state.totalEarned = state.totalEarned + income
				end
				Remotes.pushState(state.player)
			end
		end
	end)
end

return Remotes
