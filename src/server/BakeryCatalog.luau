-- BakeryCatalog: the pastry brainrot cast for Brainrot Bakery - Doughnut Dash.
-- 32 named brainrots across 7 rarities, plus the 5 mutations that roll on
-- purchase. This module is pure data and picks: no services, no state. The
-- conveyor spawns from it and the index panel lists it, so a name, price or
-- pay rate changes here and everywhere follows.

local Catalog = {}

-- The rarity ladder. order sorts the index, color paints the labels, weight
-- drives the weighted spawn pick (common brainrots roll out far more often).
Catalog.RARITIES = {
	Common = { order = 1, color = Color3.fromRGB(120, 200, 90), weight = 45 },
	Rare = { order = 2, color = Color3.fromRGB(80, 140, 255), weight = 25 },
	Epic = { order = 3, color = Color3.fromRGB(170, 90, 230), weight = 15 },
	Legendary = { order = 4, color = Color3.fromRGB(255, 190, 40), weight = 8 },
	Mythic = { order = 5, color = Color3.fromRGB(255, 80, 140), weight = 4 },
	Secret = { order = 6, color = Color3.fromRGB(60, 230, 220), weight = 2 },
	Boss = { order = 7, color = Color3.fromRGB(220, 40, 40), weight = 1 },
}

Catalog.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Boss" }

-- Mutations roll when a brainrot is bought. prefix goes on the label, mult
-- multiplies its pay, tint recolors the body. None is the plain roll.
Catalog.MUTATIONS = {
	None = { mult = 1, prefix = "", tint = nil },
	Golden = { mult = 2, prefix = "GOLDEN ", tint = Color3.fromRGB(255, 210, 60) },
	Charred = { mult = 1.5, prefix = "CHARRED ", tint = Color3.fromRGB(70, 52, 44) },
	Rainbow = { mult = 3, prefix = "RAINBOW ", tint = Color3.fromRGB(255, 120, 220) },
	Diamond = { mult = 5, prefix = "DIAMOND ", tint = Color3.fromRGB(180, 230, 255) },
}

