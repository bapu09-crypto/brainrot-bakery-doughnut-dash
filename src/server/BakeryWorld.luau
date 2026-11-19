-- BakeryWorld: builds the whole 3D bakery at runtime and builds brainrot models.
-- The static place holds only a baseplate; everything the player sees (plaza,
-- oven-line conveyor, 4 base plots, stalls, lamps, signs) is built here, so the
-- screenshots show a real world, not an empty plate. No game logic lives here:
-- this module only makes parts and hands back their references.
--
-- BASEPLATE FIX (v6): the place's Baseplate is 512x20x512, and its top face
-- sat at Y=10, burying the whole bakery (plaza, belt, pedestals and every
-- brainrot, which ride at Y~2.7). World.build() now sinks it first thing so
-- its top face is at Y=0, whatever the place file ships.
--
-- CYLINDER FIX (v6): a Roblox Cylinder part's axis is its X axis, NOT its Y
-- axis (the v4 note said Y, which was wrong). A disc written as Size
-- (diameter, thickness, diameter) with no rotation is therefore NOT a flat
-- disc lying on the ground -- it is a tube lying on its side. The upright()
-- helper below fixes that: it swaps the part's X and Y size and rolls it 90
-- degrees about Z, so the axis points straight up and the part is a flat disc
-- (or an upright can) with the size it was given. It is applied to the plaza,
-- every pedestal base and top, the barrel, the hat brim and crown, and the
-- candle stick. The brainrot BODY with shape "Cylinder" keeps its own single
-- 90-degree roll (it was already upright) and is left alone.
--
-- BELT FIX (v6): the belt used to sit at exactly the plaza's height (top Y=1),
-- so where they overlap the belt hid inside the plaza disc. The belt is now
-- raised (centre Y=1.1, top Y=1.6) so it reads clearly above the plaza, and
-- BELT_TOP_Y is 1.6 so the brainrots still ride ON the belt.
--
-- LIGHT (kept from v4): midday, bright and warm, so the world reads in a
-- screenshot.

local World = {}

-- Belt top Y=1.6: the belt part is centred at Y=1.1 and 1 stud thick.
local BELT_TOP_Y = 1.6
local PEDESTAL_TOP_Y = 2
local CONVEYOR_FROM_Z = -85
local CONVEYOR_TO_Z = 85

local PLOT_CENTERS = {
	Vector3.new(-55, 0, -55),
	Vector3.new(55, 0, -55),
	Vector3.new(-55, 0, 55),
	Vector3.new(55, 0, 55),
}
local PLOT_COLORS = {
	Color3.fromRGB(255, 170, 90),
	Color3.fromRGB(90, 180, 255),
	Color3.fromRGB(140, 220, 110),
	Color3.fromRGB(230, 110, 200),
}
-- 8 pedestals per plot, 2 rows of 4. The base cap is 6, and the Extra
-- Pedestal track adds up to 2 more, so the world needs all 8 built -- a
-- 7th or 8th buy would otherwise index a pedestal that does not exist.
local PEDESTAL_OFFSETS = {
	Vector3.new(-12, 0, -5),
	Vector3.new(-4, 0, -5),
	Vector3.new(4, 0, -5),
	Vector3.new(12, 0, -5),
	Vector3.new(-12, 0, 5),
	Vector3.new(-4, 0, 5),
	Vector3.new(4, 0, 5),
	Vector3.new(12, 0, 5),
}

