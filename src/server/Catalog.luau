-- Catalog.luau
-- Data only: the 32 pastry brainrots, the 7 rarities, the 5 mutations,
-- a weighted spawn pick, a mutation roll, and a short-money formatter.
-- No game logic lives here.

local Catalog = {}

-- Rarities in order, with the label colour and the spawn weight.
Catalog.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(80, 200, 80), Weight = 45 },
	{ Name = "Rare", Color = Color3.fromRGB(80, 140, 255), Weight = 25 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 90, 255), Weight = 15 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 200, 40), Weight = 8 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 110, 200), Weight = 4 },
	{ Name = "Secret", Color = Color3.fromRGB(60, 220, 230), Weight = 2 },
	{ Name = "Boss", Color = Color3.fromRGB(255, 60, 60), Weight = 1 },
}

-- Mutations rolled when a brainrot is bought. Chance is out of 100.
-- Tint is the body colour override; nil means keep the base colour.
Catalog.Mutations = {
	{ Name = "", Mult = 1, Chance = 70, Tint = nil },
	{ Name = "Golden", Mult = 2, Chance = 12, Tint = Color3.fromRGB(255, 215, 0) },
	{ Name = "Charred", Mult = 1.5, Chance = 8, Tint = Color3.fromRGB(40, 30, 25) },
	{ Name = "Rainbow", Mult = 3, Chance = 6, Tint = Color3.fromRGB(255, 120, 200) },
	{ Name = "Diamond", Mult = 5, Chance = 4, Tint = Color3.fromRGB(180, 230, 255) },
}

