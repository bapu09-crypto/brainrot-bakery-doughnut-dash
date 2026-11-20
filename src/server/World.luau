-- World.luau
-- Builds the whole 3D bakery at runtime and builds brainrot models.
-- The place file itself holds only a baseplate; everything here is code.
-- Cylinder rule: a Roblox Cylinder's axis runs along X, not Y. A flat
-- disc (or an upright cylinder) is sized (length, diameter, diameter)
-- and rolled 90 degrees about Z, so its axis points straight up.

local World = {}

local function part(parent, name, size, pos, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- A flat disc lying on the ground: axis straight up.
local function disc(parent, name, diameter, thickness, pos, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thickness, diameter, diameter)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.Parent = parent
	return p
end

-- A cylinder standing upright (barrel, candle, hat crown, body).
local function uprightCylinder(parent, name, height, diameter, pos, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.Parent = parent
	return p
end

-- A board with the same text on both faces, so it reads from either side.
local function sign(parent, pos, size, lines, color)
	local board = part(parent, "Sign", size, pos, color or Color3.fromRGB(90, 55, 30), Enum.Material.Wood)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.AlwaysOnTop = false
		gui.Parent = board
		for i, line in ipairs(lines) do
			local label = Instance.new("TextLabel")
			label.Name = "Line" .. i
			label.Size = UDim2.new(1, 0, 0, size.Y / #lines)
			label.Position = UDim2.new(0, 0, 0, (i - 1) * (size.Y / #lines))
			label.BackgroundTransparency = 1
			label.Text = line.Text
			label.TextColor3 = line.Color
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.Parent = gui
		end
	end
	return board
end

-- A stall sign whose main line the game rewrites when an owner joins.
local function stallSign(parent, pos, stallName)
	local board = part(parent, "StallSign", Vector3.new(16, 4, 1), pos, Color3.fromRGB(90, 55, 30), Enum.Material.Wood)
	local mainLabel = nil
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Name = "OwnerLabel"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = stallName
		label.TextColor3 = Color3.fromRGB(255, 220, 120)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
		if face == Enum.NormalId.Front then
			mainLabel = label
		end
	end
	return mainLabel
end

function World.Build()
	local ws = game:GetService("Workspace")
	local folder = Instance.new("Folder")
	folder.Name = "Bakery"
	folder.Parent = ws

	-- Warm tan plaza disc, 90 across, 1 thick, top at height 1.
	-- Collidable: it is the floor players stand on.
	local plaza = disc(folder, "Plaza", 90, 1, Vector3.new(0, 0.5, 0), Color3.fromRGB(220, 190, 140), Enum.Material.SmoothPlastic)
	plaza.CanCollide = true

	-- Big sign at the north end, facing the spawn.
	local post = part(folder, "SignPost", Vector3.new(1.5, 10, 1.5), Vector3.new(0, 5, -72), Color3.fromRGB(90, 55, 30), Enum.Material.Wood)
	post.CanCollide = true
	sign(folder, Vector3.new(0, 12, -72), Vector3.new(26, 7, 1), {
		{ Text = "DOUGHNUT DASH BAKERY", Color = Color3.fromRGB(255, 210, 60) },
		{ Text = "STEAL A BRAINROT - OVEN FRESH", Color = Color3.fromRGB(255, 255, 255) },
	})

	-- Conveyor belt down the middle, north to south. Top at 1.6, above the plaza top (1.0).
	part(folder, "Belt", Vector3.new(8, 0.6, 172), Vector3.new(0, 1.3, 0), Color3.fromRGB(170, 120, 70), Enum.Material.SmoothPlastic)
	part(folder, "RailLeft", Vector3.new(0.4, 0.5, 172), Vector3.new(-4.2, 1.8, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	part(folder, "RailRight", Vector3.new(0.4, 0.5, 172), Vector3.new(4.2, 1.8, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)

	-- Oven arch at the north end of the belt.
	part(folder, "OvenPillarL", Vector3.new(1.5, 9, 1.5), Vector3.new(-5.5, 4.5, -85), Color3.fromRGB(200, 60, 50), Enum.Material.SmoothPlastic)
	part(folder, "OvenPillarR", Vector3.new(1.5, 9, 1.5), Vector3.new(5.5, 4.5, -85), Color3.fromRGB(200, 60, 50), Enum.Material.SmoothPlastic)
	part(folder, "OvenBeam", Vector3.new(12.5, 1.5, 2), Vector3.new(0, 9.5, -85), Color3.fromRGB(200, 60, 50), Enum.Material.SmoothPlastic)
	part(folder, "OvenPanel", Vector3.new(9, 4, 0.5), Vector3.new(0, 6.5, -84), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
	sign(folder, Vector3.new(0, 11.5, -85), Vector3.new(10, 2.5, 1), {
		{ Text = "HOT OVEN", Color = Color3.fromRGB(255, 220, 120) },
	})

	-- Dark end bin at the south end of the belt.
	part(folder, "EndBin", Vector3.new(10, 3, 5), Vector3.new(0, 1.5, 89), Color3.fromRGB(50, 50, 55), Enum.Material.SmoothPlastic)

	-- Four stalls at the four corners.
	local stallCentres = {
		{ Centre = Vector3.new(-55, 0, -55), Color = Color3.fromRGB(255, 140, 60) },
		{ Centre = Vector3.new(55, 0, -55), Color = Color3.fromRGB(80, 140, 255) },
		{ Centre = Vector3.new(-55, 0, 55), Color = Color3.fromRGB(80, 200, 80) },
		{ Centre = Vector3.new(55, 0, 55), Color = Color3.fromRGB(255, 110, 200) },
	}
	local plots = {}
	for i, s in ipairs(stallCentres) do
		local c = s.Centre
		part(folder, "Trim" .. i, Vector3.new(32, 0.3, 32), Vector3.new(c.X, 0.15, c.Z), Color3.fromRGB(245, 230, 200), Enum.Material.SmoothPlastic)
		-- Collidable: the stall floor players stand on, top at height 1.
		local platform = part(folder, "Platform" .. i, Vector3.new(30, 1, 30), Vector3.new(c.X, 0.5, c.Z), s.Color, Enum.Material.SmoothPlastic)
		platform.CanCollide = true
		local label = stallSign(folder, Vector3.new(c.X, 5, c.Z - 16), "STALL " .. i)
		local plot = {
			Index = i,
			Centre = Vector3.new(c.X, 0, c.Z),
			Color = s.Color,
			SignLabel = label,
			Owners = {},
			Pedestals = {},
		}
		-- 8 pedestals in two rows of four.
		local n = 0
		for _, ox in ipairs({ -12, -4, 4, 12 }) do
			for _, oz in ipairs({ -5, 5 }) do
				n += 1
				local px = c.X + ox
				local pz = c.Z + oz
				disc(folder, "PedBase" .. i .. "_" .. n, 4, 0.5, Vector3.new(px, 1.25, pz), Color3.fromRGB(245, 230, 200), Enum.Material.SmoothPlastic)
				local top = disc(folder, "PedTop" .. i .. "_" .. n, 3, 0.4, Vector3.new(px, 1.7, pz), s.Color, Enum.Material.SmoothPlastic)
				local click = Instance.new("ClickDetector")
				click.MaxActivationDistance = 40
				click.Parent = top
				plot.Pedestals[n] = {
					Index = n,
					Plot = plot,
					Top = top,
					Click = click,
					Occupant = nil,
					StandPos = Vector3.new(px, 3.4, pz),
				}
			end
		end
		plots[i] = plot
	end

	-- Four bakery stalls along the plaza edges.
	local stallCols = {
		Color3.fromRGB(255, 140, 60),
		Color3.fromRGB(80, 140, 255),
		Color3.fromRGB(80, 200, 80),
		Color3.fromRGB(255, 110, 200),
	}
	local stallSpots = { Vector3.new(-38, 0, -20), Vector3.new(38, 0, -20), Vector3.new(-38, 0, 20), Vector3.new(38, 0, 20) }
	for i, spot in ipairs(stallSpots) do
		part(folder, "Counter" .. i, Vector3.new(6, 2, 3), Vector3.new(spot.X, 1, spot.Z), Color3.fromRGB(120, 80, 50), Enum.Material.Wood)
		part(folder, "Awning" .. i, Vector3.new(7, 0.3, 4), Vector3.new(spot.X, 3.6, spot.Z), stallCols[i], Enum.Material.SmoothPlastic)
		local goods = Instance.new("Part")
		goods.Name = "Goods" .. i
		goods.Shape = Enum.PartType.Ball
		goods.Size = Vector3.new(1.6, 1.6, 1.6)
		goods.Position = Vector3.new(spot.X, 2.8, spot.Z)
		goods.Color = Color3.fromRGB(255, 200, 90)
		goods.Material = Enum.Material.SmoothPlastic
		goods.Anchored = true
		goods.CanCollide = false
		goods.Parent = folder
	end

	-- Eight lamp posts in a ring around the plaza.
	for k = 0, 7 do
		local a = math.rad(k * 45)
		local x = math.cos(a) * 48
		local z = math.sin(a) * 48
		uprightCylinder(folder, "LampPole" .. k, 6, 0.6, Vector3.new(x, 3, z), Color3.fromRGB(60, 60, 65), Enum.Material.SmoothPlastic)
		local bulb = Instance.new("Part")
		bulb.Name = "LampBulb" .. k
		bulb.Shape = Enum.PartType.Ball
		bulb.Size = Vector3.new(1.4, 1.4, 1.4)
		bulb.Position = Vector3.new(x, 6.6, z)
		bulb.Color = Color3.fromRGB(255, 220, 140)
		bulb.Material = Enum.Material.Neon
		bulb.Anchored = true
		bulb.CanCollide = false
		bulb.Parent = folder
	end

	-- Crates and barrels as clutter, clear of the belt, stalls and spawn.
	local crateSpots = { Vector3.new(-25, 0, -30), Vector3.new(25, 0, 30), Vector3.new(-25, 0, 32), Vector3.new(28, 0, -32) }
	for i, spot in ipairs(crateSpots) do
		part(folder, "Crate" .. i, Vector3.new(2.5, 2.5, 2.5), Vector3.new(spot.X, 1.25, spot.Z), Color3.fromRGB(170, 120, 70), Enum.Material.Wood)
	end
	local barrelSpots = { Vector3.new(-30, 0, 10), Vector3.new(30, 0, -10), Vector3.new(15, 0, -35) }
	for i, spot in ipairs(barrelSpots) do
		uprightCylinder(folder, "Barrel" .. i, 2.5, 1.6, Vector3.new(spot.X, 1.25, spot.Z), Color3.fromRGB(140, 90, 50), Enum.Material.Wood)
	end

	-- Spawn pad on the east side of the plaza.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPad"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(20, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 210, 60)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	-- Burn Wave ring: a flat red disc that grows over the plaza during the burn.
	local ring = disc(folder, "BurnRing", 10, 0.3, Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	ring.Transparency = 1

	return {
		Folder = folder,
		Plots = plots,
		Spawn = spawn,
		BurnRing = ring,
	}
end

-- Build one brainrot model, centred on the origin (the caller pivots it).
-- nameText is the display name (with a mutation prefix when mutated),
-- moneyText is the price or income line for its floating label.
function World.BuildBrainrot(def, mutation, rarityColor, nameText, moneyText)
	local model = Instance.new("Model")
	model.Name = nameText

	local bodyColor = def.Color
	if mutation and mutation.Tint then
		bodyColor = mutation.Tint
	end
	local glow = def.Rarity == "Boss" or (mutation and mutation.Name == "Diamond")

	local body
	if def.Shape == "Ball" then
		body = Instance.new("Part")
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(3, 3, 3)
		body.Position = Vector3.new(0, 0, 0)
	elseif def.Shape == "Cylinder" then
		body = uprightCylinder(model, "Body", 3, 3, Vector3.new(0, 0, 0), bodyColor, glow and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		body.Name = "Body"
	else
		body = Instance.new("Part")
		body.Size = Vector3.new(3, 3, 3)
		body.Position = Vector3.new(0, 0, 0)
	end
	if def.Shape ~= "Cylinder" then
		body.Name = "Body"
		body.Color = bodyColor
		body.Material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
		body.Anchored = true
		body.CanCollide = false
		body.Parent = model
	end
	model.PrimaryPart = body

	-- Two black ball eyes and a small dark mouth on the front face.
	for _, ex in ipairs({ -0.6, 0.6 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.5, 0.5, 0.5)
		eye.Position = Vector3.new(ex, 0.5, 1.3)
		eye.Color = Color3.fromRGB(20, 20, 20)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.Parent = model
	end
	local mouth = part(model, "Mouth", Vector3.new(0.9, 0.25, 0.2), Vector3.new(0, -0.4, 1.4), Color3.fromRGB(40, 20, 20), Enum.Material.SmoothPlastic)

	-- Topping on top.
	if def.Topping == "Cherry" then
		local cherry = Instance.new("Part")
		cherry.Name = "Cherry"
		cherry.Shape = Enum.PartType.Ball
		cherry.Size = Vector3.new(0.8, 0.8, 0.8)
		cherry.Position = Vector3.new(0, 1.9, 0)
		cherry.Color = Color3.fromRGB(220, 30, 50)
		cherry.Material = Enum.Material.SmoothPlastic
		cherry.Anchored = true
		cherry.CanCollide = false
		cherry.Parent = model
	elseif def.Topping == "Hat" then
		disc(model, "HatBrim", 2.6, 0.25, Vector3.new(0, 1.6, 0), Color3.fromRGB(140, 60, 200), Enum.Material.SmoothPlastic)
		uprightCylinder(model, "HatCrown", 0.9, 1.3, Vector3.new(0, 2.1, 0), Color3.fromRGB(140, 60, 200), Enum.Material.SmoothPlastic)
	elseif def.Topping == "Sprinkles" then
		local cols = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 140, 255) }
		local spots = { Vector3.new(-0.7, 1.6, 0.3), Vector3.new(0.6, 1.7, -0.2), Vector3.new(0, 1.6, 0.7) }
		for i, spot in ipairs(spots) do
			local s = Instance.new("Part")
			s.Name = "Sprinkle"
			s.Shape = Enum.PartType.Ball
			s.Size = Vector3.new(0.35, 0.35, 0.35)
			s.Position = spot
			s.Color = cols[i]
			s.Material = Enum.Material.SmoothPlastic
			s.Anchored = true
			s.CanCollide = false
			s.Parent = model
		end
	elseif def.Topping == "Candle" then
		uprightCylinder(model, "Candle", 1.0, 0.45, Vector3.new(0, 2.0, 0), Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic)
		local flame = Instance.new("Part")
		flame.Name = "Flame"
		flame.Shape = Enum.PartType.Ball
		flame.Size = Vector3.new(0.5, 0.5, 0.5)
		flame.Position = Vector3.new(0, 2.8, 0)
		flame.Color = Color3.fromRGB(255, 200, 60)
		flame.Material = Enum.Material.Neon
		flame.Anchored = true
		flame.CanCollide = false
		flame.Parent = model
	end

	-- Floating label card: name, rarity, price or income.
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(0, 220, 0, 80)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = body
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
	frame.BorderColor3 = Color3.fromRGB(255, 210, 60)
	frame.BorderSizePixel = 2
	frame.Parent = gui
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = nameText
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = frame
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, 0, 0, 22)
	rarityLabel.Position = UDim2.new(0, 0, 0, 28)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = string.upper(def.Rarity)
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = frame
	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Size = UDim2.new(1, 0, 0, 28)
	moneyLabel.Position = UDim2.new(0, 0, 0, 50)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Text = moneyText
	moneyLabel.TextColor3 = Color3.fromRGB(90, 230, 110)
	moneyLabel.TextScaled = true
	moneyLabel.Font = Enum.Font.GothamBold
	moneyLabel.Parent = frame

	return model
end

return World
