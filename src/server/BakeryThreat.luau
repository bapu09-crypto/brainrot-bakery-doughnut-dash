-- BakeryThreat: the two clocks that keep the game tense.
-- Burn Wave: 75s calm, 10s warning, 8s burn. Anyone carrying a brainrot while
-- the wave burns and standing off their own stall drops it.
-- Golden Hour: every 180s, 30s where every pen pays double.
-- Both are announced to the HUD through callbacks the remotes module sets.

local Threat = {}

Threat.phase = "calm" -- calm | warning | burn
Threat.phaseLeft = 75
Threat.goldenActive = false
Threat.goldenLeft = 180
Threat.onThreat = nil -- function(phase, secondsLeft)
Threat.onGolden = nil -- function(active, secondsLeft)

local CALM_SECONDS = 75
local WARNING_SECONDS = 10
local BURN_SECONDS = 8
local GOLDEN_EVERY = 180
local GOLDEN_LASTS = 30

local worldRef = nil
local burnRing = nil
local running = false

local function setPhase(phase, seconds)
	Threat.phase = phase
	Threat.phaseLeft = seconds
	if Threat.onThreat then
		Threat.onThreat(phase, seconds)
	end
end

local function setGolden(active, seconds)
	Threat.goldenActive = active
	Threat.goldenLeft = seconds
	if Threat.onGolden then
		Threat.onGolden(active, seconds)
	end
end

-- The burn ring is a flat red disc that grows over the plaza while the wave
-- burns. A Cylinder's axis runs along X, so the disc is built with its size
-- swapped and rolled upright, the same as BakeryWorld's upright().
local function makeBurnRing()
	local ring = Instance.new("Part")
	ring.Name = "BurnRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(6, 20, 20)
	ring.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 90, 20)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = worldRef.folder
	return ring
end

-- Is this character standing on the given plot? Plots are 30x30 around center.
local function onPlot(character, plotIndex)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local center = worldRef.plots[plotIndex].center
	local pos = root.Position
	return math.abs(pos.X - center.X) <= 15 and math.abs(pos.Z - center.Z) <= 15
end

function Threat.start(world)
	worldRef = world
	if running then
		return
	end
	running = true
	task.spawn(function()
		while running do
			task.wait(1)
			-- Burn Wave clock.
			Threat.phaseLeft = Threat.phaseLeft - 1
			if Threat.phase == "calm" and Threat.phaseLeft <= 0 then
				setPhase("warning", WARNING_SECONDS)
			elseif Threat.phase == "warning" and Threat.phaseLeft <= 0 then
				setPhase("burn", BURN_SECONDS)
				burnRing = makeBurnRing()
			elseif Threat.phase == "burn" then
				if burnRing and burnRing.Parent then
					local grown = 20 + (BURN_SECONDS - Threat.phaseLeft) * 14
					burnRing.Size = Vector3.new(6, grown, grown)
				end
				-- Anyone carrying off their own stall drops the catch.
				local Steal = require(script.Parent.BakerySteal)
				local State = require(script.Parent.BakeryState)
				for _, state in pairs(State.players) do
					if state.carriedUid then
						local player = state.player
						local character = player.Character
						if not onPlot(character, state.plotIndex) then
							Steal.dropCarried(player, "The Burn Wave swept your catch away!")
						end
					end
				end
				if Threat.phaseLeft <= 0 then
					if burnRing then
						burnRing:Destroy()
						burnRing = nil
					end
					setPhase("calm", CALM_SECONDS)
				end
			end
			if Threat.onThreat then
				Threat.onThreat(Threat.phase, Threat.phaseLeft)
			end
			-- Golden Hour clock.
			if Threat.goldenActive then
				Threat.goldenLeft = Threat.goldenLeft - 1
				if Threat.goldenLeft <= 0 then
					setGolden(false, GOLDEN_EVERY)
				elseif Threat.onGolden then
					Threat.onGolden(true, Threat.goldenLeft)
				end
			else
				Threat.goldenLeft = Threat.goldenLeft - 1
				if Threat.goldenLeft <= 0 then
					setGolden(true, GOLDEN_LASTS)
				elseif Threat.onGolden then
					Threat.onGolden(false, Threat.goldenLeft)
				end
			end
		end
	end)
end

function Threat.isGoldenHour()
	return Threat.goldenActive
end

return Threat
