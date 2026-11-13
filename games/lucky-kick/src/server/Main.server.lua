-- Lucky Block Kick: サーバー（フィールド・キック・飛距離・報酬・保存）
local DataStoreService = game:GetService("DataStoreService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataStore2 = require(ServerScriptService.DataStore2)
local KickConfig = require(ReplicatedStorage.KickConfig)

---------------------------------------------------------------------
-- Studio で DataStore が使えないときはメモリ上で動かす
---------------------------------------------------------------------
if RunService:IsStudio() then
	local available = pcall(function()
		DataStoreService:GetDataStore("LuckyKickAccessCheck"):GetAsync("check")
	end)
	if not available then
		warn("[LuckyKick] DataStore unavailable; using temporary in-memory saves for Studio.")
		local stores = {}
		local function newStore()
			local data = {}
			local s = {}
			function s:GetAsync(key)
				return data[key]
			end
			function s:SetAsync(key, value)
				data[key] = value
			end
			function s:UpdateAsync(key, transform)
				local v = transform(data[key])
				if v ~= nil then
					data[key] = v
				end
				return v
			end
			function s:GetSortedAsync()
				return {
					GetCurrentPage = function()
						return {}
					end,
				}
			end
			return s
		end
		local service = {}
		function service:GetDataStore(name)
			stores[name] = stores[name] or newStore()
			return stores[name]
		end
		function service:GetOrderedDataStore(name)
			stores["o:" .. name] = stores["o:" .. name] or newStore()
			return stores["o:" .. name]
		end
		require(ServerScriptService.DataStore2.DataStoreServiceRetriever).Get = function()
			return service
		end
	end
end

DataStore2.Combine("KICK", "coins", "leg", "luck", "best", "rebirths", "lastDailyDay", "dailyStreak")

---------------------------------------------------------------------
-- 通信
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "KickRemotes"
local function remote(name)
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = remotes
	return e
end
local kickRemote = remote("Kick") -- 画面 → サーバー: (power)
local launchedRemote = remote("Launched") -- サーバー → 画面: (block)
local landedRemote = remote("Landed") -- サーバー → 画面: (distance, blockId, rewardId, coins, perfect)
local actionRemote = remote("Action") -- 画面 → サーバー: ("upgrade", id) / ("rebirth")
local notifyRemote = remote("Notify") -- サーバー → 画面: (key, color, ...)
remotes.Parent = ReplicatedStorage

local GOLD = Color3.fromRGB(255, 215, 80)
local PINK = Color3.fromRGB(255, 120, 200)
local GREEN = Color3.fromRGB(120, 255, 140)
local RED = Color3.fromRGB(255, 90, 90)

---------------------------------------------------------------------
-- ワールド: フィールド・距離の看板・地帯のアーチ
---------------------------------------------------------------------
local world = Instance.new("Folder")
world.Name = "World"
world.Parent = Workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = props.Parent or world
	return p
end

local FIELD_WIDTH = 180

-- キックする場所
part({ Size = Vector3.new(60, 4, 60), Position = Vector3.new(0, -2, -30), Color = Color3.fromRGB(70, 75, 85), Material = Enum.Material.Concrete })
part({ Size = Vector3.new(8, 1, 8), Position = KickConfig.TEE - Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic })

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(10, 1, 10)
spawn.Position = Vector3.new(0, 0.5, -24)
spawn.Transparency = 0.5
spawn.Neutral = true
spawn.Parent = world

-- 地帯ごとの地面（部品の最大サイズに合わせて分ける）
for i, zone in ipairs(KickConfig.Zones) do
	local finish = KickConfig.Zones[i + 1] and KickConfig.Zones[i + 1].start or KickConfig.FIELD_LENGTH
	local z = zone.start
	while z < finish do
		local length = math.min(1000, finish - z)
		part({
			Size = Vector3.new(FIELD_WIDTH, 4, length),
			Position = Vector3.new(0, -2, z + length / 2),
			Color = zone.color,
			Material = zone.material,
		})
		z = z + length
	end

	-- 地帯の入り口のアーチ
	if zone.start > 0 then
		for _, x in ipairs({ -40, 40 }) do
			part({ Size = Vector3.new(4, 40, 4), Position = Vector3.new(x, 20, zone.start), Color = zone.color, Material = Enum.Material.Neon })
		end
		local top = part({ Size = Vector3.new(84, 8, 4), Position = Vector3.new(0, 42, zone.start), Color = Color3.fromRGB(30, 30, 40) })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Parent = top
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.GothamBlack
		text.TextColor3 = zone.color
		text.Text = string.upper(zone.id)
		text:SetAttribute("LocaleKey", "zone_" .. zone.id)
		text.Parent = gui
	end
end

-- 100m ごとの看板
for distance = 100, KickConfig.FIELD_LENGTH, 100 do
	local post = part({
		Size = Vector3.new(14, 6, 1),
		Position = Vector3.new(-FIELD_WIDTH / 2 + 10, 8, distance),
		Color = Color3.fromRGB(25, 25, 35),
	})
	part({ Size = Vector3.new(1, 6, 1), Position = Vector3.new(-FIELD_WIDTH / 2 + 10, 2.5, distance), Color = Color3.fromRGB(60, 60, 70) })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Parent = post
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = distance % 1000 == 0 and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(255, 255, 255)
	text.Text = distance .. "m"
	text.Parent = gui
end

-- ブロック同士・プレイヤーとはぶつからない
pcall(function()
	PhysicsService:RegisterCollisionGroup("Blocks")
end)
PhysicsService:CollisionGroupSetCollidable("Blocks", "Blocks", false)
PhysicsService:CollisionGroupSetCollidable("Blocks", "Default", true)

---------------------------------------------------------------------
-- プレイヤー
---------------------------------------------------------------------
local loaded = {}
local lastKick = {}
local kicking = {}
local serverRecord = 0

local function store(player, key)
	return DataStore2(key, player)
end

local function getMultiplier(player)
	return KickConfig.Multiplier(store(player, "rebirths"):Get(0), player:GetAttribute("FriendCount") or 0)
end

local function refresh(player)
	player:SetAttribute("Leg", store(player, "leg"):Get(0))
	player:SetAttribute("Luck", store(player, "luck"):Get(0))
	player:SetAttribute("Multiplier", getMultiplier(player))
end

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = store(player, "coins"):Get(0)
	coins.Parent = leaderstats
	store(player, "coins"):OnUpdate(function(v)
		coins.Value = v
	end)
	local best = Instance.new("IntValue")
	best.Name = "Best"
	best.Value = store(player, "best"):Get(0)
	best.Parent = leaderstats
	store(player, "best"):OnUpdate(function(v)
		best.Value = v
	end)
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = store(player, "rebirths"):Get(0)
	rebirths.Parent = leaderstats
	store(player, "rebirths"):OnUpdate(function(v)
		rebirths.Value = v
	end)
	if not player.Parent then
		return
	end
	leaderstats.Parent = player
	player:SetAttribute("FriendCount", 0)
	loaded[player] = true
	refresh(player)

	task.delay(4, function()
		if not loaded[player] then
			return
		end
		local today = math.floor(os.time() / 86400)
		local lastDay = store(player, "lastDailyDay"):Get(0)
		if today > lastDay then
			local streak = lastDay == today - 1 and store(player, "dailyStreak"):Get(0) + 1 or 1
			local reward = math.floor(100 * math.min(streak, 7) * getMultiplier(player))
			store(player, "lastDailyDay"):Set(today)
			store(player, "dailyStreak"):Set(streak)
			store(player, "coins"):Increment(reward, 0)
			notifyRemote:FireClient(player, "announce_daily", GREEN, streak, reward)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	loaded[player] = nil
	lastKick[player] = nil
	kicking[player] = nil
end)

---------------------------------------------------------------------
-- キック
---------------------------------------------------------------------
local rng = Random.new()

local function makeBlock(blockType)
	local block = Instance.new("Part")
	block.Name = "LuckyBlock"
	block.Size = Vector3.new(3, 3, 3)
	block.Color = blockType.color
	block.Material = blockType.material
	block.CollisionGroup = "Blocks"
	block.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1.4, 0.15, 1, 1)
	for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Parent = block
		local mark = Instance.new("TextLabel")
		mark.Size = UDim2.new(1, 0, 1, 0)
		mark.BackgroundTransparency = 1
		mark.Text = "?"
		mark.TextScaled = true
		mark.Font = Enum.Font.GothamBlack
		mark.TextColor3 = Color3.fromRGB(255, 255, 255)
		mark.TextStrokeTransparency = 0
		mark.Parent = gui
	end
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = block
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = block
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(blockType.color)
	trail.Lifetime = 0.6
	trail.LightEmission = 1
	trail.Parent = block
	return block