-- shape: Ball / Block / Cylinder. top: Cherry / Hat / Sprinkles / Candle / None.
-- income is $/s once penned; price is the conveyor buy cost.
Catalog.BRAINROTS = {
	{ id = 1, name = "Bready McDoughface", rarity = "Common", income = 5, price = 50, color = Color3.fromRGB(222, 184, 135), shape = "Ball", top = "None" },
	{ id = 2, name = "Croissantio Crustini", rarity = "Common", income = 8, price = 120, color = Color3.fromRGB(232, 178, 90), shape = "Block", top = "None" },
	{ id = 3, name = "Muffinella Munchkin", rarity = "Common", income = 12, price = 200, color = Color3.fromRGB(190, 130, 80), shape = "Cylinder", top = "Cherry" },
	{ id = 4, name = "Bagelo Baguette", rarity = "Common", income = 15, price = 300, color = Color3.fromRGB(215, 165, 95), shape = "Cylinder", top = "None" },
	{ id = 5, name = "Pretzelo Twisto", rarity = "Common", income = 18, price = 400, color = Color3.fromRGB(170, 110, 60), shape = "Block", top = "None" },
	{ id = 6, name = "Donutto Dippio", rarity = "Common", income = 22, price = 550, color = Color3.fromRGB(240, 150, 180), shape = "Cylinder", top = "Sprinkles" },
	{ id = 7, name = "Cookio Crumblo", rarity = "Common", income = 28, price = 700, color = Color3.fromRGB(140, 95, 55), shape = "Ball", top = "None" },
	{ id = 8, name = "Wafflo Syrupo", rarity = "Common", income = 35, price = 900, color = Color3.fromRGB(225, 175, 85), shape = "Block", top = "None" },
	{ id = 9, name = "Tiramisu Tornado", rarity = "Rare", income = 60, price = 1500, color = Color3.fromRGB(200, 160, 110), shape = "Cylinder", top = "None" },
	{ id = 10, name = "Churro Churro", rarity = "Rare", income = 75, price = 2000, color = Color3.fromRGB(190, 130, 70), shape = "Cylinder", top = "None" },
	{ id = 11, name = "Eclairo Flashio", rarity = "Rare", income = 90, price = 2500, color = Color3.fromRGB(120, 80, 50), shape = "Block", top = "Cherry" },
	{ id = 12, name = "Cannoli Cannon", rarity = "Rare", income = 110, price = 3200, color = Color3.fromRGB(235, 220, 180), shape = "Cylinder", top = "None" },
	{ id = 13, name = "Macaron Meltdown", rarity = "Rare", income = 140, price = 4000, color = Color3.fromRGB(255, 170, 200), shape = "Ball", top = "None" },
	{ id = 14, name = "Brownie Bouncer", rarity = "Rare", income = 170, price = 5000, color = Color3.fromRGB(90, 55, 35), shape = "Block", top = "None" },
	{ id = 15, name = "Cupcako Frostina", rarity = "Rare", income = 200, price = 6000, color = Color3.fromRGB(255, 200, 220), shape = "Cylinder", top = "Cherry" },
	{ id = 16, name = "Strudelo Stormo", rarity = "Epic", income = 260, price = 8000, color = Color3.fromRGB(220, 170, 100), shape = "Block", top = "None" },
	{ id = 17, name = "Baklava Blaze", rarity = "Epic", income = 330, price = 11000, color = Color3.fromRGB(230, 190, 90), shape = "Block", top = "None" },
	{ id = 18, name = "Profiterole Pop", rarity = "Epic", income = 420, price = 14000, color = Color3.fromRGB(245, 220, 170), shape = "Ball", top = "Cherry" },
	{ id = 19, name = "Scone-o Saurus", rarity = "Epic", income = 520, price = 18000, color = Color3.fromRGB(205, 160, 100), shape = "Ball", top = "Hat" },
	{ id = 20, name = "Gelato Gigante", rarity = "Epic", income = 650, price = 23000, color = Color3.fromRGB(255, 220, 230), shape = "Cylinder", top = "Cherry" },
	{ id = 21, name = "Pannacotta Pounce", rarity = "Epic", income = 800, price = 28000, color = Color3.fromRGB(250, 240, 210), shape = "Cylinder", top = "None" },
	{ id = 22, name = "Souffle Supreme", rarity = "Legendary", income = 1200, price = 40000, color = Color3.fromRGB(255, 230, 150), shape = "Ball", top = "Hat" },
	{ id = 23, name = "Millefoglie Meteor", rarity = "Legendary", income = 1800, price = 60000, color = Color3.fromRGB(240, 210, 140), shape = "Block", top = "None" },
	{ id = 24, name = "Kouglof King", rarity = "Legendary", income = 2600, price = 90000, color = Color3.fromRGB(200, 150, 80), shape = "Cylinder", top = "Hat" },
	{ id = 25, name = "Basbousa Blaze", rarity = "Legendary", income = 3800, price = 130000, color = Color3.fromRGB(230, 170, 90), shape = "Block", top = "None" },
	{ id = 26, name = "Tres Leches Titan", rarity = "Legendary", income = 5500, price = 180000, color = Color3.fromRGB(250, 245, 220), shape = "Ball", top = "Candle" },
	{ id = 27, name = "Croquembouche Colossus", rarity = "Mythic", income = 8000, price = 250000, color = Color3.fromRGB(220, 170, 90), shape = "Ball", top = "Hat" },
	{ id = 28, name = "Opera Cake Overlord", rarity = "Mythic", income = 14000, price = 400000, color = Color3.fromRGB(90, 60, 40), shape = "Block", top = "Candle" },
	{ id = 29, name = "Stollen Star", rarity = "Mythic", income = 22000, price = 600000, color = Color3.fromRGB(255, 220, 120), shape = "Ball", top = "Hat" },
	{ id = 30, name = "Golden Doughnut Divino", rarity = "Secret", income = 45000, price = 900000, color = Color3.fromRGB(255, 200, 60), shape = "Cylinder", top = "Sprinkles" },
	{ id = 31, name = "Rainbow Babka Royale", rarity = "Secret", income = 90000, price = 1800000, color = Color3.fromRGB(255, 130, 210), shape = "Block", top = "Hat" },
	{ id = 32, name = "Il Grande Forno", rarity = "Boss", income = 310000, price = 5000000, color = Color3.fromRGB(200, 40, 40), shape = "Ball", top = "Hat" },
}

Catalog.COUNT = 32

function Catalog.getById(id)
	for _, entry in ipairs(Catalog.BRAINROTS) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function Catalog.getByRarity(rarity)
	local out = {}
	for _, entry in ipairs(Catalog.BRAINROTS) do
		if entry.rarity == rarity then
			table.insert(out, entry)
		end
	end
	return out
end

-- Weighted spawn pick: roll a rarity by weight, then a uniform brainrot of it.
function Catalog.pickRandom()
	local total = 0
	for _, rarity in ipairs(Catalog.RARITY_ORDER) do
		total = total + Catalog.RARITIES[rarity].weight
	end
	local roll = math.random() * total
	local picked = "Common"
	for _, rarity in ipairs(Catalog.RARITY_ORDER) do
		roll = roll - Catalog.RARITIES[rarity].weight
		if roll <= 0 then
			picked = rarity
			break
		end
	end
	local pool = Catalog.getByRarity(picked)
	return pool[math.random(1, #pool)]
end

-- Mutation rolled on purchase: None 70%, Golden 12%, Charred 8%, Rainbow 6%, Diamond 4%.
function Catalog.rollMutation()
	local roll = math.random() * 100
	if roll < 70 then
		return "None"
	elseif roll < 82 then
		return "Golden"
	elseif roll < 90 then
		return "Charred"
	elseif roll < 96 then
		return "Rainbow"
	else
		return "Diamond"
	end
end

-- Short money: 1500 -> $1.5K, 1400000 -> $1.40M, 250000000 -> $250.00M.
function Catalog.formatMoney(n)
	n = math.floor(n + 0.5)
	if n >= 1000000000 then
		return string.format("$%.2fB", n / 1000000000)
	elseif n >= 1000000 then
		return string.format("$%.2fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("$%.1fK", n / 1000)
	else
		return "$" .. tostring(n)
	end
end

return Catalog
