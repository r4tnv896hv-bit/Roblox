-- Shred a Billion: サーバー（土地・シュレッダー・物・粉砕・強化・トラック・保存）
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DataStore2 = require(ServerScriptService.DataStore2)
local ShredConfig = require(ReplicatedStorage.ShredConfig)

---------------------------------------------------------------------
-- Studio で DataStore が使えないときはメモリ上で動かす
---------------------------------------------------------------------
if RunService:IsStudio() then
	local available = pcall(function()
		DataStoreService:GetDataStore("ShredAccessCheck"):GetAsync("check")
	end)
	if not available then
		warn("[ShredABillion] DataStore unavailable; using temporary in-memory saves for Studio.")
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

DataStore2.Combine("SHRED", "money", "totalShredded", "upgrades", "rebirths", "lastDailyDay", "dailyStreak")

---------------------------------------------------------------------
-- 通信
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "ShredRemotes"
local function remote(name)
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = remotes
	return e
end
local notifyRemote = remote("Notify") -- (key, color, ...)
local shreddedRemote = remote("Shredded") -- (itemId, money)
local actionRemote = remote("Action") -- ("upgrade", id) / ("rebirth")
remotes.Parent = ReplicatedStorage

local GOLD = Color3.fromRGB(255, 215, 80)
local GREEN = Color3.fromRGB(120, 255, 140)
local PINK = Color3.fromRGB(255, 120, 200)
local RED = Color3.fromRGB(255, 90, 90)

---------------------------------------------------------------------
-- ワールド
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

part({ Size = Vector3.new(400, 2, 400), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(60, 62, 70), Material = Enum.Material.Concrete })
part({ Size = Vector3.new(60, 0.4, 60), Position = Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(230, 200, 90), Material = Enum.Material.Marble })

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(10, 1, 10)
spawn.Position = Vector3.new(0, 0.9, 18)
spawn.Transparency = 0.5
spawn.Parent = world

-- 土地（真ん中を向いて円形に並ぶ）
local plots = {}
local PLOT_RADIUS = 70

local function makeShredder(plotCFrame)
	local base = plotCFrame * CFrame.new(0, 0, 4)
	part({ Size = Vector3.new(10, 6, 8), CFrame = base * CFrame.new(0, 3, 0), Color = Color3.fromRGB(45, 48, 58), Material = Enum.Material.Metal })
	part({ Size = Vector3.new(11, 0.8, 9), CFrame = base * CFrame.new(0, 6.4, 0), Color = Color3.fromRGB(255, 170, 30), Material = Enum.Material.Metal })
	-- 歯（ネオンの刃）
	local blades = {}
	for i = -2, 2 do
		local blade = part({
			Size = Vector3.new(1.2, 1.2, 7),
			CFrame = base * CFrame.new(i * 1.8, 6.9, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Color = Color3.fromRGB(255, 70, 70),
			Material = Enum.Material.Neon,
		})
		table.insert(blades, blade)
	end
	-- お金が出てくる口
	local chute = part({ Size = Vector3.new(4, 2, 3), CFrame = base * CFrame.new(0, 1.5, 5), Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.Metal })
	local bills = Instance.new("ParticleEmitter")
	bills.Color = ColorSequence.new(Color3.fromRGB(110, 220, 110))
	bills.Size = NumberSequence.new(0.5)
	bills.Speed = NumberRange.new(8, 16)
	bills.SpreadAngle = Vector2.new(40, 40)
	bills.Rotation = NumberRange.new(0, 360)
	bills.RotSpeed = NumberRange.new(-200, 200)
	bills.Lifetime = NumberRange.new(1, 1.6)
	bills.Acceleration = Vector3.new(0, -30, 0)
	bills.Rate = 0
	bills.EmissionDirection = Enum.NormalId.Top
	bills.Parent = chute
	return base, blades, bills
end

for index = 1, ShredConfig.MAX_PLOTS do
	local angle = (index - 1) / ShredConfig.MAX_PLOTS * math.pi * 2
	local position = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)
	-- 土地の正面（-Z）が真ん中を向く
	local plotCFrame = CFrame.lookAt(position, Vector3.new(0, 0, 0))
	local plot = { index = index, cframe = plotCFrame, owner = nil, items = {}, queue = {}, current = nil, progress = 0 }

	plot.floor = part({ Size = Vector3.new(28, 0.6, 28), CFrame = plotCFrame * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(80, 85, 100), Material = Enum.Material.DiamondPlate })
	plot.pad = part({ Size = Vector3.new(14, 0.4, 7), CFrame = plotCFrame * CFrame.new(0, 0.8, -7), Color = Color3.fromRGB(60, 160, 90), Material = Enum.Material.SmoothPlastic })
	plot.shredderCFrame, plot.blades, plot.bills = makeShredder(plotCFrame)

	local sign = part({ Size = Vector3.new(14, 3, 0.6), CFrame = plotCFrame * CFrame.new(0, 11, 4), Color = Color3.fromRGB(25, 25, 35) })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Parent = sign
	plot.signLabel = Instance.new("TextLabel")
	plot.signLabel.Size = UDim2.new(1, 0, 1, 0)
	plot.signLabel.BackgroundTransparency = 1
	plot.signLabel.TextScaled = true
	plot.signLabel.Font = Enum.Font.GothamBlack
	plot.signLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	plot.signLabel.Text = "EMPTY"
	plot.signLabel.Parent = gui

	local plotSpawn = Instance.new("SpawnLocation")
	plotSpawn.Anchored = true
	plotSpawn.Neutral = true
	plotSpawn.Enabled = false
	plotSpawn.Size = Vector3.new(5, 0.4, 5)
	plotSpawn.CFrame = plotCFrame * CFrame.new(0, 0.8, -12)
	plotSpawn.Transparency = 1
	plotSpawn.CanCollide = false
	plotSpawn.Parent = world
	plot.spawn = plotSpawn

	plots[index] = plot
