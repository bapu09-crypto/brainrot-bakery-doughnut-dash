-- BakeryConveyor: the oven line. Brainrots roll out of the oven, ride the belt
-- from -Z to +Z, and either get bought (ClickDetector) or fall in the end bin.
-- Spawn pace quickens when any online player upgraded their ovens.

local RunService = game:GetService("RunService")

local Conveyor = {}

Conveyor.active = {} -- [uid] = instance, location == "conveyor"
Conveyor.speed = 6 -- studs per second along the belt
Conveyor.baseInterval = 4
Conveyor.buyHandler = nil -- set by BakeryRemotes: function(player, uid)

local worldRef = nil
local running = false

local function spawnInterval()
	local best = 0
	for _, state in pairs(require(script.Parent.BakeryState).players) do
		if state.upgrades.ovens > best then
			best = state.upgrades.ovens
		end
	end
	local interval = Conveyor.baseInterval - 0.3 * best
	if interval < 1.8 then
		interval = 1.8
	end
	return interval
end

local function spawnOne()
	local Catalog = require(script.Parent.BakeryCatalog)
	local State = require(script.Parent.BakeryState)
	local World = require(script.Parent.BakeryWorld)
	local entry = Catalog.pickRandom()
	local uid = State.newUid()
	local model = World.buildBrainrotModel(entry, "None")
	local labelRefs = World.makeBrainrotLabel(model, model.PrimaryPart, entry, "None",
		Catalog.formatMoney(entry.income) .. "/s  -  " .. Catalog.formatMoney(entry.price))
	model.Parent = worldRef.folder
	model:PivotTo(CFrame.new(0, worldRef.conveyor.beltTopY + 1.7, worldRef.conveyor.fromZ))
	local inst = State.registerInstance(uid, entry.id, "None", model, labelRefs)
	inst.z = worldRef.conveyor.fromZ
	inst.entry = entry
	Conveyor.active[uid] = inst
	local click = model.PrimaryPart:FindFirstChild("BrainrotClick")
	if click then
		click.MouseClick:Connect(function(player)
			if Conveyor.buyHandler then
				Conveyor.buyHandler(player, uid)
			end
		end)
	end
end

function Conveyor.start(world)
	worldRef = world
	if running then
		return
	end
	running = true
	-- Spawn loop.
	task.spawn(function()
		while running do
			task.wait(spawnInterval())
			spawnOne()
		end
	end)
	-- Movement loop.
	RunService.Heartbeat:Connect(function(dt)
		local toRemove = {}
		for uid, inst in pairs(Conveyor.active) do
			if inst.model.Parent == nil then
				table.insert(toRemove, uid)
			else
				inst.z = inst.z + Conveyor.speed * dt
				if inst.z >= worldRef.conveyor.toZ then
					table.insert(toRemove, uid)
				else
					inst.model:PivotTo(CFrame.new(0, worldRef.conveyor.beltTopY + 1.7, inst.z))
				end
			end
		end
		for _, uid in ipairs(toRemove) do
			Conveyor.remove(uid)
		end
	end)
end

-- Takes a brainrot off the belt without destroying it (a buy keeps the model).
function Conveyor.take(uid)
	local inst = Conveyor.active[uid]
	if inst then
		Conveyor.active[uid] = nil
	end
	return inst
end

-- Destroys a belt brainrot (reached the end bin, or left the game).
function Conveyor.remove(uid)
	local State = require(script.Parent.BakeryState)
	local inst = Conveyor.active[uid] or State.instances[uid]
	if inst then
		if inst.model then
			inst.model:Destroy()
		end
		State.unregisterInstance(uid)
	end
	Conveyor.active[uid] = nil
end

function Conveyor.activeCount()
	local n = 0
	for _ in pairs(Conveyor.active) do
		n = n + 1
	end
	return n
end

return Conveyor
