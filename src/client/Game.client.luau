-- Game.client.luau
-- The whole HUD plus the Rolling Pin hook: top bar, event banner, six
-- side buttons and their panels, carried bar, toasts, controls hint,
-- sprint, and re-arming the pin's Activated event on respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BakeryRemotes")
local catalog = remotes.GetCatalog:InvokeServer()

local state = nil
local serverWalk = 16
local sprinting = false
local burnPhase = "Calm"
local burnLeft = 0
local goldenOn = false
local goldenLeft = 0

-- ---------------------------------------------------------------- gui shell

local gui = Instance.new("ScreenGui")
gui.Name = "BakeryGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, name, size, pos, text, color, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.Parent = parent
	return l
end

local function panelFrame(parent, name, size, pos, color)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or Color3.fromRGB(30, 25, 20)
	f.BorderColor3 = Color3.fromRGB(255, 210, 60)
	f.BorderSizePixel = 2
	f.Parent = parent
	return f
end

-- Top bar, top-centre.
local topBar = panelFrame(gui, "TopBar", UDim2.new(0, 660, 0, 46), UDim2.new(0.5, -330, 0, 8), Color3.fromRGB(30, 25, 20))
local topLabel = label(topBar, "TopLabel", UDim2.new(1, -10, 1, -6), UDim2.new(0, 5, 0, 3), "$100", Color3.fromRGB(255, 220, 120))

-- Event banner under the top bar.
local banner = label(gui, "Banner", UDim2.new(0, 660, 0, 36), UDim2.new(0.5, -330, 0, 60), "", Color3.fromRGB(255, 80, 60))
banner.Visible = false
banner.BackgroundColor3 = Color3.fromRGB(60, 15, 15)
banner.BackgroundTransparency = 0.2
banner.BorderSizePixel = 0

-- Six side buttons on the right edge.
local side = Instance.new("Frame")
side.Name = "SideButtons"
side.Size = UDim2.new(0, 150, 0, 300)
side.Position = UDim2.new(1, -160, 0.5, -150)
side.BackgroundTransparency = 1
side.Parent = gui
local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 8)
sideLayout.Parent = side

local function sideButton(name, text)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(1, 0, 0, 42)
	b.BackgroundColor3 = Color3.fromRGB(90, 60, 25)
	b.BorderColor3 = Color3.fromRGB(255, 210, 60)
	b.BorderSizePixel = 2
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.Parent = side
	return b
end

local lockBtn = sideButton("LockBtn", "LOCK ($250)")
local rebirthBtn = sideButton("RebirthBtn", "REBIRTH")
local upgradesBtn = sideButton("UpgradesBtn", "UPGRADES")
local indexBtn = sideButton("IndexBtn", "INDEX 0/32")
local questsBtn = sideButton("QuestsBtn", "QUESTS")
local goalsBtn = sideButton("GoalsBtn", "GOALS")

-- Panels: one open at a time, X closes.
local panels = {}
local function makePanel(name, title)
	local f = panelFrame(gui, name, UDim2.new(0, 480, 0, 400), UDim2.new(0.5, -240, 0.5, -200))
	f.Visible = false
	local titleLabel = label(f, "Title", UDim2.new(1, -50, 0, 36), UDim2.new(0, 10, 0, 6), title, Color3.fromRGB(255, 220, 120))
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.new(0, 36, 0, 36)
	close.Position = UDim2.new(1, -42, 0, 6)
	close.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
	close.Text = "X"
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.TextScaled = true
	close.Font = Enum.Font.GothamBold
	close.Parent = f
	close.MouseButton1Click:Connect(function()
		f.Visible = false
	end)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rows"
	scroll.Size = UDim2.new(1, -16, 1, -52)
	scroll.Position = UDim2.new(0, 8, 0, 46)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = f
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scroll
	panels[name] = f
	return f, scroll
end

local upgradesPanel, upgradesRows = makePanel("UpgradesPanel", "UPGRADES")
local indexPanel, indexRows = makePanel("IndexPanel", "INDEX")
local questsPanel, questsRows = makePanel("QuestsPanel", "QUESTS")
local goalsPanel, goalsRows = makePanel("GoalsPanel", "GOALS")