-- The 32 brainrots, in id order. Shape is Ball, Block or Cylinder.
-- Topping is None, Cherry, Hat, Sprinkles or Candle.
Catalog.Brainrots = {
	{ Name = "Bready McDoughface", Rarity = "Common", Income = 5, Price = 50, Color = Color3.fromRGB(210, 180, 140), Shape = "Ball", Topping = "None" },
	{ Name = "Croissantio Crustini", Rarity = "Common", Income = 8, Price = 120, Color = Color3.fromRGB(255, 200, 90), Shape = "Block", Topping = "None" },
	{ Name = "Muffinella Munchkin", Rarity = "Common", Income = 12, Price = 200, Color = Color3.fromRGB(150, 100, 60), Shape = "Cylinder", Topping = "Cherry" },
	{ Name = "Bagelo Baguette", Rarity = "Common", Income = 15, Price = 300, Color = Color3.fromRGB(220, 190, 140), Shape = "Cylinder", Topping = "None" },
	{ Name = "Pretzelo Twisto", Rarity = "Common", Income = 18, Price = 400, Color = Color3.fromRGB(120, 75, 40), Shape = "Block", Topping = "None" },
	{ Name = "Donutto Dippio", Rarity = "Common", Income = 22, Price = 550, Color = Color3.fromRGB(255, 150, 200), Shape = "Cylinder", Topping = "Sprinkles" },
	{ Name = "Cookio Crumblo", Rarity = "Common", Income = 28, Price = 700, Color = Color3.fromRGB(110, 70, 40), Shape = "Ball", Topping = "None" },
	{ Name = "Wafflo Syrupo", Rarity = "Common", Income = 35, Price = 900, Color = Color3.fromRGB(255, 200, 90), Shape = "Block", Topping = "None" },
	{ Name = "Tiramisu Tornado", Rarity = "Rare", Income = 60, Price = 1500, Color = Color3.fromRGB(210, 180, 140), Shape = "Cylinder", Topping = "None" },
	{ Name = "Churro Churro", Rarity = "Rare", Income = 75, Price = 2000, Color = Color3.fromRGB(150, 100, 60), Shape = "Cylinder", Topping = "None" },
	{ Name = "Eclairo Flashio", Rarity = "Rare", Income = 90, Price = 2500, Color = Color3.fromRGB(110, 70, 40), Shape = "Block", Topping = "Cherry" },
	{ Name = "Cannoli Cannon", Rarity = "Rare", Income = 110, Price = 3200, Color = Color3.fromRGB(245, 230, 200), Shape = "Cylinder", Topping = "None" },
	{ Name = "Macaron Meltdown", Rarity = "Rare", Income = 140, Price = 4000, Color = Color3.fromRGB(255, 150, 200), Shape = "Ball", Topping = "None" },
	{ Name = "Brownie Bouncer", Rarity = "Rare", Income = 170, Price = 5000, Color = Color3.fromRGB(110, 70, 40), Shape = "Block", Topping = "None" },
	{ Name = "Cupcako Frostina", Rarity = "Rare", Income = 200, Price = 6000, Color = Color3.fromRGB(255, 200, 220), Shape = "Cylinder", Topping = "Cherry" },
	{ Name = "Strudelo Stormo", Rarity = "Epic", Income = 260, Price = 8000, Color = Color3.fromRGB(210, 180, 140), Shape = "Block", Topping = "None" },
	{ Name = "Baklava Blaze", Rarity = "Epic", Income = 330, Price = 11000, Color = Color3.fromRGB(255, 200, 90), Shape = "Block", Topping = "None" },
	{ Name = "Profiterole Pop", Rarity = "Epic", Income = 420, Price = 14000, Color = Color3.fromRGB(245, 230, 200), Shape = "Ball", Topping = "Cherry" },
	{ Name = "Scone-o Saurus", Rarity = "Epic", Income = 520, Price = 18000, Color = Color3.fromRGB(210, 180, 140), Shape = "Ball", Topping = "Hat" },
	{ Name = "Gelato Gigante", Rarity = "Epic", Income = 650, Price = 23000, Color = Color3.fromRGB(255, 200, 220), Shape = "Cylinder", Topping = "Cherry" },
	{ Name = "Pannacotta Pounce", Rarity = "Epic", Income = 800, Price = 28000, Color = Color3.fromRGB(245, 230, 200), Shape = "Cylinder", Topping = "None" },
	{ Name = "Souffle Supreme", Rarity = "Legendary", Income = 1200, Price = 40000, Color = Color3.fromRGB(255, 230, 160), Shape = "Ball", Topping = "Hat" },
	{ Name = "Millefoglie Meteor", Rarity = "Legendary", Income = 1800, Price = 60000, Color = Color3.fromRGB(210, 180, 140), Shape = "Block", Topping = "None" },
	{ Name = "Kouglof King", Rarity = "Legendary", Income = 2600, Price = 90000, Color = Color3.fromRGB(150, 100, 60), Shape = "Cylinder", Topping = "Hat" },
	{ Name = "Basbousa Blaze", Rarity = "Legendary", Income = 3800, Price = 130000, Color = Color3.fromRGB(255, 200, 90), Shape = "Block", Topping = "None" },
	{ Name = "Tres Leches Titan", Rarity = "Legendary", Income = 5500, Price = 180000, Color = Color3.fromRGB(245, 230, 200), Shape = "Ball", Topping = "Candle" },
	{ Name = "Croquembouche Colossus", Rarity = "Mythic", Income = 8000, Price = 250000, Color = Color3.fromRGB(255, 200, 90), Shape = "Ball", Topping = "Hat" },
	{ Name = "Opera Cake Overlord", Rarity = "Mythic", Income = 14000, Price = 400000, Color = Color3.fromRGB(110, 70, 40), Shape = "Block", Topping = "Candle" },
	{ Name = "Stollen Star", Rarity = "Mythic", Income = 22000, Price = 600000, Color = Color3.fromRGB(255, 215, 0), Shape = "Ball", Topping = "Hat" },
	{ Name = "Golden Doughnut Divino", Rarity = "Secret", Income = 45000, Price = 900000, Color = Color3.fromRGB(255, 215, 0), Shape = "Cylinder", Topping = "Sprinkles" },
	{ Name = "Rainbow Babka Royale", Rarity = "Secret", Income = 90000, Price = 1800000, Color = Color3.fromRGB(255, 150, 200), Shape = "Block", Topping = "Hat" },
	{ Name = "Il Grande Forno", Rarity = "Boss", Income = 310000, Price = 5000000, Color = Color3.fromRGB(255, 60, 60), Shape = "Ball", Topping = "Hat" },
}

-- Look a rarity up by name.
function Catalog.GetRarity(name)
	for _, r in ipairs(Catalog.Rarities) do
		if r.Name == name then
			return r
		end
	end
	return Catalog.Rarities[1]
end

-- Pick one brainrot, weighted by its rarity's spawn weight. Each
-- brainrot carries its rarity's full weight, so the total is the sum
-- over all 32 brainrots (682), not over the 7 rarities.
function Catalog.PickWeighted(rng)
	local total = 0
	for _, b in ipairs(Catalog.Brainrots) do
		total += Catalog.GetRarity(b.Rarity).Weight
	end
	local roll = rng:NextNumber() * total
	for _, b in ipairs(Catalog.Brainrots) do
		roll -= Catalog.GetRarity(b.Rarity).Weight
		if roll <= 0 then
			return b
		end
	end
	return Catalog.Brainrots[1]
end

-- Roll one mutation. The chances add to 100.
function Catalog.RollMutation(rng)
	local roll = rng:NextNumber() * 100
	local acc = 0
	for _, m in ipairs(Catalog.Mutations) do
		acc += m.Chance
		if roll <= acc then
			return m
		end
	end
	return Catalog.Mutations[1]
end

-- Short money: $850, $1.5K, $1.40M, $250.00M.
function Catalog.FormatMoney(n)
	n = math.floor(n + 0.5)
	if n >= 1000000 then
		return string.format("$%.2fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("$%.1fK", n / 1000)
	else
		return "$" .. tostring(n)
	end
end

return Catalog