local function part(name, className, size, position, color, material)
	local p = Instance.new(className or "Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color or Color3.fromRGB(200, 200, 200)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Stands a Cylinder part upright. A Cylinder's axis runs along X, so a part
-- written with Size (diameter, thickness, diameter) is a tube lying on its
-- side. Swapping X and Y of the size and rolling 90 degrees about Z turns
-- the axis to point straight up, leaving a flat disc (or an upright can) of
-- the size it was given, at the position it was given.
local function upright(p)
	local s = p.Size
	local pos = p.Position
	p.Size = Vector3.new(s.Y, s.X, s.Z)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

local function billboard(adornee, size, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	return gui
end

local function textLabel(parent, name, text, size, color, yPos, textSize, bold)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, 0, 0, size)
	label.Position = UDim2.new(0, 0, 0, yPos)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
	label.TextScaled = false
	label.TextWrapped = false
	label.Parent = parent
	return label
end

-- The big readable label every brainrot wears. Returns the gui and its lines
-- so the conveyor and steal code can rewrite them when the brainrot changes hands.
function World.makeBrainrotLabel(model, body, entry, mutationName, priceText)
	local gui = billboard(body, Vector2.new(230, 92), 3.4)
	gui.Name = "BrainrotLabel"
	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 14, 10)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 2
	frame.BorderColor3 = Color3.fromRGB(255, 220, 150)
	frame.Parent = gui
	local mutation = require(script.Parent.BakeryCatalog).MUTATIONS[mutationName or "None"]
	local rarity = require(script.Parent.BakeryCatalog).RARITIES[entry.rarity]
	local displayName = mutation.prefix .. entry.name
	local nameLabel = textLabel(frame, "Name", displayName, 26, Color3.fromRGB(255, 255, 255), 2, 17, true)
	local rarityLabel = textLabel(frame, "Rarity", string.upper(entry.rarity), 20, rarity.color, 28, 15, true)
	local priceLabel = textLabel(frame, "Price", priceText, 20, Color3.fromRGB(140, 255, 140), 50, 15, true)
	gui.Parent = model
	return { gui = gui, nameLabel = nameLabel, rarityLabel = rarityLabel, priceLabel = priceLabel }
end

-- Builds one brainrot character model. All parts anchored; move it with PivotTo.
function World.buildBrainrotModel(entry, mutationName)
	local Catalog = require(script.Parent.BakeryCatalog)
	local mutation = Catalog.MUTATIONS[mutationName or "None"]
	local bodyColor = mutation.tint or entry.color

	local model = Instance.new("Model")
	model.Name = entry.name

	local body = part(entry.name .. "Body", "Part", Vector3.new(3, 3, 3), Vector3.new(0, 0, 0), bodyColor)
	if entry.shape == "Ball" then
		body.Shape = Enum.PartType.Ball
	elseif entry.shape == "Cylinder" then
		body.Shape = Enum.PartType.Cylinder
		-- The ONLY 90-degree Z rotation on a brainrot body: the cylinder's
		-- axis runs along X, so this roll stands it upright like a can.
		-- (v6 leaves this exactly as it was -- it was already upright.)
		body.CFrame = CFrame.new(body.Position) * CFrame.Angles(0, 0, math.rad(90))
	end
	if entry.rarity == "Boss" or mutationName == "Diamond" then
		body.Material = Enum.Material.Neon
	end
	body.Parent = model
	model.PrimaryPart = body

	-- Eyes and a smile on the +Z face.
	local eyeL = part("EyeL", "Part", Vector3.new(0.55, 0.55, 0.3), Vector3.new(-0.7, 0.5, 1.45), Color3.fromRGB(20, 20, 20))
	eyeL.Shape = Enum.PartType.Ball
	eyeL.Parent = model
	local eyeR = part("EyeR", "Part", Vector3.new(0.55, 0.55, 0.3), Vector3.new(0.7, 0.5, 1.45), Color3.fromRGB(20, 20, 20))
	eyeR.Shape = Enum.PartType.Ball
	eyeR.Parent = model
	local mouth = part("Mouth", "Part", Vector3.new(0.9, 0.28, 0.2), Vector3.new(0, -0.35, 1.5), Color3.fromRGB(60, 20, 20))
	mouth.Parent = model

	-- The topping on top. Hat brim, crown and candle stick are Cylinders:
	-- upright() stands each one the way its Size intends.
	if entry.top == "Cherry" then
		local cherry = part("Cherry", "Part", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 1.9, 0), Color3.fromRGB(220, 30, 50))
		cherry.Shape = Enum.PartType.Ball
		cherry.Parent = model
	elseif entry.top == "Hat" then
		local brim = part("HatBrim", "Part", Vector3.new(2.6, 0.3, 2.6), Vector3.new(0, 1.6, 0), Color3.fromRGB(60, 40, 90))
		brim.Shape = Enum.PartType.Cylinder
		upright(brim)
		brim.Parent = model
		local crown = part("HatTop", "Part", Vector3.new(1.4, 1.0, 1.4), Vector3.new(0, 2.2, 0), Color3.fromRGB(60, 40, 90))
		crown.Shape = Enum.PartType.Cylinder
		upright(crown)
		crown.Parent = model
	elseif entry.top == "Sprinkles" then
		local sprinkleColors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 220, 90) }
		for i, c in ipairs(sprinkleColors) do
			local s = part("Sprinkle" .. i, "Part", Vector3.new(0.4, 0.4, 0.4), Vector3.new(-0.7 + (i - 1) * 0.7, 1.65, 0.4), c)
			s.Shape = Enum.PartType.Ball
			s.Parent = model
		end
	elseif entry.top == "Candle" then
		local stick = part("Candle", "Part", Vector3.new(0.35, 1.2, 0.35), Vector3.new(0, 2.0, 0), Color3.fromRGB(250, 245, 230))
		stick.Shape = Enum.PartType.Cylinder
		upright(stick)
		stick.Parent = model
		local flame = part("Flame", "Part", Vector3.new(0.5, 0.7, 0.5), Vector3.new(0, 2.8, 0), Color3.fromRGB(255, 200, 60))
		flame.Shape = Enum.PartType.Ball
		flame.Material = Enum.Material.Neon
		flame.Parent = model
	end

	local click = Instance.new("ClickDetector")
	click.Name = "BrainrotClick"
	click.MaxActivationDistance = 40
	click.Parent = body

	return model
