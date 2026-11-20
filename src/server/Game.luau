-- Game.luau
-- ALL the server game logic in one place: player state, the conveyor,
-- buy / steal / carry / place / drop, the slap tool, lock, rebirth,
-- upgrades, quests, goals, the Burn Wave and Golden Hour clocks, the
-- remotes, and the one-second money tick. Data-driven: one table each
-- for upgrades, quests and goals.
-- Modules are loaded as siblings under the same server Script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(script.Parent.Catalog)
local World = require(script.Parent.World)

local Game = {}

local LOCK_COST = 250
local LOCK_TIME = 60
local REBIRTH_BASE = 100000
local START_CASH = 100
local BELT_SPEED = 6
local BELT_START_Z = -85
local BELT_END_Z = 85
local BELT_TOP_Y = 3.1
local SPAWN_BASE = 4
local SLAP_RANGE = 9
local SLAP_COOLDOWN = 2
local STEAL_RANGE = 14
local PLACE_RANGE = 12

local rng = Random.new()

-- Four upgrade tracks. Cost doubles per level: Base * 2^level.
local UPGRADES = {
	Ovens = { Name = "Faster Ovens", Desc = "Brainrots roll off the line faster", Max = 5, Base = 500 },
	Income = { Name = "Sweet Income", Desc = "+10% money per second per level", Max = 5, Base = 750 },
	Pedestal = { Name = "Extra Pedestal", Desc = "+1 pedestal on your stall", Max = 2, Base = 2000 },
	Speed = { Name = "Swift Feet", Desc = "+2 walk speed per level", Max = 5, Base = 400 },
}
local UPGRADE_ORDER = { "Ovens", "Income", "Pedestal", "Speed" }

-- Six quests. Progress is read off the player state (see QuestProgress).
local QUESTS = {
	{ Id = "buy3", Text = "Buy 3 brainrots", Reward = 150, Target = 3 },
	{ Id = "lock", Text = "Lock your gate", Reward = 100, Target = 1 },
	{ Id = "rare", Text = "Pen a RARE or better", Reward = 400, Target = 1 },
	{ Id = "steal", Text = "Steal a brainrot", Reward = 500, Target = 1 },
	{ Id = "rebirth", Text = "Rebirth once", Reward = 1000, Target = 1 },
	{ Id = "own6", Text = "Own 6 brainrots", Reward = 750, Target = 6 },
}

-- Six long goals, shown with progress.
local GOALS = {
	{ Id = "mythic", Text = "Own a MYTHIC", Target = 1 },
	{ Id = "secret", Text = "Own a SECRET or BOSS", Target = 1 },
	{ Id = "collect12", Text = "Collect 12 brainrots", Target = 12 },
	{ Id = "earn1m", Text = "Earn $1,000,000 total", Target = 1000000 },
	{ Id = "rebirth3", Text = "Rebirth 3 times", Target = 3 },
	{ Id = "own8", Text = "Own 8 brainrots at once", Target = 8 },
}

local RARITY_RANK = {}
for i, r in ipairs(Catalog.Rarities) do
	RARITY_RANK[r.Name] = i
end

local world = nil
local remotes = nil
local states = {}
local beltItems = {}
local startClock = 0
local lastBurnPhase = ""
local lastGoldenOn = false

-- ---------------------------------------------------------------- helpers

local function displayName(def, mutation)
	if mutation and mutation.Name ~= "" then
		return string.upper(mutation.Name) .. " " .. def.Name
	end
	return def.Name
end

local function plainMutation()
	return { Name = "", Mult = 1, Tint = nil }
end

local function walkSpeedOf(state)
	return 16 + 2 * state.Upgrades.Speed
end

local function pedestalCapOf(state)
	return 6 + state.Upgrades.Pedestal
end

local function rebirthCostOf(state)
	return REBIRTH_BASE * (2 ^ state.Rebirths)
end

