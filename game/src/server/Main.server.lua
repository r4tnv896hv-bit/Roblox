-- コインクリッカー: サーバー側
-- 光る玉をクリックするとコインが増え、ショップでアップグレードを買えます。
-- データは DataStore2 で自動保存されます。
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
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
		warn("[CoinClicker] DataStore unavailable; using temporary in-memory saves for Studio (data resets when you stop).")
		local offlineService = createOfflineDataStoreService()
		require(ServerScriptService.DataStore2.DataStoreServiceRetriever).Get = function()
			return offlineService
		end
	end
end

local STARTING_COINS = 0
local CLICK_COOLDOWN = 0.1 -- 連打ツール対策（秒）

-- 使うキーは必ず Combine する
DataStore2.Combine("DATA", "coins", "rebirths", "lastDailyDay", "dailyStreak", "purchaseHistory", "lastSeen", "pets")
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

-- 卵を割った結果をその人に知らせる（petId）
local hatchResult = Instance.new("RemoteEvent")
hatchResult.Name = "HatchResult"
hatchResult.Parent = remotes

-- ペットの合体（petId）
local fuseRemote = Instance.new("RemoteEvent")
fuseRemote.Name = "FusePet"
fuseRemote.Parent = remotes

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
billboardLabel.Text = "Click for coins!" -- クライアント側で言語に合わせて書き換える
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
	return UpgradeConfig.Multiplier(
		DataStore2("rebirths", player):Get(0),
		player:GetAttribute("FriendCount") or 0,
		player:GetAttribute("Pass_doubleCoins") == true,
		player:GetAttribute("PetBonus") or 0
	)
end

-- ついてくるペットを属性に書く（クライアントが見た目を作る）
local function refreshPets(player)
	local owned = DataStore2("pets", player):Get({})
	local equipped, bonus = UpgradeConfig.EquippedPets(owned)
	player:SetAttribute("EquippedPets", table.concat(equipped, ","))
	player:SetAttribute("PetBonus", bonus)

	-- 持っているペットの数（ペット一覧の画面用）"cat=7,dragon=1"
	local parts = {}
	for petId, count in pairs(owned) do
		if UpgradeConfig.Pets[petId] and count > 0 then
			table.insert(parts, petId .. "=" .. count)
		end
	end
	player:SetAttribute("OwnedPets", table.concat(parts, ","))
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
				"announce_friend",
				ANNOUNCE_PINK,
				math.floor(count * UpgradeConfig.FRIEND_BONUS * 100 + 0.5)
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

	announce:FireClient(player, "announce_daily", ANNOUNCE_GREEN, streak, reward)
end

-- 持っているゲームパスを属性に書く（Pass_doubleCoins など）
local function checkGamePasses(player)
	for passKey, pass in pairs(UpgradeConfig.GamePasses) do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				player:SetAttribute("Pass_" .. passKey, true)
			end
		end
	end
end

-- 今の「毎秒のコイン」（自動コイン・工場・オートクリック、倍率込み）
local function getPerSecond(player)
	local perSecond = UpgradeConfig.CoinsPerSecond(
		DataStore2("autoLevel", player):Get(0),
		DataStore2("factoryLevel", player):Get(0)
	)
	if player:GetAttribute("Pass_autoClick") then
		perSecond = perSecond
			+ UpgradeConfig.CoinsPerClick(DataStore2("clickLevel", player):Get(0)) * UpgradeConfig.AUTO_CLICKS_PER_SECOND
	end
	return math.floor(perSecond * getMultiplier(player))
end

---------------------------------------------------------------------
-- オフライン報酬: いない間も自動コインの一部がたまる
---------------------------------------------------------------------
local function giveOfflineEarnings(player)
	local lastSeenStore = DataStore2("lastSeen", player)
	local lastSeen = lastSeenStore:Get(0)
	local now = os.time()
	lastSeenStore:Set(now)

	if lastSeen <= 0 then
		return
	end
	local away = math.min(now - lastSeen, UpgradeConfig.OFFLINE_MAX_SECONDS)
	if away < UpgradeConfig.OFFLINE_MIN_SECONDS then
		return
	end

	local reward = math.floor(getPerSecond(player) * away * UpgradeConfig.OFFLINE_RATE)
	if reward <= 0 then
		return
	end
	DataStore2("coins", player):Increment(reward, STARTING_COINS)
	announce:FireClient(player, "announce_offline", ANNOUNCE_GREEN, reward, math.floor(away / 60))