end

kickRemote.OnServerEvent:Connect(function(player, power)
	if not loaded[player] or kicking[player] then
		return
	end
	local now = os.clock()
	if lastKick[player] and now - lastKick[player] < KickConfig.KICK_COOLDOWN then
		return
	end
	lastKick[player] = now
	if type(power) ~= "number" or power ~= power then
		return
	end
	power = math.clamp(power, 0, 1)
	local perfect = power >= 0.92
	if perfect then
		power = 1.1 -- パーフェクトはさらに少し遠くへ
	end

	kicking[player] = true
	local blockType = KickConfig.RollBlock(rng, store(player, "luck"):Get(0))
	local block = makeBlock(blockType)
	block.Position = KickConfig.TEE
	block.Parent = Workspace
	block:SetNetworkOwner(nil)
	block.AssemblyLinearVelocity = KickConfig.KickVelocity(power, store(player, "leg"):Get(0))
	block.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
	launchedRemote:FireClient(player, block)

	if blockType.id == "rainbow" then
		notifyRemote:FireAllClients("announce_rainbow", PINK, player.DisplayName)
	end

	task.spawn(function()
		local started = os.clock()
		task.wait(0.8)
		while os.clock() - started < KickConfig.MAX_FLIGHT_TIME do
			if block.AssemblyLinearVelocity.Magnitude < 2 or block.Position.Y < -40 then
				break
			end
			task.wait(0.2)
		end
		local distance = math.max(0, math.floor(block.Position.Z - KickConfig.TEE.Z))

		local reward = KickConfig.RollReward(rng)
		local coins = math.floor(distance * KickConfig.COINS_PER_STUD * blockType.multiplier * reward.multiplier * getMultiplier(player))
		coins = math.max(coins, 1)
		if loaded[player] then
			store(player, "coins"):Increment(coins, 0)
			if distance > store(player, "best"):Get(0) then
				store(player, "best"):Set(distance)
			end
			landedRemote:FireClient(player, distance, blockType.id, reward.id, coins, perfect)
			if distance > serverRecord and distance >= 100 then
				serverRecord = distance
				notifyRemote:FireAllClients("announce_record", GOLD, player.DisplayName, distance)
			end
			if reward.id == "mega" then
				notifyRemote:FireAllClients("announce_mega", GOLD, player.DisplayName)
			end
		end

		-- 開けたときの演出
		block.Anchored = true
		local burst = Instance.new("ParticleEmitter")
		burst.Color = ColorSequence.new(blockType.color)
		burst.LightEmission = 1
		burst.Speed = NumberRange.new(10, 25)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Lifetime = NumberRange.new(0.8, 1.4)
		burst.Size = NumberSequence.new(0.8, 0)
		burst.Rate = 0
		burst.Parent = block
		burst:Emit(50)
		task.wait(1.5)
		block:Destroy()
		kicking[player] = nil
	end)
end)

