-- BakeryShop: the upgrade shop. Four tracks, five levels each (two for the
-- extra pedestal), costs doubling per level. The effects are read live: the
-- conveyor reads ovens, the income math reads income, the pedestal cap reads
-- pedestals, and the client reads feet through the state sync.

local Shop = {}

Shop.UPGRADES = {
	ovens = { name = "Faster Ovens", desc = "Brainrots roll off the line faster", maxLevel = 5, baseCost = 500 },
	income = { name = "Sweet Income", desc = "+10% money per second, per level", maxLevel = 5, baseCost = 750 },
	pedestals = { name = "Extra Pedestal", desc = "+1 pedestal on your stall", maxLevel = 2, baseCost = 2000 },
	feet = { name = "Swift Feet", desc = "+2 walk speed, per level", maxLevel = 5, baseCost = 400 },
}
Shop.ORDER = { "ovens", "income", "pedestals", "feet" }

function Shop.costOf(upgradeId, level)
	local def = Shop.UPGRADES[upgradeId]
	if not def then
		return nil
	end
	return def.baseCost * (2 ^ level)
end

function Shop.buy(state, upgradeId)
	local def = Shop.UPGRADES[upgradeId]
	if not def then
		return false, "No such upgrade."
	end
	local level = state.upgrades[upgradeId] or 0
	if level >= def.maxLevel then
		return false, "Already maxed out."
	end
	local cost = Shop.costOf(upgradeId, level)
	if state.cash < cost then
		return false, "Not enough cash."
	end
	state.cash = state.cash - cost
	state.upgrades[upgradeId] = level + 1
	return true, def.name .. " level " .. (level + 1) .. "!"
end

function Shop.walkSpeed(state)
	return 16 + 2 * (state.upgrades.feet or 0)
end

return Shop