local function upgradeCostOf(id, level)
	return UPGRADES[id].Base * (2 ^ level)
end

local function incomeOf(state, owned, goldenOn)
	local mult = 2 ^ state.Rebirths
	mult *= 1 + 0.1 * state.Upgrades.Income
	if goldenOn then
		mult *= 2
	end
	return owned.Income * mult
end

local function totalIncomeOf(state, goldenOn)
	local sum = 0
	for _, owned in ipairs(state.Owned) do
		sum += incomeOf(state, owned, goldenOn)
	end
	return sum
end

local function indexCountOf(state)
	local n = 0
	for _ in pairs(state.OwnedIds) do
		n += 1
	end
	return n
end

local function characterRoot(player)
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
end

local function onOwnStall(state)
	local root = characterRoot(state.Player)
	if not root or not state.Stall then
		return false
	end
	local c = state.Stall.Centre
	return math.abs(root.Position.X - c.X) <= 15 and math.abs(root.Position.Z - c.Z) <= 15
end

-- Burn Wave clock: 75s calm, 10s warning, 8s burn, repeating.
local function burnClock()
	local t = (os.clock() - startClock) % 93
	if t < 75 then
		return "Calm", 75 - t
	elseif t < 85 then
		return "Warning", 85 - t
	else
		return "Burn", 93 - t
	end
end

-- Golden Hour clock: every 180s, 30s of double pay.
local function goldenClock()
	local t = (os.clock() - startClock) % 180
	if t >= 150 then
		return true, 180 - t
	else
		return false, 150 - t
	end
end

local function questProgress(state, id)
	if id == "buy3" then
		return state.Bought
	elseif id == "lock" then
		return state.LockedEver and 1 or 0
	elseif id == "rare" then
		return state.RarePenned
	elseif id == "steal" then
		return state.Stolen
	elseif id == "rebirth" then
		return state.Rebirths
	elseif id == "own6" then
		return state.MaxOwned
	end
	return 0
end

local function goalProgress(state, id)
	if id == "mythic" then
		return state.HasMythic and 1 or 0
	elseif id == "secret" then
		return state.HasSecretBoss and 1 or 0
	elseif id == "collect12" then
		return indexCountOf(state)
	elseif id == "earn1m" then
		return math.floor(state.TotalEarned)
	elseif id == "rebirth3" then
		return state.Rebirths
	elseif id == "own8" then
		return state.MaxOwned
	end
	return 0
end

-- ---------------------------------------------------------------- state sync

