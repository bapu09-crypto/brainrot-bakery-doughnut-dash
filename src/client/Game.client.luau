-- Brainrot Bakery - Doughnut Dash (v6): the player's screen.
-- Top bar (cash / income / rebirths / index), side buttons (lock, rebirth,
-- upgrades, index, quests, goals), event banner, toasts, carried bar, and the
-- four panels. The 3D world is the game; this is only the glass over it.
-- The top bar sits top-CENTRE: Roblox's own menu buttons own the top-left.
--
-- SLAP HOOK (kept from v5): the Rolling Pin is a plain Tool the server hands
-- out with no script inside (a game server cannot write a script's Source at
-- runtime). This script watches for the "Rolling Pin" tool in the player's
-- Backpack or Character and connects its Activated event to the Slap
-- RemoteEvent, so clicking with the pin equipped fires the slap. The hook is
-- re-armed whenever the tool is re-added, including after respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BakeryRemotes")
local stateSync = remotes:WaitForChild("StateSync")
local toastEvent = remotes:WaitForChild("Toast")
local threatEvent = remotes:WaitForChild("ThreatUpdate")
local goldenEvent = remotes:WaitForChild("GoldenUpdate")
local slapEvent = remotes:WaitForChild("Slap")
local getCatalog = remotes:WaitForChild("GetCatalog")
local buyUpgrade = remotes:WaitForChild("BuyUpgrade")
local claimQuest = remotes:WaitForChild("ClaimQuest")
local lockBase = remotes:WaitForChild("LockBase")
local rebirthFn = remotes:WaitForChild("Rebirth")

local catalog = getCatalog:InvokeServer()

local baseWalk = 16
local sprinting = false
local threatPhase = "calm"
local threatLeft = 0
local goldenActive = false
local goldenLeft = 0

local function formatMoney(n)
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

-- ---------- Rolling Pin slap hook ----------

-- The server hands out a scriptless Tool, so the client owns the click:
-- activating the pin fires the Slap remote. Re-arms whenever the tool is
-- (re-)added to the Backpack or the Character, including after respawn.
local hookedPin = nil
local function hookRollingPin(tool)
	if not tool or not tool:IsA("Tool") or tool.Name ~= "Rolling Pin" then
		return
	end
	if hookedPin == tool then
		return
	end
	hookedPin = tool
	tool.Activated:Connect(function()
		slapEvent:FireServer()
	end)
end

local function scanForPin()
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		hookRollingPin(backpack:FindFirstChild("Rolling Pin"))
	end
	local character = player.Character
	if character then
		hookRollingPin(character:FindFirstChild("Rolling Pin"))
	end
end

player.CharacterAdded:Connect(function(character)
	hookedPin = nil
	task.wait(0.5)
	scanForPin()
	character.ChildAdded:Connect(function(child)
		hookRollingPin(child)
	end)
end)

task.spawn(function()
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(child)
		hookRollingPin(child)
	end)
	scanForPin()
end)

-- ---------- GUI skeleton ----------

local gui = Instance.new("ScreenGui")
gui.Name = "BakeryGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local function makeFrame(parent, name, size, position, anchor, color, transparency)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	if anchor then
		f.AnchorPoint = anchor
	end
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0.25
	f.BorderSizePixel = 2
	f.BorderColor3 = Color3.fromRGB(255, 220, 150)
	f.Parent = parent
	return f
end

local function makeLabel(parent, name, text, size, position, textSize, color, bold)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize
	label.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, size, position, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color
	b.BorderSizePixel = 2
	b.BorderColor3 = Color3.fromRGB(255, 255, 255)
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextSize = 18
	b.Font = Enum.Font.SourceSansBold
	b.Parent = parent
	return b
end

-- Top bar, top-centre.
local topBar = makeFrame(gui, "TopBar", UDim2.new(0, 560, 0, 62), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0), Color3.fromRGB(30, 20, 14), 0.2)
local cashLabel = makeLabel(topBar, "Cash", "$100", UDim2.new(0, 200, 0, 40), UDim2.new(0, 14, 0, 4), 32, Color3.fromRGB(255, 220, 90), true)
local incomeLabel = makeLabel(topBar, "Income", "+$0/s", UDim2.new(0, 200, 0, 20), UDim2.new(0, 14, 0, 40), 16, Color3.fromRGB(140, 255, 140), true)
local rebirthLabel = makeLabel(topBar, "Rebirths", "Rebirths 0 (x1)", UDim2.new(0, 160, 0, 20), UDim2.new(0, 220, 0, 8), 16, Color3.fromRGB(255, 255, 255), true)
local indexLabel = makeLabel(topBar, "Index", "Index 0/32", UDim2.new(0, 160, 0, 20), UDim2.new(0, 220, 0, 32), 16, Color3.fromRGB(255, 255, 255), true)
local stallLabel = makeLabel(topBar, "Stall", "STALL 1", UDim2.new(0, 120, 0, 20), UDim2.new(0, 400, 0, 8), 16, Color3.fromRGB(255, 200, 120), true)
local lockLabel = makeLabel(topBar, "Lock", "", UDim2.new(0, 120, 0, 20), UDim2.new(0, 400, 0, 32), 16, Color3.fromRGB(255, 120, 120), true)

