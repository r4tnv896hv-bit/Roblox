-- コインクリッカー: 画面表示（コイン数・ショップ・クリック演出）
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local remotes = ReplicatedStorage:WaitForChild("CoinClickerRemotes")
local buyUpgrade = remotes:WaitForChild("BuyUpgrade")
local coinPopup = remotes:WaitForChild("CoinPopup")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local announceRemote = remotes:WaitForChild("Announce")
local pickupRemote = remotes:WaitForChild("Pickup")

local player = Players.LocalPlayer
local language = Locale.GetLanguage(player)

local function L(key, ...)
	return Locale.Get(language, key, ...)
end
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
	coinLabel.Text = L("coins_label", formatNumber(coins.Value))
	rateLabel.Text = L(
		"rate",
		formatNumber(math.floor(UpgradeConfig.CoinsPerClick(clickLevel.Value) * multiplier)),
		formatNumber(math.floor(UpgradeConfig.CoinsPerSecond(autoLevel.Value, factoryLevel.Value) * multiplier)),
		formatNumber(math.floor(UpgradeConfig.CritChance(critLevel.Value) * 100 + 0.5)),
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
title.Text = L("shop_title")
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
			button.Text = L("upgrade_max", L("upgrade_" .. upgradeId .. "_name"), formatNumber(level))
			button.BackgroundColor3 = CANNOT_BUY
			return
		end

		local cost = UpgradeConfig.GetCost(upgradeId, level)
		button.Text = L(
			"upgrade_button",
			L("upgrade_" .. upgradeId .. "_name"),
			formatNumber(level),
			L("upgrade_" .. upgradeId .. "_desc"),
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
	rebirthButton.Text = L("rebirth_button", formatNumber(rebirths.Value + 1), UpgradeConfig.REBIRTH_BONUS, formatNumber(cost))
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
	rebirthButton.Text = L("rebirth_confirm")
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
inviteButton.Text = L("invite", formatNumber(math.floor(UpgradeConfig.FRIEND_BONUS * 100 + 0.5)))
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
---------------------------------------------------------------------
-- コインの雨のカウントダウン
---------------------------------------------------------------------
local rainLabel = Instance.new("TextLabel")
rainLabel.AnchorPoint = Vector2.new(0.5, 0)
rainLabel.Position = UDim2.new(0.5, 0, 0, 92)
rainLabel.Size = UDim2.new(0, 420, 0, 28)
rainLabel.BackgroundColor3 = PANEL
rainLabel.BackgroundTransparency = 0.35
rainLabel.TextColor3 = GOLD
rainLabel.TextScaled = true
rainLabel.Font = Enum.Font.GothamBold
rainLabel.Text = ""
rainLabel.Parent = screenGui
addCorner(rainLabel, 8)

task.spawn(function()
	while true do
		local now = os.time()
		local rainUntil = Workspace:GetAttribute("RainUntil") or 0
		local nextRain = Workspace:GetAttribute("NextRainAt") or 0
		if rainUntil > now then
			rainLabel.Text = L("rain_now", formatNumber(rainUntil - now))
			rainLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			rainLabel.BackgroundColor3 = Color3.fromRGB(200, 140, 20)
		elseif nextRain > now then
			local left = nextRain - now
			rainLabel.Text = L("rain_in", string.format("%d:%02d", math.floor(left / 60), left % 60))
			rainLabel.TextColor3 = GOLD
			rainLabel.BackgroundColor3 = PANEL
		else
			rainLabel.Text = ""
		end
		task.wait(0.5)
	end
end)

-- 週末イベントの帯
local weekendLabel = Instance.new("TextLabel")
weekendLabel.AnchorPoint = Vector2.new(0, 0)
weekendLabel.Position = UDim2.new(0, 16, 0, 60)
weekendLabel.Size = UDim2.new(0, 230, 0, 34)
weekendLabel.BackgroundColor3 = Color3.fromRGB(230, 60, 120)
weekendLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
weekendLabel.TextScaled = true
weekendLabel.Font = Enum.Font.GothamBlack
weekendLabel.Text = L("weekend_banner")
weekendLabel.Visible = Workspace:GetAttribute("Weekend") == true
weekendLabel.Parent = screenGui
addCorner(weekendLabel, 10)
Workspace:GetAttributeChangedSignal("Weekend"):Connect(function()
	weekendLabel.Visible = Workspace:GetAttribute("Weekend") == true
end)

---------------------------------------------------------------------
-- 効果音（Roblox に最初から入っている音）
---------------------------------------------------------------------
local SoundService = game:GetService("SoundService")
local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
clickSound.Volume = 0.35
clickSound.Parent = SoundService

local function playClick(pitch)
	clickSound.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(clickSound)
end

local toastArea = Instance.new("Frame")
toastArea.AnchorPoint = Vector2.new(0.5, 0)
toastArea.Position = UDim2.new(0.5, 0, 0, 126)
toastArea.Size = UDim2.new(0, 520, 0, 120)
toastArea.BackgroundTransparency = 1
toastArea.Parent = screenGui

local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 4)
toastLayout.Parent = toastArea

local toastCount = 0

-- サーバーからは「文字の種類(key)・色・数字や名前」が届くので、ここで自分の言語の文にする
local function localizeArg(arg)
	if type(arg) == "number" and arg == math.floor(arg) then
		return formatNumber(arg)
	elseif type(arg) == "string" and string.sub(arg, 1, 5) == "@pet:" then
		return Locale.PetName(language, string.sub(arg, 6))
	elseif type(arg) == "string" and string.sub(arg, 1, 1) == "@" then
		return L(string.sub(arg, 2))
	end
	return arg
end

local showToast -- 下で中身を決める

announceRemote.OnClientEvent:Connect(function(key, color, ...)
	local args = { ... }
	for i = 1, select("#", ...) do
		args[i] = localizeArg(args[i])
	end
	showToast(L(key, table.unpack(args, 1, select("#", ...))), color)
end)

function showToast(text, color)
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
end

---------------------------------------------------------------------
-- 右: Robux ショップ（ID を設定したアイテムだけ出す）
---------------------------------------------------------------------
local ROBUX_COLOR = Color3.fromRGB(0, 170, 90)
local OWNED_COLOR = Color3.fromRGB(80, 80, 80)

local robuxShop = Instance.new("Frame")
robuxShop.AnchorPoint = Vector2.new(1, 0.5)
robuxShop.Position = UDim2.new(1, -16, 0.5, 0)
robuxShop.Size = UDim2.new(0, 220, 0, 0)
robuxShop.AutomaticSize = Enum.AutomaticSize.Y
robuxShop.BackgroundColor3 = PANEL
robuxShop.BackgroundTransparency = 0.2
robuxShop.Visible = false
robuxShop.Parent = screenGui
addCorner(robuxShop, 12)
addStroke(robuxShop, GOLD, 2)

local robuxPadding = Instance.new("UIPadding")
robuxPadding.PaddingTop = UDim.new(0, 10)
robuxPadding.PaddingBottom = UDim.new(0, 10)
robuxPadding.PaddingLeft = UDim.new(0, 10)
robuxPadding.PaddingRight = UDim.new(0, 10)
robuxPadding.Parent = robuxShop

local robuxLayout = Instance.new("UIListLayout")
robuxLayout.Padding = UDim.new(0, 8)
robuxLayout.SortOrder = Enum.SortOrder.LayoutOrder
robuxLayout.Parent = robuxShop

local robuxTitle = Instance.new("TextLabel")
robuxTitle.LayoutOrder = 0
robuxTitle.Size = UDim2.new(1, 0, 0, 28)
robuxTitle.BackgroundTransparency = 1
robuxTitle.Text = L("special_shop")
robuxTitle.TextColor3 = GOLD
robuxTitle.TextScaled = true
robuxTitle.Font = Enum.Font.GothamBold
robuxTitle.Parent = robuxShop

local function makeRobuxButton(order, item, textKey, infoType, onClick)
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 54)
	button.BackgroundColor3 = ROBUX_COLOR
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 15
	button.TextWrapped = true
	button.Font = Enum.Font.GothamMedium
	button.Parent = robuxShop
	addCorner(button, 8)
	addStroke(button, Color3.new(1, 1, 1), 1)
	addShine(button)

	local price = item.price
	local function setText(suffix)
		button.Text = string.format("%s\n%s\n%s", L(textKey .. "_name"), L(textKey .. "_desc"), suffix)
	end
	setText("R$ " .. price)

	-- 実際の値段を Roblox から取ってくる
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(item.id, infoType)
		end)
		if ok and info and info.PriceInRobux then
			price = info.PriceInRobux
			if button:GetAttribute("Owned") ~= true then
				setText("R$ " .. price)
			end
		end
	end)

	button.Activated:Connect(onClick)
	robuxShop.Visible = true
	return button, setText
