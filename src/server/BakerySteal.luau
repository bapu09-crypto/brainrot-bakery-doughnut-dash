-- BakerySteal: steal, carry, place, drop, and the Rolling Pin slap tool.
-- A stolen brainrot rides over the thief's head (repositioned every frame) until
-- it is placed on the thief's own stall or dropped. Dropping returns it to its
-- original owner's stall when a pedestal is free, else it is lost.
--
-- SLAP FIX (kept from v5): the Rolling Pin is a plain Tool with only a wooden
-- Handle. No LocalScript is created at runtime and nothing writes .Source --
-- a game server cannot write a script's Source at runtime (it needs the
-- PluginOrOpenCloud capability, which a live game does not have), and the v4
-- threw on every spawn because of exactly that. The client script hooks the
-- tool's Activated event to the Slap remote instead, so the slap is driven
-- from the client and this module only needs to hand out the tool.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Steal = {}

local STEAL_RANGE = 14
local PLACE_RANGE = 12
local SLAP_RANGE = 9
local SLAP_COOLDOWN = 2

local slapCooldowns = {} -- [Player] = os.clock() of last slap
local carryFollow = false

local function characterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function distanceTo(player, position)
	local root = characterRoot(player)
	if not root then
		return 1e9
	end
	return (root.Position - position).Magnitude
end

-- Repositions every carried brainrot above its carrier's head, every frame.
local function startCarryFollow()
	if carryFollow then
		return
	end
	carryFollow = true
	RunService.Heartbeat:Connect(function()
		local State = require(script.Parent.BakeryState)
		for _, state in pairs(State.players) do
			if state.carriedUid then
				local inst = State.instances[state.carriedUid]
				local root = characterRoot(state.player)
				if inst and inst.model and inst.model.Parent and root then
					inst.model:PivotTo(CFrame.new(root.Position + Vector3.new(0, 4.5, 0)))
				end
			end
		end
	end)
end

function Steal.trySteal(player, targetUid)
	local State = require(script.Parent.BakeryState)
	local state = State.get(player)
	if not state then
		return false, "No state yet."
	end
	if state.carriedUid then
		return false, "You are already carrying a brainrot!"
	end
	local target = State.instances[targetUid]
	if not target or target.location ~= "pedestal" then
		return false, "That brainrot is gone."
	end
	if target.owner == player then
		return false, "That one is already yours."
	end
	local ownerState = State.get(target.owner)
	if ownerState and State.isLocked(ownerState) then
		return false, "That stall is locked!"
	end
	local model = target.model
	if not model or not model.Parent then
		return false, "That brainrot is gone."
	end
	local primary = model.PrimaryPart
	if not primary then
		return false, "That brainrot is gone."
	end
	if distanceTo(player, primary.Position) > STEAL_RANGE then
		return false, "Get closer to steal it!"
	end
	-- Lift it off the owner's pedestal.
	if ownerState then
		ownerState.owned[targetUid] = nil
		ownerState.pedestalMap[target.pedestalIndex] = nil
	end
	target.location = "carried"
	target.pedestalIndex = nil
	state.carriedUid = targetUid
	startCarryFollow()
	return true, "Stolen! Dash it home to your stall!"
end

function Steal.tryPlace(player)
	local State = require(script.Parent.BakeryState)
	local state = State.get(player)
	if not state then
		return false, "No state yet."
	end
	if not state.carriedUid then
		return false, "You are not carrying anything."
	end
	local inst = State.instances[state.carriedUid]
	if not inst then
		state.carriedUid = nil
		return false, "Your catch is gone."
	end
	local root = characterRoot(player)
	if not root then
		return false, "No character."
	end
	local Catalog = require(script.Parent.BakeryCatalog)
	local World = require(script.Parent.BakeryWorld)
	-- Nearest free pedestal on the player's own plot, within reach.
	local plot = nil
	for _, p in ipairs(World.getPlots()) do
		if p.index == state.plotIndex then
			plot = p
		end
	end
	if not plot then
		return false, "No stall."
	end
	local cap = State.pedestalCap(state)
	local bestIndex = nil
	local bestDist = PLACE_RANGE
	local anyFree = false
	for i = 1, cap do
		if state.pedestalMap[i] == nil then
			anyFree = true
			local ped = plot.pedestals[i]
			local d = (root.Position - ped.position).Magnitude
			if d < bestDist then
				bestDist = d
				bestIndex = i
			end
		end
	end
	if not bestIndex then
		if anyFree then
			return false, "Get closer to a free pedestal on your stall to place it!"
		end
		return false, "No free pedestal on your stall!"
	end
	local ped = plot.pedestals[bestIndex]
	inst.location = "pedestal"
	inst.owner = player
	inst.pedestalIndex = bestIndex
	inst.plotIndex = state.plotIndex
	inst.model:PivotTo(CFrame.new(ped.position + Vector3.new(0, 1.7, 0)))
	state.owned[inst.uid] = inst
	state.pedestalMap[bestIndex] = inst.uid
	state.indexOwned[inst.catalogId] = true
	state.carriedUid = nil
	local entry = Catalog.getById(inst.catalogId)
	return true, "Placed " .. entry.name .. " on your stall!"
