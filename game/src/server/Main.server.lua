-- コインクリッカー: サーバー側
-- 光る玉をクリックするとコインが増え、ショップでアップグレードを買えます。
-- データは DataStore2 で自動保存されます。
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataStore2 = require(ServerScriptService.DataStore2)
local UpgradeConfig = require(ReplicatedStorage.UpgradeConfig)

---------------------------------------------------------------------
-- Studio で DataStore が使えないとき（未公開、または API アクセスがオフ）は、
-- メモリ上の仮の保存場所で動かす。停止するとデータは消える。
---------------------------------------------------------------------
local function createOfflineDataStoreService()
	local function newStore(ordered)
		local data = {}
		local store = {}

		function store:GetAsync(key)
			return data[key]
		end

		function store:SetAsync(key, value)
			data[key] = value
		end

		function store:UpdateAsync(key, transform)
			local newValue = transform(data[key])
			if newValue ~= nil then
				data[key] = newValue
			end
			return newValue
		end

		if ordered then
			function store:GetSortedAsync(ascending, pageSize)
				local entries = {}
				for key, value in pairs(data) do
					table.insert(entries, { key = key, value = value })
				end
				table.sort(entries, function(a, b)
					if ascending then
						return a.value < b.value
					end
					return a.value > b.value
				end)

				local page = {}
				for index = 1, math.min(pageSize, #entries) do
					page[index] = entries[index]
				end

				return {
					GetCurrentPage = function()
						return page
					end,
				}
			end
		end

		return store
	end

	local stores, orderedStores = {}, {}
	local service = {}

	function service:GetDataStore(name)
		stores[name] = stores[name] or newStore(false)
		return stores[name]
	end

	function service:GetOrderedDataStore(name)
		orderedStores[name] = orderedStores[name] or newStore(true)
		return orderedStores[name]
	end

	return service
end

if RunService:IsStudio() then
	local dataStoresAvailable = pcall(function()
		DataStoreService:GetDataStore("CoinClickerAccessCheck"):GetAsync("check")
	end)

	if not dataStoresAvailable then
		warn("[CoinClicker] DataStore が使えないので、Studio 用の仮保存で動かします（停止するとデータは消えます）。")
		local offlineService = createOfflineDataStoreService()
		require(ServerScriptService.DataStore2.DataStoreServiceRetriever).Get = function()
			return offlineService
		end
	end
end

local STARTING_COINS = 0
local CLICK_COOLDOWN = 0.1 -- 連打ツール対策（秒）

-- 使うキーは必ず Combine する
DataStore2.Combine("DATA", "coins")
for _, upgradeId in ipairs(UpgradeConfig.Order) do
	DataStore2.Combine("DATA", UpgradeConfig.Upgrades[upgradeId].key)
end

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

	-- 大当たり判定
	local critChance = UpgradeConfig.CritChance(DataStore2("critLevel", player):Get(0))
	local isCrit = math.random() < critChance
	if isCrit then
		amount = amount * UpgradeConfig.CRIT_MULTIPLIER
	end

	-- 値が変わったその場で更新する（保存は DataStore2 が退出時に自動で行う）
	DataStore2("coins", player):Increment(amount, STARTING_COINS)

	-- クリックしたプレイヤーの画面に「+N」を出す
	coinPopup:FireClient(player, amount, isCrit)
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
	if level >= UpgradeConfig.GetMaxLevel(upgradeId) then
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
			local perSecond = UpgradeConfig.CoinsPerSecond(
				DataStore2("autoLevel", player):Get(0),
				DataStore2("factoryLevel", player):Get(0)
			)
			if perSecond > 0 then
				DataStore2("coins", player):Increment(perSecond, STARTING_COINS)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	loadedPlayers[player] = nil
	lastClick[player] = nil
end)

---------------------------------------------------------------------
-- ランキング看板（全サーバー共通、コイン所持数の上位10人）
---------------------------------------------------------------------
local RANKING_SIZE = 10
local RANKING_INTERVAL = 60 -- 秒。DataStore の回数制限に引っかからないよう長めにする

local board = Instance.new("Part")
board.Name = "RankingBoard"
board.Anchored = true
board.Size = Vector3.new(14, 18, 1)
board.Position = Vector3.new(18, 9, -20)
board.Orientation = Vector3.new(0, -30, 0)
board.Color = Color3.fromRGB(40, 40, 50)
board.Parent = Workspace

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Face = Enum.NormalId.Back -- スポーン地点のほうを向く面
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 40
surfaceGui.Parent = board

local boardLayout = Instance.new("UIListLayout")
boardLayout.SortOrder = Enum.SortOrder.LayoutOrder
boardLayout.Parent = surfaceGui

local function makeBoardLabel(order, height, color)
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, height, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.Parent = surfaceGui
	return label
end

local RANK_COLORS = {
	Color3.fromRGB(255, 215, 0), -- 1位 金
	Color3.fromRGB(200, 200, 210), -- 2位 銀
	Color3.fromRGB(205, 127, 50), -- 3位 銅
}

makeBoardLabel(0, 0.12, Color3.fromRGB(255, 220, 80)).Text = "コインランキング"
local rankLabels = {}
for rank = 1, RANKING_SIZE do
	rankLabels[rank] = makeBoardLabel(rank, 0.08, RANK_COLORS[rank] or Color3.new(1, 1, 1))
end
rankLabels[1].Text = "読み込み中..."

local nameCache = {}
local function getName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok then
		nameCache[userId] = name
		return name
	end
	return "???"
end

local rankingOk, rankingStore = pcall(function()
	return DataStoreService:GetOrderedDataStore("CoinRanking")
end)

local function updateRanking()
	-- いまいるプレイヤーのコインを書き込む
	for player in pairs(loadedPlayers) do
		local coins = DataStore2("coins", player):Get(STARTING_COINS)
		pcall(function()
			rankingStore:SetAsync(tostring(player.UserId), math.floor(coins))
		end)
	end

	-- 上位を読み出して看板に出す
	local ok, entries = pcall(function()
		return rankingStore:GetSortedAsync(false, RANKING_SIZE):GetCurrentPage()
	end)
	if not ok then
		rankLabels[1].Text = "ランキングを読み込めません"
		return
	end

	for rank = 1, RANKING_SIZE do
		local entry = entries[rank]
		if entry then
			rankLabels[rank].Text = string.format("%d. %s  %d", rank, getName(tonumber(entry.key)), entry.value)
		else
			rankLabels[rank].Text = ""
		end
	end
	if not entries[1] then
		rankLabels[1].Text = "まだ記録がありません"
	end
end

if rankingOk then
	task.spawn(function()
		task.wait(5) -- プレイヤーのデータ読み込みを待つ
		while true do
			updateRanking()
			task.wait(RANKING_INTERVAL)
		end
	end)
else
	rankLabels[1].Text = "ランキングは公開後に動きます"
end