local function openPanel(name)
	for key, f in pairs(panels) do
		f.Visible = key == name
	end
end

local function closePanels()
	for _, f in pairs(panels) do
		f.Visible = false
	end
end

local function clearRows(scroll)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function rowFrame(scroll)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -4, 0, 52)
	f.BackgroundColor3 = Color3.fromRGB(50, 40, 30)
	f.BorderSizePixel = 0
	f.Parent = scroll
	return f
end

-- ---------------------------------------------------------------- toasts

local toastFrame = Instance.new("Frame")
toastFrame.Name = "Toasts"
toastFrame.Size = UDim2.new(0, 480, 0, 140)
toastFrame.Position = UDim2.new(0.5, -240, 1, -210)
toastFrame.BackgroundTransparency = 1
toastFrame.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 4)
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.Parent = toastFrame

local function showToast(text)
	local count = 0
	for _, child in ipairs(toastFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			count += 1
		end
	end
	if count >= 4 then
		for _, child in ipairs(toastFrame:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 28)
	t.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
	t.BackgroundTransparency = 0.2
	t.BorderColor3 = Color3.fromRGB(255, 210, 60)
	t.BorderSizePixel = 1
	t.Text = text
	t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Parent = toastFrame
	task.delay(4, function()
		t:Destroy()
	end)
end

-- Carried bar, bottom-centre, only while carrying.
local carriedBar = label(gui, "CarriedBar", UDim2.new(0, 480, 0, 34), UDim2.new(0.5, -240, 1, -60), "", Color3.fromRGB(255, 220, 120))
carriedBar.BackgroundColor3 = Color3.fromRGB(60, 40, 15)
carriedBar.BackgroundTransparency = 0.2
carriedBar.Visible = false

-- Controls hint, bottom-left.
label(gui, "Hint", UDim2.new(0, 420, 0, 26), UDim2.new(0, 10, 1, -36),
	"WASD move - SHIFT sprint - Click a brainrot to buy - Click a pedestal to place or steal - Rolling Pin slaps",
	Color3.fromRGB(230, 230, 230))

-- ---------------------------------------------------------------- panel rows

local function rarityColor(name)
	for _, r in ipairs(catalog.Rarities) do
		if r.Name == name then
			return r.Color
		end
	end
	return Color3.fromRGB(255, 255, 255)
end

local function rebuildUpgrades()
	if not state then
		return
	end
	clearRows(upgradesRows)
	for _, u in ipairs(state.Upgrades) do
		local row = rowFrame(upgradesRows)
		label(row, "Name", UDim2.new(0, 200, 0, 24), UDim2.new(0, 8, 0, 4), u.Name .. "  Lv " .. u.Level .. "/" .. u.Max, Color3.fromRGB(255, 220, 120))
		label(row, "Desc", UDim2.new(0, 260, 0, 20), UDim2.new(0, 8, 0, 28), u.Desc, Color3.fromRGB(220, 220, 220))
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0, 110, 0, 36)
		buy.Position = UDim2.new(1, -118, 0, 8)
		buy.BackgroundColor3 = Color3.fromRGB(60, 120, 50)
		buy.Text = u.Cost and ("BUY $" .. tostring(u.Cost)) or "MAXED"
		buy.TextColor3 = Color3.fromRGB(255, 255, 255)
		buy.TextScaled = true
		buy.Font = Enum.Font.GothamBold
		buy.Parent = row
		local id = u.Id
		buy.MouseButton1Click:Connect(function()
			local ok, msg = remotes.BuyUpgrade:InvokeServer(id)
			showToast(msg)
		end)
	end
end