end

---------------------------------------------------------------------
-- プレイヤー
---------------------------------------------------------------------
local loaded = {}
local playerPlot = {}

local function store(player, key)
	return DataStore2(key, player)
end

local function upgradeLevel(player, upgradeId)
	return store(player, "upgrades"):Get({})[upgradeId] or 0
end

local function getMultiplier(player)
	return ShredConfig.Multiplier(store(player, "rebirths"):Get(0), player:GetAttribute("FriendCount") or 0)
		* ShredConfig.BladeBonus(upgradeLevel(player, "blade"))
end

local function refresh(player)
	player:SetAttribute("Upgrades_power", upgradeLevel(player, "power"))
	player:SetAttribute("Upgrades_blade", upgradeLevel(player, "blade"))
	player:SetAttribute("Upgrades_spawn", upgradeLevel(player, "spawn"))
	player:SetAttribute("Upgrades_feeder", upgradeLevel(player, "feeder"))
	player:SetAttribute("Multiplier", getMultiplier(player))
end

local function addMoney(player, amount)
	store(player, "money"):Increment(amount, 0)
	if amount > 0 then
		store(player, "totalShredded"):Increment(amount, 0)
	end
end

---------------------------------------------------------------------
-- 物とシュレッダー
---------------------------------------------------------------------
local itemRng = Random.new()

local function removeItem(plot, model)
	for i, entry in ipairs(plot.items) do
		if entry.model == model then
			table.remove(plot.items, i)
			return entry
		end
	end
	return nil
end

-- シュレッダーに投げ入れる
local function feed(plot, entry)
	if entry.feeding then
		return
	end
	entry.feeding = true
	removeItem(plot, entry.model)
	local detector = entry.model:FindFirstChildOfClass("ClickDetector")
	if detector then
		detector:Destroy()
	end
	local target = plot.shredderCFrame * CFrame.new(0, 8, 0)
	local tween = TweenService:Create(entry.model, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target })
	tween:Play()
	tween.Completed:Connect(function()
		local sink = TweenService:Create(entry.model, TweenInfo.new(0.3), { CFrame = target * CFrame.new(0, -3, 0), Transparency = 0.6 })
		sink:Play()
		sink.Completed:Connect(function()
			entry.model:Destroy()
			table.insert(plot.queue, entry.item)
		end)
	end)
end

local function spawnItem(plot)
	local owner = plot.owner
	if not owner or #plot.items >= ShredConfig.PAD_CAPACITY then
		return
	end
	local item = ShredConfig.RollItem(itemRng, upgradeLevel(owner, "power"))
	local model = Instance.new("Part")
	model.Name = "ShredItem"
	model.Anchored = true
	model.Size = item.size
	model.Color = item.color
	model.Material = item.material
	if item.shape == "Ball" then
		model.Shape = Enum.PartType.Ball
	end
	local slot = #plot.items
	local x = (slot % 4) * 3.2 - 4.8
	local z = math.floor(slot / 4) * 3 - 1.5
	model.CFrame = plot.cframe * CFrame.new(x, 1 + item.size.Y / 2, -7 + z) * CFrame.Angles(0, itemRng:NextNumber(-0.4, 0.4), 0)

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.new(0, 130, 0, 40)
	tag.StudsOffset = Vector3.new(0, item.size.Y / 2 + 1.4, 0)
	tag.MaxDistance = 60
	tag.Parent = model
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.TextStrokeTransparency = 0
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Text = item.id
	text:SetAttribute("ItemId", item.id)
	text:SetAttribute("Value", item.value)
	text.Parent = tag

	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 40
	detector.Parent = model

	local entry = { model = model, item = item }
	table.insert(plot.items, entry)
	detector.MouseClick:Connect(function(clicker)
		if clicker ~= plot.owner then
			notifyRemote:FireClient(clicker, "toast_not_yours", RED)
			return
		end
		feed(plot, entry)
	end)
	model.Parent = world
