-- コインクリッカー: 画面表示（コイン数・ショップ・クリック演出）
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))

local remotes = ReplicatedStorage:WaitForChild("CoinClickerRemotes")
local buyUpgrade = remotes:WaitForChild("BuyUpgrade")
local coinPopup = remotes:WaitForChild("CoinPopup")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local announceRemote = remotes:WaitForChild("Announce")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local upgradesFolder = player:WaitForChild("Upgrades")
local leaderstats = player:WaitForChild("leaderstats")
local coins = leaderstats:WaitForChild("Coins")
local rebirths = leaderstats:WaitForChild("Rebirths")

local GOLD = Color3.fromRGB(255, 220, 80)
local PANEL = Color3.fromRGB(35, 25, 45)
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

-- 枠線（文字ではなく四角の縁に付ける）
local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = parent
end

-- 上が明るく下が少し暗いグラデーション（ボタンの色に重なる）
local function addShine(parent)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	gradient.Parent = parent
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
addStroke(coinLabel, GOLD, 2)

local rateLabel = Instance.new("TextLabel")
rateLabel.AnchorPoint = Vector2.new(0.5, 0)
rateLabel.Position = UDim2.new(0.5, 0, 0, 64)
rateLabel.Size = UDim2.new(0, 480, 0, 24)
rateLabel.BackgroundTransparency = 1
rateLabel.TextColor3 = Color3.new(1, 1, 1)
rateLabel.TextStrokeTransparency = 0.5
rateLabel.TextScaled = true
rateLabel.Font = Enum.Font.Gotham
rateLabel.Parent = screenGui

local clickLevel = upgradesFolder:WaitForChild(UpgradeConfig.Upgrades.click.key)
local autoLevel = upgradesFolder:WaitForChild(UpgradeConfig.Upgrades.auto.key)
local critLevel = upgradesFolder:WaitForChild(UpgradeConfig.Upgrades.crit.key)
local factoryLevel = upgradesFolder:WaitForChild(UpgradeConfig.Upgrades.factory.key)

local function getMultiplier()
	return player:GetAttribute("Multiplier") or 1
end

local function updateTop()
	local multiplier = getMultiplier()
	coinLabel.Text = "コイン: " .. formatNumber(coins.Value)
	rateLabel.Text = string.format(
		"1クリック +%s ・ 毎秒 +%s ・ 大当たり %d%% ・ 倍率 x%.1f",
		formatNumber(math.floor(UpgradeConfig.CoinsPerClick(clickLevel.Value) * multiplier)),
		formatNumber(math.floor(UpgradeConfig.CoinsPerSecond(autoLevel.Value, factoryLevel.Value) * multiplier)),
		math.floor(UpgradeConfig.CritChance(critLevel.Value) * 100 + 0.5),
		multiplier
	)
end

player:GetAttributeChangedSignal("Multiplier"):Connect(updateTop)

coins.Changed:Connect(updateTop)
clickLevel.Changed:Connect(updateTop)
autoLevel.Changed:Connect(updateTop)
critLevel.Changed:Connect(updateTop)
factoryLevel.Changed:Connect(updateTop)
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
addStroke(shop, GOLD, 2)

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
	addStroke(button, Color3.fromRGB(255, 255, 255), 1)
	addShine(button)

	local function update()
		local level = levelValue.Value
		if level >= UpgradeConfig.GetMaxLevel(upgradeId) then
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

---------------------------------------------------------------------
-- 転生ボタン（ショップの一番下）
---------------------------------------------------------------------
local REBIRTH_COLOR = Color3.fromRGB(150, 70, 200)

local rebirthButton = Instance.new("TextButton")
rebirthButton.LayoutOrder = 100
rebirthButton.Size = UDim2.new(1, 0, 0, 70)
rebirthButton.TextColor3 = Color3.new(1, 1, 1)
rebirthButton.TextSize = 16
rebirthButton.TextWrapped = true
rebirthButton.Font = Enum.Font.GothamBold
rebirthButton.Parent = shop
addCorner(rebirthButton, 8)
addStroke(rebirthButton, GOLD, 2)
addShine(rebirthButton)

local confirming = false

local function updateRebirth()
	if confirming then
		return
	end
	local cost = UpgradeConfig.RebirthCost(rebirths.Value)
	rebirthButton.Text = string.format(
		"転生（%d回目）\n全部リセット → 倍率 +%.1f\n必要: %s コイン",
		rebirths.Value + 1,
		UpgradeConfig.REBIRTH_BONUS,
		formatNumber(cost)
	)
	rebirthButton.BackgroundColor3 = coins.Value >= cost and REBIRTH_COLOR or CANNOT_BUY
end