-- Event banner under the top bar.
local banner = makeFrame(gui, "Banner", UDim2.new(0, 560, 0, 44), UDim2.new(0.5, 0, 0, 78), Vector2.new(0.5, 0), Color3.fromRGB(150, 40, 20), 0.1)
banner.Visible = false
local bannerLabel = makeLabel(banner, "BannerText", "", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), 22, Color3.fromRGB(255, 255, 255), true)
bannerLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Side buttons, right edge.
local sideButtons = makeFrame(gui, "SideButtons", UDim2.new(0, 168, 0, 300), UDim2.new(1, -12, 0.5, -150), Vector2.new(1, 0), Color3.fromRGB(0, 0, 0), 1)
sideButtons.BorderSizePixel = 0
local lockButton = makeButton(sideButtons, "LockButton", "LOCK ($250)", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 0), Color3.fromRGB(200, 60, 60))
local rebirthButton = makeButton(sideButtons, "RebirthButton", "REBIRTH", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 52), Color3.fromRGB(140, 60, 200))
local upgradesButton = makeButton(sideButtons, "UpgradesButton", "UPGRADES", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 104), Color3.fromRGB(60, 120, 220))
local indexButton = makeButton(sideButtons, "IndexButton", "INDEX 0/32", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 156), Color3.fromRGB(60, 180, 90))
local questsButton = makeButton(sideButtons, "QuestsButton", "QUESTS", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 208), Color3.fromRGB(220, 150, 40))
local goalsButton = makeButton(sideButtons, "GoalsButton", "GOALS", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 260), Color3.fromRGB(200, 90, 160))

-- Carried bar, bottom-centre.
local carriedBar = makeFrame(gui, "CarriedBar", UDim2.new(0, 520, 0, 40), UDim2.new(0.5, 0, 1, -96), Vector2.new(0.5, 0), Color3.fromRGB(40, 90, 40), 0.1)
carriedBar.Visible = false
local carriedLabel = makeLabel(carriedBar, "CarriedText", "", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), 18, Color3.fromRGB(255, 255, 255), true)
carriedLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Toasts, bottom-centre above the carried bar.
local toastFrame = Instance.new("Frame")
toastFrame.Name = "Toasts"
toastFrame.Size = UDim2.new(0, 520, 0, 120)
toastFrame.Position = UDim2.new(0.5, 0, 1, -220)
toastFrame.AnchorPoint = Vector2.new(0.5, 0)
toastFrame.BackgroundTransparency = 1
toastFrame.Parent = gui

-- Controls hint, bottom-left.
local hint = makeLabel(gui, "Hint", "WASD move  -  SHIFT sprint  -  Click a brainrot to buy  -  Click a pedestal to place or steal  -  Rolling Pin slaps", UDim2.new(0, 620, 0, 20), UDim2.new(0, 12, 1, -28), 14, Color3.fromRGB(255, 255, 255), false)
hint.BackgroundTransparency = 0.5
hint.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

-- ---------- Panels ----------

