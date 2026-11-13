-- コインクリッカー: 画面表示（コイン数・ショップ・クリック演出）
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))

local remotes = ReplicatedStorage:WaitForChild("CoinClickerRemotes")
local buyUpgrade = remotes:WaitForChild("BuyUpgrade")
local coinPopup = remotes:WaitForChild("CoinPopup")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local upgradesFolder = player:WaitForChild("Upgrades")
local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")

local GOLD = Color3.fromRGB(255, 220, 80)
local PANEL = Color3.fromRGB(30, 30, 30)
local CAN_BUY = Color3.fromRGB(46, 160, 67)
local CANNOT_BUY = Color3.fromRGB(80, 80, 80)

-- 1234567 -> "1,234,567"
local function formatNumber(n)
	local s = string.format("%d", n)
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinGui"
screenGui.ResetOnSpawn = false

---------------------------------------------------------------------
-- 上部: コイン数と稼ぐ速さ
---------------------------------------------------------------------
local coinLabel = Instance.new("TextLabel")
coinLabel.AnchorPoint = Vector2.new(0.5, 0)
coinLabel.Position = UDim2.new(0.5, 0, 0, 12)
coinLabel.Size = UDim2.new(0, 260, 0, 48)
coinLabel.BackgroundColor3 = PANEL
coinLabel.BackgroundTransparency = 0.3
coinLabel.TextColor3 = GOLD
coinLabel.TextScaled = true
coinLabel.Font = Enum.Font.GothamBold
coinLabel.Parent = screenGui
addCorner(coinLabel, 12)

local rateLabel = Instance.new("TextLabel")
rateLabel.AnchorPoint = Vector2.new(0.5, 0)
rateLabel.Position = UDim2.new(0.5, 0, 0, 64)
rateLabel.Size = UDim2.new(0, 260, 0, 24)
rateLabel.BackgroundTransparency = 1
rateLabel.TextColor3 = Color3.new(1, 1, 1)
rateLabel.TextStrokeTransparency = 0.5
rateLabel.TextScaled = true
rateLabel.Font = Enum.Font.Gotham
rateLabel.Parent = screenGui

local clickLevel = upgradesFolder:WaitForChild(UpgradeConfig.Upgrades.click.key)
local autoLevel = upgradesFolder:WaitForChild(UpgradeConfig.Upgrades.auto.key)

local function updateTop()
	coinLabel.Text = "コイン: " .. formatNumber(coins.Value)
	rateLabel.Text = string.format(
		"1クリック +%s ・ 毎秒 +%s",
		formatNumber(UpgradeConfig.CoinsPerClick(clickLevel.Value)),
		formatNumber(UpgradeConfig.CoinsPerSecond(autoLevel.Value))
	)
end

coins.Changed:Connect(updateTop)
clickLevel.Changed:Connect(updateTop)
autoLevel.Changed:Connect(updateTop)
updateTop()

---------------------------------------------------------------------
-- 左: ショップ（スマホのジャンプボタンと重ならないよう左側に置く）
---------------------------------------------------------------------
local shop = Instance.new("Frame")
shop.AnchorPoint = Vector2.new(0, 0.5)
shop.Position = UDim2.new(0, 16, 0.5, 0)
shop.Size = UDim2.new(0, 240, 0, 0)
shop.AutomaticSize = Enum.AutomaticSize.Y
shop.BackgroundColor3 = PANEL
shop.BackgroundTransparency = 0.2
shop.Parent = screenGui
addCorner(shop, 12)

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = shop

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = shop

local title = Instance.new("TextLabel")
title.LayoutOrder = 0
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Text = "ショップ"
title.TextColor3 = GOLD
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = shop

for index, upgradeId in ipairs(UpgradeConfig.Order) do
	local upgrade = UpgradeConfig.Upgrades[upgradeId]
	local levelValue = upgradesFolder:WaitForChild(upgrade.key)

	local button = Instance.new("TextButton")
	button.LayoutOrder = index
	button.Size = UDim2.new(1, 0, 0, 70)
	button.AutoButtonColor = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 16
	button.TextWrapped = true
	button.Font = Enum.Font.GothamMedium
	button.Parent = shop
	addCorner(button, 8)

	local function update()
		local level = levelValue.Value
		if level >= UpgradeConfig.MAX_LEVEL then
			button.Text = string.format("%s  Lv.%d\n最大レベル", upgrade.name, level)
			button.BackgroundColor3 = CANNOT_BUY
			return
		end

		local cost = UpgradeConfig.GetCost(upgradeId, level)
		button.Text = string.format(
			"%s  Lv.%d\n%s\n費用: %s コイン",
			upgrade.name,
			level,
			upgrade.description,
			formatNumber(cost)
		)
		button.BackgroundColor3 = coins.Value >= cost and CAN_BUY or CANNOT_BUY
	end

	button.Activated:Connect(function()
		buyUpgrade:FireServer(upgradeId)
	end)

	coins.Changed:Connect(update)
	levelValue.Changed:Connect(update)
	update()
end

screenGui.Parent = playerGui

---------------------------------------------------------------------
-- クリック演出: 玉がへこむ + 「+N」が浮かぶ
---------------------------------------------------------------------
local coinButton = Workspace:WaitForChild("CoinButton")
local baseSize = coinButton.Size
local pressTween

local function playPress()
	if pressTween then
		pressTween:Cancel()
	end
	coinButton.Size = baseSize * 0.85
	pressTween = TweenService:Create(
		coinButton,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = baseSize }
	)
	pressTween:Play()
end

local function showPopup(amount)
	local popup = Instance.new("BillboardGui")
	popup.Adornee = coinButton
	popup.Size = UDim2.new(0, 120, 0, 40)
	popup.StudsOffset = Vector3.new(math.random(-20, 20) / 10, 3, 0)
	popup.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "+" .. formatNumber(amount)
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = popup

	popup.Parent = playerGui

	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local rise = TweenService:Create(popup, info, { StudsOffset = popup.StudsOffset + Vector3.new(0, 3, 0) })
	local fade = TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
	rise.Completed:Connect(function()
		popup:Destroy()
	end)
	rise:Play()
	fade:Play()
end

coinPopup.OnClientEvent:Connect(function(amount)
	playPress()
	showPopup(amount)
end)
