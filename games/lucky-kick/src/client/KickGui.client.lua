-- Lucky Block Kick: 画面（キックのゲージ・カメラ・結果・強化・お知らせ）
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local KickConfig = require(ReplicatedStorage:WaitForChild("KickConfig"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local remotes = ReplicatedStorage:WaitForChild("KickRemotes")
local kickRemote = remotes:WaitForChild("Kick")
local launchedRemote = remotes:WaitForChild("Launched")
local landedRemote = remotes:WaitForChild("Landed")
local actionRemote = remotes:WaitForChild("Action")
local notifyRemote = remotes:WaitForChild("Notify")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local language = Locale.GetLanguage(player)

local function L(key, ...)
	return Locale.Get(language, key, ...)
end

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

local PANEL = Color3.fromRGB(25, 25, 40)
local WHITE = Color3.fromRGB(255, 255, 255)

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local screen = Instance.new("ScreenGui")
screen.Name = "KickGui"
screen.ResetOnSpawn = false

local coinsLabel = Instance.new("TextLabel")
coinsLabel.AnchorPoint = Vector2.new(0.5, 0)
coinsLabel.Position = UDim2.new(0.5, 0, 0, 10)
coinsLabel.Size = UDim2.new(0, 280, 0, 50)
coinsLabel.BackgroundColor3 = PANEL
coinsLabel.BackgroundTransparency = 0.25
coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
coinsLabel.TextScaled = true
coinsLabel.Font = Enum.Font.GothamBlack
coinsLabel.Parent = screen
corner(coinsLabel, 12)

local bestLabel = Instance.new("TextLabel")
bestLabel.AnchorPoint = Vector2.new(0.5, 0)
bestLabel.Position = UDim2.new(0.5, 0, 0, 62)
bestLabel.Size = UDim2.new(0, 300, 0, 24)
bestLabel.BackgroundTransparency = 1
bestLabel.TextColor3 = WHITE
bestLabel.TextStrokeTransparency = 0.4
bestLabel.TextScaled = true
bestLabel.Font = Enum.Font.GothamBold
bestLabel.Parent = screen

---------------------------------------------------------------------
-- キックのゲージ（上下に動くバー。緑のところで押すとパーフェクト）
---------------------------------------------------------------------
local meter = Instance.new("Frame")
meter.AnchorPoint = Vector2.new(1, 1)
meter.Position = UDim2.new(1, -40, 1, -130)
meter.Size = UDim2.new(0, 46, 0, 260)
meter.BackgroundColor3 = PANEL
meter.BackgroundTransparency = 0.2
meter.Parent = screen
corner(meter, 10)

local green = Instance.new("Frame")
green.Position = UDim2.new(0, 4, 0, 4)
green.Size = UDim2.new(1, -8, 0.08, 0)
green.BackgroundColor3 = Color3.fromRGB(60, 220, 100)
green.BorderSizePixel = 0
green.Parent = meter

local fill = Instance.new("Frame")
fill.AnchorPoint = Vector2.new(0, 1)
fill.Position = UDim2.new(0, 10, 1, -4)
fill.Size = UDim2.new(1, -20, 0, 0)
fill.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
fill.BorderSizePixel = 0
fill.Parent = meter
corner(fill, 6)

local kickButton = Instance.new("TextButton")
kickButton.AnchorPoint = Vector2.new(1, 1)
kickButton.Position = UDim2.new(1, -16, 1, -30)
kickButton.Size = UDim2.new(0, 220, 0, 86)
kickButton.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
kickButton.TextColor3 = WHITE
kickButton.TextScaled = true
kickButton.Font = Enum.Font.GothamBlack
kickButton.Text = L("kick")
kickButton.Parent = screen
corner(kickButton, 16)

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(1, 1)
hint.Position = UDim2.new(1, -100, 1, -400)
hint.Size = UDim2.new(0, 300, 0, 30)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(150, 255, 170)
hint.TextStrokeTransparency = 0.3
hint.TextScaled = true
hint.Font = Enum.Font.GothamBold
hint.Text = L("kick_hint")
hint.Parent = screen

local power = 0
local busy = false
local startedAt = os.clock()

RunService.RenderStepped:Connect(function()
	if busy then
		return
	end
	-- 0〜1 を行ったり来たり（だんだん速くなりすぎないよう一定の速さ）
	local t = (os.clock() - startedAt) * 1.4
	power = 1 - math.abs((t % 2) - 1)
	fill.Size = UDim2.new(1, -20, power, -8)
	fill.BackgroundColor3 = power >= 0.92 and Color3.fromRGB(60, 220, 100) or Color3.fromRGB(255, 160, 40)
end)

kickButton.Activated:Connect(function()
	if busy then
		return
	end
	busy = true
	kickButton.Text = L("wait")
	kickButton.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
	kickRemote:FireServer(power)
	task.delay(KickConfig.KICK_COOLDOWN + 0.2, function()
		-- 着地の知らせが来なくても、いつかは押せるように戻す
		if busy then
			task.wait(KickConfig.MAX_FLIGHT_TIME)
			busy = false
			kickButton.Text = L("kick")
			kickButton.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
		end
	end)
end)

---------------------------------------------------------------------
-- カメラがブロックを追いかける
---------------------------------------------------------------------
local camera = Workspace.CurrentCamera

launchedRemote.OnClientEvent:Connect(function(block)
	if block and block:IsA("BasePart") then
		camera.CameraSubject = block
	end
end)

---------------------------------------------------------------------
-- 結果
---------------------------------------------------------------------
local resultLabel = Instance.new("TextLabel")
resultLabel.AnchorPoint = Vector2.new(0.5, 0.5)
resultLabel.Position = UDim2.new(0.5, 0, 0.35, 0)
resultLabel.Size = UDim2.new(0, 640, 0, 90)
resultLabel.BackgroundColor3 = PANEL
resultLabel.BackgroundTransparency = 0.15
resultLabel.TextColor3 = WHITE
resultLabel.TextScaled = true
resultLabel.Font = Enum.Font.GothamBlack
resultLabel.Visible = false
resultLabel.Parent = screen
corner(resultLabel, 16)
local resultScale = Instance.new("UIScale")
resultScale.Parent = resultLabel

local blockColors = {}
for _, b in ipairs(KickConfig.Blocks) do
	blockColors[b.id] = b.color
end

landedRemote.OnClientEvent:Connect(function(distance, blockId, rewardId, coins, perfect)
	local block = nil
	for _, b in ipairs(KickConfig.Blocks) do
		if b.id == blockId then
			block = b
		end
	end
	local text = L(
		"result",
		money(distance),
		L("block_" .. blockId),
		block and block.multiplier or 1,
		L("reward_" .. rewardId),
		money(coins)
	)
	if perfect then
		text = L("perfect") .. "\n" .. text
	end
	resultLabel.Text = text
	resultLabel.TextColor3 = blockColors[blockId] or WHITE
	resultLabel.Visible = true
	resultScale.Scale = 0.4
	TweenService:Create(resultScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	task.delay(2.5, function()
		resultLabel.Visible = false
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		busy = false
		startedAt = os.clock()
		kickButton.Text = L("kick")
		kickButton.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
	end)
end)

---------------------------------------------------------------------
-- 左: 強化・転生・招待
---------------------------------------------------------------------
local function makeButton(colorValue, y, height, onClick)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.Position = UDim2.new(0, 16, 0.5, y)
	b.Size = UDim2.new(0, 210, 0, height)
	b.BackgroundColor3 = colorValue
	b.TextColor3 = WHITE
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.Parent = screen
	corner(b, 12)
	b.Activated:Connect(onClick)
	return b
end

local legButton = makeButton(Color3.fromRGB(46, 160, 80), -110, 60, function()
	actionRemote:FireServer("upgrade", "leg")
end)
local luckButton = makeButton(Color3.fromRGB(70, 120, 255), -40, 60, function()
	actionRemote:FireServer("upgrade", "luck")
end)
local rebirthButton = makeButton(Color3.fromRGB(150, 70, 220), 30, 60, function()
	actionRemote:FireServer("rebirth")
end)
local inviteButton = makeButton(Color3.fromRGB(230, 80, 150), 94, 40, function()
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

local function update()
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	local best = stats and stats:FindFirstChild("Best")
	local rebirths = stats and stats:FindFirstChild("Rebirths")
	local coinValue = coins and coins.Value or 0
	coinsLabel.Text = L("coins", money(coinValue))
	bestLabel.Text = L("best", money(best and best.Value or 0), player:GetAttribute("Multiplier") or 1)

	for _, info in ipairs({ { "leg", legButton, "upgrade_leg" }, { "luck", luckButton, "upgrade_luck" } }) do
		local upgradeId, b, key = info[1], info[2], info[3]
		local level = player:GetAttribute(upgradeId == "leg" and "Leg" or "Luck") or 0
		if level >= KickConfig.Upgrades[upgradeId].maxLevel then
			b.Text = L("upgrade_max", L(key, level, ""))
		else
			local cost = KickConfig.UpgradeCost(upgradeId, level)
			b.Text = L(key, level, money(cost))
			b.AutoButtonColor = coinValue >= cost
			b.BackgroundTransparency = coinValue >= cost and 0 or 0.4
		end
	end
	local rebirthCost = KickConfig.RebirthCost(rebirths and rebirths.Value or 0)
	rebirthButton.Text = L("rebirth", money(rebirthCost))
	rebirthButton.BackgroundTransparency = coinValue >= rebirthCost and 0 or 0.4
end
task.spawn(function()
	while true do
		update()
		task.wait(0.25)
	end
end)

---------------------------------------------------------------------
-- お知らせ
---------------------------------------------------------------------
local toastArea = Instance.new("Frame")
toastArea.AnchorPoint = Vector2.new(0.5, 0)
toastArea.Position = UDim2.new(0.5, 0, 0, 92)
toastArea.Size = UDim2.new(0, 520, 0, 110)
toastArea.BackgroundTransparency = 1
toastArea.Parent = screen
local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 4)
toastLayout.Parent = toastArea

local toastCount = 0
notifyRemote.OnClientEvent:Connect(function(key, colorValue, ...)
	local count = select("#", ...)
	local args = { ... }
	for i = 1, count do
		if type(args[i]) == "number" and args[i] == math.floor(args[i]) then
			args[i] = money(args[i])
		end
	end
	toastCount = toastCount + 1
	local toast = Instance.new("TextLabel")
	toast.LayoutOrder = toastCount
	toast.Size = UDim2.new(1, 0, 0, 32)
	toast.BackgroundColor3 = PANEL
	toast.BackgroundTransparency = 0.15
	toast.TextColor3 = colorValue or WHITE
	toast.TextScaled = true
	toast.Font = Enum.Font.GothamBold
	toast.Text = L(key, table.unpack(args, 1, count))
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
end)

---------------------------------------------------------------------
-- 看板の文字・小さい画面
---------------------------------------------------------------------
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

local uiScale = Instance.new("UIScale")
uiScale.Parent = screen
local function updateScale()
	if camera then
		uiScale.Scale = math.clamp(camera.ViewportSize.Y / 700, 0.5, 1)
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

screen.Parent = playerGui