local panels = {}
local function makePanel(name, title)
	local panel = makeFrame(gui, name, UDim2.new(0, 480, 0, 430), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5), Color3.fromRGB(25, 18, 12), 0.05)
	panel.Visible = false
	makeLabel(panel, "Title", title, UDim2.new(1, -60, 0, 36), UDim2.new(0, 12, 0, 6), 24, Color3.fromRGB(255, 220, 130), true)
	local close = makeButton(panel, "Close", "X", UDim2.new(0, 36, 0, 36), UDim2.new(1, -44, 0, 6), Color3.fromRGB(180, 50, 50))
	close.TextSize = 20
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -16, 1, -52)
	body.Position = UDim2.new(0, 8, 0, 46)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.CanvasSize = UDim2.new(0, 0, 0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = panel
	panels[name] = panel
	return panel, body
end

local _, upgradesBody = makePanel("UpgradesPanel", "UPGRADES")
local _, indexBody = makePanel("IndexPanel", "BAKERY INDEX")
local _, questsBody = makePanel("QuestsPanel", "QUESTS - CONTRACTS")
local _, goalsBody = makePanel("GoalsPanel", "GOALS")

local function togglePanel(name)
	for panelName, panel in pairs(panels) do
		if panelName == name then
			panel.Visible = not panel.Visible
		else
			panel.Visible = false
		end
	end
end

upgradesButton.MouseButton1Click:Connect(function() togglePanel("UpgradesPanel") end)
indexButton.MouseButton1Click:Connect(function() togglePanel("IndexPanel") end)
questsButton.MouseButton1Click:Connect(function() togglePanel("QuestsPanel") end)
goalsButton.MouseButton1Click:Connect(function() togglePanel("GoalsPanel") end)

-- ---------- Panel contents ----------

-- Upgrades (mirrors BakeryShop's four tracks; costs come from the server).
local UPGRADE_DEFS = {
	{ id = "ovens", name = "Faster Ovens", desc = "Brainrots roll off the line faster" },
	{ id = "income", name = "Sweet Income", desc = "+10% money per second, per level" },
	{ id = "pedestals", name = "Extra Pedestal", desc = "+1 pedestal on your stall" },
	{ id = "feet", name = "Swift Feet", desc = "+2 walk speed, per level" },
}
local UPGRADE_MAX = { ovens = 5, income = 5, pedestals = 2, feet = 5 }
local upgradeRows = {}
for i, def in ipairs(UPGRADE_DEFS) do
	local row = makeFrame(upgradesBody, "Row_" .. def.id, UDim2.new(1, 0, 0, 64), UDim2.new(0, 0, 0, (i - 1) * 70), nil, Color3.fromRGB(50, 38, 26), 0.3)
	makeLabel(row, "Name", def.name, UDim2.new(1, -120, 0, 22), UDim2.new(0, 8, 0, 4), 18, Color3.fromRGB(255, 255, 255), true)
	makeLabel(row, "Desc", def.desc, UDim2.new(1, -120, 0, 18), UDim2.new(0, 8, 0, 26), 14, Color3.fromRGB(220, 220, 220), false)
	local levelLabel = makeLabel(row, "Level", "Lv 0/5", UDim2.new(0, 100, 0, 20), UDim2.new(0, 8, 0, 42), 14, Color3.fromRGB(255, 220, 130), true)
	local buy = makeButton(row, "Buy", "BUY", UDim2.new(0, 100, 0, 40), UDim2.new(1, -108, 0, 12), Color3.fromRGB(60, 160, 80))
	buy.MouseButton1Click:Connect(function()
		local _, msg = buyUpgrade:InvokeServer(def.id)
		showToast(msg)
	end)
	upgradeRows[def.id] = { row = row, levelLabel = levelLabel, buy = buy }
end

-- Index (32 rows from the catalog).
local indexRows = {}
for i, entry in ipairs(catalog.brainrots) do
	local row = makeFrame(indexBody, "Row_" .. entry.id, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, (i - 1) * 34), nil, Color3.fromRGB(50, 38, 26), 0.4)
	local rarityColor = catalog.rarities[entry.rarity].color
	makeLabel(row, "Name", entry.id .. ". " .. entry.name, UDim2.new(0, 260, 0, 30), UDim2.new(0, 8, 0, 0), 15, Color3.fromRGB(255, 255, 255), true)
	makeLabel(row, "Rarity", string.upper(entry.rarity), UDim2.new(0, 90, 0, 30), UDim2.new(0, 268, 0, 0), 14, rarityColor, true)
	makeLabel(row, "Income", formatMoney(entry.income) .. "/s", UDim2.new(0, 80, 0, 30), UDim2.new(0, 358, 0, 0), 14, Color3.fromRGB(140, 255, 140), true)
	local ownedLabel = makeLabel(row, "Owned", "-", UDim2.new(0, 30, 0, 30), UDim2.new(1, -34, 0, 0), 16, Color3.fromRGB(255, 255, 255), true)
	ownedLabel.TextXAlignment = Enum.TextXAlignment.Center
	indexRows[entry.id] = ownedLabel
end

-- Quests (mirrors BakeryQuests' six contracts; progress comes from the server).
local QUEST_DEFS = {
	{ id = "buy3", text = "Buy 3 brainrots", target = 3, reward = 150 },
	{ id = "lock1", text = "Lock your gate", target = 1, reward = 100 },
	{ id = "rare1", text = "Pen a RARE or better", target = 1, reward = 400 },
	{ id = "steal1", text = "Steal a brainrot", target = 1, reward = 500 },
	{ id = "rebirth1", text = "Rebirth once", target = 1, reward = 1000 },
	{ id = "own6", text = "Own 6 brainrots", target = 6, reward = 750 },
}
local questRows = {}
for i, def in ipairs(QUEST_DEFS) do
	local row = makeFrame(questsBody, "Row_" .. def.id, UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, (i - 1) * 62), nil, Color3.fromRGB(50, 38, 26), 0.3)
	makeLabel(row, "Text", def.text .. "  (" .. formatMoney(def.reward) .. ")", UDim2.new(1, -120, 0, 22), UDim2.new(0, 8, 0, 4), 17, Color3.fromRGB(255, 255, 255), true)
	local progressLabel = makeLabel(row, "Progress", "0/" .. def.target, UDim2.new(1, -120, 0, 18), UDim2.new(0, 8, 0, 28), 14, Color3.fromRGB(220, 220, 220), false)
	local claim = makeButton(row, "Claim", "CLAIM", UDim2.new(0, 100, 0, 36), UDim2.new(1, -108, 0, 10), Color3.fromRGB(60, 160, 80))
	claim.MouseButton1Click:Connect(function()
		local _, msg = claimQuest:InvokeServer(def.id)
		showToast(msg)
	end)
	questRows[def.id] = { progressLabel = progressLabel, claim = claim }
end

-- Goals (text + progress come from the server).
local goalRows = {}
local function refreshGoals(goals)
	for i, goal in ipairs(goals) do
		local row = goalRows[i]
		if not row then
			row = makeFrame(goalsBody, "Goal_" .. i, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, (i - 1) * 46), nil, Color3.fromRGB(50, 38, 26), 0.3)
			row.Name = "Goal_" .. i
			local textLabel = makeLabel(row, "Text", goal.text, UDim2.new(0, 300, 0, 40), UDim2.new(0, 8, 0, 0), 16, Color3.fromRGB(255, 255, 255), true)
			local progressLabel = makeLabel(row, "Progress", "", UDim2.new(0, 120, 0, 40), UDim2.new(1, -128, 0, 0), 16, Color3.fromRGB(255, 220, 130), true)
			progressLabel.TextXAlignment = Enum.TextXAlignment.Right
			goalRows[i] = { textLabel = textLabel, progressLabel = progressLabel }
			row = goalRows[i]
		end
		row.textLabel.Text = goal.text
		row.progressLabel.Text = tostring(goal.progress) .. "/" .. tostring(goal.target)
		if goal.progress >= goal.target then
			row.progressLabel.TextColor3 = Color3.fromRGB(140, 255, 140)
		else
			row.progressLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
		end
	end
