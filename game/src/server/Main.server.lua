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
DataStore2.Combine("DATA", "coins", "rebirths", "lastDailyDay", "dailyStreak")
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

local rebirthRemote = Instance.new("RemoteEvent")
rebirthRemote.Name = "Rebirth"
rebirthRemote.Parent = remotes

-- 画面上部にお知らせを出す（text, 色）
local announce = Instance.new("RemoteEvent")
announce.Name = "Announce"
announce.Parent = remotes

remotes.Parent = ReplicatedStorage

local ANNOUNCE_GOLD = Color3.fromRGB(255, 215, 80)
local ANNOUNCE_PINK = Color3.fromRGB(255, 130, 200)
local ANNOUNCE_GREEN = Color3.fromRGB(120, 255, 140)

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

local onPlayerLoaded -- 下で中身を決める

local function onPlayerAdded(player)
	-- 右上のリーダーボードに表示する
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	mirror(DataStore2("coins", player), STARTING_COINS, "Coins", leaderstats)
	mirror(DataStore2("rebirths", player), 0, "Rebirths", leaderstats)

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

	onPlayerLoaded(player)
end

---------------------------------------------------------------------
-- 倍率（転生 × フレンドボーナス）
---------------------------------------------------------------------
local function getMultiplier(player)
	return UpgradeConfig.Multiplier(DataStore2("rebirths", player):Get(0), player:GetAttribute("FriendCount") or 0)
end

local function refreshMultiplier(player)
	player:SetAttribute("Multiplier", getMultiplier(player))
end

---------------------------------------------------------------------
-- フレンドボーナス: 同じサーバーにいるフレンドの数を数える
---------------------------------------------------------------------
local friendCache = {}

local function areFriends(a, b)
	local key = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	if friendCache[key] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		friendCache[key] = ok and result or false
	end
	return friendCache[key]
end

local function updateFriendBonus()
	for player in pairs(loadedPlayers) do
		local count = 0
		for other in pairs(loadedPlayers) do
			if other ~= player and other.Parent and areFriends(player, other) then
				count = count + 1
			end
		end

		local before = player:GetAttribute("FriendCount") or 0
		player:SetAttribute("FriendCount", count)
		refreshMultiplier(player)

		if count > before and count <= UpgradeConfig.MAX_FRIENDS_COUNTED then
			announce:FireClient(
				player,
				string.format("フレンドボーナス！ コイン +%d%%", math.floor(count * UpgradeConfig.FRIEND_BONUS * 100 + 0.5)),
				ANNOUNCE_PINK
			)
		end
	end
end

---------------------------------------------------------------------
-- ログインボーナス（連続ログインで増える）
---------------------------------------------------------------------
local function giveDailyReward(player)
	local today = math.floor(os.time() / 86400)
	local lastDayStore = DataStore2("lastDailyDay", player)
	local lastDay = lastDayStore:Get(0)
	if today <= lastDay then
		return
	end

	local streakStore = DataStore2("dailyStreak", player)
	local streak = 1
	if lastDay == today - 1 then
		streak = streakStore:Get(0) + 1
	end

	local reward = UpgradeConfig.DailyReward(streak, DataStore2("rebirths", player):Get(0))
	lastDayStore:Set(today)
	streakStore:Set(streak)
	DataStore2("coins", player):Increment(reward, STARTING_COINS)

	announce:FireClient(
		player,
		string.format("ログインボーナス %d日目！ +%d コイン（毎日来ると増えるよ）", streak, reward),
		ANNOUNCE_GREEN
	)
end

function onPlayerLoaded(player)
	player:SetAttribute("FriendCount", 0)
	refreshMultiplier(player)
	updateFriendBonus()

	-- 画面の準備ができるのを少し待ってから出す
	task.delay(4, function()
		if player.Parent and loadedPlayers[player] then
			giveDailyReward(player)
		end
	end)
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

	local amount = UpgradeConfig.CoinsPerClick(DataStore2("clickLevel", player):Get(0)) * getMultiplier(player)

	-- 大当たり判定
	local critChance = UpgradeConfig.CritChance(DataStore2("critLevel", player):Get(0))
	local isCrit = math.random() < critChance
	if isCrit then
		amount = amount * UpgradeConfig.CRIT_MULTIPLIER
	end
	amount = math.floor(amount)

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
			perSecond = math.floor(perSecond * getMultiplier(player))
			if perSecond > 0 then
				DataStore2("coins", player):Increment(perSecond, STARTING_COINS)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	loadedPlayers[player] = nil
	lastClick[player] = nil
	updateFriendBonus()