end

function onPlayerLoaded(player)
	player:SetAttribute("FriendCount", 0)
	checkGamePasses(player)
	refreshPets(player)
	refreshMultiplier(player)
	updateFriendBonus()

	-- 画面の準備ができるのを少し待ってから出す
	task.delay(4, function()
		if player.Parent and loadedPlayers[player] then
			giveDailyReward(player)
			giveOfflineEarnings(player)
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

-- 玉をクリックしたとき（areaMultiplier はワールドごとの倍率、sourcePart はクリックした玉）
local function handleClick(player, areaMultiplier, sourcePart)
	if not loadedPlayers[player] then
		return
	end

	local now = tick()
	if lastClick[player] and now - lastClick[player] < CLICK_COOLDOWN then
		return
	end
	lastClick[player] = now

	local amount = UpgradeConfig.CoinsPerClick(DataStore2("clickLevel", player):Get(0))
		* getMultiplier(player)
		* areaMultiplier

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
	coinPopup:FireClient(player, amount, isCrit, sourcePart)
end

clickDetector.MouseClick:Connect(function(player)
	handleClick(player, 1, coinButton)
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
local secondsPlayed = {}

task.spawn(function()
	while true do
		task.wait(1)
		for player in pairs(loadedPlayers) do
			local perSecond = getPerSecond(player)
			if perSecond > 0 then
				DataStore2("coins", player):Increment(perSecond, STARTING_COINS)
			end

			local played = (secondsPlayed[player] or 0) + 1
			secondsPlayed[player] = played

			-- 最後にいた時刻（オフライン報酬用）を 30 秒ごとに記録
			if played % 30 == 0 then
				DataStore2("lastSeen", player):Set(os.time())
			end

			-- プレイ時間ボーナス
			if played % UpgradeConfig.PLAYTIME_GIFT_SECONDS == 0 then
				local gift = UpgradeConfig.PlaytimeGift(
					UpgradeConfig.CoinsPerClick(DataStore2("clickLevel", player):Get(0)),
					perSecond,
					getMultiplier(player)
				)
				DataStore2("coins", player):Increment(gift, STARTING_COINS)
				announce:FireClient(
					player,
					"announce_playtime",
					ANNOUNCE_GREEN,
					math.floor(played / 60),
					gift
				)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if loadedPlayers[player] then
		DataStore2("lastSeen", player):Set(os.time())
	end
	loadedPlayers[player] = nil
	lastClick[player] = nil
	secondsPlayed[player] = nil
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

	announce:FireAllClients("announce_rebirth", ANNOUNCE_PINK, player.DisplayName, rebirths + 1, getMultiplier(player))
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
	tagLabel.Text = "GOLDEN COIN!"
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

		announce:FireAllClients("announce_golden_got", ANNOUNCE_GOLD, player.DisplayName, reward)
		golden:Destroy()
	end

	detector.MouseClick:Connect(claim)
	golden.Touched:Connect(function(hit)
		if hit.Parent then
			claim(Players:GetPlayerFromCharacter(hit.Parent))
		end
	end)

	golden.Parent = Workspace
	announce:FireAllClients("announce_golden_spawn", ANNOUNCE_GOLD)

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

local boardTitle = makeBoardLabel(0, 0.12, Color3.fromRGB(255, 220, 80))
boardTitle.Name = "RankingTitle"
boardTitle.Text = "Top Coins" -- クライアント側で言語に合わせて書き換える
local rankLabels = {}
for rank = 1, RANKING_SIZE do
	rankLabels[rank] = makeBoardLabel(rank, 0.08, RANK_COLORS[rank] or Color3.new(1, 1, 1))
end
rankLabels[1].Text = "Loading..."

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
		rankLabels[1].Text = "Ranking unavailable"
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
		rankLabels[1].Text = "No records yet"
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
	rankLabels[1].Text = "Ranking works after publishing"
end


---------------------------------------------------------------------
-- 課金: ゲームパス（買い切り）
---------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	for passKey, pass in pairs(UpgradeConfig.GamePasses) do
		if pass.id == passId then
			player:SetAttribute("Pass_" .. passKey, true)
			refreshMultiplier(player)
			announce:FireAllClients("announce_pass", ANNOUNCE_PINK, player.DisplayName, "@pass_" .. passKey .. "_name")
		end
	end
end)

---------------------------------------------------------------------
-- 課金: デベロッパー製品（コインパック、何度でも買える）
-- 同じ購入を2回渡さないよう、購入 ID を記録してから保存する
---------------------------------------------------------------------
local function findProduct(productId)
	for productKey, product in pairs(UpgradeConfig.Products) do
		if product.id ~= 0 and product.id == productId then
			return product, productKey
		end
	end
	return nil, nil
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not loadedPlayers[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product, productKey = findProduct(receipt.ProductId)
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local historyStore = DataStore2("purchaseHistory", player)
	local history = historyStore:Get({})
	if table.find(history, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local perClick = UpgradeConfig.CoinsPerClick(DataStore2("clickLevel", player):Get(0))
	local perSecond = UpgradeConfig.CoinsPerSecond(
		DataStore2("autoLevel", player):Get(0),
		DataStore2("factoryLevel", player):Get(0)
	)
	local reward = UpgradeConfig.PackReward(product, perClick, perSecond, getMultiplier(player))
	DataStore2("coins", player):Increment(reward, STARTING_COINS)

	table.insert(history, receipt.PurchaseId)
	while #history > 50 do
		table.remove(history, 1)
	end
	historyStore:Set(history)

	local saved = pcall(function()
		DataStore2.SaveAll(player)
	end)
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	announce:FireAllClients("announce_pack", ANNOUNCE_GOLD, player.DisplayName, "@product_" .. productKey .. "_name", reward)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end


---------------------------------------------------------------------
-- ペットの卵: 台の上の卵に近づいて E キー（スマホはタップ）で割る
---------------------------------------------------------------------
local hatchRng = Random.new()
local lastHatch = {}
local HATCH_COOLDOWN = 1

local function hatch(player, eggId)
	if not loadedPlayers[player] then
		return
	end
	local now = tick()
	if lastHatch[player] and now - lastHatch[player] < HATCH_COOLDOWN then
		return
	end
	lastHatch[player] = now

	local egg = UpgradeConfig.Eggs[eggId]
	local coinStore = DataStore2("coins", player)
	local coins = coinStore:Get(STARTING_COINS)
	if coins < egg.cost then
		announce:FireClient(player, "announce_need_coins", ANNOUNCE_PINK, egg.cost)
		return
	end

	-- トリプルハッチのパスがあり、コインが足りれば 3 個まとめて割る
	local count = 1
	if player:GetAttribute("Pass_tripleHatch") and coins >= egg.cost * 3 then
		count = 3
	end
	coinStore:Increment(-egg.cost * count, STARTING_COINS)

	local lucky = player:GetAttribute("Pass_luckyEggs") == true
	local petsStore = DataStore2("pets", player)
	local pets = petsStore:Get({})
	local results = {}
	for i = 1, count do
		local petId = UpgradeConfig.RollEgg(eggId, hatchRng, lucky)
		results[i] = petId
		pets[petId] = (pets[petId] or 0) + 1
	end
	petsStore:Set(pets)

	refreshPets(player)
	refreshMultiplier(player)
	hatchResult:FireClient(player, table.unpack(results))

	-- レア以上は全員にお知らせ
	for _, petId in ipairs(results) do
		local rarity = UpgradeConfig.Pets[petId].rarity
		if UpgradeConfig.Rarities[rarity].order >= UpgradeConfig.Rarities.rare.order then
			announce:FireAllClients(
				"announce_hatch",
				UpgradeConfig.Rarities[rarity].color,
				player.DisplayName,
				"@rarity_" .. rarity,
				"@pet:" .. petId
			)
		end
	end
end

for _, eggId in ipairs(UpgradeConfig.EggOrder) do
	local egg = UpgradeConfig.Eggs[eggId]

	local stand = Instance.new("Part")
	stand.Name = "EggStand"
	stand.Shape = Enum.PartType.Cylinder
	stand.Anchored = true
	stand.Size = Vector3.new(1.5, 7, 7)
	stand.CFrame = CFrame.new(egg.position + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
	stand.Color = Color3.fromRGB(90, 60, 130)
	stand.Material = Enum.Material.SmoothPlastic
	stand.Parent = Workspace

	local eggPart = Instance.new("Part")
	eggPart.Name = "Egg"
	eggPart:SetAttribute("EggId", eggId)
	eggPart.Anchored = true
	eggPart.Size = Vector3.new(4, 5, 4)
	eggPart.Position = egg.position + Vector3.new(0, 4, 0)
	eggPart.Color = egg.color
	eggPart.Material = eggId == "basic" and Enum.Material.SmoothPlastic or Enum.Material.Neon
	eggPart.Parent = Workspace

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = eggPart

	local label = Instance.new("BillboardGui")
	label.Name = "EggLabel"
	label.Size = UDim2.new(0, 220, 0, 60)
	label.StudsOffset = Vector3.new(0, 4.5, 0)
	label.AlwaysOnTop = true
	label.Parent = eggPart

	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.new(1, 0, 1, 0)
	labelText.BackgroundTransparency = 1
	labelText.Text = string.format("%s Egg\n%d coins", eggId, egg.cost)
	labelText.TextColor3 = egg.color
	labelText.TextStrokeTransparency = 0
	labelText.TextScaled = true
	labelText.Font = Enum.Font.GothamBlack
	labelText.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hatch"
	prompt.ObjectText = eggId .. " egg"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = eggPart

	prompt.Triggered:Connect(function(player)
		hatch(player, eggId)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	lastHatch[player] = nil
end)

---------------------------------------------------------------------
-- ペットの合体: 同じペット 5 匹 → 金色のペット 1 匹
---------------------------------------------------------------------
fuseRemote.OnServerEvent:Connect(function(player, petId)
	if not loadedPlayers[player] or type(petId) ~= "string" then
		return
	end
	local def = UpgradeConfig.Pets[petId]
	if not def or def.golden then
		return
	end

	local petsStore = DataStore2("pets", player)
	local pets = petsStore:Get({})
	if (pets[petId] or 0) < UpgradeConfig.FUSE_COUNT then
		return
	end

	pets[petId] = pets[petId] - UpgradeConfig.FUSE_COUNT
	if pets[petId] <= 0 then
		pets[petId] = nil
	end
	local goldenId = "golden_" .. petId
	pets[goldenId] = (pets[goldenId] or 0) + 1
	petsStore:Set(pets)

	refreshPets(player)
	refreshMultiplier(player)
	announce:FireAllClients("announce_fuse", Color3.fromRGB(255, 210, 50), player.DisplayName, "@pet:" .. goldenId)
end)

---------------------------------------------------------------------
-- ワールド2: 空に浮かぶクリスタルの島（転生すると入れる）
-- 文字は英語で入れておき、LocaleKey 属性を見てクライアントが各言語に書き換える
---------------------------------------------------------------------
local SKY_Y = UpgradeConfig.WORLD2_HEIGHT

local function makeLabel(parent, offsetY, localeKey, localeArg, color, size)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.new(0, 260, 0, 60)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = localeKey
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label:SetAttribute("LocaleKey", localeKey)
	if localeArg then
		label:SetAttribute("LocaleArg", localeArg)
	end
	label.Parent = gui
	return label
end

local island = Instance.new("Part")
island.Name = "CrystalIsland"
island.Anchored = true
island.Size = Vector3.new(140, 4, 140)
island.Position = Vector3.new(0, SKY_Y, 0)
island.Color = Color3.fromRGB(185, 225, 255)
island.Material = Enum.Material.Ice
island.Parent = Workspace

local crystalRng = Random.new(77)
for _ = 1, 24 do
	local angle = crystalRng:NextNumber(0, math.pi * 2)
	local radius = crystalRng:NextNumber(38, 64)
	local height = crystalRng:NextNumber(5, 14)
	local crystal = Instance.new("Part")
	crystal.Anchored = true
	crystal.Size = Vector3.new(2.5, height, 2.5)
	crystal.CFrame = CFrame.new(math.cos(angle) * radius, SKY_Y + 2 + height / 2, math.sin(angle) * radius)
		* CFrame.Angles(crystalRng:NextNumber(-0.3, 0.3), crystalRng:NextNumber(0, math.pi), crystalRng:NextNumber(-0.3, 0.3))
	crystal.Color = Color3.fromRGB(120, 220, 255)
	crystal.Material = Enum.Material.Neon
	crystal.Transparency = 0.2
	crystal.Parent = Workspace
end

local crystalBall = Instance.new("Part")
crystalBall.Name = "CrystalBall"
crystalBall.Shape = Enum.PartType.Ball
crystalBall.Anchored = true
crystalBall.Size = Vector3.new(7, 7, 7)
crystalBall.Position = Vector3.new(0, SKY_Y + 8, -20)
crystalBall.Color = Color3.fromRGB(110, 230, 255)
crystalBall.Material = Enum.Material.Neon
crystalBall.Parent = Workspace

local crystalLight = Instance.new("PointLight")
crystalLight.Color = crystalBall.Color
crystalLight.Range = 22
crystalLight.Brightness = 3
crystalLight.Parent = crystalBall

local crystalDetector = Instance.new("ClickDetector")
crystalDetector.MaxActivationDistance = 40
crystalDetector.Parent = crystalBall
crystalDetector.MouseClick:Connect(function(player)
	handleClick(player, UpgradeConfig.WORLD2_CLICK_MULTIPLIER, crystalBall)
end)
makeLabel(crystalBall, 6, "crystal_click", nil, Color3.fromRGB(180, 245, 255))

-- ポータル（触れると移動）
local portalCooldown = {}

local function makePortal(position, color, localeKey, localeArg, destination, requiredRebirths)
	local portal = Instance.new("Part")
	portal.Name = "Portal"
	portal.Anchored = true
	portal.CanCollide = false
	portal.Size = Vector3.new(7, 10, 1)
	portal.Position = position + Vector3.new(0, 5, 0)
	portal.Color = color
	portal.Material = Enum.Material.Neon
	portal.Transparency = 0.25
	portal.Parent = Workspace

	local frame = Instance.new("Part")
	frame.Anchored = true
	frame.Size = Vector3.new(9, 12, 0.8)
	frame.Position = portal.Position + Vector3.new(0, 0.5, 0.6)
	frame.Color = Color3.fromRGB(60, 40, 90)
	frame.Parent = Workspace

	makeLabel(portal, 7.5, localeKey, localeArg, Color3.fromRGB(255, 255, 255))

	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or not loadedPlayers[player] then
			return
		end
		local now = tick()
		if portalCooldown[player] and now - portalCooldown[player] < 2 then
			return
		end
		portalCooldown[player] = now

		if DataStore2("rebirths", player):Get(0) < requiredRebirths then
			announce:FireClient(player, "announce_need_rebirth", ANNOUNCE_PINK, requiredRebirths)
			return
		end
		character:PivotTo(CFrame.new(destination))
	end)
end

makePortal(Vector3.new(16, 0, 4), Color3.fromRGB(150, 90, 255), "portal_world2", UpgradeConfig.WORLD2_REBIRTHS,
	Vector3.new(0, SKY_Y + 6, 12), UpgradeConfig.WORLD2_REBIRTHS)
makePortal(Vector3.new(16, SKY_Y + 2, 4), Color3.fromRGB(255, 200, 60), "portal_world1", nil,
	Vector3.new(0, 6, 10), 0)

Players.PlayerRemoving:Connect(function(player)
	portalCooldown[player] = nil
end)