local function buildPayload(state)
	local goldenOn, goldenLeft = goldenClock()
	local burnPhase, burnLeft = burnClock()
	local upgrades = {}
	for _, id in ipairs(UPGRADE_ORDER) do
		local def = UPGRADES[id]
		local level = state.Upgrades[id]
		upgrades[#upgrades + 1] = {
			Id = id,
			Name = def.Name,
			Desc = def.Desc,
			Level = level,
			Max = def.Max,
			Cost = level < def.Max and upgradeCostOf(id, level) or nil,
		}
	end
	local quests = {}
	for _, q in ipairs(QUESTS) do
		quests[#quests + 1] = {
			Id = q.Id,
			Text = q.Text,
			Reward = q.Reward,
			Progress = questProgress(state, q.Id),
			Target = q.Target,
			Claimed = state.ClaimedQuests[q.Id] == true,
		}
	end
	local goals = {}
	for _, g in ipairs(GOALS) do
		local p = goalProgress(state, g.Id)
		goals[#goals + 1] = { Text = g.Text, Progress = p, Target = g.Target, Done = p >= g.Target }
	end
	local ownedIds = {}
	for id in pairs(state.OwnedIds) do
		ownedIds[#ownedIds + 1] = id
	end
	table.sort(ownedIds)
	local carrying = nil
	if state.Carrying then
		carrying = {
			Name = displayName(state.Carrying.Def, state.Carrying.Mutation),
			Income = state.Carrying.Def.Income * state.Carrying.Mutation.Mult,
		}
	end
	return {
		Cash = math.floor(state.Cash),
		Income = math.floor(totalIncomeOf(state, goldenOn)),
		Rebirths = state.Rebirths,
		RebirthCost = rebirthCostOf(state),
		RebirthMult = 2 ^ state.Rebirths,
		IndexCount = indexCountOf(state),
		IndexTotal = #Catalog.Brainrots,
		OwnedIds = ownedIds,
		LockLeft = math.max(0, state.LockUntil - os.time()),
		LockCost = LOCK_COST,
		Upgrades = upgrades,
		Quests = quests,
		Goals = goals,
		Carrying = carrying,
		WalkSpeed = walkSpeedOf(state),
		GoldenOn = goldenOn,
		GoldenLeft = math.floor(goldenLeft),
		BurnPhase = burnPhase,
		BurnLeft = math.floor(burnLeft),
		Stall = state.Stall and state.Stall.Index or 0,
	}
end

local function sync(state)
	if state.Player and state.Player.Parent then
		remotes.StateSync:FireClient(state.Player, buildPayload(state))
	end
end

local function toast(state, message)
	if state and state.Player and state.Player.Parent then
		remotes.Toast:FireClient(state.Player, message)
	end
end

-- ---------------------------------------------------------------- stalls

local function refreshSign(plot)
	local label = plot.SignLabel
	if not label then
		return
	end
	if #plot.Owners > 0 and plot.Owners[1].Player then
		label.Text = plot.Owners[1].Player.DisplayName .. "'s STALL"
	else
		label.Text = "STALL " .. plot.Index
	end
end

local function assignStall(state)
	local best = world.Plots[1]
	for _, plot in ipairs(world.Plots) do
		if #plot.Owners < #best.Owners then
			best = plot
		end
	end
	state.Stall = best
	table.insert(best.Owners, state)
	refreshSign(best)
end

local function freePedestal(state)
	if not state.Stall then
		return nil
	end
	local cap = pedestalCapOf(state)
	for _, ped in ipairs(state.Stall.Pedestals) do
		if ped.Occupant == nil and ped.Index <= cap then
			return ped
		end
	end
	return nil
end

local function freePedestalFor(ownerState)
	local cap = pedestalCapOf(ownerState)
	for _, ped in ipairs(ownerState.Stall.Pedestals) do
		if ped.Occupant == nil and ped.Index <= cap then
			return ped
		end
	end
	return nil
end

-- ---------------------------------------------------------------- pen / unpen

-- Put a brainrot on a pedestal as owned by this player. Creates its model fresh.
local function penBrainrot(state, def, mutation, pedestal)
	local income = def.Income * mutation.Mult
	local name = displayName(def, mutation)
	local rarity = Catalog.GetRarity(def.Rarity)
	local model = World.BuildBrainrot(def, mutation, rarity.Color, name, Catalog.FormatMoney(income) .. "/s")
	model:PivotTo(CFrame.new(pedestal.StandPos))
	model.Parent = world.Folder
	local defId = nil
	for i, b in ipairs(Catalog.Brainrots) do
		if b == def then
			defId = i
			break
		end
	end
	local owned = {
		Def = def,
		DefId = defId,
		Mutation = mutation,
		Income = income,
		Model = model,
		Pedestal = pedestal,
		Owner = state,
	}
	pedestal.Occupant = owned
	table.insert(state.Owned, owned)
	state.OwnedIds[defId] = true
	if RARITY_RANK[def.Rarity] >= 2 then
		state.RarePenned += 1
	end
	if def.Rarity == "Mythic" then
		state.HasMythic = true
	end
	if def.Rarity == "Secret" or def.Rarity == "Boss" then
		state.HasSecretBoss = true
	end
	if #state.Owned > state.MaxOwned then
		state.MaxOwned = #state.Owned
	end
	return owned
end

local function removeOwned(state, owned)
	for i, o in ipairs(state.Owned) do
		if o == owned then
			table.remove(state.Owned, i)
			break
		end
	end
	if owned.Pedestal then
		owned.Pedestal.Occupant = nil
	end
	if owned.Model then
		owned.Model:Destroy()
	end
end

-- The carried brainrot goes back to its original owner's stall if they
-- have a free pedestal, otherwise it is lost forever.
local function dropCarried(state)
	local carried = state.Carrying
	if not carried then
		return
	end
	state.Carrying = nil
	if carried.Model then
		carried.Model:Destroy()
	end
	local ownerState = carried.FromOwner
	if ownerState and ownerState.Player and ownerState.Player.Parent then
		local ped = freePedestalFor(ownerState)
		if ped then
			penBrainrot(ownerState, carried.Def, carried.Mutation, ped)
			toast(ownerState, "Your " .. displayName(carried.Def, carried.Mutation) .. " was returned!")
			sync(ownerState)
			return
		end
	end
	toast(state, displayName(carried.Def, carried.Mutation) .. " was lost forever!")
	if ownerState then
		toast(ownerState, "Your " .. displayName(carried.Def, carried.Mutation) .. " was lost forever!")
	end
end

-- ---------------------------------------------------------------- conveyor

local function spawnBeltBrainrot()
	local def = Catalog.PickWeighted(rng)
	local rarity = Catalog.GetRarity(def.Rarity)
	local model = World.BuildBrainrot(def, plainMutation(), rarity.Color, def.Name, Catalog.FormatMoney(def.Price))
	model:PivotTo(CFrame.new(0, BELT_TOP_Y, BELT_START_Z))
	model.Parent = world.Folder
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 32
	click.Parent = model.PrimaryPart
	local item = { Def = def, Model = model, Z = BELT_START_Z }
	click.MouseClick:Connect(function(player)
		Game.TryBuy(player, item)
	end)
	table.insert(beltItems, item)
end

function Game.TryBuy(player, item)
	local state = states[player]
	if not state then
		return
	end
	-- The item may already have been bought or binned.
	local found = false
	for _, it in ipairs(beltItems) do
		if it == item then
			found = true
			break
		end
	end
	if not found then
		return
	end
	local def = item.Def
	if state.Cash < def.Price then
		toast(state, "You need " .. Catalog.FormatMoney(def.Price) .. " for " .. def.Name .. "!")
		return
	end
	local ped = freePedestal(state)
	if not ped then
		toast(state, "No free pedestal! Buy Extra Pedestal or sell space.")
		return
	end
	for i, it in ipairs(beltItems) do
		if it == item then
			table.remove(beltItems, i)
			break
		end
	end
	if item.Model then
		item.Model:Destroy()
	end
	state.Cash -= def.Price
	state.Bought += 1
	local mutation = Catalog.RollMutation(rng)
	penBrainrot(state, def, mutation, ped)
	local name = displayName(def, mutation)
	toast(state, "Bought " .. name .. " for " .. Catalog.FormatMoney(def.Price) .. "!")
	sync(state)
end

-- ---------------------------------------------------------------- pedestals

local function onPedestalClick(player, pedestal)
	local state = states[player]
	if not state then
		return
	end
	local root = characterRoot(player)
	if not root then
		return
	end
	if state.Carrying then
		-- Place the carried brainrot on one of your own free pedestals.
		if pedestal.Plot ~= state.Stall then
			toast(state, "That is not your stall! Place it on YOUR pedestal.")
			return
		end
		if pedestal.Occupant then
			toast(state, "That pedestal is taken!")
			return
		end
		if pedestal.Index > pedestalCapOf(state) then
			toast(state, "That pedestal is locked! Buy Extra Pedestal.")
			return
		end
		if (root.Position - pedestal.Top.Position).Magnitude > PLACE_RANGE then
			toast(state, "Move closer to place it!")
			return
		end
		local carried = state.Carrying
		state.Carrying = nil
		if carried.Model then
			carried.Model:Destroy()
		end
		penBrainrot(state, carried.Def, carried.Mutation, pedestal)
		toast(state, "Placed " .. displayName(carried.Def, carried.Mutation) .. " on your stall!")
		sync(state)
		return
	end
	local occ = pedestal.Occupant
	if not occ then
		return
	end
	local ownerState = occ.Owner
	if ownerState == state then
		toast(state, "That brainrot is already yours!")
		return
	end
	if os.time() < ownerState.LockUntil then
		toast(state, "That stall is locked!")
		return
	end
	if (root.Position - pedestal.Top.Position).Magnitude > STEAL_RANGE then
		toast(state, "Move closer to steal it!")
		return
	end
	-- Steal it: it floats above your head until you place or drop it.
	local def = occ.Def
	local mutation = occ.Mutation
	removeOwned(ownerState, occ)
	sync(ownerState)
	local name = displayName(def, mutation)
	local rarity = Catalog.GetRarity(def.Rarity)
	local model = World.BuildBrainrot(def, mutation, rarity.Color, name, Catalog.FormatMoney(def.Income * mutation.Mult) .. "/s")
	model.Parent = world.Folder
	state.Carrying = { Def = def, Mutation = mutation, Model = model, FromOwner = ownerState }
	state.Stolen += 1
	toast(state, "You stole " .. name .. "! Get it to your stall!")
	toast(ownerState, player.DisplayName .. " stole your " .. name .. "!")
	sync(state)
end

-- ---------------------------------------------------------------- slap tool

local function givePin(player)
	task.spawn(function()
		local backpack = player:WaitForChild("Backpack")
		local tool = Instance.new("Tool")
		tool.Name = "Rolling Pin"
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.8, 0.8, 3)
		handle.Color = Color3.fromRGB(180, 130, 70)
		handle.Material = Enum.Material.Wood
		handle.Parent = tool
		tool.Parent = backpack
	end)
end

local function onSlap(player)
	local state = states[player]
	if not state then
		return
	end
	local now = os.clock()
	if now - state.SlapAt < SLAP_COOLDOWN then
		return
	end
	state.SlapAt = now
	local root = characterRoot(player)
	if not root then
		return
	end
	local look = root.CFrame.LookVector
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherRoot = characterRoot(other)
			if otherRoot then
				local delta = otherRoot.Position - root.Position
				local dist = delta.Magnitude
				if dist <= SLAP_RANGE and dist > 0.01 then
					local dir = delta / dist
					if dir:Dot(look) > 0.3 then
						otherRoot.AssemblyLinearVelocity = dir * 35 + Vector3.new(0, 25, 0)
						local otherState = states[other]
						if otherState and otherState.Carrying then
							dropCarried(otherState)
							toast(otherState, "You were slapped and dropped your catch!")
						end
						toast(state, "You slapped " .. other.DisplayName .. "!")
						break
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- players

local function applySpeed(player, state)
	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = walkSpeedOf(state)
	end
end

local function onPlayerAdded(player)
	local state = {
		Player = player,
		Cash = START_CASH,
		TotalEarned = 0,
		Rebirths = 0,
		Upgrades = { Ovens = 0, Income = 0, Pedestal = 0, Speed = 0 },
		Owned = {},
		OwnedIds = {},
		Bought = 0,
		Stolen = 0,
		RarePenned = 0,
		HasMythic = false,
		HasSecretBoss = false,
		MaxOwned = 0,
		LockedEver = false,
		LockUntil = 0,
		Carrying = nil,
		Stall = nil,
		SlapAt = 0,
		ClaimedQuests = {},
	}
	states[player] = state
	assignStall(state)
	player.CharacterAdded:Connect(function()
		givePin(player)
		task.wait(0.5)
		applySpeed(player, state)
		sync(state)
	end)
	if player.Character then
		givePin(player)
		applySpeed(player, state)
	end
	sync(state)
end

local function onPlayerRemoving(player)
	local state = states[player]
	if not state then
		return
	end
	if state.Carrying then
		dropCarried(state)
	end
	for i = #state.Owned, 1, -1 do
		removeOwned(state, state.Owned[i])
	end
	if state.Stall then
		for i, s in ipairs(state.Stall.Owners) do
			if s == state then
				table.remove(state.Stall.Owners, i)
				break
			end
		end
		refreshSign(state.Stall)
	end
	states[player] = nil
end

-- ---------------------------------------------------------------- remotes

local function setupRemotes()
	local folder = Instance.new("Folder")
	folder.Name = "BakeryRemotes"
	folder.Parent = ReplicatedStorage
	local function event(name)
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
		return e
	end
	local function func(name)
		local f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = folder
		return f
	end
	remotes = {
		StateSync = event("StateSync"),
		Toast = event("Toast"),
		ThreatUpdate = event("ThreatUpdate"),
		GoldenUpdate = event("GoldenUpdate"),
		Slap = event("Slap"),
		GetCatalog = func("GetCatalog"),
		BuyUpgrade = func("BuyUpgrade"),
		ClaimQuest = func("ClaimQuest"),
		LockBase = func("LockBase"),
		Rebirth = func("Rebirth"),
	}

	remotes.Slap.OnServerEvent:Connect(onSlap)

	remotes.GetCatalog.OnServerInvoke = function(_player)
		return { Brainrots = Catalog.Brainrots, Rarities = Catalog.Rarities, Mutations = Catalog.Mutations }
	end

	remotes.BuyUpgrade.OnServerInvoke = function(player, id)
		local state = states[player]
		if not state then
			return false, "No state."
		end
		local def = UPGRADES[id]
		if not def then
			return false, "Unknown upgrade."
		end
		local level = state.Upgrades[id]
		if level >= def.Max then
			return false, def.Name .. " is MAXED."
		end
		local cost = upgradeCostOf(id, level)
		if state.Cash < cost then
			return false, "You need " .. Catalog.FormatMoney(cost) .. "!"
		end
		state.Cash -= cost
		state.Upgrades[id] = level + 1
		if id == "Speed" then
			applySpeed(player, state)
		end
		sync(state)
		return true, def.Name .. " is now Lv " .. (level + 1) .. "!"
	end

	remotes.ClaimQuest.OnServerInvoke = function(player, id)
		local state = states[player]
		if not state then
			return false, "No state."
		end
		local quest = nil
		for _, q in ipairs(QUESTS) do
			if q.Id == id then
				quest = q
				break
			end
		end
		if not quest then
			return false, "Unknown quest."
		end
		if state.ClaimedQuests[id] then
			return false, "Already claimed."
		end
		if questProgress(state, id) < quest.Target then
			return false, "Not complete yet."
		end
		state.ClaimedQuests[id] = true
		state.Cash += quest.Reward
		sync(state)
		return true, "Quest complete! +" .. Catalog.FormatMoney(quest.Reward)
	end

	remotes.LockBase.OnServerInvoke = function(player)
		local state = states[player]
		if not state then
			return false, "No state."
		end
		if state.Cash < LOCK_COST then
			return false, "You need " .. Catalog.FormatMoney(LOCK_COST) .. " to lock!"
		end
		state.Cash -= LOCK_COST
		state.LockUntil = os.time() + LOCK_TIME
		state.LockedEver = true
		sync(state)
		return true, "Stall locked for 60 seconds!"
	end

	remotes.Rebirth.OnServerInvoke = function(player)
		local state = states[player]
		if not state then
			return false, "No state."
		end
		local cost = rebirthCostOf(state)
		if state.Cash < cost then
			return false, "You need " .. Catalog.FormatMoney(cost) .. " to rebirth!"
		end
		if state.Carrying then
			dropCarried(state)
		end
		for i = #state.Owned, 1, -1 do
			removeOwned(state, state.Owned[i])
		end
		state.Cash = 0
		state.Rebirths += 1
		sync(state)
		return true, "Rebirth " .. state.Rebirths .. "! All earnings x" .. (2 ^ state.Rebirths) .. " forever!"
	end
end

-- ---------------------------------------------------------------- loops

local function startLoops()
	-- Spawn brainrots on the belt.
	task.spawn(function()
		while true do
			local bestOvens = 0
			for _, state in pairs(states) do
				if state.Upgrades.Ovens > bestOvens then
					bestOvens = state.Upgrades.Ovens
				end
			end
			local waitTime = math.max(1.8, SPAWN_BASE - 0.3 * bestOvens)
			task.wait(waitTime)
			if #beltItems < 12 then
				spawnBeltBrainrot()
			end
		end
	end)

	-- Move the belt, float carried brainrots above their carrier's head.
	task.spawn(function()
		while true do
			task.wait(0.1)
			for i = #beltItems, 1, -1 do
				local item = beltItems[i]
				item.Z += BELT_SPEED * 0.1
				if item.Z > BELT_END_Z then
					if item.Model then
						item.Model:Destroy()
					end
					table.remove(beltItems, i)
				elseif item.Model then
					item.Model:PivotTo(CFrame.new(0, BELT_TOP_Y, item.Z))
				end
			end
			for _, state in pairs(states) do
				if state.Carrying and state.Carrying.Model then
					local root = characterRoot(state.Player)
					if root then
						state.Carrying.Model:PivotTo(CFrame.new(root.Position + Vector3.new(0, 4.5, 0)))
					end
				end
			end
		end
	end)

	-- One-second tick: pay income, run the event clocks, sync everyone.
	task.spawn(function()
		while true do
			task.wait(1)
			local goldenOn, goldenLeft = goldenClock()
			local burnPhase, burnLeft = burnClock()
			if burnPhase ~= lastBurnPhase then
				lastBurnPhase = burnPhase
				for _, state in pairs(states) do
					remotes.ThreatUpdate:FireClient(state.Player, burnPhase, math.floor(burnLeft))
				end
			end
			if goldenOn ~= lastGoldenOn then
				lastGoldenOn = goldenOn
				for _, state in pairs(states) do
					remotes.GoldenUpdate:FireClient(state.Player, goldenOn, math.floor(goldenLeft))
				end
			end
			-- Burn Wave ring: hidden when calm, small and glowing in warning,
			-- growing over the plaza during the burn.
			local ring = world.BurnRing
			if burnPhase == "Calm" then
				ring.Transparency = 1
			elseif burnPhase == "Warning" then
				ring.Transparency = 0.7
				ring.Size = Vector3.new(0.3, 10, 10)
			else
				local t = (os.clock() - startClock) % 93
				local grown = 10 + (t - 85) / 8 * 80
				ring.Transparency = 0.5
				ring.Size = Vector3.new(0.3, grown, grown)
			end
			for _, state in pairs(states) do
				local income = totalIncomeOf(state, goldenOn)
				if income > 0 then
					state.Cash += income
					state.TotalEarned += income
				end
				if burnPhase == "Burn" and state.Carrying and not onOwnStall(state) then
					dropCarried(state)
					toast(state, "The Burn Wave caught you! You dropped your catch!")
				end
				sync(state)
			end
		end
	end)
end

-- ---------------------------------------------------------------- start

function Game.Start(builtWorld)
	world = builtWorld
	startClock = os.clock()
	setupRemotes()
	for _, plot in ipairs(world.Plots) do
		for _, ped in ipairs(plot.Pedestals) do
			ped.Click.MouseClick:Connect(function(player)
				onPedestalClick(player, ped)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	startLoops()
end

return Game
