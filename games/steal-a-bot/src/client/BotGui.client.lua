-- Steal a Bot: 画面（お金・ロック・転生・お知らせ・ボタンの表示切り替え）
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Workspace = game:GetService("Workspace")

local BotConfig = require(ReplicatedStorage:WaitForChild("BotConfig"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local remotes = ReplicatedStorage:WaitForChild("BotRemotes")
local notifyRemote = remotes:WaitForChild("Notify")
local actionRemote = remotes:WaitForChild("Action")

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
screen.Name = "BotGui"
screen.ResetOnSpawn = false

local moneyLabel = Instance.new("TextLabel")
moneyLabel.AnchorPoint = Vector2.new(0.5, 0)
moneyLabel.Position = UDim2.new(0.5, 0, 0, 10)
moneyLabel.Size = UDim2.new(0, 280, 0, 50)
moneyLabel.BackgroundColor3 = PANEL
moneyLabel.BackgroundTransparency = 0.25
moneyLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
moneyLabel.TextScaled = true
moneyLabel.Font = Enum.Font.GothamBlack
moneyLabel.Parent = screen
corner(moneyLabel, 12)

local incomeLabel = Instance.new("TextLabel")
incomeLabel.AnchorPoint = Vector2.new(0.5, 0)
incomeLabel.Position = UDim2.new(0.5, 0, 0, 62)
incomeLabel.Size = UDim2.new(0, 300, 0, 24)
incomeLabel.BackgroundTransparency = 1
incomeLabel.TextColor3 = WHITE
incomeLabel.TextStrokeTransparency = 0.4
incomeLabel.TextScaled = true
incomeLabel.Font = Enum.Font.GothamBold
incomeLabel.Parent = screen

local function makeButton(text, colorValue, position, size, onClick)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.Position = position
	b.Size = size
	b.BackgroundColor3 = colorValue
	b.TextColor3 = WHITE
	b.TextScaled = true
	b.Font = Enum.Font.GothamBlack
	b.Text = text
	b.Parent = screen
	corner(b, 12)
	b.Activated:Connect(onClick)
	return b
end

local lockButton = makeButton(L("lock"), Color3.fromRGB(220, 50, 60), UDim2.new(0, 16, 0.5, -40), UDim2.new(0, 200, 0, 60), function()
	actionRemote:FireServer("lock")
end)
local rebirthButton = makeButton("", Color3.fromRGB(150, 70, 220), UDim2.new(0, 16, 0.5, 32), UDim2.new(0, 200, 0, 60), function()
	actionRemote:FireServer("rebirth")
end)
local inviteButton = makeButton(L("invite"), Color3.fromRGB(230, 80, 150), UDim2.new(0, 16, 0.5, 96), UDim2.new(0, 200, 0, 40), function()
	pcall(function()
		SocialService:PromptGameInvite(player)
	end)
end)
inviteButton.Visible = false
task.spawn(function()
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	inviteButton.Visible = ok and can == true
end)

-- お知らせ
local toastArea = Instance.new("Frame")
toastArea.AnchorPoint = Vector2.new(0.5, 0)
toastArea.Position = UDim2.new(0.5, 0, 0, 92)
toastArea.Size = UDim2.new(0, 560, 0, 140)
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
	if #list > 4 then
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
		local arg = args[i]
		if type(arg) == "number" and arg == math.floor(arg) then
			args[i] = money(arg)
		elseif type(arg) == "string" and string.sub(arg, 1, 1) == "@" then
			args[i] = L(string.sub(arg, 2))
		end
	end
	showToast(L(key, table.unpack(args, 1, count)), colorValue)
end)

-- 表示の更新
local function update()
	local stats = player:FindFirstChild("leaderstats")
	local moneyValue = stats and stats:FindFirstChild("Money")
	local rebirths = stats and stats:FindFirstChild("Rebirths")
	moneyLabel.Text = L("money", money(moneyValue and moneyValue.Value or 0))
	incomeLabel.Text = L("income", money(player:GetAttribute("IncomePerSecond") or 0), player:GetAttribute("Multiplier") or 1)
	rebirthButton.Text = L("rebirth", money(BotConfig.RebirthCost(rebirths and rebirths.Value or 0)))
	local lockLeft = player:GetAttribute("LockLeft") or 0
	local readyIn = player:GetAttribute("LockReadyIn") or 0
	if lockLeft > 0 then
		lockButton.Text = L("lock_on", lockLeft)
		lockButton.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
	elseif readyIn > 0 then
		lockButton.Text = L("lock_wait", readyIn)
		lockButton.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
	else
		lockButton.Text = L("lock")
		lockButton.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	end
end
task.spawn(function()
	while true do
		update()
		task.wait(0.25)
	end
end)

-- 「盗む」は他人のロボットだけ、「売る」「ロック」は自分のものだけに出す。文字も自分の言語に。
local function setupPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function refresh()
		local ownerId = prompt:GetAttribute("OwnerUserId") or 0
		if prompt:GetAttribute("OwnerOnly") then
			prompt.Enabled = ownerId == player.UserId
		elseif prompt:GetAttribute("OthersOnly") then
			prompt.Enabled = ownerId ~= player.UserId
		end
		local kind = prompt:GetAttribute("Kind")
		local botId = prompt.ObjectText
		local bot = BotConfig.GetBot(botId)
		if bot then
			prompt.ObjectText = L("bot_" .. botId) .. " (" .. L("rarity_" .. bot.rarity) .. ")"
		end
		if kind == "buy" then
			prompt.ActionText = L("prompt_buy", money(prompt:GetAttribute("Price") or 0))
		elseif kind == "steal" then
			prompt.ActionText = L("prompt_steal")
		elseif kind == "sell" then
			prompt.ActionText = L("prompt_sell", money(prompt:GetAttribute("Price") or 0))
		elseif prompt:GetAttribute("BaseIndex") then
			prompt.ActionText = L("prompt_lock")
		end
	end
	refresh()
	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
end

local function setupTag(object)
	if object:IsA("TextLabel") and object:GetAttribute("BotId") then
		local bot = BotConfig.GetBot(object:GetAttribute("BotId"))
		if bot then
			object.Text = L("bot_tag", L("bot_" .. bot.id), money(bot.income))
		end
	end
end

for _, object in ipairs(Workspace:GetDescendants()) do
	setupPrompt(object)
	setupTag(object)
end
Workspace.DescendantAdded:Connect(function(object)
	task.defer(function()
		setupPrompt(object)
		setupTag(object)
	end)
end)

-- 小さい画面では縮める
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

screen.Parent = playerGui
task.delay(3, function()
	showToast(L("tutorial"), Color3.fromRGB(150, 220, 255))
end)