end

function Steal.dropCarried(player, reason)
	local State = require(script.Parent.BakeryState)
	local state = State.get(player)
	if not state or not state.carriedUid then
		return false
	end
	local inst = State.instances[state.carriedUid]
	state.carriedUid = nil
	if not inst then
		return false
	end
	-- Back to its original owner's stall when a pedestal is free.
	local ownerState = inst.owner and State.get(inst.owner) or nil
	local placed = false
	if ownerState then
		local freeIndex = State.freePedestalIndex(ownerState)
		if freeIndex then
			local World = require(script.Parent.BakeryWorld)
			local plot = nil
			for _, p in ipairs(World.getPlots()) do
				if p.index == ownerState.plotIndex then
					plot = p
				end
			end
			if plot then
				local ped = plot.pedestals[freeIndex]
				inst.location = "pedestal"
				inst.pedestalIndex = freeIndex
				inst.plotIndex = ownerState.plotIndex
				inst.model:PivotTo(CFrame.new(ped.position + Vector3.new(0, 1.7, 0)))
				ownerState.owned[inst.uid] = inst
				ownerState.pedestalMap[freeIndex] = inst.uid
				placed = true
			end
		end
	end
	if not placed then
		if inst.model then
			inst.model:Destroy()
		end
		State.unregisterInstance(inst.uid)
	end
	local Remotes = require(script.Parent.BakeryRemotes)
	Remotes.toast(player, reason or "You dropped your catch!")
	return true
end

-- The Rolling Pin: knocks a nearby player back and makes them drop a catch.
function Steal.slap(player)
	local now = os.clock()
	if slapCooldowns[player] and now - slapCooldowns[player] < SLAP_COOLDOWN then
		return
	end
	slapCooldowns[player] = now
	local root = characterRoot(player)
	if not root then
		return
	end
	local forward = root.CFrame.LookVector
	local best = nil
	local bestScore = 0.5
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherRoot = characterRoot(other)
			if otherRoot then
				local delta = otherRoot.Position - root.Position
				local dist = delta.Magnitude
				if dist <= SLAP_RANGE and dist > 0.01 then
					local facing = delta.Unit:Dot(forward)
					if facing > bestScore then
						bestScore = facing
						best = other
					end
				end
			end
		end
	end
	if best then
		local otherRoot = characterRoot(best)
		if otherRoot then
			local dir = (otherRoot.Position - root.Position).Unit
			otherRoot.AssemblyLinearVelocity = dir * 42 + Vector3.new(0, 18, 0)
			local State = require(script.Parent.BakeryState)
			local otherState = State.get(best)
			if otherState and otherState.carriedUid then
				Steal.dropCarried(best, "SLAPPED! You dropped your catch!")
			end
		end
	end
end

-- Hands the player their Rolling Pin tool. It is a plain Tool with only a
-- wooden Handle -- NO script lives inside it. The client script (Game.client)
-- connects the tool's Activated event to the Slap remote, so clicking with
-- the pin equipped fires the slap. Nothing here creates a Script or
-- LocalScript, and nothing here writes .Source: a game server cannot write
-- a script's Source at runtime, and the v4 threw on every spawn for it.
function Steal.giveSlapTool(player)
	local backpack = player:WaitForChild("Backpack")
	if backpack:FindFirstChild("Rolling Pin") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Rolling Pin"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.7, 0.7, 3.2)
	handle.Color = Color3.fromRGB(170, 120, 70)
	handle.Material = Enum.Material.Wood
	handle.Anchored = false
	handle.CanCollide = false
	handle.Parent = tool
	tool.Parent = backpack
end

return Steal