end

for index, passKey in ipairs(UpgradeConfig.GamePassOrder) do
	local pass = UpgradeConfig.GamePasses[passKey]
	if pass.id ~= 0 then
		local attribute = "Pass_" .. passKey
		local button, setText
		button, setText = makeRobuxButton(index, pass, "pass_" .. passKey, Enum.InfoType.GamePass, function()
			if player:GetAttribute(attribute) ~= true then
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		end)

		local function updateOwned()
			if player:GetAttribute(attribute) == true then
				button:SetAttribute("Owned", true)
				button.BackgroundColor3 = OWNED_COLOR
				setText(L("owned"))
			end
		end
		player:GetAttributeChangedSignal(attribute):Connect(updateOwned)
		updateOwned()
	end
end

for index, productKey in ipairs(UpgradeConfig.ProductOrder) do
	local product = UpgradeConfig.Products[productKey]
	if product.id ~= 0 then
		makeRobuxButton(10 + index, product, "product_" .. productKey, Enum.InfoType.Product, function()
			MarketplaceService:PromptProductPurchase(player, product.id)
		end)
	end
end

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

-- LocaleKey 属性が付いた文字（ポータルの看板など）を自分の言語にする
local function relabel(object)
	if object:IsA("TextLabel") then
		local key = object:GetAttribute("LocaleKey")
		if key then
			local arg = object:GetAttribute("LocaleArg")
			if arg ~= nil then
				object.Text = L(key, type(arg) == "number" and formatNumber(arg) or arg)
			else
				object.Text = L(key)
			end
		end
	end
