-- Online Shop Tycoon: サーバー（お店の経営のしくみ・保存・ランキング）
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataStore2 = require(ServerScriptService.DataStore2)
local ShopConfig = require(ReplicatedStorage.ShopConfig)

---------------------------------------------------------------------
-- Studio で DataStore が使えないときは、メモリ上の仮の保存場所で動かす
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
	local available = pcall(function()
		DataStoreService:GetDataStore("ShopTycoonAccessCheck"):GetAsync("check")
	end)
	if not available then
		warn("[ShopTycoon] DataStore unavailable; using temporary in-memory saves for Studio.")
		local offlineService = createOfflineDataStoreService()
		require(ServerScriptService.DataStore2.DataStoreServiceRetriever).Get = function()
			return offlineService
		end
	end
end

DataStore2.Combine(
	"SHOP",
	"money",
	"totalEarned",
	"stock",
	"unlocked",
	"priceMode",
	"upgrades",
	"franchises",
	"lastDailyDay",
	"dailyStreak",
	"lastSeen",
	"purchaseHistory"
)

---------------------------------------------------------------------
-- 通信
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "ShopRemotes"

local function remote(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end

local stateRemote = remote("State") -- サーバー → 画面: お店の状態
local notifyRemote = remote("Notify") -- サーバー → 画面: お知らせ (key, color, ...)
local orderRemote = remote("NewOrder") -- サーバー → 画面: 新しい注文 (productId, revenue)
local actionRemote = remote("Action") -- 画面 → サーバー: 操作 (action, arg)
remotes.Parent = ReplicatedStorage

local GOLD = Color3.fromRGB(255, 215, 80)
local GREEN = Color3.fromRGB(120, 255, 140)
local PINK = Color3.fromRGB(255, 130, 200)

---------------------------------------------------------------------
-- プレイヤーのデータ
---------------------------------------------------------------------
local loaded = {}
local session = {} -- 保存しない一時データ（注文待ち・広告など）

local function store(player, key)
	return DataStore2(key, player)
end

local function getMoney(player)
	return store(player, "money"):Get(ShopConfig.STARTING_MONEY)
end

local function addMoney(player, amount)
	store(player, "money"):Increment(amount, ShopConfig.STARTING_MONEY)
	if amount > 0 then
		store(player, "totalEarned"):Increment(amount, 0)
	end
end

local function getUpgrades(player)
	return store(player, "upgrades"):Get({})
end

local function upgradeLevel(player, upgradeId)
	return getUpgrades(player)[upgradeId] or 0
end

local function getMultiplier(player)
	return ShopConfig.Multiplier(
		store(player, "franchises"):Get(0),
		player:GetAttribute("FriendCount") or 0,
		player:GetAttribute("Pass_doubleMoney") == true
	)
end

local function totalStock(stock)
	local total = 0
	for _, count in pairs(stock) do
		total = total + count
	end
	return total
end

local function unlockedCount(player)
	return store(player, "unlocked"):Get(1)
end

local function salePrice(player, product)
	local mode = ShopConfig.PriceModes[store(player, "priceMode"):Get("normal")] or ShopConfig.PriceModes.normal
	return math.max(1, math.floor(product.price * mode.priceMultiplier * getMultiplier(player)))
end

-- 画面に送る状態
local function sendState(player)
	local s = session[player]
	if not s then
		return
	end
	local visitors = ShopConfig.BASE_VISITORS
	local ads = {}
	local now = os.clock()
	for _, ad in ipairs(s.ads) do
		if ad.endsAt > now then
			visitors = visitors + ad.visitors
			ads[ad.id] = math.ceil(ad.endsAt - now)
		end
	end
	local pending = 0
	for _, count in pairs(s.pending) do
		pending = pending + count
	end
	stateRemote:FireClient(player, {
		money = getMoney(player),
		stock = store(player, "stock"):Get({}),
		unlocked = unlockedCount(player),
		priceMode = store(player, "priceMode"):Get("normal"),
		upgrades = getUpgrades(player),
		franchises = store(player, "franchises"):Get(0),
		pending = pending,
		visitors = visitors,
		ads = ads,
		multiplier = getMultiplier(player),
		shipPerSecond = ShopConfig.ShipPerSecond(upgradeLevel(player, "staff"))
			+ (player:GetAttribute("Pass_autoShipper") and ShopConfig.AUTO_SHIPPER_BONUS or 0),
	})
end

---------------------------------------------------------------------
-- 注文と発送
---------------------------------------------------------------------
local MAX_PENDING = 200

local function shipOrders(player, count)
	local s = session[player]
	local shipped, revenue = 0, 0
	for productId, pendingCount in pairs(s.pending) do
		while pendingCount > 0 and shipped < count do
			local product = ShopConfig.GetProduct(productId)
			revenue = revenue + salePrice(player, product)
			pendingCount = pendingCount - 1
			shipped = shipped + 1
		end
		s.pending[productId] = pendingCount > 0 and pendingCount or nil
		if shipped >= count then
			break
		end
	end
	if revenue > 0 then
		addMoney(player, revenue)
	end
	return shipped, revenue
end

local function newVisitor(player, rng)
	local s = session[player]
	local stock = store(player, "stock"):Get({})
	local candidates = {}
	for index = 1, unlockedCount(player) do
		local product = ShopConfig.Products[index]
		if product and (stock[product.id] or 0) > 0 then
			table.insert(candidates, product)
		end
	end
	if #candidates == 0 then
		return
	end

	local pending = 0
	for _, count in pairs(s.pending) do
		pending = pending + count
	end
	if pending >= MAX_PENDING then
		return
	end

	local mode = ShopConfig.PriceModes[store(player, "priceMode"):Get("normal")] or ShopConfig.PriceModes.normal
	local chance = ShopConfig.BASE_CONVERSION * mode.conversion * ShopConfig.RatingBonus(upgradeLevel(player, "rating"))
	if rng:NextNumber() > math.min(chance, 0.95) then
		return
	end

	local product = candidates[rng:NextInteger(1, #candidates)]
	stock[product.id] = stock[product.id] - 1
	store(player, "stock"):Set(stock)
	s.pending[product.id] = (s.pending[product.id] or 0) + 1
	orderRemote:FireClient(player, product.id, salePrice(player, product))
end

local function autoRestock(player)
	if upgradeLevel(player, "restock") < 1 then
		return
	end
	local stock = store(player, "stock"):Get({})
	local capacity = ShopConfig.StockCapacity(upgradeLevel(player, "warehouse"))
	local unlocked = unlockedCount(player)
	local share = math.floor(capacity / unlocked)
	local money = getMoney(player)
	local changed = false
	for index = unlocked, 1, -1 do
		local product = ShopConfig.Products[index]
		local have = stock[product.id] or 0
		if have < share * 0.25 then
			local room = capacity - totalStock(stock)
			local amount = math.min(share - have, room, math.floor(money / product.cost))
			if amount > 0 then
				stock[product.id] = have + amount
				money = money - amount * product.cost
				addMoney(player, -amount * product.cost)
				changed = true
			end
		end
	end
	if changed then
		store(player, "stock"):Set(stock)
	end
end

---------------------------------------------------------------------
-- 操作（画面から）
---------------------------------------------------------------------
local lastShipClick = {}

local actions = {}

function actions.ship(player)
	local now = os.clock()
	if lastShipClick[player] and now - lastShipClick[player] < 0.08 then
		return
	end
	lastShipClick[player] = now
	shipOrders(player, ShopConfig.MANUAL_SHIP)
end

function actions.buyStock(player, productId)
	if type(productId) ~= "string" then
		return
	end
	local product, index = ShopConfig.GetProduct(productId)
	if not product or index > unlockedCount(player) then
		return
	end
	local stock = store(player, "stock"):Get({})
	local capacity = ShopConfig.StockCapacity(upgradeLevel(player, "warehouse"))
	local room = capacity - totalStock(stock)
	local amount = math.min(10, room, math.floor(getMoney(player) / product.cost))
	if room <= 0 then
		notifyRemote:FireClient(player, "toast_warehouse_full", PINK)
		return
	end
	if amount <= 0 then
		notifyRemote:FireClient(player, "toast_need_money", PINK, product.cost)
		return
	end
	stock[productId] = (stock[productId] or 0) + amount
	store(player, "stock"):Set(stock)
	addMoney(player, -amount * product.cost)
end

function actions.unlock(player)
	local unlocked = unlockedCount(player)
	local product = ShopConfig.Products[unlocked + 1]
	if not product then
		return
	end
	if getMoney(player) < product.unlock then
		notifyRemote:FireClient(player, "toast_need_money", PINK, product.unlock)
		return
	end
	addMoney(player, -product.unlock)
	store(player, "unlocked"):Set(unlocked + 1)
	notifyRemote:FireAllClients("announce_unlock", GOLD, player.DisplayName, "@product_" .. product.id)
end

function actions.priceMode(player, mode)
	if type(mode) == "string" and ShopConfig.PriceModes[mode] then
		store(player, "priceMode"):Set(mode)
	end
end

function actions.runAd(player, adId)
	local s = session[player]
	for _, ad in ipairs(ShopConfig.Ads) do
		if ad.id == adId then
			for _, active in ipairs(s.ads) do
				if active.id == adId and active.endsAt > os.clock() then
					return
				end
			end
			local cost = ShopConfig.AdCost(ad, unlockedCount(player))
			if getMoney(player) < cost then
				notifyRemote:FireClient(player, "toast_need_money", PINK, cost)
				return
			end
			addMoney(player, -cost)
			table.insert(s.ads, { id = ad.id, visitors = ad.visitors, endsAt = os.clock() + ad.duration })
			notifyRemote:FireClient(player, "toast_ad_started", GOLD, "@ad_" .. ad.id)
			return
		end
	end
end

function actions.upgrade(player, upgradeId)
	local upgrade = type(upgradeId) == "string" and ShopConfig.Upgrades[upgradeId]
	if not upgrade then
		return
	end
	local upgrades = getUpgrades(player)
	local level = upgrades[upgradeId] or 0
	if level >= upgrade.maxLevel then
		return
	end
	local cost = ShopConfig.UpgradeCost(upgradeId, level)
	if getMoney(player) < cost then
		notifyRemote:FireClient(player, "toast_need_money", PINK, cost)
		return
	end
	addMoney(player, -cost)
	upgrades[upgradeId] = level + 1
	store(player, "upgrades"):Set(upgrades)
end

function actions.sellCompany(player)
	local franchises = store(player, "franchises"):Get(0)
	local cost = ShopConfig.SellCompanyCost(franchises)
	if getMoney(player) < cost then
		notifyRemote:FireClient(player, "toast_need_money", PINK, cost)
		return
	end
	store(player, "money"):Set(ShopConfig.STARTING_MONEY)
	store(player, "stock"):Set({})
	store(player, "unlocked"):Set(1)
	store(player, "upgrades"):Set({})
	store(player, "priceMode"):Set("normal")
	store(player, "franchises"):Set(franchises + 1)
	session[player].pending = {}
	session[player].ads = {}
	notifyRemote:FireAllClients("announce_sold", PINK, player.DisplayName, franchises + 1)
end

actionRemote.OnServerEvent:Connect(function(player, action, arg)
	if not loaded[player] or type(action) ~= "string" then
		return
	end
	local handler = actions[action]
	if handler then
		handler(player, arg)
		sendState(player)
	end
end)

---------------------------------------------------------------------
-- 参加・退出・毎ティックの処理
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

local function updateFriends()
	for player in pairs(loaded) do
		local count = 0
		for other in pairs(loaded) do
			if other ~= player and other.Parent and areFriends(player, other) then
				count = count + 1
			end
		end
		local before = player:GetAttribute("FriendCount") or 0
		player:SetAttribute("FriendCount", count)
		if count > before and count <= 5 then
			notifyRemote:FireClient(player, "announce_friend", PINK, count * 20)
		end
	end
end

local function checkGamePasses(player)
	for passKey, pass in pairs(ShopConfig.GamePasses) do
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

local function giveDailyAndOffline(player)
	local today = math.floor(os.time() / 86400)
	local lastDay = store(player, "lastDailyDay"):Get(0)
	if today > lastDay then
		local streak = 1
		if lastDay == today - 1 then
			streak = store(player, "dailyStreak"):Get(0) + 1
		end
		local reward = math.floor(ShopConfig.DAILY_BASE * math.min(streak, 7) * getMultiplier(player))
		store(player, "lastDailyDay"):Set(today)
		store(player, "dailyStreak"):Set(streak)
		addMoney(player, reward)
		notifyRemote:FireClient(player, "announce_daily", GREEN, streak, reward)
	end

	local lastSeen = store(player, "lastSeen"):Get(0)
	local now = os.time()
	store(player, "lastSeen"):Set(now)
	if lastSeen > 0 then
		local away = math.min(now - lastSeen, ShopConfig.OFFLINE_MAX_SECONDS)
		local shipRate = ShopConfig.ShipPerSecond(upgradeLevel(player, "staff"))
		if away >= 60 and shipRate > 0 then
			local best = ShopConfig.Products[unlockedCount(player)]
			local reward = math.floor(away * shipRate * best.price * ShopConfig.OFFLINE_RATE * getMultiplier(player) * 0.3)
			if reward > 0 then
				addMoney(player, reward)
				notifyRemote:FireClient(player, "announce_offline", GREEN, reward, math.floor(away / 60))
			end
		end
	end
end

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = getMoney(player)
	money.Parent = leaderstats
	store(player, "money"):OnUpdate(function(value)
		money.Value = value
	end)

	local franchises = Instance.new("IntValue")
	franchises.Name = "Franchises"
	franchises.Value = store(player, "franchises"):Get(0)
	franchises.Parent = leaderstats
	store(player, "franchises"):OnUpdate(function(value)
		franchises.Value = value
	end)

	if not player.Parent then
		return
	end
	leaderstats.Parent = player

	session[player] = { pending = {}, ads = {}, visitorAcc = 0, shipAcc = 0, rng = Random.new(), seconds = 0 }
	player:SetAttribute("FriendCount", 0)
	checkGamePasses(player)
	loaded[player] = true
	updateFriends()
	sendState(player)

	task.delay(4, function()
		if loaded[player] then
			giveDailyAndOffline(player)
			sendState(player)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	if loaded[player] then
		store(player, "lastSeen"):Set(os.time())
	end
	loaded[player] = nil
	session[player] = nil
	lastShipClick[player] = nil
	updateFriends()
end)

local TICK = 0.5
task.spawn(function()
	while true do
		task.wait(TICK)
		local now = os.clock()
		for player in pairs(loaded) do
			local s = session[player]
			if s then
				-- 終わった広告を消す
				local visitors = ShopConfig.BASE_VISITORS
				for i = #s.ads, 1, -1 do
					if s.ads[i].endsAt <= now then
						table.remove(s.ads, i)
					else
						visitors = visitors + s.ads[i].visitors
					end
				end

				-- お客さんが来る
				s.visitorAcc = s.visitorAcc + visitors * TICK
				while s.visitorAcc >= 1 do
					s.visitorAcc = s.visitorAcc - 1
					newVisitor(player, s.rng)
				end

				-- スタッフが自動で発送
				local shipRate = ShopConfig.ShipPerSecond(upgradeLevel(player, "staff"))
					+ (player:GetAttribute("Pass_autoShipper") and ShopConfig.AUTO_SHIPPER_BONUS or 0)
				s.shipAcc = s.shipAcc + shipRate * TICK
				if s.shipAcc >= 1 then
					local count = math.floor(s.shipAcc)
					s.shipAcc = s.shipAcc - count
					shipOrders(player, count)
				end

				s.seconds = s.seconds + TICK
				if s.seconds % 5 < TICK then
					autoRestock(player)
				end
				if s.seconds % 30 < TICK then
					store(player, "lastSeen"):Set(os.time())
				end

				sendState(player)
			end
		end
	end
end)

---------------------------------------------------------------------
-- 課金
---------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	for passKey, pass in pairs(ShopConfig.GamePasses) do
		if pass.id == passId then
			player:SetAttribute("Pass_" .. passKey, true)
			notifyRemote:FireAllClients("announce_pass", PINK, player.DisplayName, "@pass_" .. passKey)
		end
	end
end)

---------------------------------------------------------------------
-- ランキング看板（全サーバー共通、これまでの売上合計）
---------------------------------------------------------------------
local rankingOk, rankingStore = pcall(function()
	return DataStoreService:GetOrderedDataStore("TotalEarned")
end)

local board = Workspace:WaitForChild("RankingBoard", 30)
local rankLabels = {}
if board then
	local surface = board:FindFirstChildOfClass("SurfaceGui")
	for rank = 1, 10 do
		rankLabels[rank] = surface and surface:FindFirstChild("Rank" .. rank)
	end
end

local nameCache = {}
local function getName(userId)
	if not nameCache[userId] then
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		nameCache[userId] = ok and name or "???"
	end
	return nameCache[userId]
end

local function abbreviate(n)
	local units = { "", "K", "M", "B", "T" }
	local i = 1
	while n >= 1000 and i < #units do
		n = n / 1000
		i = i + 1
	end
	return (i == 1 and string.format("%d", n) or string.format("%.1f", n)) .. units[i]
end

if rankingOk then
	task.spawn(function()
		task.wait(5)
		while true do
			for player in pairs(loaded) do
				local total = store(player, "totalEarned"):Get(0)
				pcall(function()
					rankingStore:SetAsync(tostring(player.UserId), math.floor(total))
				end)
			end
			local ok, entries = pcall(function()
				return rankingStore:GetSortedAsync(false, 10):GetCurrentPage()
			end)
			if ok then
				for rank = 1, 10 do
					local label = rankLabels[rank]
					local entry = entries[rank]
					if label then
						label.Text = entry and string.format("%d. %s  $%s", rank, getName(tonumber(entry.key)), abbreviate(entry.value)) or ""
					end
				end
			end
			task.wait(60)
		end
	end)
end