local function rebuildIndex()
	if not state then
		return
	end
	clearRows(indexRows)
	local owned = {}
	for _, id in ipairs(state.OwnedIds) do
		owned[id] = true
	end
	for i, b in ipairs(catalog.Brainrots) do
		local row = rowFrame(indexRows)
		label(row, "Name", UDim2.new(0, 230, 1, 0), UDim2.new(0, 8, 0, 0), i .. ". " .. b.Name, Color3.fromRGB(255, 255, 255))
		label(row, "Rarity", UDim2.new(0, 110, 1, 0), UDim2.new(0, 240, 0, 0), string.upper(b.Rarity), rarityColor(b.Rarity))
		label(row, "Income", UDim2.new(0, 90, 1, 0), UDim2.new(0, 350, 0, 0), "$" .. tostring(b.Income) .. "/s", Color3.fromRGB(90, 230, 110))
		if owned[i] then
			label(row, "Owned", UDim2.new(0, 60, 1, 0), UDim2.new(1, -66, 0, 0), "OWNED", Color3.fromRGB(90, 230, 110))
		else
			label(row, "Owned", UDim2.new(0, 60, 1, 0), UDim2.new(1, -66, 0, 0), "-", Color3.fromRGB(180, 180, 180))
		end
	end
end

local function rebuildQuests()
	if not state then
		return
	end
	clearRows(questsRows)
	for _, q in ipairs(state.Quests) do
		local row = rowFrame(questsRows)
		label(row, "Text", UDim2.new(0, 240, 0, 24), UDim2.new(0, 8, 0, 4), q.Text .. "  ($" .. tostring(q.Reward) .. ")", Color3.fromRGB(255, 255, 255))
		label(row, "Progress", UDim2.new(0, 240, 0, 20), UDim2.new(0, 8, 0, 28), q.Progress .. "/" .. q.Target, Color3.fromRGB(220, 220, 220))
		local claim = Instance.new("TextButton")
		claim.Size = UDim2.new(0, 110, 0, 36)
		claim.Position = UDim2.new(1, -118, 0, 8)
		claim.BackgroundColor3 = q.Claimed and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(60, 120, 50)
		claim.Text = q.Claimed and "DONE" or "CLAIM"
		claim.TextColor3 = Color3.fromRGB(255, 255, 255)
		claim.TextScaled = true
		claim.Font = Enum.Font.GothamBold
		claim.Parent = row
		local id = q.Id
		claim.MouseButton1Click:Connect(function()
			local ok, msg = remotes.ClaimQuest:InvokeServer(id)
			showToast(msg)
		end)
	end
end

local function rebuildGoals()
	if not state then
		return
	end
	clearRows(goalsRows)
	for _, g in ipairs(state.Goals) do
		local row = rowFrame(goalsRows)
		label(row, "Text", UDim2.new(0, 300, 1, 0), UDim2.new(0, 8, 0, 0), g.Text, Color3.fromRGB(255, 255, 255))
		local text = tostring(g.Progress) .. "/" .. tostring(g.Target)
		label(row, "Progress", UDim2.new(0, 130, 1, 0), UDim2.new(1, -138, 0, 0), text, g.Done and Color3.fromRGB(90, 230, 110) or Color3.fromRGB(220, 220, 220))
	end
end

local function refreshOpenPanel()
	if upgradesPanel.Visible then
		rebuildUpgrades()
	elseif indexPanel.Visible then
		rebuildIndex()
	elseif questsPanel.Visible then
		rebuildQuests()
	elseif goalsPanel.Visible then
		rebuildGoals()
	end
end

-- ---------------------------------------------------------------- state

local function updateBanner()
	if burnPhase == "Warning" then
		banner.Text = "BURN WAVE INCOMING - GET BACK TO YOUR STALL! " .. burnLeft .. "s"
		banner.TextColor3 = Color3.fromRGB(255, 180, 60)
		banner.Visible = true
	elseif burnPhase == "Burn" then
		banner.Text = "BURN WAVE! OFF YOUR STALL = DROP YOUR CATCH! " .. burnLeft .. "s"
		banner.TextColor3 = Color3.fromRGB(255, 80, 60)
		banner.Visible = true
	elseif goldenOn then
		banner.Text = "GOLDEN HOUR! PENS PAY X2 - " .. goldenLeft .. "s"
		banner.TextColor3 = Color3.fromRGB(255, 220, 60)
		banner.Visible = true
	else
		banner.Visible = false
	end
end