-- まちがって押さないよう、2回押しで転生する
rebirthButton.Activated:Connect(function()
	if coins.Value < UpgradeConfig.RebirthCost(rebirths.Value) then
		return
	end
	if confirming then
		confirming = false
		rebirthRemote:FireServer()
		return
	end

	confirming = true
	rebirthButton.Text = "本当に転生する？\nもう一度押すと転生！"
	task.delay(3, function()
		confirming = false
		updateRebirth()
	end)
end)

coins.Changed:Connect(updateRebirth)
rebirths.Changed:Connect(updateRebirth)
updateRebirth()

---------------------------------------------------------------------
-- 下: 友だち招待ボタン（招待できる環境のときだけ出す）
---------------------------------------------------------------------
local inviteButton = Instance.new("TextButton")
inviteButton.AnchorPoint = Vector2.new(0.5, 1)
inviteButton.Position = UDim2.new(0.5, 0, 1, -16)
inviteButton.Size = UDim2.new(0, 320, 0, 50)
inviteButton.BackgroundColor3 = Color3.fromRGB(230, 80, 150)
inviteButton.TextColor3 = Color3.new(1, 1, 1)
inviteButton.TextScaled = true
inviteButton.Font = Enum.Font.GothamBold
inviteButton.Text = string.format("友だちを招待！ 1人ごとにコイン +%d%%", math.floor(UpgradeConfig.FRIEND_BONUS * 100 + 0.5))
inviteButton.Visible = false
inviteButton.Parent = screenGui
addCorner(inviteButton, 12)
addStroke(inviteButton, Color3.new(1, 1, 1), 2)
addShine(inviteButton)

local textPadding = Instance.new("UIPadding")
textPadding.PaddingLeft = UDim.new(0, 10)
textPadding.PaddingRight = UDim.new(0, 10)
textPadding.PaddingTop = UDim.new(0, 8)
textPadding.PaddingBottom = UDim.new(0, 8)
textPadding.Parent = inviteButton

inviteButton.Activated:Connect(function()
	pcall(function()
		SocialService:PromptGameInvite(player)
	end)
end)

task.spawn(function()
	local ok, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	inviteButton.Visible = ok and canInvite == true
end)

---------------------------------------------------------------------
-- お知らせ（ログインボーナス・転生・ゴールデンコインなど）
---------------------------------------------------------------------
local toastArea = Instance.new("Frame")
toastArea.AnchorPoint = Vector2.new(0.5, 0)
toastArea.Position = UDim2.new(0.5, 0, 0, 96)
toastArea.Size = UDim2.new(0, 520, 0, 120)
toastArea.BackgroundTransparency = 1
toastArea.Parent = screenGui

local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 4)
toastLayout.Parent = toastArea

local toastCount = 0

announceRemote.OnClientEvent:Connect(function(text, color)
	toastCount = toastCount + 1

	local toast = Instance.new("TextLabel")
	toast.LayoutOrder = toastCount
	toast.Size = UDim2.new(1, 0, 0, 34)
	toast.BackgroundColor3 = PANEL
	toast.BackgroundTransparency = 0.25
	toast.Text = text
	toast.TextColor3 = color or GOLD
	toast.TextScaled = true
	toast.Font = Enum.Font.GothamBold
	toast.Parent = toastArea
	addCorner(toast, 10)

	-- 古いものから消えるよう、多すぎたら一番古いものを消す
	local labels = {}
	for _, child in ipairs(toastArea:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels > 3 then
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		labels[1]:Destroy()
	end

	task.delay(4, function()
		if toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.6), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			})
			fade.Completed:Connect(function()
				toast:Destroy()
			end)
			fade:Play()
		end
	end)
end)

---------------------------------------------------------------------
-- 画面が小さい（スマホなど）ときは UI 全体を縮める
---------------------------------------------------------------------
local uiScale = Instance.new("UIScale")
uiScale.Parent = screenGui

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		uiScale.Scale = math.clamp(camera.ViewportSize.Y / 650, 0.55, 1)
	end
end

if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()

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

local function showPopup(amount, isCrit)
	local popup = Instance.new("BillboardGui")
	popup.Adornee = coinButton
	popup.Size = isCrit and UDim2.new(0, 260, 0, 70) or UDim2.new(0, 120, 0, 40)
	popup.StudsOffset = Vector3.new(math.random(-20, 20) / 10, 3, 0)
	popup.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = (isCrit and "大当たり! +" or "+") .. formatNumber(amount)
	label.TextColor3 = isCrit and Color3.fromRGB(255, 90, 60) or GOLD
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

coinPopup.OnClientEvent:Connect(function(amount, isCrit)
	playPress()
	showPopup(amount, isCrit)
end)
