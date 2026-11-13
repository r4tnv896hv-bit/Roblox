-- コインクリッカー: サーバー側
-- 光る玉をクリックするとコインが増え、ショップでアップグレードを買えます。
-- データは DataStore2 で自動保存されます。
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataStore2 = require(ServerScriptService.DataStore2)
local UpgradeConfig = require(ReplicatedStorage.UpgradeConfig)

local STARTING_COINS = 0
local CLICK_COOLDOWN = 0.1 -- 連打ツール対策（秒）

-- 使うキーは必ず Combine する
DataStore2.Combine("DATA", "coins", "clickLevel", "autoLevel")

---------------------------------------------------------------------
-- クライアントとの通信用 RemoteEvent
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "CoinClickerRemotes"

local buyUpgrade = Instance.new("RemoteEvent")
buyUpgrade.Name = "BuyUpgrade"
buyUpgrade.Parent = remotes

local coinPopup = Instance.new("RemoteEvent")
coinPopup.Name = "CoinPopup"
coinPopup.Parent = remotes

remotes.Parent = ReplicatedStorage

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
billboardLabel.Text = "クリックでコイン！"
billboardLabel.TextColor3 = Color3.new(1, 1, 1)
billboardLabel.TextStrokeTransparency = 0
billboardLabel.TextScaled = true
billboardLabel.Font = Enum.Font.GothamBold
billboardLabel.Parent = billboard

---------------------------------------------------------------------
-- プレイヤーのデータ
---------------------------------------------------------------------
local loadedPlayers = {} -- データの読み込みが終わったプレイヤー

-- DataStore2 の値を IntValue に映す（クライアントが表示に使う）
local function mirror(store, defaultValue, name, parent)
	local value = Instance.new("IntValue")
	value.Name = name
	value.Value = store:Get(defaultValue)
	value.Parent = parent

	store:OnUpdate(function(newValue)
		value.Value = newValue
	end)
end

local function onPlayerAdded(player)
	-- 右上のリーダーボードに表示する
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	mirror(DataStore2("coins", player), STARTING_COINS, "Coins", leaderstats)

	-- アップグレードのレベル
	local upgrades = Instance.new("Folder")
	upgrades.Name = "Upgrades"
	for _, upgradeId in ipairs(UpgradeConfig.Order) do
		local key = UpgradeConfig.Upgrades[upgradeId].key
		mirror(DataStore2(key, player), 0, key, upgrades)
	end

	-- 読み込み中に退出した場合は何もしない
	if not player.Parent then
		return
	end

	upgrades.Parent = player
	leaderstats.Parent = player
	loadedPlayers[player] = true
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

---------------------------------------------------------------------
-- クリックでコインを増やす
---------------------------------------------------------------------
local lastClick = {}

clickDetector.MouseClick:Connect(function(player)
	if not loadedPlayers[player] then
		return
	end

	local now = tick()
	if lastClick[player] and now - lastClick[player] < CLICK_COOLDOWN then
		return
	end
	lastClick[player] = now

	local amount = UpgradeConfig.CoinsPerClick(DataStore2("clickLevel", player):Get(0))

	-- 値が変わったその場で更新する（保存は DataStore2 が退出時に自動で行う）
	DataStore2("coins", player):Increment(amount, STARTING_COINS)

	-- クリックしたプレイヤーの画面に「+N」を出す
	coinPopup:FireClient(player, amount)
end)

---------------------------------------------------------------------
-- ショップ
---------------------------------------------------------------------
buyUpgrade.OnServerEvent:Connect(function(player, upgradeId)
	if not loadedPlayers[player] then
		return
	end

	-- クライアントから来た値は信用しない
	if type(upgradeId) ~= "string" then
		return
	end
	local upgrade = UpgradeConfig.Upgrades[upgradeId]
	if not upgrade then
		return
	end

	local levelStore = DataStore2(upgrade.key, player)
	local level = levelStore:Get(0)
	if level >= UpgradeConfig.MAX_LEVEL then
		return
	end

	local cost = UpgradeConfig.GetCost(upgradeId, level)
	local coinStore = DataStore2("coins", player)
	if coinStore:Get(STARTING_COINS) < cost then
		return
	end

	coinStore:Increment(-cost, STARTING_COINS)
	levelStore:Set(level + 1)
end)

---------------------------------------------------------------------
-- 自動コイン（毎秒）
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for player in pairs(loadedPlayers) do
			local autoLevel = DataStore2("autoLevel", player):Get(0)
			if autoLevel > 0 then
				DataStore2("coins", player):Increment(UpgradeConfig.CoinsPerSecond(autoLevel), STARTING_COINS)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	loadedPlayers[player] = nil
	lastClick[player] = nil
end)