end)

---------------------------------------------------------------------
-- 転生: コインとアップグレードをリセットして、ずっと続く倍率を得る
---------------------------------------------------------------------
rebirthRemote.OnServerEvent:Connect(function(player)
	if not loadedPlayers[player] then
		return
	end

	local rebirthStore = DataStore2("rebirths", player)
	local rebirths = rebirthStore:Get(0)
	local cost = UpgradeConfig.RebirthCost(rebirths)
	local coinStore = DataStore2("coins", player)
	if coinStore:Get(STARTING_COINS) < cost then
		return
	end

	coinStore:Set(STARTING_COINS)
	for _, upgradeId in ipairs(UpgradeConfig.Order) do
		DataStore2(UpgradeConfig.Upgrades[upgradeId].key, player):Set(0)
	end
	rebirthStore:Set(rebirths + 1)
	refreshMultiplier(player)

	announce:FireAllClients(
		string.format("%s が %d回目の転生！ 倍率 x%.1f", player.DisplayName, rebirths + 1, getMultiplier(player)),
		ANNOUNCE_PINK
	)
end)

---------------------------------------------------------------------
-- ゴールデンコイン: ときどき出現する早い者勝ちボーナス
---------------------------------------------------------------------
local GOLDEN_MIN_WAIT = 120
local GOLDEN_MAX_WAIT = 240
local GOLDEN_LIFETIME = 30
local goldenRng = Random.new()

local function spawnGoldenCoin()
	local angle = goldenRng:NextNumber(0, math.pi * 2)
	local radius = goldenRng:NextNumber(15, 40)

	local golden = Instance.new("Part")
	golden.Name = "GoldenCoin"
	golden.Shape = Enum.PartType.Ball
	golden.Size = Vector3.new(4, 4, 4)
	golden.Anchored = true
	golden.CanCollide = false
	golden.Material = Enum.Material.Neon
	golden.Color = Color3.fromRGB(255, 230, 60)
	golden.Position = Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)

	local glow = Instance.new("PointLight")
	glow.Color = golden.Color
	glow.Range = 20
	glow.Brightness = 3
	glow.Parent = golden

	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = golden.Color
	sparkle.Parent = golden

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.new(0, 220, 0, 40)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.AlwaysOnTop = true
	tag.Parent = golden

	local tagLabel = Instance.new("TextLabel")
	tagLabel.Size = UDim2.new(1, 0, 1, 0)
	tagLabel.BackgroundTransparency = 1
	tagLabel.Text = "ゴールデンコイン！"
	tagLabel.TextColor3 = golden.Color
	tagLabel.TextStrokeTransparency = 0
	tagLabel.TextScaled = true
	tagLabel.Font = Enum.Font.GothamBlack
	tagLabel.Parent = tag

	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 60
	detector.Parent = golden

	local claimed = false
	local function claim(player)
		if claimed or not player or not loadedPlayers[player] then
			return
		end
		claimed = true

		local perClick = UpgradeConfig.CoinsPerClick(DataStore2("clickLevel", player):Get(0))
		local perSecond = UpgradeConfig.CoinsPerSecond(
			DataStore2("autoLevel", player):Get(0),
			DataStore2("factoryLevel", player):Get(0)
		)
		local reward = math.floor(math.max(100, perClick * 50 + perSecond * 60) * getMultiplier(player))
		DataStore2("coins", player):Increment(reward, STARTING_COINS)

		announce:FireAllClients(
			string.format("%s がゴールデンコインをゲット！ +%d", player.DisplayName, reward),
			ANNOUNCE_GOLD
		)
		golden:Destroy()
	end

	detector.MouseClick:Connect(claim)
	golden.Touched:Connect(function(hit)
		if hit.Parent then
			claim(Players:GetPlayerFromCharacter(hit.Parent))
		end
	end)

	golden.Parent = Workspace
	announce:FireAllClients("ゴールデンコインが出現！ 早い者勝ち！", ANNOUNCE_GOLD)

	task.delay(GOLDEN_LIFETIME, function()
		if not claimed then
			claimed = true
			golden:Destroy()
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(goldenRng:NextNumber(GOLDEN_MIN_WAIT, GOLDEN_MAX_WAIT))
		if next(loadedPlayers) then
			spawnGoldenCoin()
		end
	end
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