end

-- ---------- Toasts ----------

function showToast(text)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 26)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundColor3 = Color3.fromRGB(20, 14, 10)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 1
	label.BorderColor3 = Color3.fromRGB(255, 220, 150)
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 15
	label.Font = Enum.Font.SourceSansBold
	label.Parent = toastFrame
	local count = 0
	for _, child in ipairs(toastFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			count = count + 1
			child.LayoutOrder = count - 1
			child.Position = UDim2.new(0, 0, 0, (count - 1) * 30)
		end
	end
	while count > 4 do
		local oldest = nil
		for _, child in ipairs(toastFrame:GetChildren()) do
			if child:IsA("TextLabel") and (not oldest or child.LayoutOrder < oldest.LayoutOrder) then
				oldest = child
			end
		end
		if oldest then
			oldest:Destroy()
		end
		count = count - 1
	end
	task.delay(4, function()
		if label.Parent then
			label:Destroy()
		end
	end)
end

-- ---------- Banner ----------

local function refreshBanner()
	if threatPhase == "warning" then
		banner.Visible = true
		banner.BackgroundColor3 = Color3.fromRGB(180, 60, 20)
		bannerLabel.Text = "BURN WAVE INCOMING - GET BACK TO YOUR STALL! " .. threatLeft .. "s"
	elseif threatPhase == "burn" then
		banner.Visible = true
		banner.BackgroundColor3 = Color3.fromRGB(200, 30, 10)
		bannerLabel.Text = "BURN WAVE! OFF YOUR STALL = DROP YOUR CATCH! " .. threatLeft .. "s"
	elseif goldenActive then
		banner.Visible = true
		banner.BackgroundColor3 = Color3.fromRGB(180, 140, 20)
		bannerLabel.Text = "GOLDEN HOUR! PENS PAY X2 - " .. goldenLeft .. "s"
	else
		banner.Visible = false
	end
end

-- ---------- State sync ----------

local function applyState(state)
	cashLabel.Text = formatMoney(state.cash)
	incomeLabel.Text = "+" .. formatMoney(state.income) .. "/s"
	rebirthLabel.Text = "Rebirths " .. state.rebirths .. " (x" .. (2 ^ state.rebirths) .. ")"
	indexLabel.Text = "Index " .. state.indexCount .. "/" .. state.indexTotal
	stallLabel.Text = "STALL " .. state.plotIndex
	if state.lockLeft > 0 then
		lockLabel.Text = "LOCKED " .. state.lockLeft .. "s"
		lockButton.Text = "LOCKED " .. state.lockLeft .. "s"
	else
		lockLabel.Text = ""
		lockButton.Text = "LOCK ($" .. state.lockCost .. ")"
	end
	rebirthButton.Text = "REBIRTH (" .. formatMoney(state.rebirthCost) .. ")"
	indexButton.Text = "INDEX " .. state.indexCount .. "/" .. state.indexTotal
	baseWalk = state.walkSpeed
	if state.carried then
		carriedBar.Visible = true
		carriedLabel.Text = "CARRYING: " .. state.carried.name .. " (" .. formatMoney(state.carried.income) .. "/s) - click YOUR pedestal to place it!"
	else
		carriedBar.Visible = false
	end
	for id, row in pairs(upgradeRows) do
		local level = state.upgrades[id] or 0
		local maxLevel = UPGRADE_MAX[id]
		row.levelLabel.Text = "Lv " .. level .. "/" .. maxLevel
		if level >= maxLevel then
			row.buy.Text = "MAXED"
		else
			row.buy.Text = "BUY " .. formatMoney(state.upgradeCosts[id])
		end
	end
	for id, ownedLabel in pairs(indexRows) do
		if state.indexOwned[id] then
			ownedLabel.Text = "OWNED"
			ownedLabel.TextColor3 = Color3.fromRGB(140, 255, 140)
		else
			ownedLabel.Text = "-"
			ownedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end
	for id, row in pairs(questRows) do
		local q = state.quests[id]
		if q then
			local target = 1
			for _, def in ipairs(QUEST_DEFS) do
				if def.id == id then
					target = def.target
				end
			end
			row.progressLabel.Text = tostring(q.progress) .. "/" .. tostring(target)
			if q.claimed then
				row.claim.Text = "DONE"
			elseif q.progress >= target then
				row.claim.Text = "CLAIM"
			else
				row.claim.Text = "CLAIM"
			end
		end
	end
	refreshGoals(state.goals)
	threatPhase = state.threatPhase
	threatLeft = state.threatLeft
	goldenActive = state.goldenActive
	goldenLeft = state.goldenLeft
	refreshBanner()
end

stateSync.OnClientEvent:Connect(applyState)
toastEvent.OnClientEvent:Connect(showToast)
threatEvent.OnClientEvent:Connect(function(phase, secondsLeft)
	threatPhase = phase
	threatLeft = secondsLeft
	refreshBanner()
end)
goldenEvent.OnClientEvent:Connect(function(active, secondsLeft)
	goldenActive = active
	goldenLeft = secondsLeft
	refreshBanner()
end)

lockButton.MouseButton1Click:Connect(function()
	local _, msg = lockBase:InvokeServer()
	showToast(msg)
end)

rebirthButton.MouseButton1Click:Connect(function()
	local _, msg = rebirthFn:InvokeServer()
	showToast(msg)
end)

-- ---------- Sprint ----------

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = false
	end
end)

local function bindHumanoid()
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	RunService.Heartbeat:Connect(function()
		if humanoid.Parent then
			local target = baseWalk
			if sprinting then
				target = baseWalk + 10
			end
			if humanoid.WalkSpeed ~= target then
				humanoid.WalkSpeed = target
			end
		end
	end)
end
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	bindHumanoid()
end)
if player.Character then
	bindHumanoid()
end

gui.Parent = player:WaitForChild("PlayerGui")
showToast("Welcome to Doughnut Dash Bakery! Buy a brainrot off the conveyor!")