end

function World.build()
	local workspace = game:GetService("Workspace")
	local lighting = game:GetService("Lighting")
	-- Midday, bright and warm (v4): the dusk lighting hid the world.
	lighting.ClockTime = 14.0
	lighting.Ambient = Color3.fromRGB(150, 140, 130)
	lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 150)
	lighting.Brightness = 3
	lighting.FogColor = Color3.fromRGB(200, 180, 150)
	lighting.FogStart = 150
	lighting.FogEnd = 800
	lighting.GlobalShadows = true

	-- BASEPLATE FIX (v6): the place's Baseplate is 512x20x512, and its top
	-- face sat at Y=10, burying the whole bakery (plaza, belt, pedestals and
	-- every brainrot, which ride at Y~2.7). Sink it so its top face is at
	-- Y=0, which is where everything below is built. Harmless when the place
	-- already ships the baseplate low -- it just guarantees the top is at 0.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Position = Vector3.new(0, -baseplate.Size.Y / 2, 0)
		baseplate.Anchored = true
	end

	local folder = Instance.new("Folder")
	folder.Name = "Bakery"
	folder.Parent = workspace

	-- Warm plaza disc at the centre. Written as a (90, 1, 90) Cylinder and
	-- stood upright, so it is a flat disc 90 across and 1 thick, top at Y=1.
	local plaza = part("Plaza", "Part", Vector3.new(90, 1, 90), Vector3.new(0, 0.5, 0), Color3.fromRGB(235, 205, 150))
	plaza.Shape = Enum.PartType.Cylinder
	upright(plaza)
	plaza.Material = Enum.Material.SmoothPlastic
	plaza.Parent = folder

	-- Big bakery sign at the north end, facing the spawn.
	local signPost = part("SignPost", "Part", Vector3.new(2, 14, 2), Vector3.new(0, 7, -98), Color3.fromRGB(120, 80, 50))
	signPost.Parent = folder
	local signBoard = part("SignBoard", "Part", Vector3.new(46, 10, 1.5), Vector3.new(0, 16, -98), Color3.fromRGB(150, 60, 40))
	signBoard.Parent = folder
	local signGui = billboard(signBoard, Vector2.new(560, 130), 0)
	signGui.Name = "BakerySign"
	local signFrame = Instance.new("Frame")
	signFrame.Size = UDim2.fromScale(1, 1)
	signFrame.BackgroundTransparency = 1
	signFrame.Parent = signGui
	textLabel(signFrame, "Title", "DOUGHNUT DASH BAKERY", 60, Color3.fromRGB(255, 230, 130), 4, 44, true)
	textLabel(signFrame, "Sub", "STEAL A BRAINROT  -  OVEN FRESH", 30, Color3.fromRGB(255, 255, 255), 66, 22, true)
	signGui.Parent = signBoard

	-- The oven-line conveyor down the middle: belt, rails, oven arch, end bin.
	-- The belt is warm mid-brown (v4) so it reads against the pale plaza, and
	-- (v6) it is raised so its top (Y=1.6) stands clear above the plaza top
	-- (Y=1) instead of hiding inside it. The rails ride just above the belt.
	local belt = part("ConveyorBelt", "Part", Vector3.new(8, 1, 172), Vector3.new(0, 1.1, 0), Color3.fromRGB(150, 100, 60))
	belt.Material = Enum.Material.Metal
	belt.Parent = folder
	for _, x in ipairs({ -4.5, 4.5 }) do
		local rail = part("Rail", "Part", Vector3.new(0.6, 1.2, 172), Vector3.new(x, 1.7, 0), Color3.fromRGB(255, 180, 60))
		rail.Material = Enum.Material.Neon
		rail.Parent = folder
	end
	local ovenLeft = part("OvenLeft", "Part", Vector3.new(2, 10, 6), Vector3.new(-5, 5, -86), Color3.fromRGB(160, 60, 40))
	ovenLeft.Parent = folder
	local ovenRight = part("OvenRight", "Part", Vector3.new(2, 10, 6), Vector3.new(5, 5, -86), Color3.fromRGB(160, 60, 40))
	ovenRight.Parent = folder
	local ovenTop = part("OvenTop", "Part", Vector3.new(12, 2, 6), Vector3.new(0, 11, -86), Color3.fromRGB(160, 60, 40))
	ovenTop.Parent = folder
	local ovenGlow = part("OvenGlow", "Part", Vector3.new(8, 6, 0.5), Vector3.new(0, 4, -86), Color3.fromRGB(255, 140, 40))
	ovenGlow.Material = Enum.Material.Neon
	ovenGlow.Parent = folder
	local ovenGui = billboard(ovenTop, Vector2.new(200, 50), 2.5)
	local ovenFrame = Instance.new("Frame")
	ovenFrame.Size = UDim2.fromScale(1, 1)
	ovenFrame.BackgroundTransparency = 1
	ovenFrame.Parent = ovenGui
	textLabel(ovenFrame, "Oven", "HOT OVEN", 50, Color3.fromRGB(255, 220, 130), 0, 30, true)
	ovenGui.Parent = ovenTop
	local endBin = part("EndBin", "Part", Vector3.new(10, 3, 6), Vector3.new(0, 1.5, 88), Color3.fromRGB(90, 60, 40))
	endBin.Parent = folder

	-- Four base plots with eight pedestals each.
	local plots = {}
	for i, center in ipairs(PLOT_CENTERS) do
		local plotColor = PLOT_COLORS[i]
		local platform = part("Plot" .. i, "Part", Vector3.new(30, 1, 30), Vector3.new(center.X, 0.5, center.Z), plotColor)
		platform.Parent = folder
		local trim = part("PlotTrim" .. i, "Part", Vector3.new(32, 0.4, 32), Vector3.new(center.X, 0.2, center.Z), Color3.fromRGB(255, 240, 200))
		trim.Parent = folder
		local sign = part("PlotSign" .. i, "Part", Vector3.new(14, 4, 1), Vector3.new(center.X, 6, center.Z - 14), Color3.fromRGB(40, 30, 25))
		sign.Parent = folder
		local plotSignGui = billboard(sign, Vector2.new(220, 60), 0)
		local plotSignFrame = Instance.new("Frame")
		plotSignFrame.Size = UDim2.fromScale(1, 1)
		plotSignFrame.BackgroundTransparency = 1
		plotSignFrame.Parent = plotSignGui
		local signLabel = textLabel(plotSignFrame, "PlotName", "STALL " .. i, 40, Color3.fromRGB(255, 255, 255), 2, 26, true)
		plotSignGui.Parent = sign
		local pedestals = {}
		for j, offset in ipairs(PEDESTAL_OFFSETS) do
			local pos = center + offset
			-- Pedestal base and top are flat Cylinder discs, stood upright so
			-- they lie flat and the brainrots stand on them visibly.
			local base = part("Pedestal" .. j, "Part", Vector3.new(5, 1, 5), Vector3.new(pos.X, 1.5, pos.Z), Color3.fromRGB(245, 235, 210))
			base.Shape = Enum.PartType.Cylinder
			upright(base)
			base.Parent = folder
			local disc = part("PedestalTop" .. j, "Part", Vector3.new(4.4, 0.3, 4.4), Vector3.new(pos.X, 2.0, pos.Z), plotColor)
			disc.Shape = Enum.PartType.Cylinder
			upright(disc)
			disc.Parent = folder
			local click = Instance.new("ClickDetector")
			click.Name = "PedestalClick"
			click.MaxActivationDistance = 40
			click.Parent = disc
			table.insert(pedestals, {
				index = j,
				position = Vector3.new(pos.X, PEDESTAL_TOP_Y, pos.Z),
				base = base,
				top = disc,
				click = click,
			})
		end
		table.insert(plots, {
			index = i,
			center = center,
			color = plotColor,
			platform = platform,
			pedestals = pedestals,
			signLabel = signLabel,
		})
	end

	-- Bakery stalls along the plaza edges.
	local stallSpots = {
		{ pos = Vector3.new(-38, 0, 0), color = Color3.fromRGB(255, 120, 120) },
		{ pos = Vector3.new(38, 0, 0), color = Color3.fromRGB(120, 180, 255) },
		{ pos = Vector3.new(-30, 0, 38), color = Color3.fromRGB(140, 220, 140) },
		{ pos = Vector3.new(30, 0, 38), color = Color3.fromRGB(255, 200, 90) },
	}
	for i, spot in ipairs(stallSpots) do
		local counter = part("Stall" .. i, "Part", Vector3.new(10, 4, 6), Vector3.new(spot.pos.X, 2, spot.pos.Z), Color3.fromRGB(150, 100, 60))
		counter.Parent = folder
		local awning = part("Awning" .. i, "Part", Vector3.new(12, 0.6, 8), Vector3.new(spot.pos.X, 4.6, spot.pos.Z), spot.color)
		awning.Parent = folder
		local goods = part("Goods" .. i, "Part", Vector3.new(8, 1.5, 4), Vector3.new(spot.pos.X, 4.7, spot.pos.Z), Color3.fromRGB(240, 200, 130))
		goods.Shape = Enum.PartType.Ball
		goods.Parent = folder
	end

	-- Lamp posts around the plaza.
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8) + math.pi / 8
		local x = math.cos(angle) * 48
		local z = math.sin(angle) * 48
		local pole = part("LampPole" .. i, "Part", Vector3.new(0.8, 8, 0.8), Vector3.new(x, 4, z), Color3.fromRGB(60, 50, 45))
		pole.Parent = folder
		local lamp = part("Lamp" .. i, "Part", Vector3.new(1.8, 1.8, 1.8), Vector3.new(x, 8.6, z), Color3.fromRGB(255, 220, 130))
		lamp.Shape = Enum.PartType.Ball
		lamp.Material = Enum.Material.Neon
		lamp.Parent = folder
	end

	-- Crates and barrels for clutter. The barrel is a tall Cylinder, stood
	-- upright so it stands on the ground instead of lying on its side.
	local crateSpots = { Vector3.new(-20, 0, -30), Vector3.new(22, 0, -28), Vector3.new(-24, 0, 30), Vector3.new(24, 0, -38) }
	for i, pos in ipairs(crateSpots) do
		local crate = part("Crate" .. i, "Part", Vector3.new(3, 3, 3), Vector3.new(pos.X, 1.5, pos.Z), Color3.fromRGB(170, 120, 70))
		crate.Parent = folder
		local barrel = part("Barrel" .. i, "Part", Vector3.new(2.4, 3.4, 2.4), Vector3.new(pos.X + 4, 1.7, pos.Z), Color3.fromRGB(120, 80, 50))
		barrel.Shape = Enum.PartType.Cylinder
		upright(barrel)
		barrel.Parent = folder
	end

	-- Spawn pad on the east side of the plaza, clear of the belt.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BakerySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(20, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 220, 130)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = folder

	local result = {
		folder = folder,
		plots = plots,
		conveyor = { fromZ = CONVEYOR_FROM_Z, toZ = CONVEYOR_TO_Z, beltTopY = BELT_TOP_Y },
		spawnCFrame = CFrame.new(20, 3, 0),
	}
	World._world = result
	return result
end

-- The built world, for modules that need the plots after build (steal/place).
function World.getPlots()
	if World._world then
		return World._world.plots
	end
	return {}
end

World.BELT_TOP_Y = BELT_TOP_Y
World.PEDESTAL_TOP_Y = PEDESTAL_TOP_Y

return World
