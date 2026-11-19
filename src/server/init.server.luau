-- Brainrot Bakery - Doughnut Dash (v6): server entrypoint.
-- Builds the world, wires the remotes, starts the conveyor, the Burn Wave and
-- the Golden Hour, then hands every joining player a stall, a Rolling Pin and
-- a fresh ledger. One process, one game.
--
-- REQUIRE FIX (kept from v3): Rojo turns a folder holding init.server.luau
-- into the Script itself, so the modules are CHILDREN of this script -- not
-- siblings under ServerScriptService. The requires below therefore use
-- `script` (this script) and NOT `script.Parent` (which is ServerScriptService,
-- where the modules do not live). The v1 and v2 builds used script.Parent here
-- and died on their very first require, so no world built and no Remotes
-- folder ever appeared. Module-to-module requires still use script.Parent.* --
-- for a ModuleScript, script.Parent IS this Server Script, so siblings
-- resolve correctly there.
--
-- BASEPLATE + CYLINDER FIX (v6): BakeryWorld now sinks the Baseplate so its
-- top is at Y=0, stands every Cylinder disc upright with an upright() helper,
-- and raises the belt above the plaza so the brainrots ride visibly on it.
-- See the notes at the top of BakeryWorld.
--
-- SLAP FIX (kept from v5): the Rolling Pin is now a plain Tool with only a
-- Handle -- no LocalScript is created at runtime and nothing writes .Source
-- (a game server cannot do that; the v4 threw on every spawn). The client
-- script hooks the tool's Activated event to the Slap remote instead.

local Players = game:GetService("Players")

-- The Server Script itself is the parent of all modules below (Rojo makes the
-- folder the Script). Requires use `script`, never `script.Parent`.
local Server = script
local World = require(Server.BakeryWorld)
local State = require(Server.BakeryState)
local Quests = require(Server.BakeryQuests)
local Shop = require(Server.BakeryShop)
local Conveyor = require(Server.BakeryConveyor)
local Threat = require(Server.BakeryThreat)
local Steal = require(Server.BakerySteal)
local Remotes = require(Server.BakeryRemotes)

local world = World.build()
Remotes.setup(world)
Conveyor.start(world)
Threat.start(world)
Remotes.startTicker()

local function onCharacterAdded(player, character)
	local state = State.get(player)
	local humanoid = character:WaitForChild("Humanoid")
	if state and humanoid then
		humanoid.WalkSpeed = Shop.walkSpeed(state)
	end
	Steal.giveSlapTool(player)
end

local function onPlayerAdded(player)
	local plotIndex = State.assignPlot(player)
	local state = State.new(player, plotIndex)
	Quests.initState(state)
	world.plots[plotIndex].signLabel.Text = player.DisplayName .. "'s STALL"
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	Remotes.pushState(player)
end

local function onPlayerRemoving(player)
	local state = State.get(player)
	if not state then
		return
	end
	local plotIndex = state.plotIndex
	for uid, inst in pairs(state.owned) do
		if inst.model then
			inst.model:Destroy()
		end
		State.unregisterInstance(uid)
	end
	if state.carriedUid then
		local inst = State.instances[state.carriedUid]
		if inst and inst.model then
			inst.model:Destroy()
		end
		if inst then
			State.unregisterInstance(inst.uid)
		end
	end
	State.remove(player)
	local stillThere = false
	for _, other in pairs(State.players) do
		if other.plotIndex == plotIndex then
			stillThere = true
		end
	end
	if not stillThere then
		world.plots[plotIndex].signLabel.Text = "STALL " .. plotIndex
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

print("Brainrot Bakery v6 running: 32 brainrots, 4 stalls, Burn Wave live.")
