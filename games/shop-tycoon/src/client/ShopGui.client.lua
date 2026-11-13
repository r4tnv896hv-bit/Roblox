-- Online Shop Tycoon: 画面（お金・発送ボタン・管理画面・注文の通知）
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local remotes = ReplicatedStorage:WaitForChild("ShopRemotes")
local stateRemote = remotes:WaitForChild("State")
local notifyRemote = remotes:WaitForChild("Notify")
local orderRemote = remotes:WaitForChild("NewOrder")
local actionRemote = remotes:WaitForChild("Action")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local language = Locale.GetLanguage(player)

local function L(key, ...)
	return Locale.Get(language, key, ...)
end

-- 1234 -> "1,234"、1234567 -> "1.23M"
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
	local units = { "K", "M", "B", "T", "Qa" }
	local value, i = n / 1000, 1
	while value >= 1000 and i < #units do
		value = value / 1000
		i = i + 1
	end
	return string.format("%.2f", value) .. units[i]
end

local GOLD = Color3.fromRGB(255, 215, 80)
local PANEL = Color3.fromRGB(28, 22, 45)
local BLUE = Color3.fromRGB(70, 120, 255)
local GREEN = Color3.fromRGB(46, 170, 90)
local ORANGE = Color3.fromRGB(255, 140, 40)
local PURPLE = Color3.fromRGB(150, 70, 220)
local GREY = Color3.fromRGB(85, 85, 95)
local WHITE = Color3.fromRGB(255, 255, 255)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent, colorValue, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = colorValue
	s.Thickness = thickness
	s.Parent = parent
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	for key, value in pairs(props) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function button(parent, props, onClick)
	local b = Instance.new("TextButton")
	b.TextColor3 = WHITE
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.AutoButtonColor = true
	for key, value in pairs(props) do
		b[key] = value
	end
	b.Parent = parent
	corner(b, 10)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function act(action, arg)
	actionRemote:FireServer(action, arg)
end

local screen = Instance.new("ScreenGui")
screen.Name = "ShopGui"
screen.ResetOnSpawn = false

---------------------------------------------------------------------
-- 上: お金と状況
---------------------------------------------------------------------
local moneyLabel = label(screen, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0, 300, 0, 54),
	BackgroundTransparency = 0.25,
	BackgroundColor3 = PANEL,
	TextColor3 = Color3.fromRGB(120, 255, 150),
	Font = Enum.Font.GothamBlack,
	Text = "$0",
})
corner(moneyLabel, 12)
stroke(moneyLabel, Color3.fromRGB(120, 255, 150), 2)

local statusLabel = label(screen, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 68),
	Size = UDim2.new(0, 560, 0, 24),
	TextStrokeTransparency = 0.4,
	Font = Enum.Font.Gotham,
	Text = "",
})

---------------------------------------------------------------------
-- 下: 発送ボタン（いちばん大事なボタン）
---------------------------------------------------------------------
local shipButton = button(screen, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.new(0, 340, 0, 78),
	BackgroundColor3 = ORANGE,
	Font = Enum.Font.GothamBlack,
	Text = L("ship", 0),
}, function()
	act("ship")
end)
stroke(shipButton, WHITE, 3)
local shipScale = Instance.new("UIScale")
shipScale.Parent = shipButton
shipButton.Activated:Connect(function()
	shipScale.Scale = 0.92
	TweenService:Create(shipScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end)

---------------------------------------------------------------------
-- 左: 管理画面ボタンと招待ボタン
---------------------------------------------------------------------
local dashboardButton = button(screen, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, -40),
	Size = UDim2.new(0, 210, 0, 64),
	BackgroundColor3 = BLUE,
	Font = Enum.Font.GothamBlack,
	Text = L("dashboard"),
})
stroke(dashboardButton, WHITE, 2)

local inviteButton = button(screen, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 34),
	Size = UDim2.new(0, 210, 0, 44),
	BackgroundColor3 = Color3.fromRGB(230, 80, 150),
	Text = L("invite"),
	Visible = false,
}, function()
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
-- 右: 注文の通知（どんどん流れる）
---------------------------------------------------------------------
local feed = Instance.new("Frame")
feed.AnchorPoint = Vector2.new(1, 0.5)
feed.Position = UDim2.new(1, -16, 0.5, 0)
feed.Size = UDim2.new(0, 290, 0, 300)
feed.BackgroundTransparency = 1
feed.Parent = screen
local feedLayout = Instance.new("UIListLayout")
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
feedLayout.Padding = UDim.new(0, 6)
feedLayout.Parent = feed