end
for _, object in ipairs(Workspace:GetDescendants()) do
	relabel(object)
end
Workspace.DescendantAdded:Connect(function(object)
	task.defer(relabel, object)
end)

-- 玉の上の文字とランキング看板の見出しを自分の言語にする（自分の画面だけ変わる）
task.spawn(function()
	local ballLabel = coinButton:WaitForChild("BillboardGui", 10)
	ballLabel = ballLabel and ballLabel:FindFirstChildOfClass("TextLabel")
	if ballLabel then
		ballLabel.Text = L("click_me")
	end

	local board = Workspace:WaitForChild("RankingBoard", 10)
	local surface = board and board:FindFirstChildOfClass("SurfaceGui")
	local rankingTitle = surface and surface:FindFirstChild("RankingTitle")
	if rankingTitle then
		rankingTitle.Text = L("ranking_title")
	end
end)
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

local function showPopup(amount, isCrit, sourcePart)
	local popup = Instance.new("BillboardGui")
	popup.Adornee = sourcePart or coinButton
	popup.Size = isCrit and UDim2.new(0, 260, 0, 70) or UDim2.new(0, 120, 0, 40)
	popup.StudsOffset = Vector3.new(math.random(-20, 20) / 10, 3, 0)
	popup.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = isCrit and L("crit_popup", formatNumber(amount)) or ("+" .. formatNumber(amount))
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

---------------------------------------------------------------------
-- はじめての人向けのガイド
---------------------------------------------------------------------
local isNewPlayer = coins.Value < 10 and rebirths.Value == 0 and clickLevel.Value == 0
local tutorialArrow
local clicksSeen = 0

if isNewPlayer then
	tutorialArrow = Instance.new("BillboardGui")
	tutorialArrow.Name = "TutorialArrow"
	tutorialArrow.Adornee = coinButton
	tutorialArrow.Size = UDim2.new(0, 260, 0, 90)
	tutorialArrow.StudsOffset = Vector3.new(0, 8, 0)
	tutorialArrow.AlwaysOnTop = true

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Size = UDim2.new(1, 0, 1, 0)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text = L("tutorial_click") .. "\n▼"
	arrowLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	arrowLabel.TextStrokeTransparency = 0
	arrowLabel.TextScaled = true
	arrowLabel.Font = Enum.Font.GothamBlack
	arrowLabel.Parent = tutorialArrow
	tutorialArrow.Parent = playerGui

	-- ぴょこぴょこ上下に動かして目立たせる
	TweenService:Create(
		tutorialArrow,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = Vector3.new(0, 9.5, 0) }
	):Play()

	-- 10 コインたまったらショップを案内（1 回だけ）
	local shopHintShown = false
	coins.Changed:Connect(function()
		if not shopHintShown and coins.Value >= 10 and clickLevel.Value == 0 then
			shopHintShown = true
			showToast(L("tutorial_shop"), GOLD)
		end
	end)
end

-- 8 分遊んだら「いいね・お気に入り」をお願いする（1 回だけ）
task.delay(8 * 60, function()
	showToast(L("tutorial_like"), Color3.fromRGB(255, 130, 200))
end)

coinPopup.OnClientEvent:Connect(function(amount, isCrit, sourcePart)
	clicksSeen = clicksSeen + 1
	if tutorialArrow and clicksSeen >= 5 then
		tutorialArrow:Destroy()
		tutorialArrow = nil
	end
	if sourcePart == nil or sourcePart == coinButton then
		playPress()
	end
	playClick(isCrit and 1.6 or 1)
	showPopup(amount, isCrit, sourcePart)
end)

---------------------------------------------------------------------
-- コインの雨で拾ったとき: 画面に「+N」が飛び出して音が鳴る
---------------------------------------------------------------------
local pickupRng = Random.new()
pickupRemote.OnClientEvent:Connect(function(amount)
	playClick(1.3 + pickupRng:NextNumber(0, 0.4))
	local popup = Instance.new("TextLabel")
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.new(0.5 + pickupRng:NextNumber(-0.12, 0.12), 0, 0.55 + pickupRng:NextNumber(-0.08, 0.08), 0)
	popup.Size = UDim2.new(0, 220, 0, 50)
	popup.BackgroundTransparency = 1
	popup.Text = "+" .. formatNumber(amount)
	popup.TextColor3 = GOLD
	popup.TextStrokeTransparency = 0
	popup.TextScaled = true
	popup.Font = Enum.Font.GothamBlack
	popup.Parent = screenGui
	local tween = TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position - UDim2.new(0, 0, 0.12, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
	tween:Play()
end)