local function onState(newState)
	state = newState
	serverWalk = newState.WalkSpeed
	local lockText = ""
	if newState.LockLeft > 0 then
		lockText = "  |  LOCKED " .. newState.LockLeft .. "s"
	end
	topLabel.Text = "$" .. tostring(newState.Cash)
		.. "  |  $" .. tostring(newState.Income) .. "/s"
		.. "  |  Rebirths " .. newState.Rebirths .. " (x" .. newState.RebirthMult .. ")"
		.. "  |  Index " .. newState.IndexCount .. "/" .. newState.IndexTotal
		.. "  |  Stall " .. newState.Stall
		.. lockText
	lockBtn.Text = "LOCK ($" .. tostring(newState.LockCost) .. ")"
	rebirthBtn.Text = "REBIRTH ($" .. tostring(newState.RebirthCost) .. ")"
	indexBtn.Text = "INDEX " .. newState.IndexCount .. "/" .. newState.IndexTotal
	burnPhase = newState.BurnPhase
	burnLeft = newState.BurnLeft
	goldenOn = newState.GoldenOn
	goldenLeft = newState.GoldenLeft
	updateBanner()
	if newState.Carrying then
		carriedBar.Text = "CARRYING: " .. newState.Carrying.Name .. " ($" .. tostring(newState.Carrying.Income) .. "/s) - click YOUR pedestal to place it!"
		carriedBar.Visible = true
	else
		carriedBar.Visible = false
	end
	refreshOpenPanel()
end

remotes.StateSync.OnClientEvent:Connect(onState)
remotes.Toast.OnClientEvent:Connect(showToast)
remotes.ThreatUpdate.OnClientEvent:Connect(function(phase, left)
	burnPhase = phase
	burnLeft = left
	updateBanner()
end)
remotes.GoldenUpdate.OnClientEvent:Connect(function(on, left)
	goldenOn = on
	goldenLeft = left
	updateBanner()
end)

-- ---------------------------------------------------------------- buttons

lockBtn.MouseButton1Click:Connect(function()
	local ok, msg = remotes.LockBase:InvokeServer()
	showToast(msg)
end)
rebirthBtn.MouseButton1Click:Connect(function()
	local ok, msg = remotes.Rebirth:InvokeServer()
	showToast(msg)
end)
upgradesBtn.MouseButton1Click:Connect(function()
	if upgradesPanel.Visible then
		closePanels()
	else
		rebuildUpgrades()
		openPanel("UpgradesPanel")
	end
end)
indexBtn.MouseButton1Click:Connect(function()
	if indexPanel.Visible then
		closePanels()
	else
		rebuildIndex()
		openPanel("IndexPanel")
	end
end)
questsBtn.MouseButton1Click:Connect(function()
	if questsPanel.Visible then
		closePanels()
	else
		rebuildQuests()
		openPanel("QuestsPanel")
	end
end)
goalsBtn.MouseButton1Click:Connect(function()
	if goalsPanel.Visible then
		closePanels()
	else
		rebuildGoals()
		openPanel("GoalsPanel")
	end
end)

-- ---------------------------------------------------------------- sprint

local function applySpeed()
	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = serverWalk + (sprinting and 10 or 0)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = true
		applySpeed()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = false
		applySpeed()
	end
end)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	applySpeed()
end)

-- ---------------------------------------------------------------- rolling pin

local function armPin(tool)
	if not tool or not tool:IsA("Tool") then
		return
	end
	if tool.Name ~= "Rolling Pin" then
		return
	end
	if tool:GetAttribute("Armed") then
		return
	end
	tool:SetAttribute("Armed", true)
	tool.Activated:Connect(function()
		remotes.Slap:FireServer()
	end)
end

local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(armPin)
for _, tool in ipairs(backpack:GetChildren()) do
	armPin(tool)
end
player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(armPin)
	for _, tool in ipairs(char:GetChildren()) do
		armPin(tool)
	end
end)
if player.Character then
	player.Character.ChildAdded:Connect(armPin)
	for _, tool in ipairs(player.Character:GetChildren()) do
		armPin(tool)
	end
end