local feedCount = 0
orderRemote.OnClientEvent:Connect(function(productId, revenue)
	feedCount = feedCount + 1
	local product = ShopConfig.GetProduct(productId)
	local card = label(feed, {
		LayoutOrder = feedCount,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = Color3.fromRGB(30, 140, 80),
		Text = L("new_order", L("product_" .. productId), money(revenue)),
	})
	corner(card, 10)
	if product then
		stroke(card, product.color, 2)
	end

	local cards = {}
	for _, child in ipairs(feed:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(cards, child)
		end
	end
	if #cards > 5 then
		table.sort(cards, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		cards[1]:Destroy()
	end
	task.delay(3, function()
		if card.Parent then
			local fade = TweenService:Create(card, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
			fade.Completed:Connect(function()
				card:Destroy()
			end)
			fade:Play()
		end
	end)
end)

---------------------------------------------------------------------
-- お知らせ
---------------------------------------------------------------------
local toastArea = Instance.new("Frame")
toastArea.AnchorPoint = Vector2.new(0.5, 0)
toastArea.Position = UDim2.new(0.5, 0, 0, 98)
toastArea.Size = UDim2.new(0, 520, 0, 120)
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
	local toast = label(toastArea, {
		LayoutOrder = toastCount,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = PANEL,
		TextColor3 = colorValue or GOLD,
		Text = text,
	})
	corner(toast, 10)
	local toasts = {}
	for _, child in ipairs(toastArea:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 3 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	task.delay(3.5, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

local function localizeArg(arg)
	if type(arg) == "number" and arg == math.floor(arg) then
		return money(arg)
	elseif type(arg) == "string" and string.sub(arg, 1, 1) == "@" then
		return L(string.sub(arg, 2))
	end
	return arg
end

notifyRemote.OnClientEvent:Connect(function(key, colorValue, ...)
	local count = select("#", ...)
	local args = { ... }
	for i = 1, count do
		args[i] = localizeArg(args[i])
	end
	showToast(L(key, table.unpack(args, 1, count)), colorValue)
end)

---------------------------------------------------------------------
-- 管理画面（パソコンの画面）
---------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 620, 0, 440)
panel.BackgroundColor3 = PANEL
panel.Visible = false
panel.Parent = screen
corner(panel, 16)
stroke(panel, Color3.fromRGB(150, 110, 255), 3)

local closeButton = button(panel, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.new(0, 90, 0, 34),
	BackgroundColor3 = GREY,
	Text = L("close"),
}, function()
	panel.Visible = false
end)
closeButton.ZIndex = 2

dashboardButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

local tabBar = Instance.new("Frame")
tabBar.Position = UDim2.new(0, 10, 0, 10)
tabBar.Size = UDim2.new(1, -120, 0, 36)
tabBar.BackgroundTransparency = 1
tabBar.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local pages = {}
local tabButtons = {}
local TAB_ORDER = { "products", "ads", "upgrades", "company" }

local function showTab(tabId)
	for id, page in pairs(pages) do
		page.Visible = id == tabId
		tabButtons[id].BackgroundColor3 = id == tabId and PURPLE or GREY
	end
end

for index, tabId in ipairs(TAB_ORDER) do
	local page = Instance.new("ScrollingFrame")
	page.Position = UDim2.new(0, 10, 0, 54)
	page.Size = UDim2.new(1, -20, 1, -64)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 6
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page
	pages[tabId] = page

	tabButtons[tabId] = button(tabBar, {
		LayoutOrder = index,
		Size = UDim2.new(0.25, -6, 1, 0),
		BackgroundColor3 = GREY,
		Text = L("tab_" .. tabId),
	}, function()
		showTab(tabId)
	end)
end
showTab("products")

-- 1 行（左に説明、右にボタン）
local function makeRow(page, order, buttonColor, onClick)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 58)
	row.BackgroundColor3 = Color3.fromRGB(45, 36, 70)
	row.Parent = page
	corner(row, 10)
	local text = label(row, {
		Position = UDim2.new(0, 10, 0, 4),
		Size = UDim2.new(0.62, -10, 1, -8),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	local b = button(row, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.new(0.38, -10, 1, -12),
		BackgroundColor3 = buttonColor,
		Text = "",
	}, onClick)
	return row, text, b
end

-- 商品ページ
local productsPage = pages.products
local modeRow = Instance.new("Frame")
modeRow.LayoutOrder = 0
modeRow.Size = UDim2.new(1, -8, 0, 40)
modeRow.BackgroundTransparency = 1
modeRow.Parent = productsPage
local modeLabel = label(modeRow, { Size = UDim2.new(0.2, 0, 1, 0), Text = L("price_mode") })
local modeButtons = {}
for i, mode in ipairs({ "cheap", "normal", "premium" }) do
	modeButtons[mode] = button(modeRow, {
		Position = UDim2.new(0.2 + (i - 1) * 0.2, 4, 0, 2),
		Size = UDim2.new(0.2, -8, 1, -4),
		BackgroundColor3 = GREY,
		Text = L("mode_" .. mode),
	}, function()
		act("priceMode", mode)
	end)
end
local warehouseLabel = label(modeRow, {
	Position = UDim2.new(0.8, 0, 0, 0),
	Size = UDim2.new(0.2, 0, 1, 0),
	TextColor3 = Color3.fromRGB(200, 200, 220),
	Text = "",
})

local productRows = {}
for index, product in ipairs(ShopConfig.Products) do
	local row, text, b = makeRow(productsPage, index, GREEN, function()
		act("buyStock", product.id)
	end)
	productRows[index] = { row = row, text = text, button = b }
end
local unlockRow, unlockText, unlockButton = makeRow(productsPage, 100, ORANGE, function()
	act("unlock")
end)

-- 広告ページ
local adRows = {}
for index, ad in ipairs(ShopConfig.Ads) do
	local _, text, b = makeRow(pages.ads, index, ORANGE, function()
		act("runAd", ad.id)
	end)
	adRows[index] = { text = text, button = b }
end

-- 強化ページ
local upgradeRows = {}
for index, upgradeId in ipairs(ShopConfig.UpgradeOrder) do
	local _, text, b = makeRow(pages.upgrades, index, GREEN, function()
		act("upgrade", upgradeId)
	end)
	upgradeRows[upgradeId] = { text = text, button = b }
end

-- 会社ページ
local franchiseLabel = label(pages.company, {
	LayoutOrder = 0,
	Size = UDim2.new(1, -8, 0, 32),
	TextColor3 = GOLD,
	Text = "",
})
local sellButton = button(pages.company, {
	LayoutOrder = 1,
	Size = UDim2.new(1, -8, 0, 90),
	BackgroundColor3 = PURPLE,
	Text = "",
}, function()
	act("sellCompany")
end)
for index, passKey in ipairs(ShopConfig.GamePassOrder) do
	local pass = ShopConfig.GamePasses[passKey]
	if pass.id ~= 0 then
		button(pages.company, {
			LayoutOrder = 10 + index,
			Size = UDim2.new(1, -8, 0, 50),
			BackgroundColor3 = GREEN,
			Text = L("pass_" .. passKey) .. "  (Robux)",
		}, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
	end
end

---------------------------------------------------------------------
-- サーバーから届いた状態で画面を更新
---------------------------------------------------------------------
local tutorialShown = false

stateRemote.OnClientEvent:Connect(function(state)
	local stock = state.stock or {}
	local upgrades = state.upgrades or {}
	local multiplier = state.multiplier or 1
	local mode = ShopConfig.PriceModes[state.priceMode] or ShopConfig.PriceModes.normal

	moneyLabel.Text = L("money", money(state.money))
	statusLabel.Text = L(
		"status",
		money(state.pending),
		string.format("%.1f", state.visitors or 0),
		string.format("%.1f", state.shipPerSecond or 0),
		multiplier
	)
	shipButton.Text = L("ship", money(state.pending))
	shipButton.BackgroundColor3 = (state.pending or 0) > 0 and ORANGE or GREY

	-- 商品
	local total = 0
	for _, count in pairs(stock) do
		total = total + count
	end
	warehouseLabel.Text = L("warehouse_info", money(total), money(ShopConfig.StockCapacity(upgrades.warehouse or 0)))
	for modeId, b in pairs(modeButtons) do
		b.BackgroundColor3 = modeId == state.priceMode and PURPLE or GREY
	end
	for index, product in ipairs(ShopConfig.Products) do
		local rowInfo = productRows[index]
		rowInfo.row.Visible = index <= state.unlocked
		local price = math.max(1, math.floor(product.price * mode.priceMultiplier * multiplier))
		rowInfo.text.Text = L("product_row", L("product_" .. product.id), money(stock[product.id] or 0), money(price))
		local cost = product.cost * 10
		rowInfo.button.Text = L("buy_stock", money(cost))
		rowInfo.button.BackgroundColor3 = state.money >= product.cost and GREEN or GREY
	end
	local nextProduct = ShopConfig.Products[state.unlocked + 1]
	if nextProduct then
		unlockText.Text = L("product_" .. nextProduct.id)
		unlockButton.Text = L("unlock_product", "", money(nextProduct.unlock))
		unlockButton.BackgroundColor3 = state.money >= nextProduct.unlock and ORANGE or GREY
		unlockRow.Visible = true
	else
		unlockText.Text = L("all_unlocked")
		unlockButton.Visible = false
	end

	-- 広告
	for index, ad in ipairs(ShopConfig.Ads) do
		local rowInfo = adRows[index]
		rowInfo.text.Text = L("ad_row", L("ad_" .. ad.id), string.format("%.1f", ad.visitors), ad.duration)
		local remaining = state.ads and state.ads[ad.id]
		if remaining then
			rowInfo.button.Text = L("ad_running", remaining)
			rowInfo.button.BackgroundColor3 = GREY
		else
			local cost = ShopConfig.AdCost(ad, state.unlocked)
			rowInfo.button.Text = L("ad_buy", money(cost))
			rowInfo.button.BackgroundColor3 = state.money >= cost and ORANGE or GREY
		end
	end

	-- 強化
	for _, upgradeId in ipairs(ShopConfig.UpgradeOrder) do
		local rowInfo = upgradeRows[upgradeId]
		local level = upgrades[upgradeId] or 0
		rowInfo.text.Text = L("upgrade_row", L("upgrade_" .. upgradeId), level, L("upgrade_" .. upgradeId .. "_desc"))
		if level >= ShopConfig.Upgrades[upgradeId].maxLevel then
			rowInfo.button.Text = L("upgrade_max")
			rowInfo.button.BackgroundColor3 = GREY
		else
			local cost = ShopConfig.UpgradeCost(upgradeId, level)
			rowInfo.button.Text = L("upgrade_buy", money(cost))
			rowInfo.button.BackgroundColor3 = state.money >= cost and GREEN or GREY
		end
	end

	-- 会社
	local franchises = state.franchises or 0
	franchiseLabel.Text = L("franchise_info", franchises, math.floor(franchises * ShopConfig.FRANCHISE_BONUS * 100))
	local sellCost = ShopConfig.SellCompanyCost(franchises)
	sellButton.Text = L("sell_company", math.floor(ShopConfig.FRANCHISE_BONUS * 100), money(sellCost))
	sellButton.BackgroundColor3 = state.money >= sellCost and PURPLE or GREY

	-- はじめての人に遊び方を出す
	if not tutorialShown and total == 0 and franchises == 0 then
		tutorialShown = true
		showToast(L("tutorial"), Color3.fromRGB(150, 220, 255))
		panel.Visible = true
		showTab("products")
	end
end)

---------------------------------------------------------------------
-- 小さい画面では全体を縮める・看板の文字を自分の言語に
---------------------------------------------------------------------
local uiScale = Instance.new("UIScale")
uiScale.Parent = screen
local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		uiScale.Scale = math.clamp(camera.ViewportSize.Y / 700, 0.5, 1)
	end
end
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()

local function relabel(object)
	if object:IsA("TextLabel") and object:GetAttribute("LocaleKey") then
		object.Text = L(object:GetAttribute("LocaleKey"))
	end
end
for _, object in ipairs(Workspace:GetDescendants()) do
	relabel(object)
end
Workspace.DescendantAdded:Connect(function(object)
	task.defer(relabel, object)
end)

screen.Parent = playerGui
