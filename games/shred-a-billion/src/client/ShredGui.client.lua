-- Shred a Billion: 画面（お金・10億までのバー・強化・粉砕の演出・お知らせ）
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ShredConfig = require(ReplicatedStorage:WaitForChild("ShredConfig"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local remotes = ReplicatedStorage:WaitForChild("ShredRemotes")
local notifyRemote = remotes:WaitForChild("Notify")
local shreddedRemote = remotes:WaitForChild("Shredded")
local actionRemote = remotes:WaitForChild("Action")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local language = Locale.GetLanguage(player)

local function L(key, ...)
	return Locale.Get(language, key, ...)
end

-- 1234 -> "1,234"、12345678 -> "12.35M"、1e9 -> "1.00B"
local function money(n)
	n = math.floor(n or 0)
	if n < 100000 then
		local s = string.format("%d", n)
		local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if formatted:sub(1, 1) == "," then
			formatted = formatted:sub(2)
		end
		return formatted
	end
	local units = { "K", "M", "B", "T", "Qa", "Qi" }
	local value, i = n / 1000, 1
	while value >= 1000 and i < #units do
		value = value / 1000
		i = i + 1
	end
	return string.format("%.2f", value) .. units[i]
end

local PANEL = Color3.fromRGB(25, 25, 40)
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 215, 80)

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local screen = Instance.new("ScreenGui")
screen.Name = "ShredGui"
screen.ResetOnSpawn = false

local moneyLabel = Instance.new("TextLabel")
moneyLabel.AnchorPoint = Vector2.new(0.5, 0)
moneyLabel.Position = UDim2.new(0.5, 0, 0, 10)
moneyLabel.Size = UDim2.new(0, 300, 0, 52)
moneyLabel.BackgroundColor3 = PANEL
moneyLabel.BackgroundTransparency = 0.25
moneyLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
moneyLabel.TextScaled = true
moneyLabel.Font = Enum.Font.GothamBlack
moneyLabel.Parent = screen
corner(moneyLabel, 12)

-- 10億までのバー
local goalBar = Instance.new("Frame")
goalBar.AnchorPoint = Vector2.new(0.5, 0)
goalBar.Position = UDim2.new(0.5, 0, 0, 66)
goalBar.Size = UDim2.new(0, 520, 0, 30)
goalBar.BackgroundColor3 = PANEL
goalBar.BackgroundTransparency = 0.2
goalBar.Parent = screen
corner(goalBar, 10)
local goalFill = Instance.new("Frame")
goalFill.Size = UDim2.new(0, 0, 1, 0)
goalFill.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
goalFill.BorderSizePixel = 0
goalFill.Parent = goalBar
corner(goalFill, 10)
local goalText = Instance.new("TextLabel")
goalText.Size = UDim2.new(1, 0, 1, 0)
goalText.BackgroundTransparency = 1
goalText.TextColor3 = WHITE
goalText.TextStrokeTransparency = 0.3
goalText.TextScaled = true
goalText.Font = Enum.Font.GothamBlack
goalText.ZIndex = 2
goalText.Parent = goalBar

local rateLabel = Instance.new("TextLabel")
rateLabel.AnchorPoint = Vector2.new(0.5, 0)
rateLabel.Position = UDim2.new(0.5, 0, 0, 100)
rateLabel.Size = UDim2.new(0, 520, 0, 22)
rateLabel.BackgroundTransparency = 1
rateLabel.TextColor3 = WHITE
rateLabel.TextStrokeTransparency = 0.4
rateLabel.TextScaled = true
rateLabel.Font = Enum.Font.GothamBold
rateLabel.Parent = screen

-- 左: 強化・転生・招待
local function makeButton(colorValue, y, height, onClick)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.Position = UDim2.new(0, 16, 0.5, y)
	b.Size = UDim2.new(0, 230, 0, height)
	b.BackgroundColor3 = colorValue
	b.TextColor3 = WHITE
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.Parent = screen
	corner(b, 12)
	b.Activated:Connect(onClick)
	return b
end

local upgradeButtons = {}
local colors = {
	power = Color3.fromRGB(220, 70, 60),
	blade = Color3.fromRGB(70, 120, 255),
	spawn = Color3.fromRGB(46, 160, 80),
	feeder = Color3.fromRGB(230, 150, 30),
}
for i, upgradeId in ipairs(ShredConfig.UpgradeOrder) do
	upgradeButtons[upgradeId] = makeButton(colors[upgradeId], -170 + (i - 1) * 64, 56, function()
		actionRemote:FireServer("upgrade", upgradeId)
	end)
end
local rebirthButton = makeButton(Color3.fromRGB(150, 70, 220), 92, 56, function()
	actionRemote:FireServer("rebirth")
end)
local inviteButton = makeButton(Color3.fromRGB(230, 80, 150), 152, 40, function()
	pcall(function()
		SocialService:PromptGameInvite(player)
	end)
end)
inviteButton.Text = L("invite")
inviteButton.Visible = false
task.spawn(function()
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	inviteButton.Visible = ok and can == true
end)

local nextLabel = Instance.new("TextLabel")
nextLabel.AnchorPoint = Vector2.new(0, 0.5)
nextLabel.Position = UDim2.new(0, 16, 0.5, -212)
nextLabel.Size = UDim2.new(0, 260, 0, 26)
nextLabel.BackgroundTransparency = 1
nextLabel.TextColor3 = GOLD
nextLabel.TextStrokeTransparency = 0.3
nextLabel.TextScaled = true
nextLabel.TextXAlignment = Enum.TextXAlignment.Left
nextLabel.Font = Enum.Font.GothamBold
nextLabel.Parent = screen

local function update()
	local stats = player:FindFirstChild("leaderstats")
	local moneyValue = stats and stats:FindFirstChild("Money")
	local rebirthValue = stats and stats:FindFirstChild("Rebirths")
	local cash = moneyValue and moneyValue.Value or 0
	local rebirths = rebirthValue and rebirthValue.Value or 0
	local goal = ShredConfig.Goal(rebirths)

	moneyLabel.Text = L("money", money(cash))
	local progress = math.clamp(cash / goal, 0, 1)
	goalFill.Size = UDim2.new(progress, 0, 1, 0)
	if progress >= 1 then
		goalText.Text = L("goal_done", rebirths + 2)
		goalFill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
	else
		goalText.Text = L("goal", money(cash), money(goal))
		goalFill.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	end

	local powerLevel = player:GetAttribute("Upgrades_power") or 0
	rateLabel.Text = L("rate", string.format("%.1f", ShredConfig.ShredPower(powerLevel)), player:GetAttribute("Multiplier") or 1)

	for upgradeId, b in pairs(upgradeButtons) do
		local level = player:GetAttribute("Upgrades_" .. upgradeId) or 0
		if level >= ShredConfig.Upgrades[upgradeId].maxLevel then
			b.Text = L("upgrade_" .. upgradeId, level, L("upgrade_max"))
			b.BackgroundTransparency = 0.4
		else
			local cost = ShredConfig.UpgradeCost(upgradeId, level)
			b.Text = L("upgrade_" .. upgradeId, level, money(cost))
			b.BackgroundTransparency = cash >= cost and 0 or 0.4
		end
	end
	rebirthButton.Text = L("rebirth", money(goal))
	rebirthButton.BackgroundTransparency = cash >= goal and 0 or 0.4

	local nextItem
	for _, item in ipairs(ShredConfig.Items) do
		if item.unlock > powerLevel then
			nextItem = item
			break
		end
	end
	nextLabel.Text = nextItem and L("next_unlock", L("item_" .. nextItem.id), nextItem.unlock) or ""
end
task.spawn(function()
	while true do
		update()
		task.wait(0.2)
	end
end)

---------------------------------------------------------------------
-- 粉砕したとき: 画面に「+$N」が飛び出して音が鳴る
---------------------------------------------------------------------
local sound = Instance.new("Sound")
sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
sound.Volume = 0.35
sound.Parent = SoundService
local rng = Random.new()

shreddedRemote.OnClientEvent:Connect(function(itemId, amount)
	sound.PlaybackSpeed = 0.9 + rng:NextNumber(0, 0.5)
	SoundService:PlayLocalSound(sound)
	local popup = Instance.new("TextLabel")
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.new(0.5 + rng:NextNumber(-0.1, 0.1), 0, 0.6, 0)
	popup.Size = UDim2.new(0, 260, 0, 54)
	popup.BackgroundTransparency = 1
	popup.Text = "+$" .. money(amount)
	popup.TextColor3 = Color3.fromRGB(120, 255, 150)
	popup.TextStrokeTransparency = 0
	popup.TextScaled = true
	popup.Font = Enum.Font.GothamBlack
	popup.Parent = screen
	local tween = TweenService:Create(popup, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position - UDim2.new(0, 0, 0.15, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
	tween:Play()
end)

---------------------------------------------------------------------
-- お知らせ
---------------------------------------------------------------------
local toastArea = Instance.new("Frame")
toastArea.AnchorPoint = Vector2.new(0.5, 0)
toastArea.Position = UDim2.new(0.5, 0, 0, 126)
toastArea.Size = UDim2.new(0, 540, 0, 110)
toastArea.BackgroundTransparency = 1
toastArea.Parent = screen
local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 4)
toastLayout.Parent = toastArea

local toastCount = 0
local function showToast(text, colorValue)
	toastCount = toastCount + 1
	local toast = Instance.new("TextLabel")
	toast.LayoutOrder = toastCount
	toast.Size = UDim2.new(1, 0, 0, 32)
	toast.BackgroundColor3 = PANEL
	toast.BackgroundTransparency = 0.15
	toast.TextColor3 = colorValue or WHITE
	toast.TextScaled = true
	toast.Font = Enum.Font.GothamBold
	toast.Text = text
	toast.Parent = toastArea
	corner(toast, 10)
	local list = {}
	for _, child in ipairs(toastArea:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(list, child)
		end
	end
	if #list > 3 then
		table.sort(list, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		list[1]:Destroy()
	end
	task.delay(4, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

notifyRemote.OnClientEvent:Connect(function(key, colorValue, ...)
	local count = select("#", ...)
	local args = { ... }
	for i = 1, count do
		if type(args[i]) == "number" and args[i] == math.floor(args[i]) then
			args[i] = money(args[i])
		elseif type(args[i]) == "string" and string.sub(args[i], 1, 1) == "@" then
			args[i] = L(string.sub(args[i], 2))
		end
	end
	showToast(L(key, table.unpack(args, 1, count)), colorValue)
end)

---------------------------------------------------------------------
-- 物の名札・トラックの HP・土地の看板を自分の言語に
---------------------------------------------------------------------
local function relabel(object)
	if not object:IsA("TextLabel") then
		return
	end
	local itemId = object:GetAttribute("ItemId")
	if itemId then
		object.Text = L("item_tag", L("item_" .. itemId), money(object:GetAttribute("Value") or 0))
		return
	end
	if object:GetAttribute("TruckHp") ~= nil then
		local function setTruck()
			object.Text = L("truck_tag", money(object:GetAttribute("TruckHp") or 0))
		end
		setTruck()
		object:GetAttributeChangedSignal("TruckHp"):Connect(setTruck)
	end
end
for _, object in ipairs(Workspace:GetDescendants()) do
	relabel(object)
end
Workspace.DescendantAdded:Connect(function(object)
	task.defer(relabel, object)
end)

local uiScale = Instance.new("UIScale")
uiScale.Parent = screen
local camera = Workspace.CurrentCamera
local function updateScale()
	if camera then
		uiScale.Scale = math.clamp(camera.ViewportSize.Y / 720, 0.5, 1)
	end
end
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()

screen.Parent = playerGui
task.delay(3, function()
	showToast(L("tutorial"), Color3.fromRGB(150, 220, 255))
end)
