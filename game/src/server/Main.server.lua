-- コインクリッカー: サーバー側
-- 光る玉をクリックするとコインが増え、DataStore2 で自動保存されます。
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataStore2 = require(ServerScriptService.DataStore2)

local STARTING_COINS = 0
local COINS_PER_CLICK = 1
local CLICK_COOLDOWN = 0.1 -- 連打ツール対策（秒）

-- 使うキーは必ず Combine する
DataStore2.Combine("DATA", "coins")

---------------------------------------------------------------------
-- ワールドを作る（地面・スポーン地点・コインの玉）
---------------------------------------------------------------------
local baseplate = Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Anchored = true
baseplate.Size = Vector3.new(512, 4, 512)
baseplate.Position = Vector3.new(0, -2, 0)
baseplate.Color = Color3.fromRGB(91, 154, 76)
baseplate.Material = Enum.Material.Grass
baseplate.Parent = Workspace

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Anchored = true
spawnLocation.Size = Vector3.new(12, 1, 12)
spawnLocation.Position = Vector3.new(0, 0.5, 0)
spawnLocation.Parent = Workspace

local coinButton = Instance.new("Part")
coinButton.Name = "CoinButton"
coinButton.Shape = Enum.PartType.Ball
coinButton.Anchored = true
coinButton.Size = Vector3.new(6, 6, 6)
coinButton.Position = Vector3.new(0, 5, -20)
coinButton.Color = Color3.fromRGB(255, 200, 0)
coinButton.Material = Enum.Material.Neon
coinButton.Parent = Workspace

local clickDetector = Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 40
clickDetector.Parent = coinButton

local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.new(0, 260, 0, 50)
billboard.StudsOffset = Vector3.new(0, 5, 0)
billboard.AlwaysOnTop = true
billboard.Parent = coinButton

local billboardLabel = Instance.new("TextLabel")
billboardLabel.Size = UDim2.new(1, 0, 1, 0)
billboardLabel.BackgroundTransparency = 1
billboardLabel.Text = "クリックでコイン +" .. COINS_PER_CLICK
billboardLabel.TextColor3 = Color3.new(1, 1, 1)
billboardLabel.TextStrokeTransparency = 0
billboardLabel.TextScaled = true
billboardLabel.Font = Enum.Font.GothamBold
billboardLabel.Parent = billboard

---------------------------------------------------------------------
-- プレイヤーのデータ
---------------------------------------------------------------------
local function onPlayerAdded(player)
	local coinStore = DataStore2("coins", player)

	-- 右上のリーダーボードに表示する
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = coinStore:Get(STARTING_COINS)
	coins.Parent = leaderstats

	leaderstats.Parent = player

	-- 値が変わるたびに表示を更新する
	coinStore:OnUpdate(function(newValue)
		coins.Value = newValue
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	coroutine.wrap(onPlayerAdded)(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

---------------------------------------------------------------------
-- クリックでコインを増やす
---------------------------------------------------------------------
local lastClick = {}

clickDetector.MouseClick:Connect(function(player)
	local now = tick()
	if lastClick[player] and now - lastClick[player] < CLICK_COOLDOWN then
		return
	end
	lastClick[player] = now

	-- 値が変わったその場で更新する（保存は DataStore2 が退出時に自動で行う）
	DataStore2("coins", player):Increment(COINS_PER_CLICK, STARTING_COINS)
end)

Players.PlayerRemoving:Connect(function(player)
	lastClick[player] = nil
end)