end

local function clearPlot(plot)
	for _, entry in ipairs(plot.items) do
		entry.model:Destroy()
	end
	plot.items = {}
	plot.queue = {}
	plot.current = nil
	plot.progress = 0
end

-- 毎フレーム: 削る・自動投入・物を出す
RunService.Heartbeat:Connect(function(dt)
	for _, plot in ipairs(plots) do
		local owner = plot.owner
		if owner and loaded[owner] then
			-- 削る
			if not plot.current and #plot.queue > 0 then
				plot.current = table.remove(plot.queue, 1)
				plot.progress = 0
			end
			if plot.current then
				plot.progress = plot.progress + ShredConfig.ShredPower(upgradeLevel(owner, "power")) * dt
				for i, blade in ipairs(plot.blades) do
					blade.CFrame = blade.CFrame * CFrame.Angles(0, 0, dt * 12 * (i % 2 == 0 and 1 or -1))
				end
				if plot.progress >= plot.current.hp then
					local item = plot.current
					plot.current = nil
					local amount = math.floor(item.value * getMultiplier(owner))
					addMoney(owner, amount)
					plot.bills:Emit(math.clamp(math.floor(math.log10(amount + 1) * 6), 6, 40))
					shreddedRemote:FireClient(owner, item.id, amount)
				end
			end

			-- 物を出す
			plot.spawnTimer = (plot.spawnTimer or 0) + dt
			if plot.spawnTimer >= ShredConfig.SpawnInterval(upgradeLevel(owner, "spawn")) then
				plot.spawnTimer = 0
				spawnItem(plot)
			end

			-- 自動投入
			local feederInterval = ShredConfig.FeederInterval(upgradeLevel(owner, "feeder"))
			if feederInterval then
				plot.feederTimer = (plot.feederTimer or 0) + dt
				if plot.feederTimer >= feederInterval and #plot.items > 0 then
					plot.feederTimer = 0
					feed(plot, plot.items[1])
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- 参加・退出
---------------------------------------------------------------------
local function onPlayerAdded(player)
	local plot
	for _, p in ipairs(plots) do
		if not p.owner then
			plot = p
			break
		end
	end
	if not plot then
		player:Kick("Server full - please join another server")
		return
	end
	plot.owner = player
	playerPlot[player] = plot
	plot.signLabel.Text = player.DisplayName
	plot.spawn.Enabled = true
	player.RespawnLocation = plot.spawn
	player:SetAttribute("PlotIndex", plot.index)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local moneyValue = Instance.new("NumberValue")
	moneyValue.Name = "Money"
	moneyValue.Value = store(player, "money"):Get(0)
	moneyValue.Parent = leaderstats
	store(player, "money"):OnUpdate(function(v)
		moneyValue.Value = v
	end)
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = store(player, "rebirths"):Get(0)
	rebirthValue.Parent = leaderstats
	store(player, "rebirths"):OnUpdate(function(v)
		rebirthValue.Value = v
	end)
	if not player.Parent then
		return
	end
	leaderstats.Parent = player
	player:SetAttribute("FriendCount", 0)
	loaded[player] = true
	refresh(player)

	if player.Character then
		player.Character:PivotTo(plot.spawn.CFrame + Vector3.new(0, 4, 0))
	end

	task.delay(4, function()
		if not loaded[player] then
			return
		end
		local today = math.floor(os.time() / 86400)
		local lastDay = store(player, "lastDailyDay"):Get(0)
		if today > lastDay then
			local streak = lastDay == today - 1 and store(player, "dailyStreak"):Get(0) + 1 or 1
			local best = ShredConfig.RollItem(Random.new(1), upgradeLevel(player, "power"))
			local reward = math.floor(best.value * 5 * math.min(streak, 7) * getMultiplier(player))
			store(player, "lastDailyDay"):Set(today)
			store(player, "dailyStreak"):Set(streak)
			addMoney(player, reward)
			notifyRemote:FireClient(player, "announce_daily", GREEN, streak, reward)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local plot = playerPlot[player]
	if plot then
		clearPlot(plot)
		plot.owner = nil
		plot.signLabel.Text = "EMPTY"
	end
	playerPlot[player] = nil
	loaded[player] = nil
end)

---------------------------------------------------------------------
-- 強化・転生
---------------------------------------------------------------------
actionRemote.OnServerEvent:Connect(function(player, action, arg)
	if not loaded[player] then
		return
	end
	if action == "upgrade" and type(arg) == "string" and ShredConfig.Upgrades[arg] then
		local upgrades = store(player, "upgrades"):Get({})
		local level = upgrades[arg] or 0
		if level >= ShredConfig.Upgrades[arg].maxLevel then
			return
		end
		local cost = ShredConfig.UpgradeCost(arg, level)
		if store(player, "money"):Get(0) < cost then
			notifyRemote:FireClient(player, "toast_need_money", RED, cost)
			return
		end
		addMoney(player, -cost)
		upgrades[arg] = level + 1
		store(player, "upgrades"):Set(upgrades)
		refresh(player)
		if arg == "power" then
			for _, item in ipairs(ShredConfig.Items) do
				if item.unlock == level + 1 then
					notifyRemote:FireAllClients("announce_unlock", GOLD, player.DisplayName, "@item_" .. item.id)
				end
			end
		end
	elseif action == "rebirth" then
		local rebirths = store(player, "rebirths"):Get(0)
		local goal = ShredConfig.Goal(rebirths)
		if store(player, "money"):Get(0) < goal then
			notifyRemote:FireClient(player, "toast_need_money", RED, goal)
			return
		end
		store(player, "money"):Set(0)
		store(player, "upgrades"):Set({})
		store(player, "rebirths"):Set(rebirths + 1)
		local plot = playerPlot[player]
		if plot then
			clearPlot(plot)
		end
		refresh(player)
		notifyRemote:FireAllClients("announce_rebirth", PINK, player.DisplayName, rebirths + 1)
	end
end)

---------------------------------------------------------------------
-- みんなで壊す現金輸送トラック（8 分ごと）
---------------------------------------------------------------------
task.spawn(function()
	while true do
		Workspace:SetAttribute("NextTruckAt", os.time() + ShredConfig.TRUCK_INTERVAL)
		task.wait(ShredConfig.TRUCK_INTERVAL)
		if next(loaded) then
			local playerCount = 0
			for _ in pairs(loaded) do
				playerCount = playerCount + 1
			end
			local maxHp = ShredConfig.TRUCK_HP_PER_PLAYER * playerCount
			local hp = maxHp
			local hits = {}

			local truck = part({
				Name = "ArmoredTruck",
				Size = Vector3.new(10, 8, 18),
				Position = Vector3.new(0, 4.4, 0),
				Color = Color3.fromRGB(40, 90, 60),
				Material = Enum.Material.DiamondPlate,
			})
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.new(0, 260, 0, 70)
			tag.StudsOffset = Vector3.new(0, 7, 0)
			tag.AlwaysOnTop = true
			tag.Parent = truck
			local text = Instance.new("TextLabel")
			text.Size = UDim2.new(1, 0, 1, 0)
			text.BackgroundTransparency = 1
			text.TextScaled = true
			text.TextStrokeTransparency = 0
			text.Font = Enum.Font.GothamBlack
			text.TextColor3 = Color3.fromRGB(255, 220, 80)
			text:SetAttribute("TruckHp", hp)
			text.Text = tostring(hp)
			text.Parent = tag

			local detector = Instance.new("ClickDetector")
			detector.MaxActivationDistance = 80
			detector.Parent = truck
			local lastHit = {}
			detector.MouseClick:Connect(function(player)
				if hp <= 0 or not loaded[player] then
					return
				end
				local now = os.clock()
				if lastHit[player] and now - lastHit[player] < 0.1 then
					return
				end
				lastHit[player] = now
				hp = hp - 1
				hits[player] = (hits[player] or 0) + 1
				text:SetAttribute("TruckHp", hp)
				text.Text = tostring(hp)
			end)

			notifyRemote:FireAllClients("announce_truck", GOLD)
			local endAt = os.clock() + ShredConfig.TRUCK_TIME
			while hp > 0 and os.clock() < endAt do
				task.wait(0.2)
			end

			local top, topHits = nil, 0
			for player, count in pairs(hits) do
				if loaded[player] then
					local best = ShredConfig.RollItem(Random.new(2), upgradeLevel(player, "power"))
					local reward = math.floor(best.value * count * 0.6 * getMultiplier(player))
					if hp > 0 then
						reward = math.floor(reward / 3) -- 壊しきれなかったら少なめ
					end
					addMoney(player, reward)
					notifyRemote:FireClient(player, "announce_truck_reward", GOLD, reward)
					if count > topHits then
						top, topHits = player, count
					end
				end
			end
			if top then
				notifyRemote:FireAllClients("announce_truck_done", PINK, top.DisplayName)
			end
			truck:Destroy()
		end
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
		local before = player:GetAttribute("FriendCount") or 0
		player:SetAttribute("FriendCount", count)
		refresh(player)
		if count > before and count <= 5 then
			notifyRemote:FireClient(player, "announce_friend", PINK, count * 20)
		end
	end
end
Players.PlayerAdded:Connect(function()
	task.wait(6)
	updateFriends()
end)
Players.PlayerRemoving:Connect(function()
	task.defer(updateFriends)
end)