---------------------------------------------------------------------
-- 強化・転生
---------------------------------------------------------------------
actionRemote.OnServerEvent:Connect(function(player, action, arg)
	if not loaded[player] then
		return
	end
	if action == "upgrade" and type(arg) == "string" and KickConfig.Upgrades[arg] then
		local level = store(player, arg):Get(0)
		if level >= KickConfig.Upgrades[arg].maxLevel then
			return
		end
		local cost = KickConfig.UpgradeCost(arg, level)
		if store(player, "coins"):Get(0) < cost then
			notifyRemote:FireClient(player, "toast_need_money", RED, cost)
			return
		end
		store(player, "coins"):Increment(-cost, 0)
		store(player, arg):Set(level + 1)
		refresh(player)
	elseif action == "rebirth" then
		local rebirths = store(player, "rebirths"):Get(0)
		local cost = KickConfig.RebirthCost(rebirths)
		if store(player, "coins"):Get(0) < cost then
			notifyRemote:FireClient(player, "toast_need_money", RED, cost)
			return
		end
		store(player, "coins"):Set(0)
		store(player, "leg"):Set(0)
		store(player, "luck"):Set(0)
		store(player, "rebirths"):Set(rebirths + 1)
		refresh(player)
		notifyRemote:FireAllClients("announce_rebirth", PINK, player.DisplayName, rebirths + 1)
	end
end)

---------------------------------------------------------------------
-- フレンドボーナス
---------------------------------------------------------------------
local friendCache = {}
local function updateFriends()
	for player in pairs(loaded) do
		local count = 0
		for other in pairs(loaded) do
			if other ~= player then
				local key = math.min(player.UserId, other.UserId) .. ":" .. math.max(player.UserId, other.UserId)
				if friendCache[key] == nil then
					local ok, result = pcall(function()
						return player:IsFriendsWith(other.UserId)
					end)
					friendCache[key] = ok and result or false
				end
				if friendCache[key] then
					count = count + 1
				end
			end
		end
		player:SetAttribute("FriendCount", count)
		refresh(player)
	end
end
Players.PlayerAdded:Connect(function()
	task.wait(6)
	updateFriends()
end)
Players.PlayerRemoving:Connect(function()
	task.defer(updateFriends)
end)
